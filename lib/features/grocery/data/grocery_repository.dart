import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/grocery_item.dart';
import '../models/grocery_list.dart';
import '../../family/data/family_repository.dart';
import '../../../core/utils/family_permissions.dart';
import '../../../core/services/household_notification_service.dart';

/// Personal or family-scoped grocery list.
/// When in a Family Space: `families/{familyId}/groceryLists`.
class GroceryRepository extends ValueNotifier<Map<String, List<GroceryItem>>> {
  GroceryRepository._() : super({}) {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _uid = user?.uid;
      _resetListener();
    });
    FamilyRepository.instance.addListener(_onFamilyChange);
  }

  static final instance = GroceryRepository._();

  final _firestore = FirebaseFirestore.instance;
  String? _uid;
  String? _familyId;
  GroceryList? _activeList;
  StreamSubscription? _sub;
  String? error;

  GroceryList? get activeList => _activeList;
  Map<String, List<GroceryItem>> get sections => value;
  bool get isShared => _familyId != null;

  CollectionReference<Map<String, dynamic>> get _groceryListsCol {
    final familyId = _familyId;
    if (familyId != null) {
      return _firestore
          .collection('families')
          .doc(familyId)
          .collection('groceryLists');
    }
    return _firestore.collection('users').doc(_uid).collection('groceryLists');
  }

  void _onFamilyChange() {
    final newId = FamilyRepository.instance.value?.id;
    if (_familyId != newId) {
      _familyId = newId;
      _resetListener();
    }
  }

  void _resetListener() {
    _sub?.cancel();
    _sub = null;
    value = {};
    _activeList = null;
    error = null;
    if (_uid == null) return;
    _familyId = FamilyRepository.instance.value?.id;
    _listenToActiveList();
  }

  Future<void> _listenToActiveList() async {
    _sub?.cancel();
    if (_uid == null) return;
    try {
      final query = await _groceryListsCol
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      String listId;
      if (query.docs.isEmpty) {
        final doc = await _groceryListsCol.add({
          'title': isShared ? 'Family Shopping List' : 'Shopping List',
          'createdAt': FieldValue.serverTimestamp(),
        });
        listId = doc.id;
        _activeList = GroceryList(
          id: listId,
          title: isShared ? 'Family Shopping List' : 'Shopping List',
        );
      } else {
        listId = query.docs.first.id;
        _activeList = GroceryList.fromFirestore(query.docs.first);
      }

      if (_uid == null) return;

      _sub =
          _groceryListsCol.doc(listId).collection('items').snapshots().listen(
        (snapshot) {
          error = null;
          final grouped = <String, List<GroceryItem>>{};
          for (final doc in snapshot.docs) {
            final item = GroceryItem.fromFirestore(doc);
            grouped.putIfAbsent(item.category, () => []).add(item);
          }
          value = grouped;
        },
        onError: (e) {
          error = 'Failed to load grocery list: $e';
          notifyListeners();
        },
      );
    } catch (e) {
      error = 'Failed to initialize grocery list: $e';
      notifyListeners();
    }
  }

  Future<void> cycleStatus(String id) async {
    if (_activeList == null || _uid == null) return;
    if (!FamilyPermissions.canGenerateGroceryList) {
      error = FamilyPermissions.denialMessage('update the grocery list');
      notifyListeners();
      return;
    }

    GroceryItem? foundItem;
    for (final list in value.values) {
      try {
        foundItem = list.firstWhere((i) => i.id == id);
        break;
      } catch (_) {}
    }
    if (foundItem == null) return;

    final nextStatus = GroceryStatus
        .values[(foundItem.status.index + 1) % GroceryStatus.values.length];

    await _groceryListsCol
        .doc(_activeList!.id)
        .collection('items')
        .doc(id)
        .update({
      'status': nextStatus.name,
      'checked': nextStatus == GroceryStatus.used,
    });
  }

  /// Toggle purchased (used) checkbox state.
  Future<void> setPurchased(String id, bool purchased) async {
    if (_activeList == null || _uid == null) return;
    if (!FamilyPermissions.canGenerateGroceryList) {
      error = FamilyPermissions.denialMessage('update the grocery list');
      notifyListeners();
      return;
    }
    final status = purchased ? GroceryStatus.used : GroceryStatus.needed;
    await _groceryListsCol
        .doc(_activeList!.id)
        .collection('items')
        .doc(id)
        .update({
      'status': status.name,
      'checked': purchased,
    });
  }

  bool _nameExists(String name) {
    final lower = name.trim().toLowerCase();
    if (lower.isEmpty) return false;
    return allItems.any((i) => i.name.trim().toLowerCase() == lower);
  }

  Future<void> addItem(String section, GroceryItem item) async {
    if (_uid == null) {
      error = 'Not signed in; grocery item was not saved.';
      notifyListeners();
      throw StateError(error!);
    }
    if (!FamilyPermissions.canGenerateGroceryList) {
      error = FamilyPermissions.denialMessage('add grocery items');
      notifyListeners();
      throw StateError(error!);
    }
    if (_activeList == null) {
      await _listenToActiveList();
    }
    if (_activeList == null) {
      error = error ?? 'Grocery list is not ready; item was not saved.';
      notifyListeners();
      throw StateError(error!);
    }
    if (_nameExists(item.name)) {
      error = '"${item.name}" is already on your grocery list.';
      notifyListeners();
      return;
    }
    try {
      final itemToSave = item.copyWith(
        category: section,
        addedBy: item.addedBy ?? _uid,
      );
      await _groceryListsCol
          .doc(_activeList!.id)
          .collection('items')
          .add(itemToSave.toFirestore());
      error = null;

      // Send household notification
      HouseholdNotificationService.instance.notifyGroceryActivity(
        action: 'added',
        itemName: item.name,
      );
    } catch (e) {
      error = 'Failed to save grocery item: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Adds only items not already present (case-insensitive name match).
  /// Returns the number of items actually added.
  Future<int> addMultipleItems(List<GroceryItem> items) async {
    if (_uid == null) {
      error = 'Not signed in; grocery items were not saved.';
      notifyListeners();
      throw StateError(error!);
    }
    if (!FamilyPermissions.canGenerateGroceryList) {
      error = FamilyPermissions.denialMessage('generate a grocery list');
      notifyListeners();
      throw StateError(error!);
    }
    if (_activeList == null) {
      await _listenToActiveList();
    }
    if (_activeList == null) {
      error = error ?? 'Grocery list is not ready; items were not saved.';
      notifyListeners();
      throw StateError(error!);
    }

    final existing = allItems.map((i) => i.name.trim().toLowerCase()).toSet();
    final seenInBatch = <String>{};
    final toAdd = <GroceryItem>[];
    for (final item in items) {
      final key = item.name.trim().toLowerCase();
      if (key.isEmpty) continue;
      if (existing.contains(key) || seenInBatch.contains(key)) continue;
      seenInBatch.add(key);
      toAdd.add(item.copyWith(addedBy: item.addedBy ?? _uid));
    }

    if (toAdd.isEmpty) {
      error = null;
      return 0;
    }

    try {
      final batch = _firestore.batch();
      final itemsCol =
          _groceryListsCol.doc(_activeList!.id).collection('items');
      for (final item in toAdd) {
        batch.set(itemsCol.doc(), item.toFirestore());
      }
      await batch.commit();
      error = null;
      return toAdd.length;
    } catch (e) {
      error = 'Failed to save grocery items: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> clearUsed() async {
    if (_activeList == null || _uid == null) return;
    if (!FamilyPermissions.canGenerateGroceryList) return;
    final itemsCol = _groceryListsCol.doc(_activeList!.id).collection('items');
    final checkedItems = await itemsCol.where('checked', isEqualTo: true).get();
    if (checkedItems.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in checkedItems.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> deleteItem(String id) async {
    if (_activeList == null || _uid == null) return;
    if (!FamilyPermissions.canGenerateGroceryList) {
      error = FamilyPermissions.denialMessage('delete grocery items');
      notifyListeners();
      return;
    }

    // Get item name for notification
    GroceryItem? foundItem;
    for (final list in value.values) {
      try {
        foundItem = list.firstWhere((i) => i.id == id);
        break;
      } catch (_) {}
    }

    await _groceryListsCol
        .doc(_activeList!.id)
        .collection('items')
        .doc(id)
        .delete();

    // Send household notification
    if (foundItem != null) {
      HouseholdNotificationService.instance.notifyGroceryActivity(
        action: 'removed',
        itemName: foundItem.name,
      );
    }
  }

  int get remainingCount {
    int count = 0;
    for (final list in value.values) {
      count += list.where((item) => item.status != GroceryStatus.used).length;
    }
    return count;
  }

  List<GroceryItem> get allItems =>
      value.values.expand((list) => list).toList();

  List<String> get allItemNames =>
      allItems.map((i) => i.name).where((n) => n.isNotEmpty).toList();
}

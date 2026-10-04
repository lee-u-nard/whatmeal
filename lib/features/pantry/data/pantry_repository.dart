import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/pantry_item.dart';
import '../../family/data/family_repository.dart';
import '../../../core/utils/family_permissions.dart';
import '../../../core/services/household_notification_service.dart';

/// Personal or family-scoped pantry. When the user is in a Family Space,
/// reads/writes go to `families/{familyId}/pantryItems`.
class PantryRepository extends ValueNotifier<Map<String, List<PantryItem>>> {
  PantryRepository._() : super({}) {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _uid = user?.uid;
      _resetListener();
    });
    FamilyRepository.instance.addListener(_onFamilyChange);
  }

  static final instance = PantryRepository._();

  final _firestore = FirebaseFirestore.instance;
  String? _uid;
  String? _familyId;
  StreamSubscription? _sub;
  String? error;

  Map<String, List<PantryItem>> get items => value;

  bool get isShared => _familyId != null;

  CollectionReference<Map<String, dynamic>> get _pantryCol {
    final familyId = _familyId;
    if (familyId != null) {
      return _firestore
          .collection('families')
          .doc(familyId)
          .collection('pantryItems');
    }
    return _firestore.collection('users').doc(_uid).collection('pantryItems');
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
    error = null;
    if (_uid == null) return;
    _familyId = FamilyRepository.instance.value?.id;
    _listenToItems();
  }

  void _listenToItems() {
    _sub?.cancel();
    if (_uid == null) return;
    _sub = _pantryCol.orderBy('createdAt', descending: true).snapshots().listen(
      (snapshot) {
        error = null;
        final grouped = <String, List<PantryItem>>{};
        for (final doc in snapshot.docs) {
          final item = PantryItem.fromFirestore(doc);
          grouped.putIfAbsent(item.category, () => []).add(item);
        }
        value = grouped;
      },
      onError: (e) {
        error = 'Failed to load pantry: $e';
        notifyListeners();
      },
    );
  }

  Future<void> addItem(String category, PantryItem item) async {
    if (_uid == null) return;
    if (!FamilyPermissions.canManagePantry) {
      error = FamilyPermissions.denialMessage('manage the pantry');
      notifyListeners();
      throw StateError(error!);
    }
    final itemToSave = item.copyWith(
      category: category,
      addedBy: item.addedBy ?? _uid,
    );
    await _pantryCol.add(itemToSave.toFirestore());

    // Send household notification
    HouseholdNotificationService.instance.notifyPantryActivity(
      action: 'added',
      itemName: item.name,
    );
  }

  Future<void> updateItem(String category, PantryItem updatedItem) async {
    if (_uid == null || updatedItem.id == null || updatedItem.id!.isEmpty) {
      return;
    }
    if (!FamilyPermissions.canManagePantry) {
      error = FamilyPermissions.denialMessage('manage the pantry');
      notifyListeners();
      throw StateError(error!);
    }
    await _pantryCol
        .doc(updatedItem.id)
        .update(updatedItem.copyWith(category: category).toFirestore());
  }

  Future<void> setItemStatus(String id, PantryStatus status) async {
    if (_uid == null) return;
    if (!FamilyPermissions.canManagePantry) {
      error = FamilyPermissions.denialMessage('manage the pantry');
      notifyListeners();
      throw StateError(error!);
    }
    await _pantryCol.doc(id).update({'status': status.name});
  }

  /// Cycle available → runningLow → used → needed → available.
  Future<void> cycleStatus(String id) async {
    PantryItem? found;
    for (final list in value.values) {
      try {
        found = list.firstWhere((i) => i.id == id);
        break;
      } catch (_) {}
    }
    if (found == null) return;
    final next = PantryStatus
        .values[(found.status.index + 1) % PantryStatus.values.length];
    await setItemStatus(id, next);
  }

  Future<void> deleteItem(String id) async {
    if (_uid == null) return;
    if (!FamilyPermissions.canManagePantry) {
      error = FamilyPermissions.denialMessage('manage the pantry');
      notifyListeners();
      throw StateError(error!);
    }

    // Get item name for notification
    PantryItem? foundItem;
    for (final list in value.values) {
      try {
        foundItem = list.firstWhere((i) => i.id == id);
        break;
      } catch (_) {}
    }

    await _pantryCol.doc(id).delete();

    // Send household notification
    if (foundItem != null) {
      HouseholdNotificationService.instance.notifyPantryActivity(
        action: 'deleted',
        itemName: foundItem.name,
      );
    }
  }

  int get expiringCount {
    int count = 0;
    for (final list in value.values) {
      count += list.where((item) => item.isExpiringSoon).length;
    }
    return count;
  }

  /// Flat list of available / running-low item names for AI context.
  List<String> get availableNames => value.values
      .expand((list) => list)
      .where((i) =>
          i.status == PantryStatus.available ||
          i.status == PantryStatus.runningLow)
      .map((i) => i.name)
      .where((n) => n.isNotEmpty)
      .toList();
}

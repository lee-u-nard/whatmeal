import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/grocery_item.dart';
import '../models/grocery_list.dart';

class GroceryRepository extends ValueNotifier<Map<String, List<GroceryItem>>> {
  GroceryRepository._() : super({}) {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _uid = user?.uid;
      if (_uid != null) {
        _listenToActiveList();
      } else {
        _sub?.cancel();
        _sub = null;
        value = {};
        _activeList = null;
      }
    });
  }
  static final instance = GroceryRepository._();

  final _firestore = FirebaseFirestore.instance;
  String? _uid;
  GroceryList? _activeList;
  StreamSubscription? _sub;
  String? error;

  GroceryList? get activeList => _activeList;
  Map<String, List<GroceryItem>> get sections => value;

  CollectionReference<Map<String, dynamic>> get _groceryListsCol =>
      _firestore.collection('users').doc(_uid).collection('groceryLists');

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
          'title': 'Shopping List',
          'createdAt': FieldValue.serverTimestamp(),
        });
        listId = doc.id;
        _activeList = GroceryList(id: listId, title: 'Shopping List');
      } else {
        listId = query.docs.first.id;
        _activeList = GroceryList.fromFirestore(query.docs.first);
      }

      if (_uid == null) return; // double check

      _sub = _groceryListsCol.doc(listId).collection('items').snapshots().listen(
        (snapshot) {
          error = null;
          final grouped = <String, List<GroceryItem>>{};
          
          final oldItems = <String, GroceryItem>{};
          for (final list in value.values) {
            for (final item in list) {
              if (item.id != null) oldItems[item.id!] = item;
            }
          }

          for (final doc in snapshot.docs) {
            final item = GroceryItem.fromFirestore(doc);
            final old = oldItems[item.id];
            // Merging on id to preserve local-only fields
            final mergedItem = old != null ? item.copyWith(status: old.status) : item;
            grouped.putIfAbsent(mergedItem.category, () => []).add(mergedItem);
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

  void cycleStatus(String id) async {
    if (_activeList == null || _uid == null) return;
    
    GroceryItem? foundItem;
    for (final list in value.values) {
      try {
        foundItem = list.firstWhere((i) => i.id == id);
        break;
      } catch (_) {}
    }
    if (foundItem == null) return;

    final nextStatus = GroceryStatus.values[(foundItem.status.index + 1) % GroceryStatus.values.length];
    
    await _groceryListsCol
        .doc(_activeList!.id)
        .collection('items')
        .doc(id)
        .update({'checked': nextStatus == GroceryStatus.used});
  }

  Future<void> addItem(String section, GroceryItem item) async {
    if (_uid == null) {
      error = 'Not signed in; grocery item was not saved.';
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
    try {
      final itemToSave = item.copyWith(category: section);
      await _groceryListsCol
          .doc(_activeList!.id)
          .collection('items')
          .add(itemToSave.toFirestore());
      error = null;
    } catch (e) {
      error = 'Failed to save grocery item: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> addMultipleItems(List<GroceryItem> items) async {
    if (_uid == null) {
      error = 'Not signed in; grocery items were not saved.';
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
    try {
      final batch = _firestore.batch();
      final itemsCol = _groceryListsCol.doc(_activeList!.id).collection('items');
      for (final item in items) {
        batch.set(itemsCol.doc(), item.toFirestore());
      }
      await batch.commit();
      error = null;
    } catch (e) {
      error = 'Failed to save grocery items: $e';
      notifyListeners();
      rethrow;
    }
  }

  void clearUsed() async {
    if (_activeList == null || _uid == null) return;
    final itemsCol = _groceryListsCol.doc(_activeList!.id).collection('items');
    final checkedItems = await itemsCol.where('checked', isEqualTo: true).get();
    final batch = _firestore.batch();
    for (final doc in checkedItems.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  void deleteItem(String id) async {
    if (_activeList == null || _uid == null) return;
    await _groceryListsCol
        .doc(_activeList!.id)
        .collection('items')
        .doc(id)
        .delete();
  }

  int get remainingCount {
    int count = 0;
    for (final list in value.values) {
      count += list.where((item) => item.status != GroceryStatus.used).length;
    }
    return count;
  }
}

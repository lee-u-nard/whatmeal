import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/grocery_item.dart';
import '../models/grocery_list.dart';

/// Repository for grocery lists and items scoped to a family group.
/// Supports both auto-generated lists from meal plans and manual additions.
class GroceryRepository extends ChangeNotifier {
  GroceryRepository();

  final _firestore = FirebaseFirestore.instance;
  String? _familyId;
  GroceryList? _activeList;
  Map<String, List<GroceryItem>> _sections = {};

  GroceryList? get activeList => _activeList;
  Map<String, List<GroceryItem>> get sections => _sections;

  void setFamilyId(String? familyId) {
    if (_familyId == familyId) return;
    _familyId = familyId;
    if (familyId != null) {
      _listenToActiveList();
    } else {
      _sections = {};
      _activeList = null;
      notifyListeners();
    }
  }

  CollectionReference<Map<String, dynamic>> get _groceryListsCol =>
      _firestore.collection('families').doc(_familyId).collection('groceryLists');

  Future<void> _listenToActiveList() async {
    // Get or create the active grocery list
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
    } else {
      listId = query.docs.first.id;
      _activeList = GroceryList.fromFirestore(query.docs.first);
    }

    // Listen to items in the active list
    _groceryListsCol.doc(listId).collection('items').snapshots().listen((snapshot) {
      final grouped = <String, List<GroceryItem>>{};
      for (final doc in snapshot.docs) {
        final item = GroceryItem.fromFirestore(doc);
        grouped.putIfAbsent(item.category, () => []).add(item);
      }
      _sections = grouped;
      notifyListeners();
    });
  }

  /// Add a grocery item to the active list.
  Future<void> addItem(GroceryItem item) async {
    if (_familyId == null || _activeList == null) {
      // Ensure an active list exists
      await _listenToActiveList();
      if (_activeList == null) return;
    }
    await _groceryListsCol
        .doc(_activeList!.id)
        .collection('items')
        .add(item.toFirestore());
  }

  /// Toggle the checked state of an item.
  Future<void> toggleChecked(String itemId, bool checked) async {
    if (_activeList == null) return;
    await _groceryListsCol
        .doc(_activeList!.id)
        .collection('items')
        .doc(itemId)
        .update({'checked': checked});
  }

  /// Remove all checked items from the active list.
  Future<void> clearChecked() async {
    if (_activeList == null) return;
    final itemsCol = _groceryListsCol.doc(_activeList!.id).collection('items');
    final checkedItems = await itemsCol.where('checked', isEqualTo: true).get();
    final batch = _firestore.batch();
    for (final doc in checkedItems.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Count of unchecked items across all sections.
  int get remainingCount {
    int count = 0;
    for (final list in _sections.values) {
      count += list.where((item) => !item.checked).length;
    }
    return count;
  }

  /// Add multiple items at once (used when generating a grocery list from a meal plan).
  Future<void> addItemsFromMealPlan(List<GroceryItem> items) async {
    if (_activeList == null) return;
    final batch = _firestore.batch();
    final itemsCol = _groceryListsCol.doc(_activeList!.id).collection('items');
    for (final item in items) {
      batch.set(itemsCol.doc(), item.toFirestore());
    }
    await batch.commit();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/pantry_item.dart';

/// Repository for pantry items scoped to a family group.
/// Backs `PantryPage` with real-time Firestore streams.
class PantryRepository extends ChangeNotifier {
  PantryRepository();

  final _firestore = FirebaseFirestore.instance;
  String? _familyId;
  Map<String, List<PantryItem>> _items = {};

  Map<String, List<PantryItem>> get items => _items;

  /// Set the active family ID and start listening.
  void setFamilyId(String? familyId) {
    if (_familyId == familyId) return;
    _familyId = familyId;
    if (familyId != null) {
      _listenToItems();
    } else {
      _items = {};
      notifyListeners();
    }
  }

  CollectionReference<Map<String, dynamic>> get _pantryCol =>
      _firestore.collection('families').doc(_familyId).collection('pantryItems');

  void _listenToItems() {
    _pantryCol.orderBy('createdAt', descending: true).snapshots().listen((snapshot) {
      final grouped = <String, List<PantryItem>>{};
      for (final doc in snapshot.docs) {
        final item = PantryItem.fromFirestore(doc);
        grouped.putIfAbsent(item.category, () => []).add(item);
      }
      _items = grouped;
      notifyListeners();
    });
  }

  /// Add a new pantry item to Firestore.
  Future<void> addItem(PantryItem item) async {
    if (_familyId == null) return;
    await _pantryCol.add(item.toFirestore());
  }

  /// Delete a pantry item.
  Future<void> deleteItem(String itemId) async {
    if (_familyId == null) return;
    await _pantryCol.doc(itemId).delete();
  }

  /// Update a pantry item.
  Future<void> updateItem(String itemId, Map<String, dynamic> data) async {
    if (_familyId == null) return;
    await _pantryCol.doc(itemId).update(data);
  }

  /// Count of items expiring within 5 days.
  int get expiringCount {
    int count = 0;
    for (final list in _items.values) {
      count += list.where((item) => item.isExpiringSoon).length;
    }
    return count;
  }
}
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/grocery_item.dart';

class GroceryStore {
  GroceryStore(this.firestore);
  final FirebaseFirestore firestore;

  static String normalizedName(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  Future<void> updateManual(DocumentReference<Map<String, dynamic>> list,
      GroceryItem item) async {
    final normalized = normalizedName(item.name);
    final bytes = utf8.encode(normalized);
    if (item.id == null || normalized.isEmpty || bytes.length > 900) {
      throw ArgumentError('Enter a valid grocery item name.');
    }
    final oldRef = list.collection('items').doc(item.id);
    final newRef = list.collection('items').doc('name_${base64Url.encode(bytes)}');
    await firestore.runTransaction((tx) async {
      final parent = await tx.get(list);
      final old = await tx.get(oldRef);
      final destination = await tx.get(newRef);
      if (!parent.exists || !old.exists) throw StateError('Item was removed.');
      if ((old.data()?['sourceMealPaths'] as List?)?.isNotEmpty == true) {
        throw StateError('Edit the source meal to change a meal requirement.');
      }
      if (newRef.path != oldRef.path && destination.exists) {
        throw StateError('An item with this name already exists.');
      }
      tx.set(newRef, item.toFirestore());
      if (newRef.path != oldRef.path) tx.delete(oldRef);
    });
  }

  Future<DocumentReference<Map<String, dynamic>>> initialize(
      CollectionReference<Map<String, dynamic>> lists, String title) async {
    final existing =
        await lists.orderBy('createdAt', descending: true).limit(1).get();
    if (existing.docs.isNotEmpty) return existing.docs.first.reference;
    final ref = lists.doc('default');
    await firestore.runTransaction((transaction) async {
      if (!(await transaction.get(ref)).exists) {
        transaction.set(
            ref, {'title': title, 'createdAt': FieldValue.serverTimestamp()});
      }
    });
    return ref;
  }

  /// Existing random-ID records remain intact. All new app writers use the same
  /// name-based ID. Older app versions can still create random-ID duplicates.
  Future<int> addUnique(DocumentReference<Map<String, dynamic>> list,
      List<GroceryItem> items) async {
    final collection = list.collection('items');
    final existing = (await collection.get())
        .docs
        .map((doc) => normalizedName(doc.data()['name'] as String? ?? ''))
        .toSet();
    final candidates = <String, GroceryItem>{};
    for (final item in items) {
      final name = normalizedName(item.name);
      if (name.isEmpty || existing.contains(name)) continue;
      final bytes = utf8.encode(name);
      if (bytes.length > 900) {
        throw ArgumentError('Grocery item name is too long.');
      }
      candidates.putIfAbsent('name_${base64Url.encode(bytes)}', () => item);
    }
    if (candidates.isEmpty) return 0;
    if (candidates.length > 400) {
      throw ArgumentError('Add at most 400 grocery items at a time.');
    }
    return firestore.runTransaction((transaction) async {
      if (!(await transaction.get(list)).exists) {
        throw StateError('The grocery list was deleted. Refresh and retry.');
      }
      final toCreate = <String, GroceryItem>{};
      for (final entry in candidates.entries) {
        if (!(await transaction.get(collection.doc(entry.key))).exists) {
          toCreate[entry.key] = entry.value;
        }
      }
      for (final entry in toCreate.entries) {
        transaction.set(collection.doc(entry.key), entry.value.toFirestore());
      }
      return toCreate.length;
    });
  }
}

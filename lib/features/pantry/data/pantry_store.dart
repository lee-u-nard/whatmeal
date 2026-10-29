import 'package:cloud_firestore/cloud_firestore.dart';

/// A pantry change and its shared activity succeed or fail together.
class PantryStore {
  PantryStore(this.firestore);
  final FirebaseFirestore firestore;

  Future<void> write({
    required DocumentReference<Map<String, dynamic>> item,
    required String actorUid,
    required String action,
    Map<String, dynamic>? data,
  }) async {
    if (!['added', 'updated', 'deleted'].contains(action)) {
      throw ArgumentError('Unsupported pantry action.');
    }
    final root = item.parent.parent!;
    final event = root.collection('activity').doc();
    await firestore.runTransaction((tx) async {
      final existing = await tx.get(item);
      if (action == 'added' && existing.exists) {
        throw StateError('Ingredient already exists.');
      }
      if (action != 'added' && !existing.exists) {
        throw StateError('Ingredient was removed. Reload the pantry.');
      }
      if (action == 'deleted') {
        tx.delete(item);
      } else if (action == 'added') {
        tx.set(item, data!);
      } else {
        tx.update(item, data!);
      }
      if (root.parent.id == 'families') {
        tx.set(event, {
          'actorUid': actorUid,
          'type': switch (action) {
            'added' => 'pantryItemAdded',
            'deleted' => 'pantryItemDeleted',
            _ => 'pantryItemUpdated'
          },
          'createdAt': FieldValue.serverTimestamp(),
          'relatedPlanId': null,
          'targetId': item.id,
          'includeSelf': false,
        });
      }
    });
  }
}

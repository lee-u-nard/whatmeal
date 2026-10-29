import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/meal/models/meal.dart';

class MealReplacementResult {
  const MealReplacementResult(this.previous, this.successor, this.created);
  final Meal previous;
  final Meal successor;
  final bool created;
}

/// All app replacement writers share this transaction. It does not grant access;
/// Firestore rules must independently authorize the caller.
class MealReplacementStore {
  MealReplacementStore(this.firestore);
  final FirebaseFirestore firestore;

  Future<MealReplacementResult> replace({
    required DocumentReference<Map<String, dynamic>> plan,
    required String oldMealId,
    required Meal replacement,
    MealStatus status = MealStatus.pending,
    String? actorUid,
  }) async {
    if (status == MealStatus.replaced) {
      throw StateError('A replacement must be an active meal.');
    }
    final oldRef = plan.collection('meals').doc(oldMealId);
    final newRef = replacement.id.isEmpty
        ? plan.collection('meals').doc()
        : plan.collection('meals').doc(replacement.id);
    if (newRef.id == oldMealId) {
      throw StateError('The replacement must have a different meal ID.');
    }
    return firestore.runTransaction((transaction) async {
      // Read everything before writes; these reads participate in conflict checks.
      final parent = await transaction.get(plan);
      final previousDoc = await transaction.get(oldRef);
      final successorDoc = await transaction.get(newRef);
      if (!parent.exists || !previousDoc.exists) {
        throw StateError(
            'The meal or its plan was deleted. Refresh and retry.');
      }
      final previous = Meal.fromFirestore(previousDoc);
      if (previous.status == MealStatus.replaced ||
          previous.replacedByMealId?.isNotEmpty == true) {
        if (previous.replacedByMealId == newRef.id &&
            successorDoc.exists &&
            successorDoc.data()?['replacedMealId'] == oldMealId) {
          return MealReplacementResult(
              previous, Meal.fromFirestore(successorDoc), false);
        }
        throw StateError(
            'Another household member already replaced this meal. Refresh the plan.');
      }
      if (successorDoc.exists) {
        throw StateError(
            'That replacement ID is already in use. Please retry.');
      }
      final successor = replacement.copyWith(
        id: newRef.id,
        status: status,
        replacedMealId: oldMealId,
        dayIndex: previous.dayIndex,
        mealType: previous.mealType,
        clearMealType: previous.mealType == null,
      );
      transaction.update(oldRef, {
        'status': MealStatus.replaced.name,
        'accepted': false,
        // Canonicalize absent legacy slots so both atomic links retain null.
        'mealType': previous.mealType,
        'replacedByMealId': newRef.id,
      });
      transaction.set(newRef, successor.toFirestore());
      transaction.update(plan, {'updatedAt': FieldValue.serverTimestamp()});
      if (actorUid != null && plan.path.startsWith('families/')) {
        transaction.set(
            plan.parent.parent!
                .collection('activity')
                .doc('replacement_${plan.id}_${newRef.id}'),
            {
              'actorUid': actorUid,
              'type': 'mealReplaced',
              'createdAt': FieldValue.serverTimestamp(),
              'relatedPlanId': plan.id,
              'targetId': newRef.id,
              'includeSelf': false,
            });
      }
      return MealReplacementResult(previous, successor, true);
    });
  }
}

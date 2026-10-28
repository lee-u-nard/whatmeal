import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/meal/models/meal.dart';

/// Meal status and its household activity either both commit or neither does.
/// Grocery requirements derive from these persisted meal records and pantry stock.
class MealWorkflowStore {
  MealWorkflowStore(this.firestore);
  final FirebaseFirestore firestore;

  Future<bool> setStatus({
    required DocumentReference<Map<String, dynamic>> plan,
    required String mealId,
    required MealStatus status,
    required String actorUid,
  }) async {
    if (status == MealStatus.replaced) {
      throw StateError('Use the coordinated replacement operation.');
    }
    final shared = plan.path.startsWith('families/');
    final event =
        shared ? plan.parent.parent!.collection('activity').doc() : null;
    return firestore.runTransaction((tx) async {
      final parent = await tx.get(plan);
      final child = plan.collection('meals').doc(mealId);
      final current = await tx.get(child);
      if (!parent.exists ||
          !current.exists ||
          current.data()?['status'] == 'replaced') {
        throw StateError('Meal no longer active.');
      }
      if (current.data()?['status'] == status.name) return false;
      tx.update(child,
          {'status': status.name, 'accepted': status == MealStatus.accepted});
      tx.update(plan, {'updatedAt': FieldValue.serverTimestamp()});
      if (event != null) {
        final type = switch (status) {
          MealStatus.accepted => 'mealAccepted',
          MealStatus.completed => 'mealCompleted',
          MealStatus.notCompleted => 'mealNotCompleted',
          _ => 'general',
        };
        tx.set(event, {
          'actorUid': actorUid,
          'type': type,
          'createdAt': FieldValue.serverTimestamp(),
          'relatedPlanId': plan.id,
          'targetId': mealId,
          'includeSelf': false
        });
      }
      return true;
    });
  }
}

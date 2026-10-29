import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_notification.dart';

/// Shared feed + private receipts. Does not fan out into other users' trees.
class HouseholdActivityStore {
  HouseholdActivityStore(
    this.firestore, {
    Stream<QuerySnapshot<Map<String, dynamic>>> Function(
            Query<Map<String, dynamic>> query)?
        watchReceipts,
  }) : _watchReceipts = watchReceipts;
  final FirebaseFirestore firestore;
  final Stream<QuerySnapshot<Map<String, dynamic>>> Function(
      Query<Map<String, dynamic>> query)? _watchReceipts;
  Future<String> publish(
      {required String familyId,
      required String actorUid,
      required AppNotificationType type,
      String? relatedPlanId,
      String? targetId,
      bool includeSelf = true,
      String? operationId}) async {
    final ref =
        firestore.collection('families/$familyId/activity').doc(operationId);
    await firestore.runTransaction((tx) async {
      final existing = await tx.get(ref);
      if (existing.exists) {
        final data = existing.data()!;
        if (data['actorUid'] != actorUid ||
            data['type'] != type.name ||
            data['relatedPlanId'] != relatedPlanId ||
            data['targetId'] != targetId) {
          throw StateError('Activity operation ID is already in use.');
        }
        return;
      }
      tx.set(ref, {
        'actorUid': actorUid,
        'type': type.name,
        'createdAt': FieldValue.serverTimestamp(),
        'relatedPlanId': relatedPlanId,
        'targetId': targetId,
        'includeSelf': includeSelf
      });
    });
    return ref.id;
  }

  String receiptId(String familyId, String eventId) =>
      'household:$familyId:$eventId';
  Future<void> markRead(String uid, String id) =>
      firestore.doc('users/$uid/notificationReceipts/$id').set({
        'read': true,
        'dismissed': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
  Stream<List<AppNotification>> watch(
      {required String uid,
      required String familyId,
      required DateTime joinedAt}) {
    late StreamController<List<AppNotification>> output;
    StreamSubscription? activities, receipts;
    List<QueryDocumentSnapshot<Map<String, dynamic>>> events = [];
    Map<String, Map<String, dynamic>> seen = {};
    var stopped = false;
    var receiptsReady = false;
    var activityReady = false;
    void fail(Object error, StackTrace stack) {
      if (stopped) return;
      stopped = true;
      output.addError(error, stack);
      unawaited(activities?.cancel());
      unawaited(receipts?.cancel());
      unawaited(output.close());
    }

    void emit() {
      if (stopped || !receiptsReady || !activityReady) return;
      final result = <AppNotification>[];
      for (final doc in events) {
        final data = doc.data();
        final date = (data['createdAt'] as Timestamp?)?.toDate();
        if (date == null || date.isBefore(joinedAt)) continue;
        if (data['actorUid'] == uid && data['includeSelf'] == false) continue;
        final id = receiptId(familyId, doc.id);
        final receipt = seen[id];
        if (receipt?['dismissed'] == true) continue;
        final type = AppNotificationType.values
                .where((type) => type.name == data['type'])
                .firstOrNull ??
            AppNotificationType.general;
        result.add(AppNotification(
            id: id,
            title: type.displayName,
            body: switch (type) {
              AppNotificationType.mealAccepted =>
                'A household member accepted a meal.',
              AppNotificationType.mealCompleted =>
                'A household member completed a meal.',
              AppNotificationType.mealNotCompleted =>
                'A household member marked a meal not completed.',
              AppNotificationType.mealReplaced =>
                'A household member replaced a meal.',
              AppNotificationType.pantryItemAdded =>
                'A household member added a pantry ingredient.',
              AppNotificationType.pantryItemUpdated =>
                'A household member updated pantry stock.',
              AppNotificationType.pantryItemDeleted =>
                'A household member removed a pantry ingredient.',
              AppNotificationType.aiProviderChanged =>
                'A household member changed their AI provider.',
              _ =>
                'A household member updated ${type.displayName.toLowerCase()}.',
            },
            navigationRoute: data['relatedPlanId'] != null
                ? '/saved-meal-plans'
                : type.name.startsWith('pantry')
                    ? '/pantry'
                    : type.name.startsWith('grocery')
                        ? '/grocery'
                        : type.name.startsWith('aiProvider')
                            ? '/ai-settings'
                            : '/family-space',
            navigationParameters: data['relatedPlanId'] is String &&
                    data['targetId'] is String &&
                    type.name.startsWith('meal')
                ? {
                    'planPath':
                        'families/$familyId/mealPlans/${data['relatedPlanId']}',
                    'mealId': data['targetId']
                  }
                : null,
            type: type,
            createdAt: date,
            read: receipt?['read'] == true,
            actorUid: data['actorUid'] as String?,
            relatedPlanId: data['relatedPlanId'] as String?,
            targetId: data['targetId'] as String?));
      }
      output.add(result);
    }

    output = StreamController<List<AppNotification>>(onListen: () {
      activities = firestore
          .collection('families/$familyId/activity')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .listen((snapshot) {
        events = snapshot.docs;
        activityReady = true;
        emit();
      }, onError: (Object error, StackTrace stack) {
        fail(error, stack);
      });
      if (stopped) return;
      final receiptQuery =
          firestore.collection('users/$uid/notificationReceipts');
      receipts =
          (_watchReceipts?.call(receiptQuery) ?? receiptQuery.snapshots())
              .listen((snapshot) {
        seen = {for (final doc in snapshot.docs) doc.id: doc.data()};
        receiptsReady = true;
        emit();
      }, onError: (Object error, StackTrace stack) {
        fail(error, stack);
      });
    }, onCancel: () async {
      stopped = true;
      await activities?.cancel();
      await receipts?.cancel();
    });
    return output.stream;
  }
}

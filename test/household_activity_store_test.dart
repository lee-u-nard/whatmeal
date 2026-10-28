import 'dart:async';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/models/app_notification.dart';
import 'package:whatmeal/core/services/household_activity_store.dart';

void main() {
  test('shared event retries are idempotent and do not write private fan-out',
      () async {
    final db = FakeFirebaseFirestore();
    final store = HouseholdActivityStore(db);
    for (var i = 0; i < 2; i++) {
      await store.publish(
          familyId: 'f',
          actorUid: 'owner',
          type: AppNotificationType.mealReplaced,
          operationId: 'operation',
          targetId: 'meal');
    }
    expect((await db.collection('families/f/activity').get()).size, 1);
    expect((await db.collection('users').get()).size, 0);
    await expectLater(
        store.publish(
            familyId: 'f',
            actorUid: 'other',
            type: AppNotificationType.general,
            operationId: 'operation'),
        throwsStateError);
  });
  test('feed uses own receipts; cancellation prevents stale household events',
      () async {
    final db = FakeFirebaseFirestore();
    final store = HouseholdActivityStore(db);
    await store.publish(
        familyId: 'f',
        actorUid: 'owner',
        type: AppNotificationType.general,
        operationId: 'event',
        includeSelf: false);
    final queue = StreamIterator(
        store.watch(uid: 'viewer', familyId: 'f', joinedAt: DateTime(2000)));
    Future<List<AppNotification>> nextWhere(
        bool Function(List<AppNotification>) accept) async {
      while (await queue.moveNext().timeout(const Duration(seconds: 5))) {
        if (accept(queue.current)) return queue.current;
      }
      throw StateError('Feed closed early');
    }

    final initial = await nextWhere((events) => events.isNotEmpty);
    expect(initial.single.read, isFalse);
    await store.markRead('viewer', initial.single.id);
    expect(
        (await nextWhere((events) => events.isNotEmpty && events.single.read))
            .single
            .read,
        isTrue);
    expect((await db.collection('users/owner/notificationReceipts').get()).size,
        0);
    await queue.cancel();
    // A new account creates a new feed with its own receipts.
    final other = await store
        .watch(uid: 'other', familyId: 'f', joinedAt: DateTime(2000))
        .firstWhere((events) => events.isNotEmpty)
        .timeout(const Duration(seconds: 5));
    expect(other.single.read, isFalse);
    final futureMember = await store
        .watch(uid: 'new', familyId: 'f', joinedAt: DateTime(2100))
        .first;
    expect(futureMember, isEmpty);
  });
}

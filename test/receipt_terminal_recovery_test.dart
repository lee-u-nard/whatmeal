import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/models/app_notification.dart';
import 'package:whatmeal/core/services/household_activity_store.dart';

void main() {
  test(
      'receipt terminal failure never emits a healthy empty feed and releases both sources',
      () async {
    final db = FakeFirebaseFirestore();
    await HouseholdActivityStore(db).publish(
        familyId: 'home',
        actorUid: 'owner',
        type: AppNotificationType.general,
        operationId: 'event');
    final feeds = <StreamController<QuerySnapshot<Map<String, dynamic>>>>[];
    final store = HouseholdActivityStore(db, watchReceipts: (q) {
      final feed =
          StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast(
              sync: true);
      feeds.add(feed);
      return feed.stream;
    });
    final events = <List<AppNotification>>[];
    final errors = <Object>[];
    var closed = false;
    final sub = store
        .watch(uid: 'a', familyId: 'home', joinedAt: DateTime(2000))
        .listen(events.add, onError: errors.add, onDone: () => closed = true);
    addTearDown(() async {
      await sub.cancel();
      for (final c in feeds) {
        await c.close();
      }
    });
    feeds.single.add(await db.collection('users/a/notificationReceipts').get());
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(events.last.single.id, 'household:home:event');
    final count = events.length;
    feeds.single.addError(StateError('private receipt failure'));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(errors.length, 1);
    expect(events.length, count,
        reason:
            'A failed receipt source must not look like a successful empty inbox');
    expect(closed, true);
    expect(feeds.single.hasListener, false);
    final recovered = await HouseholdActivityStore(db)
        .watch(uid: 'a', familyId: 'home', joinedAt: DateTime(2000))
        .first;
    expect(recovered.single.id, 'household:home:event');
    expect(recovered.single.read, false);
  });
}

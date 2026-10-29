import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/models/app_notification.dart';
import 'package:whatmeal/core/services/notification_service.dart';
import 'package:whatmeal/features/family/models/family_space.dart';
import 'package:whatmeal/features/notifications/pages/notifications_page.dart';

class HouseholdState extends ValueNotifier<FamilySpace?> {
  HouseholdState() : super(null);
  bool get isObserved => hasListeners;
}

class Fixture {
  final db = FakeFirebaseFirestore();
  final ids = StreamController<String?>.broadcast(sync: true);
  final household = HouseholdState();
  final personal = <StreamController<QuerySnapshot<Map<String, dynamic>>>>[];
  final shared = <StreamController<List<AppNotification>>>[];
  late final service = NotificationService(
    firestore: db,
    userIds: ids.stream,
    household: household,
    watchPersonal: (_) {
      final feed =
          StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast(
              sync: true);
      personal.add(feed);
      return feed.stream;
    },
    watchShared: (uid, familyId, joinedAt) {
      final feed =
          StreamController<List<AppNotification>>.broadcast(sync: true);
      shared.add(feed);
      return feed.stream;
    },
  );

  void join(String uid) {
    household.value =
        FamilySpace(id: 'family', name: 'Local', inviteCode: '', members: [
      SharedSpaceMember(
          id: uid,
          name: 'Local',
          email: 'local@example.test',
          role: FamilyRole.member,
          joinedAt: DateTime(2026)),
    ]);
  }

  Future<void> close() async {
    service.dispose();
    household.dispose();
    await ids.close();
    for (final feed in [...personal, ...shared]) {
      await feed.close();
    }
  }
}

void main() {
  testWidgets(
      'retained inbox callbacks reject old-account read and route actions',
      (tester) async {
    final f = Fixture();
    final service = f.service;
    addTearDown(f.close);
    f.ids.add('a');
    await tester
        .pumpWidget(MaterialApp(home: NotificationsPage(service: service)));
    final oldInbox =
        tester.widget<NotificationInbox>(find.byType(NotificationInbox));
    f.ids.add('b');
    await oldInbox.onOpen(AppNotification(
        id: 'old',
        title: 'Old',
        body: 'Old',
        type: AppNotificationType.general,
        createdAt: DateTime(2026),
        read: true));
    await expectLater(oldInbox.onMarkAllRead(), throwsStateError);
    expect(tester.takeException(), isNull);
    expect((await f.db.collection('users/b/notifications').get()).size, 0);
    await tester.pumpWidget(const SizedBox());
  });
  test('queued routes and obsolete read actions cannot cross A B A sessions',
      () async {
    final f = Fixture();
    final service = f.service;
    addTearDown(f.close);
    for (final uid in ['a', 'b']) {
      await f.db.doc('users/$uid/notifications/same-id').set(AppNotification(
            id: 'same-id',
            title: 'Local',
            body: 'Local event',
            type: AppNotificationType.general,
            createdAt: DateTime(2026),
          ).toFirestore());
    }
    f.ids.add('a');
    final oldSession = service.sessionVersion;
    service.pendingNavigation.value = {'route': '/pantry'};
    f.ids.add('b');
    expect(service.pendingNavigation.value, isNull);
    for (final uid in ['b', 'a']) {
      if (uid == 'a') f.ids.add(uid);
      await expectLater(
          service.markRead('same-id', expectedSession: oldSession),
          throwsStateError);
      await expectLater(
          service.markAllRead(expectedSession: oldSession), throwsStateError);
      expect(
          (await f.db.doc('users/$uid/notifications/same-id').get())
              .data()?['read'],
          false);
    }
    await service.markRead('same-id', expectedSession: service.sessionVersion);
    expect(
        (await f.db.doc('users/a/notifications/same-id').get()).data()?['read'],
        true);
    expect(
        (await f.db.doc('users/b/notifications/same-id').get()).data()?['read'],
        false);
  });

  test(
      'household departure invalidates actions without interrupting personal feed',
      () async {
    final f = Fixture();
    final service = f.service;
    addTearDown(f.close);
    f.ids.add('a');
    f.join('a');
    final householdSession = service.sessionVersion;
    f.shared.single.add([
      AppNotification(
          id: 'household:family:event',
          title: 'Shared',
          body: 'Local',
          type: AppNotificationType.general,
          createdAt: DateTime(2026))
    ]);
    expect(service.unreadCount, 1);
    service.pendingNavigation.value = {'route': '/family-space'};
    f.household.value = null;
    expect(service.sessionVersion, isNot(householdSession));
    expect(service.pendingNavigation.value, isNull);
    expect(service.value, isEmpty);
    expect(f.shared.single.hasListener, false);
    expect(f.personal.single.hasListener, true);
    f.personal.single.add(await f.db.collection('users/a/notifications').get());
    expect(service.isLoading, false);
    await expectLater(
        service.markRead('household:family:event',
            expectedSession: householdSession),
        throwsStateError);
    expect(
        (await f.db.collection('users/a/notificationReceipts').get()).size, 0);
  });

  test('account reset publishes loading and cleared errors atomically',
      () async {
    final f = Fixture();
    final service = f.service;
    addTearDown(f.close);
    f.ids.add('a');
    f.personal.single.addError(StateError('private account failure'));
    expect(service.error, isNotNull);
    final publications = <({String? error, bool loading})>[];
    service.addListener(() =>
        publications.add((error: service.error, loading: service.isLoading)));
    f.ids.add('b');
    expect(publications, isNotEmpty);
    expect(publications.every((state) => state.error == null && state.loading),
        isTrue,
        reason: 'B must not observe A failure or a false empty inbox');
  });

  test(
      'terminal feeds retry without changing session; healthy feed cannot hide failure',
      () async {
    final f = Fixture();
    final service = f.service;
    addTearDown(f.close);
    f.ids.add('a');
    f.join('a');
    final session = service.sessionVersion;
    f.personal.single.addError(StateError('private personal failure'));
    f.shared.single.add([]);
    expect(service.error, 'Notifications could not be loaded.');
    service.retry();
    expect(service.sessionVersion, session,
        reason:
            'Retry is not an account change and must not invalidate navigation');
    expect(f.personal.length, 2);
    expect(f.shared.length, 2);
    f.personal.last.add(await f.db.collection('users/a/notifications').get());
    f.shared.last.addError(StateError('private shared failure'));
    expect(service.error, 'Household notifications could not be loaded.');
    expect(service.unreadCount, 0);
    service.retry();
    f.personal.last.add(await f.db.collection('users/a/notifications').get());
    f.shared.last.add([]);
    expect(service.error, isNull);
    expect(service.isLoading, false);
  });

  test('disposal releases account and household feeds', () async {
    final f = Fixture();
    final service = f.service;
    f.ids.add('a');
    f.join('a');
    service.dispose();
    expect(f.ids.hasListener, false);
    expect(f.personal.single.hasListener, false);
    expect(f.shared.single.hasListener, false);
    expect(f.household.isObserved, false);
    f.household.dispose();
    await f.ids.close();
    for (final feed in [...f.personal, ...f.shared]) {
      await feed.close();
    }
  });
}

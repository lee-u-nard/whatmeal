import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/models/family.dart';
import 'package:whatmeal/core/services/family_service.dart';
import 'package:whatmeal/features/auth/models/user_model.dart';
import 'package:whatmeal/features/family/data/family_repository.dart';
import 'package:whatmeal/features/family/pages/family_space_page.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 25));
UserModel user(String id) =>
    UserModel(id: id, name: id, email: '$id@example.test');

class ControlledFamilyService extends FamilyService {
  ControlledFamilyService(this.db, {this.layer}) : super(firestore: db);
  final FakeFirebaseFirestore db;
  final String? layer;
  final indexes = <StreamController<String?>>[];
  final families = <StreamController<Family?>>[];
  final members = <StreamController<QuerySnapshot<Map<String, dynamic>>>>[];
  Completer<String>? invitation;
  Completer<String>? creation;
  Completer<void>? departure;
  int orphanCalls = 0;
  @override
  Future<String> createFamily(
          {required String name,
          required String uid,
          required String displayName}) =>
      creation?.future ??
      super.createFamily(name: name, uid: uid, displayName: displayName);
  @override
  Stream<String?> membershipStream(String uid) {
    if (layer != 'index') return super.membershipStream(uid);
    final c = StreamController<String?>.broadcast(sync: true);
    indexes.add(c);
    return c.stream;
  }

  @override
  Stream<Family?> familyStream(String id) {
    if (layer != 'family') return super.familyStream(id);
    final c = StreamController<Family?>.broadcast(sync: true);
    families.add(c);
    return c.stream;
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> membersStream(String id) {
    if (layer != 'members') return super.membersStream(id);
    final c = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast(
        sync: true);
    members.add(c);
    return c.stream;
  }

  @override
  Future<String> createInvitation(
          {required String familyId,
          required String uid,
          String role = 'member',
          String? recipientUid,
          Duration lifetime = const Duration(hours: 48)}) =>
      invitation?.future ??
      super.createInvitation(
          familyId: familyId,
          uid: uid,
          role: role,
          recipientUid: recipientUid,
          lifetime: lifetime);
  @override
  Future<void> leaveFamily({required String familyId, required String uid}) =>
      departure?.future ?? super.leaveFamily(familyId: familyId, uid: uid);
  @override
  Future<void> clearOrphanedMembership({required String uid}) async {
    orphanCalls++;
  }

  Future<void> emit(String id) async {
    if (layer == 'index') indexes.last.add(id);
    if (layer == 'family') {
      families.last
          .add(Family.fromFirestore(await db.doc('families/$id').get()));
    }
    if (layer == 'members') {
      members.last.add(await db.collection('families/$id/members').get());
    }
    await settle();
  }

  void fail() {
    if (layer == 'index') {
      indexes.last.addError(StateError('private synthetic detail'));
    }
    if (layer == 'family') {
      families.last.addError(StateError('private synthetic detail'));
    }
    if (layer == 'members') {
      members.last.addError(StateError('private synthetic detail'));
    }
  }

  Future<void> close() async {
    for (final c in [...indexes, ...families, ...members]) {
      await c.close();
    }
  }
}

void main() {
  testWidgets(
      'dismissed creation sheet cannot pop a new accounts screen on late completion',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final service = ControlledFamilyService(db);
    final ids = StreamController<String?>.broadcast(sync: true);
    final account = ValueNotifier<UserModel?>(user('a'));
    final repo = FamilyRepository(
        firestore: db, authIds: ids.stream, account: account, service: service);
    addTearDown(() async {
      repo.dispose();
      account.dispose();
      await ids.close();
    });
    ids.add('a');
    await tester
        .pumpWidget(MaterialApp(home: FamilySpacePage(repository: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Space'));
    await tester.pumpAndSettle();
    service.creation = Completer<String>();
    await tester.ensureVisible(find.descendant(
        of: find.byType(BottomSheet), matching: find.text('Create Space')));
    await tester.tap(find.descendant(
        of: find.byType(BottomSheet), matching: find.text('Create Space')));
    await tester.pump();
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Updating household. Waiting for confirmation…'),
        findsOneWidget);
    ids.add('b');
    account.value = user('b');
    await tester.pumpAndSettle();
    service.creation!.complete('old-created-household');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(FamilySpacePage), findsOneWidget);
    expect(repo.currentUid, 'b');
    await tester.pumpWidget(const SizedBox());
  });
  for (final layer in ['index', 'family', 'members']) {
    test(
        '$layer terminal failure publishes a safe unavailable state and retry reopens only current feeds',
        () async {
      final db = FakeFirebaseFirestore();
      final service = ControlledFamilyService(db, layer: layer);
      final id =
          await service.createFamily(name: 'Home', uid: 'a', displayName: 'A');
      final ids = StreamController<String?>.broadcast(sync: true);
      final account = ValueNotifier<UserModel?>(user('a'));
      final repo = FamilyRepository(
          firestore: db,
          authIds: ids.stream,
          account: account,
          service: service);
      addTearDown(() async {
        repo.dispose();
        account.dispose();
        await ids.close();
        await service.close();
      });
      ids.add('a');
      await settle();
      await service.emit(id);
      expect(repo.value?.id, id);
      final observedErrors = <String?>[];
      repo.addListener(() {
        if (repo.value == null) observedErrors.add(repo.error);
      });
      service.fail();
      expect(observedErrors, isNotEmpty);
      expect(observedErrors.every((e) => e != null), true,
          reason:
              'Unavailable household must not first appear as a healthy empty household');
      expect(repo.error, isNot(contains('private synthetic')));
      repo.retry();
      await settle();
      await service.emit(id);
      expect(repo.value?.id, id);
      expect(repo.error, isNull);
      expect(
          service.indexes.length +
              service.families.length +
              service.members.length,
          2);
      ids.add('b');
      account.value = user('b');
      await settle();
      expect(repo.value, isNull);
    });
  }

  test('delayed invitation result cannot refill token after native-style A B A',
      () async {
    final db = FakeFirebaseFirestore();
    final service = ControlledFamilyService(db);
    final id =
        await service.createFamily(name: 'Home', uid: 'a', displayName: 'A');
    final ids = StreamController<String?>.broadcast(sync: true);
    final account = ValueNotifier<UserModel?>(user('a'));
    final repo = FamilyRepository(
        firestore: db, authIds: ids.stream, account: account, service: service);
    addTearDown(() async {
      repo.dispose();
      account.dispose();
      await ids.close();
    });
    ids.add('a');
    await settle();
    service.invitation = Completer<String>();
    final pending = repo.regenerateInviteKey();
    ids.add('b');
    account.value = user('b');
    await settle();
    ids.add('a');
    account.value = user('a');
    await settle();
    expect(repo.value?.id, id);
    service.invitation!.complete('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
    expect(await pending, false);
    expect(repo.activeInvitationToken, isNull);
  });

  test(
      'late departure denial cannot start orphan cleanup under another account',
      () async {
    final db = FakeFirebaseFirestore();
    final service = ControlledFamilyService(db);
    final id =
        await service.createFamily(name: 'Home', uid: 'a', displayName: 'A');
    await db.doc('families/$id/members/a').update({'role': 'member'});
    final ids = StreamController<String?>.broadcast(sync: true);
    final account = ValueNotifier<UserModel?>(user('a'));
    final repo = FamilyRepository(
        firestore: db, authIds: ids.stream, account: account, service: service);
    addTearDown(() async {
      repo.dispose();
      account.dispose();
      await ids.close();
    });
    ids.add('a');
    await settle();
    service.departure = Completer<void>();
    final pending = repo.leaveSpace();
    ids.add('b');
    account.value = user('b');
    await settle();
    service.departure!.completeError(FirebaseException(
        plugin: 'cloud_firestore', code: 'permission-denied'));
    expect(await pending, false);
    expect(service.orphanCalls, 0);
    expect(repo.error, isNull);
  });

  testWidgets(
      'old archive confirmation cannot archive the new accounts household',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final service = FamilyService(firestore: db);
    final first =
        await service.createFamily(name: 'First', uid: 'a', displayName: 'A');
    final second =
        await service.createFamily(name: 'Second', uid: 'b', displayName: 'B');
    final ids = StreamController<String?>.broadcast(sync: true);
    final account = ValueNotifier<UserModel?>(user('a'));
    final repo =
        FamilyRepository(firestore: db, authIds: ids.stream, account: account);
    addTearDown(() async {
      repo.dispose();
      account.dispose();
      await ids.close();
    });
    ids.add('a');
    await tester
        .pumpWidget(MaterialApp(home: FamilySpacePage(repository: repo)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Archive Household Space'), 400);
    await tester.tap(find.text('Archive Household Space'));
    await tester.pumpAndSettle();
    ids.add('b');
    account.value = user('b');
    await tester.pumpAndSettle();
    expect(repo.value?.id, second);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Archive Household'));
    await tester.pumpAndSettle();
    expect((await db.doc('families/$first').get()).data()?['state'], 'active');
    expect((await db.doc('families/$second').get()).data()?['state'], 'active');
    await tester.pumpWidget(const SizedBox());
  });
}

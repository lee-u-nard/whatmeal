import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/services/family_service.dart';
import 'package:whatmeal/features/auth/models/user_model.dart';
import 'package:whatmeal/features/family/data/family_repository.dart';
import 'package:whatmeal/features/family/models/household_action_error.dart';
import 'package:whatmeal/features/family/pages/family_space_page.dart';

class DepartureGate extends FamilyService {
  DepartureGate(FirebaseFirestore db) : super(firestore: db);
  Completer<void>? gate;
  int calls = 0;
  final index = StreamController<String?>.broadcast(sync: true);
  bool controlledIndex = false;
  @override
  Stream<String?> membershipStream(String uid) =>
      controlledIndex ? index.stream : super.membershipStream(uid);
  @override
  Future<void> removeMember(
      {required String familyId, required String memberUid}) {
    calls++;
    return gate?.future ??
        super.removeMember(familyId: familyId, memberUid: memberUid);
  }

  @override
  Future<void> leaveFamily({required String familyId, required String uid}) {
    calls++;
    return gate?.future ?? super.leaveFamily(familyId: familyId, uid: uid);
  }
}

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('member departure actions fit 320px at text scale $scale',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final db = FakeFirebaseFirestore();
      final service = FamilyService(firestore: db);
      final family = await service.createFamily(
          name: 'Local home', uid: 'owner', displayName: 'Owner');
      final token =
          await service.createInvitation(familyId: family, uid: 'owner');
      await service.joinFamily(
          inviteCode: token, uid: 'member', displayName: 'Member');
      final ids = StreamController<String?>.broadcast(sync: true);
      final account = ValueNotifier<UserModel?>(const UserModel(
          id: 'member', name: 'Member', email: 'member@example.test'));
      final repo = FamilyRepository(
          firestore: db, authIds: ids.stream, account: account);
      addTearDown(() async {
        repo.dispose();
        account.dispose();
        await ids.close();
      });
      ids.add('member');
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  padding: const EdgeInsets.only(bottom: 24)),
              child: child!),
          home: FamilySpacePage(repository: repo)));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Leave Household Space'), 160);
      await tester.ensureVisible(find.text('Leave Household Space'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Leave Household Space').hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final leave in [false, true]) {
    testWidgets(
        '${leave ? "departure" : "removal"} has pending feedback, safe failure and ordinary retry',
        (tester) async {
      final db = FakeFirebaseFirestore();
      final service = DepartureGate(db);
      final family = await service.createFamily(
          name: 'Local home', uid: 'owner', displayName: 'Owner');
      final invitation =
          await service.createInvitation(familyId: family, uid: 'owner');
      await service.joinFamily(
          inviteCode: invitation, uid: 'member', displayName: 'Member');
      final uid = leave ? 'member' : 'owner';
      final account = ValueNotifier<UserModel?>(
          UserModel(id: uid, name: uid, email: '$uid@example.test'));
      final ids = StreamController<String?>.broadcast(sync: true);
      final repo = FamilyRepository(
          firestore: db,
          authIds: ids.stream,
          account: account,
          service: service);
      addTearDown(() async {
        repo.dispose();
        account.dispose();
        await ids.close();
        await service.index.close();
      });
      ids.add(uid);
      await tester
          .pumpWidget(MaterialApp(home: FamilySpacePage(repository: repo)));
      await tester.pumpAndSettle();
      service.gate = Completer<void>();
      final pending = leave ? repo.leaveSpace() : repo.removeMember('member');
      await tester.pump();
      expect(find.text('Updating household. Waiting for confirmation…'),
          findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(await repo.removeMember('member'), isFalse);
      expect(service.calls, 1);
      expect(find.textContaining('You have left'), findsNothing);
      service.gate!.completeError(FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
          message: 'private-token'));
      expect(await pending, isFalse);
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('household service is unavailable'),
          findsOneWidget);
      expect(find.textContaining('private-token'), findsNothing);
      expect((await db.doc('families/$family/members/member').get()).exists,
          isTrue);
      service.gate = null;
      expect(await (leave ? repo.leaveSpace() : repo.removeMember('member')),
          isTrue);
      await tester.pumpAndSettle();
      expect((await db.doc('membershipIndex/member').get()).exists, isFalse);
      expect((await db.doc('families/$family/members/owner').get()).exists,
          isTrue);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final code in ['unavailable', 'permission-denied']) {
    test('terminal index $code uses household-specific feedback and retry',
        () async {
      final db = FakeFirebaseFirestore();
      final service = DepartureGate(db)..controlledIndex = true;
      final ids = StreamController<String?>.broadcast(sync: true);
      final account = ValueNotifier<UserModel?>(const UserModel(
          id: 'local', name: 'Local', email: 'local@example.test'));
      final repo = FamilyRepository(
          firestore: db,
          authIds: ids.stream,
          account: account,
          service: service);
      ids.add('local');
      await Future<void>.delayed(Duration.zero);
      final failure = FirebaseException(
          plugin: 'cloud_firestore', code: code, message: 'private-token');
      service.index.addError(failure);
      await Future<void>.delayed(Duration.zero);
      expect(repo.error, householdActionError(failure));
      expect(repo.error, isNot(contains('plan')));
      expect(repo.error, isNot(contains('private-token')));
      repo.retry();
      await Future<void>.delayed(Duration.zero);
      service.index.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(repo.error, isNull);
      repo.dispose();
      account.dispose();
      await ids.close();
      await service.index.close();
    });
  }
}

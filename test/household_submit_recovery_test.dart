import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/services/family_service.dart';
import 'package:whatmeal/features/auth/models/user_model.dart';
import 'package:whatmeal/features/family/data/family_repository.dart';
import 'package:whatmeal/features/family/pages/family_space_page.dart';

class SubmitGate extends FamilyService {
  SubmitGate(FakeFirebaseFirestore db) : super(firestore: db);
  Completer<String>? pending;
  int calls = 0;
  @override
  Future<String> createFamily(
      {required String name,
      required String uid,
      required String displayName}) {
    calls++;
    return pending?.future ??
        super.createFamily(name: name, uid: uid, displayName: displayName);
  }

  @override
  Future<String> joinFamily(
      {required String inviteCode,
      required String uid,
      required String displayName}) {
    calls++;
    return pending?.future ??
        super.joinFamily(
            inviteCode: inviteCode, uid: uid, displayName: displayName);
  }
}

void main() {
  for (final create in [true, false]) {
    final kind = create ? 'create' : 'join';
    late FakeFirebaseFirestore db;
    late SubmitGate service;
    late FamilyRepository repo;
    late StreamController<String?> ids;
    late ValueNotifier<UserModel?> account;
    late String draft;
    Future<void> open(WidgetTester tester) async {
      db = FakeFirebaseFirestore();
      service = SubmitGate(db);
      ids = StreamController<String?>.broadcast(sync: true);
      account = ValueNotifier(const UserModel(
          id: 'local', name: 'Local', email: 'local@example.test'));
      repo = FamilyRepository(
          firestore: db,
          authIds: ids.stream,
          account: account,
          service: service);
      addTearDown(() async {
        repo.dispose();
        account.dispose();
        await ids.close();
      });
      draft = 'Recovery household';
      if (!create) {
        final owner = FamilyService(firestore: db);
        final family = await owner.createFamily(
            name: 'Inviting household', uid: 'owner', displayName: 'Owner');
        draft = await owner.createInvitation(familyId: family, uid: 'owner');
      }
      ids.add('local');
      await tester
          .pumpWidget(MaterialApp(home: FamilySpacePage(repository: repo)));
      await tester.pumpAndSettle();
      await tester
          .ensureVisible(find.text(create ? 'Create Space' : 'Join with Key'));
      await tester.tap(find.text(create ? 'Create Space' : 'Join with Key'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find
              .descendant(
                  of: find.byType(BottomSheet),
                  matching: find.byType(TextField))
              .first,
          draft);
    }

    Finder button() => find.descendant(
        of: find.byType(BottomSheet), matching: find.byType(ElevatedButton));
    Future<void> submit(WidgetTester tester) async {
      await tester.ensureVisible(button());
      await tester.tap(button());
      await tester.pump();
    }

    testWidgets('$kind failure retains draft and retry commits once',
        (tester) async {
      await open(tester);
      service.pending = Completer<String>();
      await submit(tester);
      service.pending!.completeError(FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
          message: 'private endpoint detail'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text(draft), findsOneWidget);
      expect(find.textContaining('private endpoint'), findsNothing);
      expect(tester.widget<ElevatedButton>(button()).onPressed, isNotNull);
      expect(
          find.descendant(
              of: find.byType(BottomSheet),
              matching: find.textContaining('Check your connection')),
          findsOneWidget);
      service.pending = null;
      await submit(tester);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(service.calls, 2);
      expect((await db.doc('membershipIndex/local').get()).exists, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        '$kind pending submit is disabled; dismissed failure cannot navigate',
        (tester) async {
      await open(tester);
      service.pending = Completer<String>();
      await submit(tester);
      expect(tester.widget<ElevatedButton>(button()).onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(button());
      expect(service.calls, 1);
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Updating household. Waiting for confirmation…'),
          findsOneWidget);
      service.pending!.completeError(StateError('private endpoint detail'));
      await tester.pumpAndSettle();
      expect(find.byType(FamilySpacePage), findsOneWidget);
      expect(find.textContaining('private endpoint'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        '$kind pending sheet hides its draft across account switch and ABA',
        (tester) async {
      await open(tester);
      service.pending = Completer<String>();
      await submit(tester);
      ids.add('other');
      account.value = const UserModel(
          id: 'other', name: 'Other', email: 'other@example.test');
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text(draft), findsNothing);
      expect(find.textContaining('Your account or household changed'),
          findsOneWidget);
      service.pending!.completeError(StateError('private endpoint detail'));
      await tester.pumpAndSettle();
      ids.add('local');
      account.value = const UserModel(
          id: 'local', name: 'Local', email: 'local@example.test');
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(find.textContaining('private endpoint'), findsNothing);
      expect(find.byType(FamilySpacePage), findsOneWidget);
      expect(service.calls, 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$kind empty and invalid input is visible without dispatch',
        (tester) async {
      await open(tester);
      final field = find
          .descendant(
              of: find.byType(BottomSheet), matching: find.byType(TextField))
          .first;
      await tester.enterText(field, '   ');
      await submit(tester);
      await tester.pumpAndSettle();
      expect(
          tester
              .state<FormFieldState<String>>(find.byType(TextFormField))
              .errorText,
          isNotNull);
      expect(service.calls, 0);
      await tester.enterText(
          field, create ? List.filled(101, 'x').join() : 'legacy');
      await submit(tester);
      await tester.pumpAndSettle();
      expect(service.calls, 0);
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

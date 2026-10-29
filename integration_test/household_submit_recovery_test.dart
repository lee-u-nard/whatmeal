import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whatmeal/core/services/family_service.dart';
import 'package:whatmeal/features/auth/models/user_model.dart';
import 'package:whatmeal/features/family/data/family_repository.dart';
import 'package:whatmeal/features/family/pages/family_space_page.dart';
import 'package:whatmeal/features/family/models/household_action_error.dart';

class ObservedService extends FamilyService {
  ObservedService(FirebaseFirestore db) : super(firestore: db);
  final failureCodes = <String>[];
  @override
  Future<String> createFamily(
      {required String name,
      required String uid,
      required String displayName}) async {
    try {
      return await super
          .createFamily(name: name, uid: uid, displayName: displayName);
    } on FirebaseException catch (error) {
      failureCodes.add(error.code);
      rethrow;
    }
  }

  @override
  Future<String> joinFamily(
      {required String inviteCode,
      required String uid,
      required String displayName}) async {
    try {
      return await super.joinFamily(
          inviteCode: inviteCode, uid: uid, displayName: displayName);
    } on FirebaseException catch (error) {
      failureCodes.add(error.code);
      rethrow;
    }
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
      'disposable local SDK create/join failure recovery preserves normal login',
      (tester) async {
    expect(appFlavor, 'local');
    const host = String.fromEnvironment('WHATMEAL_EMULATOR_HOST',
        defaultValue: '10.0.2.2');
    expect(['10.0.2.2', '127.0.0.1'], contains(host));
    await Firebase.initializeApp();
    expect(Firebase.app().options.projectId, 'demo-whatmeal-audit');
    // Read-only baseline: never sign out/update the normal app's Auth instance.
    final normalAuth = FirebaseAuth.instance;
    await normalAuth.useAuthEmulator(host, 9099);
    final normalUser = await normalAuth.authStateChanges().first;
    expect(normalUser != null, isTrue,
        reason: 'Preserve the existing manual login');
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final fixture = await Firebase.initializeApp(
        name: 'household-recovery-$stamp', options: Firebase.app().options);
    final auth = FirebaseAuth.instanceFor(app: fixture);
    const fixtureAuthPort =
        int.fromEnvironment('WHATMEAL_RECOVERY_AUTH_PORT', defaultValue: 9099);
    expect([9099, 9199], contains(fixtureAuthPort));
    await auth.useAuthEmulator(host, fixtureAuthPort);
    final db = FirebaseFirestore.instanceFor(app: fixture);
    db.settings = const Settings(persistenceEnabled: false);
    // Only this secondary client uses the reversible loopback transport gate.
    db.useFirestoreEmulator(host, 8183);
    final observed = ObservedService(db);
    final phases = <String>[];
    binding.reportData = {
      'phases': phases,
      'normalLoginPreserved': false,
      'sdkFailureCodes': observed.failureCodes,
      'scope': 'Named secondary Firebase app; disposable local accounts only'
    };
    void checkpoint(String value) {
      phases.add(value);
      debugPrint('Local recovery checkpoint: $value');
    }

    Future<void> until(bool Function() ready) async {
      for (var i = 0; i < 1200 && !ready(); i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(ready(), isTrue,
          reason: 'Local recovery phase must finish within its bounded wait');
    }

    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder.first);
      await tester.pumpAndSettle();
      expect(finder.first.hitTestable(), findsOneWidget);
      await tester.tap(finder.first);
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> pauseTransport(bool paused) async {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      try {
        final request = await client.postUrl(
            Uri.parse('http://$host:8184/${paused ? 'pause' : 'resume'}'));
        request.followRedirects = false;
        final response = await request.close();
        expect(response.statusCode, 200);
        final state =
            jsonDecode(await utf8.decoder.bind(response).join()) as Map;
        expect(state['paused'], paused);
      } finally {
        client.close();
      }
    }

    Future<DocumentSnapshot<Map<String, dynamic>>> serverIndex(
        String uid) async {
      // A resumed TCP gate does not instantly clear native SDK reconnect backoff.
      // Only transient transport failures may retry; a real server result is required.
      for (var attempt = 0;; attempt++) {
        try {
          return await db
              .doc('membershipIndex/$uid')
              .get(const GetOptions(source: Source.server));
        } on FirebaseException catch (error) {
          if (!['unavailable', 'deadline-exceeded'].contains(error.code) ||
              attempt >= 29) {
            rethrow;
          }
          await tester.pump(const Duration(seconds: 1));
        }
      }
    }

    void expectNetworkFeedback() {
      final code = observed.failureCodes.last;
      expect(['unavailable', 'deadline-exceeded'], contains(code));
      final message = householdActionError(
          FirebaseException(plugin: 'cloud_firestore', code: code));
      expect(
          find.descendant(
              of: find.byType(BottomSheet), matching: find.text(message)),
          findsOneWidget);
    }

    Finder field() => find
        .descendant(
            of: find.byType(BottomSheet), matching: find.byType(TextField))
        .first;
    Finder submit() => find
        .descendant(
            of: find.byType(BottomSheet), matching: find.byType(ElevatedButton))
        .first;
    Future<void> enter(String value) async {
      await tester.ensureVisible(field());
      await tester.enterText(field(), value);
      await tester.pumpAndSettle();
    }

    bool retains(String value) =>
        tester.widget<TextField>(field()).controller?.text == value;
    Future<UserModel> register(String label) async {
      final email = 'recovery-${label.toLowerCase()}-$stamp@example.test';
      final credential = await auth.createUserWithEmailAndPassword(
          email: email, password: 'Disposable-local-123!');
      await credential.user!.updateDisplayName(label);
      await credential.user!.sendEmailVerification();
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      try {
        final request = await client.getUrl(Uri.parse(
            'http://$host:$fixtureAuthPort/emulator/v1/projects/demo-whatmeal-audit/oobCodes'));
        request.followRedirects = false;
        final response = await request.close();
        expect(response.statusCode, 200);
        final data =
            jsonDecode(await utf8.decoder.bind(response).join()) as Map;
        final code = (data['oobCodes'] as List)
            .where((value) =>
                value['email'] == email &&
                value['requestType'] == 'VERIFY_EMAIL')
            .last as Map;
        await auth.applyActionCode(code['oobCode'] as String);
        await auth.currentUser!.reload();
        await auth.currentUser!.getIdToken(true);
      } finally {
        client.close();
      }
      expect(auth.currentUser!.emailVerified, isTrue);
      return UserModel(
          id: credential.user!.uid,
          name: label,
          email: email,
          isEmailVerified: true);
    }

    FamilyRepository? repository;
    final account = ValueNotifier<UserModel?>(null);
    tester.testTextInput.register();
    addTearDown(tester.testTextInput.unregister);
    try {
      await pauseTransport(false);
      final owner = await register('Owner');
      account.value = owner;
      final repo = repository = FamilyRepository(
          firestore: db,
          authIds: auth.authStateChanges().map((user) => user?.uid),
          account: account,
          service: observed);
      await tester
          .pumpWidget(MaterialApp(home: FamilySpacePage(repository: repo)));
      await until(() => repo.currentUid == owner.id);
      await tap(find.text('Create Space'));
      final name = 'Disposable recovery $stamp';
      await enter(name);
      await pauseTransport(true);
      await tap(submit());
      await until(() => !repo.isLoading && repo.error != null);
      await tester.pumpAndSettle();
      debugPrint('Local recovery safe create feedback: ${repo.error}');
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(retains(name), isTrue);
      expectNetworkFeedback();
      checkpoint('create SDK offline failure retained draft and visible retry');
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      await binding.takeScreenshot('create-offline');
      await pauseTransport(false);
      expect((await serverIndex(owner.id)).exists, isFalse);
      await tap(submit());
      await until(() =>
          find.byType(BottomSheet).evaluate().isEmpty && repo.value != null);
      final familyId = repo.value!.id;
      expect(
          (await db
                      .doc('families/$familyId')
                      .get(const GetOptions(source: Source.server)))
                  .data()?['name'] ==
              name,
          isTrue);
      checkpoint('same create draft retried and committed through SDK');
      final service = FamilyService(firestore: db);
      final revoked =
          await service.createInvitation(familyId: familyId, uid: owner.id);
      await service.revokeInvitation(revoked);
      final valid =
          await service.createInvitation(familyId: familyId, uid: owner.id);

      await auth.signOut();
      final member = await register('Member');
      account.value = member;
      await until(() => repo.currentUid == member.id && repo.value == null);
      await tester.pumpAndSettle();
      expect(find.text(name), findsNothing);
      checkpoint('disposable member account sees no owner household');
      await tap(find.text('Join with Key'));
      await enter('legacy');
      await tap(submit());
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(repo.isLoading, isFalse);
      expect(find.textContaining('Legacy short codes'), findsOneWidget);
      checkpoint('legacy invitation validation retains join editor');

      await enter(revoked);
      await tap(submit());
      await until(() => !repo.isLoading && repo.error != null);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(retains(revoked), isTrue);
      expect(
          find.descendant(
              of: find.byType(BottomSheet),
              matching: find.textContaining('Household access was denied')),
          findsOneWidget);
      expect((await serverIndex(member.id)).exists, isFalse);
      checkpoint(
          'revoked invitation denied by rules; editor and draft retained');

      await enter(valid);
      await pauseTransport(true);
      await tap(submit());
      await until(() => !repo.isLoading && repo.error != null);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(retains(valid), isTrue);
      expectNetworkFeedback();
      checkpoint('join SDK offline failure retained exact invitation draft');
      await pauseTransport(false);
      expect((await serverIndex(member.id)).exists, isFalse);
      await tap(submit());
      await until(() =>
          find.byType(BottomSheet).evaluate().isEmpty &&
          repo.value?.id == familyId);
      final membership = await db
          .doc('families/$familyId/members/${member.id}')
          .get(const GetOptions(source: Source.server));
      expect(membership.data()?['role'], 'member');
      expect(
          (await db
                  .collection('families/$familyId/members')
                  .get(const GetOptions(source: Source.server)))
              .docs
              .length,
          2);
      checkpoint(
          'join retry committed once with member role and two total members');
      expect(normalAuth.currentUser?.uid == normalUser?.uid, isTrue);
      binding.reportData!['normalLoginPreserved'] = true;
      checkpoint(
          'normal app login unchanged by all secondary-client operations');
      await binding.takeScreenshot('joined-member');
    } finally {
      await tester.pumpWidget(const SizedBox());
      repository?.dispose();
      account.dispose();
      await pauseTransport(false);
      await auth.signOut();
      expect(normalAuth.currentUser?.uid == normalUser?.uid, isTrue);
      await fixture.delete();
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}

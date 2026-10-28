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

class DepartureObservedService extends FamilyService {
  DepartureObservedService(FirebaseFirestore db) : super(firestore: db);
  final departureErrors = <String>[];
  @override
  Future<void> leaveFamily(
      {required String familyId, required String uid}) async {
    try {
      await super.leaveFamily(familyId: familyId, uid: uid);
    } on FirebaseException catch (failure) {
      departureErrors.add(failure.code);
      rethrow;
    }
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets('local removal during outage and queued departure recovery',
      (tester) async {
    expect(appFlavor, 'local');
    const host = '10.0.2.2';
    await Firebase.initializeApp();
    expect(Firebase.app().options.projectId, 'demo-whatmeal-audit');
    final normal = FirebaseAuth.instance;
    await normal.useAuthEmulator(host, 9099);
    final baseline = await normal.authStateChanges().first;
    expect(baseline != null, isTrue,
        reason: 'Existing manual login must remain intact');
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final ownerApp = await Firebase.initializeApp(
        name: 'departure-owner-$stamp', options: Firebase.app().options);
    final memberApp = await Firebase.initializeApp(
        name: 'departure-member-$stamp', options: Firebase.app().options);
    final ownerAuth = FirebaseAuth.instanceFor(app: ownerApp);
    final memberAuth = FirebaseAuth.instanceFor(app: memberApp);
    await ownerAuth.useAuthEmulator(host, 9199);
    await memberAuth.useAuthEmulator(host, 9199);
    final ownerDb = FirebaseFirestore.instanceFor(app: ownerApp);
    final memberDb = FirebaseFirestore.instanceFor(app: memberApp);
    ownerDb.settings = const Settings(persistenceEnabled: false);
    memberDb.settings = const Settings(persistenceEnabled: false);
    ownerDb.useFirestoreEmulator(host, 9180);
    memberDb.useFirestoreEmulator(host, 8183);
    final observed = DepartureObservedService(memberDb);
    final ownerAccount = ValueNotifier<UserModel?>(null);
    final memberAccount = ValueNotifier<UserModel?>(null);
    FamilyRepository? ownerRepo, memberRepo;
    final phases = <String>[];
    binding.reportData = {
      'phases': phases,
      'normalLoginPreserved': false,
      'departureErrors': observed.departureErrors,
      'scope':
          'Two named Firebase clients on one AVD; disposable accounts only; not simultaneous devices'
    };
    void checkpoint(String message) {
      phases.add(message);
      debugPrint('Local departure checkpoint: $message');
    }

    Future<void> until(bool Function() ready) async {
      for (var n = 0; n < 1200 && !ready(); n++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(ready(), isTrue,
          reason: 'Bounded local departure phase must complete');
    }

    Future<void> transport(bool pause) async {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      try {
        final request = await client.postUrl(
            Uri.parse('http://$host:8184/${pause ? "pause" : "resume"}'));
        request.followRedirects = false;
        final response = await request.close();
        expect(response.statusCode, 200);
        expect(
            (jsonDecode(await utf8.decoder.bind(response).join())
                as Map)['paused'],
            pause);
      } finally {
        client.close();
      }
    }

    Future<UserModel> register(FirebaseAuth auth, String label) async {
      final email = 'departure-${label.toLowerCase()}-$stamp@example.test';
      final result = await auth.createUserWithEmailAndPassword(
          email: email, password: 'Disposable-local-123!');
      await result.user!.updateDisplayName(label);
      await result.user!.sendEmailVerification();
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      try {
        final response = await (await client.getUrl(Uri.parse(
                'http://$host:9199/emulator/v1/projects/demo-whatmeal-audit/oobCodes')))
            .close();
        expect(response.statusCode, 200);
        final codes = (jsonDecode(await utf8.decoder.bind(response).join())
            as Map)['oobCodes'] as List;
        final code = codes.lastWhere((entry) =>
            entry['email'] == email && entry['requestType'] == 'VERIFY_EMAIL');
        await auth.applyActionCode(code['oobCode'] as String);
        await auth.currentUser!.reload();
        await auth.currentUser!.getIdToken(true);
        expect(auth.currentUser!.emailVerified, isTrue);
        return UserModel(
            id: auth.currentUser!.uid,
            name: label,
            email: email,
            isEmailVerified: true);
      } finally {
        client.close();
      }
    }

    Future<DocumentSnapshot<Map<String, dynamic>>> serverGet(
        FirebaseFirestore db, String path) async {
      for (var attempt = 0;; attempt++) {
        try {
          return await db
              .doc(path)
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

    Future<void> deniedFamilyRead(String familyId) async {
      String? denied;
      try {
        await serverGet(memberDb, 'families/$familyId');
      } on FirebaseException catch (error) {
        denied = error.code;
      }
      expect(denied, 'permission-denied');
    }

    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder.first);
      await tester.pumpAndSettle();
      expect(finder.first.hitTestable(), findsOneWidget);
      await tester.tap(finder.first);
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> rejoin(FamilyService ownerService, String familyId) async {
      final token = await ownerService.createInvitation(
          familyId: familyId, uid: ownerAuth.currentUser!.uid);
      await tap(find.text('Join with Key'));
      final field = find
          .descendant(
              of: find.byType(BottomSheet), matching: find.byType(TextField))
          .first;
      tester.testTextInput.register();
      await tester.enterText(field, token);
      await tester.pumpAndSettle();
      await tap(find.descendant(
          of: find.byType(BottomSheet), matching: find.byType(ElevatedButton)));
      await until(() =>
          memberRepo!.value?.id == familyId &&
          !memberRepo.isLoading &&
          find.byType(BottomSheet).evaluate().isEmpty);
      await tester.pumpAndSettle();
    }

    Future<void> leaveOffline() async {
      await until(() => find.byType(SnackBar).evaluate().isEmpty);
      await tester.scrollUntilVisible(find.text('Leave Household Space'), 400);
      await tap(find.text('Leave Household Space'));
      await transport(true);
      await tap(find.widgetWithText(ElevatedButton, 'Leave Space'));
      await until(() =>
          memberRepo!.isLoading && find.byType(AlertDialog).evaluate().isEmpty);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Updating household. Waiting for confirmation…'),
          findsOneWidget);
      expect(find.text('You have left the family space.'), findsNothing);
    }

    try {
      await transport(false);
      ownerAccount.value = await register(ownerAuth, 'Owner');
      memberAccount.value = await register(memberAuth, 'Member');
      final owner = ownerRepo = FamilyRepository(
          firestore: ownerDb,
          authIds: ownerAuth.authStateChanges().map((u) => u?.uid),
          account: ownerAccount);
      final member = memberRepo = FamilyRepository(
          firestore: memberDb,
          authIds: memberAuth.authStateChanges().map((u) => u?.uid),
          account: memberAccount,
          service: observed);
      final ownerService = FamilyService(firestore: ownerDb);
      final memberService = FamilyService(firestore: memberDb);
      final familyId = await ownerService.createFamily(
          name: 'Disposable departure home',
          uid: ownerAccount.value!.id,
          displayName: 'Owner');
      final token = await ownerService.createInvitation(
          familyId: familyId, uid: ownerAccount.value!.id);
      await memberService.joinFamily(
          inviteCode: token,
          uid: memberAccount.value!.id,
          displayName: 'Member');
      await tester
          .pumpWidget(MaterialApp(home: FamilySpacePage(repository: member)));
      await until(() =>
          owner.value?.members.length == 2 &&
          member.value?.members.length == 2);
      await tester.pumpAndSettle();
      checkpoint('two authorized native SDK clients loaded the same household');
      await transport(true);
      expect(await owner.removeMember(memberAccount.value!.id), isTrue);
      expect(
          (await ownerDb
                  .collection('families/$familyId/members')
                  .get(const GetOptions(source: Source.server)))
              .docs
              .length,
          1);
      checkpoint(
          'owner removal committed while invited member transport was offline');
      await transport(false);
      await until(() => member.value == null && member.scopeId == null);
      await tester.pumpAndSettle();
      expect(find.text('Disposable departure home'), findsNothing);
      await deniedFamilyRead(familyId);
      expect(
          (await serverGet(
                  memberDb, 'membershipIndex/${memberAccount.value!.id}'))
              .exists,
          isFalse);
      checkpoint(
          'reconnect revoked member UI and server access without stale household exposure');
      await rejoin(ownerService, familyId);
      await until(() => owner.value?.members.length == 2);
      checkpoint(
          'removed member legitimately rejoined using a fresh invitation through UI');
      await leaveOffline();
      checkpoint(
          'ordinary leave UI showed pending confirmation during transport outage');
      await transport(false);
      await until(() => !member.isLoading && member.value == null);
      await tester.pumpAndSettle();
      expect(
          (await serverGet(
                  memberDb, 'membershipIndex/${memberAccount.value!.id}'))
              .exists,
          isFalse);
      await deniedFamilyRead(familyId);
      await until(() => owner.value?.members.length == 1);
      checkpoint(
          'acknowledged departure removed membership and updated the owner listener');
      await until(() =>
          find.text('You have left the family space.').evaluate().isEmpty);
      await rejoin(ownerService, familyId);
      await until(() => owner.value?.members.length == 2);
      await leaveOffline();
      expect(await owner.removeMember(memberAccount.value!.id), isTrue);
      await transport(false);
      await until(() =>
          !member.isLoading && member.value == null && member.error != null);
      await tester.pumpAndSettle();
      expect(find.text('You have left the family space.'), findsNothing);
      expect(observed.departureErrors, ['permission-denied']);
      expect([
        'Household access was denied. Check your membership or invitation and retry.',
        'Household change could not be confirmed. Check your household and retry.'
      ], contains(member.error));
      checkpoint(
          'queued departure lost a removal race and showed real rules denial without false success');
      await deniedFamilyRead(familyId);
      expect(
          (await serverGet(
                  memberDb, 'membershipIndex/${memberAccount.value!.id}'))
              .exists,
          isFalse);
      checkpoint(
          'denied queued departure left canonical index absent and access revoked');
      await rejoin(ownerService, familyId);
      await until(() => owner.value?.members.length == 2);
      checkpoint(
          'fresh invitation recovered after denied queued departure with two members only');
      expect(normal.currentUser?.uid == baseline?.uid, isTrue);
      binding.reportData!['normalLoginPreserved'] = true;
      checkpoint(
          'normal cached login remained unchanged across both disposable clients');
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      await binding.takeScreenshot('departure-recovered');
    } finally {
      await tester.pumpWidget(const SizedBox());
      ownerRepo?.dispose();
      memberRepo?.dispose();
      ownerAccount.dispose();
      memberAccount.dispose();
      await transport(false);
      await ownerAuth.signOut();
      await memberAuth.signOut();
      expect(normal.currentUser?.uid == baseline?.uid, isTrue);
      await ownerApp.delete();
      await memberApp.delete();
    }
  }, timeout: const Timeout(Duration(minutes: 9)));
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:whatmeal/features/profile/widgets/edit_profile_sheet.dart';
import 'package:whatmeal/features/profile/data/family_member_repository.dart';
import 'package:whatmeal/features/profile/pages/profile_page.dart';
import 'package:whatmeal/features/pantry/data/pantry_repository.dart';
import 'package:whatmeal/features/pantry/models/pantry_item.dart';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whatmeal/main.dart' as app;
import 'package:whatmeal/app.dart';
import 'package:whatmeal/features/auth/data/auth_repository.dart';
import 'package:whatmeal/features/auth/pages/login_page.dart';
import 'package:whatmeal/features/family/data/family_repository.dart';
import 'package:whatmeal/features/family/pages/family_space_page.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets('local Android password profile pantry and recovery acceptance',
      (tester) async {
    // Flutter documents that injected editing updates can race a real IME.
    // Use deterministic test typing; this does not verify native-keyboard UX.
    // Clipboard, permissions, Android UI and Firebase SDKs remain real.
    tester.testTextInput.register();
    addTearDown(tester.testTextInput.unregister);
    expect(appFlavor, 'local', reason: 'Refuse any production-flavor launch');
    app.main();
    final phases = <String>[];
    binding.reportData = {'completedPhases': phases};
    void checkpoint(String phase) {
      phases.add(phase);
      debugPrint('Local UI checkpoint: $phase');
    }

    Future<void> until(bool Function() ready) async {
      for (var i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        if (ready()) return;
      }
      fail('Timed out waiting for local app state');
    }

    Future<void> tap(Finder finder) async {
      // Lazy ListViews dispose controls outside the viewport. Search using
      // ordinary scrolling before waiting for an asynchronous control to appear.
      final visibleScrolls = find
          .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
          .hitTestable();
      if (finder.evaluate().isEmpty && visibleScrolls.evaluate().isNotEmpty) {
        final scrollable = visibleScrolls.last;
        for (var i = 0; i < 6 && finder.evaluate().isEmpty; i++) {
          await tester.drag(scrollable, const Offset(0, 400));
          await tester.pumpAndSettle();
        }
        for (var i = 0; i < 20 && finder.evaluate().isEmpty; i++) {
          await tester.drag(scrollable, const Offset(0, -400));
          await tester.pumpAndSettle();
        }
      }
      await until(() => finder.evaluate().isNotEmpty);
      await tester.pumpAndSettle();
      await tester.ensureVisible(finder.first);
      await tester.pumpAndSettle();
      // Native IME inset updates can arrive after Flutter's first settled frame.
      // Re-scroll after those updates; keep missed taps fatal rather than tapping
      // an off-screen button or dismissing unrelated Android UI.
      for (var attempt = 0;
          attempt < 20 && finder.first.hitTestable().evaluate().isEmpty;
          attempt++) {
        await tester.pump(const Duration(milliseconds: 200));
        await tester.ensureVisible(finder.first);
        await tester.pumpAndSettle();
      }
      if (finder.first.hitTestable().evaluate().isEmpty) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pump();
        await binding.takeScreenshot('blocked-control');
      }
      expect(finder.first.hitTestable(), findsOneWidget,
          reason: 'The UI control must be visible and able to receive taps');
      await tester.tap(finder.first);
      await tester.pump(const Duration(milliseconds: 300));
    }

    Finder field(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label);
    Future<void> enter(String label, String text) async {
      // Focus and settle the native keyboard before replacing a prefilled value.
      await tap(field(label));
      await tester.enterText(field(label), text);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field(label)).controller?.text == text,
          isTrue,
          reason: 'Entered field must retain input; never print its value');
    }

    Future<String> register(String label) async {
      await until(() => find.byType(LoginPage).evaluate().isNotEmpty);
      await tap(find.text('Create Account'));
      final email =
          '${label.toLowerCase()}-${DateTime.now().microsecondsSinceEpoch}@example.test';
      await enter('Full Name', label);
      await enter('Email Address', email);
      await enter('Password', 'Local-fixture-123!');
      await enter('Confirm Password', 'Local-fixture-123!');
      await tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await until(
          () => find.text('Verify Your Email Address').evaluate().isNotEmpty);
      expect(Firebase.app().options.projectId, 'demo-whatmeal-audit');
      // Obtain only the local emulator's generated email action; never bypass verification.
      const host = String.fromEnvironment('WHATMEAL_EMULATOR_HOST',
          defaultValue: '127.0.0.1');
      expect(['127.0.0.1', '10.0.2.2'], contains(host));
      final client = HttpClient();
      try {
        Map<String, dynamic>? code;
        // Auth routing can show verification before sendEmailVerification has
        // completed. Wait for the real demo action instead of assuming it exists.
        for (var attempt = 0; attempt < 100 && code == null; attempt++) {
          final request = await client.getUrl(Uri.parse(
              'http://$host:9099/emulator/v1/projects/demo-whatmeal-audit/oobCodes'));
          final response = await request.close();
          expect(response.statusCode, 200);
          final codes = (jsonDecode(await utf8.decoder.bind(response).join())
              as Map)['oobCodes'] as List;
          final matching = codes.where(
              (c) => c['email'] == email && c['requestType'] == 'VERIFY_EMAIL');
          if (matching.isNotEmpty) {
            code = matching.last as Map<String, dynamic>;
          }
          if (code == null) {
            await tester.pump(const Duration(milliseconds: 200));
          }
        }
        expect(code != null, isTrue,
            reason: 'Demo verification action must arrive within the deadline');
        await FirebaseAuth.instance.applyActionCode(code!['oobCode'] as String);
      } finally {
        client.close();
      }
      await tap(find.text("I've Verified My Email"));
      await until(() => find.text('Home').evaluate().isNotEmpty);
      checkpoint('$label registered and verified');
      return email;
    }

    Future<void> household() async {
      await tap(find.text('Profile'));
      await tap(find.text('Family Sharing'));
      await until(() => find.byType(FamilySpacePage).evaluate().isNotEmpty);
    }

    Future<void> logout({bool fromHousehold = true}) async {
      if (fromHousehold) {
        await tap(find.byIcon(Icons.arrow_back));
      } else {
        await tap(find.text('Profile'));
      }
      await tap(find.text('Sign Out'));
      await tap(find.widgetWithText(ElevatedButton, 'Log Out'));
      await until(() => find.byType(LoginPage).evaluate().isNotEmpty);
    }

    Future<String> invite() async {
      expect(binding.lifecycleState, AppLifecycleState.resumed,
          reason:
              'Android must give the app focus; do not bypass clipboard permission');
      await tap(find.text('Create Invitation'));
      await until(
          () => FamilyRepository.instance.activeInvitationToken != null);
      await until(() => find
          .text('Invitation token copied to clipboard.')
          .evaluate()
          .isNotEmpty);
      final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clipboard?.text != null, isTrue,
          reason: 'Native clipboard must be accessible in the focused app');
      final token = clipboard!.text!;
      expect(token == FamilyRepository.instance.activeInvitationToken, isTrue,
          reason: 'Copied invitation must match; never print token values');
      checkpoint('invitation copied');
      return token;
    }

    Future<void> join(String token, String familyId) async {
      await tap(find.text('Join with Key'));
      await enter('Invite Code / Key', token);
      await tap(find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byWidgetPredicate((w) => w is ElevatedButton)));
      await until(() => FamilyRepository.instance.value?.id == familyId);
      await until(() => FamilyRepository.instance.value!.members.length == 2);
      await until(() => find.text('Local UI Household').evaluate().isNotEmpty);
      expect(find.text('Local UI Household'), findsWidgets);
    }

    await until(() => find.byType(WhatMealApp).evaluate().isNotEmpty);
    await until(() => !AuthRepository.instance.isInitializing);
    await AuthRepository.instance.logout();
    await tester.pumpAndSettle();
    final ownerEmail = await register('RecoveryOwner');
    final ownerUid = FirebaseAuth.instance.currentUser!.uid;
    await household();
    await tap(find.text('Create Space'));
    await enter('Family Space Name', 'Local UI Household');
    await tap(find.descendant(
        of: find.byType(BottomSheet), matching: find.text('Create Space')));
    await until(() => FamilyRepository.instance.value != null);
    final familyId = FamilyRepository.instance.value!.id;
    final invitation = await invite();
    await tap(find.byIcon(Icons.arrow_back));
    await tap(find.byTooltip('Edit Profile'));
    await enter('Display Name', 'Should Not Save');
    await enter('Current Password', 'incorrect-local-value');
    const changedPassword = ' Updated-local-123! ';
    await enter('New Password', changedPassword);
    await enter('Confirm New Password', changedPassword);
    await tap(find.text('Save Changes'));
    await tap(find.text('Change Password'));
    await until(() => find
        .text('Current password is incorrect. Please retry.')
        .evaluate()
        .isNotEmpty);
    expect(AuthRepository.instance.value!.name, 'RecoveryOwner');
    expect(
        (await FirebaseFirestore.instance
                .collection('users')
                .doc(ownerUid)
                .get())
            .data()!['displayName'],
        'RecoveryOwner');
    checkpoint(
        'wrong current password retained draft and prevented name changes');
    await enter('Display Name', 'Recovery Renamed');
    await enter('Current Password', 'Local-fixture-123!');
    await tap(find.text('Save Changes'));
    await tap(find.text('Change Password'));
    await until(() => find.byType(EditProfileSheet).evaluate().isEmpty);
    await until(
        () => AuthRepository.instance.value?.name == 'Recovery Renamed');
    final account = (await FirebaseFirestore.instance
            .collection('users')
            .doc(ownerUid)
            .get())
        .data()!;
    expect(account['displayName'], 'Recovery Renamed');
    expect(
        account.keys.any((k) => k.toLowerCase().contains('password')), isFalse);
    checkpoint(
        'password and display name changed with no password stored in Firestore');

    Future<void> loginWith(String email, String password) async {
      await enter('Email Address', email);
      await enter('Password', password);
      await tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await until(() => find.text('Home').evaluate().isNotEmpty);
    }

    await logout(fromHousehold: false);
    await enter('Email Address', ownerEmail);
    await enter('Password', 'Local-fixture-123!');
    await tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await until(() => find.byType(SnackBar).evaluate().isNotEmpty);
    expect(FirebaseAuth.instance.currentUser, isNull);
    expect(find.byType(LoginPage), findsOneWidget);
    checkpoint('obsolete password rejected after password change');
    await loginWith(ownerEmail, changedPassword);
    await until(
        () => AuthRepository.instance.value?.name == 'Recovery Renamed');
    checkpoint(
        'literal whitespace password login and persisted display name verified');
    await logout(fromHousehold: false);
    await tap(find.text('Forgot Password?'));
    await enter('Email Address', 'invalid-address');
    await tap(find.text('Send Recovery Link'));
    expect(find.text('Please enter a valid email address.'), findsOneWidget);
    await enter('Email Address', ownerEmail);
    await tap(find.text('Send Recovery Link'));
    await until(() => find.text('Reset Link Sent!').evaluate().isNotEmpty);
    final client = HttpClient();
    String? resetCode;
    try {
      for (var attempt = 0; attempt < 100 && resetCode == null; attempt++) {
        final request = await client.getUrl(Uri.parse(
            'http://10.0.2.2:9099/emulator/v1/projects/demo-whatmeal-audit/oobCodes'));
        final response = await request.close();
        expect(response.statusCode, 200);
        final codes = (jsonDecode(await utf8.decoder.bind(response).join())
            as Map)['oobCodes'] as List;
        final matches = codes.where((c) =>
            c['email'] == ownerEmail && c['requestType'] == 'PASSWORD_RESET');
        if (matches.isNotEmpty) resetCode = matches.last['oobCode'] as String;
        if (resetCode == null) {
          await tester.pump(const Duration(milliseconds: 200));
        }
      }
      expect(resetCode != null, isTrue,
          reason: 'Real local reset action must arrive; never print it');
      await expectLater(
          FirebaseAuth.instance
              .verifyPasswordResetCode('invalid-local-reset-code'),
          throwsA(isA<FirebaseAuthException>()));
      expect(await FirebaseAuth.instance.verifyPasswordResetCode(resetCode!),
          ownerEmail);
      await FirebaseAuth.instance.confirmPasswordReset(
          code: resetCode, newPassword: 'Reset-local-456!');
      await expectLater(
          FirebaseAuth.instance.verifyPasswordResetCode(resetCode),
          throwsA(isA<FirebaseAuthException>()));
    } finally {
      client.close(force: true);
    }
    await tap(find.text('Return to Sign In'));
    await loginWith(ownerEmail, 'Reset-local-456!');
    await until(() => FamilyRepository.instance.value?.id == familyId);
    expect(AuthRepository.instance.value?.name, 'Recovery Renamed');
    checkpoint(
        'reset requested through UI; SDK completed demo email action; invalid and reused actions rejected; reset login passed');

    await tap(find.text('Profile'));
    await tap(find.widgetWithText(TextButton, 'Add'));
    await enter('First Name', 'Local Child');
    await enter('Age', '8');
    await tap(find.text('Peanut Allergy'));
    await tap(find.widgetWithText(ElevatedButton, 'Add Family Member'));
    await until(() => FamilyMemberRepository.instance.members
        .any((m) => m.name == 'Local Child'));
    final child = FamilyMemberRepository.instance.members
        .singleWhere((m) => m.name == 'Local Child');
    Finder childCard() => find.byWidgetPredicate(
        (w) => w is FamilyMemberCard && w.member.id == child.id);
    await tap(find.descendant(
        of: childCard(), matching: find.byTooltip('Member actions')));
    await tap(find.text('Edit Profile'));
    await enter('Age', '9');
    await enter('Role / Relation', 'Child');
    await tap(find.text('Vegan'));
    await tap(find.text('Save Changes'));
    await until(() =>
        FamilyMemberRepository.instance.members
            .singleWhere((m) => m.id == child.id)
            .age ==
        9);
    final edited = FamilyMemberRepository.instance.members
        .singleWhere((m) => m.id == child.id);
    expect(edited.restrictions, contains('Peanut Allergy'));
    expect(edited.preferences, contains('Vegan'));
    expect(edited.createdAt, child.createdAt);
    checkpoint(
        'dietary profile edited with stable identity allergy preference and creation timestamp');

    await tap(find.text('Pantry'));
    await tap(find.text('Add Ingredient'));
    await enter('Ingredient Name', 'Recovery Rice');
    await enter('Quantity (e.g. 1.2 kg, 4 units)', '2 kg');
    await tap(find.text('Select expiration date'));
    await tap(find.widgetWithText(TextButton, 'OK'));
    await tap(find.widgetWithText(FilledButton, 'Add to Pantry'));
    PantryItem? rice() => PantryRepository.instance.items.values
        .expand((v) => v)
        .where((p) => p.name == 'Recovery Rice')
        .firstOrNull;
    await until(() => rice() != null);
    final riceId = rice()!.id;
    final expiry = rice()!.expirationDate;
    final creation = rice()!.createdAt;
    final author = rice()!.addedBy;
    await tap(find.byTooltip('Item options'));
    await tap(find.text('Edit Item'));
    await tap(find.byType(DropdownButtonFormField<String>));
    await tap(find.text('Pantry Staples').last);
    await enter('Quantity (e.g. 1.2 kg, 4 units)', '3 kg');
    await tap(find.widgetWithText(FilledButton, 'Save Changes'));
    await until(() =>
        rice()?.quantity == '3 kg' && rice()?.category == 'Pantry Staples');
    expect(rice()!.id, riceId);
    expect(rice()!.expirationDate, expiry);
    expect(rice()!.createdAt, creation);
    expect(rice()!.addedBy, author);
    checkpoint(
        'pantry category and quantity edited on same document with exact expiry author and creation retained');
    expect(DateUtils.dateOnly(expiry),
        DateUtils.dateOnly(DateTime.now().add(const Duration(days: 7))));
    for (final status in [
      PantryStatus.runningLow,
      PantryStatus.used,
      PantryStatus.needed,
      PantryStatus.available
    ]) {
      await tap(
          find.byTooltip('Tap to change status (Available / Used / Needed)'));
      await until(() => rice()?.status == status);
    }
    checkpoint('pantry status cycle and selected expiration date persisted');

    await logout(fromHousehold: false);
    await register('RecoveryMember');
    expect(PantryRepository.instance.items.values.expand((v) => v), isEmpty);
    expect(FamilyMemberRepository.instance.members, isEmpty);
    await household();
    await join(invitation, familyId);
    await tap(find.byIcon(Icons.arrow_back));
    await until(() =>
        FamilyMemberRepository.instance.members.any((m) => m.id == child.id));
    expect(
        FamilyMemberRepository.instance.members
            .singleWhere((m) => m.id == child.id)
            .restrictions,
        contains('Peanut Allergy'));
    await tap(find.text('Pantry'));
    await until(() => rice()?.quantity == '3 kg');
    checkpoint(
        'second account isolated before joining then saw authorized pantry and dietary profile changes');

    Future<Map<String, dynamic>> relay(String action) async {
      expect(appFlavor, 'local');
      expect(Firebase.app().options.projectId, 'demo-whatmeal-audit');
      expect(
          const int.fromEnvironment('WHATMEAL_FIRESTORE_EMULATOR_PORT'), 8181);
      final http = HttpClient();
      try {
        final req =
            await http.postUrl(Uri.parse('http://10.0.2.2:8182/$action'));
        final res = await req.close();
        expect(res.statusCode, 200);
        return jsonDecode(await utf8.decoder.bind(res).join())
            as Map<String, dynamic>;
      } finally {
        http.close(force: true);
      }
    }

    await tap(find.byTooltip('Item options'));
    await tap(find.text('Edit Item'));
    await enter('Quantity (e.g. 1.2 kg, 4 units)', '4 kg');
    final recoveryScope = PantryRepository.instance.scopeVersion;
    try {
      final offline = await relay('offline');
      expect(offline['online'], false);
      expect(offline['dropped'] as int, greaterThan(0));
      await tap(find.widgetWithText(FilledButton, 'Save Changes'));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Edit Ingredient'), findsOneWidget);
      checkpoint('real pantry transport outage retained edit draft');
    } finally {
      expect((await relay('online'))['online'], true);
    }
    await until(() =>
        find.text('Edit Ingredient').evaluate().isEmpty ||
        find
            .text('Ingredient was not saved. Please retry.')
            .evaluate()
            .isNotEmpty);
    final itemRef = FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('pantryItems')
        .doc(riceId);
    var connected = false;
    var unavailableReads = 0;
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    while (!connected && DateTime.now().isBefore(deadline)) {
      try {
        await itemRef.get(const GetOptions(source: Source.server));
        connected = true;
      } on FirebaseException catch (e) {
        if (e.code != 'unavailable') rethrow;
        unavailableReads++;
        await tester.pump(const Duration(seconds: 1));
      }
    }
    binding.reportData!['recoveryTransport'] = {
      'serverReadSucceeded': connected,
      'unavailableReads': unavailableReads,
      'scopeUnchanged': recoveryScope == PantryRepository.instance.scopeVersion,
      'householdUnchanged': FamilyRepository.instance.value?.id == familyId,
    };
    expect(connected, isTrue,
        reason:
            'Restoring the relay must restore an authorized real server read');
    expect(PantryRepository.instance.scopeVersion, recoveryScope,
        reason: 'Outage must not silently switch the editor workspace');
    checkpoint(
        'authorized server read confirmed SDK transport restored before ordinary retry');
    if (find
        .text('Ingredient was not saved. Please retry.')
        .evaluate()
        .isNotEmpty) {
      expect(
          tester
              .widget<TextField>(field('Quantity (e.g. 1.2 kg, 4 units)'))
              .controller!
              .text,
          '4 kg');
      await tap(find.widgetWithText(FilledButton, 'Save Changes'));
    }
    await until(() => rice()?.quantity == '4 kg');
    expect(
        PantryRepository.instance.items.values
            .expand((v) => v)
            .where((p) => p.id == riceId),
        hasLength(1));
    checkpoint(
        'pantry edit recovered after reconnect without identity or quantity loss');
    await tap(find.byTooltip('Item options'));
    await tap(find.text('Delete Item'));
    await tap(find.text('Cancel'));
    expect(rice(), isNotNull);
    await tap(find.byTooltip('Item options'));
    await tap(find.text('Delete Item'));
    await tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Delete')));
    await until(() => rice() == null);
    checkpoint('pantry deletion cancellation and confirmed deletion passed');
    await tap(find.text('Profile'));
    await tap(find.descendant(
        of: childCard(), matching: find.byTooltip('Member actions')));
    await tap(find.text('Remove'));
    await tap(find.text('Cancel'));
    expect(FamilyMemberRepository.instance.members.any((m) => m.id == child.id),
        isTrue);
    await tap(find.descendant(
        of: childCard(), matching: find.byTooltip('Member actions')));
    await tap(find.text('Remove'));
    await tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Delete')));
    await until(() =>
        FamilyMemberRepository.instance.members.every((m) => m.id != child.id));
    checkpoint(
        'dietary profile deletion cancellation and confirmed deletion passed');
    expect(tester.takeException(), isNull);
  });
}

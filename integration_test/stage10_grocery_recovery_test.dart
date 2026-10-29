import 'package:whatmeal/core/services/llm_service.dart';
import 'package:whatmeal/core/services/ai/generation_failure.dart';
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
import 'package:whatmeal/features/grocery/data/grocery_repository.dart';
import 'package:whatmeal/features/grocery/models/grocery_item.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets('local Android shared groceries and verified transport recovery',
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
    await register('GroceryOwner');
    await household();
    await tap(find.text('Create Space'));
    await enter('Family Space Name', 'Local UI Household');
    await tap(find.descendant(
        of: find.byType(BottomSheet), matching: find.text('Create Space')));
    await until(() => FamilyRepository.instance.value != null);
    final familyId = FamilyRepository.instance.value!.id;
    final token = await invite();
    await logout();
    await register('GroceryMember');
    expect(FamilyRepository.instance.value, isNull);
    await household();
    await join(token, familyId);
    checkpoint('fresh demo member joined expected shared grocery household');
    await tap(find.byIcon(Icons.arrow_back));
    await tap(find.text('Grocery'));
    await until(() => !GroceryRepository.instance.isLoading);
    expect(GroceryRepository.instance.error, isNull);
    GroceryItem? manual(String name) => GroceryRepository.instance.allItems
        .where((i) => i.name == name)
        .firstOrNull;
    Future<void> addManual(String name, String quantity) async {
      await tap(find.byTooltip('Add grocery item'));
      await tap(find.widgetWithText(ElevatedButton, 'Add to List'));
      expect(find.text('Enter an item name.'), findsOneWidget);
      await enter('Item Name', name);
      await enter('Quantity', quantity);
      await tap(find.widgetWithText(ElevatedButton, 'Add to List'));
      await until(() => find.text('Add to List').evaluate().isEmpty);
      await until(() => find.byType(SnackBar).evaluate().isEmpty);
    }

    await addManual('Local Milk', '2 cups');
    await until(() => manual('Local Milk') != null);
    final manualId = manual('Local Milk')!.id;
    await addManual('  local   milk  ', '500 g');
    expect(
        GroceryRepository.instance.allItems
            .where((i) => i.name.toLowerCase().contains('milk')),
        hasLength(1));
    expect(manual('Local Milk')!.quantity, '2 cups');
    checkpoint('manual grocery add and normalized duplicate prevention');
    await tap(find.descendant(
        of: find.byKey(ValueKey(manualId)),
        matching: find.byTooltip('Edit item')));
    await enter('Item Name', 'Local Edited Milk');
    await enter('Quantity', '500 g');
    await tap(find.text('Save Changes'));
    await until(() => manual('Local Edited Milk')?.quantity == '500 g');
    final editedId = manual('Local Edited Milk')!.id;
    Finder editedRow() => find.byKey(ValueKey(editedId));
    for (final checked in [true, false, true]) {
      await tap(
          find.descendant(of: editedRow(), matching: find.byType(Checkbox)));
      await until(() => manual('Local Edited Milk')!.isPurchased == checked);
    }
    checkpoint('manual grocery edit quantity check and uncheck persisted');
    await addManual('Local Herbs', '');
    await until(() => manual('Local Herbs') != null);
    expect(manual('Local Herbs')!.quantity, '');
    final pendingHerb = manual('Local Herbs')!.id;
    await tap(find.descendant(
        of: find.byKey(ValueKey(pendingHerb)),
        matching: find.byTooltip('Edit item')));
    await enter('Quantity', '2 pieces');
    const relayPort = int.fromEnvironment('WHATMEAL_FIRESTORE_EMULATOR_PORT',
        defaultValue: 8180);
    expect(relayPort, 8181,
        reason: 'Recovery test requires the isolated relay');
    Future<Map<String, dynamic>> relay(String action) async {
      expect(appFlavor, 'local');
      expect(Firebase.app().options.projectId, 'demo-whatmeal-audit');
      final client = HttpClient();
      try {
        final uri = Uri.parse('http://10.0.2.2:8182/$action');
        final request = action == 'status'
            ? await client.getUrl(uri)
            : await client.postUrl(uri);
        final response = await request.close();
        expect(response.statusCode, 200);
        return jsonDecode(await utf8.decoder.bind(response).join())
            as Map<String, dynamic>;
      } finally {
        client.close(force: true);
      }
    }

    final before = await relay('status');
    expect(before['online'], true);
    try {
      final offline = await relay('offline');
      expect(offline['online'], false);
      expect((offline['dropped'] as int) > (before['dropped'] as int), isTrue,
          reason: 'Existing SDK transport must actually be disconnected');
      await tap(find.text('Save Changes'));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Edit Grocery Item'), findsOneWidget);
      final failed = find
          .text('Could not save grocery item. Please retry.')
          .evaluate()
          .isNotEmpty;
      if (!failed) {
        expect(find.byType(CircularProgressIndicator), findsWidgets);
        expect(
            tester
                .widget<ElevatedButton>(find.byType(ElevatedButton).last)
                .onPressed,
            isNull);
      }
      expect((await relay('status'))['online'], false);
      checkpoint(failed
          ? 'verified relay outage retained failed edit draft'
          : 'verified relay outage retained pending edit and disabled duplicate submit');
    } finally {
      expect((await relay('online'))['online'], true);
    }
    await until(() =>
        find.text('Edit Grocery Item').evaluate().isEmpty ||
        find
            .text('Could not save grocery item. Please retry.')
            .evaluate()
            .isNotEmpty);
    if (find
        .text('Could not save grocery item. Please retry.')
        .evaluate()
        .isNotEmpty) {
      expect(tester.widget<TextField>(field('Quantity')).controller!.text,
          '2 pieces');
      await tap(find.text('Save Changes'));
      checkpoint(
          'visible transaction failure retained draft and ordinary retry requested');
    }
    await until(() => find.text('Edit Grocery Item').evaluate().isEmpty);
    await until(() => manual('Local Herbs')?.quantity == '2 pieces');
    expect(
        GroceryRepository.instance.allItems
            .where((i) => i.name == 'Local Herbs'),
        hasLength(1));
    checkpoint(
        'grocery transaction recovered after verified transport reconnect without duplicate');
    await tap(find.text('Share List'));
    await until(() =>
        find.text('Grocery list copied to clipboard!').evaluate().isNotEmpty);
    final sharedText =
        (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    expect(sharedText.contains('Local Edited Milk (500 g)'), isTrue);
    expect(sharedText.contains('Local Herbs'), isTrue);
    checkpoint(
        'grocery missing quantity retained and native clipboard sharing verified');
    await until(() => find.byType(SnackBar).evaluate().isEmpty);
    await tap(find.text('Clear Used'));
    await tap(find.text('Cancel'));
    expect(manual('Local Edited Milk'), isNotNull);
    await tap(find.text('Clear Used'));
    await tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Clear Used')));
    await until(() => manual('Local Edited Milk') == null);
    expect(manual('Local Herbs'), isNotNull);
    final herbsId = manual('Local Herbs')!.id;
    await tap(find.descendant(
        of: find.byKey(ValueKey(herbsId)),
        matching: find.byTooltip('Remove item')));
    await tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Delete')));
    await until(() => manual('Local Herbs') == null);
    checkpoint(
        'grocery clearing required confirmation and retained unchecked item then delete succeeded');
    await tap(find.text('Profile'));
    await tap(find.text('AI Settings'));
    await tap(
        find.textContaining('Gemini is active as your default provider.'));
    expect(find.textContaining('Gemini is active as your default provider.'),
        findsOneWidget);
    checkpoint(
        'AI settings opened with account default configuration without live provider calls');
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final quota = await LlmService().getRemainingQuota(uid);
    await expectLater(
        LlmService().generateMealPlan(
            uid: uid,
            familyMemberNames: ['Local Member'],
            numberOfDays: 1,
            mealTypes: ['Breakfast'],
            cuisinePreferences: [],
            prioritizePantry: false),
        throwsA(isA<GenerationFailure>().having(
            (e) => e.kind, 'local guard', GenerationFailureKind.localOnly)));
    expect(await LlmService().getRemainingQuota(uid), quota);
    checkpoint(
        'local AI service guard refused live request without quota mutation');
    expect(tester.takeException(), isNull);
  });
}

import 'package:whatmeal/features/meal/pages/meal_detail_page.dart';
import 'package:whatmeal/core/services/llm_service.dart';
import 'package:whatmeal/core/services/ai/generation_failure.dart';
import 'package:whatmeal/core/services/notification_service.dart';
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
import 'package:whatmeal/features/profile/data/family_member_repository.dart';
import 'package:whatmeal/features/meal_plan/data/saved_plans_repository.dart';
import 'package:whatmeal/features/meal/models/meal.dart';
import 'package:whatmeal/features/pantry/data/pantry_repository.dart';
import 'package:whatmeal/features/grocery/data/grocery_repository.dart';
import 'package:whatmeal/features/grocery/models/grocery_item.dart';
import 'package:whatmeal/features/meal_plan/pages/generated_meal_plan_page.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
      'local Android UI registration, verification, household and account switching',
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

    Future<void> login(String email) async {
      await enter('Email Address', email);
      await enter('Password', 'Local-fixture-123!');
      await tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await until(() => find.text('Home').evaluate().isNotEmpty);
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

    // Interrupted device runs can retain native Auth state while the demo
    // backend restarts. Reset through the ordinary app session cleanup.
    await until(() => find.byType(WhatMealApp).evaluate().isNotEmpty);
    await until(() => !AuthRepository.instance.isInitializing);
    await AuthRepository.instance.logout();
    await tester.pumpAndSettle();
    final ownerEmail = await register('Owner');
    await household();
    await until(() => find.byType(FamilySpacePage).evaluate().isNotEmpty);
    await tap(find.text('Create Space'));
    await enter('Family Space Name', 'Local UI Household');
    await tap(find.descendant(
        of: find.byType(BottomSheet), matching: find.text('Create Space')));
    await until(() => FamilyRepository.instance.value != null);
    expect(FamilyRepository.instance.value!.name, 'Local UI Household');
    final familyId = FamilyRepository.instance.value!.id;
    checkpoint('household created');
    final token = await invite();
    await logout();
    final memberEmail = await register('Member');
    expect(FamilyRepository.instance.value, isNull);
    checkpoint('new account has no household');
    await household();
    expect(find.text('Local UI Household'), findsNothing);
    await join(token, familyId);
    checkpoint('member joined shared household');
    await logout();
    await login(ownerEmail);
    await household();
    await until(() => FamilyRepository.instance.value?.members.length == 2);
    final memberTile =
        find.ancestor(of: find.text('Member'), matching: find.byType(ListTile));
    await tap(find.descendant(
        of: memberTile,
        matching: find.byWidgetPredicate((w) => w is PopupMenuButton<String>)));
    await tap(find.text('Remove Member'));
    await tap(find.widgetWithText(ElevatedButton, 'Remove'));
    await until(() => FamilyRepository.instance.value?.members.length == 1);
    checkpoint('owner removed member');
    final rejoinToken = await invite();
    await logout();
    await login(memberEmail);
    await household();
    await until(() => !FamilyRepository.instance.isLoading);
    expect(FamilyRepository.instance.value, isNull);
    expect(find.text('Local UI Household'), findsNothing);
    checkpoint('removed account has no household access');
    await join(rejoinToken, familyId);
    checkpoint('legitimate rejoin');
    await tap(find.byTooltip('Leave Family Space'));
    await tap(find.widgetWithText(ElevatedButton, 'Leave Space'));
    await until(() => FamilyRepository.instance.value == null);
    await until(() => find.text('Local UI Household').evaluate().isEmpty);
    expect(find.text('Local UI Household'), findsNothing);
    checkpoint('member departed');
    await logout();
    await login(ownerEmail);
    await household();
    await until(() => FamilyRepository.instance.value?.members.length == 1);
    checkpoint('owner session restored with one member');
    expect(tester.takeException(), isNull);
    checkpoint('household UI workflow completed');

    await tap(find.byIcon(Icons.arrow_back));
    await tap(find.widgetWithText(TextButton, 'Add'));
    await enter('First Name', 'Local Participant');
    await enter('Age', '30');
    await tap(find.widgetWithText(ElevatedButton, 'Add Family Member'));
    await until(() => FamilyMemberRepository.instance.members
        .any((m) => m.name == 'Local Participant'));
    checkpoint('dietary profile created through UI');

    await tap(find.text('Meal Plan'));
    await tap(find.text('Show'));
    await tap(find.text('Create Own Plan'));
    await tap(find.text('1 Day'));
    await tap(find.text('Lunch'));
    await tap(find.text('Dinner'));
    await tap(find.widgetWithText(ElevatedButton, 'Create Custom Meal Plan'));
    checkpoint('manual plan editor opened');
    // One-day plans start on Monday; the full-week calendar may open on today.
    await tap(find.text('Mon'));
    await tap(find.byTooltip('Edit Dish'));
    await enter('Dish Name', 'Local Rice Meal');
    await enter('Ingredients (comma-separated)', '2 cups rice, 1 carrot');
    await tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
    await tap(find.byTooltip('Save Plan'));
    await enter('Plan Name', 'Local UI Saved Plan');
    await tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, 'Save Plan')));
    await until(() => SavedPlansRepository.instance.value
        .any((p) => p.title == 'Local UI Saved Plan'));
    final saved = SavedPlansRepository.instance.value
        .singleWhere((p) => p.title == 'Local UI Saved Plan');
    expect(saved.meals.single.title, 'Local Rice Meal');
    checkpoint('manual meal plan saved through UI');
    expect(tester.takeException(), isNull);

    final planPath = saved.sourcePath;
    expect(planPath?.startsWith('families/$familyId/mealPlans/'), isTrue);
    expect(saved.startDate?.weekday, DateTime.monday);
    expect(saved.endDate, saved.startDate);
    currentMeal() => SavedPlansRepository.instance.value
        .singleWhere((p) => p.sourcePath == planPath)
        .meals
        .single;
    await tap(find.text('Local Rice Meal'));
    await tap(find.byTooltip('Add favorite'));
    await until(() => currentMeal().isFavorite);
    await until(() => find.byType(SnackBar).evaluate().isEmpty);
    checkpoint('exact saved meal opened and favorited');
    for (final change in [
      ('Mark Completed', MealStatus.completed),
      ('Undo / Mark Accepted', MealStatus.accepted),
      ('Not Completed', MealStatus.notCompleted),
      ('Re-accept', MealStatus.accepted),
    ]) {
      await tap(find.ancestor(
          of: find.text(change.$1),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)));
      await tap(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(ElevatedButton, 'Confirm')));
      await until(() => currentMeal().status == change.$2);
    }
    checkpoint('completed skipped and accepted status changes persisted');
    await tap(find.byTooltip('Back'));
    await tap(find.text('Add Dish to Monday'));
    await enter('Dish Name', 'Local Second Rice Meal');
    await enter('Ingredients (comma-separated)', '1 cup rice, 2 carrots');
    await tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, 'Add Dish')));
    await until(() =>
        SavedPlansRepository.instance.value
            .singleWhere((p) => p.sourcePath == planPath)
            .meals
            .length ==
        2);
    checkpoint('second accepted meal added through UI');
    await tap(find.byIcon(Icons.arrow_back));

    await tap(find.text('Pantry'));
    await tap(find.text('Add Ingredient'));
    await enter('Ingredient Name', 'rice');
    await enter('Quantity (e.g. 1.2 kg, 4 units)', '3 cups');
    await tap(find.text('Select expiration date'));
    await tap(find.widgetWithText(TextButton, 'OK'));
    await tap(find.widgetWithText(FilledButton, 'Add to Pantry'));
    await until(() => PantryRepository.instance.items.values
        .expand((v) => v)
        .any((p) => p.name == 'rice' && p.quantity == '3 cups'));
    checkpoint('pantry quantity unit and expiration saved through UI');
    await tap(find.text('Grocery'));
    riceRequirement() => GroceryRepository.instance.sections.values
        .expand((v) => v)
        .singleWhere((i) => i.name == 'rice');
    await until(() => GroceryRepository.instance.sections.values
        .expand((v) => v)
        .any((i) => i.name == 'rice' && i.status == GroceryStatus.available));
    expect(riceRequirement().sourceMealPaths, hasLength(2));
    expect(riceRequirement().sourceMealPaths,
        contains('$planPath/meals/${saved.meals.single.id}'));
    expect(riceRequirement().quantity, '0 cup');
    checkpoint('sufficient pantry stock excluded from shopping needs');
    await tap(find.text('Pantry'));
    await tap(find.byTooltip('Item options'));
    await tap(find.text('Edit Item'));
    await enter('Quantity (e.g. 1.2 kg, 4 units)', '1 cup');
    await tap(find.widgetWithText(FilledButton, 'Save Changes'));
    await until(() => PantryRepository.instance.items.values
        .expand((v) => v)
        .any((p) => p.name == 'rice' && p.quantity == '1 cup'));
    await tap(find.text('Grocery'));
    await until(() =>
        riceRequirement().status == GroceryStatus.needed &&
        riceRequirement().quantity == '2 cup');
    checkpoint('pantry edit recalculated exact grocery shortage');

    await household();
    final dataInvite = await invite();
    await logout();
    await login(memberEmail);
    await until(() => !FamilyRepository.instance.isLoading);
    expect(FamilyRepository.instance.value, isNull);
    expect(SavedPlansRepository.instance.value, isEmpty);
    expect(PantryRepository.instance.items, isEmpty);
    expect(GroceryRepository.instance.sections, isEmpty);
    checkpoint('account switch cleared previous meal pantry and grocery data');
    await household();
    await join(dataInvite, familyId);
    await tap(find.byIcon(Icons.arrow_back));
    await tap(find.text('Pantry'));
    await until(() => PantryRepository.instance.items.values
        .expand((v) => v)
        .any((p) => p.name == 'rice' && p.quantity == '1 cup'));
    await until(() => find.text('rice').evaluate().isNotEmpty);
    await tap(find.text('Grocery'));
    await until(() => riceRequirement().quantity == '2 cup');
    checkpoint('authorized member received shared pantry and grocery updates');
    await tap(find.text('Meal Plan'));
    await tap(find.text('Saved'));
    await until(() => find.text('Local UI Saved Plan').evaluate().isNotEmpty);
    await tap(find.widgetWithText(ElevatedButton, 'Load Plan'));
    await tap(find.text('Mon'));
    final secondCard = find.ancestor(
        of: find.text('Local Second Rice Meal'),
        matching: find.byType(GeneratedMealCard));
    await tap(find.descendant(
        of: secondCard, matching: find.byTooltip('Remove Dish')));
    await tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Remove')));
    await until(() =>
        SavedPlansRepository.instance.value
            .singleWhere((p) => p.sourcePath == planPath)
            .meals
            .length ==
        1);
    await tap(find.byIcon(Icons.arrow_back));
    await tap(find.byIcon(Icons.arrow_back));
    await tap(find.text('Grocery'));
    await until(() => riceRequirement().quantity == '1 cup');
    expect(riceRequirement().sourceMealPaths.single,
        '$planPath/meals/${saved.meals.single.id}');
    checkpoint(
        'member meal deletion preserved other meal grocery contribution');
    await tap(find.text('Meal Plan'));
    await tap(find.text('Saved'));
    await tap(find.widgetWithText(TextButton, 'Reuse'));
    await tap(find.text('Mon'));
    await tap(find.byTooltip('Save Plan'));
    await enter('Plan Name', 'Local UI Reused Plan');
    await tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, 'Save Plan')));
    await until(() => SavedPlansRepository.instance.value
        .any((p) => p.title == 'Local UI Reused Plan'));
    final reused = SavedPlansRepository.instance.value
        .singleWhere((p) => p.title == 'Local UI Reused Plan');
    expect(reused.sourcePath == planPath, isFalse);
    expect(reused.meals.single.id == saved.meals.single.id, isFalse);
    expect(reused.meals.single.status, MealStatus.pending);
    reusedMeal() => SavedPlansRepository.instance.value
        .singleWhere((p) => p.sourcePath == reused.sourcePath)
        .meals
        .single;
    await tap(find.text('Local Rice Meal'));
    await until(() => find.byType(SnackBar).evaluate().isEmpty);
    await tap(find.widgetWithText(ElevatedButton, 'Accept Meal'));
    await tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, 'Confirm')));
    await until(() => reusedMeal().status == MealStatus.accepted);
    await tap(find.widgetWithText(ElevatedButton, 'Mark Completed'));
    await tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, 'Confirm')));
    await until(() => reusedMeal().status == MealStatus.completed);
    expect(currentMeal().status, MealStatus.accepted);
    checkpoint(
        'reused plan pending acceptance and completion isolated from original');
    await tap(find.byTooltip('Back'));
    await tap(find.byIcon(Icons.arrow_back));
    await tap(find.byTooltip('Meal History'));
    await tap(find.byKey(
        ValueKey('history:${reused.sourcePath}:${reused.meals.single.id}')));
    final historyDetail =
        tester.widget<MealDetailPage>(find.byType(MealDetailPage));
    expect(historyDetail.planPath, reused.sourcePath);
    expect(historyDetail.mealId, reused.meals.single.id);
    checkpoint('history opened exact reused meal identity');
    await tap(find.byTooltip('Back'));
    await tap(find.byIcon(Icons.arrow_back));
    await tap(find.byIcon(Icons.arrow_back));
    await logout(fromHousehold: false);
    await login(ownerEmail);
    await until(() => NotificationService.instance.value
        .any((n) => n.relatedPlanId == reused.id));
    final completedEvent = NotificationService.instance.value.firstWhere((n) =>
        n.relatedPlanId == reused.id &&
        n.navigationParameters?['mealId'] == reused.meals.single.id);
    final unread = NotificationService.instance.unreadCount;
    expect(unread, greaterThan(0));
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('notification-unread-badge')),
            matching: find.text(unread > 9 ? '9+' : unread.toString())),
        findsOneWidget);
    await tap(find.byIcon(Icons.notifications_none));
    await tap(find.byKey(ValueKey('notification:${completedEvent.id}')));
    final notificationDetail =
        tester.widget<MealDetailPage>(find.byType(MealDetailPage));
    expect(notificationDetail.planPath, reused.sourcePath);
    expect(notificationDetail.mealId, reused.meals.single.id);
    await until(() => NotificationService.instance.value
        .any((n) => n.id == completedEvent.id && n.read));
    checkpoint(
        'shared meal notification routed exact plan and persisted private read receipt');
    await tap(find.byTooltip('Back'));
    await tap(find.text('Mark all read'));
    await until(() => NotificationService.instance.unreadCount == 0);
    expect(find.text('Mark all read'), findsNothing);
    checkpoint('notification history mark all read cleared unread count');
    await tap(find.byIcon(Icons.arrow_back));
    await until(() => find
        .byKey(const ValueKey('notification-unread-badge'))
        .evaluate()
        .isEmpty);
    await logout(fromHousehold: false);
    await login(memberEmail);
    await tap(find.text('Meal Plan'));
    await tap(find.text('Saved'));
    await tap(find.descendant(
        of: find.byKey(ValueKey('actions:${reused.sourcePath}')),
        matching: find.widgetWithText(TextButton, 'Delete')));
    await tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, 'Delete Plan')));
    await until(() => SavedPlansRepository.instance.value
        .every((p) => p.sourcePath != reused.sourcePath));
    expect(currentMeal().title, 'Local Rice Meal');
    await tap(find.descendant(
        of: find.byKey(ValueKey('actions:$planPath')),
        matching: find.widgetWithText(TextButton, 'Delete')));
    await tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, 'Delete Plan')));
    await until(() => SavedPlansRepository.instance.value
        .every((p) => p.sourcePath != planPath));
    await tap(find.byIcon(Icons.arrow_back));
    await tap(find.text('Grocery'));
    await until(() => GroceryRepository.instance.sections.values
        .expand((v) => v)
        .every((i) =>
            i.sourceMealPaths.every((p) => !p.startsWith('$planPath/'))));
    checkpoint('saved plan deletion removed only its grocery provenance');
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

import 'dart:async';
import 'package:whatmeal/features/profile/pages/profile_page.dart';
import 'package:whatmeal/features/grocery/pages/grocery_page.dart';
import 'package:whatmeal/features/grocery/data/grocery_store.dart';
import 'package:whatmeal/features/grocery/models/grocery_item.dart';
import 'package:whatmeal/features/meal_plan/pages/saved_meal_plans_page.dart';
import 'package:whatmeal/features/meal_plan/data/saved_plans_repository.dart';
import 'package:whatmeal/features/meal_plan/data/saved_plan_stream.dart';
import 'package:whatmeal/features/meal_plan/models/saved_meal_plan.dart';
import 'package:whatmeal/features/meal_plan/models/meal_plan.dart';
import 'package:whatmeal/features/meal/models/meal.dart';
import 'package:whatmeal/features/auth/models/account_action_failure.dart';
import 'package:whatmeal/features/grocery/data/grocery_repository.dart';
import 'package:whatmeal/features/family/models/family_space.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
      'local Android terminal feed UI recovery and delayed account operations',
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

    await until(() => find.byType(WhatMealApp).evaluate().isNotEmpty);
    await until(() => !AuthRepository.instance.isInitializing);
    expect(Firebase.app().options.projectId, 'demo-whatmeal-audit');
    await AuthRepository.instance.logout();
    await tester.pumpAndSettle();
    final ownerEmail = await register('TerminalOwner');
    final ownerUid = FirebaseAuth.instance.currentUser!.uid;
    await tap(find.text('Profile'));
    await tap(find.text('Sign Out'));
    await tap(find.widgetWithText(ElevatedButton, 'Log Out'));
    final otherEmail = await register('TerminalOther');
    final otherUid = FirebaseAuth.instance.currentUser!.uid;
    await tap(find.text('Profile'));
    await tap(find.text('Sign Out'));
    await tap(find.widgetWithText(ElevatedButton, 'Log Out'));
    await enter('Email Address', ownerEmail);
    await enter('Password', 'Local-fixture-123!');
    await tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await until(() => AuthRepository.instance.value?.id == ownerUid);
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    final denials = <String>[];
    Stream<T> capture<T>(Stream<T> source) => source.handleError((Object e) {
          if (e is FirebaseException) denials.add(e.code);
          throw e;
        });
    var denyProfile = true;
    final profile = AuthRepository(
        auth: auth,
        firestore: db,
        watchProfile: (uid) => capture(db
            .doc('users/${denyProfile ? 'stage13-forbidden-outsider' : uid}')
            .snapshots()));
    await until(() => profile.profileError != null);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ProfilePage(authRepository: profile))));
    await tap(find.text('Retry Account Profile'));
    // Denied again proves Retry actually reopens rather than only clearing text.
    await until(() => profile.profileError != null);
    denyProfile = false;
    await tap(find.text('Retry Account Profile'));
    await until(() =>
        profile.profileError == null && profile.value?.name == 'TerminalOwner');
    checkpoint(
        'Auth profile real SDK terminal denial recovered through visible Retry Account Profile');
    final household = ValueNotifier<FamilySpace?>(null);
    final plans = ValueNotifier<List<SavedMealPlan>>([]);
    final pantry = ValueNotifier<Map<String, List<PantryItem>>>({});
    await GroceryStore(db).initialize(
        db.collection('users/$ownerUid/groceryLists'), 'Shopping List');
    await GroceryStore(db).addUnique(
        db.doc('users/$ownerUid/groceryLists/default'),
        [GroceryItem(name: 'Terminal Milk', quantity: '2 cups')]);
    var denyItems = true;
    var denyParents = false;
    final grocery = GroceryRepository(
        firestore: db,
        authIds: auth.authStateChanges().map((u) => u?.uid),
        household: household,
        plans: plans,
        pantry: pantry,
        pantryScope: () => null,
        canEdit: () => true,
        watchParents: (q) => capture(denyParents
            ? db
                .collection('users/stage13-forbidden-outsider/groceryLists')
                .snapshots()
            : q.snapshots()),
        watchItems: (col) => capture((denyItems
                    ? db.collection(
                        'users/stage13-forbidden-outsider/groceryLists/default/items')
                    : col)
                .snapshots())
            .map((s) => s.docs.map(GroceryItem.fromFirestore).toList()));
    await until(() => grocery.error != null);
    await tester
        .pumpWidget(MaterialApp(home: GroceryPage(repository: grocery)));
    denyItems = false;
    await tap(find.widgetWithText(ElevatedButton, 'Retry'));
    await until(() =>
        grocery.error == null &&
        grocery.allItems.any((i) => i.name == 'Terminal Milk'));
    expect(find.text('Terminal Milk'), findsOneWidget);
    checkpoint(
        'grocery item real SDK terminal denial recovered through visible Retry');
    denyParents = true;
    grocery.retry();
    await until(() => grocery.error != null);
    denyParents = false;
    await tap(find.widgetWithText(ElevatedButton, 'Retry'));
    await until(() =>
        grocery.error == null &&
        grocery.allItems.any((i) => i.name == 'Terminal Milk'));
    checkpoint(
        'grocery parent real SDK terminal denial recovered through visible Retry');
    await tap(find.byTooltip('Edit item'));
    await enter('Item Name', 'Obsolete editor draft');
    await auth.signOut();
    await auth.signInWithEmailAndPassword(
        email: otherEmail, password: 'Local-fixture-123!');
    await until(() => grocery.scopePath == 'users/$otherUid');
    await auth.signOut();
    await auth.signInWithEmailAndPassword(
        email: ownerEmail, password: 'Local-fixture-123!');
    await until(() =>
        grocery.scopePath == 'users/$ownerUid' &&
        grocery.allItems.any((i) => i.name == 'Terminal Milk'));
    await tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
    await until(() => find
        .text(
            'Your account or household changed. Close this editor and reopen it.')
        .evaluate()
        .isNotEmpty);
    final unchangedGroceries = await db
        .collection('users/$ownerUid/groceryLists/default/items')
        .get(const GetOptions(source: Source.server));
    expect(
        unchangedGroceries.docs
            .any((d) => d.data()['name'] == 'Obsolete editor draft'),
        false);
    expect(
        unchangedGroceries.docs.any((d) => d.data()['name'] == 'Terminal Milk'),
        true);
    await tap(find.byTooltip('Close'));
    checkpoint(
        'open grocery editor rejected an obsolete draft after native A B A without changing stored groceries');
    final account = AuthRepository.instance;
    final writer = SavedPlansRepository(
        firestore: db,
        account: account,
        household: household,
        canEditShared: () => true);
    final planId = await writer.savePlan(
        MealPlan(
            id: '',
            title: 'Terminal Plan',
            createdBy: ownerUid,
            numberOfDays: 1,
            startDate: DateTime(2026, 10, 17),
            mealTypes: ['Dinner']),
        [
          Meal(id: 'terminal-meal', title: 'Terminal Soup', mealType: 'Dinner')
        ]);
    writer.dispose();
    var denyPlanParent = true;
    var denyNested = false;
    final saved = SavedPlansRepository(
        firestore: db,
        account: account,
        household: household,
        canEditShared: () => true,
        watch: (q) => capture(watchSavedPlans(
            denyPlanParent
                ? db.collection('users/stage13-forbidden-outsider/mealPlans')
                : q,
            watchMeals: (mq) => capture(denyNested
                ? db
                    .collection(
                        'users/stage13-forbidden-outsider/mealPlans/p/meals')
                    .snapshots()
                : mq.snapshots()))));
    await until(() => saved.error != null);
    await tester
        .pumpWidget(MaterialApp(home: SavedMealPlansPage(repository: saved)));
    denyPlanParent = false;
    denyNested = true;
    await tap(find.text('Retry Saved Plans'));
    await until(() => saved.error != null);
    checkpoint(
        'saved-plan parent denial exposes safe Retry and nested denial is surfaced');
    denyNested = false;
    await tap(find.text('Retry Saved Plans'));
    await until(() =>
        saved.error == null &&
        saved.value.any(
            (p) => p.id == planId && p.meals.single.title == 'Terminal Soup'));
    expect(find.text('Terminal Plan'), findsOneWidget);
    checkpoint(
        'nested saved-plan real SDK terminal denial recovered through visible Retry with exact plan identity');
    await tap(find.widgetWithText(TextButton, 'Delete'));
    await auth.signOut();
    await auth.signInWithEmailAndPassword(
        email: otherEmail, password: 'Local-fixture-123!');
    await until(() => saved.value.isEmpty && account.value?.id == otherUid);
    await auth.signOut();
    await auth.signInWithEmailAndPassword(
        email: ownerEmail, password: 'Local-fixture-123!');
    await until(() => saved.value.any((p) => p.id == planId));
    await tap(find.widgetWithText(ElevatedButton, 'Delete Plan'));
    await until(() => find
        .text('Could not delete plan. Please retry.')
        .evaluate()
        .isNotEmpty);
    expect(
        (await db
                .doc('users/$ownerUid/mealPlans/$planId')
                .get(const GetOptions(source: Source.server)))
            .exists,
        true);
    checkpoint(
        'stale saved-plan deletion confirmation rejected after native A B A with original plan intact');
    denyPlanParent = true;
    saved.retry();
    final dependentGrocery = GroceryRepository(
        firestore: db,
        authIds: auth.authStateChanges().map((u) => u?.uid),
        household: household,
        plans: saved,
        pantry: pantry,
        pantryScope: () => null,
        canEdit: () => true);
    await until(
        () => dependentGrocery.error != null && !dependentGrocery.isLoading);
    await tester.pumpWidget(
        MaterialApp(home: GroceryPage(repository: dependentGrocery)));
    expect(
        find.text(
            'Meal shopping requirements could not be loaded. Please retry.'),
        findsOneWidget);
    final sameSession = saved.sessionVersion;
    denyPlanParent = false;
    denyNested = false;
    await tap(find.widgetWithText(ElevatedButton, 'Retry'));
    await until(() =>
        dependentGrocery.error == null &&
        !dependentGrocery.isLoading &&
        dependentGrocery.allItems.any((i) => i.name == 'Terminal Milk') &&
        saved.value.any((p) => p.id == planId));
    expect(saved.sessionVersion, sameSession);
    checkpoint(
        'grocery surfaced upstream saved-plan denial and visible Retry restored both feeds without changing account session');
    final cleanup = Completer<void>();
    final delayedAuth = AuthRepository(
        auth: auth,
        firestore: db,
        cleanupNotifications: () => cleanup.future,
        clearKey: (_) async {});
    await until(() => delayedAuth.value?.id == ownerUid);
    final logout = delayedAuth.logout();
    final logoutAssertion =
        expectLater(logout, throwsA(isA<AccountActionFailure>()));
    await auth.signOut();
    await auth.signInWithEmailAndPassword(
        email: otherEmail, password: 'Local-fixture-123!');
    await until(() => delayedAuth.value?.id == auth.currentUser?.uid);
    expect(auth.currentUser!.uid, otherUid);
    cleanup.complete();
    await logoutAssertion;
    expect(auth.currentUser?.uid == otherUid, isTrue);
    expect(saved.value, isEmpty);
    expect(grocery.allItems, isEmpty);
    checkpoint(
        'delayed logout cleanup rejected obsolete completion without signing out new native account');
    delayedAuth.dispose();
    await auth.signOut();
    await auth.signInWithEmailAndPassword(
        email: ownerEmail, password: 'Local-fixture-123!');
    await until(() => account.value?.id == ownerUid);
    final gate = Completer<void>();
    var first = true;
    final delayedGrocery = GroceryRepository(
        firestore: db,
        authIds: auth.authStateChanges().map((u) => u?.uid),
        household: household,
        plans: plans,
        pantry: pantry,
        pantryScope: () => null,
        canEdit: () => true,
        initialize: (col, title) async {
          if (first) {
            first = false;
            await gate.future;
          } else {
            await GroceryStore(db).initialize(col, title);
          }
        });
    await until(() => delayedGrocery.scopePath == 'users/$ownerUid');
    final add = delayedGrocery
        .addMultipleItems([GroceryItem(name: 'Obsolete draft', quantity: '9')]);
    final addAssertion = expectLater(add, throwsStateError);
    await auth.signOut();
    await auth.signInWithEmailAndPassword(
        email: otherEmail, password: 'Local-fixture-123!');
    await until(() => delayedGrocery.scopePath == 'users/$otherUid');
    await auth.signOut();
    await auth.signInWithEmailAndPassword(
        email: ownerEmail, password: 'Local-fixture-123!');
    await until(() => delayedGrocery.scopePath == 'users/$ownerUid');
    gate.completeError(StateError('synthetic local delayed failure'));
    await addAssertion;
    expect(delayedGrocery.error, isNull);
    final own = await db
        .collection('users/$ownerUid/groceryLists/default/items')
        .get(const GetOptions(source: Source.server));
    expect(own.docs.any((d) => d.data()['name'] == 'Obsolete draft'), false);
    checkpoint(
        'failing delayed grocery initialization and pending add rejected after real native A B A transitions');
    expect(denials.where((code) => code == 'permission-denied').length,
        greaterThanOrEqualTo(5));
    binding.reportData!['sdkPermissionDenials'] =
        denials.where((code) => code == 'permission-denied').length;
    delayedGrocery.dispose();
    dependentGrocery.dispose();
    saved.dispose();
    grocery.dispose();
    profile.dispose();
    await tester.pumpWidget(const SizedBox());
    household.dispose();
    plans.dispose();
    pantry.dispose();
  }, timeout: const Timeout(Duration(minutes: 10)));
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whatmeal/app.dart';
import 'package:whatmeal/core/config/runtime_environment.dart';
import 'package:whatmeal/core/services/ai/generation_failure.dart';
import 'package:whatmeal/features/ai_settings/data/ai_provider_repository.dart';
import 'package:whatmeal/features/ai_settings/models/ai_provider.dart';
import 'package:whatmeal/features/auth/data/auth_repository.dart';
import 'package:whatmeal/features/auth/pages/login_page.dart';
import 'package:whatmeal/features/family/data/family_repository.dart';
import 'package:whatmeal/features/meal/pages/meal_detail_page.dart';
import 'package:whatmeal/features/meal_plan/data/saved_plans_repository.dart';
import 'package:whatmeal/features/meal_plan/pages/generated_meal_plan_page.dart';
import 'package:whatmeal/features/meal_plan/pages/saved_meal_plans_page.dart';
import 'package:whatmeal/features/profile/data/family_member_repository.dart';
import 'package:whatmeal/main.dart' as app;
import 'support/firestore_batch_capture.dart';

/// Run generate once, then rebuild with CLOUD_ACCEPTANCE_PHASE=reopen and the
/// recorded IDs. The runner must force-stop only .cloudtest between phases.
/// No emulator, REST AI call, or injected meal result is used by this harness.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
      'cloudtest live UI generation and persisted exact-plan acceptance',
      (tester) async {
    expect(appFlavor, 'cloudtest',
        reason: 'Refuse every existing app package.');
    expect(useFirebaseEmulators, isFalse);
    const project = 'whatmeal-gemini-test-20261019';
    const phase = String.fromEnvironment('CLOUD_ACCEPTANCE_PHASE',
        defaultValue: 'generate');
    expect(['generate', 'reopen'], contains(phase));
    const accounts = {
      'owner': (
        email: String.fromEnvironment('CLOUD_OWNER_EMAIL'),
        password: String.fromEnvironment('CLOUD_OWNER_PASSWORD'),
      ),
      'outsider': (
        email: String.fromEnvironment('CLOUD_OUTSIDER_EMAIL'),
        password: String.fromEnvironment('CLOUD_OUTSIDER_PASSWORD'),
      ),
    };
    for (final account in accounts.values) {
      expect(account.email.endsWith('@example.test'), isTrue,
          reason: 'Use only the approved disposable test-project accounts.');
      expect(account.password.isNotEmpty, isTrue,
          reason: 'Supply credentials through an ignored defines file.');
    }
    var planId = const String.fromEnvironment('CLOUD_ACCEPTANCE_PLAN_ID');
    var mealId = const String.fromEnvironment('CLOUD_ACCEPTANCE_MEAL_ID');
    const planTitle = String.fromEnvironment('CLOUD_ACCEPTANCE_PLAN_TITLE',
        defaultValue: 'Cloud Gemini Acceptance');
    final checkpoints = <String>[];
    binding.reportData = {
      'phase': phase,
      'projectId': project,
      'completedPhases': checkpoints,
      'authentication':
          'normal Android sign-in UI; accounts preverified by test-project admin',
      'generationButtonTaps': 0,
      'savePlanButtonTaps': 0,
      'liveGenerationObserved': false,
      'serverPersistenceVerified': false,
      'outsiderDenied': false,
    };
    void checkpoint(String message) {
      checkpoints.add(message);
      debugPrint('Cloud acceptance checkpoint: $message');
    }

    Future<void> until(bool Function() ready, String stage,
        {int attempts = 200}) async {
      for (var i = 0; i < attempts; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        if (ready()) return;
      }
      fail(
          'Timed out during $stage. No retry or failure dismissal was automated.');
    }

    Future<void> reveal(Finder finder) async {
      for (final offset in [400.0, -400.0]) {
        for (var i = 0;
            i < 20 &&
                finder.evaluate().isEmpty &&
                find.byType(Scrollable).evaluate().isNotEmpty;
            i++) {
          final vertical = find.byType(Scrollable).evaluate().where((element) =>
              (element.widget as Scrollable).axisDirection ==
              AxisDirection.down);
          if (vertical.isEmpty) break;
          await tester.drag(
              find.byWidget(vertical.last.widget), Offset(0, offset));
          await tester.pump(const Duration(milliseconds: 200));
        }
      }
      await until(
          () => finder.evaluate().isNotEmpty, 'locating an app control');
      await tester.ensureVisible(finder.first);
      await tester.pumpAndSettle(const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate, const Duration(seconds: 10));
      expect(finder.first.hitTestable(), findsOneWidget,
          reason: 'The actual app control must be visible and receive taps.');
    }

    Future<void> tap(Finder finder) async {
      await reveal(finder);
      await tester.tap(finder.first);
      await tester.pump(const Duration(milliseconds: 250));
    }

    Finder field(String label) => find.byWidgetPredicate((widget) =>
        widget is TextField && widget.decoration?.labelText == label);
    Future<void> enter(String label, String value) async {
      await reveal(field(label));
      await tester.enterText(field(label), value);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<TextField>(field(label)).controller?.text == value,
          isTrue,
          reason: 'Input must be retained; its value is never printed.');
    }

    tester.testTextInput.register();
    addTearDown(tester.testTextInput.unregister);
    app.main();
    await until(() => find.byType(WhatMealApp).evaluate().isNotEmpty,
        'cloudtest application startup');
    expect(Firebase.app().options.projectId == project, isTrue,
        reason: 'Refuse any other Firebase project before account operations.');
    final auth = AuthRepository.instance;
    final plans = SavedPlansRepository.instance;
    final profiles = FamilyMemberRepository.instance;
    final ai = AiProviderRepository.instance;
    await until(() => !auth.isInitializing, 'initial authentication state');
    // Only startup normalization uses the SDK; subsequent switches use Log Out.
    await auth.logout();
    await until(() => find.byType(LoginPage).evaluate().isNotEmpty,
        'initial sign-in screen');

    Future<void> login(String role) async {
      final account = accounts[role]!;
      await enter('Email Address', account.email);
      await enter('Password', account.password);
      await tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await until(
          () =>
              !auth.isInitializing &&
              auth.isAuthenticated &&
              find.text('Home').evaluate().isNotEmpty,
          'verified disposable sign-in');
      expect(auth.isEmailVerified, isTrue,
          reason:
              'Real email delivery is not exercised; admin preverification is required.');
      await until(() => !plans.isLoading && !profiles.isLoading,
          'account-scoped Firestore listeners');
      expect(plans.error == null && profiles.error == null, isTrue,
          reason: 'Listener errors must not be interpreted as empty data.');
      expect(FamilyRepository.instance.value == null, isTrue,
          reason: 'This acceptance uses separate personal test workspaces.');
    }

    Future<void> shell() async {
      for (var i = 0; i < 5 && find.text('Profile').evaluate().isEmpty; i++) {
        final back = find.byIcon(Icons.arrow_back).evaluate().isNotEmpty
            ? find.byIcon(Icons.arrow_back)
            : find.byIcon(Icons.chevron_left);
        await tap(back);
      }
      expect(find.text('Profile'), findsWidgets);
    }

    Future<void> logout() async {
      await shell();
      await tap(find.text('Profile'));
      await tap(find.text('Sign Out'));
      await tap(find.widgetWithText(ElevatedButton, 'Log Out'));
      await until(() => find.byType(LoginPage).evaluate().isNotEmpty,
          'normal account-switch logout');
    }

    await login('owner');
    checkpoint(
        'owner signed in through normal UI to the approved cloud project');
    final ownerUid = FirebaseAuth.instance.currentUser!.uid;
    if (phase == 'generate') {
      expect(plans.value.isEmpty, isTrue,
          reason:
              'An existing plan requires reopen phase; do not generate a second successful plan.');
      await tap(find.text('Profile'));
      if (!profiles.members
          .any((member) => member.name == 'Cloud Participant')) {
        await tap(find.widgetWithText(TextButton, 'Add'));
        await enter('First Name', 'Cloud Participant');
        await enter('Age', '30');
        await tap(find.widgetWithText(ElevatedButton, 'Add Family Member'));
        await until(
            () => profiles.members
                .any((member) => member.name == 'Cloud Participant'),
            'synthetic participant persistence');
      }
      expect(profiles.members.length, 1,
          reason:
              'The bounded request plans for one synthetic participant only.');
      await until(() => !ai.isSaving, 'default provider settings');
      expect(ai.value.providerType, AiProviderType.gemini);
      expect(ai.value.apiKey == null, isTrue,
          reason: 'Use Firebase AI Logic, never a custom provider credential.');
      binding.reportData!['requestedModel'] = ai.value.selectedModel;
      await tap(find.text('Meal Plan'));
      await tap(find.text('Show'));
      await tap(find.text('1 Day'));
      await tap(find.text('Breakfast'));
      await tap(find.text('Lunch'));
      await tap(find.widgetWithText(FilterChip, 'Filipino'));
      checkpoint(
          'normal AI form configured for one participant one day Dinner');
      final captureErrors = <String>[];
      final capture = FirestoreBatchCapture(
        ownerUid: ownerUid,
        onChanged: (privateBatches, summaries) {
          binding.reportData!['_privateFirestoreBatches'] = privateBatches;
          binding.reportData!['firestoreBatchSummaries'] = summaries;
        },
        onDiagnosticError: (code) {
          captureErrors.add(code);
          binding.reportData!['batchCaptureErrors'] = captureErrors;
        },
      );
      capture.install(binding.defaultBinaryMessenger);
      addTearDown(capture.dispose);
      await tap(find.widgetWithText(ElevatedButton, 'Generate AI Meal Plan'));
      binding.reportData!['generationButtonTaps'] = 1;
      // Never tap Retry: preserve the first live result, including failed calls.
      for (var i = 0;
          i < 900 && find.byType(GeneratedMealPlanPage).evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 200));
        if (find.byType(AlertDialog).evaluate().isNotEmpty &&
            find.text('Generating AI Meal Plan').evaluate().isEmpty) {
          final kinds = GenerationFailureKind.values.where((kind) => find
              .text(GenerationFailure(kind).toString())
              .evaluate()
              .isNotEmpty);
          binding.reportData!['generationFailureKind'] =
              kinds.isEmpty ? 'unclassified_error_dialog' : kinds.first.name;
          fail(
              'The app reported a live generation failure. No retry was submitted.');
        }
      }
      expect(find.byType(GeneratedMealPlanPage), findsOneWidget,
          reason: 'A timeout or interrupted generation is not a pass.');
      // Generation may succeed while its first persistence attempt fails. Read
      // the genuine retained editor draft before requiring a saved-plan echo.
      final generated = tester
          .widget<GeneratedMealPlanPage>(find.byType(GeneratedMealPlanPage))
          .draft;
      expect(generated != null && generated.meals.length == 1, isTrue,
          reason: 'The real editor must retain the single generated recipe.');
      final generatedMeal = generated!.meals.single;
      expect(
          generatedMeal.id.isNotEmpty &&
              generatedMeal.ingredients.isNotEmpty &&
              generatedMeal.instructions.isNotEmpty,
          isTrue);
      expect(
          generated.numberOfDays == 1 &&
              generatedMeal.type.toLowerCase() == 'dinner' &&
              generatedMeal.dayIndex == 0,
          isTrue);
      expect(generated.sourceSessionVersion == plans.sessionVersion, isTrue);
      expect(
          generated.initialSaveFailed == (generated.planPath == null), isTrue);
      mealId = generatedMeal.id;
      if (generated.planPath != null) {
        expect(generated.planPath!.startsWith('users/$ownerUid/mealPlans/'),
            isTrue);
        planId = generated.planPath!.split('/').last;
      }
      binding.reportData!.addAll({
        if (planId.isNotEmpty) 'planId': planId,
        'mealId': mealId,
        'planTitle': generated.title,
        'liveGenerationObserved': true,
        'initialSaveFailed': generated.initialSaveFailed,
      });
      await until(
          () => find
              .textContaining('Generated with Gemini (')
              .evaluate()
              .isNotEmpty,
          'actual provider/model disclosure',
          attempts: 20);
      expect(find.textContaining('Generated with Gemini ('), findsOneWidget,
          reason: 'The UI must disclose actual provider/model fulfillment.');
      checkpoint(
          'live Firebase AI result reached the genuine editor independently of persistence');
      await tap(find.byTooltip('Save Plan'));
      await enter('Plan Name', planTitle);
      await tap(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(ElevatedButton, 'Save Plan')));
      binding.reportData!['savePlanButtonTaps'] = 1;
      bool savedExactRecipe() =>
          plans.value.length == 1 &&
          plans.value.single.title == planTitle &&
          plans.value.single.meals.length == 1 &&
          plans.value.single.meals.single.id == mealId &&
          find.byType(AlertDialog).evaluate().isEmpty;
      const saveError =
          'Could not save meal plan. Complete the meal names and retry.';
      await until(
          () =>
              savedExactRecipe() || find.text(saveError).evaluate().isNotEmpty,
          'ordinary Save Plan persistence or explicit failure');
      final saveFailed = find.text(saveError).evaluate().isNotEmpty;
      binding.reportData!['saveFailureObserved'] = saveFailed;
      expect(saveFailed, isFalse,
          reason:
              'Save Plan reported a failure; no further AI request or retry was submitted.');
      expect(savedExactRecipe(), isTrue);
      planId = plans.value.single.id;
      expect(
          plans.value.single.sourcePath == 'users/$ownerUid/mealPlans/$planId',
          isTrue);
      expect(binding.reportData!['generationButtonTaps'], 1,
          reason: 'Saving the retained recipe must not generate it again.');
      binding.reportData!.addAll({'planId': planId, 'planTitle': planTitle});
      checkpoint(
          'ordinary Save Plan persisted the same generated meal without another AI request');
    } else {
      expect(planId.isNotEmpty && mealId.isNotEmpty, isTrue,
          reason: 'Reopen requires IDs from the actual first-run evidence.');
    }
    expect(!planId.contains('/') && !mealId.contains('/'), isTrue);
    final planPath = 'users/$ownerUid/mealPlans/$planId';
    final planRef = FirebaseFirestore.instance.doc(planPath);
    final serverPlan = await planRef
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 30));
    final serverMeals = await planRef
        .collection('meals')
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 30));
    expect(
        serverPlan.metadata.hasPendingWrites || serverPlan.metadata.isFromCache,
        isFalse,
        reason: 'A pending local echo is not server persistence.');
    expect(
        serverMeals.metadata.hasPendingWrites ||
            serverMeals.metadata.isFromCache,
        isFalse,
        reason: 'Pending cached meals are not a successful server save.');
    expect(serverPlan.exists, isTrue);
    expect(serverPlan.data()?['title'] == planTitle, isTrue);
    expect(serverPlan.data()?['createdBy'] == ownerUid, isTrue);
    expect(serverPlan.data()?['numberOfDays'] == 1, isTrue);
    expect(serverPlan.data()?['mealTypes'].toString() == '[Dinner]', isTrue);
    expect(serverPlan.data()?['startDate'] == serverPlan.data()?['endDate'],
        isTrue);
    expect(serverMeals.docs.length, 1);
    final serverMeal = serverMeals.docs.single;
    expect(serverMeal.id == mealId, isTrue);
    expect((serverMeal.data()['mealType'] as String).toLowerCase() == 'dinner',
        isTrue);
    expect(serverMeal.data()['dayIndex'] == 0, isTrue);
    expect((serverMeal.data()['ingredients'] as List).isNotEmpty, isTrue);
    expect((serverMeal.data()['instructions'] as List).isNotEmpty, isTrue);
    expect((serverMeal.data()['title'] as String).trim().isNotEmpty, isTrue);
    binding.reportData!.addAll({
      'planId': planId,
      'mealId': mealId,
      'planTitle': planTitle,
      'serverPersistenceVerified': true,
      'mealCount': 1,
      'numberOfDays': 1,
      'mealType': 'Dinner'
    });
    checkpoint(
        'server reads corroborated exact plan meal identity dates and complete recipe');

    await shell();
    await tap(find.text('Home'));
    await tap(find.text('Saved Plans'));
    await until(
        () =>
            find.byType(SavedMealPlansPage).evaluate().isNotEmpty &&
            plans.value.any((plan) => plan.sourcePath == planPath),
        'saved-plan screen');
    final actions = find.byKey(ValueKey('actions:$planPath'));
    await tap(find.descendant(
        of: actions,
        matching: find.widgetWithText(ElevatedButton, 'Load Plan')));
    await until(() => find.byType(GeneratedMealPlanPage).evaluate().isNotEmpty,
        'exact saved plan reopening');
    final editor = tester
        .widget<GeneratedMealPlanPage>(find.byType(GeneratedMealPlanPage));
    expect(editor.draft?.planPath == planPath, isTrue);
    await tap(find.text('Mon'));
    await tap(find.text(serverMeal.data()['title'] as String));
    await until(() => find.byType(MealDetailPage).evaluate().isNotEmpty,
        'exact saved meal details');
    final detail = tester.widget<MealDetailPage>(find.byType(MealDetailPage));
    expect(detail.planPath == planPath && detail.mealId == mealId, isTrue);
    checkpoint(
        'saved-plan Load and meal-detail UI retained exact persisted identities');

    await logout();
    await login('outsider');
    expect(plans.value.every((plan) => plan.sourcePath != planPath), isTrue);
    expect(
        profiles.members.every((member) => member.name != 'Cloud Participant'),
        isTrue);
    await tap(find.text('Saved Plans'));
    await until(() => find.byType(SavedMealPlansPage).evaluate().isNotEmpty,
        'outsider saved-plan UI');
    expect(find.text(planTitle), findsNothing);
    expect(find.text('No Saved Meal Plans'), findsOneWidget);
    var denied = false;
    try {
      await planRef
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 30));
    } on FirebaseException catch (error) {
      denied = error.code == 'permission-denied';
    }
    expect(denied, isTrue,
        reason: 'Real deployed test rules must deny cross-account reads.');
    binding.reportData!['outsiderDenied'] = true;
    checkpoint(
        'outsider normal UI excluded owner data and server denied the exact owner plan');
    await logout();
    await login('owner');
    await until(() => plans.value.any((plan) => plan.sourcePath == planPath),
        'owner plan after account switching');
    expect(tester.takeException(), isNull);
    checkpoint('owner session restored with the actual generated plan intact');
  });
}

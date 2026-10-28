import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:whatmeal/features/auth/models/user_model.dart';
import 'package:whatmeal/features/family/models/family_space.dart';
import 'package:whatmeal/features/meal/models/meal.dart';
import 'package:whatmeal/features/meal/widgets/meal_status_badge.dart';
import 'package:whatmeal/features/meal_plan/data/saved_plans_repository.dart';
import 'package:whatmeal/features/meal_plan/models/meal_plan.dart';
import 'package:whatmeal/features/meal_plan/models/saved_meal_plan.dart';
import 'package:whatmeal/features/meal_plan/widgets/meal_calendar_workspace.dart';
import 'package:whatmeal/features/meal_plan/pages/meal_plan_page.dart';
import 'package:whatmeal/features/profile/data/family_member_repository.dart';
import 'package:whatmeal/features/profile/models/family_member.dart';

SavedMealPlan calendarPlan(
        String? path, DateTime? start, List<GeneratedMeal> meals) =>
    SavedMealPlan(
        id: path?.split('/').last ?? 'draft',
        sourcePath: path,
        title: path ?? 'Unsaved plan',
        dates: '',
        mealsCount: meals.length,
        estCost: '',
        familyMembers: const [],
        startDate: start,
        createdAt: DateTime(2026, 10, 26),
        meals: meals);

GeneratedMeal dinner(String id, String title, MealStatus status) =>
    GeneratedMeal.fromCore(Meal(
        id: id, title: title, mealType: 'Dinner', dayIndex: 2, status: status));

void main() {
  testWidgets(
      'saved unfinished plan stays visible and opens its original identity',
      (tester) async {
    final account = ValueNotifier<UserModel?>(
        UserModel(id: 'local', name: 'Local', email: 'local@example.test'));
    final household = ValueNotifier<FamilySpace?>(null);
    final repo = SavedPlansRepository(
        firestore: FakeFirebaseFirestore(),
        account: account,
        household: household,
        canEditShared: () => true,
        watch: (_) => Stream.value([]));
    GeneratedPlanDraft? opened;
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
              body: SingleChildScrollView(
                  child: MealCalendarWorkspace(
                      repository: repo,
                      selectedDate: DateTime(2026, 10, 28),
                      onCreatePlan: () {},
                      onGenerateGrocery: () {})))),
      GoRoute(
          path: '/generated-plan',
          builder: (_, state) {
            opened = state.extra as GeneratedPlanDraft;
            return const Scaffold(body: Text('Existing draft editor'));
          }),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    repo.value = [
      SavedMealPlan(
          id: 'draft',
          sourcePath: 'users/local/mealPlans/draft',
          title: 'My unfinished week',
          dates: '',
          mealsCount: 0,
          estCost: '',
          familyMembers: const [],
          meals: const [],
          startDate: DateTime(2026, 10, 26),
          endDate: DateTime(2026, 11, 1),
          numberOfDays: 7)
    ];
    await tester.pumpAndSettle();
    expect(find.text('My unfinished week'), findsOneWidget);
    expect(find.byType(MealStatusBadge), findsNothing);
    await tester.ensureVisible(find.text('Edit plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit plan'));
    await tester.pumpAndSettle();
    expect(opened!.planPath, 'users/local/mealPlans/draft');
    expect(opened!.isManual, isTrue);
    expect(opened!.initialDayIndex, 2);
    expect(opened!.numberOfDays, 7);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    repo.dispose();
    account.dispose();
    household.dispose();
  });
  testWidgets('returning to an original date updates the cached planner branch',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final account = ValueNotifier<UserModel?>(
        UserModel(id: 'local', name: 'Local', email: 'local@example.test'));
    final household = ValueNotifier<FamilySpace?>(null);
    final repo = SavedPlansRepository(
        firestore: db,
        account: account,
        household: household,
        canEditShared: () => true,
        watch: (_) => Stream.value([]));
    final members = FamilyMemberRepository(
        firestore: db, authIds: Stream.value('local'), household: household);
    GeneratedPlanDraft? opened;
    final router =
        GoRouter(initialLocation: '/meal-plan?date=2026-10-26', routes: [
      StatefulShellRoute.indexedStack(
          builder: (_, __, shell) => Scaffold(body: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/meal-plan',
                  builder: (_, state) => MealPlanPage(
                      initialDate:
                          DateTime.parse(state.uri.queryParameters['date']!),
                      memberRepository: members,
                      savedPlansRepository: repo)),
            ])
          ]),
      GoRoute(
          path: '/generated-plan',
          builder: (context, state) {
            opened = state.extra as GeneratedPlanDraft;
            return Scaffold(
                body: TextButton(
                    onPressed: () => context.go('/meal-plan?date=2026-10-26'),
                    child: const Text('Return to Monday')));
          }),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    repo.value = [
      calendarPlan('users/local/mealPlans/week', DateTime(2026, 10, 26),
          [dinner('wednesday', 'Wednesday dinner', MealStatus.pending)])
    ];
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Show'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create Own Plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Own Plan'));
    await tester.pumpAndSettle();
    final title = find.byWidgetPredicate((widget) =>
        widget is TextField &&
        widget.decoration?.hintText == 'e.g., Weekly Family Menu');
    await tester.ensureVisible(title);
    await tester.pumpAndSettle();
    await tester.enterText(title, 'Preserve my draft title');
    await tester.drag(find.byType(ListView), const Offset(0, 900));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Wed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wed'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.queryParameters['date'],
        '2026-10-28');
    expect(find.textContaining('Wednesday · Oct 28'), findsOneWidget);
    await tester.ensureVisible(find.text('Edit plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Return to Monday'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Monday · Oct 26'), findsOneWidget);
    expect(find.textContaining('Wednesday · Oct 28'), findsNothing);
    await tester.scrollUntilVisible(title, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Preserve my draft title'), findsOneWidget);
    expect(find.text('Hide'), findsOneWidget);
    members.value = const [
      FamilyMember(
          id: 'profile-1',
          name: 'Disposable profile',
          age: 30,
          preferences: [],
          restrictions: [])
    ];
    await tester.pumpAndSettle();
    final create =
        find.widgetWithText(ElevatedButton, 'Create Custom Meal Plan');
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(opened!.isManual, isTrue);
    expect(opened!.title, 'Preserve my draft title');
    expect(opened!.startDate, DateTime(2026, 10, 26));
    expect(opened!.meals, hasLength(21));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    members.dispose();
    repo.dispose();
    account.dispose();
    household.dispose();
  });
  testWidgets('calendar Edit plan preserves document identity and selected day',
      (tester) async {
    final account = ValueNotifier<UserModel?>(
        UserModel(id: 'local', name: 'Local', email: 'local@example.test'));
    final household = ValueNotifier<FamilySpace?>(null);
    final plan = SavedMealPlan(
        id: 'p',
        sourcePath: 'users/local/mealPlans/p',
        title: 'Existing',
        dates: '',
        mealsCount: 1,
        estCost: '',
        familyMembers: const [],
        startDate: DateTime(2026, 10, 26),
        meals: [
          GeneratedMeal.fromCore(Meal(
              id: 'm',
              title: 'Rice',
              dayIndex: 2,
              imageUrl: 'https://example.invalid/rice.jpg'))
        ]);
    final repo = SavedPlansRepository(
        firestore: FakeFirebaseFirestore(),
        account: account,
        household: household,
        canEditShared: () => true,
        watch: (_) => Stream.value([plan]));
    GeneratedPlanDraft? opened;
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
              body: SingleChildScrollView(
                  child: MealCalendarWorkspace(
                      repository: repo,
                      selectedDate: DateTime(2026, 10, 28),
                      onCreatePlan: () {},
                      onGenerateGrocery: () {})))),
      GoRoute(
          path: '/generated-plan',
          builder: (_, state) {
            opened = state.extra! as GeneratedPlanDraft;
            return const Scaffold(body: Text('Editing existing plan'));
          }),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit plan'));
    await tester.tap(find.text('Edit plan'));
    await tester.pumpAndSettle();
    expect(opened!.planPath, plan.sourcePath);
    expect(opened!.startDate, DateTime(2026, 10, 26));
    expect(opened!.initialDayIndex, 2);
    expect(opened!.sourceSessionVersion, repo.sessionVersion);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    repo.dispose();
    account.dispose();
    household.dispose();
  });
  testWidgets(
      'next Monday survives creation, refresh and Firebase serialization',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final account = ValueNotifier<UserModel?>(
        UserModel(id: 'local', name: 'Local', email: 'local@example.test'));
    final household = ValueNotifier<FamilySpace?>(null);
    final repo = SavedPlansRepository(
        firestore: db,
        account: account,
        household: household,
        canEditShared: () => true);
    addTearDown(() {
      repo.dispose();
      account.dispose();
      household.dispose();
    });
    var selected = DateTime(2026, 10, 19);
    DateTime? createdFor;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
      child: StatefulBuilder(
          builder: (_, refresh) => MealCalendarWorkspace(
                selectedDate: selected,
                repository: repo,
                onDateSelected: (date) => refresh(() => selected = date),
                onCreatePlan: () => createdFor = selected,
                onGenerateGrocery: () {},
              )),
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next week'));
    await tester.pumpAndSettle();
    expect(selected, DateTime(2026, 10, 26));
    expect(find.textContaining('Monday · Oct 26'), findsOneWidget);
    final create = find.text('Create meal plan').first;
    await tester.ensureVisible(create);
    await tester.tap(create);
    expect(createdFor, selected);
    final id = await repo.savePlan(
        MealPlan(
            id: '',
            title: 'Future Monday',
            startDate: createdFor,
            endDate: createdFor,
            numberOfDays: 1),
        [Meal(id: 'm', title: 'Rice', dayIndex: 0)]);
    await tester.pumpAndSettle();
    final data = (await db.doc('users/local/mealPlans/$id').get()).data()!;
    expect((data['startDate'] as Timestamp).toDate(), DateTime(2026, 10, 26));
    expect((data['endDate'] as Timestamp).toDate(), DateTime(2026, 10, 26));
    expect(selected, DateTime(2026, 10, 26));
    expect(find.textContaining('Monday · Oct 26'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'weekly calendar preserves same-type meals by plan path and meal ID',
      (tester) async {
    final account = ValueNotifier<UserModel?>(
        UserModel(id: 'local', name: 'Local', email: 'local@example.test'));
    final household = ValueNotifier<FamilySpace?>(null);
    final repo = SavedPlansRepository(
        firestore: FakeFirebaseFirestore(),
        account: account,
        household: household,
        canEditShared: () => true,
        watch: (_) => Stream.value([]));
    final personalMeal = dinner('same', 'Personal dinner', MealStatus.pending);
    final personal =
        calendarPlan('users/local/mealPlans/p', DateTime(2026, 10, 26), [
      personalMeal,
      personalMeal,
      dinner('second', 'Second dinner', MealStatus.completed)
    ]);
    final shared = calendarPlan(
        'families/house/mealPlans/p',
        DateTime(2026, 10, 26),
        [dinner('same', 'Shared dinner', MealStatus.accepted)]);
    String? openedPath;
    String? openedMeal;
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
              body: SingleChildScrollView(
                  child: MealCalendarWorkspace(
                      repository: repo,
                      selectedDate: DateTime(2026, 10, 28),
                      onCreatePlan: () {},
                      onGenerateGrocery: () {})))),
      GoRoute(
          path: '/meal/:id',
          builder: (_, state) {
            openedPath = state.uri.queryParameters['plan'];
            openedMeal = state.pathParameters['id'];
            return const Scaffold(body: Text('Exact saved meal'));
          }),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    repo.value = [personal, shared, personal];
    await tester.pumpAndSettle();

    expect(find.text('Personal dinner'), findsOneWidget);
    expect(find.text('Second dinner'), findsOneWidget);
    expect(find.text('Shared dinner'), findsOneWidget);
    expect(find.text('3 meals'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(
        tester
            .widgetList<MealStatusBadge>(find.byType(MealStatusBadge))
            .map((badge) => badge.status)
            .toSet(),
        {MealStatus.pending, MealStatus.completed, MealStatus.accepted});

    await tester.ensureVisible(find.text('Shared dinner'));
    await tester.tap(find.text('Shared dinner'));
    await tester.pumpAndSettle();
    expect(openedPath, shared.sourcePath);
    expect(openedMeal, 'same');
    router.pop();
    await tester.pumpAndSettle();
    repo.value = [shared, personal];
    await tester.pumpAndSettle();
    expect(find.textContaining('Wednesday · Oct 28'), findsOneWidget);
    expect(find.text('3 meals'), findsOneWidget);
    expect(find.text('Personal dinner'), findsOneWidget);
    expect(find.text('Shared dinner'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    router.dispose();
    repo.dispose();
    account.dispose();
    household.dispose();
  });

  testWidgets('weekly calendar excludes undated and unsaved plans',
      (tester) async {
    final account = ValueNotifier<UserModel?>(
        UserModel(id: 'local', name: 'Local', email: 'local@example.test'));
    final household = ValueNotifier<FamilySpace?>(null);
    final repo = SavedPlansRepository(
        firestore: FakeFirebaseFirestore(),
        account: account,
        household: household,
        canEditShared: () => true,
        watch: (_) => Stream.value([]));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: MealCalendarWorkspace(
                    repository: repo,
                    selectedDate: DateTime(2026, 10, 28),
                    onCreatePlan: () {},
                    onGenerateGrocery: () {})))));
    await tester.pumpAndSettle();
    repo.value = [
      calendarPlan('users/local/mealPlans/undated', null,
          [dinner('undated', 'Undated dinner', MealStatus.pending)]),
      calendarPlan(null, DateTime(2026, 10, 26),
          [dinner('draft', 'Unsaved dinner', MealStatus.pending)]),
      calendarPlan('users/local/mealPlans/scheduled', DateTime(2026, 10, 26), [
        dinner('scheduled', 'Scheduled dinner', MealStatus.completed),
        dinner('old', 'Replaced dinner', MealStatus.replaced)
      ]),
    ];
    await tester.pumpAndSettle();
    expect(find.text('Undated dinner'), findsNothing);
    expect(find.text('Unsaved dinner'), findsNothing);
    expect(find.text('Replaced dinner'), findsNothing);
    expect(find.text('Scheduled dinner'), findsOneWidget);
    expect(find.text('1 meal'), findsOneWidget);
    expect(
        find.descendant(
            of: find
                .byKey(const ValueKey('calendar-day-2026-10-28T00:00:00.000')),
            matching: find.text('1')),
        findsOneWidget);
    expect(find.textContaining('Wednesday · Oct 28'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    repo.dispose();
    account.dispose();
    household.dispose();
  });
}

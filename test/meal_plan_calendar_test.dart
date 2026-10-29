import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:whatmeal/features/auth/models/user_model.dart';
import 'package:whatmeal/features/family/models/family_space.dart';
import 'package:whatmeal/features/meal/models/meal.dart';
import 'package:whatmeal/features/meal_plan/data/saved_plans_repository.dart';
import 'package:whatmeal/features/meal_plan/models/calendar_plan_day.dart';
import 'package:whatmeal/features/meal_plan/models/saved_meal_plan.dart';
import 'package:whatmeal/features/meal_plan/pages/meal_plan_calendar_page.dart';

GeneratedMeal meal(String name, MealStatus status, {int day = 0}) =>
    GeneratedMeal.fromCore(Meal(
        id: 'same-meal',
        title: name,
        mealType: 'Dinner',
        dayIndex: day,
        status: status));
SavedMealPlan plan(String path, DateTime? start, List<GeneratedMeal> meals,
        {DateTime? end, int? days}) =>
    SavedMealPlan(
        id: path.split('/').last,
        title: path,
        sourcePath: path,
        dates: '',
        mealsCount: meals.length,
        estCost: '',
        familyMembers: const [],
        meals: meals,
        startDate: start,
        endDate: end,
        numberOfDays: days,
        createdAt: DateTime(2020, 1, 1));

void main() {
  test('month cells preserve weekdays, leap days and year boundaries', () {
    final october = mealCalendarMonth(DateTime(2026, 10));
    expect(october.take(3), everyElement(isNull));
    expect(october[3], DateTime(2026, 10, 1));
    expect(october.whereType<DateTime>(), hasLength(31));
    expect(mealCalendarMonth(DateTime(2024, 2)).whereType<DateTime>(),
        hasLength(29));
    expect(mealCalendarMonth(DateTime(2027, 1)).whereType<DateTime>().first,
        DateTime(2027, 1, 1));
  });

  test(
      'all scheduled periods preserve status and overlapping document identities',
      () {
    final plans = [
      plan('users/a/mealPlans/same', DateTime(2026, 9, 30),
          [meal('Past pending', MealStatus.pending)]),
      plan('users/a/mealPlans/today', DateTime(2026, 10, 25),
          [meal('Today accepted', MealStatus.accepted)]),
      plan('families/f/mealPlans/same', DateTime(2026, 12, 31),
          [meal('Future done', MealStatus.completed)]),
      plan('users/a/mealPlans/future', DateTime(2026, 12, 31),
          [meal('Future skipped', MealStatus.notCompleted)]),
    ];
    expect(
        calendarPlansForDay(plans, DateTime(2026, 9, 30))
            .single
            .meals
            .single
            .status,
        MealStatus.pending);
    final future = calendarPlansForDay(plans, DateTime(2026, 12, 31));
    expect(future, hasLength(2));
    expect(future.map((entry) => entry.plan.sourcePath).toSet(), hasLength(2));
    expect(
        future
            .expand((entry) => entry.meals)
            .map((meal) => meal.status)
            .toSet(),
        {MealStatus.completed, MealStatus.notCompleted});
    expect(calendarPlansForDay([...plans, plans.first], DateTime(2026, 9, 30)),
        hasLength(1));
  });

  test(
      'coverage uses persisted duration and scheduled offsets, never creation time',
      () {
    final p = plan('users/a/mealPlans/p', DateTime(2026, 12, 30),
        [meal('January meal', MealStatus.pending, day: 3)],
        days: 7);
    expect(
        calendarPlansForDay([p], DateTime(2027, 1, 2))
            .single
            .meals
            .single
            .title,
        'January meal');
    expect(calendarPlansForDay([p], DateTime(2027, 1, 6)), isEmpty);
    expect(
        calendarPlansForDay([p], DateTime(2027, 1, 4)).single.meals, isEmpty);
    final undated = plan('users/a/mealPlans/undated', null,
        [meal('Undated', MealStatus.pending)]);
    expect(calendarPlansForDay([undated], DateTime(2020, 1, 1)), isEmpty);
    final decoded = SavedMealPlan.fromFirestore('p', {
      'title': 'Plan',
      'startDate': Timestamp.fromDate(DateTime(2026, 10, 26)),
      'numberOfDays': 7,
    }, []);
    expect(decoded.numberOfDays, 7);
    expect(GeneratedPlanDraft.fromSaved(decoded).numberOfDays, 7);
  });

  test(
      'unsaved drafts and replaced records never become persisted calendar entries',
      () {
    final unsaved = SavedMealPlan(
        id: '',
        title: 'Draft',
        dates: '',
        mealsCount: 1,
        estCost: '',
        familyMembers: const [],
        startDate: DateTime(2026, 10, 26),
        meals: [meal('Draft meal', MealStatus.pending)]);
    final replaced = plan('users/a/mealPlans/p', DateTime(2026, 10, 26),
        [meal('Old', MealStatus.replaced)]);
    expect(calendarPlansForDay([unsaved], DateTime(2026, 10, 26)), isEmpty);
    expect(calendarPlansForDay([replaced], DateTime(2026, 10, 26)).single.meals,
        isEmpty);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
        'month navigation, exact meal routing and selected date survive refresh at $scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final account = ValueNotifier<UserModel?>(
          UserModel(id: 'a', name: 'A', email: 'a@example.test'));
      final household = ValueNotifier<FamilySpace?>(null);
      final repo = SavedPlansRepository(
          firestore: FakeFirebaseFirestore(),
          account: account,
          household: household,
          canEditShared: () => true,
          watch: (_) => Stream.value([]));
      final p = plan('users/a/mealPlans/p', DateTime(2026, 10, 26),
          [meal('Monday dinner', MealStatus.pending)]);
      final overlap = plan('families/f/mealPlans/p', DateTime(2026, 10, 26),
          [meal('Shared dinner', MealStatus.accepted)]);
      repo.value = [p, overlap];
      String? openedPath;
      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (_, __) => MealPlanCalendarPage(
                repository: repo, now: () => DateTime(2026, 10, 25))),
        GoRoute(
            path: '/meal/:id',
            builder: (_, state) {
              openedPath = state.uri.queryParameters['plan'];
              return const Scaffold(body: Text('Existing meal details'));
            }),
      ]);
      await tester.pumpWidget(MaterialApp.router(
          routerConfig: router,
          builder: (_, child) => MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: child!)));
      repo.value = [p, overlap];
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);
      final day = find.byKey(const ValueKey('meal-calendar-day-2026-10-26'));
      await tester.ensureVisible(day);
      await tester.tap(day);
      await tester.pumpAndSettle();
      expect(find.textContaining('Monday, October 26, 2026'), findsOneWidget);
      final entry = find.byKey(
          const ValueKey('calendar-meal:families/f/mealPlans/p:same-meal'));
      await tester.scrollUntilVisible(entry, 240,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(entry.hitTestable(), findsOneWidget);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(openedPath, 'families/f/mealPlans/p');
      router.pop();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('meal-calendar-selected-date')), -200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Monday, October 26, 2026'), findsOneWidget);
      repo.value = [
        p.copyWith(
            meals: [p.meals.single.copyWith(status: MealStatus.completed)])
      ];
      await tester.pumpAndSettle();
      expect(find.text('Shared dinner'), findsNothing);
      await tester.scrollUntilVisible(find.text('Completed'), 160,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Completed'), findsOneWidget);
      final next = find.byTooltip('Next month');
      await tester.scrollUntilVisible(next, -240,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text('November 2026'), findsOneWidget);
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Monday, October 26, 2026'), findsOneWidget);
      account.value = UserModel(id: 'b', name: 'B', email: 'b@example.test');
      await tester.pumpAndSettle();
      expect(repo.value, isEmpty);
      expect(find.text('Monday dinner'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      repo.dispose();
      account.dispose();
      household.dispose();
    });
  }

  testWidgets(
      'terminal failure offers Retry and reload does not move the selected date',
      (tester) async {
    final account = ValueNotifier<UserModel?>(
        UserModel(id: 'a', name: 'A', email: 'a@example.test'));
    final household = ValueNotifier<FamilySpace?>(null);
    final feeds = <StreamController<List<SavedMealPlan>>>[];
    final repo = SavedPlansRepository(
        firestore: FakeFirebaseFirestore(),
        account: account,
        household: household,
        canEditShared: () => true,
        watch: (_) {
          final feed =
              StreamController<List<SavedMealPlan>>.broadcast(sync: true);
          feeds.add(feed);
          return feed.stream;
        });
    await tester.pumpWidget(MaterialApp(
        home: MealPlanCalendarPage(
            repository: repo, initialDate: DateTime(2026, 12, 31))));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    feeds.single.addError(StateError('private diagnostic'));
    await tester.pumpAndSettle();
    expect(find.text('Retry Calendar'), findsOneWidget);
    expect(find.textContaining('private diagnostic'), findsNothing);
    await tester.ensureVisible(find.text('Retry Calendar'));
    await tester.tap(find.text('Retry Calendar'));
    await tester.pump();
    feeds.last.add([]);
    await tester.pumpAndSettle();
    expect(find.text('Retry Calendar'), findsNothing);
    expect(find.textContaining('Thursday, December 31, 2026'), findsOneWidget);
    expect(
        find.text('No meal plans are scheduled for this day.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    repo.dispose();
    account.dispose();
    household.dispose();
    for (final feed in feeds) {
      unawaited(feed.close());
    }
  });
}

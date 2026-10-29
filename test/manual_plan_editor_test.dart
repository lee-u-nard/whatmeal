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
import 'package:whatmeal/features/meal_plan/models/meal_plan.dart';
import 'package:whatmeal/features/meal_plan/models/saved_meal_plan.dart';
import 'package:whatmeal/features/meal_plan/pages/generated_meal_plan_page.dart';

class _RetryRepository extends SavedPlansRepository {
  _RetryRepository(
      {required super.firestore,
      required super.account,
      required super.household,
      required super.canEditShared});
  int attempts = 0;
  @override
  Future<String> savePlan(MealPlan plan, List<Meal> meals,
      {bool allowEmptyDraft = false}) async {
    if (++attempts == 1) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
    return super.savePlan(plan, meals, allowEmptyDraft: allowEmptyDraft);
  }
}

UserModel user(String id) =>
    UserModel(id: id, name: id, email: '$id@example.test');

GeneratedMeal slot(int day, String type, {String title = ''}) => GeneratedMeal(
    id: 'slot-$day-$type',
    title: title,
    type: type,
    prepTime: '',
    calories: '',
    badgeText: 'Custom',
    imageUrl: '',
    ingredients: const [],
    macros: const {},
    dayIndex: day,
    status: MealStatus.accepted);

void main() {
  late FakeFirebaseFirestore db;
  late ValueNotifier<UserModel?> account;
  late ValueNotifier<FamilySpace?> household;
  late SavedPlansRepository repo;
  GoRouter? router;

  setUp(() {
    router = null;
    db = FakeFirebaseFirestore();
    account = ValueNotifier<UserModel?>(user('manual-owner'));
    household = ValueNotifier<FamilySpace?>(null);
    repo = SavedPlansRepository(
        firestore: db,
        account: account,
        household: household,
        canEditShared: () => true);
  });
  tearDown(() {
    router?.dispose();
    repo.dispose();
    account.dispose();
    household.dispose();
  });

  Future<void> open(WidgetTester tester, List<GeneratedMeal> meals,
      {int days = 7, bool manual = true}) async {
    router = GoRouter(initialLocation: '/editor', routes: [
      GoRoute(
          path: '/editor',
          builder: (_, __) => GeneratedMealPlanPage(
              repository: repo,
              draft: GeneratedPlanDraft(
                  meals: meals,
                  familyMembers: const [],
                  selectedMemberIds: const ['profile-1'],
                  numberOfDays: days,
                  startDate: DateTime(2026, 10, 26),
                  title: 'My Family Meal Plan',
                  sourceSessionVersion: repo.sessionVersion,
                  isManual: manual))),
      GoRoute(
          path: '/meal-plan',
          builder: (_, state) => Scaffold(
              body: Text('Calendar ${state.uri.queryParameters['date']}'))),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Save Plan'));
    await tester.pumpAndSettle();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pumpAndSettle();
    expect(repo.error, isNull);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save Plan').last);
    await tester.pumpAndSettle();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pumpAndSettle();
    expect(repo.error, isNull);
  }

  testWidgets('21 unfilled manual slots save a dated draft, not blank meals',
      (tester) async {
    await open(tester, [
      for (var day = 0; day < 7; day++)
        for (final type in ['Breakfast', 'Lunch', 'Dinner']) slot(day, type)
    ]);
    await save(tester);
    final plans = await db.collection('users/manual-owner/mealPlans').get();
    expect(plans.docs, hasLength(1));
    final parent = plans.docs.single;
    expect(parent.data()['status'], 'draft');
    expect(parent.data()['title'], 'My Family Meal Plan');
    expect(parent.data()['createdBy'], 'manual-owner');
    expect(parent.data()['numberOfDays'], 7);
    expect(parent.data()['mealTypes'], ['Breakfast', 'Lunch', 'Dinner']);
    expect(parent.data()['selectedMemberIds'], ['profile-1']);
    expect((parent.data()['startDate'] as Timestamp).toDate(),
        DateTime(2026, 10, 26));
    expect((parent.data()['endDate'] as Timestamp).toDate(),
        DateTime(2026, 11, 1));
    expect((await parent.reference.collection('meals').get()).docs, isEmpty);
    expect(
        calendarPlansForDay(repo.value, DateTime(2026, 10, 26)), hasLength(1));
    expect(
        calendarPlansForDay(repo.value, DateTime(2026, 11, 1)), hasLength(1));
    expect(find.textContaining('Add a name for:'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Calendar 2026-10-26'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('partial manual plan persists only named dishes on exact dates',
      (tester) async {
    await open(tester,
        [slot(0, 'Breakfast'), slot(2, 'Dinner', title: 'Chicken adobo')]);
    await save(tester);
    final plans = await db.collection('users/manual-owner/mealPlans').get();
    expect(plans.docs, hasLength(1));
    final meals = await plans.docs.single.reference.collection('meals').get();
    expect(meals.docs, hasLength(1));
    expect(meals.docs.single.data()['title'], 'Chicken adobo');
    expect(meals.docs.single.data()['dayIndex'], 2);
    expect(plans.docs.single.data()['status'], 'saved');
    expect(
        calendarPlansForDay(repo.value, DateTime(2026, 10, 28))
            .single
            .meals
            .single
            .title,
        'Chicken adobo');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'failed manual draft save stays open and retries persistence once',
      (tester) async {
    repo.dispose();
    final retry = _RetryRepository(
        firestore: db,
        account: account,
        household: household,
        canEditShared: () => true);
    repo = retry;
    await open(tester, [slot(0, 'Lunch')]);
    await save(tester);
    expect(find.text('Save Meal Plan'), findsOneWidget);
    expect((await db.collection('users/manual-owner/mealPlans').get()).docs,
        isEmpty);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save Plan').last);
    await tester.pumpAndSettle();
    expect(retry.attempts, 2);
    expect((await db.collection('users/manual-owner/mealPlans').get()).docs,
        hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('stale manual save dialog cannot write to the next account',
      (tester) async {
    await open(tester, [slot(0, 'Lunch')]);
    await tester.tap(find.byTooltip('Save Plan'));
    await tester.pumpAndSettle();
    account.value = user('other-account');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save Plan').last);
    await tester.pumpAndSettle();
    expect((await db.collection('users/manual-owner/mealPlans').get()).docs,
        isEmpty);
    expect((await db.collection('users/other-account/mealPlans').get()).docs,
        isEmpty);
    expect(find.textContaining('Your account or household changed.'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('generated recipes survive save failure and save-only retry',
      (tester) async {
    repo.dispose();
    final retry = _RetryRepository(
        firestore: db,
        account: account,
        household: household,
        canEditShared: () => true);
    repo = retry;
    final generated = GeneratedMeal.fromCore(Meal(
        id: 'generated-recipe',
        title: 'Generated rice bowl',
        mealType: 'Lunch',
        ingredients: const [Ingredient(name: 'Rice', amount: '1 cup')],
        instructions: const ['Cook the rice.']));
    await open(tester, [generated], manual: false);
    await save(tester);
    expect(find.text('Save Meal Plan'), findsOneWidget);
    expect((await db.collection('users/manual-owner/mealPlans').get()).docs,
        isEmpty);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save Plan').last);
    await tester.pumpAndSettle();
    final plans = await db.collection('users/manual-owner/mealPlans').get();
    expect(plans.docs, hasLength(1));
    final recipe = (await plans.docs.single.reference
            .collection('meals')
            .doc('generated-recipe')
            .get())
        .data()!;
    expect(recipe['title'], 'Generated rice bowl');
    expect(recipe['ingredients'], [
      {'name': 'Rice', 'amount': '1 cup'}
    ]);
    expect(recipe['instructions'], ['Cook the rice.']);
    expect(retry.attempts, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'saving one-day plan from an unused later tab returns to saved date',
      (tester) async {
    await open(tester, [slot(0, 'Lunch')], days: 1);
    final sunday = find.text('Sun');
    await tester.ensureVisible(sunday);
    await tester.tap(sunday);
    await tester.pumpAndSettle();
    await save(tester);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Calendar 2026-10-26'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test(
      'AI empty recipes are not filtered; partially entered manual recipes are retained',
      () {
    final empty = slot(0, 'Lunch');
    final partial = empty.copyWith(ingredients: ['1 cup rice']);
    GeneratedPlanDraft draft(bool manual) => GeneratedPlanDraft(
        meals: [], familyMembers: [], numberOfDays: 1, isManual: manual);
    expect(draft(false).mealsForSaving([empty]), [empty]);
    expect(draft(true).mealsForSaving([empty, partial]), [partial]);
  });
}

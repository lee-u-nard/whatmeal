import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:whatmeal/core/utils/week_calendar.dart';
import 'package:whatmeal/features/home/pages/home_page.dart';
import 'package:whatmeal/features/meal/models/meal.dart';
import 'package:whatmeal/features/meal_plan/data/saved_plans_repository.dart';
import 'package:whatmeal/features/meal_plan/models/saved_meal_plan.dart';
import 'package:whatmeal/features/meal_plan/pages/meal_history_page.dart';
import 'package:whatmeal/features/meal_plan/pages/meal_plan_calendar_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUpAll(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const codec = StandardMessageCodec();
    const prefix =
        'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi';
    for (final entry in {
      'registerIdTokenListener': 'home-id',
      'registerAuthStateListener': 'home-auth'
    }.entries) {
      messenger.setMockMessageHandler('$prefix.${entry.key}',
          (_) async => codec.encodeMessage(<Object?>[entry.value]));
      messenger.setMockMethodCallHandler(
          MethodChannel(entry.value), (_) async => null);
    }
    await Firebase.initializeApp();
    SavedPlansRepository.instance;
    await Future<void>.delayed(Duration.zero);
  });

  testWidgets(
      'Home compact toggle and all status shortcuts work at narrow width',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final now = DateTime.now();
    final meals = [
      for (final status in [
        MealStatus.pending,
        MealStatus.accepted,
        MealStatus.completed
      ])
        GeneratedMeal.fromCore(Meal(
            id: status.name,
            title: 'Local ${status.name}',
            dayIndex: WeekCalendar.dayIndexOf(now),
            status: status,
            isFavorite: status == MealStatus.accepted,
            imageUrl: 'https://example.invalid/local.jpg'))
    ];
    SavedPlansRepository.instance.value = [
      SavedMealPlan(
          id: 'p',
          sourcePath: 'users/local/mealPlans/p',
          title: 'Local plan',
          dates: '',
          mealsCount: 3,
          estCost: '',
          familyMembers: const [],
          startDate: WeekCalendar.mondayOf(now),
          meals: meals),
      for (final kind in ['undated', 'unsaved'])
        SavedMealPlan(
            id: kind,
            sourcePath:
                kind == 'undated' ? 'users/local/mealPlans/undated' : null,
            title: '$kind plan',
            dates: '',
            mealsCount: 1,
            estCost: '',
            familyMembers: const [],
            startDate: kind == 'undated' ? null : WeekCalendar.mondayOf(now),
            createdAt: now,
            meals: [
              GeneratedMeal.fromCore(Meal(
                  id: kind,
                  title: '$kind calendar meal',
                  dayIndex: WeekCalendar.dayIndexOf(now)))
            ])
    ];
    String? openedPlan;
    final router = GoRouter(initialLocation: '/home', routes: [
      GoRoute(
          path: '/home', builder: (_, __) => const Scaffold(body: HomePage())),
      GoRoute(
          path: '/meal-calendar',
          builder: (_, __) => const MealPlanCalendarPage()),
      GoRoute(
          path: '/meal/:id',
          builder: (_, state) {
            openedPlan = state.uri.queryParameters['plan'];
            return const Scaffold(body: Text('Exact scheduled meal'));
          }),
      GoRoute(
          path: '/meal-history',
          builder: (_, state) => MealHistoryPage(
              filter: state.uri.queryParameters['filter'],
              week:
                  DateTime.tryParse(state.uri.queryParameters['week'] ?? ''))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Calendar'));
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Meal Plan Calendar'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Weekly Schedule'), findsNothing);
    await tester.ensureVisible(find.byTooltip('Expand calendar'));
    await tester.tap(find.byTooltip('Expand calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Weekly Schedule'), findsOneWidget);
    expect(find.text('Meal: Local pending'), findsOneWidget);
    expect(find.text('Meal: undated calendar meal'), findsNothing);
    expect(find.text('Meal: unsaved calendar meal'), findsNothing);
    for (final label in ['Pending', 'Accepted', 'Done', 'Favorites']) {
      final stat = find
          .ancestor(of: find.text(label).first, matching: find.byType(Column))
          .first;
      expect(
          find.descendant(of: stat, matching: find.text('1')), findsOneWidget);
    }
    await tester.ensureVisible(find.text('Meal: Local pending'));
    await tester.tap(find.text('Meal: Local pending'));
    await tester.pumpAndSettle();
    expect(openedPlan, 'users/local/mealPlans/p');
    router.pop();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 600));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Compact calendar'));
    await tester.tap(find.byTooltip('Compact calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Weekly Schedule'), findsNothing);
    for (final entry in {
      'Pending': 'Pending Meals',
      'Accepted': 'Accepted Meals',
      'Done': 'Completed Meals',
      'Favorites': 'Favorite Meals'
    }.entries) {
      final shortcut = find.text(entry.key).first;
      await tester.ensureVisible(shortcut);
      await tester.tap(shortcut);
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      final expectedStatus = switch (entry.key) {
        'Pending' => 'pending',
        'Done' => 'completed',
        _ => 'accepted',
      };
      expect(find.text('Local $expectedStatus'), findsOneWidget);
      for (final status in ['pending', 'accepted', 'completed']) {
        if (status != expectedStatus) {
          expect(find.text('Local $status'), findsNothing);
        }
      }
      router.pop();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

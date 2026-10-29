import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/auth/data/auth_repository.dart';
import 'package:whatmeal/features/family/data/family_repository.dart';
import 'package:whatmeal/features/meal/models/meal.dart';
import 'package:whatmeal/features/meal/pages/meal_detail_page.dart';
import 'package:whatmeal/features/meal_plan/data/saved_plans_repository.dart';
import 'package:whatmeal/features/meal_plan/models/saved_meal_plan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const codec = StandardMessageCodec();
  const authPrefix =
      'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi';
  const authEvents = {
    'registerIdTokenListener': 'meal-insets-id-token',
    'registerAuthStateListener': 'meal-insets-auth-state',
  };
  late SavedPlansRepository repository;

  setUpAll(() async {
    // This is a layout regression of the real page, not Firebase acceptance.
    // Both native Auth listeners stay signed out, so no profile/plan query or
    // authentication request is made. Replies contain only event-channel names.
    for (final event in authEvents.entries) {
      messenger.setMockMessageHandler('$authPrefix.${event.key}',
          (_) async => codec.encodeMessage(<Object?>[event.value]));
      messenger.setMockMethodCallHandler(
          MethodChannel(event.value), (_) async => null);
    }
    await Firebase.initializeApp();
    repository = SavedPlansRepository.instance;
    // Let the initial signed-out events finish before seeding display data.
    await Future<void>.delayed(Duration.zero);
  });

  tearDownAll(() {
    repository.dispose();
    FamilyRepository.instance.dispose();
    AuthRepository.instance.dispose();
    for (final event in authEvents.entries) {
      messenger.setMockMessageHandler('$authPrefix.${event.key}', null);
      messenger.setMockMethodCallHandler(MethodChannel(event.value), null);
    }
  });

  const navigationBar = 48.0;
  const displays = [Size(320, 640), Size(411, 891), Size(640, 360)];
  const actions = {
    MealStatus.pending: ['Replace Meal', 'Accept Meal'],
    MealStatus.accepted: [
      'Not Completed',
      'Mark Completed',
      'Replace with AI',
    ],
    MealStatus.completed: ['Undo / Mark Accepted'],
    MealStatus.notCompleted: ['Re-accept', 'Mark Done', 'Replace with AI'],
  };

  for (final display in displays) {
    for (final entry in actions.entries) {
      testWidgets(
          'Meal Details ${entry.key.name} actions avoid 48px navigation bar at '
          '${display.width.toInt()}x${display.height.toInt()}', (tester) async {
        tester.view.physicalSize = display;
        tester.view.devicePixelRatio = 1;
        tester.view.viewPadding =
            const FakeViewPadding(top: 24, bottom: navigationBar);
        tester.view.padding =
            const FakeViewPadding(top: 24, bottom: navigationBar);
        tester.view.viewInsets = const FakeViewPadding();
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.view.resetViewPadding();
          tester.view.resetPadding();
          tester.view.resetViewInsets();
        });

        final meal = GeneratedMeal.fromCore(Meal(
          id: 'inset-meal',
          title: 'Local layout fixture',
          mealType: 'Lunch',
          status: entry.key,
          // Avoid the optional image-search service. Widget-test HTTP returns
          // an unavailable image, handled by the page's real image fallback.
          imageUrl: 'https://example.invalid/layout-fixture.png',
          ingredients: const [Ingredient(name: 'rice', amount: '1 cup')],
          instructions: const ['Cook the rice.'],
        ));
        const planPath = 'users/layout-only/mealPlans/inset-plan';
        repository.value = [
          SavedMealPlan(
            id: 'inset-plan',
            title: 'Layout fixture plan',
            dates: '',
            mealsCount: 1,
            estCost: '',
            familyMembers: const [],
            meals: [meal],
            sourcePath: planPath,
          )
        ];
        await tester.pumpWidget(const MaterialApp(
          home: MealDetailPage(mealId: 'inset-meal', planPath: planPath),
        ));
        await tester.pumpAndSettle();
        expect(find.text('Meal Details'), findsOneWidget);
        expect(find.text('Meal Not Found'), findsNothing);
        expect(tester.takeException(), isNull);

        for (final label in entry.value) {
          final button = find.ancestor(
              of: find.text(label),
              matching: find.byWidgetPredicate(
                  (widget) => widget is ButtonStyleButton));
          expect(button, findsOneWidget);
          expect(button.hitTestable(), findsOneWidget,
              reason: '$label must remain usable in the real page footer');
          final rectangle = tester.getRect(button);
          expect(rectangle.bottom,
              lessThanOrEqualTo(display.height - navigationBar),
              reason:
                  'The entire $label button must be above Android navigation');
          expect(rectangle.left, greaterThanOrEqualTo(0));
          expect(rectangle.right, lessThanOrEqualTo(display.width));
        }
        expect(tester.takeException(), isNull);
        // Detach the page listener before clearing singleton display fixtures.
        await tester.pumpWidget(const SizedBox());
        repository.value = [];
      });
    }
  }
}

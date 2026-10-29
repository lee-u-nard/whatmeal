import 'dart:convert';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/family/models/family_space.dart';
import 'package:whatmeal/features/grocery/data/meal_grocery_projection.dart';
import 'package:whatmeal/features/meal/models/meal.dart';
import 'package:whatmeal/features/meal/widgets/unsaved_meal_preview.dart';
import 'package:whatmeal/features/meal/widgets/meal_ingredients_panel.dart';
import 'package:whatmeal/features/meal_plan/models/saved_meal_plan.dart';
import 'package:whatmeal/features/meal_plan/pages/generated_meal_plan_page.dart';
import 'package:whatmeal/features/pantry/data/pantry_repository.dart';
import 'package:whatmeal/features/pantry/models/pantry_item.dart';

GeneratedMeal recipe({List<Ingredient>? ingredients}) =>
    GeneratedMeal.fromCore(Meal(
      id: 'draft',
      title: 'Rice',
      status: MealStatus.pending,
      imageUrl: 'https://example.invalid/rice.jpg',
      ingredients:
          ingredients ?? const [Ingredient(name: 'rice', amount: '3 cups')],
      instructions: const ['Cook the rice.'],
    ));

void main() {
  test(
      'cooking rejects incomplete, failed, or other-account stock and recovers',
      () async {
    final household = ValueNotifier<FamilySpace?>(null);
    final pantry = PantryRepository(
        firestore: FakeFirebaseFirestore(),
        authIds: Stream.value('local'),
        household: household,
        watch: (_) => const Stream.empty());
    await Future<void>.delayed(Duration.zero);
    expect(mealCookingProblem(recipe(), pantry, expectedScope: 'users/local'),
        isNotNull);
    pantry.isLoading = false;
    pantry.value = {
      'Dry': [PantryItem(name: 'rice', quantity: '2 cups')]
    };
    expect(mealCookingProblem(recipe(), pantry, expectedScope: 'users/local'),
        contains('do not cover'));
    pantry.value = {
      'Dry': [PantryItem(name: 'rice', quantity: '3 cups')]
    };
    expect(mealCookingProblem(recipe(), pantry, expectedScope: 'users/local'),
        isNull);
    expect(mealCookingProblem(recipe(), pantry, expectedScope: 'users/other'),
        isNotNull);
    pantry.error = 'Stock failed';
    expect(mealCookingProblem(recipe(), pantry, expectedScope: 'users/local'),
        isNotNull);
    pantry.dispose();
    household.dispose();
  });
  test('recipe stock comparison agrees with aggregate grocery shortages', () {
    final meal = recipe();
    final pantry = [PantryItem(name: 'rice', quantity: '2 cups')];
    final preview = MealGroceryProjection.forMeal(meal, pantry).values.single;
    expect(preview.required, 3);
    expect(preview.available, 2);
    expect(preview.missing, 1);
    final plan = SavedMealPlan(
        id: 'p',
        sourcePath: 'users/local/mealPlans/p',
        title: 'Plan',
        dates: '',
        mealsCount: 1,
        estCost: '',
        familyMembers: const [],
        meals: [meal.copyWith(status: MealStatus.accepted)]);
    final shopping =
        MealGroceryProjection.calculate([plan], pantry).values.single;
    expect(shopping.missing, preview.missing);
    expect(pantry.single.quantity, '2 cups');
    expect(meal.status, MealStatus.pending);
  });

  test('recipe comparison consolidates quantities without mass/volume guessing',
      () {
    final meal = recipe(ingredients: const [
      Ingredient(name: 'rice', amount: '1 cup'),
      Ingredient(name: 'rice', amount: '2 cups')
    ]);
    final stock = [PantryItem(name: 'rice', quantity: '100 g')];
    final result = MealGroceryProjection.forMeal(meal, stock).values.single;
    expect(result.required, 3);
    expect(result.available, 0);
    expect(result.missing, 3);
  });

  test('expired and used stock never satisfy cooking ingredients', () {
    final result = MealGroceryProjection.forMeal(recipe(), [
      PantryItem(
          name: 'rice', quantity: '9 cups', expirationDate: DateTime(2020)),
      PantryItem(name: 'rice', quantity: '9 cups', status: PantryStatus.used),
    ]).values.single;
    expect(result.missing, 3);
  });

  testWidgets('unsaved card offers Cook without accepting or completing it',
      (tester) async {
    var cooked = 0;
    var statusWrites = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
      child: GeneratedMealCard(
          meal: recipe(),
          dayIndex: 0,
          isSaved: false,
          onOpen: () {},
          onReplace: () {},
          onAccept: () => statusWrites++,
          onComplete: () => statusWrites++,
          onCook: () => cooked++),
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Accept'), findsNothing);
    expect(find.text('Done'), findsNothing);
    await tester.ensureVisible(find.text('Cook'));
    await tester.tap(find.text('Cook'));
    expect(cooked, 1);
    expect(statusWrites, 0);
  });

  testWidgets(
      'unsaved preview shows quantities and only requests explicit saving',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final household = ValueNotifier<FamilySpace?>(null);
    final pantry = PantryRepository(
        firestore: db, authIds: const Stream.empty(), household: household);
    pantry.value = {
      'Dry': [PantryItem(name: 'rice', quantity: '2 cups')]
    };
    var saves = 0;
    final meal = recipe();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: UnsavedMealPreview(
                meal: meal, pantry: pantry, onSave: () => saves++))));
    await tester.pumpAndSettle();
    expect(find.textContaining('3 cups rice'), findsOneWidget);
    expect(find.textContaining('Partially available'), findsOneWidget);
    expect(find.textContaining('missing 1 cup'), findsOneWidget);
    expect(find.textContaining('Cook the rice.'), findsOneWidget);
    expect(saves, 0);
    await tester.ensureVisible(find.text('Save Meal Plan'));
    await tester.tap(find.text('Save Meal Plan'));
    expect(saves, 1);
    expect(meal.status, MealStatus.pending);
    expect(jsonDecode(db.dump()), isEmpty);
    await tester.pumpWidget(const SizedBox());
    pantry.dispose();
    household.dispose();
  });
}

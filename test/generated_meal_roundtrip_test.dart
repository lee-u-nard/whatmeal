import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/grocery/data/meal_grocery_projection.dart';
import 'package:whatmeal/features/meal/models/meal.dart';
import 'package:whatmeal/features/meal_plan/models/saved_meal_plan.dart';
import 'package:whatmeal/features/pantry/models/pantry_item.dart';

Meal _core() => Meal(
      id: 'original',
      title: 'Original rice recipe',
      subtitle: 'Original description',
      cuisine: 'Filipino',
      mealType: 'Dinner',
      dayIndex: 1,
      ingredients: const [
        Ingredient(name: 'Rice', amount: '2 cups'),
        Ingredient(name: 'Tomato, diced', amount: '200 g'),
      ],
      instructions: const ['Cook the original ingredients.'],
      availableIngredients: const ['Rice'],
      missingIngredients: const ['Tomato'],
      status: MealStatus.pending,
      replacedMealId: 'previous',
      createdAt: DateTime(2026, 10, 19, 9),
    );

List<Map<String, dynamic>> _ingredients(Meal meal) =>
    meal.ingredients.map((ingredient) => ingredient.toMap()).toList();

SavedMealPlan _plan(GeneratedMeal meal) => SavedMealPlan(
    id: 'p',
    sourcePath: 'families/demo/mealPlans/p',
    title: 'Fixture',
    dates: '',
    mealsCount: 1,
    estCost: '',
    familyMembers: const [],
    meals: [meal]);

void main() {
  test('untouched core/display/core preserves quantities and recipe metadata',
      () {
    final source = _core();
    final roundTrip = GeneratedMeal.fromCore(source).toCore();
    expect(_ingredients(roundTrip), _ingredients(source));
    expect(roundTrip.subtitle, source.subtitle);
    expect(roundTrip.cuisine, source.cuisine);
    expect(roundTrip.createdAt, source.createdAt);
    expect(roundTrip.status, source.status);
    expect(roundTrip.replacedMealId, source.replacedMealId);
  });

  test('current editor state overrides source while ingredient detail survives',
      () {
    final source = _core();
    final changed = GeneratedMeal.fromCore(source)
        .copyWith(
          title: 'Edited title',
          type: 'Lunch',
          dayIndex: 2,
          status: MealStatus.accepted,
          isFavorite: true,
          instructions: const ['Use the edited instructions.'],
          availableIngredients: const ['Rice', 'Tomato'],
          missingIngredients: const [],
          replacedMealId: 'updated-previous',
        )
        .toCore();
    expect(changed.id, source.id);
    expect(changed.title, 'Edited title');
    expect(changed.mealType, 'Lunch');
    expect(changed.dayIndex, 2);
    expect(changed.status, MealStatus.accepted);
    expect(changed.accepted, isTrue);
    expect(changed.isFavorite, isTrue);
    expect(changed.instructions, ['Use the edited instructions.']);
    expect(changed.availableIngredients, ['Rice', 'Tomato']);
    expect(changed.missingIngredients, isEmpty);
    expect(changed.replacedMealId, 'updated-previous');
    expect(changed.createdAt, source.createdAt);
    expect(_ingredients(changed), _ingredients(source));
  });

  test('title-only form submission with identical ingredient text keeps detail',
      () {
    final source = _core();
    final display = GeneratedMeal.fromCore(source);
    final changed = display
        .copyWith(title: 'New title', ingredients: List.of(display.ingredients))
        .toCore();
    expect(changed.title, 'New title');
    expect(_ingredients(changed), _ingredients(source));
  });

  test('ingredient edits invalidate source detail and never restore old recipe',
      () {
    final display = GeneratedMeal.fromCore(_core());
    final edited = display.copyWith(ingredients: const ['3 cups Lentils']);
    final core = edited.copyWith(status: MealStatus.accepted).toCore();
    expect(_ingredients(core), [
      {'name': '3 cups Lentils', 'amount': ''}
    ]);
    expect(core.cuisine, 'Filipino');
    expect(core.subtitle, 'Original description');
    // Even restoring the same display string cannot resurrect a discarded
    // structured recipe after a real edit. Legacy text remains authoritative.
    final reverted = edited.copyWith(ingredients: display.ingredients).toCore();
    expect(reverted.ingredients.map((ingredient) => ingredient.name),
        display.ingredients);
    expect(
        reverted.ingredients.every((ingredient) => ingredient.amount.isEmpty),
        isTrue);
  });

  test(
      'directly changed display list cannot silently restore source ingredient',
      () {
    final display = GeneratedMeal.fromCore(_core());
    display.ingredients[0] = 'Edited ingredient text';
    final core = display.toCore();
    expect(core.ingredients.first.name, 'Edited ingredient text');
    expect(core.ingredients.first.amount, isEmpty);
  });

  test('manual text recipes retain their existing serialization behavior', () {
    const manual = GeneratedMeal(
        id: 'manual',
        title: 'Manual',
        type: 'Dinner',
        prepTime: '',
        calories: '',
        badgeText: '',
        imageUrl: '',
        ingredients: ['2 cups Rice'],
        macros: {});
    final core = manual.copyWith(status: MealStatus.accepted).toCore();
    expect(_ingredients(core), [
      {'name': '2 cups Rice', 'amount': ''}
    ]);
    expect(core.accepted, isTrue);
  });

  test('new meal identity retains recipe but gets a fresh creation timestamp',
      () {
    final source = _core();
    final core = GeneratedMeal.fromCore(source)
        .copyWith(id: 'new-identity', status: MealStatus.pending)
        .toCore();
    expect(core.id, 'new-identity');
    expect(core.createdAt, isNull,
        reason: 'Firestore assigns server time to a newly created meal.');
    expect(_ingredients(core), _ingredients(source));
    expect(core.cuisine, source.cuisine);
  });

  test(
      'reusing a saved plan resets identity, time, status and replacement links',
      () {
    final source = _core().copyWith(
        status: MealStatus.accepted,
        replacedMealId: 'old-predecessor',
        isFavorite: true);
    final reuse = GeneratedPlanDraft.fromSaved(
        _plan(GeneratedMeal.fromCore(source)),
        reuse: true,
        today: DateTime(2026, 10, 26));
    final core = reuse.meals.single.toCore();
    expect(core.id, isNot(source.id));
    expect(core.createdAt, isNull);
    expect(core.status, MealStatus.pending);
    expect(core.accepted, isFalse);
    expect(core.replacedMealId, isNull);
    expect(core.replacedByMealId, isNull);
    expect(_ingredients(core), _ingredients(source));
    expect(core.isFavorite, source.isFavorite);
  });

  test('accepted retry roundtrip retains grocery quantity and exact provenance',
      () {
    final source = Meal(
        id: 'rice-meal',
        title: 'Rice',
        mealType: 'Dinner',
        status: MealStatus.accepted,
        ingredients: const [Ingredient(name: 'Rice', amount: '2 cups')]);
    final retry = GeneratedMeal.fromCore(source).copyWith(isFavorite: true);
    final roundTrip = GeneratedMeal.fromCore(retry.toCore());
    final requirements = MealGroceryProjection.calculate([
      _plan(roundTrip)
    ], [
      PantryItem(
          name: 'Rice', quantity: '1 cup', expirationDate: DateTime(2030)),
    ], now: DateTime(2026, 10, 19));
    final row = requirements.values.single;
    expect(row.required, 2);
    expect(row.available, 1);
    expect(row.missing, 1);
    expect(row.sources.keys, ['families/demo/mealPlans/p/meals/rice-meal']);
    expect(roundTrip.status, MealStatus.accepted);
    expect(roundTrip.isFavorite, isTrue);
  });
}

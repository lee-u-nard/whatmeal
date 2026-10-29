import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/grocery/data/meal_grocery_projection.dart';
import 'package:whatmeal/features/grocery/models/grocery_item.dart';
import 'package:whatmeal/features/meal/models/meal.dart';
import 'package:whatmeal/features/meal_plan/models/saved_meal_plan.dart';
import 'package:whatmeal/features/pantry/models/pantry_item.dart';

GeneratedMeal meal(String id, String ingredient,
        {MealStatus status = MealStatus.accepted}) =>
    GeneratedMeal(
        id: id,
        title: id,
        type: 'Dinner',
        prepTime: '',
        calories: '',
        badgeText: '',
        imageUrl: '',
        ingredients: [ingredient],
        macros: const {},
        status: status);
SavedMealPlan plan(List<GeneratedMeal> meals) => SavedMealPlan(
    id: 'plan',
    sourcePath: 'families/a/mealPlans/plan',
    title: 'Plan',
    dates: '',
    mealsCount: meals.length,
    estCost: '',
    familyMembers: const [],
    meals: meals);
PantryItem pantry(String name, String quantity) =>
    PantryItem(name: name, quantity: quantity, expirationDate: DateTime(2030));

void main() {
  test('name-only available pantry ingredient is not a shopping need', () {
    final rows = MealGroceryProjection.calculate([
      plan([meal('a', 'rice'), meal('b', 'onions'), meal('c', 'eggs')])
    ], [
      pantry('rice', '')
    ]).values.map((r) => r.toItem(null)).toList();
    expect(rows.singleWhere((r) => r.name == 'rice').status,
        GroceryStatus.available);
    expect(rows.where((r) => r.status == GroceryStatus.needed).length, 2);
  });
  test('zero pantry stock does not cover a name-only ingredient', () {
    final row = MealGroceryProjection.calculate([
      plan([meal('a', 'rice')])
    ], [
      pantry('rice', '0 g')
    ]).values.single.toItem(null);
    expect(row.status, GroceryStatus.needed);
  });
  test('acceptance calculates only missing amount, including unit conversion',
      () {
    final result = MealGroceryProjection.calculate([
      plan([meal('a', '500 g rice')])
    ], [
      pantry('Rice', '0.2 kg')
    ]);
    expect(result.values.single.missing, 300);
    expect(result.values.single.toItem(null).quantity, '300 g');
  });
  test('shared ingredients retain remaining meal provenance after deletion',
      () {
    final a = meal('a', '2 red onions');
    final b = meal('b', '3 onions');
    final both = MealGroceryProjection.calculate([
      plan([a, b])
    ], []);
    expect(both.length, 1);
    expect(both.values.single.required, 5);
    expect(both.values.single.sources.length, 2);
    final remaining = MealGroceryProjection.calculate([
      plan([b])
    ], []);
    expect(remaining.keys.single, both.keys.single);
    expect(remaining.values.single.required, 3);
  });
  test('pantry growth removes purchase need without removing meal requirement',
      () {
    final result = MealGroceryProjection.calculate([
      plan([meal('a', '2 onions')])
    ], [
      pantry('onion', '3 pieces')
    ]);
    expect(result.values.single.missing, 0);
    expect(result.values.single.toItem(null).status, GroceryStatus.available);
  });
  test('replacement and skipped/completed meals no longer require shopping',
      () {
    final result = MealGroceryProjection.calculate([
      plan([
        meal('a', '2 onions', status: MealStatus.replaced),
        meal('b', '1 kg rice'),
        meal('c', '3 eggs', status: MealStatus.completed),
        meal('d', '1 apple', status: MealStatus.notCompleted),
      ])
    ], []);
    expect(result.values.single.name, 'rice');
  });
  test('repeated projection is idempotent and purchase receipt remains checked',
      () {
    final plans = [
      plan([meal('a', '2 onions')])
    ];
    final first = MealGroceryProjection.calculate(plans, []);
    final next = MealGroceryProjection.calculate(plans, []);
    final receipt = first.values.single
        .toItem(null)
        .copyWith(status: GroceryStatus.used, checked: true);
    expect(next.keys, first.keys);
    expect(next.values.single.toItem(receipt).isPurchased, true);
    final more = MealGroceryProjection.calculate([
      plan([meal('a', '5 onions')])
    ], []);
    expect(more.values.single.toItem(receipt).quantity, '5 unit');
    // Checking does not create inventory; pantry remains the stock authority.
    expect(more.values.single.toItem(receipt).isPurchased, false);
  });
  test(
      'name-only uses pantry presence while incompatible measured units stay needed',
      () {
    final result = MealGroceryProjection.calculate([
      plan([meal('a', 'rice'), meal('b', '2 cups flour')])
    ], [
      pantry('rice', '1 kg'),
      pantry('flour', '500 g')
    ]);
    expect(result.values.first.toItem(null).status, GroceryStatus.available);
    expect(result.values.last.missing, 2);
    expect(IngredientQuantity.canonicalName('coconut'), isNot('nut'));
  });
  test('expired and used stock are excluded', () {
    final result = MealGroceryProjection.calculate([
      plan([meal('a', '2 onions')])
    ], [
      pantry('onion', '5').copyWith(expirationDate: DateTime(2000)),
      pantry('onion', '5').copyWith(status: PantryStatus.used),
    ]);
    expect(result.values.single.available, 0);
  });
}

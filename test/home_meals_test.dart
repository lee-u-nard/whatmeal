import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/home/models/home_meals.dart';
import 'package:whatmeal/features/meal/models/meal.dart';
import 'package:whatmeal/features/meal_plan/models/saved_meal_plan.dart';
import 'package:whatmeal/features/profile/models/family_member.dart';

void main() {
  final monday = DateTime(2026, 10, 26);
  GeneratedMeal meal(String title,
          {MealStatus status = MealStatus.pending,
          bool favorite = false,
          List<String> ingredients = const ['rice']}) =>
      GeneratedMeal.fromCore(Meal(
          id: title,
          title: title,
          dayIndex: 0,
          status: status,
          isFavorite: favorite,
          ingredients: ingredients
              .map((name) => Ingredient(name: name, amount: '1 cup'))
              .toList()));
  SavedMealPlan plan(String path, List<GeneratedMeal> meals) => SavedMealPlan(
      id: 'same',
      sourcePath: path,
      title: path,
      dates: '',
      mealsCount: meals.length,
      estCost: '',
      familyMembers: const ['member'],
      meals: meals,
      startDate: monday);
  const profiles = [
    FamilyMember(
        id: 'member',
        name: 'Local',
        age: 30,
        preferences: ['rice'],
        restrictions: ['Peanut allergy'])
  ];

  test('Home shortcuts match only their requested status', () {
    final pending = meal('Pending');
    final accepted = meal('Accepted', status: MealStatus.accepted);
    final done = meal('Done', status: MealStatus.completed);
    final favorite = meal('Favorite', favorite: true);
    for (final entry in {
      'pending': pending,
      'accepted': accepted,
      'completed': done,
      'favorites': favorite
    }.entries) {
      expect(matchesMealFilter(entry.value, entry.key), isTrue);
    }
    expect(matchesMealFilter(done, 'pending'), isFalse);
    expect(matchesMealFilter(pending, 'accepted'), isFalse);
  });

  test(
      'recommendations retain exact plan identity and exclude unsafe or finished meals',
      () {
    final a = plan('users/a/mealPlans/same', [
      meal('Rice'),
      meal('Peanut dish', ingredients: ['peanut']),
      meal('Done', status: MealStatus.completed)
    ]);
    final b = plan('families/f/mealPlans/same', [meal('Rice', favorite: true)]);
    final entries = homeRecommendations([a, b], profiles, monday);
    expect(entries, hasLength(2));
    expect(entries.first.plan.sourcePath, b.sourcePath);
    expect(entries.last.plan.sourcePath, a.sourcePath);
    expect(
        homeRecommendations([a], profiles, monday.add(const Duration(days: 1))),
        isEmpty);
    expect(homeRecommendations([a], [], monday), isEmpty);
  });

  test(
      'legacy participant names resolve to current restrictions instead of empty recommendations',
      () {
    final legacy = plan('users/a/mealPlans/legacy', [
      meal('Rice'),
      meal('Peanut dish', ingredients: ['peanut'])
    ]).copyWith(familyMembers: ['Local']);
    expect(
        homeRecommendations([legacy], profiles, monday)
            .map((entry) => entry.meal.title),
        ['Rice']);
  });

  test('unassigned plans still respect current household restrictions', () {
    final legacy = plan('users/a/mealPlans/legacy', [
      meal('Peanut dish', ingredients: ['peanut'])
    ]).copyWith(familyMembers: []);
    expect(homeRecommendations([legacy], profiles, monday), isEmpty);
  });
}

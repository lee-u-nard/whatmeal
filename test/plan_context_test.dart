import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/services/ai/ai_models.dart';
import 'package:whatmeal/core/services/ai/ingredient_restrictions.dart';
import 'package:whatmeal/features/meal/models/meal.dart';
import 'package:whatmeal/features/meal_plan/models/saved_meal_plan.dart';

void main() {
  test(
      'calendar editing retains exact saved identity, date and selected offset',
      () {
    final start = DateTime(2026, 10, 26);
    final plan = SavedMealPlan(
        id: 'p',
        sourcePath: 'families/f/mealPlans/p',
        title: 'Plan',
        dates: '',
        mealsCount: 1,
        estCost: '',
        familyMembers: const ['member'],
        startDate: start,
        meals: [
          GeneratedMeal.fromCore(Meal(id: 'm', title: 'Rice', dayIndex: 2))
        ]);
    final draft = GeneratedPlanDraft.fromSaved(plan,
        selectedDate: DateTime(2026, 10, 28));
    expect(draft.planPath, 'families/f/mealPlans/p');
    expect(draft.startDate, start);
    expect(draft.initialDayIndex, 2);
    expect(draft.selectedMemberIds, ['member']);
    expect(plan.dateForMeal(draft.meals.single), DateTime(2026, 10, 28));
  });

  test(
      'changing a dish clears stale image metadata but retains recipe quantities',
      () {
    final original = GeneratedMeal.fromCore(Meal(
        id: 'm',
        title: 'Rice',
        imageUrl: 'https://example.invalid/rice.jpg',
        imageSearchQuery: 'rice',
        ingredients: const [Ingredient(name: 'rice', amount: '1 cup')]));
    final renamed = original.copyWith(title: 'Vegetable soup');
    expect(renamed.imageUrl, isEmpty);
    expect(renamed.imageSearchQuery, 'Vegetable soup');
    expect(renamed.toCore().ingredients.single.amount, '1 cup');
  });
  test(
      'open saved plan retains document identity, participant IDs and actual date',
      () {
    final plan = SavedMealPlan(
        id: 'p',
        sourcePath: 'families/f/mealPlans/p',
        title: 'Plan',
        dates: '',
        mealsCount: 1,
        estCost: '',
        familyMembers: const ['profile-id'],
        cuisinePreferences: const ['Filipino'],
        startDate: DateTime(2026, 10, 6),
        meals: [
          GeneratedMeal.fromCore(Meal(id: 'm', title: 'Soup', dayIndex: 1))
        ]);
    final draft = GeneratedPlanDraft.fromSaved(plan);
    expect(draft.planPath, plan.sourcePath);
    expect(draft.selectedMemberIds, ['profile-id']);
    expect(draft.cuisinePreferences, ['Filipino']);
    expect(draft.startDate, DateTime(2026, 10, 6));
    expect(plan.dateForMeal(plan.meals.single), DateTime(2026, 10, 7));
  });
  test('reuse creates a new pending draft and clears replacement relationships',
      () {
    final plan = SavedMealPlan(
        id: 'p',
        sourcePath: 'families/f/mealPlans/p',
        title: 'Plan',
        dates: '',
        mealsCount: 1,
        estCost: '',
        familyMembers: const [
          'profile-id'
        ],
        meals: [
          GeneratedMeal.fromCore(Meal(
              id: 'm',
              title: 'Soup',
              replacedMealId: 'old',
              status: MealStatus.completed))
        ]);
    final draft = GeneratedPlanDraft.fromSaved(plan,
        reuse: true, today: DateTime(2026, 10, 6));
    expect(draft.planPath, isNull);
    expect(draft.meals.single.id, isNot('m'));
    expect(draft.meals.single.status, MealStatus.pending);
    expect(draft.meals.single.replacedMealId, isNull);
    expect(draft.startDate, DateTime(2026, 10, 5));
    expect(plan.meals.single.status, MealStatus.completed);
  });
  test(
      'full and compact AI prompts distinguish shopping from pantry and retain restrictions',
      () {
    const request = AiMealPlanRequest(
        familyMemberNames: ['Child'],
        memberAges: {'Child': 8},
        numberOfDays: 1,
        mealTypes: ['Dinner'],
        pantryItems: ['rice'],
        groceryItems: ['chicken'],
        restrictions: ['peanut allergy'],
        preferences: ['mild'],
        cuisinePreferences: ['Filipino']);
    for (final prompt in [
      request.buildPrompt(),
      request.buildCompactPrompt()
    ]) {
      expect(prompt, contains('NOT available'));
      expect(prompt, contains('peanut allergy'));
      expect(prompt, contains('mild'));
      expect(prompt, contains('Filipino'));
      expect(prompt, contains('age 8'));
      expect(prompt, isNot(contains('pantry + grocery')));
    }
  });
  test(
      'common restrictions reject forbidden ingredients without substring false matches',
      () {
    expect(
        () => IngredientRestrictions.validate(
            ['peanut butter'], ['Peanut allergy']),
        throwsFormatException);
    expect(() => IngredientRestrictions.validate(['whey'], ['Dairy-free']),
        throwsFormatException);
    expect(() => IngredientRestrictions.validate(['chicken'], ['Vegetarian']),
        throwsFormatException);
    expect(
        () => IngredientRestrictions.validate(
            ['eggplant', 'coconut'], ['Egg allergy', 'Nut allergy']),
        returnsNormally);
  });
}

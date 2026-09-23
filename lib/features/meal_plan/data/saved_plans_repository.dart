import 'package:flutter/foundation.dart';
import '../models/saved_meal_plan.dart';
import '../../meal/models/meal.dart' as core_meal;
import '../models/meal_plan.dart' as core_plan;
import 'meal_plan_repository.dart';

class SavedPlansRepository extends ValueNotifier<List<SavedMealPlan>> {
  SavedPlansRepository._() : super([]) {
    _mealPlanRepository.addListener(_onMealPlansChanged);
    _onMealPlansChanged();
  }

  static final instance = SavedPlansRepository._();

  final _mealPlanRepository = MealPlanRepository();

  void _onMealPlansChanged() async {
    try {
      final plans = _mealPlanRepository.savedPlans;
      final mappedPlans = <SavedMealPlan>[];

      for (final plan in plans) {
        final coreMeals = await _mealPlanRepository.getMealsForPlan(plan.id);
        mappedPlans.add(SavedMealPlan(
          id: plan.id,
          title: plan.title,
          dates: plan.dateRange,
          mealsCount: coreMeals.length,
          estCost: plan.estimatedCost ?? '\$0.00',
          familyMembers: plan.selectedMemberIds,
          meals: coreMeals.map(_mapMeal).toList(),
          createdAt: plan.createdAt,
        ));
      }

      value = mappedPlans;
    } catch (e) {
      debugPrint('SavedPlansRepository load failed: $e');
    }
  }

  GeneratedMeal _mapMeal(core_meal.Meal meal) {
    return GeneratedMeal(
      id: meal.id,
      title: meal.title,
      type: meal.mealType ?? 'Unknown',
      prepTime: meal.prepTime ?? 'Unknown',
      calories: meal.calories ?? 'Unknown',
      badgeText: meal.badgeText ?? '',
      imageUrl: meal.imageUrl ?? '',
      ingredients: meal.ingredients.map((i) => '${i.name} ${i.amount}'.trim()).toList(),
      macros: {
        'Protein': meal.protein ?? '0g',
        'Carbs': meal.carbs ?? '0g',
        'Fats': meal.fats ?? '0g',
      },
      dayIndex: meal.dayIndex,
    );
  }

  Future<void> savePlan(SavedMealPlan plan) async {
    try {
      final corePlan = core_plan.MealPlan(
        id: '',
        title: plan.title,
        estimatedCost: plan.estCost,
        selectedMemberIds: plan.familyMembers,
        status: 'saved',
      );

      final coreMeals = plan.meals
          .map((m) => core_meal.Meal(
                id: '',
                title: m.title,
                mealType: m.type,
                prepTime: m.prepTime,
                calories: m.calories,
                badgeText: m.badgeText,
                imageUrl: m.imageUrl,
                ingredients: m.ingredients
                    .map((i) => core_meal.Ingredient(name: i, amount: ''))
                    .toList(),
                protein: m.macros['Protein'],
                carbs: m.macros['Carbs'],
                fats: m.macros['Fats'],
              ))
          .toList();

      await _mealPlanRepository.savePlan(corePlan, coreMeals);
    } catch (e) {
      debugPrint('SavedPlansRepository.savePlan failed: $e');
      rethrow;
    }
  }

  Future<void> deletePlan(String id) async {
    await _mealPlanRepository.deletePlan(id);
  }
}

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/ingredient_matcher.dart';
import '../../grocery/data/meal_grocery_projection.dart';
import '../../meal_plan/models/saved_meal_plan.dart';
import '../../pantry/data/pantry_repository.dart';
import '../../pantry/models/pantry_item.dart';

String? mealCookingProblem(GeneratedMeal meal, PantryRepository pantry,
    {required String? expectedScope}) {
  if (expectedScope == null ||
      pantry.scopePath != expectedScope ||
      pantry.isLoading ||
      pantry.error != null) {
    return 'Pantry quantities are unavailable. Reload your pantry before cooking.';
  }
  final requirements = MealGroceryProjection.forMeal(
      meal, pantry.items.values.expand((items) => items)).values;
  if (requirements.isEmpty) {
    return 'Add recipe ingredients before cooking this meal.';
  }
  if (requirements
      .any((item) => item.unknown ? !item.nameAvailable : item.missing > 0)) {
    return 'Pantry quantities do not cover this recipe. Check the missing quantities below and update your pantry or grocery list before cooking.';
  }
  return null;
}

/// Live stock comparison; provider-reported availability is never authoritative.
class MealIngredientsPanel extends StatelessWidget {
  const MealIngredientsPanel({super.key, required this.meal, this.pantry});
  final GeneratedMeal meal;
  final PantryRepository? pantry;

  @override
  Widget build(BuildContext context) {
    final repo = pantry ?? PantryRepository.instance;
    final ingredients = IngredientMatcher.allIngredients(
        ingredients: meal.ingredients,
        availableIngredients: meal.availableIngredients,
        missingIngredients: meal.missingIngredients);
    return ValueListenableBuilder<Map<String, List<PantryItem>>>(
      valueListenable: repo,
      builder: (context, stock, _) {
        final ready = !repo.isLoading && repo.error == null;
        final requirements = ready
            ? MealGroceryProjection.forMeal(
                meal, stock.values.expand((items) => items)).values.toList()
            : const <MealGroceryRequirement>[];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final ingredient in ingredients)
            Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $ingredient')),
          if (ingredients.isEmpty)
            const Text('No ingredients recorded for this meal.'),
          if (!ready) ...[
            Text(repo.error ?? 'Loading pantry quantities…'),
            if (repo.error != null)
              TextButton(
                  onPressed: repo.retry, child: const Text('Retry Pantry')),
          ] else
            for (final requirement in requirements)
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    requirement.unknown
                        ? '${requirement.name}: ${requirement.nameAvailable ? 'Present' : 'Missing'} — verify recipe quantity'
                        : '${requirement.name}: ${requirement.missing == 0 ? 'Available' : requirement.available > 0 ? 'Partially available' : 'Missing'}'
                            ' — recipe ${requirement.amount(requirement.required)}; pantry ${requirement.amount(requirement.available)};'
                            ' missing ${requirement.amount(requirement.missing)}',
                    style: TextStyle(
                        color: requirement.unknown
                            ? AppColors.textSecondary
                            : requirement.missing == 0
                                ? AppColors.primary
                                : AppColors.danger),
                  )),
        ]);
      },
    );
  }
}

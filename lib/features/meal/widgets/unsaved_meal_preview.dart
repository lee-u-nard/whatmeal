import 'package:flutter/material.dart';
import '../../meal_plan/models/saved_meal_plan.dart';
import '../../pantry/data/pantry_repository.dart';
import 'meal_ingredients_panel.dart';
import 'meal_network_image.dart';

class UnsavedMealPreview extends StatelessWidget {
  const UnsavedMealPreview(
      {super.key, required this.meal, required this.onSave, this.pantry});
  final GeneratedMeal meal;
  final VoidCallback onSave;
  final PantryRepository? pantry;

  @override
  Widget build(BuildContext context) => SafeArea(
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(meal.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            MealNetworkImage(
                url: meal.imageUrl,
                mealTitle: meal.title,
                height: 140,
                width: double.infinity),
            const SizedBox(height: 12),
            const Text('Ingredients',
                style: TextStyle(fontWeight: FontWeight.bold)),
            MealIngredientsPanel(meal: meal, pantry: pantry),
            for (var index = 0; index < meal.instructions.length; index++)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('${index + 1}. ${meal.instructions[index]}')),
            const SizedBox(height: 16),
            const Text(
                'Save this meal plan before cooking or updating meal status. Saving does not mark it cooked.'),
            const SizedBox(height: 8),
            FilledButton(
                onPressed: onSave, child: const Text('Save Meal Plan')),
          ],
        ),
      ));
}

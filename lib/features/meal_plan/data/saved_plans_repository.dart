import 'package:flutter/foundation.dart';
import '../models/saved_meal_plan.dart';

class SavedPlansRepository extends ValueNotifier<List<SavedMealPlan>> {
  SavedPlansRepository._()
      : super([
          const SavedMealPlan(
            id: 'sp_1',
            title: 'Winter Cozy Warmers',
            dates: 'Oct 1 - Oct 7',
            mealsCount: 15,
            estCost: '\$112.50',
            familyMembers: ['Dad', 'Mom', 'Leo', 'Emma'],
            meals: [
              GeneratedMeal(
                id: 'm_salmon',
                title: 'Honey Garlic Pan Seared Salmon',
                type: 'Dinner',
                prepTime: '25m',
                calories: '450 kcal',
                badgeText: 'Dinner Special',
                imageUrl: 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&w=800&q=80',
                ingredients: ['Fresh Salmon Fillet', 'Asparagus spears', 'Lemon slices', 'Olive oil', 'Garlic'],
                macros: {'Protein': '42g', 'Carbs': '8g', 'Fats': '18g'},
              ),
              GeneratedMeal(
                id: 'm_avocado',
                title: 'Avocado & Spinach Salad',
                type: 'Lunch',
                prepTime: '10m',
                calories: '320 kcal',
                badgeText: 'Pantry Cleanout',
                imageUrl: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=800&q=80',
                ingredients: ['Fresh Spinach', 'Avocado', 'Cherry Tomatoes', 'Olive oil'],
                macros: {'Protein': '12g', 'Carbs': '14g', 'Fats': '22g'},
              ),
            ],
          ),
          const SavedMealPlan(
            id: 'sp_2',
            title: 'Eco Pantry Cleanout',
            dates: 'Sep 24 - Sep 30',
            mealsCount: 12,
            estCost: '\$84.20',
            familyMembers: ['Dad', 'Mom', 'Leo'],
            meals: [
              GeneratedMeal(
                id: 'm_chicken',
                title: 'Grilled Herb Lemon Chicken',
                type: 'Dinner',
                prepTime: '20m',
                calories: '510 kcal',
                badgeText: 'High Protein',
                imageUrl: 'https://images.unsplash.com/photo-1532550907401-a500c9a57435?auto=format&fit=crop&w=800&q=80',
                ingredients: ['Chicken Breast', 'Lemon', 'Rosemary', 'Garlic'],
                macros: {'Protein': '48g', 'Carbs': '4g', 'Fats': '14g'},
              ),
            ],
          ),
          const SavedMealPlan(
            id: 'sp_3',
            title: 'High-Protein Strength Week',
            dates: 'Sep 15 - Sep 21',
            mealsCount: 14,
            estCost: '\$145.00',
            familyMembers: ['Dad', 'Mom'],
            meals: [],
          ),
        ]);

  static final instance = SavedPlansRepository._();

  void savePlan(SavedMealPlan plan) {
    value = [plan, ...value];
  }

  void deletePlan(String id) {
    value = value.where((p) => p.id != id).toList();
  }
}

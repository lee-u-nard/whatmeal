import '../../meal/models/meal.dart';

class GeneratedMeal {
  const GeneratedMeal({
    required this.id,
    required this.title,
    required this.type, // Breakfast, Lunch, Dinner
    required this.prepTime,
    required this.calories,
    required this.badgeText,
    required this.imageUrl,
    required this.ingredients,
    required this.macros,
    this.dayIndex = 0,
  });

  final String id;
  final String title;
  final String type;
  final String prepTime;
  final String calories;
  final String badgeText;
  final String imageUrl;
  final List<String> ingredients;
  final Map<String, String> macros;
  final int dayIndex;

  factory GeneratedMeal.fromCore(Meal meal, {int fallbackIndex = 0}) {
    return GeneratedMeal(
      id: meal.id.isNotEmpty
          ? meal.id
          : 'gen_${meal.dayIndex}_${fallbackIndex}_${meal.title.hashCode}',
      title: meal.title,
      type: meal.mealType ?? 'Meal',
      prepTime: meal.prepTime ?? '',
      calories: meal.calories ?? '',
      badgeText: meal.badgeText ?? '',
      imageUrl: meal.imageUrl ?? '',
      ingredients: meal.ingredients
          .map((i) => '${i.name} ${i.amount}'.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      macros: {
        'Protein': meal.protein ?? '0g',
        'Carbs': meal.carbs ?? '0g',
        'Fats': meal.fats ?? '0g',
      },
      dayIndex: meal.dayIndex,
    );
  }

  Meal toCore() {
    return Meal(
      id: id,
      title: title,
      mealType: type,
      dayIndex: dayIndex,
      prepTime: prepTime,
      calories: calories,
      badgeText: badgeText,
      imageUrl: imageUrl,
      ingredients: ingredients
          .map((i) => Ingredient(name: i, amount: ''))
          .toList(),
      protein: macros['Protein'],
      carbs: macros['Carbs'],
      fats: macros['Fats'],
    );
  }
}

/// Passed through `/generated-plan` so the results screen is not hardcoded.
class GeneratedPlanDraft {
  const GeneratedPlanDraft({
    required this.meals,
    required this.familyMembers,
    required this.numberOfDays,
    this.title,
  });

  final List<GeneratedMeal> meals;
  final List<String> familyMembers;
  final int numberOfDays;
  final String? title;
}

class SavedMealPlan {
  const SavedMealPlan({
    required this.id,
    required this.title,
    required this.dates,
    required this.mealsCount,
    required this.estCost,
    required this.familyMembers,
    required this.meals,
    this.createdAt,
  });

  final String id;
  final String title;
  final String dates;
  final int mealsCount;
  final String estCost;
  final List<String> familyMembers;
  final List<GeneratedMeal> meals;
  final DateTime? createdAt;

  SavedMealPlan copyWith({
    String? id,
    String? title,
    String? dates,
    int? mealsCount,
    String? estCost,
    List<String>? familyMembers,
    List<GeneratedMeal>? meals,
    DateTime? createdAt,
  }) {
    return SavedMealPlan(
      id: id ?? this.id,
      title: title ?? this.title,
      dates: dates ?? this.dates,
      mealsCount: mealsCount ?? this.mealsCount,
      estCost: estCost ?? this.estCost,
      familyMembers: familyMembers ?? this.familyMembers,
      meals: meals ?? this.meals,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

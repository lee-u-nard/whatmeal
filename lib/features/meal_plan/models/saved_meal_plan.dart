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

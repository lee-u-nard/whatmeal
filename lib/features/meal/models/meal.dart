import 'package:cloud_firestore/cloud_firestore.dart';

class Ingredient {
  const Ingredient({required this.name, required this.amount});

  final String name;
  final String amount;

  factory Ingredient.fromMap(Map<String, dynamic> data) => Ingredient(
        name: data['name'] ?? '',
        amount: data['amount'] ?? '',
      );

  Map<String, dynamic> toMap() => {'name': name, 'amount': amount};
}

enum MealStatus {
  pending,
  accepted,
  completed,
  notCompleted,
  replaced;

  String get label {
    switch (this) {
      case MealStatus.pending:
        return 'Pending';
      case MealStatus.accepted:
        return 'Accepted';
      case MealStatus.completed:
        return 'Completed';
      case MealStatus.notCompleted:
        return 'Not Completed';
      case MealStatus.replaced:
        return 'Replaced';
    }
  }

  static MealStatus fromString(String? val, {bool legacyAccepted = false}) {
    if (val != null) {
      switch (val.toLowerCase()) {
        case 'pending':
          return MealStatus.pending;
        case 'accepted':
          return MealStatus.accepted;
        case 'completed':
        case 'done':
          return MealStatus.completed;
        case 'notcompleted':
        case 'not_completed':
        case 'skipped':
          return MealStatus.notCompleted;
        case 'replaced':
          return MealStatus.replaced;
      }
    }
    return legacyAccepted ? MealStatus.accepted : MealStatus.pending;
  }
}

class Meal {
  Meal({
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.cuisine,
    this.mealType,
    this.dayIndex = 0,
    this.prepTime,
    this.cookTime,
    this.servings,
    this.calories,
    this.protein,
    this.carbs,
    this.fats,
    this.badgeText,
    this.ingredients = const [],
    this.instructions = const [],
    this.availableIngredients = const [],
    this.missingIngredients = const [],
    this.tags = const [],
    this.reasoning,
    this.imageSearchQuery,
    this.youtubeSearchQuery,
    this.status = MealStatus.pending,
    bool? accepted,
    this.replacedByMealId,
    this.replacedMealId,
    this.isFavorite = false,
    this.createdAt,
  }) : accepted = accepted ?? (status == MealStatus.accepted);

  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? cuisine;
  final String? mealType;
  final int dayIndex;
  final String? prepTime;
  final String? cookTime;
  final String? servings;
  final String? calories;
  final String? protein;
  final String? carbs;
  final String? fats;
  final String? badgeText;
  final List<Ingredient> ingredients;
  final List<String> instructions;
  final List<String> availableIngredients;
  final List<String> missingIngredients;
  final List<String> tags;

  /// Short AI explanation of why this meal fits the household.
  final String? reasoning;
  final String? imageSearchQuery;
  final String? youtubeSearchQuery;
  final MealStatus status;
  final bool accepted;
  final String? replacedByMealId;
  final String? replacedMealId;
  final bool isFavorite;
  final DateTime? createdAt;

  bool get isPending => status == MealStatus.pending;
  bool get isAccepted => status == MealStatus.accepted;
  bool get isCompleted => status == MealStatus.completed;
  bool get isNotCompleted => status == MealStatus.notCompleted;
  bool get isReplaced => status == MealStatus.replaced;

  factory Meal.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final legacyAccepted = data['accepted'] == true;
    final status = MealStatus.fromString(
      data['status'] as String?,
      legacyAccepted: legacyAccepted,
    );

    final rawIngredients = data['ingredients'] as List<dynamic>? ?? [];
    final ingredients = <Ingredient>[];
    for (final item in rawIngredients) {
      if (item is Map) {
        ingredients.add(Ingredient.fromMap(Map<String, dynamic>.from(item)));
      } else if (item is String && item.trim().isNotEmpty) {
        ingredients.add(Ingredient(name: item.trim(), amount: ''));
      }
    }

    return Meal(
      id: doc.id,
      title: data['title'] ?? '',
      subtitle: data['subtitle'],
      imageUrl: data['imageUrl'],
      cuisine: data['cuisine'],
      mealType: data['mealType'] ?? data['type'],
      dayIndex: data['dayIndex'] ?? 0,
      prepTime: data['prepTime'],
      cookTime: data['cookTime'],
      servings: data['servings'],
      calories: data['calories'],
      protein: data['protein'] ??
          (data['macros'] is Map ? (data['macros'] as Map)['Protein'] : null),
      carbs: data['carbs'] ??
          (data['macros'] is Map ? (data['macros'] as Map)['Carbs'] : null),
      fats: data['fats'] ??
          (data['macros'] is Map ? (data['macros'] as Map)['Fats'] : null),
      badgeText: data['badgeText'],
      ingredients: ingredients,
      instructions:
          List<String>.from(data['instructions'] as List<dynamic>? ?? []),
      availableIngredients: List<String>.from(
          data['availableIngredients'] as List<dynamic>? ?? []),
      missingIngredients:
          List<String>.from(data['missingIngredients'] as List<dynamic>? ?? []),
      tags: List<String>.from(data['tags'] as List<dynamic>? ?? []),
      reasoning: data['reasoning'] as String?,
      imageSearchQuery: data['imageSearchQuery'],
      youtubeSearchQuery: data['youtubeSearchQuery'],
      status: status,
      accepted: status == MealStatus.accepted,
      replacedByMealId: data['replacedByMealId'] as String?,
      replacedMealId: data['replacedMealId'] as String?,
      isFavorite: data['isFavorite'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'subtitle': subtitle,
        'imageUrl': imageUrl,
        'cuisine': cuisine,
        'mealType': mealType,
        'dayIndex': dayIndex,
        'prepTime': prepTime,
        'cookTime': cookTime,
        'servings': servings,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fats': fats,
        'badgeText': badgeText,
        'ingredients': ingredients.map((i) => i.toMap()).toList(),
        'instructions': instructions,
        'availableIngredients': availableIngredients,
        'missingIngredients': missingIngredients,
        'tags': tags,
        'reasoning': reasoning,
        'imageSearchQuery': imageSearchQuery,
        'youtubeSearchQuery': youtubeSearchQuery,
        'status': status.name,
        'accepted': status == MealStatus.accepted,
        'replacedByMealId': replacedByMealId,
        'replacedMealId': replacedMealId,
        'isFavorite': isFavorite,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };

  Meal copyWith({
    bool clearReplacementLinks = false,
    String? id,
    int? dayIndex,
    String? mealType,
    bool clearMealType = false,
    MealStatus? status,
    bool? accepted,
    String? replacedByMealId,
    String? replacedMealId,
    bool? isFavorite,
    String? imageUrl,
    List<String>? availableIngredients,
    List<String>? missingIngredients,
    List<String>? instructions,
    List<String>? tags,
    String? reasoning,
    String? servings,
  }) =>
      Meal(
        id: id ?? this.id,
        title: title,
        subtitle: subtitle,
        imageUrl: imageUrl ?? this.imageUrl,
        cuisine: cuisine,
        mealType: clearMealType ? null : mealType ?? this.mealType,
        dayIndex: dayIndex ?? this.dayIndex,
        prepTime: prepTime,
        cookTime: cookTime,
        servings: servings ?? this.servings,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fats: fats,
        badgeText: badgeText,
        ingredients: ingredients,
        instructions: instructions ?? this.instructions,
        availableIngredients: availableIngredients ?? this.availableIngredients,
        missingIngredients: missingIngredients ?? this.missingIngredients,
        tags: tags ?? this.tags,
        reasoning: reasoning ?? this.reasoning,
        imageSearchQuery: imageSearchQuery,
        youtubeSearchQuery: youtubeSearchQuery,
        status: status ?? this.status,
        accepted: accepted ??
            (status != null ? status == MealStatus.accepted : this.accepted),
        replacedByMealId: clearReplacementLinks
            ? null
            : replacedByMealId ?? this.replacedByMealId,
        replacedMealId: clearReplacementLinks
            ? null
            : replacedMealId ?? this.replacedMealId,
        isFavorite: isFavorite ?? this.isFavorite,
        createdAt: createdAt,
      );
}

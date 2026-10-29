import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/week_calendar.dart';
import '../../meal/models/meal.dart';

class GeneratedMeal {
  const GeneratedMeal({
    required this.id,
    required this.title,
    required this.type,
    required this.prepTime,
    required this.calories,
    required this.badgeText,
    required this.imageUrl,
    required this.ingredients,
    required this.macros,
    this.availableIngredients = const [],
    this.missingIngredients = const [],
    this.instructions = const [],
    this.tags = const [],
    this.servings,
    this.cookTime,
    this.reasoning,
    this.imageSearchQuery,
    this.youtubeSearchQuery,
    this.dayIndex = 0,
    this.status = MealStatus.pending,
    this.replacedByMealId,
    this.replacedMealId,
    this.isFavorite = false,
    Meal? sourceMeal,
    bool preserveSourceIngredients = false,
  })  : _sourceMeal = sourceMeal,
        _preserveSourceIngredients = preserveSourceIngredients;

  // Display strings are intentionally retained for the editor, while an
  // untouched SDK recipe keeps its original structured ingredient quantities.
  // Neither field is persisted as extra Firestore schema data.
  final Meal? _sourceMeal;
  final bool _preserveSourceIngredients;

  final String id;
  final String title;
  final String type;
  final String prepTime;
  final String calories;
  final String badgeText;
  final String imageUrl;
  final List<String> ingredients;
  final Map<String, String> macros;
  final List<String> availableIngredients;
  final List<String> missingIngredients;
  final List<String> instructions;
  final List<String> tags;
  final String? servings;
  final String? cookTime;
  final String? reasoning;
  final String? imageSearchQuery;
  final String? youtubeSearchQuery;
  final int dayIndex;
  final MealStatus status;
  final String? replacedByMealId;
  final String? replacedMealId;
  final bool isFavorite;

  bool get isPending => status == MealStatus.pending;
  bool get isAccepted => status == MealStatus.accepted;
  bool get isCompleted => status == MealStatus.completed;
  bool get isNotCompleted => status == MealStatus.notCompleted;
  bool get isReplaced => status == MealStatus.replaced;

  /// Display tags: AI tags + derived quick tags from badge/context.
  List<String> get displayTags {
    final result = <String>[...tags];
    final badge = badgeText.toLowerCase();
    void addIf(bool cond, String tag) {
      if (cond && !result.any((t) => t.toLowerCase() == tag.toLowerCase())) {
        result.add(tag);
      }
    }

    addIf(availableIngredients.isNotEmpty, 'Pantry Friendly');
    addIf(badge.contains('quick') || badge.contains('easy'), 'Quick');
    addIf(
        badge.contains('budget') || badge.contains('cheap'), 'Budget Friendly');
    addIf(badge.contains('favorite') || isFavorite, 'Family Favorite');
    if (result.isEmpty && badgeText.isNotEmpty) result.add(badgeText);
    return result;
  }

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
          .map((i) => '${i.amount} ${i.name}'.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      macros: {
        'Protein': meal.protein ?? '',
        'Carbs': meal.carbs ?? '',
        'Fats': meal.fats ?? '',
      },
      availableIngredients: meal.availableIngredients,
      missingIngredients: meal.missingIngredients,
      instructions: meal.instructions,
      tags: meal.tags,
      servings: meal.servings,
      cookTime: meal.cookTime,
      reasoning: meal.reasoning,
      imageSearchQuery: meal.imageSearchQuery,
      youtubeSearchQuery: meal.youtubeSearchQuery,
      dayIndex: meal.dayIndex,
      status: meal.status,
      replacedByMealId: meal.replacedByMealId,
      replacedMealId: meal.replacedMealId,
      isFavorite: meal.isFavorite,
      sourceMeal: meal,
      preserveSourceIngredients: true,
    );
  }

  static bool _sameIngredientText(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var i = 0; i < first.length; i++) {
      if (first[i] != second[i]) return false;
    }
    return true;
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'mealType': type,
        'type': type,
        'prepTime': prepTime,
        'cookTime': cookTime,
        'servings': servings,
        'calories': calories,
        'badgeText': badgeText,
        'imageUrl': imageUrl,
        'ingredients':
            ingredients.map((i) => {'name': i, 'amount': ''}).toList(),
        'macros': macros,
        'protein': macros['Protein'],
        'carbs': macros['Carbs'],
        'fats': macros['Fats'],
        'instructions': instructions,
        'tags': tags,
        'reasoning': reasoning,
        'availableIngredients': availableIngredients,
        'missingIngredients': missingIngredients,
        'imageSearchQuery': imageSearchQuery,
        'youtubeSearchQuery': youtubeSearchQuery,
        'dayIndex': dayIndex,
        'status': status.name,
        'accepted': status == MealStatus.accepted,
        'replacedByMealId': replacedByMealId,
        'replacedMealId': replacedMealId,
        'isFavorite': isFavorite,
      };

  Meal toCore() {
    final source = _sourceMeal;
    final sourceText = source?.ingredients
        .map((ingredient) => '${ingredient.amount} ${ingredient.name}'.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    final keepStructuredIngredients = _preserveSourceIngredients &&
        sourceText != null &&
        _sameIngredientText(ingredients, sourceText);
    return Meal(
      id: id,
      title: title,
      subtitle: source?.subtitle,
      cuisine: source?.cuisine,
      mealType: type,
      dayIndex: dayIndex,
      prepTime: prepTime,
      cookTime: cookTime,
      servings: servings,
      calories: calories,
      badgeText: badgeText,
      imageUrl: imageUrl,
      ingredients: keepStructuredIngredients && source != null
          ? List.of(source.ingredients)
          : ingredients.map((i) => Ingredient(name: i, amount: '')).toList(),
      instructions: instructions,
      tags: tags,
      reasoning: reasoning,
      availableIngredients: availableIngredients,
      missingIngredients: missingIngredients,
      imageSearchQuery: imageSearchQuery,
      youtubeSearchQuery: youtubeSearchQuery,
      protein: macros['Protein'],
      carbs: macros['Carbs'],
      fats: macros['Fats'],
      status: status,
      accepted: status == MealStatus.accepted,
      replacedByMealId: replacedByMealId,
      replacedMealId: replacedMealId,
      isFavorite: isFavorite,
      createdAt: source != null && source.id == id ? source.createdAt : null,
    );
  }

  GeneratedMeal copyWith({
    String? id,
    String? title,
    String? type,
    String? prepTime,
    String? calories,
    String? badgeText,
    String? imageUrl,
    List<String>? ingredients,
    Map<String, String>? macros,
    List<String>? availableIngredients,
    List<String>? missingIngredients,
    List<String>? instructions,
    List<String>? tags,
    String? servings,
    String? cookTime,
    String? reasoning,
    String? imageSearchQuery,
    String? youtubeSearchQuery,
    int? dayIndex,
    MealStatus? status,
    String? replacedByMealId,
    String? replacedMealId,
    bool? isFavorite,
  }) {
    final dishChanged = title != null &&
        title.trim().toLowerCase() != this.title.trim().toLowerCase();
    return GeneratedMeal(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      prepTime: prepTime ?? this.prepTime,
      calories: calories ?? this.calories,
      badgeText: badgeText ?? this.badgeText,
      imageUrl: imageUrl ?? (dishChanged ? '' : this.imageUrl),
      ingredients: ingredients ?? this.ingredients,
      macros: macros ?? this.macros,
      availableIngredients: availableIngredients ?? this.availableIngredients,
      missingIngredients: missingIngredients ?? this.missingIngredients,
      instructions: instructions ?? this.instructions,
      tags: tags ?? this.tags,
      servings: servings ?? this.servings,
      cookTime: cookTime ?? this.cookTime,
      reasoning: reasoning ?? this.reasoning,
      imageSearchQuery: imageSearchQuery ??
          (dishChanged ? title.trim() : this.imageSearchQuery),
      youtubeSearchQuery: youtubeSearchQuery ?? this.youtubeSearchQuery,
      dayIndex: dayIndex ?? this.dayIndex,
      status: status ?? this.status,
      replacedByMealId: replacedByMealId ?? this.replacedByMealId,
      replacedMealId: replacedMealId ?? this.replacedMealId,
      isFavorite: isFavorite ?? this.isFavorite,
      sourceMeal: _sourceMeal,
      preserveSourceIngredients: _preserveSourceIngredients &&
          (ingredients == null ||
              _sameIngredientText(this.ingredients, ingredients)),
    );
  }
}

/// Passed through `/generated-plan` so the results screen is not hardcoded.
class GeneratedPlanDraft {
  const GeneratedPlanDraft({
    required this.meals,
    required this.familyMembers,
    required this.numberOfDays,
    this.startDate,
    this.title,
    this.planPath,
    this.selectedMemberIds = const [],
    this.cuisinePreferences = const [],
    this.prioritizePantry = true,
    this.initialSaveFailed = false,
    this.sourceSessionVersion,
    this.initialDayIndex,
    this.isManual = false,
  });

  factory GeneratedPlanDraft.fromSaved(SavedMealPlan plan,
      {bool reuse = false,
      DateTime? today,
      DateTime? selectedDate,
      int? sourceSessionVersion}) {
    final seed = DateTime.now().microsecondsSinceEpoch;
    final mealDays = plan.meals.isEmpty
        ? 1
        : plan.meals
            .map((meal) => meal.dayIndex + 1)
            .reduce((a, b) => a > b ? a : b);
    final declaredDays = plan.numberOfDays ??
        (plan.startDate != null && plan.endDate != null
            ? DateTime.utc(plan.endDate!.year, plan.endDate!.month,
                        plan.endDate!.day)
                    .difference(DateTime.utc(plan.startDate!.year,
                        plan.startDate!.month, plan.startDate!.day))
                    .inDays +
                1
            : plan.meals.isEmpty
                ? 7
                : mealDays);
    final days = declaredDays > mealDays ? declaredDays : mealDays;
    return GeneratedPlanDraft(
      isManual: plan.meals.isEmpty,
      sourceSessionVersion: sourceSessionVersion,
      initialDayIndex: selectedDate == null || reuse
          ? null
          : DateTime.utc(
                  selectedDate.year, selectedDate.month, selectedDate.day)
              .difference(DateTime.utc(
                  (plan.startDate ?? plan.weekStart).year,
                  (plan.startDate ?? plan.weekStart).month,
                  (plan.startDate ?? plan.weekStart).day))
              .inDays
              .clamp(0, (days < 7 ? 7 : days) - 1),
      meals: reuse
          ? plan.activeMeals
              .asMap()
              .entries
              .map((entry) => GeneratedMeal.fromCore(entry.value
                      .toCore()
                      .copyWith(
                          status: MealStatus.pending,
                          clearReplacementLinks: true))
                  .copyWith(id: 'reuse_${seed}_${entry.key}'))
              .toList()
          : plan.activeMeals,
      familyMembers: plan.familyMembers,
      selectedMemberIds: plan.familyMembers,
      numberOfDays: days,
      startDate: reuse
          ? WeekCalendar.mondayOf(today ?? DateTime.now())
          : plan.startDate ?? plan.weekStart,
      title: plan.title,
      planPath: reuse ? null : plan.sourcePath,
      cuisinePreferences: plan.cuisinePreferences,
    );
  }

  final List<GeneratedMeal> meals;
  final List<String> familyMembers;
  final int numberOfDays;
  final DateTime? startDate;
  final String? title;
  final String? planPath;
  final List<String> selectedMemberIds;
  final List<String> cuisinePreferences;
  final bool prioritizePantry;
  final bool initialSaveFailed;
  final int? sourceSessionVersion;
  final int? initialDayIndex;
  // Editor-only intent; never written as an extra Firestore schema field.
  final bool isManual;

  /// Unfilled manual slots are a template, not accepted meals. Keep partially
  /// entered recipes so normal name validation cannot silently discard them.
  List<GeneratedMeal> mealsForSaving(Iterable<GeneratedMeal> current) =>
      current.where((meal) => !isManual || !_unfilledSlot(meal)).toList();

  static bool _unfilledSlot(GeneratedMeal meal) =>
      meal.title.trim().isEmpty &&
      meal.prepTime.trim().isEmpty &&
      meal.calories.trim().isEmpty &&
      meal.imageUrl.trim().isEmpty &&
      meal.ingredients.every((value) => value.trim().isEmpty) &&
      meal.macros.values.every((value) => value.trim().isEmpty) &&
      meal.instructions.every((value) => value.trim().isEmpty) &&
      meal.availableIngredients.every((value) => value.trim().isEmpty) &&
      meal.missingIngredients.every((value) => value.trim().isEmpty) &&
      meal.tags.every((value) => value.trim().isEmpty) &&
      (meal.servings?.trim().isEmpty ?? true) &&
      (meal.cookTime?.trim().isEmpty ?? true) &&
      (meal.reasoning?.trim().isEmpty ?? true) &&
      (meal.imageSearchQuery?.trim().isEmpty ?? true) &&
      (meal.youtubeSearchQuery?.trim().isEmpty ?? true);
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
    this.startDate,
    this.endDate,
    this.numberOfDays,
    this.sourcePath,
    this.cuisinePreferences = const [],
  });

  final List<String> cuisinePreferences;
  final String? sourcePath;
  final String id;
  final String title;
  final String dates;
  final int mealsCount;
  final String estCost;
  final List<String> familyMembers;
  final List<GeneratedMeal> meals;
  final DateTime? createdAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? numberOfDays;

  /// Monday of this plan's week (falls back to createdAt / today).
  DateTime get weekStart {
    if (startDate != null) {
      return WeekCalendar.mondayOf(startDate!);
    }
    if (createdAt != null) return WeekCalendar.mondayOf(createdAt!);
    return WeekCalendar.mondayOf(DateTime.now());
  }

  /// Absolute calendar date for a meal using startDate + dayIndex.
  DateTime dateForMeal(GeneratedMeal meal) {
    final start = startDate ?? weekStart;
    return DateTime(start.year, start.month, start.day + meal.dayIndex);
  }

  factory SavedMealPlan.fromFirestore(
      String id, Map<String, dynamic> data, List<GeneratedMeal> meals) {
    final startDate = (data['startDate'] as Timestamp?)?.toDate();
    final endDate = (data['endDate'] as Timestamp?)?.toDate();
    String dates = data['dates'] as String? ?? '';
    if (dates.isEmpty && startDate != null && endDate != null) {
      dates = WeekCalendar.formatRange(startDate, endDate);
    } else if (dates.isEmpty) {
      dates = 'Saved Plan';
    }
    return SavedMealPlan(
      id: id,
      title: data['title'] as String? ?? 'Meal Plan',
      cuisinePreferences:
          List<String>.from(data['cuisinePreferences'] ?? const []),
      dates: dates,
      mealsCount: meals.length,
      estCost: data['estimatedCost'] as String? ?? '\$0.00',
      familyMembers:
          List<String>.from(data['selectedMemberIds'] as List<dynamic>? ?? []),
      meals: meals,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      startDate: startDate,
      endDate: endDate,
      numberOfDays:
          data['numberOfDays'] is int ? data['numberOfDays'] as int : null,
    );
  }

  List<GeneratedMeal> get activeMeals =>
      meals.where((m) => !m.isReplaced).toList();

  List<GeneratedMeal> get pendingMeals =>
      meals.where((m) => m.isPending).toList();

  List<GeneratedMeal> get acceptedMeals =>
      meals.where((m) => m.isAccepted).toList();

  List<GeneratedMeal> get completedMeals =>
      meals.where((m) => m.isCompleted).toList();

  List<GeneratedMeal> get notCompletedMeals =>
      meals.where((m) => m.isNotCompleted).toList();

  List<GeneratedMeal> get replacedMeals =>
      meals.where((m) => m.isReplaced).toList();

  SavedMealPlan copyWith({
    String? id,
    String? title,
    String? dates,
    int? mealsCount,
    String? estCost,
    List<String>? familyMembers,
    List<GeneratedMeal>? meals,
    DateTime? createdAt,
    DateTime? startDate,
    DateTime? endDate,
    int? numberOfDays,
    String? sourcePath,
    List<String>? cuisinePreferences,
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
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      numberOfDays: numberOfDays ?? this.numberOfDays,
      sourcePath: sourcePath ?? this.sourcePath,
      cuisinePreferences: cuisinePreferences ?? this.cuisinePreferences,
    );
  }
}

import '../../models/llm_config.dart';
import 'ingredient_restrictions.dart';
import '../../../features/meal/models/meal.dart';

// ---------------------------------------------------------------------------
// Normalized Internal Request Models
// ---------------------------------------------------------------------------

/// Normalized meal generation request holding all WhatMeal household context.
class AiMealPlanRequest {
  const AiMealPlanRequest({
    required this.familyMemberNames,
    this.memberAges = const {},
    required this.numberOfDays,
    required this.mealTypes,
    this.cuisinePreferences = const [],
    this.prioritizePantry = true,
    this.pantryItems = const [],
    this.groceryItems = const [],
    this.restrictions = const [],
    this.preferences = const [],
    this.budget,
  });

  final List<String> familyMemberNames;
  final Map<String, int> memberAges;
  final int numberOfDays;
  final List<String> mealTypes;
  final List<String> cuisinePreferences;
  final bool prioritizePantry;
  final List<String> pantryItems;
  final List<String> groceryItems;
  final List<String> restrictions;
  final List<String> preferences;
  final String? budget;

  /// Reject partial, duplicated, or out-of-range plans before they reach the UI.
  void validateMeals(List<AiMealResponse> meals) {
    if (numberOfDays < 1 ||
        mealTypes.isEmpty ||
        meals.length != numberOfDays * mealTypes.length) {
      throw const FormatException(
          'AI returned an incomplete meal plan. Please retry.');
    }
    final allowedTypes = mealTypes.map((type) => type.toLowerCase()).toSet();
    final slots = <String>{};
    for (final meal in meals) {
      final type = meal.mealType.trim().toLowerCase();
      if (meal.dayIndex < 0 ||
          meal.dayIndex >= numberOfDays ||
          !allowedTypes.contains(type) ||
          !slots.add('${meal.dayIndex}:$type')) {
        throw const FormatException(
            'AI returned invalid or duplicate meal slots. Please retry.');
      }
      meal.validateRecipe();
      IngredientRestrictions.validate(
          meal.ingredients.map((i) => i.name), restrictions);
    }
  }

  /// Compiles a clear, structured prompt instructing the model to return
  /// only a strictly formatted JSON array of meals.
  String buildPrompt() {
    final memberDetails = familyMemberNames.map((name) {
      final age = memberAges[name];
      return age != null ? '$name (age $age)' : name;
    }).join(', ');

    final cuisineNote = cuisinePreferences.isEmpty
        ? 'any cuisine (no specific preference)'
        : cuisinePreferences.join(', ');

    final availableNote = pantryItems.isNotEmpty
        ? 'Available ingredients (pantry only): ${pantryItems.join(', ')}.'
        : 'No available pantry ingredients listed.';
    final shoppingNote = groceryItems.isNotEmpty
        ? 'Shopping list (NOT available yet): ${groceryItems.join(', ')}. Do not classify these as pantry stock.'
        : '';

    final pantryPriorityNote = prioritizePantry && pantryItems.isNotEmpty
        ? 'PRIORITY: Use these pantry items first to reduce food waste: ${pantryItems.join(', ')}.'
        : '';

    final restrictionsNote = restrictions.isNotEmpty
        ? 'CRITICAL ALLERGIES & DIETARY RESTRICTIONS (NEVER INCLUDE THESE): ${restrictions.join(', ')}.'
        : 'No dietary restrictions.';

    final preferencesNote = preferences.isNotEmpty
        ? 'Dietary preferences: ${preferences.join(', ')}.'
        : '';

    final budgetNote = (budget != null && budget!.isNotEmpty)
        ? 'Estimated household budget guideline: $budget.'
        : '';

    final expectedTotalMeals = numberOfDays * mealTypes.length;

    return '''
You are WhatMeal's expert family meal planning AI.
Do not invent nutrition facts. Leave nutrition strings empty when no reliable estimate is available; label estimates explicitly.
Create a practical, healthy, family-friendly $numberOfDays-day meal plan.

Household Members: $memberDetails
Meal Types: ${mealTypes.join(', ')}
Planning Period: $numberOfDays days (dayIndex 0 to ${numberOfDays - 1})
Cuisine Preferences: $cuisineNote
$restrictionsNote
$preferencesNote
$budgetNote
$availableNote
$shoppingNote
$pantryPriorityNote

Instructions:
1. For every meal, categorize used ingredients into:
   - "availableIngredients": items from the available list used in this meal.
   - "missingIngredients": ingredients needed that must be purchased.
2. Provide step-by-step cooking instructions in an "instructions" array.
3. Realistic prep time, cook time, servings, and nutritional macros (calories, protein, carbs, fats).
4. Include Filipino, Asian, and international comfort dishes where appropriate.
5. Generate EXACTLY $expectedTotalMeals meal objects ($numberOfDays days x ${mealTypes.length} meals per day).
6. For each meal include a short "reasoning" (1-2 sentences) explaining why it fits this household (pantry, preferences, budget, restrictions).
7. Add "tags" from: "Pantry Friendly", "Budget Friendly", "Quick", "Family Favorite" when applicable.

CRITICAL: Return ONLY valid JSON. Prefer this object shape (required for providers that enforce json_object mode):
{"meals":[ ...meal objects... ]}
A bare JSON array of meal objects is also accepted. Do not add markdown backticks, explanations, or prologue.
Keep instruction/subtitle strings short. Escape quotes inside strings. Never truncate mid-object.

Schema for each meal object:
{
  "title": "Dish name",
  "subtitle": "Short appetizing description",
  "cuisine": "Cuisine style",
  "mealType": "${mealTypes.first}",
  "dayIndex": 0,
  "prepTime": "15m",
  "cookTime": "25m",
  "servings": "${familyMemberNames.length} persons",
  "calories": "480 kcal",
  "protein": "32g",
  "carbs": "50g",
  "fats": "14g",
  "badgeText": "Quick & Easy",
  "tags": ["Pantry Friendly", "Quick"],
  "reasoning": "Uses garlic and rice already in the pantry and fits the family's low-sodium preference.",
  "ingredients": [
    {"name": "ingredient name", "amount": "quantity with unit"}
  ],
  "instructions": [
    "Step 1: Prep vegetables...",
    "Step 2: Sauté aromatics...",
    "Step 3: Simmer until tender."
  ],
  "availableIngredients": ["item from pantry used"],
  "missingIngredients": ["item to buy"],
  "imageSearchQuery": "photo search query for food photo",
  "youtubeSearchQuery": "how to cook dish recipe tutorial"
}
''';
  }

  /// Smaller JSON prompt for providers with strict JSON mode (e.g. Groq).
  /// Optional [onlyDayIndex] generates a single day to avoid truncation.
  String buildCompactPrompt({int? onlyDayIndex}) {
    final memberDetails = familyMemberNames.map((name) {
      final age = memberAges[name];
      return age != null ? '$name (age $age)' : name;
    }).join(', ');

    final cuisineNote = cuisinePreferences.isEmpty
        ? 'any cuisine'
        : cuisinePreferences.join(', ');

    final availableNote = pantryItems.isEmpty
        ? 'Pantry: none listed.'
        : 'Available pantry stock: ${pantryItems.take(40).join(', ')}.';
    final shoppingNote = groceryItems.isEmpty
        ? ''
        : 'Shopping list (NOT available): ${groceryItems.take(40).join(', ')}.';
    final pantryPriorityNote = prioritizePantry && pantryItems.isNotEmpty
        ? 'Prefer pantry first: ${pantryItems.take(20).join(', ')}.'
        : '';
    final restrictionsNote =
        restrictions.isNotEmpty ? 'NEVER use: ${restrictions.join(', ')}.' : '';
    final preferencesNote =
        preferences.isNotEmpty ? 'Preferences: ${preferences.join(', ')}.' : '';
    final budgetNote =
        (budget != null && budget!.isNotEmpty) ? 'Budget: $budget.' : '';

    final dayStart = onlyDayIndex ?? 0;
    final dayEnd = onlyDayIndex ?? (numberOfDays - 1);
    final dayCount = dayEnd - dayStart + 1;
    final expected = dayCount * mealTypes.length;
    final dayHint = onlyDayIndex == null
        ? 'dayIndex from 0 to ${numberOfDays - 1}'
        : 'ONLY dayIndex $onlyDayIndex';

    return '''
Create $expected family meals as JSON for WhatMeal.
Leave unknown nutrition blank; explicitly label any estimates.
Members: $memberDetails
Meal types per day: ${mealTypes.join(', ')}
Days: $dayHint ($dayCount day(s))
Cuisine: $cuisineNote
$restrictionsNote
$preferencesNote
$budgetNote
$availableNote
$shoppingNote
$pantryPriorityNote

Return ONLY a JSON object (the word JSON is required):
{"meals":[ ... exactly $expected objects ... ]}

Each meal object keys:
title, subtitle, cuisine, mealType, dayIndex, prepTime, cookTime, servings,
calories, protein, carbs, fats, badgeText, tags, reasoning,
ingredients (array of objects like {"name":"rice","amount":"2 cups"}),
instructions (max 3 short strings),
availableIngredients, missingIngredients,
imageSearchQuery, youtubeSearchQuery

Rules:
- Valid JSON only. No markdown. No trailing commas. Escape quotes.
- Keep every string short (under 80 characters).
- Exactly $expected meals. Cover each meal type for each requested day.
''';
  }
}

/// Request to replace a single meal in an existing plan.
class AiMealReplacementRequest {
  const AiMealReplacementRequest({
    required this.currentMeal,
    this.cuisinePreferences = const [],
    this.restrictions = const [],
    this.pantryItems = const [],
    this.preferences = const [],
  });

  final Meal currentMeal;
  final List<String> cuisinePreferences;
  final List<String> restrictions;
  final List<String> pantryItems;
  final List<String> preferences;

  String buildPrompt() {
    final pantryNote = pantryItems.isNotEmpty
        ? 'Available pantry items to use if possible: ${pantryItems.join(', ')}.'
        : '';
    final cuisineNote = cuisinePreferences.isEmpty
        ? 'any cuisine'
        : cuisinePreferences.join(', ');
    final restrictionsNote = restrictions.isNotEmpty
        ? 'Dietary restrictions (MUST NOT CONTAIN): ${restrictions.join(', ')}.'
        : 'No restrictions.';

    return '''
You are WhatMeal's meal replacement assistant. Replace the following meal with an alternative.
Current Meal to replace: "${currentMeal.title}" (${currentMeal.cuisine ?? 'any'})
Meal Type: ${currentMeal.mealType ?? 'Meal'}
Day Index: ${currentMeal.dayIndex}
Cuisine Preferences: $cuisineNote
$restrictionsNote
$pantryNote
Household preferences: ${preferences.join(', ')}

Return ONLY a single valid JSON object with these exact keys:
{
  "title": "Dish name",
  "subtitle": "Brief flavor description",
  "cuisine": "Cuisine",
  "mealType": "${currentMeal.mealType ?? 'Meal'}",
  "dayIndex": ${currentMeal.dayIndex},
  "prepTime": "15m",
  "cookTime": "20m",
  "servings": "Family",
  "calories": "450 kcal",
  "protein": "28g",
  "carbs": "45g",
  "fats": "12g",
  "badgeText": "AI Replacement",
  "tags": ["Quick"],
  "reasoning": "Similar meal type with different ingredients to keep variety.",
  "ingredients": [{"name": "ingredient", "amount": "amount"}],
  "instructions": ["Step 1", "Step 2"],
  "availableIngredients": [],
  "missingIngredients": [],
  "imageSearchQuery": "food photo search term",
  "youtubeSearchQuery": "recipe tutorial search term"
}
''';
  }
}

// ---------------------------------------------------------------------------
// Normalized Internal Response Models
// ---------------------------------------------------------------------------

class AiMealResponse {
  const AiMealResponse({
    required this.title,
    this.subtitle,
    this.cuisine,
    this.mealType = 'Meal',
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
  });

  final String title;
  final String? subtitle;
  final String? cuisine;
  final String mealType;
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
  final String? reasoning;
  final String? imageSearchQuery;
  final String? youtubeSearchQuery;

  void validateRecipe() {
    if (title.trim().isEmpty ||
        ingredients.isEmpty ||
        instructions.isEmpty ||
        ingredients.any(
            (item) => item.name.trim().isEmpty || item.amount.trim().isEmpty) ||
        instructions.any((step) => step.trim().isEmpty)) {
      throw const FormatException(
          'AI returned an incomplete recipe. Please retry.');
    }
  }

  Meal toCoreMeal({int fallbackIndex = 0}) {
    return Meal(
      id: '',
      title: title.isNotEmpty ? title : 'Meal ${fallbackIndex + 1}',
      subtitle: subtitle,
      cuisine: cuisine,
      mealType: mealType,
      dayIndex: dayIndex,
      prepTime: prepTime,
      cookTime: cookTime,
      servings: servings,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
      badgeText: badgeText ?? 'AI Suggested',
      ingredients: ingredients,
      instructions: instructions,
      availableIngredients: availableIngredients,
      missingIngredients: missingIngredients,
      tags: tags,
      reasoning: reasoning,
      imageSearchQuery: imageSearchQuery,
      youtubeSearchQuery: youtubeSearchQuery,
    );
  }

  factory AiMealResponse.fromJson(Map<String, dynamic> json,
      {int fallbackIndex = 0}) {
    final title = (json['title'] ??
            json['name'] ??
            json['dish'] ??
            json['dish_name'] ??
            json['dishName'] ??
            json['meal_name'] ??
            json['mealName'] ??
            json['recipe'] ??
            json['recipe_name'] ??
            json['recipeName'] ??
            json['meal'] ??
            '')
        .toString()
        .trim();

    final subtitle = (json['subtitle'] ??
            json['description'] ??
            json['summary'] ??
            json['short_description'])
        ?.toString();

    final cuisine =
        (json['cuisine'] ?? json['cuisine_type'] ?? json['style'])?.toString();

    final mealType = (json['mealType'] ??
            json['meal_type'] ??
            json['type'] ??
            json['course'] ??
            json['category'] ??
            'Meal')
        .toString()
        .trim();

    final rawDayIndex = json['dayIndex'] ??
        json['day_index'] ??
        json['day'] ??
        json['day_number'] ??
        json['dayNumber'];
    final dayIndex = AiMealResponse._asInt(rawDayIndex, fallbackIndex);

    final prepTime =
        (json['prepTime'] ?? json['prep_time'] ?? json['prep'])?.toString();
    final cookTime =
        (json['cookTime'] ?? json['cook_time'] ?? json['cook'])?.toString();
    final servings = (json['servings'] ??
            json['serving_size'] ??
            json['portions'] ??
            json['yield'])
        ?.toString();
    final calories = (json['calories'] ??
            json['calorie_count'] ??
            json['kcal'] ??
            json['energy'])
        ?.toString();
    final protein = (json['protein'] ?? json['protein_g'])?.toString();
    final carbs =
        (json['carbs'] ?? json['carbohydrates'] ?? json['carbs_g'])?.toString();
    final fats = (json['fats'] ?? json['fat'] ?? json['fats_g'])?.toString();
    final badgeText = (json['badgeText'] ??
            json['badge_text'] ??
            json['badge'] ??
            json['tag'])
        ?.toString();

    final rawIngredients =
        json['ingredients'] ?? json['ingredient_list'] ?? json['items'];
    final parsedIngredients = <Ingredient>[];
    if (rawIngredients is List) {
      for (final item in rawIngredients) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final iName = (map['name'] ?? map['ingredient'] ?? map['item'] ?? '')
              .toString();
          final iAmount = (map['amount'] ??
                  map['quantity'] ??
                  map['qty'] ??
                  map['measure'] ??
                  '')
              .toString();
          if (iName.isNotEmpty) {
            parsedIngredients.add(Ingredient(name: iName, amount: iAmount));
          }
        } else if (item is String && item.isNotEmpty) {
          parsedIngredients.add(Ingredient(name: item, amount: ''));
        }
      }
    }

    final rawInstructions = json['instructions'] ??
        json['directions'] ??
        json['steps'] ??
        json['method'];
    final parsedInstructions = <String>[];
    if (rawInstructions is List) {
      for (final e in rawInstructions) {
        if (e is Map) {
          final step = (e['step'] ??
                  e['instruction'] ??
                  e['description'] ??
                  e['text'] ??
                  '')
              .toString()
              .trim();
          if (step.isNotEmpty) parsedInstructions.add(step);
        } else if (e != null) {
          final s = e.toString().trim();
          if (s.isNotEmpty) parsedInstructions.add(s);
        }
      }
    } else if (rawInstructions is String && rawInstructions.trim().isNotEmpty) {
      final lines = rawInstructions.split(RegExp(r'\n+|\d+\.\s*'));
      for (final line in lines) {
        final s = line.trim();
        if (s.isNotEmpty) parsedInstructions.add(s);
      }
    }

    final rawTags = json['tags'] ?? json['labels'] ?? json['categories'];
    final parsedTags = <String>[];
    if (rawTags is List) {
      for (final t in rawTags) {
        if (t != null) {
          final s = t.toString().trim();
          if (s.isNotEmpty) parsedTags.add(s);
        }
      }
    }

    final availableIngredients = <String>[];
    final rawAvailable = json['availableIngredients'] ??
        json['available_ingredients'] ??
        json['pantry_used'];
    if (rawAvailable is List) {
      for (final a in rawAvailable) {
        if (a != null) availableIngredients.add(a.toString().trim());
      }
    }

    final missingIngredients = <String>[];
    final rawMissing = json['missingIngredients'] ??
        json['missing_ingredients'] ??
        json['needed_ingredients'];
    if (rawMissing is List) {
      for (final m in rawMissing) {
        if (m != null) missingIngredients.add(m.toString().trim());
      }
    }

    final reasoning = (json['reasoning'] ??
            json['explanation'] ??
            json['notes'] ??
            json['why'])
        ?.toString()
        .trim();
    final imageSearchQuery = (json['imageSearchQuery'] ??
            json['image_search_query'] ??
            json['image_query'])
        ?.toString();
    final youtubeSearchQuery = (json['youtubeSearchQuery'] ??
            json['youtube_search_query'] ??
            json['video_query'])
        ?.toString();

    return AiMealResponse(
      title: title,
      subtitle: subtitle,
      cuisine: cuisine,
      mealType: mealType.isNotEmpty ? mealType : 'Meal',
      dayIndex: dayIndex,
      prepTime: prepTime,
      cookTime: cookTime,
      servings: servings,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
      badgeText: badgeText,
      ingredients: parsedIngredients,
      instructions: parsedInstructions,
      availableIngredients: availableIngredients,
      missingIngredients: missingIngredients,
      tags: parsedTags,
      reasoning: reasoning,
      imageSearchQuery: imageSearchQuery,
      youtubeSearchQuery: youtubeSearchQuery,
    );
  }

  static int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }
}

class AiMealPlanResponse {
  const AiMealPlanResponse({
    required this.meals,
    required this.provider,
    required this.model,
  });

  final List<AiMealResponse> meals;
  final LlmProvider provider;
  final String model;

  List<Meal> toCoreMeals() {
    return [
      for (var i = 0; i < meals.length; i++)
        meals[i].toCoreMeal(fallbackIndex: i),
    ];
  }
}

// ---------------------------------------------------------------------------
// Connection Testing State
// ---------------------------------------------------------------------------

enum TestConnectionStatus {
  failed,
  connected,
  invalidKey,
  invalidModel,
  invalidEndpoint,
  configurationError,
  authenticationRequired,
  permissionDenied,
  rateLimited,
  networkError,
  providerUnavailable,
}

class TestConnectionResult {
  const TestConnectionResult({
    required this.isValid,
    required this.status,
    this.errorMessage,
  });

  final bool isValid;
  final TestConnectionStatus status;
  final String? errorMessage;

  factory TestConnectionResult.success() => const TestConnectionResult(
        isValid: true,
        status: TestConnectionStatus.connected,
      );

  factory TestConnectionResult.failure({
    required TestConnectionStatus status,
    required String message,
  }) =>
      TestConnectionResult(
        isValid: false,
        status: status,
        errorMessage: message,
      );
}

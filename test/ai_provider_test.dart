import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/models/llm_config.dart';
import 'package:whatmeal/core/services/ai/ai_models.dart';
import 'package:whatmeal/core/services/ai/ai_logger.dart';
import 'package:whatmeal/core/services/ai/ai_json_parser.dart';
import 'package:whatmeal/core/services/ai/ai_provider_factory.dart';
import 'package:whatmeal/core/services/ai/adapters/gemini_adapter.dart';
import 'package:whatmeal/core/services/ai/adapters/openai_adapter.dart';
import 'package:whatmeal/core/services/ai/adapters/anthropic_adapter.dart';
import 'package:whatmeal/core/services/ai/adapters/groq_adapter.dart';
import 'package:whatmeal/core/services/ai/adapters/custom_adapter.dart';
import 'package:whatmeal/features/ai_settings/models/ai_provider.dart';

void main() {
  group('AI Normalized Request & Prompt Builder', () {
    test('builds comprehensive prompt with all WhatMeal context', () {
      const request = AiMealPlanRequest(
        familyMemberNames: ['Alice', 'Bob', 'Charlie'],
        memberAges: {'Charlie': 7},
        numberOfDays: 3,
        mealTypes: ['Breakfast', 'Dinner'],
        cuisinePreferences: ['Filipino', 'Asian'],
        prioritizePantry: true,
        pantryItems: ['Garlic', 'Rice', 'Soy Sauce'],
        groceryItems: ['Chicken Breast', 'Eggs'],
        restrictions: ['Peanut Allergy'],
        preferences: ['Low Sodium'],
        budget: '\$50/week',
      );

      final prompt = request.buildPrompt();

      expect(prompt, contains('Alice, Bob, Charlie (age 7)'));
      expect(prompt, contains('Breakfast, Dinner'));
      expect(prompt, contains('3 days'));
      expect(prompt, contains('Filipino, Asian'));
      expect(prompt, contains('CRITICAL ALLERGIES & DIETARY RESTRICTIONS (NEVER INCLUDE THESE): Peanut Allergy'));
      expect(prompt, contains('Low Sodium'));
      expect(prompt, contains('\$50/week'));
      expect(prompt, contains('Garlic, Rice, Soy Sauce'));
      expect(prompt, contains('Chicken Breast, Eggs'));
      expect(prompt, contains('PRIORITY: Use these pantry items first'));
      expect(prompt, contains('availableIngredients'));
      expect(prompt, contains('missingIngredients'));
      expect(prompt, contains('instructions'));
    });
  });

  group('AI JSON Parser & Validation', () {
    test('parses clean JSON array of meals', () {
      const jsonText = '''
[
  {
    "title": "Chicken Adobo",
    "subtitle": "Classic savory-tangy stew",
    "cuisine": "Filipino",
    "mealType": "Dinner",
    "dayIndex": 0,
    "prepTime": "15m",
    "cookTime": "30m",
    "servings": "4 persons",
    "calories": "450 kcal",
    "protein": "38g",
    "carbs": "12g",
    "fats": "18g",
    "badgeText": "Family Favorite",
    "ingredients": [
      {"name": "Chicken", "amount": "500g"},
      {"name": "Soy Sauce", "amount": "1/4 cup"}
    ],
    "instructions": [
      "Marinate chicken in soy sauce and garlic.",
      "Simmer until chicken is cooked through and sauce reduces."
    ],
    "availableIngredients": ["Soy Sauce"],
    "missingIngredients": ["Chicken"],
    "imageSearchQuery": "chicken adobo filipino food",
    "youtubeSearchQuery": "how to cook authentic chicken adobo"
  }
]
''';

      final meals = AiJsonParser.parseMealList(jsonText);
      expect(meals.length, equals(1));
      final meal = meals.first;
      expect(meal.title, equals('Chicken Adobo'));
      expect(meal.cuisine, equals('Filipino'));
      expect(meal.mealType, equals('Dinner'));
      expect(meal.dayIndex, equals(0));
      expect(meal.calories, equals('450 kcal'));
      expect(meal.protein, equals('38g'));
      expect(meal.ingredients.length, equals(2));
      expect(meal.ingredients.first.name, equals('Chicken'));
      expect(meal.instructions.length, equals(2));
      expect(meal.availableIngredients, contains('Soy Sauce'));
      expect(meal.missingIngredients, contains('Chicken'));

      final coreMeal = meal.toCoreMeal();
      expect(coreMeal.title, equals('Chicken Adobo'));
      expect(coreMeal.mealType, equals('Dinner'));
    });

    test('strips markdown code fences before parsing', () {
      const markdownJson = '''
Here is your requested meal plan:
```json
[
  {
    "title": "Sinigang na Baboy",
    "cuisine": "Filipino",
    "mealType": "Lunch",
    "dayIndex": 1,
    "ingredients": [{"name": "Pork", "amount": "500g"}]
  }
]
```
Enjoy your meals!
''';

      final meals = AiJsonParser.parseMealList(markdownJson);
      expect(meals.length, equals(1));
      expect(meals.first.title, equals('Sinigang na Baboy'));
      expect(meals.first.dayIndex, equals(1));
    });

    test('handles wrapped JSON object with "meals" key', () {
      const wrappedJson = '''
{
  "meals": [
    {
      "title": "Garlic Fried Rice with Egg",
      "mealType": "Breakfast",
      "dayIndex": 0,
      "ingredients": [{"name": "Rice", "amount": "2 cups"}]
    }
  ]
}
''';

      final meals = AiJsonParser.parseMealList(wrappedJson);
      expect(meals.length, equals(1));
      expect(meals.first.title, equals('Garlic Fried Rice with Egg'));
    });

    test('parses single replacement meal', () {
      const singleMealJson = '''
{
  "title": "Pork Menudo",
  "cuisine": "Filipino",
  "mealType": "Dinner",
  "dayIndex": 2,
  "calories": "520 kcal",
  "ingredients": [{"name": "Pork", "amount": "400g"}],
  "instructions": ["Sauté garlic", "Simmer tomato sauce"]
}
''';

      final meal = AiJsonParser.parseSingleMeal(singleMealJson);
      expect(meal.title, equals('Pork Menudo'));
      expect(meal.dayIndex, equals(2));
    });

    test('parses JSON with alternative field names (name, dish, recipe, prep_time)', () {
      const altJson = '''
{
  "daily_meals": [
    {
      "name": "Arroz Caldo",
      "dish_name": "Arroz Caldo",
      "course": "Breakfast",
      "day_number": 0,
      "prep_time": "10m",
      "cook_time": "20m",
      "calorie_count": "350 kcal",
      "ingredient_list": ["Rice", "Chicken", "Ginger"],
      "directions": "1. Sauté ginger and chicken.\\n2. Add rice and broth and simmer."
    }
  ]
}
''';

      final meals = AiJsonParser.parseMealList(altJson);
      expect(meals.length, equals(1));
      expect(meals.first.title, equals('Arroz Caldo'));
      expect(meals.first.mealType, equals('Breakfast'));
      expect(meals.first.prepTime, equals('10m'));
      expect(meals.first.ingredients.length, equals(3));
      expect(meals.first.instructions.length, equals(2));
    });

    test('parses nested days structure from LLM', () {
      const nestedDaysJson = '''
{
  "days": [
    {
      "day": 0,
      "meals": [
        {"title": "Pandesal with Egg", "mealType": "Breakfast"},
        {"title": "Pork Sinigang", "mealType": "Lunch"}
      ]
    },
    {
      "day": 1,
      "meals": [
        {"title": "Champorado", "mealType": "Breakfast"}
      ]
    }
  ]
}
''';

      final meals = AiJsonParser.parseMealList(nestedDaysJson);
      expect(meals.length, equals(3));
      expect(meals[0].title, equals('Pandesal with Egg'));
      expect(meals[1].title, equals('Pork Sinigang'));
      expect(meals[2].title, equals('Champorado'));
    });

    test('throws FormatException on malformed non-JSON response', () {
      expect(
        () => AiJsonParser.parseMealList('I cannot generate a meal plan today because I am down.'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('AI Logger Credential Protection', () {
    test('redacts Bearer tokens, OpenAI keys, Groq keys, Claude keys, and query secrets', () {
      const sensitiveText =
          'Error calling endpoint with Authorization: Bearer sk-1234567890abcdefghijklmn and Groq key gsk_1234567890abcdefghijklmn and Claude sk-ant-api03-abcdefghijklmn at https://api.example.com?key=AIzaSyD1234567890abcdefghijklmn';

      final sanitized = AiLogger.sanitize(sensitiveText);

      expect(sanitized, isNot(contains('sk-1234567890abcdefghijklmn')));
      expect(sanitized, isNot(contains('gsk_1234567890abcdefghijklmn')));
      expect(sanitized, isNot(contains('sk-ant-api03-abcdefghijklmn')));
      expect(sanitized, isNot(contains('AIzaSyD1234567890abcdefghijklmn')));
      expect(sanitized, contains('[REDACTED]'));
    });
  });

  group('AI Provider Factory & Adapter Isolation', () {
    test('creates distinct adapters with correct provider types and endpoints', () {
      final geminiAdapter = AiProviderFactory.create(LlmConfig(provider: LlmProvider.gemini));
      expect(geminiAdapter, isA<GeminiAdapter>());
      expect(geminiAdapter.provider, equals(LlmProvider.gemini));
      expect(geminiAdapter.model, equals('gemini-3.8-flash'));

      final openaiAdapter = AiProviderFactory.create(
        LlmConfig(provider: LlmProvider.openai, apiKey: 'sk-test', model: 'gpt-4o-mini'),
      );
      expect(openaiAdapter, isA<OpenAiAdapter>());
      expect(openaiAdapter.provider, equals(LlmProvider.openai));
      expect(openaiAdapter.model, equals('gpt-4o-mini'));

      final claudeAdapter = AiProviderFactory.create(
        LlmConfig(provider: LlmProvider.anthropic, apiKey: 'sk-ant-test', model: 'claude-3-5-haiku-20241022'),
      );
      expect(claudeAdapter, isA<AnthropicAdapter>());
      expect(claudeAdapter.provider, equals(LlmProvider.anthropic));
      expect(claudeAdapter.model, equals('claude-3-5-haiku-20241022'));

      final groqAdapter = AiProviderFactory.create(
        LlmConfig(provider: LlmProvider.groq, apiKey: 'gsk-test', model: 'llama-3.1-8b-instant'),
      );
      expect(groqAdapter, isA<GroqAdapter>());
      expect(groqAdapter.provider, equals(LlmProvider.groq));
      expect(groqAdapter.model, equals('llama-3.1-8b-instant'));
      expect(GroqAdapter.baseUrl, equals('https://api.groq.com/openai/v1'));
      expect(GroqAdapter.completionsEndpoint, equals('https://api.groq.com/openai/v1/chat/completions'));

      final customAdapter = AiProviderFactory.create(
        LlmConfig(
          provider: LlmProvider.custom,
          apiKey: 'custom-key',
          customEndpoint: 'http://localhost:11434/v1',
          model: 'mistral',
          isOpenAiCompatible: true,
        ),
      ) as CustomAdapter;
      expect(customAdapter.provider, equals(LlmProvider.custom));
      expect(customAdapter.completionsUrl, equals('http://localhost:11434/v1/chat/completions'));
      expect(customAdapter.isOpenAiCompatible, isTrue);
    });
  });

  group('Provider Switching & Reverting Logic', () {
    test('default LlmConfig has Gemini with no custom key', () {
      final config = LlmConfig.defaultConfig;
      expect(config.provider, equals(LlmProvider.gemini));
      expect(config.isCustom, isFalse);
      expect(config.apiKey, isNull);
    });

    test('AiProviderConfig masks saved API keys in UI', () {
      const config = AiProviderConfig(
        providerType: AiProviderType.groq,
        selectedModel: 'llama-3.1-8b-instant',
        apiKey: 'gsk_1234567890abcdef',
      );

      final masked = config.maskedApiKey;
      expect(masked, equals('gsk_••••••••cdef'));
      expect(masked, isNot(contains('1234567890ab')));
    });

    test('reverting provider config produces default Gemini config', () {
      final customConfig = LlmConfig(
        provider: LlmProvider.groq,
        apiKey: 'gsk_123456',
        model: 'llama-3.1-8b-instant',
      );
      expect(customConfig.isCustom, isTrue);

      // Revert to default
      final reverted = LlmConfig.defaultConfig;
      expect(reverted.provider, equals(LlmProvider.gemini));
      expect(reverted.apiKey, isNull);
      expect(reverted.isCustom, isFalse);
    });
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/services/ai/ai_json_parser.dart';
import 'package:whatmeal/core/services/ai/ai_models.dart';
import 'package:whatmeal/features/meal/models/meal.dart';

const _planRequest = AiMealPlanRequest(
  familyMemberNames: ['Disposable demo member'],
  numberOfDays: 1,
  mealTypes: ['Dinner'],
);

AiMealResponse _recipe(List<Ingredient> ingredients) => AiMealResponse(
      title: 'Rice bowl',
      mealType: 'Dinner',
      ingredients: ingredients,
      instructions: const ['Cook the rice and season before serving.'],
    );

Map<String, dynamic> _recipeJson(List<Object> ingredients) => {
      'title': 'Rice bowl',
      'mealType': 'Dinner',
      'dayIndex': 0,
      'ingredients': ingredients,
      'instructions': ['Cook the rice and season before serving.'],
    };

void main() {
  test('compact Groq prompt requests separate ingredient names and amounts',
      () {
    final prompt = _planRequest.buildCompactPrompt();

    expect(
        prompt,
        contains(
            'ingredients (array of objects like {"name":"rice","amount":"2 cups"})'));
    expect(prompt, isNot(contains('ingredients (array of short strings')));
  });

  for (final amount in ['', ' \t\n ']) {
    test('recipe rejects ${amount.isEmpty ? 'empty' : 'whitespace'} amounts',
        () {
      final recipe = _recipe([Ingredient(name: 'Rice', amount: amount)]);
      expect(recipe.validateRecipe, throwsFormatException);
    });
  }

  test('parsed plan with omitted ingredient amount cannot pass validation', () {
    final meals = AiJsonParser.parseMealList(jsonEncode({
      'meals': [
        _recipeJson([
          {'name': 'Rice'}
        ])
      ]
    }));

    expect(meals.single.ingredients.single.amount, '');
    expect(() => _planRequest.validateMeals(meals), throwsFormatException);
  });

  test('parsed replacement with whitespace amount cannot pass validation', () {
    final meal = AiJsonParser.parseSingleMeal(jsonEncode(_recipeJson([
      {'name': 'Rice', 'amount': ' \t '}
    ])));

    expect(meal.validateRecipe, throwsFormatException);
  });

  test('ingredient strings do not imply a separately usable quantity', () {
    final meal =
        AiJsonParser.parseSingleMeal(jsonEncode(_recipeJson(['2 cups rice'])));

    expect(meal.ingredients.single.name, '2 cups rice');
    expect(meal.ingredients.single.amount, '');
    expect(meal.validateRecipe, throwsFormatException);
  });

  test('one quantified ingredient cannot conceal another missing amount', () {
    final recipe = _recipe(const [
      Ingredient(name: 'Rice', amount: '1 cup'),
      Ingredient(name: 'Salt', amount: ''),
    ]);

    expect(recipe.validateRecipe, throwsFormatException);
  });

  test('explicit to taste remains a valid qualitative amount', () {
    final recipe = _recipe(const [
      Ingredient(name: 'Rice', amount: '1 cup'),
      Ingredient(name: 'Salt', amount: 'to taste'),
    ]);

    expect(recipe.validateRecipe, returnsNormally);
    expect(recipe.ingredients.last.amount, 'to taste');
  });

  test('ordinary quantified ingredients remain valid without guessing units',
      () {
    final recipe = _recipe(const [
      Ingredient(name: 'Rice', amount: '1 cup'),
      Ingredient(name: 'Carrots', amount: '100 g'),
      Ingredient(name: 'Oil', amount: '1/2 tbsp'),
      Ingredient(name: 'Salt', amount: '1 pinch'),
    ]);

    expect(recipe.validateRecipe, returnsNormally);
  });

  test('parsed complete plan preserves quantitative and qualitative amounts',
      () {
    final meals = AiJsonParser.parseMealList(jsonEncode({
      'meals': [
        _recipeJson([
          {'name': 'Rice', 'amount': '1 cup'},
          {'name': 'Salt', 'amount': 'to taste'},
        ])
      ]
    }));

    expect(() => _planRequest.validateMeals(meals), returnsNormally);
    expect(meals.single.ingredients.map((ingredient) => ingredient.amount),
        ['1 cup', 'to taste']);
  });

  test('parsed complete replacement preserves its ingredient quantities', () {
    final meal = AiJsonParser.parseSingleMeal(jsonEncode(_recipeJson([
      {'name': 'Rice', 'amount': '2 cups'},
      {'name': 'Salt', 'amount': 'to taste'},
    ])));

    expect(meal.validateRecipe, returnsNormally);
    expect(meal.ingredients.first.amount, '2 cups');
  });
}

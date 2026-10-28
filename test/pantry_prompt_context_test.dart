import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/services/ai/ai_models.dart';
import 'package:whatmeal/core/services/ai/pantry_prompt_context.dart';
import 'package:whatmeal/features/pantry/models/pantry_item.dart';
import 'package:whatmeal/features/meal/models/meal.dart';

void main() {
  final now = DateTime(2026, 10, 19, 15, 30);
  PantryItem item(String name, String quantity,
          {PantryStatus status = PantryStatus.available, DateTime? expires}) =>
      PantryItem(
          name: name,
          quantity: quantity,
          status: status,
          expirationDate: expires ?? DateTime(2026, 10, 21));

  test('known amounts and units survive into plan and replacement prompts', () {
    final context = pantryPromptContext([
      item('Rice', '1/2 cup'),
      item('Milk', '250 ml', status: PantryStatus.runningLow),
      item('Flour', '0.75 kg'),
    ], now: now);
    expect(context, ['1/2 cup Rice', '250 ml Milk', '0.75 kg Flour']);
    final prompt = AiMealPlanRequest(
      familyMemberNames: const ['Test member'],
      numberOfDays: 1,
      mealTypes: const ['Dinner'],
      pantryItems: context,
    ).buildPrompt();
    expect(
        prompt,
        contains(
            'Available ingredients (pantry only): 1/2 cup Rice, 250 ml Milk, 0.75 kg Flour.'));
    final replacement = AiMealReplacementRequest(
      currentMeal: Meal(id: 'test-meal', title: 'Rice bowl'),
      pantryItems: context,
    ).buildPrompt();
    expect(
        replacement,
        contains(
            'Available pantry items to use if possible: 1/2 cup Rice, 250 ml Milk, 0.75 kg Flour.'));
  });

  test(
      'used needed and expired stock is excluded; expiry today remains available',
      () {
    final context = pantryPromptContext([
      item('Used rice', '1 cup', status: PantryStatus.used),
      item('Shopping eggs', '3 pcs', status: PantryStatus.needed),
      item('Old milk', '1 L', expires: DateTime(2026, 10, 18, 23, 59)),
      item('Today spinach', '100 g', expires: DateTime(2026, 10, 19)),
      item('Low oats', '1/4 cup', status: PantryStatus.runningLow),
    ], now: now);
    expect(context, ['100 g Today spinach', '1/4 cup Low oats']);
  });

  test('blank quantities stay unknown without fabricating amount or unit', () {
    final context = pantryPromptContext([
      item('  Salt  ', '  '),
      item('Pepper', ''),
      item('  ', '2 kg'),
    ], now: now);
    expect(context, ['Salt', 'Pepper']);
  });

  test('separate lots and free-form quantities are retained without conversion',
      () {
    final context = pantryPromptContext([
      item('Rice', ' 1 cup '),
      item('Rice', '250 g'),
      item('Beans', 'half a jar'),
    ], now: now);
    expect(context, ['1 cup Rice', '250 g Rice', 'half a jar Beans']);
  });
}

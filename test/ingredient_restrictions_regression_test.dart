import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/services/ai/ingredient_restrictions.dart';

void main() {
  for (final restriction in ['Dairy-free', 'Lactose-free', 'Vegan']) {
    for (final ingredient in [
      'coconut milk',
      'almond milk',
      'oat milk',
      'soy milk',
      'coconut cream',
      'peanut butter'
    ]) {
      test('$restriction accepts explicitly named $ingredient substitute', () {
        expect(
            () => IngredientRestrictions.validate([ingredient], [restriction]),
            returnsNormally);
      });
    }
    for (final ingredient in [
      'milk',
      'butter',
      'cheese',
      'coconut milk and cow milk',
      'peanut butter with milk'
    ]) {
      test('$restriction still rejects $ingredient', () {
        expect(
            () => IngredientRestrictions.validate([ingredient], [restriction]),
            throwsFormatException);
      });
    }
  }
  for (final entry in {
    'almond milk': ['Dairy-free', 'Nut allergy'],
    'peanut butter': ['Vegan', 'Peanut allergy'],
    'soy milk': ['Dairy-free', 'Soy allergy'],
    'coconut milk with whey': ['Dairy-free'],
    'oat milk with casein': ['Dairy-free'],
    'coconut milk': ['Avoid coconut milk'],
    'almond milk and rice': ['No milk'],
  }.entries) {
    test('substitution does not bypass explicit restrictions: ${entry.key}',
        () {
      expect(() => IngredientRestrictions.validate([entry.key], entry.value),
          throwsFormatException);
    });
  }
}

/// A conservative backstop for common explicitly selected restrictions.
/// Free-text restrictions also remain in the provider prompt; this is not a
/// clinical allergy guarantee or a substitute for checking packaged ingredients.
class IngredientRestrictions {
  static void validate(
      Iterable<String> ingredients, Iterable<String> restrictions) {
    const groups = <String, List<String>>{
      'dairy': [
        'milk',
        'cheese',
        'butter',
        'cream',
        'yogurt',
        'whey',
        'casein'
      ],
      'lactose': ['milk', 'cheese', 'butter', 'cream', 'yogurt', 'whey'],
      'egg': ['egg', 'eggs', 'mayonnaise'],
      'peanut': ['peanut', 'peanuts', 'groundnut', 'groundnuts'],
      'nut': [
        'peanut',
        'peanuts',
        'almond',
        'almonds',
        'walnut',
        'walnuts',
        'cashew',
        'cashews',
        'pecan',
        'pistachio'
      ],
      'shellfish': [
        'shrimp',
        'prawn',
        'crab',
        'lobster',
        'clam',
        'mussel',
        'oyster',
        'scallop'
      ],
      'gluten': ['wheat', 'barley', 'rye', 'semolina', 'couscous'],
      'soy': ['soy', 'soya', 'tofu', 'tempeh', 'edamame'],
      'fish': ['fish', 'salmon', 'tuna', 'cod', 'anchovy', 'tilapia', 'bangus'],
      'vegetarian': [
        'chicken',
        'beef',
        'pork',
        'bacon',
        'ham',
        'lamb',
        'turkey',
        'fish',
        'shrimp',
        'gelatin'
      ],
      'vegan': [
        'chicken',
        'beef',
        'pork',
        'bacon',
        'ham',
        'lamb',
        'turkey',
        'fish',
        'shrimp',
        'milk',
        'cheese',
        'egg',
        'eggs',
        'butter',
        'honey',
        'gelatin'
      ],
    };
    final forbidden = <String>{};
    final literalForbidden = <String>{};
    for (final raw in restrictions) {
      final restriction = raw.toLowerCase();
      for (final entry in groups.entries) {
        if (RegExp('\\b${entry.key}s?\\b').hasMatch(restriction)) {
          forbidden.addAll(entry.value);
        }
      }
      final literal = restriction
          .replaceFirst(RegExp(r'^(no |avoid |allergic to )'), '')
          .replaceFirst(RegExp(r' (allergy|free)$'), '')
          .trim();
      if (literal.isNotEmpty) literalForbidden.add(literal);
    }
    for (final ingredient in ingredients) {
      for (final forbiddenName in {...forbidden, ...literalForbidden}) {
        // Classify explicitly named plant substitutes only for group-derived
        // dairy terms. Explicit exclusions still match the original ingredient,
        // and nut/soy checks and additional dairy ingredients remain intact.
        final candidate = !literalForbidden.contains(forbiddenName) &&
                const {'milk', 'cream', 'butter'}.contains(forbiddenName)
            ? _withoutPlantDairyTerms(ingredient)
            : ingredient;
        if (RegExp('\\b${RegExp.escape(forbiddenName)}\\b',
                caseSensitive: false)
            .hasMatch(candidate)) {
          throw const FormatException(
              'Generated meal conflicts with a dietary restriction. Please regenerate.');
        }
      }
    }
  }

  static String _withoutPlantDairyTerms(String ingredient) => ingredient
      .replaceAllMapped(
          RegExp(
              r'\b(coconut|almond|oat|soy|soya|rice|cashew|hemp|pea)\s+(milk|cream)\b',
              caseSensitive: false),
          (match) => '${match[1]} substitute')
      .replaceAllMapped(
          RegExp(
              r'\b(peanut|almond|cashew|sunflower seed|cocoa|cacao|apple)\s+butter\b',
              caseSensitive: false),
          (match) => '${match[1]} substitute');
}

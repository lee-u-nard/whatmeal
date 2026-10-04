/// Helpers for matching recipe ingredients against pantry item names.
///
/// Matching is name-based only (case-insensitive) and treats common
/// singular/plural forms as the same item (egg/eggs, tomato/tomatoes).
class IngredientMatcher {
  IngredientMatcher._();

  /// True when [ingredient] is considered present in [pantryNames].
  static bool isInPantry(String ingredient, Iterable<String> pantryNames) {
    final needle = normalize(ingredient);
    if (needle.isEmpty) return false;
    for (final name in pantryNames) {
      if (_namesMatch(needle, normalize(name))) return true;
    }
    return false;
  }

  /// Split [ingredients] into (inPantry, needToBuy) using live pantry names.
  static ({List<String> inPantry, List<String> needToBuy}) partition(
    Iterable<String> ingredients,
    Iterable<String> pantryNames,
  ) {
    final inPantry = <String>[];
    final needToBuy = <String>[];
    final seenBuy = <String>{};
    final seenHave = <String>{};

    for (final raw in ingredients) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      final key = normalize(name);
      if (key.isEmpty) continue;

      if (isInPantry(name, pantryNames)) {
        if (seenHave.add(key)) inPantry.add(name);
      } else {
        if (seenBuy.add(key)) needToBuy.add(name);
      }
    }
    return (inPantry: inPantry, needToBuy: needToBuy);
  }

  /// Whether two normalized ingredient names refer to the same item.
  static bool _namesMatch(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;
    // "green onion" vs "onion", "chicken breast" vs "chicken"
    if (a.contains(b) || b.contains(a)) return true;
    final aTokens = a.split(' ').where((t) => t.length > 2).toSet();
    final bTokens = b.split(' ').where((t) => t.length > 2).toSet();
    if (aTokens.isNotEmpty && bTokens.isNotEmpty) {
      if (aTokens.intersection(bTokens).isNotEmpty) {
        // Prefer matching the primary noun (last significant token).
        final aLast = a.split(' ').last;
        final bLast = b.split(' ').last;
        if (aLast == bLast) return true;
      }
    }
    return false;
  }

  /// Lowercase, strip quantities/units, collapse whitespace, singularize tokens.
  static String normalize(String raw) {
    var s = raw.toLowerCase().trim();
    if (s.isEmpty) return '';

    // Drop parenthetical notes: "tofu (firm)"
    s = s.replaceAll(RegExp(r'\([^)]*\)'), ' ');

    // Strip leading quantities: "2 cups", "200g", "1/2 tsp", "3 pcs"
    s = s.replaceFirst(
      RegExp(
        r'^[\d./¼½¾]+\s*'
        r'(cups?|tbsp|tbsps?|tsp|tsps?|g|kg|ml|l|oz|lbs?|lb|'
        r'pieces?|pcs?|cloves?|slices?|cans?|packs?|bunches?|'
        r'handfuls?|pinch(?:es)?|dash(?:es)?)?\s*',
      ),
      '',
    );

    // Keep letters, spaces, hyphens only.
    s = s.replaceAll(RegExp(r'[^a-z\s-]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) return '';

    return s.split(' ').map(_singularizeToken).join(' ');
  }

  static String _singularizeToken(String word) {
    if (word.length <= 3) return word;

    // irregulars
    const irregular = {
      'leaves': 'leaf',
      'loaves': 'loaf',
      'potatoes': 'potato',
      'tomatoes': 'tomato',
      'heroes': 'hero',
      'chilies': 'chili',
      'chillies': 'chilli',
      'berries': 'berry',
      'cherries': 'cherry',
      'strawberries': 'strawberry',
      'blueberries': 'blueberry',
      'raspberries': 'raspberry',
      'children': 'child',
      'geese': 'goose',
      'mice': 'mouse',
    };
    if (irregular.containsKey(word)) return irregular[word]!;

    if (word.endsWith('ies') && word.length > 4) {
      return '${word.substring(0, word.length - 3)}y';
    }
    if (word.endsWith('oes') && word.length > 4) {
      return word.substring(0, word.length - 2); // tomatoes -> tomato
    }
    if (word.endsWith('ses') ||
        word.endsWith('xes') ||
        word.endsWith('zes') ||
        word.endsWith('ches') ||
        word.endsWith('shes')) {
      return word.substring(0, word.length - 2);
    }
    if (word.endsWith('s') && !word.endsWith('ss') && !word.endsWith('us')) {
      return word.substring(0, word.length - 1);
    }
    return word;
  }

  /// Full ingredient list for a meal: prefer [ingredients], else merge AI lists.
  static List<String> allIngredients({
    required List<String> ingredients,
    List<String> availableIngredients = const [],
    List<String> missingIngredients = const [],
  }) {
    if (ingredients.isNotEmpty) return ingredients;
    final merged = <String>[];
    final seen = <String>{};
    for (final i in [...availableIngredients, ...missingIngredients]) {
      final key = normalize(i);
      if (key.isEmpty) continue;
      if (seen.add(key)) merged.add(i.trim());
    }
    return merged;
  }
}

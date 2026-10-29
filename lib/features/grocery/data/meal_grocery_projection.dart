import 'dart:convert';
import 'dart:math' as math;
import '../../../core/utils/ingredient_matcher.dart';
import '../../meal_plan/models/saved_meal_plan.dart';
import '../../pantry/models/pantry_item.dart';
import '../models/grocery_item.dart';

/// A read model of persisted meals, not a second independently edited meal ledger.
/// Every source is a document path; removing a source recalculates its contribution.
class MealGroceryRequirement {
  MealGroceryRequirement(this.name, this.unit);
  final String name;
  final String unit;
  final Map<String, double> sources = {};
  double available = 0;
  bool unknown = false;
  bool nameAvailable = false;
  double get required => sources.values.fold(0, (a, b) => a + b);
  double get missing => math.max(0.0, required - available);
  String get id => 'meal_${base64Url.encode(utf8.encode('$name|$unit'))}';
  String amount(double value) =>
      '${value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '')} $unit'
          .trim();
  GroceryItem toItem(GroceryItem? receipt) {
    final purchased = receipt != null &&
        receipt.isPurchased &&
        receipt.sourceMealPaths.any(sources.containsKey);
    final bought =
        purchased ? IngredientQuantity.parse(receipt.quantity) : null;
    // A checked row is a shopping completion marker, not a second inventory.
    // Stock changes are authoritative in pantry; never double-count a purchase
    // that the user subsequently adds to pantry.
    final purchaseCovers = purchased &&
        (unknown || (bought?.unit == unit && (bought?.amount ?? 0) >= missing));
    final covered = unknown ? nameAvailable : missing == 0;
    return GroceryItem(
      id: id,
      name: name,
      sourceMealPaths: sources.keys.toList(),
      quantity: unknown ? 'Check recipe quantity' : amount(missing),
      category: covered ? 'AVAILABLE IN PANTRY' : 'NEEDED FOR MEALS',
      status: covered
          ? GroceryStatus.available
          : purchaseCovers
              ? GroceryStatus.used
              : GroceryStatus.needed,
      tag: unknown
          ? '${sources.length} meal(s); verify pantry quantity'
          : 'Meals: ${amount(required)}; pantry: ${amount(available)}',
    );
  }
}

/// Conservative conversion: never equate volume and mass or guess package sizes.
class IngredientQuantity {
  const IngredientQuantity(this.amount, this.unit, this.name);
  final double? amount;
  final String unit;
  final String name;
  static IngredientQuantity parse(String raw) {
    var text = raw
        .trim()
        .toLowerCase()
        .replaceAll('½', '1/2')
        .replaceAll('¼', '1/4')
        .replaceAll('¾', '3/4');
    const number = r'(\d+(?:\.\d+)?(?:\s+\d+/\d+|/\d+)?)';
    const units =
        r'(kilograms?|kg|grams?|g|millilit(?:er|re)s?|ml|lit(?:er|re)s?|l|cups?|tablespoons?|tbsp|teaspoons?|tsp|pieces?|pcs?|units?|cloves?|cans?|packs?|bunches?)';
    var match = RegExp('^$number\\s*$units?\\b\\s*', caseSensitive: false)
        .firstMatch(text);
    var name = text;
    if (match != null) {
      name = text.substring(match.end);
    } else {
      match = RegExp('\\s+$number\\s*$units?\$', caseSensitive: false)
          .firstMatch(text);
      if (match != null) name = text.substring(0, match.start);
    }
    if (match == null) return IngredientQuantity(null, '', canonicalName(text));
    double fraction(String v) {
      final parts = v.split('/');
      if (parts.length == 1) return double.parse(v);
      final denominator = double.parse(parts[1]);
      return denominator == 0
          ? double.nan
          : double.parse(parts[0]) / denominator;
    }

    final amount = match
        .group(1)!
        .split(RegExp(r'\s+'))
        .map(fraction)
        .fold<double>(0, (a, b) => a + b);
    var unit = match.group(2) ?? 'unit';
    var factor = 1.0;
    if (RegExp(r'^(kg|kilogram)').hasMatch(unit)) {
      unit = 'g';
      factor = 1000;
    } else if (RegExp(r'^(g|gram)').hasMatch(unit)) {
      unit = 'g';
    } else if (RegExp(r'^(ml|millilit)').hasMatch(unit)) {
      unit = 'ml';
    } else if (RegExp(r'^(l|lit)').hasMatch(unit)) {
      unit = 'ml';
      factor = 1000;
    } else if (RegExp(r'^(piece|pc|unit)').hasMatch(unit)) {
      unit = 'unit';
    } else {
      unit = IngredientMatcher.normalize(unit);
    }
    return IngredientQuantity(
        amount.isFinite && amount >= 0 ? amount * factor : null,
        unit,
        canonicalName(name));
  }

  static String canonicalName(String raw) {
    final name = IngredientMatcher.normalize(raw);
    // Explicit aliases, never substring matching (nut is not coconut).
    return const {
          'red onion': 'onion',
          'white onion': 'onion',
          'yellow onion': 'onion'
        }[name] ??
        name;
  }
}

class MealGroceryProjection {
  static Map<String, MealGroceryRequirement> calculate(
      Iterable<SavedMealPlan> plans, Iterable<PantryItem> pantry,
      {DateTime? now}) {
    final requirements = <String, MealGroceryRequirement>{};
    for (final plan in plans) {
      for (final meal in plan.meals.where((m) => m.isAccepted)) {
        final source = '${plan.sourcePath ?? plan.id}/meals/${meal.id}';
        _addMeal(requirements, meal, source);
      }
    }
    return _applyPantry(requirements, pantry, now);
  }

  static Map<String, MealGroceryRequirement> forMeal(
      GeneratedMeal meal, Iterable<PantryItem> pantry,
      {DateTime? now}) {
    final requirements = <String, MealGroceryRequirement>{};
    _addMeal(requirements, meal, 'recipe/${meal.id}');
    return _applyPantry(requirements, pantry, now);
  }

  static void _addMeal(Map<String, MealGroceryRequirement> requirements,
      GeneratedMeal meal, String source) {
    for (final raw in IngredientMatcher.allIngredients(
        ingredients: meal.ingredients,
        availableIngredients: meal.availableIngredients,
        missingIngredients: meal.missingIngredients)) {
      final q = IngredientQuantity.parse(raw);
      if (q.name.isEmpty) continue;
      final requirement = requirements.putIfAbsent(
          '${q.name}|${q.unit}', () => MealGroceryRequirement(q.name, q.unit));
      requirement.sources.update(source, (v) => v + (q.amount ?? 0),
          ifAbsent: () => q.amount ?? 0);
      requirement.unknown |= q.amount == null;
    }
  }

  static Map<String, MealGroceryRequirement> _applyPantry(
      Map<String, MealGroceryRequirement> requirements,
      Iterable<PantryItem> pantry,
      DateTime? now) {
    final today = now ?? DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    for (final item in pantry) {
      if (item.status == PantryStatus.used ||
          item.status == PantryStatus.needed ||
          item.expirationDate.isBefore(day)) {
        continue;
      }
      final quantity = IngredientQuantity.parse(item.quantity);
      final name = IngredientQuantity.canonicalName(item.name);
      // Name-only recipes use explicit usable pantry presence. Do not guess a
      // quantity for measured recipes or treat zero stock as available.
      if (quantity.amount == null || quantity.amount! > 0) {
        for (final requirement in requirements.values) {
          if (requirement.name == name && requirement.unknown) {
            requirement.nameAvailable = true;
          }
        }
      }
      final key =
          '${IngredientQuantity.canonicalName(item.name)}|${quantity.unit}';
      final requirement = requirements[key];
      if (requirement != null && quantity.amount != null) {
        requirement.available += quantity.amount!;
      }
    }
    return {
      for (final requirement in requirements.values) requirement.id: requirement
    };
  }
}

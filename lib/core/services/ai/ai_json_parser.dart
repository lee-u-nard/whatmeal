import 'dart:convert';
import 'ai_models.dart';

/// Robust parser for AI responses. Validates structure and prevents crashes
/// caused by markdown fences, surrounding text, truncated output, or
/// common model JSON mistakes (trailing commas, unescaped quotes, nested days/meals wrappers).
class AiJsonParser {
  AiJsonParser._();

  /// Parses a raw model completion string into a validated list of [AiMealResponse].
  /// Throws a descriptive [FormatException] if no valid meals can be extracted.
  static List<AiMealResponse> parseMealList(String rawText) {
    if (rawText.trim().isEmpty) {
      throw const FormatException('AI returned an empty response.');
    }

    final candidates = _jsonCandidates(rawText, preferArray: true);
    Object? decoded;

    for (final candidate in candidates) {
      try {
        decoded = jsonDecode(candidate);
        break;
      } catch (_) {}
    }

    // Last resort: salvage complete meal objects from a truncated/broken payload.
    if (decoded == null) {
      final salvaged = _salvageMealMaps(rawText);
      if (salvaged.isNotEmpty) {
        decoded = salvaged;
      }
    }

    if (decoded == null) {
      throw FormatException(
        'AI returned invalid meal JSON. Please retry.',
      );
    }

    final items = _extractMealItems(decoded);

    final meals = <AiMealResponse>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is Map) {
        try {
          final map = Map<String, dynamic>.from(item);
          final parsed = AiMealResponse.fromJson(map, fallbackIndex: i);
          if (parsed.title.isNotEmpty) {
            meals.add(parsed);
          }
        } catch (_) {
          // Skip individual malformed items rather than failing the whole plan
        }
      }
    }

    // If still empty, try fallback recursive collection of maps
    if (meals.isEmpty && decoded is Map) {
      final recursiveMaps = <Map<String, dynamic>>[];
      _collectMealMapsRecursive(decoded, recursiveMaps);
      for (var i = 0; i < recursiveMaps.length; i++) {
        try {
          final parsed =
              AiMealResponse.fromJson(recursiveMaps[i], fallbackIndex: i);
          if (parsed.title.isNotEmpty) {
            meals.add(parsed);
          }
        } catch (_) {}
      }
    }

    if (meals.isEmpty) {
      throw const FormatException(
        'No valid meal objects could be parsed from the AI output.',
      );
    }

    return meals;
  }

  /// Parses a raw model completion string into a single [AiMealResponse].
  static AiMealResponse parseSingleMeal(String rawText) {
    if (rawText.trim().isEmpty) {
      throw const FormatException('AI returned an empty response.');
    }

    final candidates = _jsonCandidates(rawText, preferArray: false);
    Object? decoded;

    for (final candidate in candidates) {
      try {
        decoded = jsonDecode(candidate);
        break;
      } catch (_) {}
    }

    if (decoded == null) {
      final salvaged = _salvageMealMaps(rawText);
      if (salvaged.isNotEmpty) {
        decoded = salvaged.first;
      }
    }

    if (decoded == null) {
      throw FormatException(
          'AI returned invalid replacement JSON. Please retry.');
    }

    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      final items = _extractMealItems(map);
      for (final item in items) {
        if (item is Map) {
          final meal = AiMealResponse.fromJson(Map<String, dynamic>.from(item));
          if (meal.title.isNotEmpty) return meal;
        }
      }
      final meal = AiMealResponse.fromJson(map);
      if (meal.title.isNotEmpty) return meal;
    } else if (decoded is List && decoded.isNotEmpty) {
      for (final item in decoded) {
        if (item is Map) {
          final meal = AiMealResponse.fromJson(Map<String, dynamic>.from(item));
          if (meal.title.isNotEmpty) return meal;
        }
      }
    }

    throw const FormatException(
      'Failed to extract valid meal data from replacement response.',
    );
  }

  /// Extracts meal objects from diverse JSON structures (arrays, day wrappers, mealPlan maps, etc.)
  static List<dynamic> _extractMealItems(dynamic decoded) {
    if (decoded is List) {
      final result = <dynamic>[];
      for (final item in decoded) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          if (map['meals'] is List) {
            result.addAll(_extractMealItems(map['meals']));
          } else if (map['dishes'] is List) {
            result.addAll(_extractMealItems(map['dishes']));
          } else if (map['recipes'] is List) {
            result.addAll(_extractMealItems(map['recipes']));
          } else if (_isLikelyMealMap(map)) {
            result.add(map);
          } else {
            result.addAll(_extractMealItems(map));
          }
        } else {
          result.add(item);
        }
      }
      return result;
    }

    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);

      // 1. If map has specific plan list keys, extract from them
      for (final key in [
        'meals',
        'meal_plan',
        'mealPlan',
        'plan',
        'plans',
        'recipes',
        'dishes',
        'menu',
        'data',
        'daily_meals',
        'dailyMeals',
      ]) {
        if (map[key] is List) {
          return _extractMealItems(map[key]);
        }
      }

      if (map['days'] is List || map['daily_plan'] is List) {
        final days = (map['days'] ?? map['daily_plan']) as List;
        return _extractMealItems(days);
      }

      // 2. If the map itself is a single meal (e.g. has title/dish and ingredients), return it
      if (_isLikelyMealMap(map)) {
        return [map];
      }

      // 3. If the map is a dictionary of days (e.g. {"Day 1": [...], "Day 2": [...]})
      final fromValues = <dynamic>[];
      for (final entry in map.entries) {
        if (entry.key == 'tags' ||
            entry.key == 'ingredients' ||
            entry.key == 'instructions') {
          continue;
        }
        final val = entry.value;
        if (val is List) {
          fromValues.addAll(_extractMealItems(val));
        } else if (val is Map &&
            _isLikelyMealMap(Map<String, dynamic>.from(val))) {
          fromValues.add(val);
        }
      }
      if (fromValues.isNotEmpty) {
        return fromValues;
      }

      return [map];
    }

    return [];
  }

  static bool _isLikelyMealMap(Map<String, dynamic> map) {
    // If it's just an ingredient {name: Pork, amount: 400g}, it's NOT a meal
    final isIngredient = (map.containsKey('amount') ||
            map.containsKey('quantity') ||
            map.containsKey('unit') ||
            map.containsKey('measure')) &&
        !map.containsKey('ingredients') &&
        !map.containsKey('instructions') &&
        !map.containsKey('prepTime') &&
        !map.containsKey('cookTime') &&
        !map.containsKey('mealType');
    if (isIngredient) return false;

    final hasMealName = (map['title'] ??
            map['dish'] ??
            map['dish_name'] ??
            map['dishName'] ??
            map['meal_name'] ??
            map['mealName'] ??
            map['recipe'] ??
            map['recipe_name'] ??
            map['recipeName'] ??
            map['meal']) !=
        null;

    if (hasMealName) return true;

    final hasName = map['name'] != null;
    final hasFoodProps = map['ingredients'] != null ||
        map['instructions'] != null ||
        map['prepTime'] != null ||
        map['prep_time'] != null ||
        map['calories'] != null ||
        map['mealType'] != null ||
        map['meal_type'] != null ||
        map['cuisine'] != null;

    return (hasName && hasFoodProps) || (hasFoodProps && map['title'] != null);
  }

  static void _collectMealMapsRecursive(
      dynamic node, List<Map<String, dynamic>> out) {
    if (node is Map) {
      final map = Map<String, dynamic>.from(node);
      if (_isLikelyMealMap(map) && !out.any((m) => m == map)) {
        out.add(map);
      }
      for (final val in map.values) {
        _collectMealMapsRecursive(val, out);
      }
    } else if (node is List) {
      for (final item in node) {
        _collectMealMapsRecursive(item, out);
      }
    }
  }

  /// Builds several decode candidates: raw extract, repaired, truncated-closed.
  static List<String> _jsonCandidates(String text,
      {required bool preferArray}) {
    final extracted = _extractJsonBlock(text, preferArray: preferArray);
    final repaired = _repairCommonJsonIssues(extracted);
    final closed = _closeTruncatedJson(repaired);

    final out = <String>[];
    void add(String s) {
      final t = s.trim();
      if (t.isNotEmpty && !out.contains(t)) out.add(t);
    }

    add(extracted);
    add(repaired);
    add(closed);
    // Also try wrapping a bare array as {"meals": [...]} for object-mode APIs.
    if (repaired.trim().startsWith('[')) {
      add('{"meals":$repaired}');
      add('{"meals":${_closeTruncatedJson(repaired)}}');
    }
    return out;
  }

  /// Extracts the JSON substring by stripping markdown code fences and locating
  /// outermost brackets `[...]` or braces `{...}`.
  static String _extractJsonBlock(String text, {required bool preferArray}) {
    var content = text.trim();

    // Strip markdown fences
    content = content.replaceAll(
      RegExp(r'^```json\s*', multiLine: true, caseSensitive: false),
      '',
    );
    content = content.replaceAll(RegExp(r'^```\s*', multiLine: true), '');
    content = content.replaceAll(RegExp(r'```$', multiLine: true), '');
    content = content.trim();

    if (preferArray) {
      final firstBracket = content.indexOf('[');
      final lastBracket = content.lastIndexOf(']');
      if (firstBracket >= 0 && lastBracket > firstBracket) {
        return content.substring(firstBracket, lastBracket + 1);
      }
      // Truncated array with no closing bracket — keep from first `[`.
      if (firstBracket >= 0) {
        return content.substring(firstBracket);
      }
    }

    final firstBrace = content.indexOf('{');
    final lastBrace = content.lastIndexOf('}');
    if (firstBrace >= 0 && lastBrace > firstBrace) {
      return content.substring(firstBrace, lastBrace + 1);
    }
    if (firstBrace >= 0) {
      return content.substring(firstBrace);
    }

    return content;
  }

  /// Fixes trailing commas and similar model slip-ups that break jsonDecode.
  static String _repairCommonJsonIssues(String input) {
    var s = input;
    // Remove trailing commas before } or ]
    s = s.replaceAll(RegExp(r',\s*}'), '}');
    s = s.replaceAll(RegExp(r',\s*]'), ']');
    // Strip BOM / zero-width chars
    s = s.replaceAll(RegExp(r'[\uFEFF\u200B]'), '');
    return s;
  }

  /// Closes truncated JSON by balancing quotes/braces/brackets when possible.
  static String _closeTruncatedJson(String input) {
    var s = _repairCommonJsonIssues(input).trimRight();
    if (s.isEmpty) return s;

    // If we ended mid-string, close the quote.
    var inString = false;
    var escape = false;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (escape) {
        escape = false;
        continue;
      }
      if (c == r'\') {
        escape = true;
        continue;
      }
      if (c == '"') inString = !inString;
    }
    if (inString) s = '$s"';

    // Drop dangling incomplete key/value after last comma/colon if needed.
    s = s.replaceAll(RegExp(r',\s*$'), '');
    s = s.replaceAll(RegExp(r':\s*$'), ': null');

    final stack = <String>[];
    inString = false;
    escape = false;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (escape) {
        escape = false;
        continue;
      }
      if (c == r'\') {
        escape = true;
        continue;
      }
      if (c == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;
      if (c == '{') stack.add('}');
      if (c == '[') stack.add(']');
      if (c == '}' || c == ']') {
        if (stack.isNotEmpty && stack.last == c) stack.removeLast();
      }
    }

    // Close open structures in reverse order.
    while (stack.isNotEmpty) {
      // Avoid trailing comma before closer
      s = s.replaceAll(RegExp(r',\s*$'), '');
      s = '$s${stack.removeLast()}';
    }

    return s;
  }

  /// Pulls complete `{...}` objects that look like meals out of broken payloads.
  static List<Map<String, dynamic>> _salvageMealMaps(String rawText) {
    final content = _extractJsonBlock(rawText, preferArray: true);
    final maps = <Map<String, dynamic>>[];
    var depth = 0;
    var start = -1;
    var inString = false;
    var escape = false;

    for (var i = 0; i < content.length; i++) {
      final c = content[i];
      if (escape) {
        escape = false;
        continue;
      }
      if (c == r'\') {
        escape = true;
        continue;
      }
      if (c == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;

      if (c == '{') {
        if (depth == 0) start = i;
        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 0 && start >= 0) {
          final slice = content.substring(start, i + 1);
          try {
            final decoded = jsonDecode(_repairCommonJsonIssues(slice));
            if (decoded is Map) {
              final map = Map<String, dynamic>.from(decoded);
              if (_isLikelyMealMap(map)) {
                maps.add(map);
              }
            }
          } catch (_) {
            // ignore incomplete object
          }
          start = -1;
        }
      }
    }
    return maps;
  }
}

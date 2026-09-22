import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/llm_config.dart';
import '../../features/meal/models/meal.dart';

// ---------------------------------------------------------------------------
// Result wrapper
// ---------------------------------------------------------------------------

/// Wraps the result of an AI generation call with metadata about how the
/// request was fulfilled (custom key vs. built-in Gemini fallback, quota).
class AiResult<T> {
  AiResult({
    required this.data,
    this.usedFallback = false,
    this.quotaRemaining,
  });

  /// The generated data.
  final T data;

  /// `true` when the user had a custom key configured but it failed, and the
  /// app silently fell back to the built-in Gemini key.
  final bool usedFallback;

  /// How many built-in Gemini generations remain today.
  /// `null` when the request was fulfilled by a custom key.
  final int? quotaRemaining;
}

// ---------------------------------------------------------------------------
// Quota constants
// ---------------------------------------------------------------------------

/// Maximum number of built-in Gemini requests allowed per user per day.
const int kDailyQuotaLimit = 10;

// ---------------------------------------------------------------------------
// Key-validation result
// ---------------------------------------------------------------------------

class KeyValidationResult {
  const KeyValidationResult({required this.isValid, this.errorMessage});

  final bool isValid;

  /// Plain-language error message shown to the user on failure. `null` on success.
  final String? errorMessage;
}

// ---------------------------------------------------------------------------
// LlmService
// ---------------------------------------------------------------------------

/// AI-powered meal planning service.
///
/// Routing priority (per call):
///  1. User's custom key (OpenAI / Anthropic) — if configured and healthy
///  2. Built-in Firebase AI Logic (Gemini) — always available as fallback,
///     subject to [kDailyQuotaLimit] per user per day
class LlmService {
  LlmService();

  final _firestore = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Provider config — Firestore persistence
  // ---------------------------------------------------------------------------

  /// Read the user's stored [LlmConfig] from Firestore.
  /// Returns [LlmConfig.defaultConfig] if nothing is stored.
  Future<LlmConfig> getLlmConfig(String uid) async {
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('secrets')
        .doc('llmConfig')
        .get();
    if (!doc.exists) return LlmConfig.defaultConfig;
    return LlmConfig.fromMap(doc.data()!);
  }

  /// Save [config] to Firestore.
  Future<void> saveLlmConfig(String uid, LlmConfig config) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('secrets')
        .doc('llmConfig')
        .set(config.toMap());
  }

  /// Remove the custom key and revert to built-in Gemini.
  Future<void> clearLlmConfig(String uid) async {
    await saveLlmConfig(uid, LlmConfig.defaultConfig);
  }

  /// Stream of the user's active [LlmConfig]. Emits on every save.
  Stream<LlmConfig> activeConfigStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('secrets')
        .doc('llmConfig')
        .snapshots()
        .map((snap) =>
            snap.exists ? LlmConfig.fromMap(snap.data()!) : LlmConfig.defaultConfig);
  }

  // ---------------------------------------------------------------------------
  // Daily quota — built-in Gemini
  // ---------------------------------------------------------------------------

  DocumentReference<Map<String, dynamic>> _quotaRef(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('usageCounters')
      .doc('daily');

  /// Returns the current quota counter for today, creating it if needed.
  Future<({String date, int count})> _getOrCreateQuota(String uid) async {
    final today = _today();
    final snap = await _quotaRef(uid).get();
    if (!snap.exists || (snap.data()?['date'] as String?) != today) {
      return (date: today, count: 0);
    }
    return (date: today, count: (snap.data()!['count'] as int? ?? 0));
  }

  /// Checks whether the user is under their daily quota and atomically
  /// increments the counter if so.
  ///
  /// Returns `true` if the request is allowed (counter was incremented),
  /// `false` if the quota is exceeded.
  Future<bool> _tryIncrementQuota(String uid) async {
    final quota = await _getOrCreateQuota(uid);
    if (quota.count >= kDailyQuotaLimit) return false;

    await _quotaRef(uid).set({
      'date': quota.date,
      'count': quota.count + 1,
    });
    return true;
  }

  /// Remaining built-in Gemini requests for today (0–[kDailyQuotaLimit]).
  Future<int> getRemainingQuota(String uid) async {
    final quota = await _getOrCreateQuota(uid);
    return (kDailyQuotaLimit - quota.count).clamp(0, kDailyQuotaLimit);
  }

  // ---------------------------------------------------------------------------
  // Key validation (for "Test connection" step in settings)
  // ---------------------------------------------------------------------------

  /// Validates [apiKey] against [provider]'s API with the cheapest possible
  /// request. Returns a [KeyValidationResult] with a plain-language message.
  Future<KeyValidationResult> validateKey(
      LlmProvider provider, String apiKey) async {
    try {
      switch (provider) {
        case LlmProvider.gemini:
          // Built-in — never needs validation.
          return const KeyValidationResult(isValid: true);
        case LlmProvider.openai:
          return await _validateOpenAiKey(apiKey);
        case LlmProvider.anthropic:
          return await _validateAnthropicKey(apiKey);
      }
    } catch (e) {
      return KeyValidationResult(
        isValid: false,
        errorMessage:
            "Couldn't reach the server. Check your internet connection and try again.",
      );
    }
  }

  Future<KeyValidationResult> _validateOpenAiKey(String apiKey) async {
    final response = await http
        .get(
          Uri.parse('https://api.openai.com/v1/models'),
          headers: {'Authorization': 'Bearer $apiKey'},
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return const KeyValidationResult(isValid: true);
    } else if (response.statusCode == 401) {
      return const KeyValidationResult(
        isValid: false,
        errorMessage:
            "That key doesn't look right. Double-check it was copied in full and try again.",
      );
    } else {
      return KeyValidationResult(
        isValid: false,
        errorMessage:
            "OpenAI returned an unexpected error (${response.statusCode}). Try again in a moment.",
      );
    }
  }

  Future<KeyValidationResult> _validateAnthropicKey(String apiKey) async {
    // Cheapest Anthropic call: 1-token completion.
    final body = jsonEncode({
      'model': 'claude-haiku-20240307',
      'max_tokens': 1,
      'messages': [
        {'role': 'user', 'content': 'Hi'},
      ],
    });

    final response = await http
        .post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return const KeyValidationResult(isValid: true);
    } else if (response.statusCode == 401) {
      return const KeyValidationResult(
        isValid: false,
        errorMessage:
            "That key doesn't look right. Double-check it was copied in full and try again.",
      );
    } else {
      return KeyValidationResult(
        isValid: false,
        errorMessage:
            "Anthropic returned an unexpected error (${response.statusCode}). Try again in a moment.",
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Meal Plan Generation
  // ---------------------------------------------------------------------------

  /// Generate a multi-day meal plan.
  ///
  /// Automatically routes to the user's custom key (if configured and valid)
  /// or the built-in Gemini backend. Returns an [AiResult] carrying the meals
  /// plus metadata about how the request was fulfilled.
  Future<AiResult<List<Meal>>> generateMealPlan({
    required String uid,
    required List<String> familyMemberNames,
    required int numberOfDays,
    required List<String> mealTypes,
    required List<String> cuisinePreferences,
    required bool prioritizePantry,
    List<String> pantryItems = const [],
    List<String> restrictions = const [],
  }) async {
    final prompt = _buildMealPlanPrompt(
      familyMemberNames: familyMemberNames,
      numberOfDays: numberOfDays,
      mealTypes: mealTypes,
      cuisinePreferences: cuisinePreferences,
      prioritizePantry: prioritizePantry,
      pantryItems: pantryItems,
      restrictions: restrictions,
    );

    return _generate(uid: uid, prompt: prompt, parse: _parseMealsFromText);
  }

  /// Generate a single replacement meal.
  Future<AiResult<Meal>> replaceMeal({
    required String uid,
    required Meal currentMeal,
    List<String> cuisinePreferences = const [],
    List<String> restrictions = const [],
  }) async {
    final prompt = '''
You are a meal planning assistant. Replace the following meal with a different one.
Current meal: ${currentMeal.title} (${currentMeal.cuisine})
Cuisine preferences: ${cuisinePreferences.join(', ')}
Dietary restrictions: ${restrictions.join(', ')}

Return ONLY a JSON object with these fields:
{"title":"...","subtitle":"...","cuisine":"...","mealType":"${currentMeal.mealType}","prepTime":"...","cookTime":"...","servings":"...","calories":"...","protein":"...","carbs":"...","fats":"...","badgeText":"AI Suggested","ingredients":[{"name":"...","amount":"..."}]}
''';

    final result = await _generate(
      uid: uid,
      prompt: prompt,
      parse: (text) {
        final meals = _parseMealsFromText(text);
        if (meals.isEmpty) throw Exception('Failed to generate a replacement meal.');
        return meals.first;
      },
    );

    return result;
  }

  // ---------------------------------------------------------------------------
  // Core generation routing
  // ---------------------------------------------------------------------------

  Future<AiResult<T>> _generate<T>({
    required String uid,
    required String prompt,
    required T Function(String) parse,
  }) async {
    final config = await getLlmConfig(uid);

    // 1 — Try the user's custom key first.
    if (config.isCustom) {
      try {
        final text = await _generateWithCustomKey(config, prompt);
        return AiResult(data: parse(text));
      } catch (_) {
        // Custom key failed — fall through to built-in Gemini.
      }
    }

    // 2 — Built-in Gemini (with quota guard).
    final allowed = await _tryIncrementQuota(uid);
    if (!allowed) {
      throw QuotaExceededException();
    }

    final remaining = await getRemainingQuota(uid);
    final text = await _generateWithFirebaseAI(prompt);
    return AiResult(
      data: parse(text),
      usedFallback: config.isCustom, // fell back from a broken custom key
      quotaRemaining: remaining,
    );
  }

  // ---------------------------------------------------------------------------
  // Firebase AI Logic (built-in Gemini)
  // ---------------------------------------------------------------------------

  GenerativeModel _getGeminiModel() {
    final googleAI = FirebaseAI.googleAI(auth: FirebaseAuth.instance);
    return googleAI.generativeModel(model: 'gemini-flash-latest');
  }

  Future<String> _generateWithFirebaseAI(String prompt) async {
    final model = _getGeminiModel();
    final response = await model.generateContent([Content.text(prompt)]);
    final text = response.text;
    if (text == null || text.isEmpty) {
      throw Exception('Firebase AI returned an empty response.');
    }
    return text;
  }

  // ---------------------------------------------------------------------------
  // Custom key providers (OpenAI / Anthropic)
  // ---------------------------------------------------------------------------

  Future<String> _generateWithCustomKey(LlmConfig config, String prompt) async {
    switch (config.provider) {
      case LlmProvider.gemini:
        return _generateWithFirebaseAI(prompt);
      case LlmProvider.openai:
        return _generateWithOpenAI(config.apiKey!, prompt);
      case LlmProvider.anthropic:
        return _generateWithAnthropic(config.apiKey!, prompt);
    }
  }

  Future<String> _generateWithOpenAI(String apiKey, String prompt) async {
    final body = jsonEncode({
      'model': 'gpt-4o-mini',
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
    });

    final response = await http
        .post(
          Uri.parse('https://api.openai.com/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception('OpenAI error ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final text =
        (decoded['choices'] as List).first['message']['content'] as String?;
    if (text == null || text.isEmpty) throw Exception('OpenAI returned empty response.');
    return text;
  }

  Future<String> _generateWithAnthropic(String apiKey, String prompt) async {
    final body = jsonEncode({
      'model': 'claude-haiku-20240307',
      'max_tokens': 4096,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
    });

    final response = await http
        .post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception('Anthropic error ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final text =
        (decoded['content'] as List).first['text'] as String?;
    if (text == null || text.isEmpty) throw Exception('Anthropic returned empty response.');
    return text;
  }

  // ---------------------------------------------------------------------------
  // Prompt builder
  // ---------------------------------------------------------------------------

  String _buildMealPlanPrompt({
    required List<String> familyMemberNames,
    required int numberOfDays,
    required List<String> mealTypes,
    required List<String> cuisinePreferences,
    required bool prioritizePantry,
    required List<String> pantryItems,
    required List<String> restrictions,
  }) {
    return '''
You are a family meal planning assistant. Generate a $numberOfDays-day meal plan.

Family members: ${familyMemberNames.join(', ')}
Meal types per day: ${mealTypes.join(', ')}
Cuisine preferences: ${cuisinePreferences.join(', ')}
Dietary restrictions: ${restrictions.join(', ')}
${prioritizePantry && pantryItems.isNotEmpty ? 'Prioritize using these pantry items: ${pantryItems.join(', ')}' : ''}

Return ONLY a JSON array of meal objects. Each meal must have:
{"title":"...","subtitle":"...","cuisine":"...","mealType":"Breakfast|Lunch|Dinner","dayIndex":0,"prepTime":"10m","cookTime":"15m","servings":"4 Persons","calories":"450 kcal","protein":"42g","carbs":"8g","fats":"18g","badgeText":"...","ingredients":[{"name":"...","amount":"..."}]}

Generate ${numberOfDays * mealTypes.length} meals total (${mealTypes.length} per day, for $numberOfDays days).
Set dayIndex from 0 to ${numberOfDays - 1}.
''';
  }

  // ---------------------------------------------------------------------------
  // Response parser
  // ---------------------------------------------------------------------------

  List<Meal> _parseMealsFromText(String text) {
    try {
      // Strip markdown code fences if present
      String content = text
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final arrayStart = content.indexOf('[');
      final arrayEnd = content.lastIndexOf(']');
      if (arrayStart >= 0 && arrayEnd > arrayStart) {
        content = content.substring(arrayStart, arrayEnd + 1);
      }

      final dynamic decoded = jsonDecode(content);
      final List<dynamic> mealsJson = decoded is List ? decoded : [decoded];

      return mealsJson.map((json) {
        final map = Map<String, dynamic>.from(json as Map);
        return Meal(
          id: '',
          title: map['title'] ?? '',
          subtitle: map['subtitle'],
          cuisine: map['cuisine'],
          mealType: map['mealType'],
          dayIndex: map['dayIndex'] ?? 0,
          prepTime: map['prepTime'],
          cookTime: map['cookTime'],
          servings: map['servings'],
          calories: map['calories'],
          protein: map['protein'],
          carbs: map['carbs'],
          fats: map['fats'],
          badgeText: map['badgeText'],
          ingredients: (map['ingredients'] as List<dynamic>?)
                  ?.map(
                    (e) => Ingredient.fromMap(
                      Map<String, dynamic>.from(e as Map),
                    ),
                  )
                  .toList() ??
              [],
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to parse AI response: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// Exceptions
// ---------------------------------------------------------------------------

/// Thrown when a user's daily built-in Gemini quota is exhausted.
class QuotaExceededException implements Exception {
  @override
  String toString() => 'QuotaExceededException';
}



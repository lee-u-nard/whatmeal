import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../models/llm_config.dart';
import '../ai_provider_adapter.dart';
import '../ai_models.dart';
import '../ai_logger.dart';
import '../ai_json_parser.dart';
import 'http_response_support.dart';
import '../model_registry.dart';

/// Groq provider adapter using Groq's OpenAI-compatible API.
///
/// Base URL: https://api.groq.com/openai/v1
/// Completions endpoint: https://api.groq.com/openai/v1/chat/completions
class GroqAdapter implements AiProviderAdapter {
  GroqAdapter({
    required this.apiKey,
    String? model,
    http.Client? client,
  })  : model =
            (model != null && model.isNotEmpty) ? model : 'openai/gpt-oss-20b',
        _transport = AiHttpTransport('Groq', client: client);

  final String apiKey;
  @override
  final String model;
  final AiHttpTransport _transport;

  @override
  LlmProvider get provider => LlmProvider.groq;

  static const String baseUrl = 'https://api.groq.com/openai/v1';
  static const String completionsEndpoint = '$baseUrl/chat/completions';
  static const String modelsEndpoint = '$baseUrl/models';

  @override
  Future<TestConnectionResult> testConnection() async {
    if (apiKey.trim().isEmpty) {
      return TestConnectionResult.failure(
        status: TestConnectionStatus.invalidKey,
        message: 'Groq API key is missing. Please enter your key.',
      );
    }
    // Model listing only proves catalog access. Test the selected completion
    // directly, and require usable output rather than a bare HTTP 200.
    try {
      final response = await _transport.post(
        Uri.parse(completionsEndpoint),
        headers: _headers,
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'user', 'content': 'Reply with OK.'}
          ],
          'max_completion_tokens': 1024,
        }),
        timeout: const Duration(seconds: 15),
      );
      if (response.statusCode != 200) {
        return providerHttpFailure(response, 'Groq').toConnectionResult();
      }
      completedChatText(response.body, 'Groq');
      return TestConnectionResult.success();
    } on AiHttpFailure catch (error) {
      return error.toConnectionResult();
    } catch (error) {
      AiLogger.logError(provider: 'Groq', model: model, error: error);
      return TestConnectionResult.failure(
        status: TestConnectionStatus.providerUnavailable,
        message: 'Groq returned an invalid response. Please retry.',
      );
    }
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${apiKey.trim()}',
        'Content-Type': 'application/json',
      };

  @override
  Future<AiMealPlanResponse> generateMealPlan(AiMealPlanRequest request) async {
    final expected = request.numberOfDays * request.mealTypes.length;

    // Large plans often break Groq JSON mode (truncation / validation).
    // Generate one day at a time and merge.
    if (request.numberOfDays > 1 && expected > 6) {
      final allMeals = <AiMealResponse>[];
      for (var day = 0; day < request.numberOfDays; day++) {
        final prompt = request.buildCompactPrompt(onlyDayIndex: day);
        final rawText = await _callCompletions(prompt, forceJsonObject: true);
        final dayMeals = AiJsonParser.parseMealList(rawText);
        for (final meal in dayMeals) {
          allMeals.add(AiMealResponse(
            title: meal.title,
            subtitle: meal.subtitle,
            cuisine: meal.cuisine,
            mealType: meal.mealType,
            dayIndex: day,
            prepTime: meal.prepTime,
            cookTime: meal.cookTime,
            servings: meal.servings,
            calories: meal.calories,
            protein: meal.protein,
            carbs: meal.carbs,
            fats: meal.fats,
            badgeText: meal.badgeText,
            ingredients: meal.ingredients,
            instructions: meal.instructions,
            availableIngredients: meal.availableIngredients,
            missingIngredients: meal.missingIngredients,
            tags: meal.tags,
            reasoning: meal.reasoning,
            imageSearchQuery: meal.imageSearchQuery,
            youtubeSearchQuery: meal.youtubeSearchQuery,
          ));
        }
      }
      // Do not silently restart an expensive plan after an auth, quota,
      // transport, truncation, or recipe failure on a later day.
      request.validateMeals(allMeals);
      return AiMealPlanResponse(
          meals: allMeals, provider: provider, model: model);
    }

    final prompt = request.buildCompactPrompt();
    final rawText = await _callCompletions(prompt, forceJsonObject: true);
    final meals = AiJsonParser.parseMealList(rawText);
    return AiMealPlanResponse(meals: meals, provider: provider, model: model);
  }

  @override
  Future<AiMealResponse> generateMealReplacement(
      AiMealReplacementRequest request) async {
    final prompt = '''
${request.buildPrompt()}

Return ONLY a JSON object (include the word JSON). Keep strings short.
''';
    final rawText = await _callCompletions(prompt, forceJsonObject: true);
    return AiJsonParser.parseSingleMeal(rawText);
  }

  /// Only an explicit JSON-mode validation error is retried once. Provider
  /// failed_generation data is not accepted as a successful complete response.
  Future<String> _callCompletions(
    String prompt, {
    required bool forceJsonObject,
  }) async {
    try {
      return await _postCompletion(prompt, useJsonObject: forceJsonObject);
    } on _GroqJsonValidationException {
      try {
        return await _postCompletion(prompt, useJsonObject: false);
      } on _GroqJsonValidationException {
        throw const AiHttpFailure(
            'Groq could not produce valid JSON. Try fewer meals or another model.');
      }
    }
  }

  Future<String> _postCompletion(
    String prompt, {
    required bool useJsonObject,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw const AiHttpFailure(
          'Groq API key is missing.', TestConnectionStatus.invalidKey);
    }
    final startTime = DateTime.now();
    AiLogger.logRequest(
        provider: 'Groq', endpoint: completionsEndpoint, model: model);

    final body = <String, dynamic>{
      'model': model,
      'messages': [
        {
          'role': 'system',
          'content': 'You are WhatMeal\'s meal planner. '
              'Reply with valid JSON only (the word JSON must appear). '
              'Shape: {"meals":[...]} for plans, or one meal object for replacements. '
              'No markdown. No trailing commas. Short strings. Complete the full JSON.',
        },
        {'role': 'user', 'content': prompt},
      ],
      'temperature': 0.2,
      'max_completion_tokens': 6000,
    };
    if (useJsonObject) {
      body['response_format'] = {'type': 'json_object'};
    }

    final response = await _transport.post(
      Uri.parse(completionsEndpoint),
      headers: _headers,
      body: jsonEncode(body),
      timeout: const Duration(seconds: 90),
    );

    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    AiLogger.logResponse(
      provider: 'Groq',
      model: model,
      statusCode: response.statusCode,
      elapsedMs: elapsed,
    );

    if (response.statusCode == 200) {
      return completedChatText(response.body, 'Groq');
    }
    if (response.statusCode == 400 && _isJsonValidation(response.body)) {
      throw const _GroqJsonValidationException();
    }
    throw providerHttpFailure(response, 'Groq');
  }

  bool _isJsonValidation(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map || decoded['error'] is! Map) return false;
      final error = decoded['error'] as Map;
      return error['code'] == 'json_validate_failed';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> fetchAvailableModels() async {
    try {
      final cleanKey = apiKey.trim();
      if (cleanKey.isEmpty) return [];
      final response = await _transport.get(
        Uri.parse(modelsEndpoint),
        headers: {
          'Authorization': 'Bearer $cleanKey',
          'Content-Type': 'application/json',
        },
        timeout: const Duration(seconds: 15),
      );

      if (response.statusCode != 200) {
        throw providerHttpFailure(response, 'Groq');
      }
      final decoded = decodeProviderObject(response.body, 'Groq');
      final data = decoded['data'] as List<dynamic>? ?? [];

      final validModels = <String>[];
      for (final item in data) {
        if (item is Map && item['id'] is String) {
          final id = item['id'] as String;
          validModels.add(id);
        }
      }

      return AiModelRegistry.filterDiscovered(provider, validModels);
    } on AiHttpFailure {
      rethrow;
    } catch (_) {
      throw const AiHttpFailure('Groq returned an invalid model catalogue.');
    }
  }
}

class _GroqJsonValidationException implements Exception {
  const _GroqJsonValidationException();
}

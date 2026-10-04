import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../models/llm_config.dart';
import '../ai_provider_adapter.dart';
import '../ai_models.dart';
import '../ai_logger.dart';
import '../ai_json_parser.dart';

/// Groq provider adapter using Groq's OpenAI-compatible API.
///
/// Base URL: https://api.groq.com/openai/v1
/// Completions endpoint: https://api.groq.com/openai/v1/chat/completions
class GroqAdapter implements AiProviderAdapter {
  GroqAdapter({
    required this.apiKey,
    String? model,
  }) : model =
            (model != null && model.isNotEmpty) ? model : 'openai/gpt-oss-20b';

  final String apiKey;
  @override
  final String model;

  @override
  LlmProvider get provider => LlmProvider.groq;

  static const String baseUrl = 'https://api.groq.com/openai/v1';
  static const String completionsEndpoint = '$baseUrl/chat/completions';
  static const String modelsEndpoint = '$baseUrl/models';

  @override
  Future<TestConnectionResult> testConnection() async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      return TestConnectionResult.failure(
        status: TestConnectionStatus.invalidKey,
        message:
            'Groq API key is missing. Please enter your key from console.groq.com.',
      );
    }

    final startTime = DateTime.now();
    AiLogger.logRequest(
        provider: 'Groq', endpoint: modelsEndpoint, model: model);

    try {
      final modelsResponse = await http.get(
        Uri.parse(modelsEndpoint),
        headers: {
          'Authorization': 'Bearer $cleanKey',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      final modelsElapsed = DateTime.now().difference(startTime).inMilliseconds;
      AiLogger.logResponse(
        provider: 'Groq (models)',
        model: model,
        statusCode: modelsResponse.statusCode,
        elapsedMs: modelsElapsed,
      );

      if (modelsResponse.statusCode == 401) {
        return TestConnectionResult.failure(
          status: TestConnectionStatus.invalidKey,
          message:
              'Invalid Groq API key. Check that you copied the complete key starting with "gsk_".',
        );
      } else if (modelsResponse.statusCode == 429) {
        return TestConnectionResult.failure(
          status: TestConnectionStatus.rateLimited,
          message: 'Groq rate limit exceeded. Please wait a moment.',
        );
      } else if (modelsResponse.statusCode != 200) {
        return TestConnectionResult.failure(
          status: TestConnectionStatus.providerUnavailable,
          message: 'Groq API returned HTTP ${modelsResponse.statusCode}.',
        );
      }

      final completionStartTime = DateTime.now();
      AiLogger.logRequest(
          provider: 'Groq', endpoint: completionsEndpoint, model: model);

      final completionResponse = await http
          .post(
            Uri.parse(completionsEndpoint),
            headers: {
              'Authorization': 'Bearer $cleanKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {'role': 'user', 'content': 'Hi'}
              ],
              'max_tokens': 1,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final completionElapsed =
          DateTime.now().difference(completionStartTime).inMilliseconds;
      AiLogger.logResponse(
        provider: 'Groq (test completion)',
        model: model,
        statusCode: completionResponse.statusCode,
        elapsedMs: completionElapsed,
      );

      if (completionResponse.statusCode == 200) {
        return TestConnectionResult.success();
      }

      String compError = '';
      try {
        final errJson = jsonDecode(completionResponse.body);
        if (errJson is Map &&
            errJson['error'] is Map &&
            errJson['error']['message'] != null) {
          compError = errJson['error']['message'].toString();
        }
      } catch (_) {}

      if (completionResponse.statusCode == 404) {
        return TestConnectionResult.failure(
          status: TestConnectionStatus.invalidModel,
          message: compError.isNotEmpty
              ? compError
              : 'Model "$model" is not available on your Groq tier. Try "openai/gpt-oss-20b".',
        );
      } else if (completionResponse.statusCode == 400) {
        return TestConnectionResult.failure(
          status: TestConnectionStatus.invalidModel,
          message: compError.isNotEmpty
              ? compError
              : 'Groq rejected model "$model". Pick a supported model ID.',
        );
      } else if (completionResponse.statusCode == 429) {
        return TestConnectionResult.failure(
          status: TestConnectionStatus.rateLimited,
          message: compError.isNotEmpty
              ? compError
              : 'Groq rate limit reached for model "$model". The key is valid.',
        );
      } else {
        return TestConnectionResult.failure(
          status: TestConnectionStatus.providerUnavailable,
          message: compError.isNotEmpty
              ? compError
              : 'Groq returned HTTP ${completionResponse.statusCode} for model "$model".',
        );
      }
    } catch (e) {
      AiLogger.logError(provider: 'Groq', model: model, error: e);
      return TestConnectionResult.failure(
        status: TestConnectionStatus.networkError,
        message:
            'Could not connect to Groq API. Check your internet connection.',
      );
    }
  }

  @override
  Future<AiMealPlanResponse> generateMealPlan(AiMealPlanRequest request) async {
    final expected = request.numberOfDays * request.mealTypes.length;

    // Large plans often break Groq JSON mode (truncation / validation).
    // Generate one day at a time and merge.
    if (request.numberOfDays > 1 && expected > 6) {
      try {
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
        if (allMeals.isNotEmpty) {
          return AiMealPlanResponse(
              meals: allMeals, provider: provider, model: model);
        }
      } catch (e) {
        AiLogger.logError(
          provider: 'Groq',
          model: model,
          error:
              'Day-by-day generation encountered an issue ($e). Trying single compact prompt.',
        );
      }
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

  /// Calls Groq chat completions. On JSON validation failure, tries to salvage
  /// `failed_generation`, then retries once without strict JSON mode.
  Future<String> _callCompletions(
    String prompt, {
    required bool forceJsonObject,
  }) async {
    try {
      return await _postCompletion(
        prompt,
        useJsonObject: forceJsonObject,
      );
    } on _GroqJsonValidationException catch (e) {
      // 1) Salvage whatever Groq already generated.
      if (e.failedGeneration != null && e.failedGeneration!.trim().isNotEmpty) {
        try {
          final salvaged = AiJsonParser.parseMealList(e.failedGeneration!);
          if (salvaged.isNotEmpty) {
            AiLogger.logError(
              provider: 'Groq',
              model: model,
              error:
                  'JSON validation failed; salvaged ${salvaged.length} meals from failed_generation.',
            );
            return e.failedGeneration!;
          }
        } catch (_) {
          try {
            AiJsonParser.parseSingleMeal(e.failedGeneration!);
            return e.failedGeneration!;
          } catch (_) {}
        }
      }

      // 2) Retry without response_format (best-effort free-form JSON).
      AiLogger.logError(
        provider: 'Groq',
        model: model,
        error: 'Retrying without json_object mode after validation failure.',
      );
      return _postCompletion(prompt, useJsonObject: false);
    }
  }

  Future<String> _postCompletion(
    String prompt, {
    required bool useJsonObject,
  }) async {
    final cleanKey = apiKey.trim();
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
      'max_tokens': 6000,
    };
    if (useJsonObject) {
      body['response_format'] = {'type': 'json_object'};
    }

    final response = await http
        .post(
          Uri.parse(completionsEndpoint),
          headers: {
            'Authorization': 'Bearer $cleanKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 90));

    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    AiLogger.logResponse(
      provider: 'Groq',
      model: model,
      statusCode: response.statusCode,
      elapsedMs: elapsed,
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final choice = (decoded['choices'] as List?)?.firstOrNull;
      final text = choice?['message']?['content'] as String?;
      final finishReason = choice?['finish_reason'] as String?;
      if (text == null || text.trim().isEmpty) {
        throw Exception('Groq returned an empty response.');
      }
      if (finishReason == 'length') {
        AiLogger.logError(
          provider: 'Groq',
          model: model,
          error:
              'Response truncated (finish_reason=length). Parser will salvage.',
        );
      }
      return text;
    }

    String errorMessage = '';
    String? failedGeneration;
    try {
      final errJson = jsonDecode(response.body);
      if (errJson is Map) {
        final errObj = errJson['error'];
        if (errObj is Map) {
          if (errObj['message'] != null) {
            errorMessage = errObj['message'].toString();
          }
          final fg = errObj['failed_generation'];
          if (fg != null) failedGeneration = fg.toString();
        } else if (errJson['message'] != null) {
          errorMessage = errJson['message'].toString();
        }
      }
    } catch (_) {}

    final isJsonValidation = response.statusCode == 400 &&
        (errorMessage.toLowerCase().contains('validate json') ||
            errorMessage.toLowerCase().contains('failed_generation') ||
            failedGeneration != null);

    if (isJsonValidation) {
      throw _GroqJsonValidationException(
        errorMessage.isNotEmpty ? errorMessage : 'Failed to validate JSON',
        failedGeneration: failedGeneration,
      );
    }

    if (response.statusCode == 401) {
      throw Exception(errorMessage.isNotEmpty
          ? errorMessage
          : 'Invalid Groq API key. Check your key in AI Settings.');
    } else if (response.statusCode == 404) {
      throw Exception(errorMessage.isNotEmpty
          ? errorMessage
          : 'Groq model "$model" not found (HTTP 404). Check AI Settings.');
    } else if (response.statusCode == 429) {
      throw Exception(errorMessage.isNotEmpty
          ? errorMessage
          : 'Groq rate limit exceeded. Please wait and try again.');
    } else if (response.statusCode == 500 || response.statusCode == 503) {
      throw Exception(errorMessage.isNotEmpty
          ? errorMessage
          : 'Groq service is temporarily unavailable.');
    } else {
      throw Exception(errorMessage.isNotEmpty
          ? 'Groq error: $errorMessage'
          : 'Groq error (HTTP ${response.statusCode}).');
    }
  }

  @override
  Future<List<String>> fetchAvailableModels() async {
    try {
      final cleanKey = apiKey.trim();
      final response = await http.get(
        Uri.parse(modelsEndpoint),
        headers: {
          'Authorization': 'Bearer $cleanKey',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return [];
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as List<dynamic>? ?? [];

      final validModels = <String>[];
      for (final item in data) {
        if (item is Map && item['id'] is String) {
          final id = item['id'] as String;
          if (_isChatModel(id)) {
            validModels.add(id);
          }
        }
      }

      validModels.sort((a, b) {
        final aScore = _modelPriority(a);
        final bScore = _modelPriority(b);
        if (aScore != bScore) return bScore.compareTo(aScore);
        return a.compareTo(b);
      });

      return validModels;
    } catch (_) {
      return [];
    }
  }

  static bool _isChatModel(String id) {
    final lower = id.toLowerCase();
    const excludeTerms = [
      'whisper',
      'tts',
      'audio',
      'vision-preview',
      'embedding',
      'guard'
    ];
    for (final term in excludeTerms) {
      if (lower.contains(term)) return false;
    }
    return true;
  }

  static int _modelPriority(String id) {
    final lower = id.toLowerCase();
    if (lower.contains('gpt-oss-20b')) return 10;
    if (lower.contains('gpt-oss-120b')) return 9;
    if (lower.contains('llama-3.3-70b-versatile')) return 8;
    if (lower.contains('qwen3.8-27b') || lower.contains('qwen-2.5')) return 7;
    if (lower.contains('minimax-m2.7')) return 6;
    if (lower.contains('llama-3.1-8b-instant')) return 5;
    if (lower.contains('deepseek')) return 4;
    return 1;
  }
}

class _GroqJsonValidationException implements Exception {
  _GroqJsonValidationException(this.message, {this.failedGeneration});

  final String message;
  final String? failedGeneration;

  @override
  String toString() => message;
}

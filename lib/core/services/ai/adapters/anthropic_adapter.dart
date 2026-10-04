import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../models/llm_config.dart';
import '../ai_provider_adapter.dart';
import '../ai_models.dart';
import '../ai_logger.dart';
import '../ai_json_parser.dart';

/// Anthropic (Claude) provider adapter.
class AnthropicAdapter implements AiProviderAdapter {
  AnthropicAdapter({
    required this.apiKey,
    String? model,
  }) : model = model ?? 'claude-haiku-4-5';

  final String apiKey;
  @override
  final String model;

  @override
  LlmProvider get provider => LlmProvider.anthropic;

  static const String _endpoint = 'https://api.anthropic.com/v1/messages';

  @override
  Future<TestConnectionResult> testConnection() async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      return TestConnectionResult.failure(
        status: TestConnectionStatus.invalidKey,
        message: 'Anthropic Claude API key is missing. Please enter your key.',
      );
    }

    final startTime = DateTime.now();
    AiLogger.logRequest(provider: 'Claude', endpoint: _endpoint, model: model);

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'x-api-key': cleanKey,
              'anthropic-version': '2023-06-01',
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'max_tokens': 1,
              'messages': [
                {'role': 'user', 'content': 'Hi'}
              ],
            }),
          )
          .timeout(const Duration(seconds: 15));

      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      AiLogger.logResponse(
        provider: 'Claude',
        model: model,
        statusCode: response.statusCode,
        elapsedMs: elapsed,
      );

      if (response.statusCode == 200) {
        return TestConnectionResult.success();
      } else if (response.statusCode == 401) {
        return TestConnectionResult.failure(
          status: TestConnectionStatus.invalidKey,
          message:
              'Invalid Claude API key. Check that it was copied correctly from console.anthropic.com.',
        );
      } else if (response.statusCode == 404 || response.statusCode == 400) {
        final bodyStr = response.body.toLowerCase();
        if (bodyStr.contains('model') || response.statusCode == 404) {
          return TestConnectionResult.failure(
            status: TestConnectionStatus.invalidModel,
            message:
                'Model "$model" is not recognized or not accessible by this Anthropic key.',
          );
        }
        return TestConnectionResult.failure(
          status: TestConnectionStatus.invalidKey,
          message:
              'Anthropic rejected the request (${response.statusCode}). Check your key.',
        );
      } else if (response.statusCode == 429) {
        return TestConnectionResult.failure(
          status: TestConnectionStatus.rateLimited,
          message:
              'Claude rate limit or credit balance exceeded. Check your Anthropic console.',
        );
      } else if (response.statusCode == 529) {
        return TestConnectionResult.failure(
          status: TestConnectionStatus.providerUnavailable,
          message:
              'Anthropic servers are currently overloaded. Try again in a few moments.',
        );
      } else {
        return TestConnectionResult.failure(
          status: TestConnectionStatus.providerUnavailable,
          message: 'Anthropic returned HTTP ${response.statusCode}.',
        );
      }
    } catch (e) {
      AiLogger.logError(provider: 'Claude', model: model, error: e);
      return TestConnectionResult.failure(
        status: TestConnectionStatus.networkError,
        message:
            'Could not connect to Anthropic. Check your internet connection.',
      );
    }
  }

  @override
  Future<AiMealPlanResponse> generateMealPlan(AiMealPlanRequest request) async {
    final prompt = request.buildPrompt();
    final rawText = await _callMessages(prompt);
    final meals = AiJsonParser.parseMealList(rawText);
    return AiMealPlanResponse(meals: meals, provider: provider, model: model);
  }

  @override
  Future<AiMealResponse> generateMealReplacement(
      AiMealReplacementRequest request) async {
    final prompt = request.buildPrompt();
    final rawText = await _callMessages(prompt);
    return AiJsonParser.parseSingleMeal(rawText);
  }

  Future<String> _callMessages(String prompt) async {
    final cleanKey = apiKey.trim();
    final startTime = DateTime.now();
    AiLogger.logRequest(provider: 'Claude', endpoint: _endpoint, model: model);

    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'x-api-key': cleanKey,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'max_tokens': 4096,
            'system':
                'You are WhatMeal\'s specialized chef assistant. Always return valid, unescaped raw JSON strictly conforming to the requested schema. Never output markdown fences or explanatory text.',
            'messages': [
              {'role': 'user', 'content': prompt}
            ],
          }),
        )
        .timeout(const Duration(seconds: 90));

    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    AiLogger.logResponse(
      provider: 'Claude',
      model: model,
      statusCode: response.statusCode,
      elapsedMs: elapsed,
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final content = decoded['content'] as List?;
      final text = content?.firstOrNull?['text'] as String?;
      if (text == null || text.trim().isEmpty) {
        throw Exception('Anthropic Claude returned an empty response.');
      }
      return text;
    } else if (response.statusCode == 401) {
      throw Exception(
          'Invalid Claude API key. Please check your key in AI Settings.');
    } else if (response.statusCode == 404 || response.statusCode == 400) {
      throw Exception(
          'Claude model "$model" is not accessible or does not exist (HTTP ${response.statusCode}).');
    } else if (response.statusCode == 429) {
      throw Exception(
          'Claude rate limit or credit balance exceeded. Please check your Anthropic account.');
    } else if (response.statusCode == 529) {
      throw Exception(
          'Claude is currently overloaded. Please wait a moment and try again.');
    } else {
      throw Exception('Claude error (HTTP ${response.statusCode}).');
    }
  }

  @override
  Future<List<String>> fetchAvailableModels() async {
    return [
      'claude-haiku-4-5',
      'claude-sonnet-4-5',
      'claude-opus-4-5',
      'claude-3-5-haiku-20241022',
      'claude-3-5-sonnet-20241022',
    ];
  }
}

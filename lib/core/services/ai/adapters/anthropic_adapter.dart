import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../models/llm_config.dart';
import '../ai_provider_adapter.dart';
import '../ai_models.dart';
import '../ai_logger.dart';
import '../ai_json_parser.dart';
import 'http_response_support.dart';
import '../model_registry.dart';

/// Anthropic (Claude) provider adapter.
class AnthropicAdapter implements AiProviderAdapter {
  AnthropicAdapter({
    required this.apiKey,
    String? model,
    http.Client? client,
  })  : model = model ?? 'claude-haiku-4-5',
        _transport = AiHttpTransport('Claude', client: client);

  final String apiKey;
  @override
  final String model;
  final AiHttpTransport _transport;

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
      final response = await _transport.post(
        Uri.parse(_endpoint),
        headers: {
          'x-api-key': cleanKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'max_tokens': 32,
          'messages': [
            {'role': 'user', 'content': 'Reply with OK.'}
          ],
        }),
        timeout: const Duration(seconds: 15),
      );

      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      AiLogger.logResponse(
        provider: 'Claude',
        model: model,
        statusCode: response.statusCode,
        elapsedMs: elapsed,
      );

      if (response.statusCode == 200) {
        _completedText(response.body);
        return TestConnectionResult.success();
      }
      return providerHttpFailure(response, 'Claude').toConnectionResult();
    } on AiHttpFailure catch (error) {
      return error.toConnectionResult();
    } catch (e) {
      AiLogger.logError(provider: 'Claude', model: model, error: e);
      return TestConnectionResult.failure(
        status: TestConnectionStatus.networkError,
        message:
            'Could not connect to Anthropic. Check your internet connection.',
      );
    }
  }

  String _completedText(String body) {
    final decoded = decodeProviderObject(body, 'Claude');
    if (decoded['stop_reason'] == 'max_tokens') {
      throw const AiHttpFailure(
          'Claude response was cut short. Try fewer meals or another model.');
    }
    if (decoded['stop_reason'] == 'refusal') {
      throw const AiHttpFailure(
          'Claude declined this request. Review the request and try again.');
    }
    if (decoded['stop_reason'] != 'end_turn') {
      throw const AiHttpFailure(
          'Claude did not finish a text response. Please retry.');
    }
    final content = decoded['content'];
    if (content is! List) {
      throw const AiHttpFailure(
          'Claude returned an invalid response. Please retry.');
    }
    final text = StringBuffer();
    for (final block in content) {
      if (block is! Map) {
        throw const AiHttpFailure(
            'Claude returned an invalid response. Please retry.');
      }
      if (block['type'] == 'text') {
        if (block['text'] is! String) {
          throw const AiHttpFailure(
              'Claude returned an invalid response. Please retry.');
        }
        text.write(block['text']);
      }
    }
    if (text.toString().trim().isEmpty) {
      throw const AiHttpFailure(
          'Claude returned an empty response. Please retry.');
    }
    return text.toString();
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
    if (cleanKey.isEmpty) {
      throw const AiHttpFailure(
          'Claude API key is missing.', TestConnectionStatus.invalidKey);
    }
    final startTime = DateTime.now();
    AiLogger.logRequest(provider: 'Claude', endpoint: _endpoint, model: model);

    final response = await _transport.post(
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
      timeout: const Duration(seconds: 90),
    );

    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    AiLogger.logResponse(
      provider: 'Claude',
      model: model,
      statusCode: response.statusCode,
      elapsedMs: elapsed,
    );

    if (response.statusCode == 200) {
      return _completedText(response.body);
    }
    throw providerHttpFailure(response, 'Claude');
  }

  @override
  Future<List<String>> fetchAvailableModels() async {
    final ids = <String>[];
    String? after;
    for (var page = 0; page < 10; page++) {
      final response = await _transport.get(
        Uri.https('api.anthropic.com', '/v1/models', {
          'limit': '1000',
          if (after != null) 'after_id': after,
        }),
        headers: {
          'x-api-key': apiKey.trim(),
          'anthropic-version': '2023-06-01'
        },
        timeout: const Duration(seconds: 15),
      );
      if (response.statusCode != 200) {
        throw providerHttpFailure(response, 'Claude');
      }
      final data = decodeProviderObject(response.body, 'Claude');
      for (final item in (data['data'] as List? ?? []).whereType<Map>()) {
        if (item['id'] is String) ids.add(item['id'] as String);
      }
      final next = data['last_id'];
      if (data['has_more'] != true || next is! String || next == after) break;
      after = next;
    }
    // Anthropic lists dated snapshots, while the UI stores documented aliases.
    const aliases = {
      'claude-haiku-4-5-20251001': 'claude-haiku-4-5',
      'claude-sonnet-4-5-20250929': 'claude-sonnet-4-5',
      'claude-opus-4-5-20251101': 'claude-opus-4-5',
    };
    return AiModelRegistry.filterDiscovered(
        provider, ids.map((id) => aliases[id] ?? id));
  }
}

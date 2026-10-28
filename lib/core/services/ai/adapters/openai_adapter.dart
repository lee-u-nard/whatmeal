import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../models/llm_config.dart';
import '../ai_provider_adapter.dart';
import '../ai_models.dart';
import '../ai_logger.dart';
import '../ai_json_parser.dart';
import 'http_response_support.dart';
import '../model_registry.dart';

/// OpenAI / ChatGPT provider adapter.
class OpenAiAdapter implements AiProviderAdapter {
  OpenAiAdapter({
    required this.apiKey,
    String? model,
    this.customEndpoint,
    http.Client? client,
  })  : model = model ?? 'gpt-4.1-mini',
        _transport = AiHttpTransport('OpenAI', client: client);

  final String apiKey;
  @override
  final String model;
  final String? customEndpoint;
  final AiHttpTransport _transport;

  @override
  LlmProvider get provider => LlmProvider.openai;

  String get _completionsEndpoint =>
      customEndpoint ?? 'https://api.openai.com/v1/chat/completions';

  String get _modelsEndpoint {
    if (customEndpoint != null) {
      final uri = Uri.parse(customEndpoint!);
      final segs = uri.pathSegments
          .where((s) => s != 'chat' && s != 'completions')
          .toList();
      segs.add('models');
      return uri.replace(pathSegments: segs).toString();
    }
    return 'https://api.openai.com/v1/models';
  }

  @override
  Future<TestConnectionResult> testConnection() async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      return TestConnectionResult.failure(
        status: TestConnectionStatus.invalidKey,
        message: 'OpenAI API key is missing. Please enter your key.',
      );
    }

    final startTime = DateTime.now();
    AiLogger.logRequest(
        provider: 'OpenAI', endpoint: _completionsEndpoint, model: model);

    try {
      final response = await _transport.post(
        Uri.parse(_completionsEndpoint),
        headers: {
          'Authorization': 'Bearer $cleanKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'user', 'content': 'Reply with OK.'}
          ],
          'max_completion_tokens': 1024,
          if (_supportsNoReasoning) 'reasoning_effort': 'none',
        }),
        timeout: const Duration(seconds: 15),
      );

      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      AiLogger.logResponse(
        provider: 'OpenAI',
        model: model,
        statusCode: response.statusCode,
        elapsedMs: elapsed,
      );

      if (response.statusCode == 200) {
        completedChatText(response.body, 'OpenAI');
        return TestConnectionResult.success();
      }
      return providerHttpFailure(response, 'OpenAI').toConnectionResult();
    } on AiHttpFailure catch (error) {
      return error.toConnectionResult();
    } catch (e) {
      AiLogger.logError(provider: 'OpenAI', model: model, error: e);
      return TestConnectionResult.failure(
        status: TestConnectionStatus.networkError,
        message: 'Could not connect to OpenAI. Check your network connection.',
      );
    }
  }

  // These model families explicitly support disabling reasoning. Earlier
  // reasoning models must not receive an unsupported "none" effort value.
  bool get _supportsNoReasoning =>
      model.startsWith('gpt-6') || model.startsWith('gpt-5.6');

  @override
  Future<AiMealPlanResponse> generateMealPlan(AiMealPlanRequest request) async {
    final prompt = request.buildPrompt();
    final rawText = await _callCompletions(prompt);
    final meals = AiJsonParser.parseMealList(rawText);
    return AiMealPlanResponse(meals: meals, provider: provider, model: model);
  }

  @override
  Future<AiMealResponse> generateMealReplacement(
      AiMealReplacementRequest request) async {
    final prompt = request.buildPrompt();
    final rawText = await _callCompletions(prompt);
    return AiJsonParser.parseSingleMeal(rawText);
  }

  Future<String> _callCompletions(String prompt) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      throw const AiHttpFailure(
          'OpenAI API key is missing.', TestConnectionStatus.invalidKey);
    }
    final startTime = DateTime.now();
    AiLogger.logRequest(
        provider: 'OpenAI', endpoint: _completionsEndpoint, model: model);

    final response = await _transport.post(
      Uri.parse(_completionsEndpoint),
      headers: {
        'Authorization': 'Bearer $cleanKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are a professional chef and nutritionist. Always return valid, well-structured JSON.'
          },
          {'role': 'user', 'content': prompt}
        ],
        'response_format': {'type': 'json_object'},
        if (_supportsNoReasoning) 'reasoning_effort': 'none',
      }),
      timeout: const Duration(seconds: 90),
    );

    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    AiLogger.logResponse(
      provider: 'OpenAI',
      model: model,
      statusCode: response.statusCode,
      elapsedMs: elapsed,
    );

    if (response.statusCode == 200) {
      return completedChatText(response.body, 'OpenAI');
    }
    throw providerHttpFailure(response, 'OpenAI');
  }

  @override
  Future<List<String>> fetchAvailableModels() async {
    try {
      final cleanKey = apiKey.trim();
      if (cleanKey.isEmpty) return [];
      final response = await _transport.get(
        Uri.parse(_modelsEndpoint),
        headers: {'Authorization': 'Bearer $cleanKey'},
        timeout: const Duration(seconds: 15),
      );

      if (response.statusCode != 200) {
        throw providerHttpFailure(response, 'OpenAI');
      }
      final decoded = decodeProviderObject(response.body, 'OpenAI');
      final data = decoded['data'] as List<dynamic>? ?? [];
      final list = <String>[];
      for (final item in data) {
        if (item is Map && item['id'] is String) {
          final id = item['id'] as String;
          list.add(id);
        }
      }
      return AiModelRegistry.filterDiscovered(provider, list);
    } on AiHttpFailure {
      rethrow;
    } catch (_) {
      throw const AiHttpFailure('OpenAI returned an invalid model catalogue.');
    }
  }
}

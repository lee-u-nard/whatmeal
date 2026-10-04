import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../models/llm_config.dart';
import '../ai_provider_adapter.dart';
import '../ai_models.dart';
import '../ai_logger.dart';
import '../ai_json_parser.dart';

/// OpenAI / ChatGPT provider adapter.
class OpenAiAdapter implements AiProviderAdapter {
  OpenAiAdapter({
    required this.apiKey,
    String? model,
    this.customEndpoint,
  }) : model = model ?? 'gpt-4.1-mini';

  final String apiKey;
  @override
  final String model;
  final String? customEndpoint;

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
      final response = await http
          .post(
            Uri.parse(_completionsEndpoint),
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

      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      AiLogger.logResponse(
        provider: 'OpenAI',
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
              'Invalid OpenAI API key. Check that it was copied correctly from platform.openai.com.',
        );
      } else if (response.statusCode == 404) {
        return TestConnectionResult.failure(
          status: TestConnectionStatus.invalidModel,
          message:
              'Model "$model" does not exist or your account has no access to it.',
        );
      } else if (response.statusCode == 429) {
        return TestConnectionResult.failure(
          status: TestConnectionStatus.rateLimited,
          message:
              'OpenAI quota or rate limit exceeded. Verify your account balance or wait a moment.',
        );
      } else {
        return TestConnectionResult.failure(
          status: TestConnectionStatus.providerUnavailable,
          message: 'OpenAI returned HTTP ${response.statusCode}.',
        );
      }
    } catch (e) {
      AiLogger.logError(provider: 'OpenAI', model: model, error: e);
      return TestConnectionResult.failure(
        status: TestConnectionStatus.networkError,
        message: 'Could not connect to OpenAI. Check your network connection.',
      );
    }
  }

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
    final startTime = DateTime.now();
    AiLogger.logRequest(
        provider: 'OpenAI', endpoint: _completionsEndpoint, model: model);

    final response = await http
        .post(
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
          }),
        )
        .timeout(const Duration(seconds: 90));

    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    AiLogger.logResponse(
      provider: 'OpenAI',
      model: model,
      statusCode: response.statusCode,
      elapsedMs: elapsed,
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final text = (decoded['choices'] as List?)?.firstOrNull?['message']
          ?['content'] as String?;
      if (text == null || text.trim().isEmpty) {
        throw Exception('OpenAI returned an empty response.');
      }
      return text;
    } else if (response.statusCode == 401) {
      throw Exception('Invalid OpenAI API key. Check your key in AI Settings.');
    } else if (response.statusCode == 404) {
      throw Exception(
          'OpenAI model "$model" was not found (HTTP 404). Check your model selection.');
    } else if (response.statusCode == 429) {
      throw Exception(
          'OpenAI rate limit or billing quota exceeded. Verify your account balance.');
    } else {
      throw Exception('OpenAI error (HTTP ${response.statusCode}).');
    }
  }

  @override
  Future<List<String>> fetchAvailableModels() async {
    try {
      final cleanKey = apiKey.trim();
      final response = await http.get(
        Uri.parse(_modelsEndpoint),
        headers: {'Authorization': 'Bearer $cleanKey'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return [];
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as List<dynamic>? ?? [];
      final list = <String>[];
      for (final item in data) {
        if (item is Map && item['id'] is String) {
          final id = item['id'] as String;
          if (_isChatModel(id)) list.add(id);
        }
      }
      list.sort((a, b) => a.compareTo(b));
      return list;
    } catch (_) {
      return [];
    }
  }

  bool _isChatModel(String id) {
    final lower = id.toLowerCase();
    final isGpt = lower.contains('gpt');
    // Include o-series reasoning models (o1, o3, o4-mini, etc.)
    final isOSeries = RegExp(r'^o\d').hasMatch(lower);
    if (!isGpt && !isOSeries) return false;
    if (lower.contains('audio') ||
        lower.contains('realtime') ||
        lower.contains('embedding') ||
        lower.contains('instruct') ||
        lower.contains('tts')) {
      return false;
    }
    return true;
  }
}

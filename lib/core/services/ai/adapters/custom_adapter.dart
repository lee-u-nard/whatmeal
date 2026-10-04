import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../models/llm_config.dart';
import '../ai_provider_adapter.dart';
import '../ai_models.dart';
import '../ai_logger.dart';
import '../ai_json_parser.dart';

/// Adapter for self-hosted or third-party custom AI endpoints (e.g. Ollama, LM Studio, vLLM, OpenRouter).
class CustomAdapter implements AiProviderAdapter {
  CustomAdapter({
    required this.endpoint,
    this.apiKey,
    String? model,
    this.isOpenAiCompatible = true,
  }) : model = (model != null && model.isNotEmpty) ? model : 'default';

  final String endpoint;
  final String? apiKey;
  @override
  final String model;
  final bool isOpenAiCompatible;

  @override
  LlmProvider get provider => LlmProvider.custom;

  /// Resolves the chat completion endpoint correctly.
  String get completionsUrl {
    final ep = endpoint.trim();
    if (!isOpenAiCompatible) return ep;
    if (ep.endsWith('/chat/completions') || ep.endsWith('chat/completions')) {
      return ep;
    }
    return ep.endsWith('/') ? '${ep}chat/completions' : '$ep/chat/completions';
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    final key = apiKey?.trim();
    if (key != null && key.isNotEmpty) {
      headers['Authorization'] = 'Bearer $key';
    }
    return headers;
  }

  @override
  Future<TestConnectionResult> testConnection() async {
    final url = completionsUrl;
    if (url.isEmpty || !url.startsWith('http')) {
      return TestConnectionResult.failure(
        status: TestConnectionStatus.invalidEndpoint,
        message: 'Please provide a valid HTTP/HTTPS endpoint URL.',
      );
    }

    final startTime = DateTime.now();
    AiLogger.logRequest(provider: 'Custom', endpoint: url, model: model);

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: _headers,
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
        provider: 'Custom',
        model: model,
        statusCode: response.statusCode,
        elapsedMs: elapsed,
      );

      if (response.statusCode == 200) {
        return TestConnectionResult.success();
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        return TestConnectionResult.failure(
          status: TestConnectionStatus.invalidKey,
          message:
              'Authentication failed (HTTP ${response.statusCode}). Verify the API key if required by your endpoint.',
        );
      } else if (response.statusCode == 404) {
        return TestConnectionResult.failure(
          status: TestConnectionStatus.invalidEndpoint,
          message:
              'Endpoint returned 404 Not Found at $url. Check the base URL and path.',
        );
      } else {
        return TestConnectionResult.failure(
          status: TestConnectionStatus.providerUnavailable,
          message: 'Custom endpoint returned HTTP ${response.statusCode}.',
        );
      }
    } catch (e) {
      AiLogger.logError(provider: 'Custom', model: model, error: e);
      return TestConnectionResult.failure(
        status: TestConnectionStatus.networkError,
        message:
            'Could not connect to custom endpoint. Verify the host is reachable: $e',
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
    final url = completionsUrl;
    final startTime = DateTime.now();
    AiLogger.logRequest(provider: 'Custom', endpoint: url, model: model);

    final response = await http
        .post(
          Uri.parse(url),
          headers: _headers,
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'user', 'content': prompt}
            ],
          }),
        )
        .timeout(const Duration(seconds: 90));

    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    AiLogger.logResponse(
      provider: 'Custom',
      model: model,
      statusCode: response.statusCode,
      elapsedMs: elapsed,
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final text = (decoded['choices'] as List?)?.firstOrNull?['message']
          ?['content'] as String?;
      if (text == null || text.trim().isEmpty) {
        throw Exception('Custom API returned an empty response.');
      }
      return text;
    } else {
      throw Exception(
          'Custom endpoint error (HTTP ${response.statusCode}): ${response.body}');
    }
  }

  @override
  Future<List<String>> fetchAvailableModels() async {
    // If endpoint is OpenAI compatible, we can attempt GET /models
    if (!isOpenAiCompatible || endpoint.isEmpty) return [];
    try {
      final uri = Uri.parse(completionsUrl);
      final segs = uri.pathSegments
          .where((s) => s != 'chat' && s != 'completions')
          .toList();
      segs.add('models');
      final modelsUrl = uri.replace(pathSegments: segs).toString();

      final response = await http
          .get(
            Uri.parse(modelsUrl),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return [];
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as List<dynamic>? ?? [];
      final list = <String>[];
      for (final item in data) {
        if (item is Map && item['id'] is String) {
          list.add(item['id'] as String);
        }
      }
      return list;
    } catch (_) {
      return [];
    }
  }
}

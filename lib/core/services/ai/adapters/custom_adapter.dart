import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../models/llm_config.dart';
import '../ai_provider_adapter.dart';
import '../ai_models.dart';
import '../ai_logger.dart';
import '../ai_json_parser.dart';
import 'http_response_support.dart';

/// OpenAI Chat Completions wire protocol only. Native Ollama and arbitrary
/// JSON APIs are not supported; use their compatible endpoint if available.
class CustomAdapter implements AiProviderAdapter {
  CustomAdapter({
    required this.endpoint,
    this.apiKey,
    String? model,
    this.isOpenAiCompatible = true,
    http.Client? client,
  })  : _transport = AiHttpTransport('Custom', client: client),
        model = (model != null && model.isNotEmpty) ? model : 'default';

  final AiHttpTransport _transport;
  final String endpoint;
  final String? apiKey;
  @override
  final String model;
  final bool isOpenAiCompatible;

  @override
  LlmProvider get provider => LlmProvider.custom;

  /// Resolves the chat completion endpoint correctly.
  String get completionsUrl {
    final uri = Uri.tryParse(endpoint.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw const FormatException(
          'Enter a valid HTTP/HTTPS endpoint without embedded credentials.');
    }
    if (!isOpenAiCompatible) return uri.toString();
    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    return uri
        .replace(
            path: path.endsWith('/chat/completions')
                ? path
                : '$path/chat/completions')
        .toString();
  }

  Future<http.Response> _post(Uri uri,
          {Map<String, String>? headers,
          Object? body,
          Duration timeout = const Duration(seconds: 90)}) =>
      _transport.post(uri,
          headers: headers ?? {}, body: body as String, timeout: timeout);

  Future<http.Response> _get(Uri uri, {Map<String, String>? headers}) =>
      _transport.get(uri,
          headers: headers ?? {}, timeout: const Duration(seconds: 15));

  String _content(String body) {
    return completedChatText(body, 'Custom');
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
    final String url;
    try {
      url = completionsUrl;
    } catch (_) {
      return TestConnectionResult.failure(
        status: TestConnectionStatus.invalidEndpoint,
        message: 'Please provide a valid HTTP/HTTPS endpoint URL.',
      );
    }

    final startTime = DateTime.now();
    AiLogger.logRequest(provider: 'Custom', endpoint: url, model: model);

    try {
      final response = await _post(
        Uri.parse(url),
        timeout: const Duration(seconds: 15),
        headers: _headers,
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'user', 'content': 'Hi'}
          ],
          'max_tokens': 32,
        }),
      ).timeout(const Duration(seconds: 15));

      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      AiLogger.logResponse(
        provider: 'Custom',
        model: model,
        statusCode: response.statusCode,
        elapsedMs: elapsed,
      );

      if (response.statusCode == 200) {
        try {
          _content(response.body);
        } catch (_) {
          return TestConnectionResult.failure(
              status: TestConnectionStatus.invalidEndpoint,
              message:
                  'Endpoint does not return OpenAI Chat Completions JSON.');
        }
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
              'Endpoint returned 404 Not Found. Check the base URL and path.',
        );
      } else {
        return providerHttpFailure(response, 'Custom').toConnectionResult();
      }
    } on AiHttpFailure catch (e) {
      return e.toConnectionResult();
    } catch (e) {
      AiLogger.logError(provider: 'Custom', model: model, error: e);
      return TestConnectionResult.failure(
        status: TestConnectionStatus.networkError,
        message:
            'Could not connect to custom endpoint. Verify the host is reachable.',
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

    final response = await _post(
      Uri.parse(url),
      headers: _headers,
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
      }),
    ).timeout(const Duration(seconds: 90));

    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    AiLogger.logResponse(
      provider: 'Custom',
      model: model,
      statusCode: response.statusCode,
      elapsedMs: elapsed,
    );

    if (response.statusCode == 200) {
      return _content(response.body);
    } else {
      throw providerHttpFailure(response, 'Custom');
    }
  }

  @override
  Future<List<String>> fetchAvailableModels() async {
    // If endpoint is OpenAI compatible, we can attempt GET /models
    if (!isOpenAiCompatible || endpoint.isEmpty) return [];
    try {
      final uri = Uri.parse(completionsUrl);
      final segs = uri.pathSegments.toList();
      segs.removeRange(segs.length - 2, segs.length);
      segs.add('models');
      final modelsUrl = uri.replace(pathSegments: segs).toString();

      final response = await _get(
        Uri.parse(modelsUrl),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw providerHttpFailure(response, 'Custom');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as List<dynamic>? ?? [];
      final list = <String>[];
      for (final item in data) {
        if (item is Map && item['id'] is String) {
          list.add(item['id'] as String);
        }
      }
      return list;
    } on AiHttpFailure {
      rethrow;
    } catch (_) {
      throw const AiHttpFailure(
          'Custom endpoint returned an invalid model catalogue.');
    }
  }
}

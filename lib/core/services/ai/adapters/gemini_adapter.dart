import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../../models/llm_config.dart';
import '../ai_provider_adapter.dart';
import '../ai_models.dart';
import '../bundled_key_pool.dart';
import '../firebase_ai_app_check.dart';
import '../generation_failure.dart';
import '../ai_logger.dart';
import '../ai_json_parser.dart';
import '../model_registry.dart';
import 'http_response_support.dart';

/// Configured prototype keys already use the Gemini Developer API. Prefer that
/// route directly; explicit personal keys take precedence. The legacy Firebase
/// route remains available when no prototype pool is configured.
class GeminiAdapter implements AiProviderAdapter {
  GeminiAdapter({
    this.apiKey,
    String? model,
    http.Client? client,
    List<String>? bundledKeys,
  })  : _transport = AiHttpTransport('Gemini', client: client),
        _keyPool = bundledKeys == null
            ? BundledKeyPool.instance
            : BundledKeyPool(bundledKeys),
        model = (model != null && model.trim().isNotEmpty)
            ? model.trim()
            : AiModelRegistry.defaultGemini;

  final AiHttpTransport _transport;
  final BundledKeyPool _keyPool;
  final String? apiKey;
  @override
  final String model;

  @override
  LlmProvider get provider => LlmProvider.gemini;

  bool get usesFirebaseAi => !_hasCustomKey && _keyPool.count == 0;
  bool get _hasCustomKey => apiKey?.trim().isNotEmpty == true;
  String get _effectiveKey => apiKey!.trim();

  @override
  Future<TestConnectionResult> testConnection() async {
    try {
      if (_hasCustomKey) {
        await _generateWithRest('Reply with OK.', probe: true);
        return TestConnectionResult.success();
      } else if (_keyPool.count > 0) {
        await _withBundledKey(_countWithRest);
        return TestConnectionResult.success();
      } else {
        // Test built-in Firebase AI Logic
        AiLogger.logRequest(
          provider: 'Gemini (Firebase AI)',
          endpoint: 'Firebase AI Logic SDK',
          model: model,
        );
        final generativeModel = FirebaseAI.googleAI(
          auth: FirebaseAuth.instance,
          appCheck: FirebaseAiAppCheck(FirebaseAppCheck.instance),
        ).generativeModel(model: model);

        // Verify the real model endpoint without waiting for text generation.
        // A successful connection check does not claim meal generation passed.
        final response = await generativeModel
            .countTokens([Content.text('WhatMeal connection check')]).timeout(
                const Duration(seconds: 15));
        if (response.totalTokens <= 0) {
          throw const GenerationFailure(GenerationFailureKind.malformed);
        }
        return TestConnectionResult.success();
      }
    } on AiHttpFailure catch (e) {
      return e.toConnectionResult();
    } catch (e) {
      AiLogger.logError(provider: 'Gemini', model: model, error: e);
      final failure = GenerationFailure.from(e);
      return TestConnectionResult.failure(
        status: switch (failure.kind) {
          GenerationFailureKind.network ||
          GenerationFailureKind.dns ||
          GenerationFailureKind.timeout =>
            TestConnectionStatus.networkError,
          GenerationFailureKind.invalidModel =>
            TestConnectionStatus.invalidModel,
          GenerationFailureKind.configuration =>
            TestConnectionStatus.configurationError,
          GenerationFailureKind.authentication =>
            TestConnectionStatus.authenticationRequired,
          GenerationFailureKind.permission =>
            TestConnectionStatus.permissionDenied,
          GenerationFailureKind.quota => TestConnectionStatus.rateLimited,
          GenerationFailureKind.appCheck ||
          GenerationFailureKind.firebase =>
            TestConnectionStatus.failed,
          _ => TestConnectionStatus.providerUnavailable,
        },
        message: GenerationFailure.connectionCheckMessage(e),
      );
    }
  }

  Future<T> _withBundledKey<T>(Future<T> Function(String) operation) async {
    final keys = _keyPool.requestKeys();
    for (var index = 0; index < keys.length; index++) {
      try {
        return await operation(keys[index]);
      } catch (error) {
        if (index == keys.length - 1 || !BundledKeyPool.canTryNext(error)) {
          rethrow;
        }
      }
    }
    throw const GenerationFailure(GenerationFailureKind.configuration);
  }

  Future<void> _countWithRest(String key) async {
    final cleanModel = model.replaceFirst(RegExp(r'^models/'), '');
    final response = await _transport.post(
      Uri.https('generativelanguage.googleapis.com',
          '/v1beta/models/$cleanModel:countTokens'),
      headers: {'Content-Type': 'application/json', 'x-goog-api-key': key},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': 'WhatMeal connection check'}
            ]
          }
        ]
      }),
      timeout: const Duration(seconds: 15),
    );
    if (response.statusCode != 200) {
      throw providerHttpFailure(response, 'Gemini');
    }
    final count = decodeProviderObject(response.body, 'Gemini')['totalTokens'];
    if (count is! int || count <= 0) {
      throw const GenerationFailure(GenerationFailureKind.malformed);
    }
  }

  @override
  Future<AiMealPlanResponse> generateMealPlan(AiMealPlanRequest request) async {
    final prompt = request.buildPrompt();
    final rawText = await _generate(prompt);
    final meals = AiJsonParser.parseMealList(rawText);
    return AiMealPlanResponse(meals: meals, provider: provider, model: model);
  }

  @override
  Future<AiMealResponse> generateMealReplacement(
      AiMealReplacementRequest request) async {
    final prompt = request.buildPrompt();
    final rawText = await _generate(prompt);
    return AiJsonParser.parseSingleMeal(rawText);
  }

  Future<String> _generate(String prompt) async {
    if (_hasCustomKey) {
      return _generateWithRest(prompt);
    }
    if (_keyPool.count > 0) {
      return _withBundledKey(
          (key) => _generateWithRest(prompt, credential: key));
    }
    return _generateWithFirebaseAI(prompt);
  }

  Future<String> _generateWithFirebaseAI(String prompt) async {
    AiLogger.logRequest(
      provider: 'Gemini (Firebase AI)',
      endpoint: 'Firebase AI Logic SDK',
      model: model,
    );
    final generativeModel = FirebaseAI.googleAI(
      auth: FirebaseAuth.instance,
      appCheck: FirebaseAiAppCheck(FirebaseAppCheck.instance),
    ).generativeModel(
      model: model,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        responseMimeType: 'application/json',
      ),
    );

    final response = await generativeModel.generateContent(
        [Content.text(prompt)]).timeout(const Duration(seconds: 90));
    return firebaseText(response);
  }

  /// Validate completion metadata before the JSON parser can salvage a partial
  /// recipe. No provider body or block-reason text escapes into the UI/logs.
  static String firebaseText(GenerateContentResponse response) {
    final candidate = response.candidates.firstOrNull;
    if (response.promptFeedback?.blockReason != null ||
        candidate?.finishReason == FinishReason.safety ||
        candidate?.finishReason == FinishReason.recitation) {
      throw const GenerationFailure(GenerationFailureKind.safety);
    }
    if (candidate?.finishReason != FinishReason.stop) {
      throw const GenerationFailure(GenerationFailureKind.malformed);
    }
    final text = response.text;
    if (text == null || text.trim().isEmpty) {
      throw const GenerationFailure(GenerationFailureKind.malformed);
    }
    return text;
  }

  static String restText(String body) {
    final decoded = decodeProviderObject(body, 'Gemini');
    final feedback = decoded['promptFeedback'];
    if (feedback is Map && feedback['blockReason'] != null) {
      throw const GenerationFailure(GenerationFailureKind.safety);
    }
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty || candidates.first is! Map) {
      throw const GenerationFailure(GenerationFailureKind.malformed);
    }
    final candidate = candidates.first as Map;
    final reason = candidate['finishReason'];
    if (const ['SAFETY', 'RECITATION', 'BLOCKLIST', 'PROHIBITED_CONTENT']
        .contains(reason)) {
      throw const GenerationFailure(GenerationFailureKind.safety);
    }
    if (reason != 'STOP') {
      throw const GenerationFailure(GenerationFailureKind.malformed);
    }
    final content = candidate['content'];
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List) {
      throw const GenerationFailure(GenerationFailureKind.malformed);
    }
    final text = parts
        .whereType<Map>()
        .where((p) => p['thought'] != true && p['text'] is String)
        .map((p) => p['text'] as String)
        .join();
    if (text.trim().isEmpty) {
      throw const GenerationFailure(GenerationFailureKind.malformed);
    }
    return text;
  }

  Future<String> _generateWithRest(String prompt,
      {bool probe = false, String? credential}) async {
    final cleanModel = model.replaceAll('models/', '');
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$cleanModel:generateContent',
    );
    AiLogger.logRequest(
      provider: 'Gemini (REST)',
      endpoint:
          'https://generativelanguage.googleapis.com/v1beta/models/$cleanModel:generateContent',
      model: model,
    );
    final startTime = DateTime.now();

    final response = await _transport.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': credential ?? _effectiveKey
      },
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          if (probe) 'maxOutputTokens': 256,
          if (!probe) 'temperature': 0.7,
          if (!probe) 'responseMimeType': 'application/json',
        },
      }),
      timeout: Duration(seconds: probe ? 15 : 90),
    );

    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    AiLogger.logResponse(
      provider: 'Gemini (REST)',
      model: model,
      statusCode: response.statusCode,
      elapsedMs: elapsed,
    );

    if (response.statusCode == 200) {
      return restText(response.body);
    }
    throw providerHttpFailure(response, 'Gemini');
  }

  @override
  Future<List<String>> fetchAvailableModels() async {
    if (!_hasCustomKey) {
      throw const AiHttpFailure(
          'Account model discovery requires your own Gemini API key. The documented catalogue remains available.');
    }
    final ids = <String>[];
    String? pageToken;
    var pages = 0;
    do {
      final response = await _transport.get(
        Uri.https('generativelanguage.googleapis.com', '/v1beta/models', {
          'pageSize': '1000',
          if (pageToken != null) 'pageToken': pageToken,
        }),
        headers: {'x-goog-api-key': _effectiveKey},
        timeout: const Duration(seconds: 15),
      );
      if (response.statusCode != 200) {
        throw providerHttpFailure(response, 'Gemini');
      }
      final data = decodeProviderObject(response.body, 'Gemini');
      for (final item in (data['models'] as List? ?? []).whereType<Map>()) {
        if (item['supportedGenerationMethods'] is List &&
            (item['supportedGenerationMethods'] as List)
                .contains('generateContent') &&
            item['name'] is String) {
          ids.add((item['name'] as String).replaceFirst('models/', ''));
        }
      }
      final next = data['nextPageToken'];
      // Bound discovery even if an endpoint repeats tokens unexpectedly.
      if (next is! String || next.isEmpty || next == pageToken) break;
      pageToken = next;
    } while (++pages < 10);
    return AiModelRegistry.filterDiscovered(provider, ids);
  }
}

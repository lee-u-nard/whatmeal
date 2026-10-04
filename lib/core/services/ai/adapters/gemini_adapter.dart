import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../../models/llm_config.dart';
import '../../../constants.dart';
import '../ai_provider_adapter.dart';
import '../ai_models.dart';
import '../ai_logger.dart';
import '../ai_json_parser.dart';

/// Gemini adapter implementing WhatMeal's default AI provider via Firebase AI Logic
/// (and optional direct Google AI Studio API key via REST).
class GeminiAdapter implements AiProviderAdapter {
  GeminiAdapter({
    this.apiKey,
    String? model,
  }) : model = (model != null && model.trim().isNotEmpty)
            ? model.trim()
            : 'gemini-3.8-flash';

  final String? apiKey;
  @override
  final String model;

  @override
  LlmProvider get provider => LlmProvider.gemini;

  bool get _hasCustomKey =>
      (apiKey != null && apiKey!.trim().isNotEmpty) ||
      (kGeminiApiKey.isNotEmpty && kGeminiApiKey != 'YOUR_GEMINI_API_KEY');

  String get _effectiveKey => (apiKey != null && apiKey!.trim().isNotEmpty)
      ? apiKey!.trim()
      : kGeminiApiKey;

  @override
  Future<TestConnectionResult> testConnection() async {
    final startTime = DateTime.now();
    try {
      if (_hasCustomKey) {
        AiLogger.logRequest(
          provider: 'Gemini (REST)',
          endpoint: 'generativelanguage.googleapis.com',
          model: model,
        );
        final cleanModel = model.replaceAll('models/', '');
        final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$cleanModel:generateContent?key=$_effectiveKey',
        );
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {'text': 'Ping'}
                    ]
                  }
                ],
                'generationConfig': {'maxOutputTokens': 1},
              }),
            )
            .timeout(const Duration(seconds: 15));

        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        AiLogger.logResponse(
          provider: 'Gemini (REST)',
          model: model,
          statusCode: response.statusCode,
          elapsedMs: elapsed,
        );

        if (response.statusCode == 200) {
          return TestConnectionResult.success();
        } else if (response.statusCode == 400 || response.statusCode == 403) {
          return TestConnectionResult.failure(
            status: TestConnectionStatus.invalidKey,
            message: 'Invalid Gemini API key or lack of permissions.',
          );
        } else if (response.statusCode == 404) {
          return TestConnectionResult.failure(
            status: TestConnectionStatus.invalidModel,
            message: 'Model "$model" was not found on Google AI Studio.',
          );
        } else if (response.statusCode == 429) {
          return TestConnectionResult.failure(
            status: TestConnectionStatus.rateLimited,
            message: 'Gemini rate limit exceeded. Please wait a moment.',
          );
        } else {
          return TestConnectionResult.failure(
            status: TestConnectionStatus.providerUnavailable,
            message: 'Google Gemini returned HTTP ${response.statusCode}.',
          );
        }
      } else {
        // Test built-in Firebase AI Logic
        AiLogger.logRequest(
          provider: 'Gemini (Firebase AI)',
          endpoint: 'Firebase AI Logic SDK',
          model: model,
        );
        final generativeModel = FirebaseAI.googleAI(
          auth: FirebaseAuth.instance,
          appCheck: FirebaseAppCheck.instance,
        ).generativeModel(model: model);

        final response = await generativeModel.generateContent(
            [Content.text('Ping')]).timeout(const Duration(seconds: 15));
        if (response.text != null) {
          return TestConnectionResult.success();
        }
        return TestConnectionResult.failure(
          status: TestConnectionStatus.providerUnavailable,
          message: 'Firebase AI Logic returned an empty test response.',
        );
      }
    } catch (e) {
      AiLogger.logError(provider: 'Gemini', model: model, error: e);
      final msg = e.toString().toLowerCase();
      if (msg.contains('app check') ||
          msg.contains('deactivated') ||
          msg.contains('fetch-status-error')) {
        return TestConnectionResult.failure(
          status: TestConnectionStatus.providerUnavailable,
          message:
              'Firebase AI / App Check is not enabled. Provide a free Gemini API key to connect directly.',
        );
      }
      return TestConnectionResult.failure(
        status: TestConnectionStatus.networkError,
        message:
            'Could not connect to Gemini servers. Check your internet connection.',
      );
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
      appCheck: FirebaseAppCheck.instance,
    ).generativeModel(
      model: model,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        responseMimeType: 'application/json',
      ),
    );

    final response = await generativeModel.generateContent(
        [Content.text(prompt)]).timeout(const Duration(seconds: 90));
    final text = response.text;
    if (text == null || text.trim().isEmpty) {
      throw Exception('Firebase AI Logic returned an empty response.');
    }
    return text;
  }

  Future<String> _generateWithRest(String prompt) async {
    final cleanModel = model.replaceAll('models/', '');
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$cleanModel:generateContent?key=$_effectiveKey',
    );
    AiLogger.logRequest(
      provider: 'Gemini (REST)',
      endpoint:
          'https://generativelanguage.googleapis.com/v1beta/models/$cleanModel:generateContent',
      model: model,
    );
    final startTime = DateTime.now();

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.7,
              'responseMimeType': 'application/json',
            },
          }),
        )
        .timeout(const Duration(seconds: 90));

    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    AiLogger.logResponse(
      provider: 'Gemini (REST)',
      model: model,
      statusCode: response.statusCode,
      elapsedMs: elapsed,
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        final block = decoded['promptFeedback']?['blockReason']?.toString();
        throw Exception(
          block != null
              ? 'Gemini blocked the meal-plan request ($block). Try adjusting preferences or restrictions.'
              : 'Gemini REST returned no candidates. Try again or switch models in AI Settings.',
        );
      }
      final parts = candidates.firstOrNull?['content']?['parts'] as List?;
      final text = parts?.firstOrNull?['text'] as String?;
      if (text == null || text.trim().isEmpty) {
        throw Exception('Gemini REST returned an empty response.');
      }
      return text;
    } else if (response.statusCode == 400 || response.statusCode == 403) {
      final detail = _extractApiError(response.body);
      throw Exception(
        'Invalid Gemini API key or permission denied${detail != null ? ': $detail' : '. Check your key in AI Settings.'}',
      );
    } else if (response.statusCode == 404) {
      throw Exception(
        'Gemini model "$model" not found (HTTP 404). Try gemini-3.8-flash in AI Settings.',
      );
    } else if (response.statusCode == 429) {
      throw Exception('Gemini rate limit exceeded. Please wait a moment.');
    } else {
      final detail = _extractApiError(response.body);
      throw Exception(
        'Gemini REST API error (HTTP ${response.statusCode})${detail != null ? ': $detail' : '.'}',
      );
    }
  }

  String? _extractApiError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        final message = decoded['error']['message']?.toString();
        if (message != null && message.trim().isNotEmpty) {
          return message.length > 160
              ? '${message.substring(0, 160)}…'
              : message;
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<List<String>> fetchAvailableModels() async {
    return [
      'gemini-3.8-flash',
      'gemini-3.7-flash',
      'gemini-3.6-flash',
      'gemini-3.5-flash',
      'gemini-3.5-flash-lite',
      'gemini-3.1-pro-preview',
      'gemini-3-flash-preview',
      'gemini-2.5-flash',
      'gemini-2.5-flash-lite',
    ];
  }
}

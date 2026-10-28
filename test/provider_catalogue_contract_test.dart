// Offline HTTP mock contracts only. These do not establish live provider,
// account/model access, Firebase AI Logic, cost, or recipe accuracy.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whatmeal/core/models/llm_config.dart';
import 'package:whatmeal/core/services/ai/adapters/anthropic_adapter.dart';
import 'package:whatmeal/core/services/ai/adapters/gemini_adapter.dart';
import 'package:whatmeal/core/services/ai/adapters/groq_adapter.dart';
import 'package:whatmeal/core/services/ai/adapters/http_response_support.dart';
import 'package:whatmeal/core/services/ai/adapters/openai_adapter.dart';
import 'package:whatmeal/core/services/ai/ai_models.dart';
import 'package:whatmeal/core/services/ai/ai_provider_adapter.dart';
import 'package:whatmeal/core/services/ai/model_registry.dart';

const _mockKey = 'fake-local-catalogue-key';
const _request = AiMealPlanRequest(
  familyMemberNames: ['Disposable demo member'],
  numberOfDays: 1,
  mealTypes: ['Dinner'],
  restrictions: ['Peanut'],
);

AiProviderAdapter _adapter(
        LlmProvider provider, String model, http.Client client) =>
    switch (provider) {
      LlmProvider.gemini =>
        GeminiAdapter(apiKey: _mockKey, model: model, client: client),
      LlmProvider.openai =>
        OpenAiAdapter(apiKey: _mockKey, model: model, client: client),
      LlmProvider.anthropic =>
        AnthropicAdapter(apiKey: _mockKey, model: model, client: client),
      LlmProvider.groq =>
        GroqAdapter(apiKey: _mockKey, model: model, client: client),
      LlmProvider.custom =>
        throw StateError('No built-in custom model catalogue'),
    };

String _completeEnvelope(LlmProvider provider) {
  final recipeJson = jsonEncode({
    'meals': [
      {
        'title': 'Handwritten mock rice recipe',
        'mealType': 'Dinner',
        'dayIndex': 0,
        'ingredients': [
          {'name': 'Rice', 'amount': '1 cup'}
        ],
        'instructions': ['Cook the rice until tender.'],
      }
    ]
  });
  return jsonEncode(switch (provider) {
    LlmProvider.gemini => {
        'candidates': [
          {
            'finishReason': 'STOP',
            'content': {
              'parts': [
                {'text': recipeJson}
              ]
            }
          }
        ]
      },
    LlmProvider.anthropic => {
        'stop_reason': 'end_turn',
        'content': [
          {'type': 'text', 'text': recipeJson}
        ],
      },
    LlmProvider.openai || LlmProvider.groq => {
        'choices': [
          {
            'finish_reason': 'stop',
            'message': {'content': recipeJson}
          }
        ]
      },
    LlmProvider.custom => throw StateError('Not a built-in provider'),
  });
}

void main() {
  // The loop follows reviewed selectable entries so adding a provider model
  // also requires its existing adapter to satisfy this generation contract.
  for (final model in AiModelRegistry.all.where((m) => m.selectable)) {
    test('offline mock generation contract: ${model.provider.name}/${model.id}',
        () async {
      var requests = 0;
      final client = MockClient((httpRequest) async {
        requests++;
        expect(httpRequest.method, 'POST');
        expect(httpRequest.url.scheme, 'https');
        final body = jsonDecode(httpRequest.body) as Map;
        switch (model.provider) {
          case LlmProvider.gemini:
            expect(httpRequest.url.host, 'generativelanguage.googleapis.com');
            expect(httpRequest.url.path,
                '/v1beta/models/${model.id}:generateContent');
            expect(httpRequest.url.queryParameters.containsKey('key'), isFalse);
            expect(httpRequest.headers['x-goog-api-key'], _mockKey);
            expect(body['generationConfig']['responseMimeType'],
                'application/json');
            expect(body['contents'], isNotEmpty);
          case LlmProvider.anthropic:
            expect(httpRequest.url.host, 'api.anthropic.com');
            expect(httpRequest.url.path, '/v1/messages');
            expect(httpRequest.headers['x-api-key'], _mockKey);
            expect(httpRequest.headers['anthropic-version'], '2023-06-01');
            expect(body['model'], model.id);
          case LlmProvider.openai:
            expect(httpRequest.url.host, 'api.openai.com');
            expect(httpRequest.url.path, '/v1/chat/completions');
            expect(httpRequest.headers['Authorization'], 'Bearer $_mockKey');
            expect(body['model'], model.id);
            expect(body['response_format'], {'type': 'json_object'});
          case LlmProvider.groq:
            expect(httpRequest.url.host, 'api.groq.com');
            expect(httpRequest.url.path, '/openai/v1/chat/completions');
            expect(httpRequest.headers['Authorization'], 'Bearer $_mockKey');
            expect(body['model'], model.id);
            expect(body['response_format'], {'type': 'json_object'});
          case LlmProvider.custom:
            fail(
                'Custom endpoints must not be represented as reviewed models.');
        }
        return http.Response(_completeEnvelope(model.provider), 200);
      });
      final adapter = _adapter(model.provider, model.id, client);
      final response = await adapter.generateMealPlan(_request);
      expect(response.provider, model.provider);
      expect(response.model, model.id);
      expect(response.meals.single.title, 'Handwritten mock rice recipe');
      _request.validateMeals(response.meals);
      expect(requests, 1);
    });
  }

  test(
      'offline mock discovery: failed HTTP statuses remain explicit and redacted',
      () async {
    for (final provider
        in LlmProvider.values.where((p) => p != LlmProvider.custom)) {
      for (final status in [401, 403, 404, 429, 500]) {
        var requests = 0;
        final adapter =
            _adapter(provider, AiModelRegistry.choices(provider).first,
                MockClient((request) async {
          requests++;
          expect(request.method, 'GET');
          return http.Response(
              jsonEncode({
                'error': {'message': '$_mockKey private echoed data'}
              }),
              status);
        }));
        await expectLater(
            adapter.fetchAvailableModels(),
            throwsA(isA<AiHttpFailure>()
                .having((e) => e.message, 'message', isNot(contains(_mockKey)))
                .having((e) => e.message, 'message', isNot(contains('echoed')))
                .having(
                    (e) => e.status,
                    'status',
                    switch (status) {
                      401 => TestConnectionStatus.invalidKey,
                      403 => TestConnectionStatus.permissionDenied,
                      404 => TestConnectionStatus.invalidModel,
                      429 => TestConnectionStatus.rateLimited,
                      _ => TestConnectionStatus.providerUnavailable,
                    })));
        expect(requests, 1, reason: 'Discovery must not silently retry.');
      }
    }
  });

  test(
      'offline mock discovery: OpenAI/Groq exclude unknown and non-chat models',
      () async {
    for (final provider in [LlmProvider.openai, LlmProvider.groq]) {
      final choices = AiModelRegistry.choices(provider);
      final unsupported = provider == LlmProvider.openai
          ? ['gpt-4o-realtime-preview', 'text-embedding-3-small', 'gpt-4-0314']
          : ['whisper-large-v3', 'llama3-70b-8192', 'unknown-future-model'];
      final notSelectable = AiModelRegistry.forProvider(provider)
          .where((m) => !m.selectable)
          .map((m) => m.id);
      final adapter =
          _adapter(provider, choices.first, MockClient((request) async {
        expect(
            request.url.path,
            provider == LlmProvider.openai
                ? '/v1/models'
                : '/openai/v1/models');
        return http.Response(
            jsonEncode({
              'data': [
                for (final id in [
                  ...choices,
                  choices.first,
                  ...unsupported,
                  ...notSelectable,
                  'unreviewed-model-id',
                ])
                  {'id': id}
              ]
            }),
            200);
      }));
      final expected = [...choices]..sort();
      expect(await adapter.fetchAvailableModels(), expected);
    }
  });

  test('offline mock discovery: Claude paginates and maps dated aliases',
      () async {
    var pages = 0;
    final adapter = AnthropicAdapter(
        apiKey: _mockKey,
        client: MockClient((request) async {
          pages++;
          expect(request.url.path, '/v1/models');
          expect(request.url.queryParameters['limit'], '1000');
          expect(request.headers['x-api-key'], _mockKey);
          if (pages == 1) {
            expect(
                request.url.queryParameters.containsKey('after_id'), isFalse);
            return http.Response(
                jsonEncode({
                  'data': [
                    {'id': 'claude-haiku-4-5-20251001'}
                  ],
                  'has_more': true,
                  'last_id': 'claude-haiku-4-5-20251001',
                }),
                200);
          }
          expect(request.url.queryParameters['after_id'],
              'claude-haiku-4-5-20251001');
          return http.Response(
              jsonEncode({
                'data': [
                  {'id': 'claude-sonnet-4-5-20250929'},
                  {'id': 'claude-opus-4-5-20251101'},
                  {'id': 'claude-sonnet-5-5'},
                  {'id': 'claude-3-5-sonnet-20241022'},
                  {'id': 'unknown-future-model'},
                ],
                'has_more': false,
              }),
              200);
        }));
    final expected = AiModelRegistry.filterDiscovered(LlmProvider.anthropic, [
      'claude-haiku-4-5',
      'claude-sonnet-4-5',
      'claude-opus-4-5',
      'claude-sonnet-5-5',
    ]);
    expect(await adapter.fetchAvailableModels(), expected);
    expect(pages, 2);
  });

  test('offline mock discovery: Gemini pages only supported content models',
      () async {
    final choices = AiModelRegistry.choices(LlmProvider.gemini);
    var pages = 0;
    final adapter = GeminiAdapter(
        apiKey: _mockKey,
        client: MockClient((request) async {
          pages++;
          expect(request.url.host, 'generativelanguage.googleapis.com');
          expect(request.url.path, '/v1beta/models');
          expect(request.headers['x-goog-api-key'], _mockKey);
          expect(request.url.queryParameters.containsKey('key'), isFalse);
          if (pages == 1) {
            expect(
                request.url.queryParameters.containsKey('pageToken'), isFalse);
            return http.Response(
                jsonEncode({
                  'models': [
                    {
                      'name': 'models/${choices.first}',
                      'supportedGenerationMethods': ['generateContent'],
                    },
                    {
                      'name': 'models/${choices.last}',
                      'supportedGenerationMethods': ['embedContent'],
                    },
                  ],
                  'nextPageToken': 'mock-next-page',
                }),
                200);
          }
          expect(request.url.queryParameters['pageToken'], 'mock-next-page');
          return http.Response(
              jsonEncode({
                'models': [
                  {
                    'name': 'models/${choices[1]}',
                    'supportedGenerationMethods': ['generateContent'],
                  },
                  {
                    'name': 'models/unknown-future-model',
                    'supportedGenerationMethods': ['generateContent'],
                  },
                  {
                    'name': 'models/${choices.first}',
                    'supportedGenerationMethods': ['generateContent'],
                  },
                ],
              }),
              200);
        }));
    final expected = [choices.first, choices[1]]..sort();
    expect(await adapter.fetchAvailableModels(), expected);
    expect(pages, 2);
  });
}

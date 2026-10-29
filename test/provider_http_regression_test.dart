import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whatmeal/core/services/ai/adapters/anthropic_adapter.dart';
import 'package:whatmeal/core/services/ai/adapters/groq_adapter.dart';
import 'package:whatmeal/core/services/ai/adapters/http_response_support.dart';
import 'package:whatmeal/core/services/ai/adapters/openai_adapter.dart';
import 'package:whatmeal/core/services/ai/ai_models.dart';
import 'package:whatmeal/core/services/ai/ai_provider_adapter.dart';
import 'package:whatmeal/features/meal/models/meal.dart';

const _fakeKey = 'fake-local-test-secret';
const _planRequest = AiMealPlanRequest(
  familyMemberNames: ['Demo'],
  numberOfDays: 1,
  mealTypes: ['Dinner'],
);
const _largePlanRequest = AiMealPlanRequest(
  familyMemberNames: ['Demo'],
  numberOfDays: 3,
  mealTypes: ['Breakfast', 'Lunch', 'Dinner'],
);

Map<String, dynamic> _recipe({String title = 'Vegetable rice'}) => {
      'title': title,
      'mealType': 'Dinner',
      'dayIndex': 0,
      'ingredients': [
        {'name': 'Rice', 'amount': '1 cup'}
      ],
      'instructions': ['Cook the rice until tender.'],
    };

String _chat(String text, {String? finish = 'stop', Object? refusal}) =>
    jsonEncode({
      'choices': [
        {
          'message': {'content': text, if (refusal != null) 'refusal': refusal},
          if (finish != null) 'finish_reason': finish,
        }
      ],
    });

String _claude(String text, {String? finish = 'end_turn'}) => jsonEncode({
      'content': [
        {'type': 'text', 'text': text}
      ],
      if (finish != null) 'stop_reason': finish,
    });

class _ProviderCase {
  const _ProviderCase(this.name, this.create, {this.anthropic = false});
  final String name;
  final AiProviderAdapter Function(http.Client, String) create;
  final bool anthropic;

  String completion(String content, {String? finish}) => anthropic
      ? _claude(content, finish: finish ?? 'end_turn')
      : _chat(content, finish: finish ?? 'stop');
}

void main() {
  final cases = [
    _ProviderCase(
        'OpenAI', (client, key) => OpenAiAdapter(apiKey: key, client: client)),
    _ProviderCase(
        'Groq', (client, key) => GroqAdapter(apiKey: key, client: client)),
    _ProviderCase('Claude',
        (client, key) => AnthropicAdapter(apiKey: key, client: client),
        anthropic: true),
  ];

  for (final provider in cases) {
    group('${provider.name} injected HTTP protocol', () {
      test('connection requires real completed text and correct credentials',
          () async {
        var requests = 0;
        final adapter = provider.create(MockClient((request) async {
          requests++;
          expect(request.method, 'POST');
          expect(request.url.scheme, 'https');
          expect(
              request
                  .headers[provider.anthropic ? 'x-api-key' : 'Authorization'],
              provider.anthropic ? _fakeKey : 'Bearer $_fakeKey');
          if (provider.anthropic) {
            expect(request.headers['anthropic-version'], '2023-06-01');
          }
          final body = jsonDecode(request.body) as Map;
          expect(body['model'], isA<String>());
          expect(body['messages'].last['content'], 'Reply with OK.');
          return http.Response(provider.completion('OK'), 200);
        }), '  $_fakeKey  ');
        expect((await adapter.testConnection()).isValid, isTrue);
        expect(requests, 1);
      });

      test('HTTP 200 with malformed or empty output is not connected',
          () async {
        for (final body in [
          '{}',
          '[]',
          '<html>$_fakeKey</html>',
          provider.completion(''),
        ]) {
          final adapter = provider.create(
              MockClient((_) async => http.Response(body, 200)), _fakeKey);
          final result = await adapter.testConnection();
          expect(result.isValid, isFalse);
          expect(result.errorMessage, isNot(contains(_fakeKey)));
          expect(result.status, TestConnectionStatus.providerUnavailable);
        }
      });

      test('refusal and incomplete finish reasons do not count as a connection',
          () async {
        final bodies = provider.anthropic
            ? [
                _claude('private content', finish: 'refusal'),
                _claude('OK', finish: 'max_tokens'),
                _claude('OK', finish: 'tool_use'),
                _claude('OK', finish: null),
              ]
            : [
                _chat('OK', refusal: 'private content'),
                _chat('OK', finish: 'length'),
                _chat('OK', finish: 'tool_calls'),
                _chat('OK', finish: 'content_filter'),
                _chat('OK', finish: null),
              ];
        for (final body in bodies) {
          final result = await provider
              .create(
                  MockClient((_) async => http.Response(body, 200)), _fakeKey)
              .testConnection();
          expect(result.isValid, isFalse);
          expect(result.errorMessage, isNot(contains('private content')));
        }
      });

      test('missing key performs no request for probe or generation', () async {
        final adapter = provider.create(MockClient((_) async {
          fail('A missing key must not trigger HTTP.');
        }), ' ');
        expect((await adapter.testConnection()).status,
            TestConnectionStatus.invalidKey);
        await expectLater(adapter.generateMealPlan(_planRequest),
            throwsA(isA<AiHttpFailure>()));
      });

      for (final status in [400, 401, 403, 404, 429, 500, 529]) {
        test('HTTP $status errors are classified and never echo provider data',
            () async {
          var requests = 0;
          final adapter = provider.create(MockClient((_) async {
            requests++;
            return http.Response(
                jsonEncode({
                  'error': {'message': '$_fakeKey private household content'}
                }),
                status);
          }), _fakeKey);
          final connection = await adapter.testConnection();
          expect(connection.isValid, isFalse);
          expect(connection.errorMessage, isNot(contains(_fakeKey)));
          expect(connection.errorMessage, isNot(contains('household')));
          expect(
              connection.status,
              switch (status) {
                401 => TestConnectionStatus.invalidKey,
                403 => TestConnectionStatus.permissionDenied,
                404 => TestConnectionStatus.invalidModel,
                429 => TestConnectionStatus.rateLimited,
                _ => TestConnectionStatus.providerUnavailable,
              });
          await expectLater(
              adapter.generateMealPlan(_planRequest),
              throwsA(isA<AiHttpFailure>()
                  .having(
                      (e) => e.message, 'message', isNot(contains(_fakeKey)))
                  .having((e) => e.status, 'status', connection.status)));
          expect(requests, 2,
              reason: 'One probe and one generation; no retries.');
        });
      }

      test(
          'timeout and transport errors have useful redacted recovery messages',
          () async {
        for (final error in [
          TimeoutException(_fakeKey),
          http.ClientException('$_fakeKey private household'),
        ]) {
          final adapter =
              provider.create(MockClient((_) async => throw error), _fakeKey);
          final connection = await adapter.testConnection();
          expect(connection.status, TestConnectionStatus.networkError);
          expect(connection.errorMessage, isNot(contains(_fakeKey)));
          if (error is TimeoutException) {
            expect(connection.errorMessage, contains('timed out'));
          }
          await expectLater(
              adapter.generateMealPlan(_planRequest),
              throwsA(isA<AiHttpFailure>().having(
                  (e) => e.message, 'message', isNot(contains(_fakeKey)))));
        }
      });

      test('complete generation and replacement preserve requested meal data',
          () async {
        var requests = 0;
        final adapter = provider.create(MockClient((request) async {
          requests++;
          final body = jsonDecode(request.body) as Map;
          expect(body['messages'], isList);
          final output = requests == 1
              ? jsonEncode({
                  'meals': [_recipe()]
                })
              : jsonEncode(_recipe(title: 'Alternative rice'));
          return http.Response(provider.completion(output), 200);
        }), _fakeKey);
        final response = await adapter.generateMealPlan(_planRequest);
        expect(response.meals.single.title, 'Vegetable rice');
        expect(response.meals.single.ingredients.single.name, 'Rice');
        final replacement = await adapter.generateMealReplacement(
            AiMealReplacementRequest(
                currentMeal: Meal(
                    id: 'local-meal', title: 'Old dish', mealType: 'Dinner')));
        expect(replacement.title, 'Alternative rice');
        expect(requests, 2);
      });

      test('truncated but parseable recipe is rejected before parser salvage',
          () async {
        final output = jsonEncode({
          'meals': [_recipe()]
        });
        final body = provider.completion(output,
            finish: provider.anthropic ? 'max_tokens' : 'length');
        final adapter = provider.create(
            MockClient((_) async => http.Response(body, 200)), _fakeKey);
        await expectLater(
            adapter.generateMealPlan(_planRequest),
            throwsA(isA<AiHttpFailure>()
                .having((e) => e.message, 'message', contains('cut short'))));
      });
    });
  }

  test('OpenAI reasoning probe uses supported token field without temperature',
      () async {
    for (final model in ['gpt-6-luna', 'gpt-5.6', 'o3', 'gpt-4.1-mini']) {
      final adapter = OpenAiAdapter(
          apiKey: _fakeKey,
          model: model,
          client: MockClient((request) async {
            final body = jsonDecode(request.body) as Map;
            expect(body['max_completion_tokens'], isA<int>());
            expect(body.containsKey('max_tokens'), isFalse);
            expect(body.containsKey('temperature'), isFalse);
            if (model.startsWith('gpt-6') || model.startsWith('gpt-5.6')) {
              expect(body['reasoning_effort'], 'none');
            } else {
              expect(body.containsKey('reasoning_effort'), isFalse);
            }
            return http.Response(_chat('OK'), 200);
          }));
      expect((await adapter.testConnection()).isValid, isTrue);
    }
  });

  test('Claude combines text blocks after reasoning without losing recipe JSON',
      () async {
    final output = jsonEncode({
      'meals': [_recipe()]
    });
    final split = output.length ~/ 2;
    final adapter = AnthropicAdapter(
        apiKey: _fakeKey,
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'stop_reason': 'end_turn',
              'content': [
                {'type': 'thinking', 'thinking': 'private reasoning'},
                {'type': 'text', 'text': output.substring(0, split)},
                {'type': 'text', 'text': output.substring(split)},
              ]
            }),
            200)));
    expect((await adapter.generateMealPlan(_planRequest)).meals.single.title,
        'Vegetable rice');
  });

  test(
      'Groq large plan never restarts after auth, quota, or truncation failures',
      () async {
    for (final status in [401, 429, 200]) {
      var requests = 0;
      final adapter = GroqAdapter(
          apiKey: _fakeKey,
          client: MockClient((_) async {
            requests++;
            return http.Response(
                status == 200
                    ? _chat(
                        jsonEncode({
                          'meals': [_recipe()]
                        }),
                        finish: 'length')
                    : _fakeKey,
                status);
          }));
      await expectLater(adapter.generateMealPlan(_largePlanRequest),
          throwsA(isA<AiHttpFailure>()));
      expect(requests, 1);
    }
  });

  test(
      'Groq retries explicit JSON mode error once without accepting failed data',
      () async {
    var requests = 0;
    final adapter = GroqAdapter(
        apiKey: _fakeKey,
        client: MockClient((request) async {
          requests++;
          final body = jsonDecode(request.body) as Map;
          if (requests == 1) {
            expect(body['response_format'], {'type': 'json_object'});
            return http.Response(
                jsonEncode({
                  'error': {
                    'code': 'json_validate_failed',
                    'message': _fakeKey,
                    'failed_generation': jsonEncode({
                      'meals': [_recipe(title: 'Rejected data')]
                    }),
                  }
                }),
                400);
          }
          expect(body.containsKey('response_format'), isFalse);
          return http.Response(
              _chat(jsonEncode({
                'meals': [_recipe(title: 'Successful retry')]
              })),
              200);
        }));
    expect((await adapter.generateMealPlan(_planRequest)).meals.single.title,
        'Successful retry');
    expect(requests, 2);
  });

  test('Groq repeated JSON rejection stops after one retry with redacted error',
      () async {
    var requests = 0;
    final adapter = GroqAdapter(
        apiKey: _fakeKey,
        client: MockClient((_) async {
          requests++;
          return http.Response(
              jsonEncode({
                'error': {'code': 'json_validate_failed', 'message': _fakeKey}
              }),
              400);
        }));
    await expectLater(adapter.generateMealPlan(_planRequest), throwsException);
    expect(requests, 2);
  });

  test('Groq ordinary bad request never retries based on echoed message text',
      () async {
    var requests = 0;
    final adapter = GroqAdapter(
        apiKey: _fakeKey,
        client: MockClient((_) async {
          requests++;
          return http.Response(
              jsonEncode({
                'error': {
                  'message': '$_fakeKey failed_generation validate JSON',
                }
              }),
              400);
        }));
    await expectLater(
        adapter.generateMealPlan(_planRequest), throwsA(isA<AiHttpFailure>()));
    expect(requests, 1);
  });
}

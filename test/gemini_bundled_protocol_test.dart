import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whatmeal/core/services/ai/adapters/gemini_adapter.dart';
import 'package:whatmeal/core/services/ai/ai_models.dart';
import 'package:whatmeal/core/services/ai/generation_failure.dart';
import 'package:whatmeal/features/meal/models/meal.dart';

const _request = AiMealPlanRequest(
    familyMemberNames: ['Synthetic Adult'],
    numberOfDays: 1,
    mealTypes: ['Dinner']);
const _meal = {
  'title': 'Garlic rice',
  'mealType': 'Dinner',
  'dayIndex': 0,
  'ingredients': [
    {'name': 'Rice', 'amount': '1 cup'}
  ],
  'instructions': ['Cook rice.'],
};
String _completion(Object content, {String finishReason = 'STOP'}) =>
    jsonEncode({
      'candidates': [
        {
          'finishReason': finishReason,
          'content': {
            'parts': [
              {'text': jsonEncode(content)}
            ]
          },
        }
      ],
    });

void main() {
  test('configured default checks selected direct model without Firebase init',
      () async {
    var calls = 0;
    final adapter = GeminiAdapter(
        bundledKeys: ['synthetic-a'],
        model: 'gemini-3.5-flash',
        client: MockClient((request) async {
          calls++;
          expect(request.url.host, 'generativelanguage.googleapis.com');
          expect(
              request.url.path, '/v1beta/models/gemini-3.5-flash:countTokens');
          expect(request.url.query, isEmpty);
          expect(request.headers['x-goog-api-key'], 'synthetic-a');
          expect(request.headers.containsKey('X-Firebase-AppCheck'), isFalse);
          return http.Response('{"totalTokens":5}', 200);
        }));
    expect(adapter.usesFirebaseAi, isFalse);
    expect((await adapter.testConnection()).isValid, isTrue);
    expect(calls, 1);
  });

  test('empty explicit pool retains the legacy Firebase route', () {
    expect(GeminiAdapter(bundledKeys: const []).usesFirebaseAi, isTrue);
  });

  test('generation tries eligible credentials without changing selected model',
      () async {
    final attempted = <String>[];
    final adapter = GeminiAdapter(
        bundledKeys: ['synthetic-a', 'synthetic-b', 'synthetic-c'],
        model: 'gemini-3.5-flash',
        client: MockClient((request) async {
          expect(request.url.path,
              '/v1beta/models/gemini-3.5-flash:generateContent');
          expect(
              jsonDecode(request.body)['generationConfig']['responseMimeType'],
              'application/json');
          attempted.add(request.headers['x-goog-api-key']!);
          return switch (attempted.length) {
            1 => http.Response('{}', 401),
            2 => http.Response('{}', 403),
            _ => http.Response(
                _completion({
                  'meals': [_meal]
                }),
                200),
          };
        }));
    final response = await adapter.generateMealPlan(_request);
    _request.validateMeals(response.meals);
    expect(response.model, 'gemini-3.5-flash');
    expect(response.meals.single.title, 'Garlic rice');
    expect(attempted, ['synthetic-a', 'synthetic-b', 'synthetic-c']);
  });

  test('personal key wins over prototype pool', () async {
    var calls = 0;
    final adapter = GeminiAdapter(
        apiKey: ' personal-synthetic ',
        bundledKeys: ['synthetic-pool'],
        client: MockClient((request) async {
          calls++;
          expect(request.headers['x-goog-api-key'], 'personal-synthetic');
          return http.Response(
              _completion({
                'meals': [_meal]
              }),
              200);
        }));
    await adapter.generateMealPlan(_request);
    expect(calls, 1);
  });

  test('all failed keys return actual quota error instead of Firebase error',
      () async {
    var calls = 0;
    final adapter = GeminiAdapter(
        bundledKeys: ['synthetic-a', 'synthetic-b', 'synthetic-a'],
        client: MockClient((_) async {
          calls++;
          return http.Response('{"error":{"message":"private-response"}}', 429);
        }));
    final result = await adapter.testConnection();
    expect(result.isValid, isFalse);
    expect(result.status, TestConnectionStatus.rateLimited);
    expect(result.errorMessage, contains('quota or rate limit'));
    expect(result.errorMessage, isNot(contains('Firebase')));
    expect(result.errorMessage, isNot(contains('private-response')));
    expect(calls, 2);
  });

  for (final status in [400, 404, 500]) {
    test('HTTP $status stops without rotating credentials', () async {
      var calls = 0;
      final adapter = GeminiAdapter(
          bundledKeys: ['synthetic-a', 'synthetic-b'],
          client: MockClient((_) async {
            calls++;
            return http.Response('{}', status);
          }));
      final result = await adapter.testConnection();
      expect(result.isValid, isFalse);
      if (status == 404) {
        expect(result.status, TestConnectionStatus.invalidModel);
      }
      expect(calls, 1);
    });
  }

  test('network failure stops without duplicate credential attempts', () async {
    var calls = 0;
    final adapter = GeminiAdapter(
        bundledKeys: ['synthetic-a', 'synthetic-b'],
        client: MockClient((_) async {
          calls++;
          throw http.ClientException('private-network-response');
        }));
    final result = await adapter.testConnection();
    expect(result.status, TestConnectionStatus.networkError);
    expect(result.errorMessage, isNot(contains('private-network-response')));
    expect(calls, 1);
  });

  test('invalid token-count payload is not connection success or retried',
      () async {
    var calls = 0;
    final adapter = GeminiAdapter(
        bundledKeys: ['synthetic-a', 'synthetic-b'],
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }));
    expect((await adapter.testConnection()).isValid, isFalse);
    expect(calls, 1);
  });

  test('malformed generation response is not retried against another key',
      () async {
    var calls = 0;
    final adapter = GeminiAdapter(
        bundledKeys: ['synthetic-a', 'synthetic-b'],
        client: MockClient((_) async {
          calls++;
          return http.Response(
              _completion({
                'meals': [_meal]
              }, finishReason: 'MAX_TOKENS'),
              200);
        }));
    await expectLater(
        adapter.generateMealPlan(_request), throwsA(isA<GenerationFailure>()));
    expect(calls, 1);
  });

  test('replacement uses direct pool and preserves the requested model',
      () async {
    var calls = 0;
    final adapter = GeminiAdapter(
        bundledKeys: ['synthetic-a'],
        model: 'gemini-3.5-flash',
        client: MockClient((request) async {
          calls++;
          expect(request.url.path,
              '/v1beta/models/gemini-3.5-flash:generateContent');
          return http.Response(_completion(_meal), 200);
        }));
    final response = await adapter.generateMealReplacement(
        AiMealReplacementRequest(
            currentMeal: Meal(
                id: 'synthetic-meal', title: 'Old rice', mealType: 'Dinner')));
    response.validateRecipe();
    expect(response.title, 'Garlic rice');
    expect(calls, 1);
  });

  test('concurrent requests each try every distinct key at most once',
      () async {
    final calls = <String, int>{};
    final adapter = GeminiAdapter(
        bundledKeys: ['synthetic-a', 'synthetic-b', 'synthetic-c'],
        client: MockClient((request) async {
          final key = request.headers['x-goog-api-key']!;
          calls.update(key, (value) => value + 1, ifAbsent: () => 1);
          await Future<void>.delayed(Duration.zero);
          return http.Response('{}', 429);
        }));
    final results =
        await Future.wait([adapter.testConnection(), adapter.testConnection()]);
    expect(
        results.every(
            (result) => result.status == TestConnectionStatus.rateLimited),
        isTrue);
    expect(calls, {'synthetic-a': 2, 'synthetic-b': 2, 'synthetic-c': 2});
  });
}

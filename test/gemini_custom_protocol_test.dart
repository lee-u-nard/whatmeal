import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whatmeal/core/services/ai/adapters/gemini_adapter.dart';
import 'package:whatmeal/core/services/ai/adapters/custom_adapter.dart';
import 'package:whatmeal/core/services/ai/adapters/http_response_support.dart';
import 'package:whatmeal/core/services/ai/ai_models.dart';
import 'package:whatmeal/core/services/ai/generation_failure.dart';

const request = AiMealPlanRequest(
    familyMemberNames: ['Demo'], numberOfDays: 1, mealTypes: ['Dinner']);
const recipe =
    '{"meals":[{"title":"Rice","mealType":"Dinner","dayIndex":0,"ingredients":[{"name":"Rice","amount":"1 cup"}],"instructions":["Cook rice."]}]}';
String gemini(String text, {String reason = 'STOP'}) => jsonEncode({
      'candidates': [
        {
          'finishReason': reason,
          'content': {
            'parts': [
              {'text': text}
            ]
          }
        }
      ]
    });

void main() {
  test(
      'Gemini REST uses exact model and header credentials, never URL credentials',
      () async {
    final adapter = GeminiAdapter(
        apiKey: 'synthetic-only-key',
        model: 'gemini-3.8-flash',
        client: MockClient((r) async {
          expect(r.url.path, endsWith('/gemini-3.8-flash:generateContent'));
          expect(r.url.query, isEmpty);
          expect(r.headers['x-goog-api-key'], 'synthetic-only-key');
          final body = jsonDecode(r.body);
          expect(
              body['generationConfig']['responseMimeType'], 'application/json');
          return http.Response(gemini(recipe), 200);
        }));
    final response = await adapter.generateMealPlan(request);
    request.validateMeals(response.meals);
    expect(response.model, 'gemini-3.8-flash');
    expect(response.meals.single.title, 'Rice');
  });
  test('Gemini joins all text parts and excludes thought parts', () {
    final body = jsonEncode({
      'candidates': [
        {
          'finishReason': 'STOP',
          'content': {
            'parts': [
              {'text': 'private reasoning', 'thought': true},
              {'text': '{"meals":'},
              {'text': '[]}'}
            ]
          }
        }
      ]
    });
    expect(GeminiAdapter.restText(body), '{"meals":[]}');
  });
  for (final reason in ['MAX_TOKENS', 'SAFETY', 'RECITATION', 'OTHER']) {
    test('Gemini rejects $reason even with parsable meal JSON', () async {
      final adapter = GeminiAdapter(
          apiKey: 'synthetic',
          client: MockClient(
              (_) async => http.Response(gemini(recipe, reason: reason), 200)));
      await expectLater(
          adapter.generateMealPlan(request), throwsA(isA<GenerationFailure>()));
    });
  }
  test(
      'Gemini connection does not claim success for HTML, empty or blocked HTTP200',
      () async {
    for (final body in [
      '<html>secret</html>',
      '{}',
      gemini(''),
      '{"promptFeedback":{"blockReason":"SAFETY","blockReasonMessage":"secret"}}'
    ]) {
      final adapter = GeminiAdapter(
          apiKey: 'synthetic',
          client: MockClient((_) async => http.Response(body, 200)));
      final result = await adapter.testConnection();
      expect(result.isValid, isFalse);
      expect(result.errorMessage, isNot(contains('secret')));
    }
  });
  test('Firebase SDK response checks completion metadata before parsing', () {
    final stopped = GenerateContentResponse([
      Candidate(Content.model([TextPart(recipe)]), null, null,
          FinishReason.stop, null)
    ], null);
    expect(GeminiAdapter.firebaseText(stopped), recipe);
    final partial = GenerateContentResponse([
      Candidate(Content.model([TextPart(recipe)]), null, null,
          FinishReason.maxTokens, null)
    ], null);
    expect(() => GeminiAdapter.firebaseText(partial),
        throwsA(isA<GenerationFailure>()));
  });
  test(
      'Gemini catalogue filters capabilities, restricted and unknown IDs across pages',
      () async {
    var calls = 0;
    final adapter = GeminiAdapter(
        apiKey: 'synthetic',
        client: MockClient((r) async {
          expect(r.headers['x-goog-api-key'], 'synthetic');
          expect(r.url.queryParameters.containsKey('key'), isFalse);
          calls++;
          return http.Response(
              jsonEncode({
                'models': [
                  {
                    'name': 'models/gemini-3.8-flash',
                    'supportedGenerationMethods': ['generateContent']
                  },
                  {
                    'name': 'models/gemini-3.7-flash',
                    'supportedGenerationMethods': ['embedContent']
                  },
                  {
                    'name': 'models/gemini-3.1-pro-preview',
                    'supportedGenerationMethods': ['generateContent']
                  },
                  {
                    'name': 'models/unknown-text-model',
                    'supportedGenerationMethods': ['generateContent']
                  },
                ],
                if (calls == 1) 'nextPageToken': 'next-synthetic'
              }),
              200);
        }));
    expect(await adapter.fetchAvailableModels(), ['gemini-3.8-flash']);
    expect(calls, 2);
  });
  test('custom rejects incomplete completion and preserves rate limit category',
      () async {
    final adapter = CustomAdapter(
        endpoint: 'https://endpoint.test/v1',
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'choices': [
                {
                  'finish_reason': 'length',
                  'message': {'content': recipe}
                }
              ]
            }),
            200)));
    await expectLater(
        adapter.generateMealPlan(request), throwsA(isA<AiHttpFailure>()));
    final limited = CustomAdapter(
        endpoint: 'https://endpoint.test/v1',
        client: MockClient((_) async => http.Response('secret', 429)));
    expect((await limited.testConnection()).status,
        TestConnectionStatus.rateLimited);
  });
  test(
      'safe typed failures retain malformed, safety, quota and timeout categories',
      () {
    final cases = <AiHttpFailure, GenerationFailureKind>{
      const AiHttpFailure('AI response was cut short.'):
          GenerationFailureKind.malformed,
      const AiHttpFailure('AI declined this request.'):
          GenerationFailureKind.safety,
      const AiHttpFailure('AI quota', TestConnectionStatus.rateLimited):
          GenerationFailureKind.quota,
      const AiHttpFailure(
              'AI request timed out.', TestConnectionStatus.networkError):
          GenerationFailureKind.timeout,
    };
    for (final entry in cases.entries) {
      expect(GenerationFailure.from(entry.key).kind, entry.value);
    }
  });
  test('custom transport failure recovers on next explicit attempt', () async {
    var calls = 0;
    final adapter = CustomAdapter(
        endpoint: 'https://endpoint.test/v1',
        client: MockClient((_) async {
          if (++calls == 1) throw TimeoutException('synthetic secret');
          return http.Response(
              '{"choices":[{"finish_reason":"stop","message":{"content":"OK"}}]}',
              200);
        }));
    final failed = await adapter.testConnection();
    expect(failed.isValid, isFalse);
    expect(failed.errorMessage, isNot(contains('synthetic secret')));
    expect((await adapter.testConnection()).isValid, isTrue);
    expect(calls, 2);
  });
}

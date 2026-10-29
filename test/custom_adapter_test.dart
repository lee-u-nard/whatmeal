import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whatmeal/core/models/llm_config.dart';
import 'package:whatmeal/core/services/ai/adapters/custom_adapter.dart';
import 'package:whatmeal/core/services/ai/ai_json_parser.dart';
import 'package:whatmeal/core/services/llm_service.dart';

void main() {
  test('base URL preserves query and exact URL mode preserves path', () {
    expect(
        CustomAdapter(endpoint: 'https://example.test/v1/?tenant=a')
            .completionsUrl,
        'https://example.test/v1/chat/completions?tenant=a');
    expect(
        CustomAdapter(
                endpoint: 'https://example.test/exact',
                isOpenAiCompatible: false)
            .completionsUrl,
        'https://example.test/exact');
  });
  test('rejects embedded credentials and non-HTTP endpoints', () async {
    for (final endpoint in [
      'https://secret@example.test',
      'file:///tmp/api',
      'httpbroken://host'
    ]) {
      expect((await CustomAdapter(endpoint: endpoint).testConnection()).isValid,
          isFalse);
    }
  });
  test('test connection requires chat response and sends bearer header',
      () async {
    final adapter = CustomAdapter(
        endpoint: 'https://example.test/v1',
        apiKey: 'fake-test-key',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer fake-test-key');
          expect(jsonDecode(request.body)['messages'], isList);
          return http.Response(
              '{"choices":[{"finish_reason":"stop","message":{"content":"Hi"}}]}',
              200);
        }));
    expect((await adapter.testConnection()).isValid, isTrue);
    final malformed = CustomAdapter(
        endpoint: 'https://example.test',
        client: MockClient((_) async => http.Response('<html>OK</html>', 200)));
    expect((await malformed.testConnection()).isValid, isFalse);
  });
  test('HTTP and transport errors never echo response or credentials',
      () async {
    for (final status in [401, 403, 404, 429, 500]) {
      final adapter = CustomAdapter(
          endpoint: 'https://example.test',
          client:
              MockClient((_) async => http.Response('private-secret', status)));
      final result = await adapter.testConnection();
      expect(result.isValid, isFalse);
      expect(result.errorMessage, isNot(contains('private-secret')));
    }
    final adapter = CustomAdapter(
        endpoint: 'https://example.test',
        client: MockClient((_) async => throw Exception('private-secret')));
    expect((await adapter.testConnection()).errorMessage,
        isNot(contains('private-secret')));
  });
  test('parser and public provider exceptions omit arbitrary sensitive text',
      () {
    try {
      AiJsonParser.parseMealList('private-secret');
      fail('Expected parse failure');
    } catch (error) {
      expect(error.toString(), isNot(contains('private-secret')));
    }
    expect(
        AiProviderException(
                provider: LlmProvider.groq, cause: Exception('private-secret'))
            .toString(),
        isNot(contains('private-secret')));
  });
}

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:whatmeal/core/services/ai/adapters/http_response_support.dart';
import 'package:whatmeal/core/services/ai/ai_models.dart';
import 'package:whatmeal/core/services/ai/bundled_key_pool.dart';

void main() {
  test('Google HTTP 400 invalid credentials permit bounded credential failover',
      () {
    final failure = providerHttpFailure(
        http.Response(
            jsonEncode({
              'error': {
                'status': 'INVALID_ARGUMENT',
                'message': 'synthetic-private',
                'details': [
                  {'reason': 'API_KEY_INVALID'}
                ]
              }
            }),
            400),
        'Gemini');
    expect(failure.status, TestConnectionStatus.invalidKey);
    expect(BundledKeyPool.canTryNext(failure), isTrue);
    expect(failure.toString(), isNot(contains('synthetic-private')));
  });
  test('ordinary bad requests do not rotate through configured credentials',
      () {
    final failure = providerHttpFailure(
        http.Response(
            '{"error":{"status":"INVALID_ARGUMENT","message":"bad payload"}}',
            400),
        'Gemini');
    expect(BundledKeyPool.canTryNext(failure), isFalse);
  });
}

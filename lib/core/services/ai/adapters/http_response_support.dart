import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../ai_models.dart';

/// Controlled public errors never include a provider body, URL, or transport
/// exception: any of those may echo credentials or household prompt contents.
class AiHttpFailure implements Exception {
  const AiHttpFailure(this.message,
      [this.status = TestConnectionStatus.providerUnavailable]);

  final String message;
  final TestConnectionStatus status;

  TestConnectionResult toConnectionResult() => TestConnectionResult.failure(
        status: status,
        message: message,
      );

  @override
  String toString() => message;
}

/// An injected client stays owned by its caller. Normal requests use a client
/// per call, including closing it after timeouts instead of leaving it running.
class AiHttpTransport {
  const AiHttpTransport(this.provider, {http.Client? client})
      : _client = client;

  final String provider;
  final http.Client? _client;

  Future<http.Response> post(Uri uri,
          {required Map<String, String> headers,
          required String body,
          required Duration timeout}) =>
      _send(
          (client) => client.post(uri, headers: headers, body: body), timeout);

  Future<http.Response> get(Uri uri,
          {required Map<String, String> headers, required Duration timeout}) =>
      _send((client) => client.get(uri, headers: headers), timeout);

  Future<http.Response> _send(Future<http.Response> Function(http.Client) send,
      Duration timeout) async {
    final client = _client ?? http.Client();
    try {
      return await send(client).timeout(timeout);
    } on TimeoutException {
      throw AiHttpFailure('$provider request timed out. Please retry.',
          TestConnectionStatus.networkError);
    } catch (_) {
      throw AiHttpFailure(
          'Could not connect to $provider. Check your network connection.',
          TestConnectionStatus.networkError);
    } finally {
      if (_client == null) client.close();
    }
  }
}

Map<String, dynamic> decodeProviderObject(String body, String provider) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {
    // JSON errors can include the raw provider response. Never expose them.
  }
  throw AiHttpFailure('$provider returned an invalid response. Please retry.');
}

/// Both OpenAI and Groq use this completion envelope. A successful HTTP status
/// is insufficient: truncated, refused, tool-only, or unfinished output is not a
/// usable completion even if the permissive recipe parser could salvage it.
String completedChatText(String body, String provider) {
  final decoded = decodeProviderObject(body, provider);
  final choices = decoded['choices'];
  if (choices is! List || choices.isEmpty || choices.first is! Map) {
    throw AiHttpFailure('$provider returned no completion. Please retry.');
  }
  final choice = choices.first as Map;
  final message = choice['message'];
  if (message is! Map) {
    throw AiHttpFailure(
        '$provider returned an invalid completion. Please retry.');
  }
  final refusal = message['refusal'];
  if (refusal != null && refusal != '') {
    throw AiHttpFailure(
        '$provider declined this request. Review the request and try again.');
  }
  if (choice['finish_reason'] == 'length') {
    throw AiHttpFailure(
        '$provider response was cut short. Try fewer meals or another model.');
  }
  if (choice['finish_reason'] != 'stop') {
    throw AiHttpFailure(
        '$provider did not finish a text response. Please retry.');
  }
  final text = message['content'];
  if (text is! String || text.trim().isEmpty) {
    throw AiHttpFailure('$provider returned an empty response. Please retry.');
  }
  return text;
}

AiHttpFailure providerHttpFailure(http.Response response, String provider) {
  final status = response.statusCode;
  if (provider == 'Gemini' &&
      status == 400 &&
      _isInvalidGoogleKey(response.body)) {
    return const AiHttpFailure(
        'Invalid Gemini API key. Check the configured credential.',
        TestConnectionStatus.invalidKey);
  }
  if (status == 401) {
    return AiHttpFailure('Invalid $provider API key. Check AI Settings.',
        TestConnectionStatus.invalidKey);
  }
  if (status == 403) {
    return AiHttpFailure(
        '$provider denied access. Check your key permissions and model access.',
        TestConnectionStatus.permissionDenied);
  }
  if (status == 404 || (status == 400 && _isModelError(response.body))) {
    return AiHttpFailure(
        '$provider model is unavailable. Check your model selection.',
        TestConnectionStatus.invalidModel);
  }
  if (status == 429) {
    return AiHttpFailure(
        '$provider quota or rate limit exceeded. Check your provider account or wait before retrying.',
        TestConnectionStatus.rateLimited);
  }
  if (status == 400) {
    return AiHttpFailure(
        '$provider rejected the request. Check model and protocol compatibility.');
  }
  return AiHttpFailure(
      '$provider is unavailable (HTTP $status). Please try again later.');
}

bool _isInvalidGoogleKey(String body) {
  try {
    final data = jsonDecode(body);
    if (data is! Map || data['error'] is! Map) return false;
    final details = (data['error'] as Map)['details'];
    return details is List &&
        details.whereType<Map>().any((detail) =>
            detail['reason'] == 'API_KEY_INVALID' ||
            detail['reason'] == 'API_KEY_EXPIRED');
  } catch (_) {
    return false;
  }
}

bool _isModelError(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['error'] is! Map) return false;
    final error = decoded['error'] as Map;
    final code = error['code'] ?? error['type'];
    return const {
      'model_not_found',
      'model_not_supported',
      'invalid_model',
      'model_decommissioned',
    }.contains(code);
  } catch (_) {
    return false;
  }
}

import 'package:flutter/foundation.dart';

/// Safe diagnostic logger for AI provider operations.
/// NEVER logs API keys, bearer tokens, or sensitive user secrets.
class AiLogger {
  AiLogger._();

  /// Logs an outgoing AI provider request with sanitized metadata.
  static void logRequest({
    required String provider,
    required String endpoint,
    required String model,
  }) {
    final sanitizedEndpoint = _sanitizeUrl(endpoint);
    debugPrint(
        '[AI][$provider] -> Outgoing request | Model: $model | Endpoint: $sanitizedEndpoint');
  }

  /// Logs an incoming AI provider response with status and duration.
  static void logResponse({
    required String provider,
    required String model,
    required int statusCode,
    int? elapsedMs,
  }) {
    final elapsedStr = elapsedMs != null ? ' in ${elapsedMs}ms' : '';
    debugPrint(
        '[AI][$provider] <- Response HTTP $statusCode$elapsedStr | Model: $model');
  }

  /// Logs an AI provider error safely, stripping any potential keys or sensitive tokens.
  static void logError({
    required String provider,
    required String model,
    required Object error,
    int? statusCode,
  }) {
    final cleanMsg = sanitize(error.toString());
    final statusStr = statusCode != null ? ' (HTTP $statusCode)' : '';
    debugPrint('[AI][$provider][ERROR] Model: $model$statusStr | $cleanMsg');
  }

  /// Redacts potential API keys, Bearer tokens, and secrets from text.
  static String sanitize(String text) {
    var sanitized = text;
    // Redact Bearer tokens
    sanitized = sanitized.replaceAll(
        RegExp(r'Bearer\s+[A-Za-z0-9_\-\.]{8,}', caseSensitive: false),
        'Bearer [REDACTED]');
    // Redact query parameter keys (e.g. ?key=AIzaSy... or &key=...)
    sanitized = sanitized.replaceAll(
        RegExp(r'(key|api_key|apiKey)=[A-Za-z0-9_\-\.]{8,}',
            caseSensitive: false),
        r'$1=[REDACTED]');
    // Redact Groq keys (gsk_...)
    sanitized = sanitized.replaceAll(
        RegExp(r'gsk_[A-Za-z0-9_]{10,}'), 'gsk_[REDACTED]');
    // Redact OpenAI keys (sk-...)
    sanitized = sanitized.replaceAll(
        RegExp(r'sk-[A-Za-z0-9_\-]{10,}'), 'sk-[REDACTED]');
    // Redact Anthropic keys (sk-ant-...)
    sanitized = sanitized.replaceAll(
        RegExp(r'sk-ant-[A-Za-z0-9_\-]{10,}'), 'sk-ant-[REDACTED]');
    // Redact Gemini AIza keys
    sanitized = sanitized.replaceAll(
        RegExp(r'AIza[0-9A-Za-z-_]{30,}'), 'AIza[REDACTED]');
    return sanitized;
  }

  static String _sanitizeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.queryParameters.isEmpty) return url;
      final cleanParams = <String, String>{};
      uri.queryParameters.forEach((k, v) {
        if (k.toLowerCase().contains('key') ||
            k.toLowerCase().contains('token') ||
            k.toLowerCase().contains('secret')) {
          cleanParams[k] = '[REDACTED]';
        } else {
          cleanParams[k] = v;
        }
      });
      return uri.replace(queryParameters: cleanParams).toString();
    } catch (_) {
      return sanitize(url);
    }
  }
}

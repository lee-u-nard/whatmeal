import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_ai/firebase_ai.dart'
    show FirebaseAIException, InvalidApiKey;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'adapters/http_response_support.dart';
import 'ai_models.dart';
import 'app_check_diagnostic.dart';

enum GenerationFailureKind {
  localOnly,
  network,
  dns,
  unavailable,
  timeout,
  configuration,
  invalidModel,
  quota,
  authentication,
  permission,
  appCheck,
  firebase,
  malformed,
  safety,
  validation,
  unknown,
}

/// Only fixed, non-sensitive messages may cross the provider/UI boundary.
class GenerationFailure implements Exception {
  const GenerationFailure(this.kind)
      : _firebaseDiagnostic = null,
        _appCheckHint = null,
        cause = null;
  const GenerationFailure._firebase(
      this.kind, this._firebaseDiagnostic, this._appCheckHint)
      : cause = null;
  const GenerationFailure._caused(
      this.kind, this._firebaseDiagnostic, this.cause, this._appCheckHint);
  final GenerationFailureKind kind;
  final String? _firebaseDiagnostic;
  final String? _appCheckHint;

  /// Debugger-only original error. Never serialize or log this value: native
  /// provider messages may contain credentials. [toString] remains sanitized.
  final Object? cause;

  static GenerationFailure from(Object error) {
    if (error is GenerationFailure) return error;
    if (error is AiSetupFailure) return error.failure;
    final failure = _classify(error);
    return GenerationFailure._caused(failure.kind, failure._firebaseDiagnostic,
        error, failure._appCheckHint);
  }

  static GenerationFailure _classify(Object error) {
    if (error is AiHttpFailure) {
      final message = error.message.toLowerCase();
      return GenerationFailure(switch (error.status) {
        TestConnectionStatus.failed => GenerationFailureKind.unknown,
        TestConnectionStatus.invalidModel => GenerationFailureKind.invalidModel,
        TestConnectionStatus.invalidKey ||
        TestConnectionStatus.invalidEndpoint ||
        TestConnectionStatus.configurationError =>
          GenerationFailureKind.configuration,
        TestConnectionStatus.authenticationRequired =>
          GenerationFailureKind.authentication,
        TestConnectionStatus.permissionDenied =>
          GenerationFailureKind.permission,
        TestConnectionStatus.rateLimited => GenerationFailureKind.quota,
        TestConnectionStatus.networkError => message.contains('timed out')
            ? GenerationFailureKind.timeout
            : GenerationFailureKind.network,
        _ => message.contains('declined')
            ? GenerationFailureKind.safety
            : message.contains('denied access') ||
                    message.contains('rejected the request')
                ? GenerationFailureKind.configuration
                : message.contains('invalid') ||
                        message.contains('no completion') ||
                        message.contains('cut short') ||
                        message.contains('did not finish') ||
                        message.contains('empty response')
                    ? GenerationFailureKind.malformed
                    : GenerationFailureKind.unavailable,
      });
    }
    if (error is TimeoutException) {
      return const GenerationFailure(GenerationFailureKind.timeout);
    }
    if (error is FirebaseAIException) {
      if (error is InvalidApiKey) {
        return const GenerationFailure(GenerationFailureKind.configuration);
      }
      final message = error.message.toLowerCase();
      final firebaseAiKind = _firebaseMessageKind(message);
      if (firebaseAiKind != null) {
        return GenerationFailure(firebaseAiKind);
      }
    }
    if (error is FirebaseException) {
      // The pinned Android plugin labels every native App Check exception
      // "unknown". Its plugin identifies the failing stage, not the cause.
      if (error.plugin == 'firebase_app_check' || error.plugin == 'app-check') {
        final details = AppCheckDiagnostic.fromMessage(error.message);
        return GenerationFailure._firebase(GenerationFailureKind.appCheck,
            '${_firebaseDiagnosticFor(error)}${details.suffix}', details.hint);
      }
      final messageKind =
          _firebaseMessageKind(error.message?.toLowerCase() ?? '');
      if (messageKind == GenerationFailureKind.configuration) {
        return GenerationFailure(messageKind!);
      }
      final codeKind = switch (error.code) {
        'network-request-failed' => GenerationFailureKind.network,
        'invalid-user-token' ||
        'user-disabled' ||
        'requires-recent-login' =>
          GenerationFailureKind.authentication,
        'no-app' ||
        'not-initialized' ||
        'invalid-api-key' =>
          GenerationFailureKind.configuration,
        'permission-denied' => GenerationFailureKind.permission,
        'unauthenticated' ||
        'user-token-expired' =>
          GenerationFailureKind.authentication,
        'resource-exhausted' => GenerationFailureKind.quota,
        'deadline-exceeded' => GenerationFailureKind.timeout,
        _ => null,
      };
      if (codeKind != null) return GenerationFailure(codeKind);
      return GenerationFailure(messageKind ?? GenerationFailureKind.firebase);
    }
    // SDKs use different exception classes across mobile/web. Inspect internally
    // without logging/returning exception text (which can contain URLs or keys).
    final text = error.toString().toLowerCase();
    if (text.contains('failed host lookup') ||
        text.contains('name resolution')) {
      return const GenerationFailure(GenerationFailureKind.dns);
    }
    if (error is http.ClientException || text.contains('socketexception')) {
      return const GenerationFailure(GenerationFailureKind.network);
    }
    if (text.contains('429') ||
        text.contains('rate limit') ||
        text.contains('quota')) {
      return const GenerationFailure(GenerationFailureKind.quota);
    }
    if (text.contains('safety') || text.contains('blocked')) {
      return const GenerationFailure(GenerationFailureKind.safety);
    }
    if (text.contains('model_not_found') ||
        text.contains('model not found') ||
        text.contains('model_not_supported') ||
        text.contains('model not supported') ||
        text.contains('invalid_model') ||
        text.contains('invalid model') ||
        text.contains('model is unavailable') ||
        text.contains('unknown model') ||
        (text.contains('model') && text.contains('not found'))) {
      return const GenerationFailure(GenerationFailureKind.invalidModel);
    }
    if (text.contains('api key') ||
        text.contains('app check') ||
        text.contains('app-check') ||
        text.contains('permission_denied') ||
        text.contains('403') ||
        text.contains('401') ||
        text.contains('deactivated') ||
        text.contains('404')) {
      return const GenerationFailure(GenerationFailureKind.configuration);
    }
    if (error is FormatException ||
        text.contains('empty response') ||
        text.contains('no candidates')) {
      return const GenerationFailure(GenerationFailureKind.malformed);
    }
    if (error is ArgumentError || error is StateError) {
      return const GenerationFailure(GenerationFailureKind.validation);
    }
    if (text.contains('503') || text.contains('502') || text.contains('500')) {
      return const GenerationFailure(GenerationFailureKind.unavailable);
    }
    return const GenerationFailure(GenerationFailureKind.unknown);
  }

  /// SDK token failures must not be presented as a failed plan save. Never
  /// expose raw exception messages or arbitrary plugin/code strings.
  static String connectionCheckMessage(Object error) {
    final failure = from(error);
    if (failure.kind == GenerationFailureKind.appCheck) {
      return 'Gemini connection check failed. $failure';
    }
    final message = failure.kind == GenerationFailureKind.firebase
        ? 'Firebase could not complete the Gemini connection check. '
            'Check Firebase AI Logic, App Check, and sign-in, then retry.'
        : failure.toString();
    if (error is! FirebaseException) return message;
    return '$message Diagnostic: ${_firebaseDiagnosticFor(error)}.';
  }

  static String _firebaseDiagnosticFor(FirebaseException error) {
    const plugins = {
      'firebase_app_check',
      'app-check',
      'firebase_auth',
      'firebase_core',
      'core',
      'cloud_firestore',
      'firebase_ai',
      'firebase_vertexai'
    };
    const codes = {
      'unknown',
      'internal',
      'network-request-failed',
      'unavailable',
      'permission-denied',
      'unauthenticated',
      'user-token-expired',
      'invalid-user-token',
      'user-disabled',
      'requires-recent-login',
      'resource-exhausted',
      'too-many-requests',
      'deadline-exceeded',
      'no-app',
      'not-initialized',
      'invalid-api-key',
      'channel-error'
    };
    final plugin = plugins.contains(error.plugin) ? error.plugin : 'firebase';
    final code = codes.contains(error.code) ? error.code : 'other';
    return '$plugin/$code';
  }

  static GenerationFailureKind? _firebaseMessageKind(String text) {
    if ((text.contains('app check') ||
            text.contains('app-check') ||
            text.contains('appcheck')) &&
        (text.contains('token') || text.contains('attestation'))) {
      return GenerationFailureKind.appCheck;
    }
    if (text.contains('model_not_found') ||
        text.contains('model not found') ||
        text.contains('model_not_supported') ||
        text.contains('model not supported') ||
        text.contains('invalid_model') ||
        text.contains('invalid model') ||
        text.contains('model is unavailable') ||
        text.contains('unknown model') ||
        (text.contains('model') && text.contains('not found'))) {
      return GenerationFailureKind.invalidModel;
    }
    if (text.contains('quota') ||
        text.contains('resource_exhausted') ||
        text.contains('rate limit')) {
      return GenerationFailureKind.quota;
    }
    if (text.contains('service_disabled') ||
        text.contains('api_key_service_blocked') ||
        text.contains('service api is not enabled') ||
        text.contains('service api not enabled')) {
      return GenerationFailureKind.configuration;
    }
    if (text.contains('permission_denied') ||
        text.contains('permission denied')) {
      return GenerationFailureKind.permission;
    }
    if (text.contains('firebase ai logic api') ||
        text.contains('vertex ai in firebase api') ||
        text.contains('app check') ||
        text.contains('app-check') ||
        text.contains('appcheck') ||
        text.contains('api key') ||
        text.contains('api_key_invalid') ||
        text.contains('unsupported user location') ||
        text.contains('user location is not supported')) {
      return GenerationFailureKind.configuration;
    }
    if (text.contains('unavailable') ||
        text.contains('service unavailable') ||
        text.contains('http 503') ||
        text.contains('http 502') ||
        text.contains('http 500')) {
      return GenerationFailureKind.unavailable;
    }
    return null;
  }

  @override
  String toString() => switch (kind) {
        GenerationFailureKind.localOnly =>
          'Live AI is disabled in the isolated local tester. Use manual planning; a separate test environment needs approval.',
        GenerationFailureKind.network =>
          'The AI connection failed. Check your network and retry.',
        GenerationFailureKind.dns =>
          'The AI server address could not be resolved. Check DNS or retry later.',
        GenerationFailureKind.unavailable =>
          'The AI provider is temporarily unavailable. Retry later.',
        GenerationFailureKind.timeout =>
          'The AI provider timed out. Please retry.',
        GenerationFailureKind.configuration =>
          'The selected AI configuration was rejected. Check provider credentials, model and endpoint. When using Firebase AI Logic, also check the Firebase app and App Check configuration.',
        GenerationFailureKind.invalidModel =>
          'The selected AI model is not available for this provider or project. Choose a supported model and retry.',
        GenerationFailureKind.quota =>
          'The provider quota or rate limit was reached. Retry later.',
        GenerationFailureKind.authentication =>
          'Your Firebase session needs refreshing. Sign in again.',
        GenerationFailureKind.permission =>
          'Access to Firebase or the AI provider was denied. Check account permissions and App Check configuration.',
        GenerationFailureKind.appCheck =>
          '${_appCheckHint ?? AppCheckDiagnostic.defaultHint(isWeb: kIsWeb)}${_firebaseDiagnostic == null ? '' : ' Diagnostic: $_firebaseDiagnostic.'}',
        GenerationFailureKind.firebase =>
          'A Firebase service request failed. Check your connection and project configuration, then retry.',
        GenerationFailureKind.malformed =>
          'The AI response was incomplete or invalid. Please retry.',
        GenerationFailureKind.safety =>
          'The AI provider declined this request under its content policy. Adjust the request and retry.',
        GenerationFailureKind.validation =>
          'The request or generated meals did not pass validation. Review the selected members, preferences, and restrictions.',
        GenerationFailureKind.unknown =>
          'Meal generation could not complete. Please retry; the cause could not be identified.',
      };
}

enum AiSetupStep { settings, quota }

/// Firebase data access before dispatch is not an AI response or save failure.
class AiSetupFailure implements Exception {
  const AiSetupFailure(this.step, this.failure);
  final AiSetupStep step;
  final GenerationFailure failure;

  @override
  String toString() {
    final action = step == AiSetupStep.settings
        ? 'load saved AI settings'
        : 'reserve a free Gemini request';
    final reason = switch (failure.kind) {
      GenerationFailureKind.appCheck => failure.toString(),
      GenerationFailureKind.permission ||
      GenerationFailureKind.configuration =>
        'Firebase denied access. Check Firestore permissions and App Check.',
      GenerationFailureKind.authentication => 'Sign in again and retry.',
      GenerationFailureKind.quota =>
        'Firebase data quota is exhausted; this is separate from Gemini provider quota.',
      _ => 'Check your connection and Firebase project access, then retry.',
    };
    final dispatch = step == AiSetupStep.settings
        ? 'No AI generation request was sent.'
        : 'No built-in Gemini request was sent.';
    return 'Could not $action. $reason $dispatch';
  }
}

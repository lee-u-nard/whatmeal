import 'dart:async';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:whatmeal/core/services/ai/adapters/gemini_adapter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:whatmeal/core/services/ai/generation_failure.dart';

void main() {
  test('original exception remains available without leaking into feedback',
      () {
    final original = FirebaseException(
        plugin: 'firebase_app_check',
        code: 'unknown',
        message: 'synthetic-private-error-body');
    final failure = GenerationFailure.from(original);
    expect(failure.cause, same(original));
    expect(failure.toString(), contains('firebase_app_check/unknown'));
    expect(failure.toString(), isNot(contains('synthetic-private-error-body')));
    expect(GenerationFailure.from(failure), same(failure));
    expect(GenerationFailure.from(AiSetupFailure(AiSetupStep.quota, failure)),
        same(failure));
  });

  test('provider exception remains available without printing its response',
      () {
    final original = FirebaseAIException('RESOURCE_EXHAUSTED synthetic-secret');
    final failure = GenerationFailure.from(original);
    expect(failure.kind, GenerationFailureKind.quota);
    expect(failure.cause, same(original));
    expect(failure.toString(), isNot(contains('synthetic-secret')));
  });
  test(
      'Firebase token dependency diagnostics are safe and do not claim a save failed',
      () {
    final error = FirebaseException(
        plugin: 'firebase_app_check',
        code: 'unknown',
        message: 'private-key-or-token-value');
    expect(GenerationFailure.from(error).kind, GenerationFailureKind.appCheck);
    expect(GenerationFailure.from(error).toString(),
        contains('firebase_app_check/unknown'));
    final message = GenerationFailure.connectionCheckMessage(error);
    expect(message, contains('Gemini connection check'));
    expect(message, contains('firebase_app_check/unknown'));
    expect(message, isNot(contains('private-key-or-token-value')));
    expect(message, isNot(contains('saved')));
    final untrusted = GenerationFailure.connectionCheckMessage(
        FirebaseException(
            plugin: 'private-plugin-value',
            code: 'private-code-value',
            message: 'private-body-value'));
    expect(untrusted, contains('firebase/other'));
    expect(untrusted, isNot(contains('private-')));
  });

  test(
      'recognized initialization and auth token failures keep correct categories',
      () {
    expect(
        GenerationFailure.from(FirebaseException(
                plugin: 'firebase_auth', code: 'network-request-failed'))
            .kind,
        GenerationFailureKind.network);
    expect(
        GenerationFailure.from(FirebaseException(
                plugin: 'firebase_auth', code: 'invalid-user-token'))
            .kind,
        GenerationFailureKind.authentication);
    expect(
        GenerationFailure.from(
                FirebaseException(plugin: 'core', code: 'no-app'))
            .kind,
        GenerationFailureKind.configuration);
  });
  test('legacy Gemini never inherits another account credential', () {
    expect(GeminiAdapter(bundledKeys: const []).usesFirebaseAi, isTrue);
    expect(GeminiAdapter(apiKey: 'account-a-key').usesFirebaseAi, isFalse);
    expect(GeminiAdapter(apiKey: ' ', bundledKeys: const []).usesFirebaseAi,
        isTrue);
    expect(GeminiAdapter(bundledKeys: const []).usesFirebaseAi, isTrue);
  });
  test('provider failures retain distinct safe categories', () {
    final cases = <Object, GenerationFailureKind>{
      TimeoutException('secret'): GenerationFailureKind.timeout,
      http.ClientException('failed host lookup secret'):
          GenerationFailureKind.dns,
      http.ClientException('secret'): GenerationFailureKind.network,
      Exception('HTTP 401 secret'): GenerationFailureKind.configuration,
      Exception('HTTP 429 secret'): GenerationFailureKind.quota,
      Exception('HTTP 503 secret'): GenerationFailureKind.unavailable,
      FirebaseAIException(
              '404 NOT_FOUND: models/gemini-3.8-flash was not found'):
          GenerationFailureKind.invalidModel,
      FirebaseException(
          plugin: 'firestore',
          code: 'permission-denied',
          message: 'secret'): GenerationFailureKind.permission,
      FirebaseException(plugin: 'firestore', code: 'unauthenticated'):
          GenerationFailureKind.authentication,
      FirebaseException(plugin: 'firestore', code: 'unavailable'):
          GenerationFailureKind.firebase,
      const FormatException('secret'): GenerationFailureKind.malformed,
      Exception('safety blocked secret'): GenerationFailureKind.safety,
      ArgumentError('secret'): GenerationFailureKind.validation,
      Exception('secret'): GenerationFailureKind.unknown,
    };
    for (final entry in cases.entries) {
      final failure = GenerationFailure.from(entry.key);
      expect(failure.kind, entry.value);
      expect(failure.toString(), isNot(contains('secret')));
    }
  });
  test('Firebase AI service configuration errors are actionable and safe', () {
    final cases = <Object>[
      InvalidApiKey('synthetic private key details'),
      FirebaseAIException(
          'PERMISSION_DENIED: SERVICE_DISABLED for firebase AI logic API'),
      FirebaseAIException(
          'The Vertex AI in Firebase API is not enabled for this project'),
      FirebaseAIException(
          'API_KEY_SERVICE_BLOCKED because App Check is not configured'),
    ];
    for (final error in cases) {
      final failure = GenerationFailure.from(error);
      expect(failure.kind, GenerationFailureKind.configuration);
      expect(failure.toString(), contains('Firebase AI Logic'));
      expect(failure.toString(), contains('App Check'));
      expect(failure.toString(), isNot(contains('synthetic')));
    }
  });

  test('Firebase AI quota and service availability remain distinguishable', () {
    expect(
      GenerationFailure.from(FirebaseAIException('RESOURCE_EXHAUSTED quota'))
          .kind,
      GenerationFailureKind.quota,
    );
    expect(
      GenerationFailure.from(FirebaseAIException('503 service unavailable'))
          .kind,
      GenerationFailureKind.unavailable,
    );
  });

  test('unsupported Gemini model is not classified as provider outage', () {
    final failure = GenerationFailure.from(FirebaseAIException(
        'MODEL_NOT_FOUND: the selected model is not supported'));
    expect(failure.kind, GenerationFailureKind.invalidModel);
    expect(failure.toString(), contains('selected AI model'));
    expect(failure.toString(), isNot(contains('MODEL_NOT_FOUND')));
  });

  test('Firebase AI permission denial remains distinguishable', () {
    final failure = GenerationFailure.from(
        FirebaseAIException('PERMISSION_DENIED: App Check token rejected'));
    expect(failure.kind, GenerationFailureKind.appCheck);
    expect(failure.toString(), contains('verification token'));
  });

  test('native App Check errors never imply Gemini quota or sign-in failures',
      () {
    for (final code in ['unknown', 'resource-exhausted', 'unauthenticated']) {
      final error = FirebaseException(
          plugin: 'firebase_app_check',
          code: code,
          message: 'quota api key token synthetic-private-details');
      final failure = GenerationFailure.from(error);
      expect(failure.kind, GenerationFailureKind.appCheck);
      expect(failure.toString(), contains('verification token'));
      expect(failure.toString(), isNot(contains('synthetic-private-details')));
      expect(failure.toString(), isNot(contains('Sign in again')));
    }
  });

  test('pre-generation App Check failure keeps setup and save stages separate',
      () {
    final failure = GenerationFailure.from(FirebaseException(
        plugin: 'firebase_app_check', code: 'unknown', message: 'private'));
    final setup = AiSetupFailure(AiSetupStep.quota, failure).toString();
    expect(setup, contains('verification token'));
    expect(setup, contains('No built-in Gemini request was sent'));
    expect(setup, isNot(contains('quota is exhausted')));
  });
}

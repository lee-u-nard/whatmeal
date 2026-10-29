import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/services/ai/app_check_diagnostic.dart';
import 'package:whatmeal/core/services/ai/generation_failure.dart';

void main() {
  test(
      'web App Check feedback does not blame Android signing or Play Integrity',
      () {
    final web = AppCheckDiagnostic.defaultHint(isWeb: true);
    expect(web, contains('reCAPTCHA'));
    expect(web, isNot(contains('Play Integrity')));
    expect(web, isNot(contains('signing certificate')));
    expect(AppCheckDiagnostic.defaultHint(isWeb: false),
        contains('Play Integrity'));
  });
  test('native HTTP status and attestation reason expose no response body', () {
    const raw =
        'com.google.firebase.FirebaseException: Error returned from API. '
        'code: 403 body: App attestation failed. private-token https://private/?key=secret';
    final detail = AppCheckDiagnostic.fromMessage(raw);
    expect(detail.httpStatus, 403);
    expect(detail.reason, 'APP_ATTESTATION_FAILED');
    final failure = GenerationFailure.from(FirebaseException(
        plugin: 'firebase_app_check', code: 'unknown', message: raw));
    final feedback = GenerationFailure.connectionCheckMessage(failure.cause!);
    expect(failure.kind, GenerationFailureKind.appCheck);
    for (final text in [feedback, failure.toString()]) {
      expect(text, contains('HTTP 403'));
      expect(text, contains('APP_ATTESTATION_FAILED'));
      expect(text, isNot(contains('private-token')));
      expect(text, isNot(contains('https://private')));
      expect(text, isNot(contains('key=secret')));
    }
  });

  test('SDK backoff does not invent a fresh HTTP status or Gemini quota', () {
    final detail = AppCheckDiagnostic.fromMessage('Too many attempts.');
    expect(detail.httpStatus, isNull);
    expect(detail.reason, 'APP_CHECK_BACKOFF');
    final error = FirebaseException(
        plugin: 'firebase_app_check',
        code: 'unknown',
        message: 'java.lang.Exception: Too many attempts.');
    final failure = GenerationFailure.from(error);
    expect(failure.kind, GenerationFailureKind.appCheck);
    expect(failure.toString(), contains('Wait before retrying'));
    expect(failure.toString(), contains('Do not clear app data'));
    expect(failure.toString(), isNot(contains('HTTP')));
  });

  test('blocked App Check service is distinct from a personal Gemini key', () {
    for (final text in [
      'API_KEY_SERVICE_BLOCKED private-response',
      'Requests to this API firebaseappcheck.googleapis.com method '
          'google.firebase.appcheck.v1.TokenExchangeService.ExchangePlayIntegrityToken are blocked.',
    ]) {
      final detail = AppCheckDiagnostic.fromMessage(text);
      expect(detail.reason, 'API_KEY_SERVICE_BLOCKED');
      expect(detail.hint, contains('Firebase client API key restrictions'));
      expect(detail.hint, isNot(contains('private-response')));
    }
    final invalid = AppCheckDiagnostic.fromMessage('API key not valid. secret');
    expect(invalid.reason, 'API_KEY_INVALID');
    expect(invalid.hint, contains('personal Gemini key is not the fix'));
  });

  test('classic Play Integrity codes keep their documented meanings', () {
    const cases = {
      -3: 'PLAY_INTEGRITY_NETWORK_ERROR',
      -4: 'PLAY_STORE_ACCOUNT_NOT_FOUND',
      -6: 'PLAY_SERVICES_NOT_FOUND',
      -8: 'PLAY_INTEGRITY_TOO_MANY_REQUESTS',
      -14: 'PLAY_STORE_VERSION_OUTDATED',
      -15: 'PLAY_SERVICES_VERSION_OUTDATED',
      -16: 'CLOUD_PROJECT_NUMBER_IS_INVALID',
      -17: 'PLAY_INTEGRITY_CLIENT_TRANSIENT_ERROR',
    };
    for (final item in cases.entries) {
      for (final text in [
        'IntegrityServiceException: ${item.key}: secret-body',
        'Integrity API error (${item.key}): secret-body',
      ]) {
        final detail = AppCheckDiagnostic.fromMessage(text);
        expect(detail.reason, item.value);
        expect(detail.suffix, isNot(contains('secret-body')));
      }
    }
  });

  test('Android client rejection does not expose its package or fingerprint',
      () {
    for (final raw in [
      'API_KEY_ANDROID_APP_BLOCKED private-fingerprint',
      'Requests from this Android client application private-package are blocked.',
    ]) {
      final detail = AppCheckDiagnostic.fromMessage(raw);
      expect(detail.reason, 'API_KEY_ANDROID_APP_BLOCKED');
      expect(detail.hint, contains('allowed package and signing fingerprint'));
      expect(detail.hint, isNot(contains('private-')));
      expect(detail.suffix, isNot(contains('private-')));
    }
  });

  test('unrelated numbers and Standard Integrity codes remain unknown', () {
    for (final text in [
      null,
      '',
      'private403_-8_secret',
      'unknown HTTP 403 secret',
      'Integrity API error (-999): private',
      'StandardIntegrityException: -17: Integrity API error (-17): private'
    ]) {
      final detail = AppCheckDiagnostic.fromMessage(text);
      expect(detail.httpStatus, isNull);
      expect(detail.reason, isNull);
      expect(detail.suffix, isEmpty);
    }
  });

  test('unregistered app reports a fixed label without its ID', () {
    final detail =
        AppCheckDiagnostic.fromMessage('App not registered: sensitive-app-id');
    expect(detail.reason, 'APP_NOT_REGISTERED');
    expect(detail.hint, isNot(contains('sensitive-app-id')));
  });

  test('other Firebase plugins are not given native App Check evidence', () {
    final error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Too many attempts.');
    final failure = GenerationFailure.from(error);
    expect(failure.kind, GenerationFailureKind.permission);
    expect(failure.toString(), isNot(contains('APP_CHECK_BACKOFF')));
  });
}

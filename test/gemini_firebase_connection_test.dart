// Native token failures are injected; these tests never call an AI endpoint.
// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'package:firebase_app_check_platform_interface/firebase_app_check_platform_interface.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whatmeal/core/services/ai/adapters/gemini_adapter.dart';
import 'package:whatmeal/core/services/ai/ai_models.dart';
import 'package:whatmeal/core/services/ai/generation_failure.dart';
import 'package:whatmeal/core/services/ai/model_registry.dart';

class _Core extends TestFirebaseCoreHostApi {
  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => [];

  @override
  Future<CoreInitializeResponse> initializeApp(
          String appName, CoreFirebaseOptions options) async =>
      CoreInitializeResponse(
          name: appName,
          options: options,
          isAutomaticDataCollectionEnabled: false,
          pluginConstants: {});

  @override
  Future<CoreFirebaseOptions> optionsFromResource() async =>
      throw StateError('Explicit synthetic test options required');
}

class _TokenFailure extends FirebaseAppCheckPlatform {
  Object? error = FirebaseException(
      plugin: 'firebase_app_check',
      code: 'unknown',
      message: 'synthetic-private-token');
  int limitedCalls = 0;

  @override
  FirebaseAppCheckPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseAppCheckPlatform setInitialValues() => this;
  @override
  Future<String?> getToken(bool forceRefresh) =>
      throw StateError('Session-token fallback is forbidden');
  @override
  Future<String> getLimitedUseToken() async {
    limitedCalls++;
    final failure = error;
    if (failure != null) throw failure;
    return 'synthetic-test-appcheck';
  }
}

class _NoSignedInUser extends FirebaseAuthPlatform {
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseAuthPlatform setInitialValues(
          {PigeonUserDetails? currentUser, String? languageCode}) =>
      this;
  @override
  UserPlatform? get currentUser => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final native = _TokenFailure();
  setUpAll(() async {
    TestFirebaseCoreHostApi.setUp(_Core());
    await Firebase.initializeApp(
        options: const FirebaseOptions(
            apiKey: 'synthetic-not-a-key',
            appId: 'synthetic-test-app',
            messagingSenderId: 'synthetic',
            projectId: 'demo-whatmeal-test'));
    FirebaseAppCheckPlatform.instance = native;
    FirebaseAuthPlatform.instance = _NoSignedInUser();
  });
  setUp(() {
    native.limitedCalls = 0;
  });

  test('keyless connection checks model tokens without generating a recipe',
      () async {
    native.error = null;
    var requests = 0;
    final result = await http.runWithClient(
        () => GeminiAdapter(bundledKeys: const []).testConnection(),
        () => MockClient((request) async {
              requests++;
              expect(request.url.host, 'firebasevertexai.googleapis.com');
              expect(request.url.path, endsWith(':countTokens'));
              expect(request.url.path,
                  contains('models/${AiModelRegistry.defaultGemini}'));
              expect(request.headers['X-Firebase-AppCheck'],
                  'synthetic-test-appcheck');
              return http.Response('{"totalTokens": 5}', 200);
            }));
    expect(result.isValid, true);
    expect(result.status, TestConnectionStatus.connected);
    expect(requests, 1);
    expect(native.limitedCalls, 1);
  });

  test('real SDK token failure reaches connection UI as App Check, not outage',
      () async {
    native.error = FirebaseException(
        plugin: 'firebase_app_check',
        code: 'unknown',
        message: 'synthetic-private-token');
    final result = await GeminiAdapter(bundledKeys: const []).testConnection();
    expect(result.isValid, false);
    expect(result.status, TestConnectionStatus.failed);
    expect(result.errorMessage, contains('verification token'));
    expect(result.errorMessage, contains('firebase_app_check/unknown'));
    expect(result.errorMessage, isNot(contains('synthetic-private-token')));
    expect(native.limitedCalls, 1);
  });

  test(
      'SDK connection timeout keeps timeout feedback rather than outage status',
      () async {
    native.error = TimeoutException('synthetic-private-token');
    final result = await GeminiAdapter(bundledKeys: const []).testConnection();
    expect(result.isValid, false);
    expect(result.status, TestConnectionStatus.networkError);
    expect(result.errorMessage, contains('timed out'));
    expect(result.errorMessage, isNot(contains('synthetic-private-token')));
    expect(native.limitedCalls, 1);
  });

  test(
      'generation token failure remains separate from response parsing and saving',
      () async {
    native.error =
        FirebaseException(plugin: 'firebase_app_check', code: 'unknown');
    await expectLater(
        GeminiAdapter(bundledKeys: const []).generateMealPlan(
            const AiMealPlanRequest(
                familyMemberNames: ['Synthetic'],
                numberOfDays: 1,
                mealTypes: ['Dinner'])),
        throwsA(predicate((error) =>
            error != null &&
            GenerationFailure.from(error).kind ==
                GenerationFailureKind.appCheck)));
    expect(native.limitedCalls, 1);
  });
}

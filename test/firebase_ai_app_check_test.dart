import 'dart:async';

// Exercise the installed SDK's actual header callback without sending requests.
// ignore: implementation_imports
import 'package:firebase_ai/src/base_model.dart' show BaseModel;
import 'package:firebase_app_check/firebase_app_check.dart';
// Needed to implement the pinned App Check public interface faithfully.
// ignore: depend_on_referenced_packages
import 'package:firebase_app_check_platform_interface/firebase_app_check_platform_interface.dart'
    show WebProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/services/ai/firebase_ai_app_check.dart';

class _AppCheck implements FirebaseAppCheck {
  @override
  late FirebaseApp app;

  @override
  final Map<dynamic, dynamic> pluginConstants = {'fixture': true};

  final tokens = StreamController<String?>.broadcast();
  late final Stream<String?> tokenStream = tokens.stream;
  int limitedCalls = 0;
  int sessionCalls = 0;
  Object? limitedError;
  bool? autoRefresh;
  WebProvider? activatedWeb;
  AndroidProvider? activatedAndroid;
  AppleProvider? activatedApple;

  @override
  Future<void> activate({
    WebProvider? webProvider,
    AndroidProvider androidProvider = AndroidProvider.playIntegrity,
    AppleProvider appleProvider = AppleProvider.deviceCheck,
  }) async {
    activatedWeb = webProvider;
    activatedAndroid = androidProvider;
    activatedApple = appleProvider;
  }

  @override
  Future<String?> getToken([bool? forceRefresh]) async {
    sessionCalls++;
    return 'synthetic-session';
  }

  @override
  Future<String> getLimitedUseToken() async {
    final number = ++limitedCalls;
    if (limitedError case final error?) throw error;
    await Future<void>.delayed(Duration.zero);
    return 'synthetic-limited-$number';
  }

  @override
  Future<void> setTokenAutoRefreshEnabled(
      bool isTokenAutoRefreshEnabled) async {
    autoRefresh = isTokenAutoRefreshEnabled;
  }

  @override
  Stream<String?> get onTokenChange => tokenStream;
}

void main() {
  late _AppCheck original;
  late FirebaseAiAppCheck ai;

  setUp(() {
    original = _AppCheck();
    ai = FirebaseAiAppCheck(original);
  });

  tearDown(() => original.tokens.close());

  test('each AI SDK header callback obtains a fresh limited-use token',
      () async {
    final headers = BaseModel.firebaseTokens(ai, null, null);
    expect((await headers())['X-Firebase-AppCheck'], 'synthetic-limited-1');
    expect((await headers())['X-Firebase-AppCheck'], 'synthetic-limited-2');
    expect(original.limitedCalls, 2);
    expect(original.sessionCalls, 0);
  });

  test('getToken refresh arguments never request session tokens', () async {
    expect(await ai.getToken(), 'synthetic-limited-1');
    expect(await ai.getToken(false), 'synthetic-limited-2');
    expect(await ai.getToken(true), 'synthetic-limited-3');
    expect(await ai.getLimitedUseToken(), 'synthetic-limited-4');
    expect(original.limitedCalls, 4);
    expect(original.sessionCalls, 0);
  });

  test('concurrent AI requests obtain distinct limited-use tokens', () async {
    final headers = BaseModel.firebaseTokens(ai, null, null);
    final results = await Future.wait(List.generate(
      3,
      (_) => Future<Map<String, String>>.sync(headers),
    ));
    expect(results.map((r) => r['X-Firebase-AppCheck']).toSet(), {
      'synthetic-limited-1',
      'synthetic-limited-2',
      'synthetic-limited-3',
    });
    expect(original.limitedCalls, 3);
    expect(original.sessionCalls, 0);
  });

  test('token failures propagate without cached or session-token fallback',
      () async {
    final failure = FirebaseException(
      plugin: 'firebase_app_check',
      code: 'permission-denied',
    );
    final headers = BaseModel.firebaseTokens(ai, null, null);
    expect((await headers())['X-Firebase-AppCheck'], 'synthetic-limited-1');
    original.limitedError = failure;
    await expectLater(headers(), throwsA(same(failure)));
    await expectLater(headers(), throwsA(same(failure)));
    expect(original.limitedCalls, 3);
    expect(original.sessionCalls, 0);
    original.limitedError = null;
    expect((await headers())['X-Firebase-AppCheck'], 'synthetic-limited-4');
  });

  test('non-AI calls retain the original session-token path', () async {
    expect(await original.getToken(), 'synthetic-session');
    await ai.getToken();
    expect(await original.getToken(true), 'synthetic-session');
    expect(original.sessionCalls, 2);
    expect(original.limitedCalls, 1);
  });

  test('other App Check operations remain delegated', () async {
    final web = ReCaptchaV3Provider('synthetic-public-site-key');
    await ai.activate(webProvider: web);
    expect(original.activatedWeb, same(web));
    expect(original.activatedAndroid, AndroidProvider.playIntegrity);
    expect(original.activatedApple, AppleProvider.deviceCheck);
    await ai.setTokenAutoRefreshEnabled(false);
    expect(original.autoRefresh, false);
    expect(ai.pluginConstants, same(original.pluginConstants));
    expect(ai.onTokenChange, same(original.onTokenChange));
    final event = ai.onTokenChange.first;
    original.tokens.add('synthetic-event');
    expect(await event, 'synthetic-event');
    expect(original.limitedCalls, 0);
    expect(original.sessionCalls, 0);
  });
}

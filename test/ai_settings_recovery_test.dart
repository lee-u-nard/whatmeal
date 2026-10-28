import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/models/app_notification.dart';
import 'package:whatmeal/core/config/runtime_environment.dart';
import 'package:whatmeal/core/models/llm_config.dart';
import 'package:whatmeal/core/services/ai/ai_models.dart';
import 'package:whatmeal/core/services/ai/generation_failure.dart';
import 'package:whatmeal/core/services/llm_service.dart';
import 'package:whatmeal/features/ai_settings/data/ai_provider_repository.dart';
import 'package:whatmeal/features/ai_settings/models/ai_provider.dart';
import 'package:whatmeal/features/ai_settings/pages/ai_settings_page.dart';

// Synthetic adapters only. These cases do not contact a provider or Firebase.
void main() {
  late StreamController<String?> accounts;
  late Map<String, StreamController<LlmConfig>> feeds;
  late Map<String, LlmConfig> saved;
  late AiProviderRepository repo;
  late ValidateAiConnection validate;
  late LoadAiModels discover;
  late Future<void> Function(String, LlmConfig) save;
  late List<LlmConfig> writes;
  late List<({String uid, String title, String body, AppNotificationType type})>
      notices;

  Future<void> tick() => Future<void>.delayed(Duration.zero);
  void switchTo(String uid) {
    accounts.add(uid);
    feeds[uid]!.add(saved[uid]!);
  }

  setUp(() {
    accounts = StreamController<String?>.broadcast(sync: true);
    feeds = {
      for (final uid in ['a', 'b'])
        uid: StreamController<LlmConfig>.broadcast(sync: true),
    };
    saved = {
      for (final uid in ['a', 'b'])
        uid: LlmConfig(
          provider: LlmProvider.groq,
          apiKey: '$uid-synthetic-key',
          model: 'openai/gpt-oss-20b',
        ),
    };
    writes = [];
    notices = [];
    save = (uid, config) async {
      writes.add(config);
      saved[uid] = config;
    };
    validate = (_) async => const KeyValidationResult(isValid: true);
    discover = (_) async => ['openai/gpt-oss-20b'];
    repo = AiProviderRepository(
      userIds: accounts.stream,
      watchConfig: (uid) => feeds[uid]!.stream,
      readConfig: (uid) async => saved[uid]!,
      saveConfig: (uid, config) => save(uid, config),
      validateConnection: (config) => validate(config),
      loadModels: (config) => discover(config),
      onConnectionResult: (uid, title, body, type) =>
          notices.add((uid: uid, title: title, body: body, type: type)),
    );
    switchTo('a');
  });

  testWidgets(
      'unknown Firebase connection failure does not claim provider outage or a failed save',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    feeds['a']!.add(LlmConfig.defaultConfig);
    validate = (_) async => throw FirebaseException(
        plugin: 'firebase_app_check',
        code: 'unknown',
        message: 'private-token-value');
    await repo.testConnection();
    expect(repo.value.status, ApiConnectionStatus.failed);
    await tester
        .pumpWidget(MaterialApp(home: AiSettingsPage(repository: repo)));
    expect(find.textContaining('Diagnostic: firebase_app_check/unknown'),
        findsOneWidget);
    expect(find.text('Provider Unavailable'), findsNothing);
    expect(find.textContaining('may not have been saved'), findsNothing);
    expect(repo.value.statusMessage, isNot(contains('private-token-value')));
    await tester.pumpWidget(const SizedBox());
  });

  tearDown(() async {
    repo.dispose();
    await accounts.close();
    for (final feed in feeds.values) {
      await feed.close();
    }
  });

  testWidgets('default Gemini notice reflects the actual runtime mode',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    feeds['a']!.add(LlmConfig.defaultConfig);
    await tester
        .pumpWidget(MaterialApp(home: AiSettingsPage(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Live AI is disabled'),
        useFirebaseEmulators ? findsOneWidget : findsNothing);
    expect(find.textContaining('configured Google AI Studio credentials'),
        useFirebaseEmulators ? findsNothing : findsOneWidget);
    expect(repo.generationReadinessError, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test(
      'pending or failed Gemini selection cannot use a previously saved provider',
      () async {
    expect(repo.generationReadinessError, isNull);
    final gate = Completer<void>();
    save = (uid, config) async {
      await gate.future;
      throw StateError('private detail');
    };
    final pending = repo.selectProvider(AiProviderType.gemini);
    expect(repo.value.providerType, AiProviderType.gemini);
    expect(repo.generationReadinessError, contains('still saving'));
    gate.complete();
    await pending;
    expect(repo.generationReadinessError, contains('not synchronized'));
    expect(saved['a']!.provider, LlmProvider.groq);
    save = (uid, config) async {
      saved[uid] = config;
    };
    await repo.selectProvider(AiProviderType.gemini);
    expect(repo.generationReadinessError, isNull);
    expect(saved['a']!.provider, LlmProvider.gemini);
    expect(saved['a']!.apiKey, isNull);
  });

  test(
      'settings read errors block generation, connection errors do not invalidate saved settings',
      () async {
    feeds['a']!.addError(StateError('private detail'));
    expect(repo.generationReadinessError, contains('not synchronized'));
    feeds['a']!.add(saved['a']!);
    validate = (_) async => throw TimeoutException('private detail');
    await repo.testConnection();
    expect(repo.generationReadinessError, isNull);
    accounts.add(null);
    expect(repo.generationReadinessError, contains('Sign in'));
  });

  test('discovery never replaces or persists an unavailable saved model',
      () async {
    discover = (_) async => ['openai/gpt-oss-120b', 'openai/gpt-oss-120b', ' '];
    await repo.fetchModels();
    expect(repo.value.selectedModel, 'openai/gpt-oss-20b');
    expect(repo.value.fetchedModels, ['openai/gpt-oss-120b']);
    expect(repo.value.status, ApiConnectionStatus.invalidModel);
    expect(writes, isEmpty);
    expect(saved['a']!.model, 'openai/gpt-oss-20b');
  });

  test('empty or non-reviewed discovery does not become a static live list',
      () async {
    discover = (_) async => ['embedding-only-unreviewed-model'];
    await repo.fetchModels();
    expect(repo.value.fetchedModels, isEmpty);
    expect(repo.value.effectiveModels, isEmpty);
    expect(repo.value.selectedModel, 'openai/gpt-oss-20b');
    expect(repo.value.status, ApiConnectionStatus.failed);
    expect(writes, isEmpty);
  });

  test('built-in Gemini does not pretend to discover a live catalogue',
      () async {
    feeds['a']!.add(LlmConfig.defaultConfig);
    var called = false;
    discover = (_) async {
      called = true;
      return [];
    };
    await repo.fetchModels();
    expect(called, isFalse);
    expect(repo.value.status, ApiConnectionStatus.configured);
    expect(repo.value.status, isNot(ApiConnectionStatus.providerUnavailable));
    expect(repo.value.statusMessage, contains('suggested models'));
    expect(repo.value.fetchedModels, isNull);
  });

  test('anonymous custom endpoint can be checked and discovered explicitly',
      () async {
    feeds['a']!.add(LlmConfig(
      provider: LlmProvider.custom,
      customEndpoint: 'http://127.0.0.1:4321/v1',
      model: 'local-text-model',
    ));
    discover = (config) async {
      expect(config.apiKey, isNull);
      expect(config.customEndpoint, 'http://127.0.0.1:4321/v1');
      return ['local-text-model'];
    };
    await repo.fetchModels();
    expect(repo.value.fetchedModels, ['local-text-model']);
    await repo.testConnection();
    expect(repo.value.status, ApiConnectionStatus.connected);
  });

  test('connection check does not claim meal generation is verified', () async {
    await repo.testConnection();
    expect(repo.value.status, ApiConnectionStatus.connected);
    expect(repo.value.statusMessage, contains('has not been verified'));
    expect(notices.single.uid, 'a');
    expect(notices.single.body, contains('has not been verified'));
    expect(notices.single.body, isNot(contains('ready for meal generation')));
  });

  test('model edit clears a prior connection result and persists the exact ID',
      () async {
    await repo.testConnection();
    expect(await repo.updateModel(' openai/gpt-oss-120b '), isTrue);
    expect(repo.value.status, ApiConnectionStatus.configured);
    expect(saved['a']!.model, 'openai/gpt-oss-120b');
    final count = writes.length;
    expect(await repo.updateModel('  '), isFalse);
    expect(writes.length, count);
    expect(repo.value.selectedModel, 'openai/gpt-oss-120b');
  });

  test('key and endpoint edits clear stale discovered models', () async {
    await repo.fetchModels();
    expect(repo.value.fetchedModels, isNotNull);
    await repo.setApiKey('changed-synthetic-key');
    expect(repo.value.fetchedModels, isNull);
    await repo.fetchModels();
    repo.setCustomEndpoint('https://different.example.test/v1');
    expect(repo.value.fetchedModels, isNull);
    await tick();
  });

  test('delayed successful connection cannot notify or update the next account',
      () async {
    final gate = Completer<KeyValidationResult>();
    validate = (_) => gate.future;
    final pending = repo.testConnection();
    switchTo('b');
    gate.complete(const KeyValidationResult(isValid: true));
    await pending;
    expect(repo.value.apiKey, 'b-synthetic-key');
    expect(repo.value.status, ApiConnectionStatus.configured);
    expect(notices, isEmpty);
  });

  test('delayed failed connection is ignored after A B A session changes',
      () async {
    final gate = Completer<KeyValidationResult>();
    validate = (_) => gate.future;
    final pending = repo.testConnection();
    switchTo('b');
    switchTo('a');
    gate.complete(const KeyValidationResult(
      isValid: false,
      status: TestConnectionStatus.invalidKey,
      errorMessage: 'Old session failed.',
    ));
    await pending;
    expect(repo.value.status, ApiConnectionStatus.configured);
    expect(repo.value.statusMessage, isNot(contains('Old session')));
    expect(notices, isEmpty);
  });

  test('delayed model discovery cannot leak across accounts', () async {
    final gate = Completer<List<String>>();
    discover = (_) => gate.future;
    final pending = repo.fetchModels();
    switchTo('b');
    gate.complete(['openai/gpt-oss-120b']);
    await pending;
    expect(repo.value.apiKey, 'b-synthetic-key');
    expect(repo.value.fetchedModels, isNull);
    expect(repo.value.selectedModel, 'openai/gpt-oss-20b');
  });

  test('model change supersedes discovery already in flight', () async {
    final gate = Completer<List<String>>();
    discover = (_) => gate.future;
    final pending = repo.fetchModels();
    await repo.updateModel('openai/gpt-oss-120b');
    gate.complete(['openai/gpt-oss-20b']);
    await pending;
    expect(repo.value.selectedModel, 'openai/gpt-oss-120b');
    expect(repo.value.fetchedModels, isNull);
    expect(repo.value.status, ApiConnectionStatus.configured);
  });

  test('duplicate connection taps do not issue duplicate requests', () async {
    final gate = Completer<KeyValidationResult>();
    var requests = 0;
    validate = (_) {
      requests++;
      return gate.future;
    };
    final pending = repo.testConnection();
    await repo.testConnection();
    await repo.fetchModels();
    expect(requests, 1);
    gate.complete(const KeyValidationResult(isValid: true));
    await pending;
    expect(notices.length, 1);
  });

  test('failed checks redact thrown details and recover on retry', () async {
    validate = (_) async => throw StateError('synthetic-private-value');
    await repo.testConnection();
    expect(repo.value.status, ApiConnectionStatus.providerUnavailable);
    expect(
        repo.value.statusMessage, isNot(contains('synthetic-private-value')));
    validate = (_) async => const KeyValidationResult(isValid: true);
    await repo.testConnection();
    expect(repo.value.status, ApiConnectionStatus.connected);
  });

  test('rejected saved model configuration is not misreported as unavailable',
      () async {
    validate = (_) async =>
        throw const GenerationFailure(GenerationFailureKind.configuration);
    await repo.testConnection();
    expect(repo.value.status, ApiConnectionStatus.configurationError);
    expect(repo.value.statusMessage, contains('configuration was rejected'));
  });

  test('disabled Firebase AI service asks for project setup', () async {
    validate = (_) async => throw FirebaseAIException(
        'PERMISSION_DENIED: SERVICE_DISABLED for firebase AI logic API');
    await repo.testConnection();
    expect(repo.value.status, ApiConnectionStatus.configurationError);
    expect(repo.value.status.label, 'Configuration Required');
    expect(repo.value.statusMessage, contains('Firebase AI Logic'));
    expect(repo.value.statusMessage, contains('App Check'));
  });

  test('unsupported Gemini model is reported as invalid model', () async {
    feeds['a']!.add(LlmConfig.defaultConfig);
    validate = (_) async => throw FirebaseAIException(
        'MODEL_NOT_FOUND: selected model is not supported');
    await repo.testConnection();
    expect(repo.value.status, ApiConnectionStatus.invalidModel);
    expect(repo.value.statusMessage, contains('selected AI model'));
  });

  test('Firebase permission failure is not reported as provider unavailable',
      () async {
    validate = (_) async =>
        throw const GenerationFailure(GenerationFailureKind.permission);
    await repo.testConnection();
    expect(repo.value.status, ApiConnectionStatus.permissionDenied);
    expect(repo.value.status.label, 'Permission Denied');
  });

  test('failed discovery redacts details and succeeds on retry', () async {
    discover = (_) async => throw StateError('synthetic-private-value');
    await repo.fetchModels();
    expect(repo.value.status, ApiConnectionStatus.failed);
    expect(
        repo.value.statusMessage, isNot(contains('synthetic-private-value')));
    discover = (_) async => ['openai/gpt-oss-20b'];
    await repo.fetchModels();
    expect(repo.value.status, ApiConnectionStatus.configured);
    expect(repo.value.fetchedModels, ['openai/gpt-oss-20b']);
  });

  testWidgets('dropdown retains absent model and follows remote model changes',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    feeds['a']!.add(LlmConfig(
        provider: LlmProvider.groq,
        apiKey: 'synthetic-key',
        model: 'saved-unknown-model'));
    await tester
        .pumpWidget(MaterialApp(home: AiSettingsPage(repository: repo)));
    DropdownButtonFormField<String> dropdown() =>
        tester.widget(find.byType(DropdownButtonFormField<String>));
    expect(dropdown().initialValue, 'saved-unknown-model');
    expect(tester.takeException(), isNull);
    feeds['a']!.add(LlmConfig(
        provider: LlmProvider.groq,
        apiKey: 'synthetic-key',
        model: 'openai/gpt-oss-120b'));
    await tester.pump();
    expect(dropdown().initialValue, 'openai/gpt-oss-120b');
    expect(writes, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'custom model draft survives rebuild and clears on account switch',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final custom = LlmConfig(
        provider: LlmProvider.custom,
        apiKey: 'synthetic-key',
        model: 'saved-model',
        customEndpoint: 'https://example.test/v1');
    saved['a'] = custom;
    saved['b'] = custom;
    feeds['a']!.add(custom);
    await tester
        .pumpWidget(MaterialApp(home: AiSettingsPage(repository: repo)));
    final field = find.widgetWithText(TextField, 'Model');
    await tester.enterText(field, 'unsaved-draft');
    final gate = Completer<KeyValidationResult>();
    validate = (_) => gate.future;
    final pending = repo.testConnection();
    await tester.pump();
    expect(find.text('unsaved-draft'), findsOneWidget);
    switchTo('b');
    await tester.pump();
    expect(find.text('unsaved-draft'), findsNothing);
    expect(find.text('saved-model'), findsOneWidget);
    gate.complete(const KeyValidationResult(isValid: true));
    await pending;
    expect(notices, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  for (final fails in [false, true]) {
    testWidgets(
        'old-account ${fails ? 'failed' : 'successful'} key save cannot show feedback in next session',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final gate = Completer<void>();
      save = (uid, config) async {
        await gate.future;
        if (fails) throw StateError('old-account-private-error');
        saved[uid] = config;
      };
      await tester
          .pumpWidget(MaterialApp(home: AiSettingsPage(repository: repo)));
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pump();
      await tester.enterText(
          find.widgetWithText(TextField, 'API Key'), 'new-synthetic-key');
      await tester.tap(find.text('Save Key'));
      await tester.pump();
      switchTo('b');
      await tester.pump();
      gate.complete();
      await tester.runAsync(tick);
      await tester.pumpAndSettle();
      expect(repo.value.apiKey, 'b-synthetic-key');
      expect(find.text('API key updated!'), findsNothing);
      expect(find.textContaining('not saved'), findsNothing);
      expect(find.textContaining('old-account-private-error'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

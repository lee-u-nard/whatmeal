import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:whatmeal/features/ai_settings/pages/ai_settings_page.dart';
import 'package:whatmeal/core/models/llm_config.dart';
import 'package:whatmeal/features/ai_settings/data/ai_provider_repository.dart';
import 'package:whatmeal/features/ai_settings/models/ai_provider.dart';

Future<void> tick() => Future<void>.delayed(Duration.zero);
LlmConfig custom(String key) =>
    LlmConfig(provider: LlmProvider.groq, apiKey: key, model: 'test-model');

void main() {
  late StreamController<String?> accounts;
  late Map<String, StreamController<LlmConfig>> feeds;
  late Map<String, LlmConfig> persisted;
  late AiProviderRepository repo;
  late Future<void> Function(String, LlmConfig) save;
  late Future<LlmConfig> Function(String) read;
  late List<AiProviderType> announced;
  setUp(() {
    accounts = StreamController<String?>.broadcast(sync: true);
    feeds = {
      for (final uid in ['a', 'b'])
        uid: StreamController<LlmConfig>.broadcast(sync: true)
    };
    persisted = {'a': custom('a-test'), 'b': custom('b-test')};
    save = (uid, config) async {
      persisted[uid] = config;
    };
    read = (uid) async => persisted[uid]!;
    announced = [];
    repo = AiProviderRepository(
        onProviderChanged: announced.add,
        userIds: accounts.stream,
        watchConfig: (uid) => feeds[uid]!.stream,
        readConfig: (uid) => read(uid),
        saveConfig: (uid, config) => save(uid, config));
    accounts.add('a');
    feeds['a']!.add(persisted['a']!);
  });
  tearDown(() async {
    repo.dispose();
    await accounts.close();
    for (final feed in feeds.values) {
      await feed.close();
    }
  });

  test(
      'provider notification waits for successful persistence and rejects failed saves',
      () async {
    final gate = Completer<void>();
    save = (uid, config) async {
      await gate.future;
      persisted[uid] = config;
    };
    final change = repo.selectProvider(AiProviderType.openAi);
    await tick();
    expect(announced, isEmpty);
    gate.complete();
    await change;
    expect(announced, [AiProviderType.openAi]);
    save = (_, __) async => throw StateError('test failure');
    await repo.selectProvider(AiProviderType.claude);
    expect(announced, [AiProviderType.openAi]);
  });

  test('remote provider changes and deletion reach active settings', () {
    expect(repo.value.apiKey, 'a-test');
    feeds['a']!.add(LlmConfig(
        provider: LlmProvider.custom,
        apiKey: 'new-test',
        customEndpoint: 'https://example.test/v1'));
    expect(repo.value.providerType, AiProviderType.custom);
    expect(repo.value.customEndpoint, 'https://example.test/v1');
    feeds['a']!.add(LlmConfig.defaultConfig);
    expect(repo.value.providerType, AiProviderType.gemini);
    expect(repo.value.apiKey, isNull);
  });

  test('pending edits survive old echoes and reconcile after serialized writes',
      () async {
    final gate = Completer<void>();
    final writes = <String?>[];
    save = (uid, config) async {
      writes.add(config.apiKey);
      if (writes.length == 1) await gate.future;
      persisted[uid] = config;
    };
    repo.setApiKey('first');
    await tick();
    repo.setApiKey('second');
    feeds['a']!.add(custom('stale-remote'));
    expect(repo.value.apiKey, 'second');
    expect(repo.isSaving, isTrue);
    gate.complete();
    await tick();
    await tick();
    expect(writes, ['first', 'second']);
    expect(repo.value.apiKey, 'second');
    expect(repo.isSaving, isFalse);
  });

  test('removal reports failed persistence and allows retry', () async {
    save = (_, __) async => throw StateError('sensitive-test-value');
    expect(await repo.removeKey(), isFalse);
    expect(repo.value.status, ApiConnectionStatus.failed);
    expect(repo.value.statusMessage, isNot(contains('sensitive-test-value')));
    expect(persisted['a']!.provider, LlmProvider.groq);
    save = (uid, config) async {
      persisted[uid] = config;
    };
    expect(await repo.removeKey(), isTrue);
    expect(persisted['a']!.provider, LlmProvider.gemini);
    expect(persisted['a']!.apiKey, isNull);
  });

  test('A logout B login detaches feed and does not block B behind A save',
      () async {
    final gate = Completer<void>();
    save = (uid, config) async {
      if (uid == 'a') await gate.future;
      persisted[uid] = config;
    };
    final oldSave = repo.removeKey();
    await tick();
    accounts.add(null);
    expect(repo.value.apiKey, isNull);
    accounts.add('b');
    feeds['b']!.add(persisted['b']!);
    feeds['a']!.add(custom('late-a'));
    expect(repo.value.apiKey, 'b-test');
    expect(await repo.removeKey(), isTrue);
    gate.complete();
    expect(await oldSave, isFalse);
    expect(repo.value.apiKey, isNull);
    expect(repo.isSaving, isFalse);
  });

  test('A B A ignores completion of first A session', () async {
    final gate = Completer<void>();
    save = (_, __) => gate.future;
    final firstA = repo.removeKey();
    await tick();
    accounts.add('b');
    accounts.add('a');
    feeds['a']!.add(custom('new-session'));
    gate.complete();
    expect(await firstA, isFalse);
    expect(repo.value.apiKey, 'new-session');
  });

  test('new remote snapshot wins over delayed reconciliation read', () async {
    final gate = Completer<LlmConfig>();
    read = (_) => gate.future;
    final removing = repo.removeKey();
    await tick();
    feeds['a']!.add(custom('other-device'));
    gate.complete(LlmConfig.defaultConfig);
    expect(await removing, isTrue);
    expect(repo.value.apiKey, 'other-device');
  });

  test('listener error clears stale credentials without exposing error', () {
    feeds['a']!.addError(StateError('sensitive-test-value'));
    expect(repo.value.apiKey, isNull);
    expect(repo.value.status, ApiConnectionStatus.failed);
    expect(repo.value.statusMessage, isNot(contains('sensitive-test-value')));
    feeds['a']!.add(custom('recovered'));
    expect(repo.value.apiKey, 'recovered');
  });
  testWidgets('remove dialog waits for save and reports failure truthfully',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gate = Completer<void>();
    save = (_, __) async {
      await gate.future;
      throw StateError('test-only-secret');
    };
    await tester
        .pumpWidget(MaterialApp(home: AiSettingsPage(repository: repo)));
    await tester.tap(find.text('Remove', skipOffstage: false));
    await tester.pumpAndSettle();
    expect(find.text('Remove API Key'), findsOneWidget);
    await tester.tap(find.text('Remove Key'));
    await tester.pumpAndSettle();
    expect(find.text('API Key removed. Switched back to default Gemini.'),
        findsNothing);
    await tester.runAsync(() async {
      await tick();
    });
    gate.complete();
    await tester.runAsync(() async {
      await tick();
    });
    await tester.pumpAndSettle();
    expect(find.text('API key removal was not saved. Please retry.'),
        findsOneWidget);
    expect(find.textContaining('test-only-secret'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('remote custom endpoint updates existing settings field',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    feeds['a']!.add(LlmConfig(
        provider: LlmProvider.custom,
        apiKey: 'test-key',
        customEndpoint: 'https://first.test/v1'));
    await tester
        .pumpWidget(MaterialApp(home: AiSettingsPage(repository: repo)));
    expect(find.text('https://first.test/v1'), findsOneWidget);
    feeds['a']!.add(LlmConfig(
        provider: LlmProvider.custom,
        apiKey: 'test-key',
        customEndpoint: 'https://second.test/v1'));
    await tester.pump();
    expect(find.text('https://first.test/v1'), findsNothing);
    expect(find.text('https://second.test/v1'), findsOneWidget);
    accounts.add(null);
    await tester.pump();
    expect(find.text('https://second.test/v1'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/models/llm_config.dart';
import 'package:whatmeal/features/ai_settings/data/ai_provider_repository.dart';
import 'package:whatmeal/features/ai_settings/models/ai_provider.dart';
import 'package:whatmeal/features/ai_settings/pages/ai_settings_page.dart';

void main() {
  testWidgets(
      'provider settings retry resubscribes and isolates old account feed',
      (tester) async {
    final accounts = StreamController<String?>.broadcast(sync: true);
    final feeds = {
      for (final uid in ['a', 'b'])
        uid: StreamController<LlmConfig>.broadcast(sync: true)
    };
    var watches = 0;
    final repo = AiProviderRepository(
        userIds: accounts.stream,
        watchConfig: (uid) {
          watches++;
          return feeds[uid]!.stream;
        },
        readConfig: (_) async => LlmConfig.defaultConfig,
        saveConfig: (uid, config) async {});
    addTearDown(() async {
      repo.dispose();
      await accounts.close();
      for (final feed in feeds.values) {
        await feed.close();
      }
    });
    accounts.add('a');
    feeds['a']!.addError(StateError('Synthetic private detail'));
    await tester
        .pumpWidget(MaterialApp(home: AiSettingsPage(repository: repo)));
    expect(repo.value.status, ApiConnectionStatus.failed);
    expect(find.text('Retry Settings'), findsOneWidget);
    await tester.tap(find.text('Retry Settings'));
    await tester.pumpAndSettle();
    expect(watches, 2);
    feeds['a']!.add(LlmConfig(provider: LlmProvider.groq));
    await tester.pump();
    expect(repo.value.providerType, AiProviderType.groq);
    accounts.add('b');
    await tester.pump();
    feeds['a']!.add(LlmConfig(provider: LlmProvider.anthropic));
    await tester.pump();
    expect(repo.value.providerType, AiProviderType.gemini);
    expect(find.textContaining('Synthetic private detail'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('default provider settings fit 320 pixels at text scale $scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = AiProviderRepository(
        userIds: Stream.value('local-widget-account'),
        watchConfig: (_) => Stream.value(LlmConfig.defaultConfig),
        readConfig: (_) async => LlmConfig.defaultConfig,
        saveConfig: (uid, config) async {},
      );
      addTearDown(repo.dispose);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: AiSettingsPage(repository: repo)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final list = find.byType(Scrollable).first;
      for (var i = 0; i < 18; i++) {
        await tester.drag(list, const Offset(0, -180));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason:
                'All settings sections must fit without suppressed layout errors');
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}

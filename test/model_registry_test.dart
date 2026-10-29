import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/models/llm_config.dart';
import 'package:whatmeal/core/services/ai/ai_provider_factory.dart';
import 'package:whatmeal/core/services/ai/generation_failure.dart';
import 'package:whatmeal/core/services/ai/model_registry.dart';
import 'package:whatmeal/features/ai_settings/models/ai_provider.dart';

void main() {
  test(
      'keyless default uses live-tested Flash Lite without replacing saved models',
      () {
    final defaults = LlmConfig.defaultConfig;
    expect(defaults.model, 'gemini-3.5-flash-lite');
    expect(defaults.apiKey, isNull);
    expect(defaults.isCustom, false);
    expect(AiProviderFactory.create(defaults).model, 'gemini-3.5-flash-lite');
    final saved = LlmConfig.fromMap({
      'provider': 'gemini',
      'model': 'gemini-3.8-flash',
    });
    expect(AiProviderFactory.create(saved).model, 'gemini-3.8-flash');
  });
  test('reviewed models have unique provider identities and central UI choices',
      () {
    final ids =
        AiModelRegistry.all.map((m) => '${m.provider.name}:${m.id}').toSet();
    expect(ids.length, AiModelRegistry.all.length);
    for (final type in AiProviderType.values) {
      expect(type.availableModels, AiModelRegistry.choices(type.toLlmProvider));
      if (type != AiProviderType.custom) {
        expect(type.availableModels, contains(type.defaultModel));
      }
    }
    expect(LlmConfig.defaultConfig.model, AiProviderType.gemini.defaultModel);
  });
  test('retired and billing restricted choices are retained only as metadata',
      () {
    expect(AiProviderType.claude.availableModels,
        isNot(contains('claude-3-5-haiku-20241022')));
    expect(AiProviderType.gemini.availableModels,
        isNot(contains('gemini-3.1-pro-preview')));
    expect(AiProviderType.groq.availableModels,
        isNot(contains('minimaxai/minimax-m2.7')));
    expect(
        AiModelRegistry.find(LlmProvider.anthropic, 'claude-3-5-haiku-20241022')
            ?.lifecycle,
        ModelLifecycle.retired);
    expect(AiModelRegistry.label(LlmProvider.groq, 'qwen/qwen3.8-27b'),
        contains('preview'));
  });
  test('deprecated choices stop being offered on the published retirement date',
      () {
    final model = AiModelRegistry.find(LlmProvider.openai, 'o4-mini')!;
    expect(model.availableOn(DateTime(2026, 10, 22)), isTrue);
    expect(model.availableOn(DateTime(2026, 10, 23)), isFalse);
    expect(model.label, contains('2026-10-23'));
  });
  test('model discovery never confuses text capabilities with an ID prefix',
      () {
    expect(
        AiModelRegistry.filterDiscovered(LlmProvider.openai, [
          'gpt-6-luna',
          'gpt-6-audio',
          'gpt-search-only',
          'gpt-6-luna',
          'o99-unknown'
        ]),
        ['gpt-6-luna']);
    expect(
        AiModelRegistry.filterDiscovered(LlmProvider.anthropic,
            ['claude-3-5-sonnet-20241022', 'claude-haiku-5-5']),
        ['claude-haiku-5-5']);
  });
  test('factory rejects retired, wrong provider, unknown and invalid model IDs',
      () {
    for (final config in [
      LlmConfig(
          provider: LlmProvider.anthropic,
          apiKey: 'test-only',
          model: 'claude-3-5-haiku-20241022'),
      LlmConfig(
          provider: LlmProvider.groq,
          apiKey: 'test-only',
          model: 'gemini-3.8-flash'),
      LlmConfig(provider: LlmProvider.gemini, model: 'gemini-3.1-pro-preview'),
      LlmConfig(
          provider: LlmProvider.openai,
          apiKey: 'test-only',
          model: 'gpt-unknown'),
      LlmConfig(provider: LlmProvider.custom, model: '../bad?secret'),
    ]) {
      expect(() => AiProviderFactory.create(config),
          throwsA(isA<GenerationFailure>()));
    }
    expect(
        AiProviderFactory.create(LlmConfig(
                provider: LlmProvider.custom,
                model: 'local-model:v1',
                customEndpoint: 'http://localhost:1234/v1'))
            .model,
        'local-model:v1');
  });
  test('factory dispatches the same normalized model ID it validates', () {
    for (final provider in LlmProvider.values) {
      final model = provider == LlmProvider.custom
          ? 'local-model:v1'
          : AiModelRegistry.choices(provider).first;
      final adapter = AiProviderFactory.create(LlmConfig(
        provider: provider,
        apiKey: provider == LlmProvider.gemini ? null : 'fixture-only',
        model: '  $model  ',
        customEndpoint:
            provider == LlmProvider.custom ? 'http://localhost:1234/v1' : null,
      ));
      expect(adapter.model, model);
    }
  });

  test('blank model overrides use provider defaults instead of sending blanks',
      () {
    for (final provider in LlmProvider.values) {
      LlmConfig config(String? model) => LlmConfig(
            provider: provider,
            apiKey: provider == LlmProvider.gemini ? null : 'fixture-only',
            model: model,
            customEndpoint: provider == LlmProvider.custom
                ? 'http://localhost:1234/v1'
                : null,
          );
      expect(AiProviderFactory.create(config('  ')).model,
          AiProviderFactory.create(config(null)).model);
    }
  });

  test('unavailable models are distinguishable from rejected credentials', () {
    for (final config in [
      LlmConfig(provider: LlmProvider.gemini, model: 'unknown-model'),
      LlmConfig(
          provider: LlmProvider.anthropic,
          apiKey: 'fixture-only',
          model: 'claude-3-5-haiku-20241022'),
      LlmConfig(
          provider: LlmProvider.groq,
          apiKey: 'fixture-only',
          model: AiModelRegistry.defaultGemini),
    ]) {
      expect(
          () => AiProviderFactory.create(config),
          throwsA(isA<GenerationFailure>().having(
              (e) => e.kind, 'kind', GenerationFailureKind.invalidModel)));
    }
    expect(
        () => AiProviderFactory.create(LlmConfig(provider: LlmProvider.groq)),
        throwsA(isA<GenerationFailure>().having(
            (e) => e.kind, 'kind', GenerationFailureKind.configuration)));
  });

  test('all notes distinguish documented access from live verification', () {
    for (final model in AiModelRegistry.all) {
      final note = AiModelRegistry.note(model.provider, model.id);
      if (model.provider == LlmProvider.gemini &&
          model.id == 'gemini-3.5-flash-lite') {
        expect(note, contains('Live-tested through Firebase AI Logic'));
        expect(note, contains('isolated Spark project'));
        expect(note, contains('attestation remains unverified'));
      } else {
        expect(note, contains('Not live-verified'));
      }
    }
  });
}

import '../../models/llm_config.dart';

enum ModelLifecycle { stable, deprecated, preview, retired }

/// Documentation metadata is not evidence of account access or a live test.
class AiModelInfo {
  const AiModelInfo(
    this.provider,
    this.id,
    this.name, {
    this.lifecycle = ModelLifecycle.stable,
    this.accessNote = '',
    this.verificationNote = 'Not live-verified in WhatMeal.',
    this.retirement,
    this.offerNormally = true,
  });
  final LlmProvider provider;
  final String id;
  final String name;
  final ModelLifecycle lifecycle;
  final String accessNote;
  final String verificationNote;
  final String? retirement;
  final bool offerNormally;

  bool availableOn(DateTime day) =>
      lifecycle != ModelLifecycle.retired &&
      (retirement == null || day.isBefore(DateTime.parse(retirement!)));
  bool get selectable => offerNormally && availableOn(DateTime.now());
  String get label => '$name ($id)${switch (lifecycle) {
        ModelLifecycle.deprecated =>
          ' — deprecated${retirement == null ? '' : ', ends $retirement'}',
        ModelLifecycle.preview => ' — preview',
        ModelLifecycle.retired => ' — retired',
        ModelLifecycle.stable => '',
      }}';
}

/// Small, reviewed text-generation catalogue. Keep retired entries so saved
/// selections can be explained instead of silently replaced with another ID.
class AiModelRegistry {
  AiModelRegistry._();
  static const checkedOn = '2026-10-18';
  // Live-verified keyless Spark model. Explicit saved selections are preserved.
  static const defaultGemini = 'gemini-3.5-flash-lite';
  static const all = <AiModelInfo>[
    AiModelInfo(LlmProvider.gemini, defaultGemini, 'Gemini 3.5 Flash Lite',
        verificationNote:
            'Live-tested through Firebase AI Logic in an isolated Spark project on 2026-10-26; native production/device attestation remains unverified.'),
    AiModelInfo(LlmProvider.gemini, 'gemini-3.8-flash', 'Gemini 3.8 Flash',
        accessNote:
            'Generation timed out in isolated Spark tests on 2026-10-26.'),
    AiModelInfo(LlmProvider.gemini, 'gemini-3.7-flash', 'Gemini 3.7 Flash'),
    AiModelInfo(LlmProvider.gemini, 'gemini-3.6-flash', 'Gemini 3.6 Flash'),
    AiModelInfo(LlmProvider.gemini, 'gemini-3.5-flash', 'Gemini 3.5 Flash'),
    AiModelInfo(
        LlmProvider.gemini, 'gemini-3.1-flash-lite', 'Gemini 3.1 Flash Lite'),
    AiModelInfo(LlmProvider.gemini, 'gemini-3-flash-preview', 'Gemini 3 Flash',
        lifecycle: ModelLifecycle.preview),
    AiModelInfo(LlmProvider.gemini, 'gemini-3.1-pro-preview', 'Gemini 3.1 Pro',
        lifecycle: ModelLifecycle.preview,
        offerNormally: false,
        accessNote:
            'Requires Blaze billing; unavailable in this Spark workflow.'),
    AiModelInfo(LlmProvider.gemini, 'gemini-2.5-flash', 'Gemini 2.5 Flash',
        offerNormally: false,
        accessNote:
            'Legacy access: only projects that previously used this model.'),
    AiModelInfo(
        LlmProvider.gemini, 'gemini-2.5-flash-lite', 'Gemini 2.5 Flash Lite',
        offerNormally: false,
        accessNote:
            'Legacy access: only projects that previously used this model.'),
    AiModelInfo(LlmProvider.openai, 'gpt-6-luna', 'GPT-6 Luna'),
    AiModelInfo(LlmProvider.openai, 'gpt-4.1-mini', 'GPT-4.1 mini',
        lifecycle: ModelLifecycle.deprecated, retirement: '2027-01-14'),
    AiModelInfo(LlmProvider.openai, 'gpt-4.1', 'GPT-4.1',
        lifecycle: ModelLifecycle.deprecated, retirement: '2027-01-14'),
    AiModelInfo(LlmProvider.openai, 'gpt-4o', 'GPT-4o',
        lifecycle: ModelLifecycle.deprecated, retirement: '2027-01-14'),
    AiModelInfo(LlmProvider.openai, 'gpt-4o-mini', 'GPT-4o mini',
        lifecycle: ModelLifecycle.deprecated, retirement: '2027-01-14'),
    AiModelInfo(LlmProvider.openai, 'o4-mini', 'o4-mini',
        lifecycle: ModelLifecycle.deprecated, retirement: '2026-10-23'),
    AiModelInfo(LlmProvider.openai, 'o3', 'o3',
        lifecycle: ModelLifecycle.deprecated, retirement: '2026-12-11'),
    AiModelInfo(LlmProvider.anthropic, 'claude-haiku-4-5', 'Claude Haiku 4.5'),
    AiModelInfo(LlmProvider.anthropic, 'claude-haiku-5-5', 'Claude Haiku 5.5'),
    AiModelInfo(
        LlmProvider.anthropic, 'claude-sonnet-5-5', 'Claude Sonnet 5.5'),
    AiModelInfo(LlmProvider.anthropic, 'claude-sonnet-4-5', 'Claude Sonnet 4.5',
        lifecycle: ModelLifecycle.deprecated, retirement: '2026-11-30'),
    AiModelInfo(LlmProvider.anthropic, 'claude-opus-4-5', 'Claude Opus 4.5'),
    AiModelInfo(
        LlmProvider.anthropic, 'claude-3-5-haiku-20241022', 'Claude 3.5 Haiku',
        lifecycle: ModelLifecycle.retired, retirement: '2026-02-19'),
    AiModelInfo(LlmProvider.anthropic, 'claude-3-5-sonnet-20241022',
        'Claude 3.5 Sonnet',
        lifecycle: ModelLifecycle.retired, retirement: '2025-10-28'),
    AiModelInfo(LlmProvider.groq, 'openai/gpt-oss-20b', 'GPT OSS 20B'),
    AiModelInfo(LlmProvider.groq, 'openai/gpt-oss-120b', 'GPT OSS 120B'),
    AiModelInfo(LlmProvider.groq, 'llama-3.3-70b-versatile', 'Llama 3.3 70B',
        offerNormally: false, accessNote: 'Enterprise access required.'),
    AiModelInfo(LlmProvider.groq, 'llama-3.1-8b-instant', 'Llama 3.1 8B',
        offerNormally: false, accessNote: 'Enterprise access required.'),
    AiModelInfo(LlmProvider.groq, 'qwen/qwen3.8-27b', 'Qwen 3.8 27B',
        lifecycle: ModelLifecycle.preview),
    AiModelInfo(LlmProvider.groq, 'minimaxai/minimax-m2.7', 'MiniMax M2.7',
        lifecycle: ModelLifecycle.preview,
        offerNormally: false,
        accessNote: 'Enterprise access required.'),
  ];

  static List<AiModelInfo> forProvider(LlmProvider provider) =>
      all.where((m) => m.provider == provider).toList(growable: false);
  static AiModelInfo? find(LlmProvider provider, String id) =>
      all.where((m) => m.provider == provider && m.id == id).firstOrNull;
  static List<String> choices(LlmProvider provider) => forProvider(provider)
      .where((m) => m.selectable)
      .map((m) => m.id)
      .toList(growable: false);
  static String label(LlmProvider provider, String id) =>
      find(provider, id)?.label ?? '$id — unverified model';
  static String note(LlmProvider provider, String id) {
    final info = find(provider, id);
    return [
      if (info != null && info.accessNote.isNotEmpty) info.accessNote,
      if (info?.retirement != null) 'Provider retirement: ${info!.retirement}.',
      if (info?.lifecycle == ModelLifecycle.preview)
        'Preview availability can change.',
      switch (provider) {
        LlmProvider.gemini =>
          'Eligible Developer API models have limited free access; Firebase setup and account quotas apply.',
        LlmProvider.groq =>
          'A limited free API tier exists; account limits and model access apply.',
        LlmProvider.openai ||
        LlmProvider.anthropic =>
          'Uses your own billed API account.',
        LlmProvider.custom =>
          'Endpoint compatibility, access and cost must be checked by its operator.',
      },
      info?.verificationNote ?? 'Not live-verified in WhatMeal.',
    ].join(' ');
  }

  /// Model discovery is restricted to the reviewed text protocol catalogue.
  /// Custom endpoints retain explicit IDs, with no compatibility guarantee.
  static List<String> filterDiscovered(
          LlmProvider provider, Iterable<String> ids) =>
      ids
          .where((id) =>
              provider == LlmProvider.custom ||
              find(provider, id)?.selectable == true)
          .toSet()
          .toList()
        ..sort();
}

import '../services/ai/model_registry.dart';

/// Supported AI providers for meal-plan generation.
///
/// Each value carries its own display metadata and hard-coded API endpoint
/// (except [custom], which uses a user-supplied endpoint) so the client
/// never needs to ask users to type a URL for built-in providers.
enum LlmProvider {
  gemini,
  openai,
  anthropic,
  groq,
  custom;

  // ---------------------------------------------------------------------------
  // Display metadata (used by the UI provider-picker cards)
  // ---------------------------------------------------------------------------

  /// Human-readable provider name shown on cards.
  String get displayName {
    switch (this) {
      case LlmProvider.gemini:
        return 'Gemini';
      case LlmProvider.openai:
        return 'ChatGPT (OpenAI)';
      case LlmProvider.anthropic:
        return 'Claude (Anthropic)';
      case LlmProvider.groq:
        return 'Groq';
      case LlmProvider.custom:
        return 'Custom API';
    }
  }

  /// One-line plain-language description shown on cards.
  String get description {
    switch (this) {
      case LlmProvider.gemini:
        return 'Built-in Gemini — configured provider quotas apply';
      case LlmProvider.openai:
        return 'Bring your own account — billed by OpenAI';
      case LlmProvider.anthropic:
        return 'Bring your own account — billed by Anthropic';
      case LlmProvider.groq:
        return 'Bring your own Groq account — tier limits apply';
      case LlmProvider.custom:
        return 'Any OpenAI-compatible endpoint you host';
    }
  }

  /// URL where users can create an API key for this provider.
  ///
  /// `null` for [LlmProvider.gemini] since it uses the built-in backend,
  /// and for [LlmProvider.custom] which has a user-supplied endpoint.
  String? get keyCreationUrl {
    switch (this) {
      case LlmProvider.gemini:
        return 'https://aistudio.google.com/app/apikey';
      case LlmProvider.openai:
        return 'https://platform.openai.com/api-keys';
      case LlmProvider.anthropic:
        return 'https://console.anthropic.com/settings/keys';
      case LlmProvider.groq:
        return 'https://console.groq.com/keys';
      case LlmProvider.custom:
        return null;
    }
  }

  /// The built-in API endpoint used when routing a request to this provider.
  ///
  /// - `null` for [LlmProvider.custom] (endpoint is stored in [LlmConfig.customEndpoint]).
  String? get endpoint {
    switch (this) {
      case LlmProvider.gemini:
        return 'https://generativelanguage.googleapis.com/v1beta/models';
      case LlmProvider.openai:
        return 'https://api.openai.com/v1/chat/completions';
      case LlmProvider.anthropic:
        return 'https://api.anthropic.com/v1/messages';
      case LlmProvider.groq:
        return 'https://api.groq.com/openai/v1/chat/completions';
      case LlmProvider.custom:
        return null;
    }
  }

  /// Serialisation key stored in Firestore.
  String get id =>
      name; // 'gemini' | 'openai' | 'anthropic' | 'groq' | 'custom'

  /// Whether this provider requires the user to supply their own API key.
  bool get requiresCustomKey => this != LlmProvider.gemini;

  /// Whether this provider uses an OpenAI-compatible chat completions endpoint.
  bool get isOpenAiCompatible =>
      this == LlmProvider.openai ||
      this == LlmProvider.groq ||
      this == LlmProvider.custom;

  /// Parse from the Firestore `provider` string. Returns [LlmProvider.gemini]
  /// as a safe default if the value is unrecognised.
  static LlmProvider fromId(String? id) {
    return LlmProvider.values.firstWhere(
      (p) => p.id == id,
      orElse: () => LlmProvider.gemini,
    );
  }
}

// ---------------------------------------------------------------------------

/// Configuration for a user's AI provider selection.
///
/// Stored at `users/{uid}/secrets/llmConfig` (owner-only Firestore access).
///
/// When [apiKey] is `null` (or [provider] is [LlmProvider.gemini]),
/// the app uses the built-in shared Gemini backend — no key needed.
class LlmConfig {
  LlmConfig({
    required this.provider,
    this.apiKey,
    this.model,
    this.customEndpoint,
    this.isOpenAiCompatible,
    this.updatedAt,
  });

  final LlmProvider provider;

  /// The user's custom API key. `null` means "use built-in Gemini default".
  final String? apiKey;

  /// Override model name for this provider.
  /// Defaults to the provider's [LlmProvider.defaultModel] when `null`.
  final String? model;

  /// Custom API endpoint, only used when [provider] is [LlmProvider.custom].
  final String? customEndpoint;

  /// Whether custom endpoint follows OpenAI-compatible protocol.
  final bool? isOpenAiCompatible;

  final DateTime? updatedAt;

  /// Whether this config represents a user-supplied custom key.
  bool get isCustom => apiKey != null && apiKey!.trim().isNotEmpty;

  /// Resolved API endpoint:
  /// - built-in endpoint for known providers
  /// - [customEndpoint] for [LlmProvider.custom]
  String? get resolvedEndpoint =>
      provider == LlmProvider.custom ? customEndpoint : provider.endpoint;

  factory LlmConfig.fromMap(Map<String, dynamic> data) {
    return LlmConfig(
      provider: LlmProvider.fromId(data['provider'] as String?),
      apiKey: data['apiKey'] as String?,
      model: data['model'] as String?,
      customEndpoint: data['customEndpoint'] as String?,
      isOpenAiCompatible: data['isOpenAiCompatible'] as bool? ?? true,
      updatedAt: data['updatedAt'] != null
          ? DateTime.tryParse(data['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'provider': provider.id,
        'apiKey': apiKey,
        'model': model,
        'customEndpoint': customEndpoint,
        'isOpenAiCompatible': isOpenAiCompatible ?? true,
        'updatedAt': DateTime.now().toIso8601String(),
      };

  /// Default config: built-in Gemini, no custom key.
  static LlmConfig get defaultConfig => LlmConfig(
        provider: LlmProvider.gemini,
        model: AiModelRegistry.defaultGemini,
      );
}

/// Supported AI providers for meal-plan generation.
///
/// Each value carries its own display metadata and hard-coded API endpoint
/// so the client never asks users to enter a URL.
enum LlmProvider {
  gemini,
  openai,
  anthropic;

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
    }
  }

  /// One-line plain-language description shown on cards.
  String get description {
    switch (this) {
      case LlmProvider.gemini:
        return 'Free, built in — works right away';
      case LlmProvider.openai:
        return 'Bring your own account — billed by OpenAI';
      case LlmProvider.anthropic:
        return 'Bring your own account — billed by Anthropic';
    }
  }

  /// URL where users can create an API key for this provider.
  ///
  /// `null` for [LlmProvider.gemini] since it uses the built-in backend.
  String? get keyCreationUrl {
    switch (this) {
      case LlmProvider.gemini:
        return null;
      case LlmProvider.openai:
        return 'https://platform.openai.com/api-keys';
      case LlmProvider.anthropic:
        return 'https://console.anthropic.com/settings/keys';
    }
  }

  /// The API endpoint used internally when routing a request to this provider.
  ///
  /// `null` for [LlmProvider.gemini] since it uses Firebase AI Logic.
  String? get endpoint {
    switch (this) {
      case LlmProvider.gemini:
        return null;
      case LlmProvider.openai:
        return 'https://api.openai.com/v1/chat/completions';
      case LlmProvider.anthropic:
        return 'https://api.anthropic.com/v1/messages';
    }
  }

  /// Serialisation key stored in Firestore.
  String get id => name; // 'gemini' | 'openai' | 'anthropic'

  /// Whether this provider requires the user to supply their own API key.
  bool get requiresCustomKey => this != LlmProvider.gemini;

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
    this.updatedAt,
  });

  final LlmProvider provider;

  /// The user's custom API key. `null` means "use built-in Gemini default".
  final String? apiKey;

  final DateTime? updatedAt;

  /// Whether this config represents a user-supplied custom key.
  bool get isCustom =>
      provider.requiresCustomKey && apiKey != null && apiKey!.isNotEmpty;

  factory LlmConfig.fromMap(Map<String, dynamic> data) {
    return LlmConfig(
      provider: LlmProvider.fromId(data['provider'] as String?),
      apiKey: data['apiKey'] as String?,
      updatedAt: data['updatedAt'] != null
          ? DateTime.tryParse(data['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'provider': provider.id,
    'apiKey': apiKey,
    'updatedAt': DateTime.now().toIso8601String(),
  };

  /// Default config: built-in Gemini, no custom key.
  static LlmConfig get defaultConfig => LlmConfig(provider: LlmProvider.gemini);
}

enum AiProviderType {
  openAi,
  gemini,
  claude,
  groq,
  custom,
}

extension AiProviderTypeX on AiProviderType {
  String get displayName {
    switch (this) {
      case AiProviderType.openAi:
        return 'OpenAI (GPT-4o)';
      case AiProviderType.gemini:
        return 'Google Gemini';
      case AiProviderType.claude:
        return 'Anthropic Claude';
      case AiProviderType.groq:
        return 'Groq Llama 3.3';
      case AiProviderType.custom:
        return 'Custom OpenAI-Compatible API';
    }
  }

  String get defaultModel {
    switch (this) {
      case AiProviderType.openAi:
        return 'gpt-4o-mini';
      case AiProviderType.gemini:
        return 'gemini-1.5-flash';
      case AiProviderType.claude:
        return 'claude-3-5-sonnet-20241022';
      case AiProviderType.groq:
        return 'llama-3.3-70b-versatile';
      case AiProviderType.custom:
        return 'v1/chat/completions';
    }
  }
}

enum ApiConnectionStatus {
  notConfigured,
  testing,
  connected,
  failed,
}

class AiProviderConfig {
  const AiProviderConfig({
    required this.providerType,
    required this.selectedModel,
    this.apiKey,
    this.customEndpoint,
    this.status = ApiConnectionStatus.notConfigured,
    this.statusMessage,
  });

  final AiProviderType providerType;
  final String selectedModel;
  final String? apiKey;
  final String? customEndpoint;
  final ApiConnectionStatus status;
  final String? statusMessage;

  String get maskedApiKey {
    if (apiKey == null || apiKey!.isEmpty) return 'No API Key set';
    if (apiKey!.length <= 8) return '••••••••';
    final prefix = apiKey!.substring(0, 4);
    final suffix = apiKey!.substring(apiKey!.length - 4);
    return '$prefix••••••••$suffix';
  }

  AiProviderConfig copyWith({
    AiProviderType? providerType,
    String? selectedModel,
    String? apiKey,
    String? customEndpoint,
    ApiConnectionStatus? status,
    String? statusMessage,
  }) {
    return AiProviderConfig(
      providerType: providerType ?? this.providerType,
      selectedModel: selectedModel ?? this.selectedModel,
      apiKey: apiKey ?? this.apiKey,
      customEndpoint: customEndpoint ?? this.customEndpoint,
      status: status ?? this.status,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

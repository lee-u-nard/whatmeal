import 'package:flutter/material.dart';
import '../../../core/models/llm_config.dart';
import '../../../core/services/ai/model_registry.dart';
import '../../../core/theme/app_theme.dart';

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
        return 'OpenAI (GPT)';
      case AiProviderType.gemini:
        return 'Google Gemini';
      case AiProviderType.claude:
        return 'Anthropic Claude';
      case AiProviderType.groq:
        return 'Groq';
      case AiProviderType.custom:
        return 'Custom API';
    }
  }

  String get defaultModel {
    switch (this) {
      case AiProviderType.openAi:
        return 'gpt-4.1-mini';
      case AiProviderType.gemini:
        return AiModelRegistry.defaultGemini;
      case AiProviderType.claude:
        return 'claude-haiku-4-5';
      case AiProviderType.groq:
        return 'openai/gpt-oss-20b';
      case AiProviderType.custom:
        return 'default';
    }
  }

  /// Available model choices for this provider shown in the model selector.
  List<String> get availableModels => AiModelRegistry.choices(toLlmProvider);

  /// Whether this provider requires the user to enter an API key.
  bool get requiresApiKey => this != AiProviderType.gemini;

  /// Whether this provider needs a custom endpoint URL field.
  bool get needsCustomEndpoint => this == AiProviderType.custom;

  /// Map to the core [LlmProvider] enum.
  LlmProvider get toLlmProvider {
    switch (this) {
      case AiProviderType.openAi:
        return LlmProvider.openai;
      case AiProviderType.gemini:
        return LlmProvider.gemini;
      case AiProviderType.claude:
        return LlmProvider.anthropic;
      case AiProviderType.groq:
        return LlmProvider.groq;
      case AiProviderType.custom:
        return LlmProvider.custom;
    }
  }
}

enum ApiConnectionStatus {
  configured,
  notConfigured,
  testing,
  connected,
  invalidKey,
  invalidModel,
  invalidEndpoint,
  configurationError,
  authenticationRequired,
  permissionDenied,
  rateLimited,
  networkError,
  providerUnavailable,
  failed,
}

extension ApiConnectionStatusX on ApiConnectionStatus {
  String get label {
    switch (this) {
      case ApiConnectionStatus.configured:
        return 'Configured - not tested';
      case ApiConnectionStatus.notConfigured:
        return 'Not Configured';
      case ApiConnectionStatus.testing:
        return 'Testing Connection...';
      case ApiConnectionStatus.connected:
        return 'Connected';
      case ApiConnectionStatus.invalidKey:
        return 'Invalid API Key';
      case ApiConnectionStatus.invalidModel:
        return 'Invalid Model';
      case ApiConnectionStatus.invalidEndpoint:
        return 'Invalid Endpoint';
      case ApiConnectionStatus.configurationError:
        return 'Configuration Required';
      case ApiConnectionStatus.authenticationRequired:
        return 'Authentication Required';
      case ApiConnectionStatus.permissionDenied:
        return 'Permission Denied';
      case ApiConnectionStatus.rateLimited:
        return 'Rate Limited';
      case ApiConnectionStatus.networkError:
        return 'Network Error';
      case ApiConnectionStatus.providerUnavailable:
        return 'Provider Unavailable';
      case ApiConnectionStatus.failed:
        return 'Connection Failed';
    }
  }

  Color get color {
    switch (this) {
      case ApiConnectionStatus.connected:
        return AppColors.primary;
      case ApiConnectionStatus.testing:
        return AppColors.info;
      case ApiConnectionStatus.rateLimited:
        return AppColors.warning;
      case ApiConnectionStatus.configured:
      case ApiConnectionStatus.notConfigured:
        return AppColors.textMuted;
      default:
        return AppColors.danger;
    }
  }
}

class AiProviderConfig {
  const AiProviderConfig({
    required this.providerType,
    required this.selectedModel,
    this.apiKey,
    this.customEndpoint,
    this.isOpenAiCompatible = true,
    this.status = ApiConnectionStatus.notConfigured,
    this.statusMessage,
    this.fetchedModels,
  });

  final AiProviderType providerType;
  final String selectedModel;
  final String? apiKey;
  final String? customEndpoint;
  final bool isOpenAiCompatible;
  final ApiConnectionStatus status;
  final String? statusMessage;

  /// Live model list fetched from the provider's /models endpoint.
  /// `null` means not yet loaded; empty list means loaded but none found.
  final List<String>? fetchedModels;

  /// Credentials belong to a provider, never to the next dropdown selection.
  AiProviderConfig forProvider(AiProviderType type) {
    if (type == providerType) return this;
    final isGemini = type == AiProviderType.gemini;
    return AiProviderConfig(
      providerType: type,
      selectedModel: type.defaultModel,
      status: isGemini
          ? ApiConnectionStatus.configured
          : ApiConnectionStatus.notConfigured,
      statusMessage: isGemini
          ? 'Using built-in Gemini (no key required)'
          : 'API Key required for ${type.displayName}',
    );
  }

  /// The model list shown in the dropdown: prefer fetched live list,
  /// fall back to the static list baked into the provider type.
  List<String> get effectiveModels => fetchedModels == null
      ? providerType.availableModels
      : AiModelRegistry.filterDiscovered(
          providerType.toLlmProvider, fetchedModels!);

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
    bool? isOpenAiCompatible,
    ApiConnectionStatus? status,
    String? statusMessage,
    List<String>? fetchedModels,
    bool clearFetchedModels = false,
  }) {
    return AiProviderConfig(
      providerType: providerType ?? this.providerType,
      selectedModel: selectedModel ?? this.selectedModel,
      apiKey: apiKey ?? this.apiKey,
      customEndpoint: customEndpoint ?? this.customEndpoint,
      isOpenAiCompatible: isOpenAiCompatible ?? this.isOpenAiCompatible,
      status: status ?? this.status,
      statusMessage: statusMessage ?? this.statusMessage,
      fetchedModels:
          clearFetchedModels ? null : fetchedModels ?? this.fetchedModels,
    );
  }
}

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../core/models/llm_config.dart';
import '../../../core/models/app_notification.dart';
import '../../../core/services/llm_service.dart';
import '../../../core/services/ai/ai_models.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/household_notification_service.dart';
import '../../auth/data/auth_repository.dart';
import '../models/ai_provider.dart';

class AiProviderRepository extends ValueNotifier<AiProviderConfig> {
  AiProviderRepository._()
      : super(
          const AiProviderConfig(
            providerType: AiProviderType.gemini,
            selectedModel: 'gemini-3.8-flash',
            status: ApiConnectionStatus.connected,
            statusMessage: 'Using built-in Gemini (no key required)',
          ),
        ) {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _uid = user?.uid;
      if (_uid != null) {
        _loadFromFirestore();
      } else {
        value = const AiProviderConfig(
          providerType: AiProviderType.gemini,
          selectedModel: 'gemini-3.8-flash',
          status: ApiConnectionStatus.connected,
          statusMessage: 'Using built-in Gemini (no key required)',
        );
      }
    });
  }

  static final instance = AiProviderRepository._();

  final _llm = LlmService();
  String? _uid;
  StreamSubscription<User?>? _authSub;

  Future<void> _loadFromFirestore() async {
    if (_uid == null) return;
    try {
      final config = await _llm.getLlmConfig(_uid!);
      value = _fromLlmConfig(config);
    } catch (e) {
      debugPrint('[AiProviderRepo] Load failed: $e');
    }
  }

  Future<void> _saveToFirestore(LlmConfig config) async {
    if (_uid == null) return;
    try {
      await _llm.saveLlmConfig(_uid!, config);
    } catch (e) {
      debugPrint('[AiProviderRepo] Save failed: $e');
    }
  }

  AiProviderConfig _fromLlmConfig(LlmConfig config) {
    final type = _uiTypeFrom(config.provider);
    final hasKey = config.apiKey != null && config.apiKey!.isNotEmpty;
    final isBuiltIn = config.provider == LlmProvider.gemini && !config.isCustom;
    return AiProviderConfig(
      providerType: type,
      selectedModel: config.model ?? type.defaultModel,
      apiKey: config.apiKey,
      customEndpoint: config.customEndpoint,
      isOpenAiCompatible: config.isOpenAiCompatible ?? true,
      status: isBuiltIn
          ? ApiConnectionStatus.connected
          : (hasKey
              ? ApiConnectionStatus.connected
              : ApiConnectionStatus.notConfigured),
      statusMessage: isBuiltIn
          ? 'Using built-in Gemini (no key required)'
          : (hasKey
              ? 'API key loaded from saved settings'
              : 'API Key required for ${type.displayName}'),
    );
  }

  AiProviderType _uiTypeFrom(LlmProvider p) {
    switch (p) {
      case LlmProvider.openai:
        return AiProviderType.openAi;
      case LlmProvider.anthropic:
        return AiProviderType.claude;
      case LlmProvider.groq:
        return AiProviderType.groq;
      case LlmProvider.custom:
        return AiProviderType.custom;
      case LlmProvider.gemini:
        return AiProviderType.gemini;
    }
  }

  void selectProvider(AiProviderType type) {
    final oldProvider = value.providerType;
    final llmProvider = type.toLlmProvider;
    final isGemini = llmProvider == LlmProvider.gemini;

    // When switching to Gemini, default to built-in free Gemini (no key required)
    final keyToKeep = isGemini ? null : value.apiKey;
    final hasKey = keyToKeep != null && keyToKeep.isNotEmpty;

    value = AiProviderConfig(
      providerType: type,
      selectedModel: type.defaultModel,
      apiKey: keyToKeep,
      customEndpoint: isGemini ? null : value.customEndpoint,
      isOpenAiCompatible: value.isOpenAiCompatible,
      fetchedModels: null,
      status: isGemini
          ? ApiConnectionStatus.connected
          : (hasKey
              ? ApiConnectionStatus.connected
              : ApiConnectionStatus.notConfigured),
      statusMessage: isGemini
          ? 'Using built-in Gemini (no key required)'
          : (hasKey
              ? 'Switched to ${type.displayName}'
              : 'API Key required for ${type.displayName}'),
    );
    _persist();

    // Send household notification when provider changes
    if (oldProvider != type) {
      HouseholdNotificationService.instance.notifyAiProviderChanged(
        action: 'changed',
        providerName: type.displayName,
      );
    }
  }

  void setApiKey(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      removeKey();
      return;
    }
    value = value.copyWith(
      apiKey: trimmed,
      status: ApiConnectionStatus.connected,
      statusMessage: 'Key saved — tap "Test Connection" to verify',
    );
    _persist();
  }

  void setCustomEndpoint(String endpoint) {
    value = value.copyWith(customEndpoint: endpoint.trim());
    _persist();
  }

  void setOpenAiCompatible(bool compatible) {
    value = value.copyWith(isOpenAiCompatible: compatible);
    _persist();
  }

  void updateModel(String model) {
    value = value.copyWith(selectedModel: model.trim());
    _persist();
  }

  Future<void> testConnection() async {
    value = value.copyWith(
      status: ApiConnectionStatus.testing,
      statusMessage:
          'Testing connection to ${value.providerType.displayName}...',
    );
    final llmProvider = value.providerType.toLlmProvider;
    final apiKey = value.apiKey ?? '';
    try {
      final result = await _llm.validateKey(
        llmProvider,
        apiKey,
        customEndpoint: value.customEndpoint,
        model: value.selectedModel,
        isOpenAiCompatible: value.isOpenAiCompatible,
      );
      if (result.isValid) {
        value = value.copyWith(
          status: ApiConnectionStatus.connected,
          statusMessage:
              'Connection successful! ${value.providerType.displayName} is ready.',
        );
        final uid = AuthRepository.instance.currentUser?.uid;
        if (uid != null) {
          NotificationService.instance.push(
            uid,
            'AI Provider Connected',
            '${value.providerType.displayName} is ready for meal generation.',
            AppNotificationType.aiSuccess,
          );
        }
      } else {
        value = value.copyWith(
          status: _mapStatus(result.status),
          statusMessage: result.errorMessage ?? 'Validation failed.',
        );
        final uid = AuthRepository.instance.currentUser?.uid;
        if (uid != null) {
          NotificationService.instance.push(
            uid,
            'AI Provider Connection Failed',
            result.errorMessage ??
                'Could not connect to ${value.providerType.displayName}.',
            AppNotificationType.aiSuccess,
          );
        }
      }
    } catch (_) {
      value = value.copyWith(
        status: ApiConnectionStatus.networkError,
        statusMessage:
            "Couldn't reach the server. Check your internet connection.",
      );
    }
  }

  ApiConnectionStatus _mapStatus(TestConnectionStatus status) {
    switch (status) {
      case TestConnectionStatus.connected:
        return ApiConnectionStatus.connected;
      case TestConnectionStatus.invalidKey:
        return ApiConnectionStatus.invalidKey;
      case TestConnectionStatus.invalidModel:
        return ApiConnectionStatus.invalidModel;
      case TestConnectionStatus.invalidEndpoint:
        return ApiConnectionStatus.invalidEndpoint;
      case TestConnectionStatus.rateLimited:
        return ApiConnectionStatus.rateLimited;
      case TestConnectionStatus.networkError:
        return ApiConnectionStatus.networkError;
      case TestConnectionStatus.providerUnavailable:
        return ApiConnectionStatus.providerUnavailable;
    }
  }

  /// Fetches the live list of models from the provider API using the user's actual API key.
  Future<void> fetchModels() async {
    final apiKey = value.apiKey ?? '';
    if (apiKey.isEmpty && value.providerType != AiProviderType.gemini) return;

    value = value.copyWith(
      status: ApiConnectionStatus.testing,
      statusMessage: 'Loading available models...',
    );

    try {
      final models = await _llm.fetchAvailableModels(
        provider: value.providerType.toLlmProvider,
        apiKey: apiKey,
        customEndpoint: value.customEndpoint,
        isOpenAiCompatible: value.isOpenAiCompatible,
      );

      if (models.isEmpty) {
        value = value.copyWith(
          status: ApiConnectionStatus.failed,
          statusMessage: 'No chat models found. Check your API key or plan.',
          fetchedModels: [],
        );
        return;
      }

      final newModel = models.contains(value.selectedModel)
          ? value.selectedModel
          : models.first;

      value = value.copyWith(
        fetchedModels: models,
        selectedModel: newModel,
        status: ApiConnectionStatus.connected,
        statusMessage: 'Found ${models.length} model(s). Using "$newModel".',
      );
      _persist();
    } catch (e) {
      value = value.copyWith(
        status: ApiConnectionStatus.failed,
        statusMessage: 'Failed to load models: ${e.toString()}',
      );
    }
  }

  void removeKey() {
    value = const AiProviderConfig(
      providerType: AiProviderType.gemini,
      selectedModel: 'gemini-3.8-flash',
      apiKey: null,
      customEndpoint: null,
      fetchedModels: null,
      status: ApiConnectionStatus.connected,
      statusMessage: 'Using built-in Gemini (no key required)',
    );
    if (_uid != null) {
      _llm.clearLlmConfig(_uid!);
    }
    _persist();
  }

  void _persist() {
    _saveToFirestore(LlmConfig(
      provider: value.providerType.toLlmProvider,
      apiKey: value.apiKey,
      model: value.selectedModel,
      customEndpoint: value.customEndpoint,
      isOpenAiCompatible: value.isOpenAiCompatible,
    ));
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

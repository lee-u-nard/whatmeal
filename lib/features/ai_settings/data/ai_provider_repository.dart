import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../core/models/llm_config.dart';
import '../../../core/services/llm_service.dart';
import '../models/ai_provider.dart';

class AiProviderRepository extends ValueNotifier<AiProviderConfig> {
  AiProviderRepository._()
      : super(
          const AiProviderConfig(
            providerType: AiProviderType.gemini,
            selectedModel: 'gemini-flash-latest',
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
          selectedModel: 'gemini-flash-latest',
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
    } catch (_) {}
  }

  Future<void> _saveToFirestore(LlmConfig config) async {
    if (_uid == null) return;
    try {
      await _llm.saveLlmConfig(_uid!, config);
    } catch (_) {}
  }

  AiProviderConfig _fromLlmConfig(LlmConfig config) {
    final type = _providerTypeFromLlm(config.provider);
    final hasKey = config.apiKey != null && config.apiKey!.isNotEmpty;
    final isBuiltIn = config.provider == LlmProvider.gemini;
    return AiProviderConfig(
      providerType: type,
      selectedModel: type.defaultModel,
      apiKey: config.apiKey,
      status: isBuiltIn
          ? ApiConnectionStatus.connected
          : (hasKey ? ApiConnectionStatus.connected : ApiConnectionStatus.notConfigured),
      statusMessage: isBuiltIn
          ? 'Using built-in Gemini (no key required)'
          : (hasKey ? 'API key loaded from saved settings' : 'API Key required for ${type.displayName}'),
    );
  }

  AiProviderType _providerTypeFromLlm(LlmProvider p) {
    switch (p) {
      case LlmProvider.openai:
        return AiProviderType.openAi;
      case LlmProvider.anthropic:
        return AiProviderType.claude;
      case LlmProvider.gemini:
        return AiProviderType.gemini;
    }
  }

  LlmProvider _llmProviderFrom(AiProviderType type) {
    switch (type) {
      case AiProviderType.openAi:
        return LlmProvider.openai;
      case AiProviderType.claude:
        return LlmProvider.anthropic;
      case AiProviderType.gemini:
      case AiProviderType.groq:
      case AiProviderType.custom:
        return LlmProvider.gemini;
    }
  }

  void selectProvider(AiProviderType type) {
    final llmProvider = _llmProviderFrom(type);
    final isBuiltIn = llmProvider == LlmProvider.gemini;
    value = value.copyWith(
      providerType: type,
      selectedModel: type.defaultModel,
      status: isBuiltIn
          ? ApiConnectionStatus.connected
          : (value.apiKey != null && value.apiKey!.isNotEmpty
              ? ApiConnectionStatus.connected
              : ApiConnectionStatus.notConfigured),
      statusMessage: isBuiltIn
          ? 'Using built-in Gemini (no key required)'
          : (value.apiKey != null && value.apiKey!.isNotEmpty
              ? 'Switched to ${type.displayName}'
              : 'API Key required for ${type.displayName}'),
    );
    _saveToFirestore(LlmConfig(provider: llmProvider, apiKey: isBuiltIn ? null : value.apiKey));
  }

  void setApiKey(String key) {
    final trimmed = key.trim();
    final llmProvider = _llmProviderFrom(value.providerType);
    if (trimmed.isEmpty) {
      value = value.copyWith(
        apiKey: null,
        status: llmProvider == LlmProvider.gemini
            ? ApiConnectionStatus.connected
            : ApiConnectionStatus.notConfigured,
        statusMessage: llmProvider == LlmProvider.gemini
            ? 'Using built-in Gemini (no key required)'
            : 'API Key removed',
      );
    } else {
      value = value.copyWith(
        apiKey: trimmed,
        status: ApiConnectionStatus.connected,
        statusMessage: 'Key saved — tap "Test Connection" to verify',
      );
    }
    _saveToFirestore(LlmConfig(provider: llmProvider, apiKey: trimmed.isEmpty ? null : trimmed));
  }

  void updateModel(String model) {
    value = value.copyWith(selectedModel: model);
  }

  Future<void> testConnection() async {
    value = value.copyWith(
      status: ApiConnectionStatus.testing,
      statusMessage: 'Testing connection to ${value.providerType.displayName}...',
    );
    final llmProvider = _llmProviderFrom(value.providerType);
    final apiKey = value.apiKey ?? '';
    try {
      final result = await _llm.validateKey(llmProvider, apiKey);
      if (result.isValid) {
        value = value.copyWith(
          status: ApiConnectionStatus.connected,
          statusMessage: 'Connection successful! ${value.providerType.displayName} is ready.',
        );
      } else {
        value = value.copyWith(
          status: ApiConnectionStatus.failed,
          statusMessage: result.errorMessage ?? 'Validation failed.',
        );
      }
    } catch (_) {
      value = value.copyWith(
        status: ApiConnectionStatus.failed,
        statusMessage: "Couldn't reach the server. Check your internet connection.",
      );
    }
  }

  void removeKey() {
    final llmProvider = _llmProviderFrom(value.providerType);
    value = value.copyWith(
      apiKey: null,
      status: llmProvider == LlmProvider.gemini
          ? ApiConnectionStatus.connected
          : ApiConnectionStatus.notConfigured,
      statusMessage: llmProvider == LlmProvider.gemini
          ? 'Using built-in Gemini (no key required)'
          : 'API key cleared',
    );
    _saveToFirestore(LlmConfig(provider: llmProvider, apiKey: null));
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

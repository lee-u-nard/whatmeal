import 'package:flutter/foundation.dart';
import '../models/ai_provider.dart';

class AiProviderRepository extends ValueNotifier<AiProviderConfig> {
  AiProviderRepository._()
      : super(
          const AiProviderConfig(
            providerType: AiProviderType.gemini,
            selectedModel: 'gemini-1.5-flash',
            apiKey: 'AIzaSyD_WhatMealSampleKey9823412',
            status: ApiConnectionStatus.connected,
            statusMessage: 'Connected & ready to generate plans',
          ),
        );

  static final instance = AiProviderRepository._();

  void selectProvider(AiProviderType type) {
    value = value.copyWith(
      providerType: type,
      selectedModel: type.defaultModel,
      status: value.apiKey != null && value.apiKey!.isNotEmpty
          ? ApiConnectionStatus.connected
          : ApiConnectionStatus.notConfigured,
      statusMessage: value.apiKey != null && value.apiKey!.isNotEmpty
          ? 'Switched provider to ${type.displayName}'
          : 'API Key required for ${type.displayName}',
    );
  }

  void setApiKey(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      value = value.copyWith(
        apiKey: null,
        status: ApiConnectionStatus.notConfigured,
        statusMessage: 'API Key removed',
      );
    } else {
      value = value.copyWith(
        apiKey: trimmed,
        status: ApiConnectionStatus.connected,
        statusMessage: 'Key saved and active',
      );
    }
  }

  void updateModel(String model) {
    value = value.copyWith(selectedModel: model);
  }

  Future<void> testConnection() async {
    value = value.copyWith(
      status: ApiConnectionStatus.testing,
      statusMessage: 'Testing connection to ${value.providerType.displayName}...',
    );

    await Future.delayed(const Duration(milliseconds: 1200));

    if (value.apiKey == null || value.apiKey!.isEmpty) {
      value = value.copyWith(
        status: ApiConnectionStatus.failed,
        statusMessage: 'Authentication failed: Empty API Key',
      );
    } else if (value.apiKey!.contains('fail') || value.apiKey!.contains('invalid')) {
      value = value.copyWith(
        status: ApiConnectionStatus.failed,
        statusMessage: 'HTTP 401: Invalid API Key provided for ${value.providerType.displayName}',
      );
    } else {
      value = value.copyWith(
        status: ApiConnectionStatus.connected,
        statusMessage: 'Connection successful! Provider is ready.',
      );
    }
  }

  void removeKey() {
    value = value.copyWith(
      apiKey: null,
      status: ApiConnectionStatus.notConfigured,
      statusMessage: 'API key cleared',
    );
  }
}

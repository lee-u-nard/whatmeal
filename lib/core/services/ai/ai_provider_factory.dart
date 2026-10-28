import '../../models/llm_config.dart';
import 'ai_provider_adapter.dart';
import 'adapters/gemini_adapter.dart';
import 'adapters/openai_adapter.dart';
import 'adapters/anthropic_adapter.dart';
import 'adapters/groq_adapter.dart';
import 'adapters/custom_adapter.dart';
import 'model_registry.dart';
import 'generation_failure.dart';

/// Factory class to instantiate the appropriate [AiProviderAdapter] for a given [LlmConfig].
class AiProviderFactory {
  AiProviderFactory._();

  static AiProviderAdapter create(LlmConfig config) {
    validate(config);
    final selectedModel = config.model?.trim();
    final model =
        selectedModel == null || selectedModel.isEmpty ? null : selectedModel;
    switch (config.provider) {
      case LlmProvider.gemini:
        return GeminiAdapter(
          apiKey: config.apiKey,
          model: model,
        );
      case LlmProvider.openai:
        return OpenAiAdapter(
          apiKey: config.apiKey ?? '',
          model: model,
          customEndpoint: config.customEndpoint,
        );
      case LlmProvider.anthropic:
        return AnthropicAdapter(
          apiKey: config.apiKey ?? '',
          model: model,
        );
      case LlmProvider.groq:
        return GroqAdapter(
          apiKey: config.apiKey ?? '',
          model: model,
        );
      case LlmProvider.custom:
        return CustomAdapter(
          endpoint: config.customEndpoint ?? '',
          apiKey: config.apiKey,
          model: model,
          isOpenAiCompatible: config.isOpenAiCompatible ?? true,
        );
    }
  }

  /// Reject invalid saved combinations before any credential leaves the app.
  /// A newly discovered model is not an automatic claim of protocol support.
  static void validate(LlmConfig config) {
    final id = config.model?.trim();
    if (id != null && id.isNotEmpty) {
      final known = AiModelRegistry.find(config.provider, id);
      if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:/-]*$').hasMatch(id) ||
          (known != null && !known.availableOn(DateTime.now())) ||
          (known == null && config.provider != LlmProvider.custom)) {
        throw const GenerationFailure(GenerationFailureKind.invalidModel);
      }
      if (config.provider == LlmProvider.gemini &&
          id == 'gemini-3.1-pro-preview') {
        throw const GenerationFailure(GenerationFailureKind.configuration);
      }
    }
    if (config.provider != LlmProvider.gemini &&
        config.provider != LlmProvider.custom &&
        !config.isCustom) {
      throw const GenerationFailure(GenerationFailureKind.configuration);
    }
  }
}

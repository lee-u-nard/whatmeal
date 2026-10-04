import '../../models/llm_config.dart';
import 'ai_provider_adapter.dart';
import 'adapters/gemini_adapter.dart';
import 'adapters/openai_adapter.dart';
import 'adapters/anthropic_adapter.dart';
import 'adapters/groq_adapter.dart';
import 'adapters/custom_adapter.dart';

/// Factory class to instantiate the appropriate [AiProviderAdapter] for a given [LlmConfig].
class AiProviderFactory {
  AiProviderFactory._();

  static AiProviderAdapter create(LlmConfig config) {
    switch (config.provider) {
      case LlmProvider.gemini:
        return GeminiAdapter(
          apiKey: config.apiKey,
          model: config.model,
        );
      case LlmProvider.openai:
        return OpenAiAdapter(
          apiKey: config.apiKey ?? '',
          model: config.model,
          customEndpoint: config.customEndpoint,
        );
      case LlmProvider.anthropic:
        return AnthropicAdapter(
          apiKey: config.apiKey ?? '',
          model: config.model,
        );
      case LlmProvider.groq:
        return GroqAdapter(
          apiKey: config.apiKey ?? '',
          model: config.model,
        );
      case LlmProvider.custom:
        return CustomAdapter(
          endpoint: config.customEndpoint ?? '',
          apiKey: config.apiKey,
          model: config.model,
          isOpenAiCompatible: config.isOpenAiCompatible ?? true,
        );
    }
  }
}

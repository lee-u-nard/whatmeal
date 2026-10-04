import '../../models/llm_config.dart';
import 'ai_models.dart';

/// Common interface for WhatMeal AI provider adapters.
///
/// Encapsulates all provider-specific HTTP calls, authentication headers,
/// model negotiation, and error handling, while exposing normalized request/response
/// methods to the rest of the application.
abstract class AiProviderAdapter {
  /// The provider enum this adapter implements.
  LlmProvider get provider;

  /// The active model configured for this adapter.
  String get model;

  /// Tests that the API key, model ID, and endpoint are valid and accessible.
  /// Does not succeed unless the model can actually produce a test output.
  Future<TestConnectionResult> testConnection();

  /// Generates a normalized meal plan for the given household context.
  Future<AiMealPlanResponse> generateMealPlan(AiMealPlanRequest request);

  /// Generates a replacement meal for a single meal slot.
  Future<AiMealResponse> generateMealReplacement(
      AiMealReplacementRequest request);

  /// Optionally fetches the list of chat-compatible models currently accessible
  /// to the account. Returns an empty list if not supported by the provider.
  Future<List<String>> fetchAvailableModels() async => [];
}

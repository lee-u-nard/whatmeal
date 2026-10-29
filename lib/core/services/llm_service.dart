import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/llm_config.dart';
import '../../features/meal/models/meal.dart';
import 'ai/ai_models.dart';
import 'ai/generation_failure.dart';
import 'ai/ingredient_restrictions.dart';
import 'ai/ai_provider_factory.dart';
import 'ai/ai_provider_adapter.dart';
import 'ai/ai_logger.dart';
import 'secure_key_store.dart';
import 'ai_quota_store.dart';
import '../config/runtime_environment.dart';
import 'ai/live_ai_policy.dart';

// ---------------------------------------------------------------------------
// Result wrapper
// ---------------------------------------------------------------------------

/// Wraps the result of an AI generation call with metadata about how the
/// request was fulfilled (provider used, remaining Gemini quota).
class AiResult<T> {
  AiResult({
    required this.data,
    this.usedFallback = false,
    this.quotaRemaining,
    this.providerUsed,
    required this.modelUsed,
  });

  /// The generated data.
  final T data;

  /// Whether fallback was used.
  final bool usedFallback;

  /// How many built-in Gemini generations remain today.
  /// `null` when fulfilled by a custom provider key.
  final int? quotaRemaining;

  /// Which provider fulfilled the request.
  final LlmProvider? providerUsed;

  /// Exact model ID requested from the adapter that fulfilled the operation.
  final String modelUsed;

  /// Both plan generation and replacement disclose an automatic provider change.
  String? get fallbackNotice => usedFallback
      ? 'Your selected AI provider failed. Used ${providerUsed?.displayName ?? 'AI'} ($modelUsed) instead.'
      : null;
}

// ---------------------------------------------------------------------------
// Quota constants
// ---------------------------------------------------------------------------

/// Maximum number of built-in Gemini requests allowed per user per day.
const int kDailyQuotaLimit = 10;

// ---------------------------------------------------------------------------
// Key-validation result
// ---------------------------------------------------------------------------

class KeyValidationResult {
  const KeyValidationResult({
    required this.isValid,
    this.errorMessage,
    this.status = TestConnectionStatus.connected,
  });

  final bool isValid;
  final TestConnectionStatus status;

  /// Plain-language error message shown to the user on failure. `null` on success.
  final String? errorMessage;
}

// ---------------------------------------------------------------------------
// LlmService
// ---------------------------------------------------------------------------

/// AI-powered meal planning service.
///
/// Routing behavior:
///  - If user configured a custom key (OpenAI / Anthropic / Groq / Custom), the active
///    adapter for that provider is invoked. If it fails, built-in Gemini is tried
///    with its own quota and an explicit fallback notice. If both fail, a safe
///    [AiProviderException] allows Retry or Settings editing.
///  - If user has no custom key (or provider is Gemini), uses WhatMeal's built-in
///    Firebase AI Logic Gemini engine, subject to [kDailyQuotaLimit] per day.
///  - When the user removes a custom key, the active provider automatically reverts
///    to default built-in Gemini.
class LlmService {
  LlmService({
    FirebaseFirestore? firestore,
    Future<LlmConfig> Function(String uid)? readConfig,
    AiProviderAdapter Function(LlmConfig config)? createAdapter,
    Future<int?> Function(String uid, int limit)? reserveQuota,
    Future<int> Function(String uid, int limit)? remainingQuota,
  })  : _injectedFirestore = firestore,
        _readConfig = readConfig,
        _createAdapter = createAdapter ?? AiProviderFactory.create,
        _reserveQuotaOverride = reserveQuota,
        _remainingQuotaOverride = remainingQuota;

  final FirebaseFirestore? _injectedFirestore;
  final Future<LlmConfig> Function(String uid)? _readConfig;
  final AiProviderAdapter Function(LlmConfig config) _createAdapter;
  final Future<int?> Function(String uid, int limit)? _reserveQuotaOverride;
  final Future<int> Function(String uid, int limit)? _remainingQuotaOverride;

  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  AiProviderAdapter _adapterFor(LlmConfig config) {
    AiProviderFactory.validate(config);
    return _createAdapter(config);
  }

  // ---------------------------------------------------------------------------
  // Provider config — Firestore persistence
  // ---------------------------------------------------------------------------

  /// Read the user's stored [LlmConfig] from Firestore secrets.
  ///
  /// Keys live only at `users/{uid}/secrets/llmConfig` (owner-only rules)
  /// and are never logged. A short-lived memory cache speeds up repeats.
  Future<LlmConfig> getLlmConfig(String uid) async {
    if (_readConfig != null) return _readConfig!(uid);
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('secrets')
        .doc('llmConfig')
        .get();
    if (!doc.exists) return LlmConfig.defaultConfig;

    final config = LlmConfig.fromMap(doc.data()!);
    // The persisted provider and credential must always come from one snapshot.
    final apiKey = config.apiKey;
    return LlmConfig(
      provider: config.provider,
      apiKey: apiKey,
      model: config.model,
      customEndpoint: config.customEndpoint,
      isOpenAiCompatible: config.isOpenAiCompatible,
      updatedAt: config.updatedAt,
    );
  }

  /// Save [config] to the owner-only Firestore secrets doc + memory cache.
  Future<void> saveLlmConfig(String uid, LlmConfig config) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('secrets')
        .doc('llmConfig')
        .set(config.toMap());
    // Persisted configuration is read as one snapshot; do not refill a session
    // credential cache after a delayed save from an account that logged out.
  }

  /// Remove the custom key and revert completely to built-in default Gemini.
  Future<void> clearLlmConfig(String uid) async {
    await SecureKeyStore.instance.clearApiKey(uid);
    await saveLlmConfig(uid, LlmConfig.defaultConfig);
  }

  /// Stream of the user's active [LlmConfig]. Emits on every save.
  Stream<LlmConfig> activeConfigStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('secrets')
        .doc('llmConfig')
        .snapshots()
        .map((snap) => snap.exists
            ? LlmConfig.fromMap(snap.data()!)
            : LlmConfig.defaultConfig);
  }

  // ---------------------------------------------------------------------------
  // Daily quota — built-in Gemini
  // ---------------------------------------------------------------------------

  Future<int> _reserveQuota(String uid) async {
    final int? remaining;
    try {
      remaining = _reserveQuotaOverride != null
          ? await _reserveQuotaOverride!(uid, kDailyQuotaLimit)
          : await AiQuotaStore(_firestore).reserve(uid, kDailyQuotaLimit);
    } on FirebaseException catch (error) {
      throw AiSetupFailure(AiSetupStep.quota, GenerationFailure.from(error));
    }
    if (remaining == null) throw QuotaExceededException();
    return remaining;
  }

  Future<int> getRemainingQuota(String uid) => _remainingQuotaOverride != null
      ? _remainingQuotaOverride!(uid, kDailyQuotaLimit)
      : AiQuotaStore(_firestore).remaining(uid, kDailyQuotaLimit);

  Future<LlmConfig> _generationConfig(String uid) async {
    try {
      return await getLlmConfig(uid);
    } on FirebaseException catch (error) {
      throw AiSetupFailure(AiSetupStep.settings, GenerationFailure.from(error));
    }
  }

  // ---------------------------------------------------------------------------
  // Key validation (Real Test Connection)
  // ---------------------------------------------------------------------------

  /// Performs a real test connection to verify that the provider API key,
  /// model, and endpoint are valid and operational.
  Future<KeyValidationResult> validateKey(
    LlmProvider provider,
    String apiKey, {
    String? customEndpoint,
    String? model,
    bool? isOpenAiCompatible,
  }) async {
    if (useFirebaseEmulators) {
      return KeyValidationResult(
          isValid: false,
          status: TestConnectionStatus.providerUnavailable,
          errorMessage: const GenerationFailure(GenerationFailureKind.localOnly)
              .toString());
    }
    final config = LlmConfig(
      provider: provider,
      apiKey: apiKey.trim(),
      model: model,
      customEndpoint: customEndpoint,
      isOpenAiCompatible: isOpenAiCompatible,
    );

    final adapter = _adapterFor(config);
    final testResult = await adapter.testConnection();

    return KeyValidationResult(
      isValid: testResult.isValid,
      status: testResult.status,
      errorMessage: testResult.errorMessage,
    );
  }

  /// Fetches available chat-compatible models from the provider.
  Future<List<String>> fetchAvailableModels({
    required LlmProvider provider,
    required String apiKey,
    String? customEndpoint,
    bool? isOpenAiCompatible,
  }) async {
    requireLiveAiEnvironment(useFirebaseEmulators);
    final config = LlmConfig(
      provider: provider,
      apiKey: apiKey.trim(),
      customEndpoint: customEndpoint,
      isOpenAiCompatible: isOpenAiCompatible,
    );
    final adapter = _adapterFor(config);
    return adapter.fetchAvailableModels();
  }

  // ---------------------------------------------------------------------------
  // Meal Plan Generation
  // ---------------------------------------------------------------------------

  Future<AiResult<List<Meal>>> generateMealPlan({
    required String uid,
    required List<String> familyMemberNames,
    required int numberOfDays,
    required List<String> mealTypes,
    required List<String> cuisinePreferences,
    required bool prioritizePantry,
    List<String> pantryItems = const [],
    List<String> groceryItems = const [],
    List<String> restrictions = const [],
    List<String> preferences = const [],
    Map<String, int> memberAges = const {},
    String? budget,
  }) async {
    requireLiveAiEnvironment(useFirebaseEmulators);
    final request = AiMealPlanRequest(
      familyMemberNames: familyMemberNames,
      memberAges: memberAges,
      numberOfDays: numberOfDays,
      mealTypes: mealTypes,
      cuisinePreferences: cuisinePreferences,
      prioritizePantry: prioritizePantry,
      pantryItems: pantryItems,
      groceryItems: groceryItems,
      restrictions: restrictions,
      preferences: preferences,
      budget: budget,
    );

    final config = await _generationConfig(uid);
    final isGeminiDefault =
        config.provider == LlmProvider.gemini && !config.isCustom;
    // Reject a retired model, invalid combination or adapter setup failure
    // before consuming the user's built-in generation quota.
    final adapter = _adapterFor(config);

    int? remainingQuota;
    if (isGeminiDefault) {
      remainingQuota = await _reserveQuota(uid);
    }

    try {
      final response = await adapter.generateMealPlan(request);
      request.validateMeals(response.meals);
      return AiResult(
        data: response.toCoreMeals(),
        usedFallback: false,
        quotaRemaining: remainingQuota,
        providerUsed: adapter.provider,
        modelUsed: adapter.model,
      );
    } catch (e) {
      AiLogger.logError(
        provider: config.provider.displayName,
        model: adapter.model,
        error: e,
      );
      if (isGeminiDefault) {
        // The adapter already attempted its bounded direct credential pool.
        // Preserve that actual failure; do not retry or switch models here.
        throw _mapFirebaseAiError(e);
      }

      // Automatic Gemini fallback when a custom BYO provider fails.
      try {
        final geminiAdapter = _adapterFor(LlmConfig.defaultConfig);
        remainingQuota = await _reserveQuota(uid);
        final fallbackResponse = await geminiAdapter.generateMealPlan(request);
        request.validateMeals(fallbackResponse.meals);
        return AiResult(
          data: fallbackResponse.toCoreMeals(),
          usedFallback: true,
          quotaRemaining: remainingQuota,
          providerUsed: geminiAdapter.provider,
          modelUsed: geminiAdapter.model,
        );
      } catch (fallbackError) {
        throw AiProviderException(
            provider: config.provider, cause: e, fallbackCause: fallbackError);
      }
    }
  }

  /// Generate a single replacement meal.
  Future<AiResult<Meal>> replaceMeal({
    required String uid,
    required Meal currentMeal,
    List<String> cuisinePreferences = const [],
    List<String> restrictions = const [],
    List<String> pantryItems = const [],
    List<String> preferences = const [],
  }) async {
    requireLiveAiEnvironment(useFirebaseEmulators);
    final request = AiMealReplacementRequest(
      currentMeal: currentMeal,
      cuisinePreferences: cuisinePreferences,
      restrictions: restrictions,
      pantryItems: pantryItems,
      preferences: preferences,
    );

    final config = await _generationConfig(uid);
    final isGeminiDefault =
        config.provider == LlmProvider.gemini && !config.isCustom;
    final adapter = _adapterFor(config);

    int? remainingQuota;
    if (isGeminiDefault) {
      remainingQuota = await _reserveQuota(uid);
    }

    try {
      final response = await adapter.generateMealReplacement(request);
      response.validateRecipe();
      IngredientRestrictions.validate(
          response.ingredients.map((i) => i.name), restrictions);
      return AiResult(
        data: response.toCoreMeal().copyWith(
            dayIndex: currentMeal.dayIndex, mealType: currentMeal.mealType),
        usedFallback: false,
        quotaRemaining: remainingQuota,
        providerUsed: adapter.provider,
        modelUsed: adapter.model,
      );
    } catch (e) {
      AiLogger.logError(
        provider: config.provider.displayName,
        model: adapter.model,
        error: e,
      );
      if (isGeminiDefault) {
        // Credential attempts belong to the adapter, with the selected model.
        throw _mapFirebaseAiError(e);
      }

      try {
        final geminiAdapter = _adapterFor(LlmConfig.defaultConfig);
        remainingQuota = await _reserveQuota(uid);
        final fallbackResponse =
            await geminiAdapter.generateMealReplacement(request);
        fallbackResponse.validateRecipe();
        IngredientRestrictions.validate(
            fallbackResponse.ingredients.map((i) => i.name), restrictions);
        return AiResult(
          data: fallbackResponse.toCoreMeal().copyWith(
              dayIndex: currentMeal.dayIndex, mealType: currentMeal.mealType),
          usedFallback: true,
          quotaRemaining: remainingQuota,
          providerUsed: geminiAdapter.provider,
          modelUsed: geminiAdapter.model,
        );
      } catch (fallbackError) {
        throw AiProviderException(
            provider: config.provider, cause: e, fallbackCause: fallbackError);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Exceptions
// ---------------------------------------------------------------------------

/// Thrown when a user's daily built-in Gemini quota is exhausted.
class QuotaExceededException implements Exception {
  @override
  String toString() => 'QuotaExceededException';
}

/// Thrown when Firebase AI Logic is off, deactivated, or App Check is missing.
class FirebaseAiNotEnabledException implements Exception {
  @override
  String toString() =>
      "Firebase AI / App Check is not enabled for this project. "
      "You can enter a free Google Gemini key in AI Settings to generate plans directly!";
}

/// Thrown when a user-configured AI provider fails.
class AiProviderException implements Exception {
  const AiProviderException({
    required this.provider,
    required this.cause,
    this.fallbackCause,
  });

  final LlmProvider provider;
  final Object cause;
  final Object? fallbackCause;

  @override
  String toString() {
    String describe(Object error) => error is AiSetupFailure
        ? error.toString()
        : GenerationFailure.from(error).toString();
    final primary = '${provider.displayName}: ${describe(cause)}';
    return fallbackCause == null
        ? primary
        : '$primary Built-in Gemini fallback failed: ${describe(fallbackCause!)}';
  }
}

Exception _mapFirebaseAiError(Object e) => GenerationFailure.from(e);

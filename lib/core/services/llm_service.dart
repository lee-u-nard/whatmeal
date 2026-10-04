import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/llm_config.dart';
import '../../features/meal/models/meal.dart';
import 'ai/ai_models.dart';
import 'ai/ai_provider_factory.dart';
import 'ai/ai_logger.dart';
import 'secure_key_store.dart';

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
///    adapter for that provider is invoked. If it fails, a clean [AiProviderException]
///    is thrown with clear diagnostics to allow Retry or Settings editing.
///  - If user has no custom key (or provider is Gemini), uses WhatMeal's built-in
///    Firebase AI Logic Gemini engine, subject to [kDailyQuotaLimit] per day.
///  - When the user removes a custom key, the active provider automatically reverts
///    to default built-in Gemini.
class LlmService {
  LlmService();

  final _firestore = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Provider config — Firestore persistence
  // ---------------------------------------------------------------------------

  /// Read the user's stored [LlmConfig] from Firestore secrets.
  ///
  /// Keys live only at `users/{uid}/secrets/llmConfig` (owner-only rules)
  /// and are never logged. A short-lived memory cache speeds up repeats.
  Future<LlmConfig> getLlmConfig(String uid) async {
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('secrets')
        .doc('llmConfig')
        .get();
    if (!doc.exists) return LlmConfig.defaultConfig;

    final config = LlmConfig.fromMap(doc.data()!);
    // Prefer memory cache if present (same session after save).
    final cached = await SecureKeyStore.instance.readApiKey(uid);
    final apiKey =
        (cached != null && cached.isNotEmpty) ? cached : config.apiKey;
    if (apiKey != null && apiKey.isNotEmpty) {
      await SecureKeyStore.instance.saveApiKey(uid, apiKey);
    }
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
    await SecureKeyStore.instance.saveApiKey(uid, config.apiKey);
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('secrets')
        .doc('llmConfig')
        .set(config.toMap());
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

  DocumentReference<Map<String, dynamic>> _quotaRef(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('usageCounters')
      .doc('daily');

  /// Returns the current quota counter for today, creating it if needed.
  Future<({String date, int count})> _getOrCreateQuota(String uid) async {
    final today = _today();
    final snap = await _quotaRef(uid).get();
    if (!snap.exists || (snap.data()?['date'] as String?) != today) {
      return (date: today, count: 0);
    }
    return (date: today, count: (snap.data()!['count'] as int? ?? 0));
  }

  /// Checks whether the user is under their daily quota and atomically increments the counter.
  Future<bool> _tryIncrementQuota(String uid) async {
    final quota = await _getOrCreateQuota(uid);
    if (quota.count >= kDailyQuotaLimit) return false;

    await _quotaRef(uid).set({
      'date': quota.date,
      'count': quota.count + 1,
    });
    return true;
  }

  /// Remaining built-in Gemini requests for today (0–[kDailyQuotaLimit]).
  Future<int> getRemainingQuota(String uid) async {
    final quota = await _getOrCreateQuota(uid);
    return (kDailyQuotaLimit - quota.count).clamp(0, kDailyQuotaLimit);
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
    final config = LlmConfig(
      provider: provider,
      apiKey: apiKey.trim(),
      model: model,
      customEndpoint: customEndpoint,
      isOpenAiCompatible: isOpenAiCompatible,
    );

    final adapter = AiProviderFactory.create(config);
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
    final config = LlmConfig(
      provider: provider,
      apiKey: apiKey.trim(),
      customEndpoint: customEndpoint,
      isOpenAiCompatible: isOpenAiCompatible,
    );
    final adapter = AiProviderFactory.create(config);
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

    final config = await getLlmConfig(uid);
    final isGeminiDefault =
        config.provider == LlmProvider.gemini && !config.isCustom;

    int? remainingQuota;
    if (isGeminiDefault) {
      final quota = await _getOrCreateQuota(uid);
      if (quota.count >= kDailyQuotaLimit) throw QuotaExceededException();
      remainingQuota =
          (kDailyQuotaLimit - quota.count).clamp(0, kDailyQuotaLimit);
    }

    final adapter = AiProviderFactory.create(config);
    try {
      final response = await adapter.generateMealPlan(request);
      if (isGeminiDefault) {
        await _tryIncrementQuota(uid);
        remainingQuota = await getRemainingQuota(uid);
      }
      return AiResult(
        data: response.toCoreMeals(),
        usedFallback: false,
        quotaRemaining: remainingQuota,
        providerUsed: config.provider,
      );
    } catch (e) {
      AiLogger.logError(
        provider: config.provider.displayName,
        model: adapter.model,
        error: e,
      );
      if (isGeminiDefault) {
        throw _mapFirebaseAiError(e);
      }

      // Automatic Gemini fallback when a custom BYO provider fails.
      try {
        final quota = await _getOrCreateQuota(uid);
        if (quota.count >= kDailyQuotaLimit) {
          throw AiProviderException(provider: config.provider, cause: e);
        }
        final geminiAdapter = AiProviderFactory.create(LlmConfig.defaultConfig);
        final fallbackResponse = await geminiAdapter.generateMealPlan(request);
        await _tryIncrementQuota(uid);
        remainingQuota = await getRemainingQuota(uid);
        return AiResult(
          data: fallbackResponse.toCoreMeals(),
          usedFallback: true,
          quotaRemaining: remainingQuota,
          providerUsed: LlmProvider.gemini,
        );
      } catch (_) {
        throw AiProviderException(provider: config.provider, cause: e);
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
  }) async {
    final request = AiMealReplacementRequest(
      currentMeal: currentMeal,
      cuisinePreferences: cuisinePreferences,
      restrictions: restrictions,
      pantryItems: pantryItems,
    );

    final config = await getLlmConfig(uid);
    final isGeminiDefault =
        config.provider == LlmProvider.gemini && !config.isCustom;

    int? remainingQuota;
    if (isGeminiDefault) {
      final quota = await _getOrCreateQuota(uid);
      if (quota.count >= kDailyQuotaLimit) throw QuotaExceededException();
      remainingQuota =
          (kDailyQuotaLimit - quota.count).clamp(0, kDailyQuotaLimit);
    }

    final adapter = AiProviderFactory.create(config);
    try {
      final response = await adapter.generateMealReplacement(request);
      if (isGeminiDefault) {
        await _tryIncrementQuota(uid);
        remainingQuota = await getRemainingQuota(uid);
      }
      return AiResult(
        data: response.toCoreMeal(fallbackIndex: currentMeal.dayIndex),
        usedFallback: false,
        quotaRemaining: remainingQuota,
        providerUsed: config.provider,
      );
    } catch (e) {
      AiLogger.logError(
        provider: config.provider.displayName,
        model: adapter.model,
        error: e,
      );
      if (isGeminiDefault) {
        throw _mapFirebaseAiError(e);
      }

      try {
        final quota = await _getOrCreateQuota(uid);
        if (quota.count >= kDailyQuotaLimit) {
          throw AiProviderException(provider: config.provider, cause: e);
        }
        final geminiAdapter = AiProviderFactory.create(LlmConfig.defaultConfig);
        final fallbackResponse =
            await geminiAdapter.generateMealReplacement(request);
        await _tryIncrementQuota(uid);
        remainingQuota = await getRemainingQuota(uid);
        return AiResult(
          data:
              fallbackResponse.toCoreMeal(fallbackIndex: currentMeal.dayIndex),
          usedFallback: true,
          quotaRemaining: remainingQuota,
          providerUsed: LlmProvider.gemini,
        );
      } catch (_) {
        throw AiProviderException(provider: config.provider, cause: e);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
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
  const AiProviderException({required this.provider, required this.cause});

  final LlmProvider provider;
  final Object cause;

  @override
  String toString() {
    var msg = cause.toString();
    if (msg.startsWith('Exception: ')) {
      msg = msg.substring('Exception: '.length);
    }
    return msg.isNotEmpty ? msg : '${provider.displayName} request failed.';
  }
}

Exception _mapFirebaseAiError(Object e) {
  final message = e.toString().toLowerCase();
  if (message.contains('deactivated') ||
      message.contains('app check') ||
      message.contains('app-check') ||
      message.contains('fetch-status-error') ||
      message.contains('firebase ai logic') ||
      message.contains('permission_denied') ||
      message.contains('permission denied')) {
    return FirebaseAiNotEnabledException();
  }
  if (e is Exception) return e;
  return Exception(e.toString());
}

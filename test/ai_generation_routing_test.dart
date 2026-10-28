import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:whatmeal/core/models/llm_config.dart';
import 'package:whatmeal/core/services/ai/ai_models.dart';
import 'package:whatmeal/core/services/ai/ai_provider_adapter.dart';
import 'package:whatmeal/core/services/ai/generation_failure.dart';
import 'package:whatmeal/core/services/ai/model_registry.dart';
import 'package:whatmeal/core/services/llm_service.dart';
import 'package:whatmeal/features/meal/models/meal.dart';

AiMealResponse _recipe({
  String title = 'Rice bowl',
  String type = 'Lunch',
  int day = 0,
  String ingredient = 'rice',
}) =>
    AiMealResponse(
      title: title,
      mealType: type,
      dayIndex: day,
      ingredients: [Ingredient(name: ingredient, amount: '1 cup')],
      instructions: const ['Cook and serve.'],
    );

class _Adapter extends AiProviderAdapter {
  _Adapter({
    required this.provider,
    required this.model,
    this.meals,
    this.planError,
    this.replacement,
    this.replacementError,
    this.planResult,
  });

  @override
  final LlmProvider provider;
  @override
  final String model;
  final List<AiMealResponse>? meals;
  final Object? planError;
  final AiMealResponse? replacement;
  final Object? replacementError;
  final Future<AiMealPlanResponse>? planResult;
  final planRequests = <AiMealPlanRequest>[];
  final replacementRequests = <AiMealReplacementRequest>[];

  @override
  Future<AiMealPlanResponse> generateMealPlan(AiMealPlanRequest request) async {
    planRequests.add(request);
    if (planError != null) throw planError!;
    if (planResult != null) return planResult!;
    return AiMealPlanResponse(
        meals: meals ?? [_recipe()], provider: provider, model: model);
  }

  @override
  Future<AiMealResponse> generateMealReplacement(
      AiMealReplacementRequest request) async {
    replacementRequests.add(request);
    if (replacementError != null) throw replacementError!;
    return replacement ?? _recipe();
  }

  @override
  Future<TestConnectionResult> testConnection() async =>
      TestConnectionResult.success();
}

LlmConfig _groqConfig([String model = 'openai/gpt-oss-20b']) => LlmConfig(
    provider: LlmProvider.groq, apiKey: 'fixture-only-not-a-key', model: model);

class _Harness {
  _Harness({LlmConfig? config, _Adapter? custom, _Adapter? gemini})
      : config = config ?? _groqConfig(),
        custom = custom ??
            _Adapter(provider: LlmProvider.groq, model: 'openai/gpt-oss-20b'),
        gemini = gemini ??
            _Adapter(
                provider: LlmProvider.gemini,
                model: AiModelRegistry.defaultGemini);

  final LlmConfig config;
  final _Adapter custom;
  final _Adapter gemini;
  final created = <LlmConfig>[];
  final quotaUsers = <String>[];
  int? remaining = 9;
  Object? constructionError;
  Object? configError;
  Object? quotaError;

  late final service = LlmService(
    readConfig: (uid) async {
      if (configError != null) throw configError!;
      return config;
    },
    createAdapter: (config) {
      created.add(config);
      if (constructionError != null) throw constructionError!;
      return config.provider == LlmProvider.gemini ? gemini : custom;
    },
    reserveQuota: (uid, limit) async {
      expect(limit, kDailyQuotaLimit);
      quotaUsers.add(uid);
      if (quotaError != null) throw quotaError!;
      return remaining;
    },
    remainingQuota: (uid, limit) async => remaining ?? 0,
  );
}

Future<AiResult<List<Meal>>> _generate(
  LlmService service, {
  String uid = 'local-owner',
  int days = 1,
  List<String> types = const ['Lunch'],
  List<String> restrictions = const [],
}) =>
    service.generateMealPlan(
      uid: uid,
      familyMemberNames: const ['Demo owner', 'Demo member'],
      numberOfDays: days,
      mealTypes: types,
      cuisinePreferences: const ['Filipino'],
      prioritizePantry: true,
      pantryItems: const ['1 cup rice'],
      groceryItems: const ['carrots'],
      restrictions: restrictions,
      preferences: const ['low sodium'],
      memberAges: const {'Demo member': 12},
      budget: '100',
    );

Meal _currentMeal() => Meal(
      id: 'existing-meal',
      title: 'Original dinner',
      dayIndex: 3,
      mealType: 'Dinner',
    );

void main() {
  for (final step in AiSetupStep.values) {
    test('Firebase ${step.name} failure is identified before a Gemini request',
        () async {
      final harness = _Harness(config: LlmConfig.defaultConfig);
      final error = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'private detail');
      if (step == AiSetupStep.settings) {
        harness.configError = error;
      } else {
        harness.quotaError = error;
      }
      await expectLater(
          _generate(harness.service),
          throwsA(isA<AiSetupFailure>()
              .having((error) => error.step, 'step', step)
              .having((error) => error.toString(), 'safe message',
                  isNot(contains('private detail')))));
      expect(harness.gemini.planRequests, isEmpty);
      expect(harness.custom.planRequests, isEmpty);
      expect(harness.quotaUsers.length, step == AiSetupStep.settings ? 0 : 1);
    });
  }
  test('construction does not initialize Firebase', () {
    expect(() => LlmService(), returnsNormally);
  });

  test('custom success keeps requested provider/model and household context',
      () async {
    final harness = _Harness();
    final result = await _generate(harness.service,
        restrictions: const ['peanut allergy']);

    expect(result.data.single.title, 'Rice bowl');
    expect(result.providerUsed, LlmProvider.groq);
    expect(result.modelUsed, 'openai/gpt-oss-20b');
    expect(result.usedFallback, isFalse);
    expect(result.fallbackNotice, isNull);
    expect(result.quotaRemaining, isNull);
    expect(harness.quotaUsers, isEmpty);
    expect(harness.gemini.planRequests, isEmpty);
    final request = harness.custom.planRequests.single;
    expect(request.familyMemberNames, ['Demo owner', 'Demo member']);
    expect(request.memberAges, {'Demo member': 12});
    expect(request.pantryItems, ['1 cup rice']);
    expect(request.groceryItems, ['carrots']);
    expect(request.restrictions, ['peanut allergy']);
    expect(request.preferences, ['low sodium']);
    expect(request.budget, '100');
  });

  test('built-in success reserves once and reports actual requested model',
      () async {
    final harness = _Harness(config: LlmConfig.defaultConfig);
    final result = await _generate(harness.service);

    expect(result.providerUsed, LlmProvider.gemini);
    expect(result.modelUsed, AiModelRegistry.defaultGemini);
    expect(result.quotaRemaining, 9);
    expect(result.usedFallback, isFalse);
    expect(harness.quotaUsers, ['local-owner']);
  });

  test('custom failure discloses fallback provider/model and reserves once',
      () async {
    final harness = _Harness(
      custom: _Adapter(
        provider: LlmProvider.groq,
        model: 'openai/gpt-oss-20b',
        planError: TimeoutException('fixture-only-sensitive-detail'),
      ),
    );
    final result = await _generate(harness.service);

    expect(result.usedFallback, isTrue);
    expect(result.providerUsed, LlmProvider.gemini);
    expect(result.modelUsed, AiModelRegistry.defaultGemini);
    expect(result.fallbackNotice, contains('Gemini'));
    expect(result.fallbackNotice, contains(AiModelRegistry.defaultGemini));
    expect(result.fallbackNotice, isNot(contains('sensitive-detail')));
    expect(harness.quotaUsers, ['local-owner']);
    expect(harness.gemini.planRequests.single,
        same(harness.custom.planRequests.single));
  });

  test('replacement keeps saved slot and exact custom model identity',
      () async {
    final harness = _Harness();
    final result = await harness.service.replaceMeal(
      uid: 'local-member',
      currentMeal: _currentMeal(),
      restrictions: const ['peanut allergy'],
      preferences: const ['low sodium'],
      pantryItems: const ['rice'],
    );

    expect(result.data.dayIndex, 3);
    expect(result.data.mealType, 'Dinner');
    expect(result.providerUsed, LlmProvider.groq);
    expect(result.modelUsed, 'openai/gpt-oss-20b');
    expect(result.usedFallback, isFalse);
    expect(harness.quotaUsers, isEmpty);
    expect(harness.custom.replacementRequests.single.restrictions,
        ['peanut allergy']);
  });

  test('replacement fallback uses the same explicit notice as plan fallback',
      () async {
    final harness = _Harness(
      custom: _Adapter(
        provider: LlmProvider.groq,
        model: 'openai/gpt-oss-20b',
        replacementError:
            const GenerationFailure(GenerationFailureKind.authentication),
      ),
    );
    final result = await harness.service
        .replaceMeal(uid: 'local-member', currentMeal: _currentMeal());

    expect(result.usedFallback, isTrue);
    expect(result.providerUsed, LlmProvider.gemini);
    expect(result.modelUsed, AiModelRegistry.defaultGemini);
    expect(result.fallbackNotice,
        'Your selected AI provider failed. Used Gemini (${AiModelRegistry.defaultGemini}) instead.');
    expect(result.data.dayIndex, 3);
    expect(result.data.mealType, 'Dinner');
    expect(harness.quotaUsers, ['local-member']);
  });

  for (final config in [
    LlmConfig(provider: LlmProvider.gemini, model: 'not-a-reviewed-model'),
    LlmConfig(provider: LlmProvider.gemini, model: 'gemini-3.1-pro-preview'),
    LlmConfig(
        provider: LlmProvider.anthropic,
        apiKey: 'fixture-only-not-a-key',
        model: 'claude-3-5-haiku-20241022'),
    LlmConfig(provider: LlmProvider.groq, model: 'openai/gpt-oss-20b'),
  ]) {
    test('invalid ${config.provider.name}/${config.model} spends no quota',
        () async {
      final harness = _Harness(config: config);
      await expectLater(
          _generate(harness.service),
          throwsA(isA<GenerationFailure>().having(
              (error) => error.kind,
              'kind',
              config.model == 'not-a-reviewed-model' ||
                      config.model == 'claude-3-5-haiku-20241022'
                  ? GenerationFailureKind.invalidModel
                  : GenerationFailureKind.configuration)));
      await expectLater(
          harness.service
              .replaceMeal(uid: 'local-owner', currentMeal: _currentMeal()),
          throwsA(isA<GenerationFailure>()));
      expect(harness.created, isEmpty);
      expect(harness.quotaUsers, isEmpty);
    });
  }

  test('adapter construction failure spends no built-in quota', () async {
    final harness = _Harness(config: LlmConfig.defaultConfig)
      ..constructionError = const FormatException('bad fixture setup');
    await expectLater(_generate(harness.service), throwsFormatException);
    expect(harness.quotaUsers, isEmpty);
  });

  for (final invalidMeals in [
    <AiMealResponse>[],
    [_recipe(), _recipe(title: 'Duplicate slot')],
  ]) {
    test(
        '${invalidMeals.isEmpty ? 'Incomplete' : 'Duplicate-slot'} plan is rejected by both provider routes',
        () async {
      final harness = _Harness(
        custom: _Adapter(
            provider: LlmProvider.groq,
            model: 'openai/gpt-oss-20b',
            meals: invalidMeals),
        gemini: _Adapter(
            provider: LlmProvider.gemini,
            model: AiModelRegistry.defaultGemini,
            meals: invalidMeals),
      );
      await expectLater(
          _generate(harness.service, types: const ['Lunch', 'Dinner']),
          throwsA(isA<AiProviderException>().having(
              (error) => error.fallbackCause,
              'fallback validation failure',
              isA<FormatException>())));
      expect(harness.quotaUsers, ['local-owner']);
    });
  }

  test('unsafe primary plan is discarded and safe fallback can recover',
      () async {
    final harness = _Harness(
      custom: _Adapter(
          provider: LlmProvider.groq,
          model: 'openai/gpt-oss-20b',
          meals: [_recipe(ingredient: 'peanut butter')]),
    );
    final result = await _generate(harness.service,
        restrictions: const ['peanut allergy']);
    expect(result.usedFallback, isTrue);
    expect(result.data.single.ingredients.single.name, 'rice');
  });

  test('allergy-conflicting plan and fallback never reach generated results',
      () async {
    final unsafe = [_recipe(ingredient: 'peanut butter')];
    final harness = _Harness(
      custom: _Adapter(
          provider: LlmProvider.groq,
          model: 'openai/gpt-oss-20b',
          meals: unsafe),
      gemini: _Adapter(
          provider: LlmProvider.gemini,
          model: AiModelRegistry.defaultGemini,
          meals: unsafe),
    );
    await expectLater(
        _generate(harness.service, restrictions: const ['peanut allergy']),
        throwsA(isA<AiProviderException>()));
  });

  test('allergy-conflicting replacements are rejected on both provider routes',
      () async {
    final harness = _Harness(
      custom: _Adapter(
          provider: LlmProvider.groq,
          model: 'openai/gpt-oss-20b',
          replacement: _recipe(ingredient: 'peanut butter')),
      gemini: _Adapter(
          provider: LlmProvider.gemini,
          model: AiModelRegistry.defaultGemini,
          replacement: _recipe(ingredient: 'peanuts')),
    );
    await expectLater(
        harness.service.replaceMeal(
          uid: 'local-member',
          currentMeal: _currentMeal(),
          restrictions: const ['peanut allergy'],
        ),
        throwsA(isA<AiProviderException>()));
    expect(harness.quotaUsers, ['local-member']);
  });

  test('fallback failure shows both safe classifications without private text',
      () async {
    final harness = _Harness(
      custom: _Adapter(
          provider: LlmProvider.groq,
          model: 'openai/gpt-oss-20b',
          planError: Exception('401 fixture-only-private-key')),
      gemini: _Adapter(
          provider: LlmProvider.gemini,
          model: AiModelRegistry.defaultGemini,
          planError: TimeoutException('fixture-only-private-key')),
    );
    await expectLater(
        _generate(harness.service),
        throwsA(isA<AiProviderException>()
            .having((error) => error.toString(), 'fallback reason',
                contains('fallback failed: The AI provider timed out'))
            .having((error) => error.toString(), 'no raw error',
                isNot(contains('fixture-only-private-key')))));
  });

  test('fallback quota exhaustion is reported and performs no Gemini request',
      () async {
    final harness = _Harness(
      custom: _Adapter(
          provider: LlmProvider.groq,
          model: 'openai/gpt-oss-20b',
          planError: TimeoutException('fixture')),
    )..remaining = null;
    await expectLater(
        _generate(harness.service),
        throwsA(isA<AiProviderException>()
            .having((error) => error.toString(), 'quota', contains('quota'))));
    expect(harness.gemini.planRequests, isEmpty);
    expect(harness.quotaUsers, ['local-owner']);
  });

  test('built-in quota exhaustion never invokes generation', () async {
    final harness = _Harness(config: LlmConfig.defaultConfig)..remaining = null;
    await expectLater(
        _generate(harness.service), throwsA(isA<QuotaExceededException>()));
    expect(harness.gemini.planRequests, isEmpty);
  });

  test('overlapping accounts keep their own config and result identity',
      () async {
    final delayed = Completer<AiMealPlanResponse>();
    final owner = _Adapter(
        provider: LlmProvider.groq,
        model: 'openai/gpt-oss-20b',
        planResult: delayed.future);
    final member =
        _Adapter(provider: LlmProvider.groq, model: 'openai/gpt-oss-120b');
    final service = LlmService(
      readConfig: (uid) async => _groqConfig(
          uid == 'owner' ? 'openai/gpt-oss-20b' : 'openai/gpt-oss-120b'),
      createAdapter: (config) => config.model == owner.model ? owner : member,
      reserveQuota: (uid, limit) async => fail('Unexpected quota reservation'),
    );

    final ownerPending = _generate(service, uid: 'owner');
    final memberResult = await _generate(service, uid: 'member');
    delayed.complete(AiMealPlanResponse(
        meals: [_recipe(title: 'Owner result')],
        provider: owner.provider,
        model: owner.model));
    final ownerResult = await ownerPending;

    expect(memberResult.modelUsed, member.model);
    expect(memberResult.data.single.title, 'Rice bowl');
    expect(ownerResult.modelUsed, owner.model);
    expect(ownerResult.data.single.title, 'Owner result');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:whatmeal/core/services/ai/ai_logger.dart';
import 'package:whatmeal/core/services/ai/ai_models.dart';
import 'package:whatmeal/features/meal/models/meal.dart';
import 'package:whatmeal/core/models/family.dart';
import 'package:whatmeal/core/routing/notification_route.dart';
import 'package:whatmeal/features/ai_settings/models/ai_provider.dart';

void main() {
  test('household ownership compares the caller UID with its creator', () {
    final family = Family(
        id: 'f',
        name: 'Family',
        inviteCode: 'CODE12',
        createdBy: 'owner',
        memberUids: ['owner', 'member']);
    expect(family.isOwner('owner'), isTrue);
    expect(family.isOwner('member'), isFalse);
    expect(family.isOwner('outsider'), isFalse);
    expect(family.isOwner(null), isFalse);
  });
  group('AI response acceptance', () {
    test('replacement can preserve the requested day and meal type', () {
      final meal = Meal(
          id: 'replacement',
          title: 'Rice',
          dayIndex: 0,
          mealType: 'Lunch',
          instructions: ['Cook']);
      final replacement = meal.copyWith(dayIndex: 5, mealType: 'Dinner');
      expect(replacement.dayIndex, 5);
      expect(replacement.mealType, 'Dinner');
      expect(replacement.instructions, ['Cook']);
      expect(meal.dayIndex, 0);
    });
    const request = AiMealPlanRequest(
        familyMemberNames: ['A'],
        numberOfDays: 1,
        mealTypes: ['Breakfast', 'Dinner']);
    AiMealResponse recipe(String type, {int day = 0}) => AiMealResponse(
          title: 'Vegetable rice',
          mealType: type,
          dayIndex: day,
          ingredients: const [Ingredient(name: 'Rice', amount: '1 cup')],
          instructions: const ['Cook the rice.'],
        );
    test('accepts one complete recipe per requested slot', () {
      expect(
          () => request.validateMeals([recipe('Breakfast'), recipe('Dinner')]),
          returnsNormally);
    });
    test('rejects partial plans', () {
      expect(() => request.validateMeals([recipe('Breakfast')]),
          throwsFormatException);
    });
    test('rejects duplicates, unknown types, and wrong dates', () {
      for (final bad in [
        recipe('Breakfast'),
        recipe('Snack'),
        recipe('Dinner', day: 1)
      ]) {
        expect(() => request.validateMeals([recipe('Breakfast'), bad]),
            throwsFormatException);
      }
    });
    test('rejects recipes with no ingredients or instructions', () {
      expect(() => const AiMealResponse(title: 'Incomplete').validateRecipe(),
          throwsFormatException);
    });
  });
  test('AI diagnostics never log raw errors or URL credentials', () {
    final lines = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) lines.add(message);
    };
    addTearDown(() => debugPrint = original);
    AiLogger.logRequest(
      provider: 'Custom',
      model: 'model',
      endpoint:
          'https://user:password@example.com/private-secret?auth=opaque-secret#fragment-secret',
    );
    AiLogger.logError(
        provider: 'Custom',
        model: 'model',
        error: Exception('server echoed arbitrary-secret'));
    expect(lines.join(), contains('https://example.com'));
    for (final secret in [
      'password',
      'private-secret',
      'opaque-secret',
      'fragment-secret',
      'arbitrary-secret'
    ]) {
      expect(lines.join(), isNot(contains(secret)));
    }
  });
  group('Provider credential boundaries', () {
    const configured = AiProviderConfig(
      providerType: AiProviderType.groq,
      selectedModel: 'old-model',
      apiKey: 'test-credential-never-send-to-another-host',
      customEndpoint: 'https://old.example/v1',
      fetchedModels: ['old-model'],
      status: ApiConnectionStatus.connected,
    );
    for (final provider in AiProviderType.values) {
      if (provider == AiProviderType.groq) continue;
      test('switching to $provider drops credentials and endpoint', () {
        final next = configured.forProvider(provider);
        expect(next.providerType, provider);
        expect(next.apiKey, isNull);
        expect(next.customEndpoint, isNull);
        expect(next.fetchedModels, isNull);
        expect(next.selectedModel, provider.defaultModel);
        expect(
            next.status,
            provider == AiProviderType.gemini
                ? ApiConnectionStatus.configured
                : ApiConnectionStatus.notConfigured);
      });
    }
    test('reselecting the same provider preserves configuration', () {
      expect(configured.forProvider(AiProviderType.groq), same(configured));
    });
  });

  group('Notification routes', () {
    test('handles flattened backend payload', () {
      expect(notificationRoute({'route': '/meal-plan', 'mealId': 'meal 1'}),
          '/meal/meal%201');
    });
    test('handles string encoded legacy parameters', () {
      expect(
          notificationRoute({'parameters': '{"mealId":"abc"}'}), '/meal/abc');
    });
    test('opens saved plans instead of an empty generated draft', () {
      expect(notificationRoute({'planId': 'p1'}),
          '/notification-target?planId=p1');
      expect(
          notificationRoute({'route': '/generated-plan'}), '/saved-meal-plans');
    });
    test('malformed parameters and untrusted routes safely fall back', () {
      expect(
          notificationRoute(
              {'parameters': '{bad', 'route': 'https://evil.test'}),
          '/home');
      expect(notificationRoute({'mealId': '../other', 'route': '/login'}),
          '/home');
      expect(notificationRoute({'parameters': '[]', 'route': '/pantry'}),
          '/pantry');
    });
  });
}

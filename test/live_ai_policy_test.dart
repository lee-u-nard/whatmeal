import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/services/ai/live_ai_policy.dart';
import 'package:whatmeal/core/services/ai/generation_failure.dart';
import 'package:whatmeal/core/config/runtime_environment.dart';
import 'package:whatmeal/core/services/llm_service.dart';
import 'package:whatmeal/core/models/llm_config.dart';

void main() {
  if (useFirebaseEmulators) {
    test('demo service blocks config reads, quota writes and provider requests',
        () async {
      var reads = 0, quota = 0, adapters = 0;
      final service = LlmService(readConfig: (_) async {
        reads++;
        return LlmConfig.defaultConfig;
      }, reserveQuota: (_, __) async {
        quota++;
        return 9;
      }, createAdapter: (_) {
        adapters++;
        throw StateError('must never run');
      });
      await expectLater(
          service.generateMealPlan(
              uid: 'fixture',
              familyMemberNames: ['Fixture'],
              numberOfDays: 1,
              mealTypes: ['Dinner'],
              cuisinePreferences: ['Filipino'],
              prioritizePantry: false),
          throwsA(isA<GenerationFailure>().having(
              (error) => error.kind, 'kind', GenerationFailureKind.localOnly)));
      expect([reads, quota, adapters], [0, 0, 0]);
    });
  }
  test('demo mode refuses external AI with a safe actionable error', () {
    expect(
        () => requireLiveAiEnvironment(true),
        throwsA(isA<GenerationFailure>()
            .having((e) => e.kind, 'kind', GenerationFailureKind.localOnly)
            .having((e) => e.toString(), 'message',
                contains('disabled in the isolated local tester'))));
  });
  test('policy does not replace normal provider behavior with fake results',
      () {
    expect(() => requireLiveAiEnvironment(false), returnsNormally);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/config/runtime_environment.dart';
import 'package:whatmeal/core/services/ai/live_ai_policy.dart';
import 'package:whatmeal/core/services/ai/generation_failure.dart';

void main() {
  test('original isolated tester keeps its exact backend identity', () {
    final target = LocalFirebaseTarget.forAndroidFlavor('local');
    expect(target.projectId, 'demo-whatmeal-audit');
    expect(target.authPort, 9099);
    expect(target.firestorePort, 8180);
  });
  test('showcase has a distinct demo project and both backend ports', () {
    final target = LocalFirebaseTarget.forAndroidFlavor('showcase');
    expect(target.projectId, 'demo-whatmeal-showcase');
    expect(target.authPort, 9299);
    expect(target.firestorePort, 9280);
    expect(target.projectId, isNot(LocalFirebaseTarget.audit.projectId));
    expect(target.authPort, isNot(LocalFirebaseTarget.audit.authPort));
    expect(
        target.firestorePort, isNot(LocalFirebaseTarget.audit.firestorePort));
    expect(() => requireLiveAiEnvironment(true),
        throwsA(isA<GenerationFailure>()));
  });
  test(
      'production and unspecified Android flavors cannot target local services',
      () {
    for (final flavor in [null, 'production', 'unknown']) {
      expect(
          () => LocalFirebaseTarget.forAndroidFlavor(flavor), throwsStateError);
    }
  });
}

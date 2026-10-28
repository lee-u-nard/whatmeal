import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/config/ai_test_environment.dart';

void main() {
  void requireLaunch({
    String? flavor = 'aitest',
    bool android = true,
    bool debug = true,
    bool emulators = false,
  }) =>
      AiTestEnvironment.requireLaunch(
        actualFlavor: flavor,
        isAndroid: android,
        isDebug: debug,
        useEmulators: emulators,
      );

  void requireIdentity({
    String? project = AiTestEnvironment.projectId,
    String app = AiTestEnvironment.appId,
    String number = AiTestEnvironment.projectNumber,
  }) =>
      AiTestEnvironment.requireIdentity(
        actualProjectId: project,
        actualAppId: app,
        actualProjectNumber: number,
      );

  test('approved AI-only Android debug configuration passes launch guards', () {
    expect(requireLaunch, returnsNormally);
    expect(requireIdentity, returnsNormally);
    expect(AiTestEnvironment.packageId, 'com.example.whatmeal.aitest');
  });

  test('AI harness refuses production, demo, missing, and unknown flavors', () {
    for (final flavor in [null, 'production', 'local', 'showcase', 'unknown']) {
      expect(() => requireLaunch(flavor: flavor), throwsStateError);
    }
  });

  test('AI harness refuses non-Android execution', () {
    expect(() => requireLaunch(android: false), throwsStateError);
  });

  test('AI harness refuses release and profile execution', () {
    expect(() => requireLaunch(debug: false), throwsStateError);
  });

  test('AI harness refuses emulator runtime flags', () {
    expect(() => requireLaunch(emulators: true), throwsStateError);
  });

  test('AI harness rejects production and local Firebase project identities',
      () {
    for (final project in [
      null,
      '',
      'whatmeal-101',
      'demo-whatmeal-audit',
      'demo-whatmeal-showcase',
      'unapproved-project',
    ]) {
      expect(() => requireIdentity(project: project), throwsStateError);
    }
  });

  test(
      'AI harness requires the approved Android Firebase app and project number',
      () {
    expect(
        () => requireIdentity(app: 'unapproved-android-app'), throwsStateError);
    expect(() => requireIdentity(number: 'other-project-number'),
        throwsStateError);
  });

  test('normal app rejects AI harness flavor before Firebase initialization',
      () {
    expect(() => AiTestEnvironment.requireNormalEntryPoint('aitest'),
        throwsStateError);
    for (final flavor in [null, 'production', 'local', 'showcase']) {
      expect(() => AiTestEnvironment.requireNormalEntryPoint(flavor),
          returnsNormally);
    }
  });

  test('live request budget permits exactly two claimed attempts', () {
    final budget = AiTestRequestBudget();
    expect(budget.attempts, 0);
    expect(budget.canRequest, isTrue);
    budget.claim();
    expect(budget.attempts, 1);
    expect(budget.canRequest, isTrue);
    budget.claim();
    expect(budget.attempts, 2);
    expect(budget.canRequest, isFalse);
    expect(budget.claim, throwsStateError);
    expect(budget.attempts, 2);
  });

  test('failed attempts and rapid claims cannot refund or exceed the budget',
      () {
    final budget = AiTestRequestBudget();
    for (var attempt = 0; attempt < 2; attempt++) {
      budget.claim();
      // A failure after claiming has no reset/refund path.
      expect(budget.attempts, attempt + 1);
    }
    for (var extraTap = 0; extraTap < 3; extraTap++) {
      expect(budget.claim, throwsStateError);
    }
    expect(budget.attempts, AiTestRequestBudget.maximum);
  });
}

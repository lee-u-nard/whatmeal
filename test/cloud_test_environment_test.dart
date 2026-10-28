import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/config/ai_test_environment.dart';
import 'package:whatmeal/core/config/cloud_test_environment.dart';
import 'package:whatmeal/core/config/runtime_environment.dart';

void main() {
  void requireLaunch({
    String? flavor = 'cloudtest',
    bool android = true,
    bool debug = true,
    bool emulators = false,
  }) =>
      CloudTestEnvironment.requireLaunch(
        actualFlavor: flavor,
        isAndroid: android,
        isDebug: debug,
        useEmulators: emulators,
      );

  void requireIdentity({
    String? project = CloudTestEnvironment.projectId,
    String app = CloudTestEnvironment.appId,
    String number = CloudTestEnvironment.projectNumber,
  }) =>
      CloudTestEnvironment.requireIdentity(
        actualProjectId: project,
        actualAppId: app,
        actualProjectNumber: number,
      );

  test('approved full-app cloud test has its own Android app identity', () {
    expect(requireLaunch, returnsNormally);
    expect(requireIdentity, returnsNormally);
    expect(CloudTestEnvironment.packageId, 'com.example.whatmeal.cloudtest');
    expect(CloudTestEnvironment.packageId, isNot(AiTestEnvironment.packageId));
    expect(CloudTestEnvironment.appId, isNot(AiTestEnvironment.appId));
    expect(CloudTestEnvironment.projectId, AiTestEnvironment.projectId);
  });

  test(
      'cloud test refuses production, isolated demo, AI harness, and no flavor',
      () {
    for (final flavor in [
      null,
      'production',
      'local',
      'showcase',
      'aitest',
      'unknown'
    ]) {
      expect(() => requireLaunch(flavor: flavor), throwsStateError);
    }
  });

  test('cloud test refuses non-Android platforms', () {
    expect(() => requireLaunch(android: false), throwsStateError);
  });

  test('cloud test refuses non-debug execution', () {
    expect(() => requireLaunch(debug: false), throwsStateError);
  });

  test('cloud test refuses emulator defines instead of changing backend mode',
      () {
    expect(() => requireLaunch(emulators: true), throwsStateError);
  });

  test('cloud test cannot initialize production or either local project', () {
    for (final project in [
      null,
      '',
      'whatmeal-101',
      LocalFirebaseTarget.audit.projectId,
      LocalFirebaseTarget.showcase.projectId,
      'unapproved-project',
    ]) {
      expect(() => requireIdentity(project: project), throwsStateError);
    }
  });

  test('cloud test rejects a different Android app within the approved project',
      () {
    expect(
        () => requireIdentity(app: AiTestEnvironment.appId), throwsStateError);
    expect(() => requireIdentity(app: 'unapproved-app'), throwsStateError);
    expect(() => requireIdentity(number: 'other-number'), throwsStateError);
  });

  test('normal bootstrap accepts cloud test while AI-only bootstrap rejects it',
      () {
    expect(() => AiTestEnvironment.requireNormalEntryPoint('cloudtest'),
        returnsNormally);
    expect(
        () => AiTestEnvironment.requireLaunch(
              actualFlavor: 'cloudtest',
              isAndroid: true,
              isDebug: true,
              useEmulators: false,
            ),
        throwsStateError);
    expect(() => LocalFirebaseTarget.forAndroidFlavor('cloudtest'),
        throwsStateError);
  });
}

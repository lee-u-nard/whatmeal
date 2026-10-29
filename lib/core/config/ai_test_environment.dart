/// This allowlist authorizes one separate Android AI smoke test, never a
/// production app, an emulator household, or an arbitrary Firebase project.
class AiTestEnvironment {
  AiTestEnvironment._();

  static const flavor = 'aitest';
  static const packageId = 'com.example.whatmeal.aitest';
  static const projectId = 'whatmeal-gemini-test-20261019';
  static const appId = '1:952163528165:android:9348c46aaa5943ff95530c';
  static const projectNumber = '952163528165';

  static void requireLaunch({
    required String? actualFlavor,
    required bool isAndroid,
    required bool isDebug,
    required bool useEmulators,
  }) {
    if (actualFlavor != flavor || !isAndroid || !isDebug || useEmulators) {
      throw StateError(
          'The AI smoke test requires its separate Android debug build.');
    }
  }

  static void requireIdentity({
    required String? actualProjectId,
    required String actualAppId,
    required String actualProjectNumber,
  }) {
    if (actualProjectId != projectId ||
        actualAppId != appId ||
        actualProjectNumber != projectNumber) {
      // Never include unexpected config fields, which may contain secrets.
      throw StateError('The AI test Firebase identity did not match approval.');
    }
  }

  static void requireNormalEntryPoint(String? actualFlavor) {
    if (actualFlavor == flavor) {
      throw StateError('The AI test cannot launch the normal application.');
    }
  }
}

/// Claimed before asynchronous work, so rapid taps and failed requests cannot
/// bypass the limit. One process session can make at most two live attempts.
class AiTestRequestBudget {
  static const maximum = 2;
  int _attempts = 0;

  int get attempts => _attempts;
  bool get canRequest => _attempts < maximum;

  void claim() {
    if (!canRequest) {
      throw StateError('The AI test session limit has been reached.');
    }
    _attempts++;
  }
}

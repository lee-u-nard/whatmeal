/// Approval for the separate, disposable full-app Firebase Spark test.
/// These identifiers never authorize the original production project.
class CloudTestEnvironment {
  CloudTestEnvironment._();

  static const flavor = 'cloudtest';
  static const packageId = 'com.example.whatmeal.cloudtest';
  static const projectId = 'whatmeal-gemini-test-20261019';
  static const appId = '1:952163528165:android:e184bb528e406cff95530c';
  static const projectNumber = '952163528165';

  static void requireLaunch({
    required String? actualFlavor,
    required bool isAndroid,
    required bool isDebug,
    required bool useEmulators,
  }) {
    if (actualFlavor != flavor || !isAndroid || !isDebug || useEmulators) {
      throw StateError(
          'The cloud test requires its separate Android debug build.');
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
      throw StateError(
          'The cloud-test Firebase identity did not match approval.');
    }
  }
}

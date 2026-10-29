import 'package:integration_test/integration_test_driver.dart';

/// Whitelist evidence fields: no credentials, Firebase documents or screenshots.
Future<void> main() => integrationDriver(
      timeout: const Duration(minutes: 10),
      writeResponseOnFailure: true,
      responseDataCallback: (data) async {
        await writeResponseData({
          'completedPhases': data?['completedPhases'] ?? [],
          'authMethod': data?['authMethod'],
          'liveAiCalled': data?['liveAiCalled'],
          'configurationRestored': data?['configurationRestored'] ?? false,
          'restorationFailures': data?['restorationFailures'],
          'restorationErrors': data?['restorationErrors'] ?? [],
        },
            destinationDirectory: 'audit/stage15/provider-local-fixes',
            testOutputFilename: 'android-provider-settings');
      },
    );

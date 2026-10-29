import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver.dart';

/// Keep synthetic document IDs for the separate cold-reopen run. Never export
/// account identifiers, entered credentials, Firebase options or token output.
Future<void> main() => integrationDriver(
      timeout: const Duration(minutes: 12),
      writeResponseOnFailure: true,
      responseDataCallback: (data) async {
        final phase = data?['phase'] == 'reopen' ? 'reopen' : 'generate';
        final privateBatches = data?['_privateFirestoreBatches'];
        if (privateBatches != null) {
          final directory = Directory('build/cloudtest-private/evidence');
          await directory.create(recursive: true);
          await File('${directory.path}/android-$phase-batch-private.json')
              .writeAsString(
                  const JsonEncoder.withIndent('  ').convert(privateBatches));
        }
        final safe = <String, dynamic>{
          for (final key in [
            'phase',
            'projectId',
            'completedPhases',
            'authentication',
            'generationButtonTaps',
            'savePlanButtonTaps',
            'liveGenerationObserved',
            'initialSaveFailed',
            'saveFailureObserved',
            'generationFailureKind',
            'requestedModel',
            'planId',
            'mealId',
            'planTitle',
            'mealCount',
            'numberOfDays',
            'mealType',
            'serverPersistenceVerified',
            'outsiderDenied',
            'firestoreBatchSummaries',
            'batchCaptureErrors',
          ])
            if (data?.containsKey(key) ?? false) key: data![key],
        };
        await writeResponseData(safe,
            destinationDirectory: 'build/cloudtest-private/evidence',
            testOutputFilename: 'android-$phase');
      },
    );

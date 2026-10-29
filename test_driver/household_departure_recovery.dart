import 'dart:io';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
    timeout: const Duration(minutes: 10),
    writeResponseOnFailure: true,
    responseDataCallback: (data) async {
      final result = <String, dynamic>{...?data};
      final screenshots = result.remove('screenshots') as List?;
      if (screenshots != null) {
        for (final shot in screenshots) {
          final name = (shot['screenshotName'] ?? 'capture')
              .toString()
              .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
          await File('audit/stage15/departure-recovery/$name.png')
              .writeAsBytes(List<int>.from(shot['bytes'] as List));
        }
      }
      await writeResponseData(result,
          destinationDirectory: 'audit/stage15/departure-recovery',
          testOutputFilename: 'android-phases');
    });

import 'package:integration_test/integration_test_driver.dart';
import 'dart:io';

Future<void> main() => integrationDriver(
      timeout: const Duration(minutes: 12),
      writeResponseOnFailure: true,
      responseDataCallback: (data) async {
        final result = <String, dynamic>{...?data};
        final screenshots = result.remove('screenshots') as List?;
        if (screenshots != null && screenshots.isNotEmpty) {
          final bytes = List<int>.from(screenshots.last['bytes'] as List);
          await File('audit/stage12/blocked-control.png').writeAsBytes(bytes);
          result['failureScreenshot'] = 'blocked-control.png';
        }
        await writeResponseData(result,
            destinationDirectory: 'audit/stage12',
            testOutputFilename: 'android-phases');
      },
    );

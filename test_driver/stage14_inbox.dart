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
          await File('audit/stage14/notification-recovered.png')
              .writeAsBytes(bytes);
          result['screenshot'] = 'notification-recovered.png';
        }
        await writeResponseData(result,
            destinationDirectory: 'audit/stage14',
            testOutputFilename: 'android-phases');
      },
    );

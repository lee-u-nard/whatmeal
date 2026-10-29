import 'package:flutter/services.dart' show appFlavor;
import 'ai_test_environment.dart';
import 'cloud_test_environment.dart';

/// Every isolated Android flavor refuses live AI and native messaging.
const useFirebaseEmulators = appFlavor == 'local' ||
    appFlavor == 'showcase' ||
    bool.fromEnvironment('WHATMEAL_EMULATORS');

/// Approved cloud testing exercises the in-app inbox without starting native
/// FCM, requesting device permission, or uploading a device registration token.
const useNativeDeviceNotifications = !useFirebaseEmulators &&
    appFlavor != AiTestEnvironment.flavor &&
    appFlavor != CloudTestEnvironment.flavor;

/// Fixed, separate targets prevent the showcase from reusing the cached tester's
/// backend. The showcase also has a different Android application ID/data folder.
class LocalFirebaseTarget {
  const LocalFirebaseTarget._(
      this.projectId, this.authPort, this.firestorePort);
  final String projectId;
  final int authPort;
  final int firestorePort;

  static const audit = LocalFirebaseTarget._('demo-whatmeal-audit', 9099, 8180);
  static const showcase =
      LocalFirebaseTarget._('demo-whatmeal-showcase', 9299, 9280);

  static LocalFirebaseTarget forAndroidFlavor(String? flavor) =>
      switch (flavor) {
        'local' => audit,
        'showcase' => showcase,
        _ => throw StateError(
            'Android emulator mode requires an isolated flavor.'),
      };
}

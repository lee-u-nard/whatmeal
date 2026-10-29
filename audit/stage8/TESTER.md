# Local Android verification — Stage 8

The Stage 7 APK must not be used for isolated startup. Its Dart configuration selected a demo project but its generated native resources selected the existing project. No Stage 7 device launch was performed.

Stage 8 adds Android flavors:

- `local`: package `com.example.whatmeal.local`, native and Dart project `demo-whatmeal-audit`, matching app/sender IDs and dummy API key. Local mode is selected automatically by the flavor. Messaging auto-initialization and FCM token refresh/cleanup are disabled in this mode. Local network security permits HTTP only to `127.0.0.1`, `localhost` and Android's `10.0.2.2` host alias, without subdomains.
- `production`: retains the existing package/configuration; not built, installed or launched for this acceptance session. Proper release signing still requires the owner's existing signing configuration. Selecting a flavor does not authorize a deployment.

Use `flutter test integration_test/local_workflow_test.dart -d emulator-5554 --flavor local --dart-define=WHATMEAL_EMULATOR_HOST=10.0.2.2` only with the demo Auth and Firestore emulators running on 9099/8180. The test refuses a non-local flavor before calling app startup. It uses only the demo Auth emulator's email action codes to exercise verification; it does not grant verified status through an admin override.

For a standalone tester APK use `flutter build apk --release --flavor local --dart-define=WHATMEAL_EMULATOR_HOST=10.0.2.2` with explicit `WHATMEAL_TESTER_SIGNING=true`. Do not add `--no-pub` when switching from integration/debug to release: the installed Flutter tool skips platform tooling regeneration with that flag, retaining the test plugin in the Java registrant while release Gradle excludes dev plugins. Do not run Flutter analysis/pub/test concurrently with an Android build either, because those commands can regenerate the registrant for a different build mode. Retain the integration suite; let the normal release command regenerate its own files.

This host required the existing process-local `jdk.net.unixdomain.tmpdir` workaround. It has approximately 8 GB RAM, so build/AVD memory pressure is material. The audit AVD and SDK image are under ignored `build/audit-avds` and `build/android-sdk-audit`. They are local testing artifacts, not production app data. No firewall, security software, Windows virtualization settings or real device data were changed.

Live AI testing remains explicitly pending: the user has not confirmed an approved non-production Firebase project. Do not use production or treat mocked adapter tests as live AI evidence. Actual test outcomes belong in the Stage 8 report/logs; setup alone is not an acceptance pass.

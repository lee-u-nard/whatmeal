# Reproducible commands and safety boundaries

Run commands from the repository root, serially. Flutter path used: `C:/Users/ASUS V16/flutter_windows_3.44.5-stable/flutter/bin/flutter.bat`. Scripts record tool output and actual exit codes; a process/session interruption without exit is incomplete.

1. `flutter test` → `flutter-tests-resumed.txt/.exit`: 278 passed, exit0. Earlier `flutter-tests-final.txt` interrupted at266; copied to `flutter-tests-interrupted.txt`, never counted as pass.
2. `flutter analyze` → `analyze-resumed.txt/.exit`: exit1, sealed test-fixture warning. Replaced direct implementation with existing fake Firestore `.get(Source.cache/server)` snapshots.
3. `flutter test test/family_snapshot_authority_test.dart` → `cache-final.txt/.exit`: 2 passed, exit0.
4. `flutter analyze` → `analyze-complete.txt/.exit`: clean, exit0.
5. `./audit/stage15/household-recovery/start_disposable_backend.ps1` starts only demo Auth9199/Firestore9180 with unchanged rules, separate hub4490/log4590, no UI. Imports/exports only ignored disposable fixture state.
6. `node audit/stage15/household-recovery/fixture_proxy.cjs`: loopback8183→9180; control8184 pauses/resumes this connection only. It never proxies the normal backend or logs payloads.
7. `./audit/stage15/household-recovery/build_integration.ps1`: `flutter build apk --debug --flavor local --target integration_test/household_submit_recovery_test.dart --target-platform android-x64 --dart-define=WHATMEAL_EMULATOR_HOST=10.0.2.2 --dart-define=WHATMEAL_RECOVERY_AUTH_PORT=9199`. Exit in build-integration.exit. `verify_integration.ps1` verifies package/demo/native guards/existing signer/hash, then permits Android test.
8. `./audit/stage15/household-recovery/build_tester.ps1`: `flutter build apk --release --flavor local --target lib/main.dart --dart-define=WHATMEAL_EMULATOR_HOST=10.0.2.2`; process-only WHATMEAL_TESTER_SIGNING=true, existing debug identity; no secret generated/read. Final44.0s build exit0. `verify_tester.ps1` verifies isolation/signature/network guards/hash.
9. `./audit/stage15/household-recovery/open_device.ps1`: starts only backed-up whatmeal-stage9-aosp on emulator-5564; no app install/launch, no wipe, no normal backend restart.
10. `./audit/stage15/household-recovery/run_android.ps1`: `flutter drive --driver=test_driver/household_submit_recovery.dart --target=integration_test/household_submit_recovery_test.dart --use-application-binary=build/stage15/household-recovery/integration.apk --flavor=local -d emulator-5564 --keep-app-running`; no concurrent Flutter commands. Logs redact bearer tokens/action URLs/native UID logs. Current result in android.exit and android-phases.json.

Java settings are process-local: Android Studio JBR, Unix-domain temp path under audit/stage15, Gradle heap768MB, Kotlin compiler in-process. No system/firewall/security change.

Normal Auth9099/Firestore8180 remain stopped after the unexpected interruption. Do not start an empty replacement or reset accounts. Whole AVD private-state backup and hash manifest are ignored under build/private-state-snapshots. This is not an export of the former in-memory backend.

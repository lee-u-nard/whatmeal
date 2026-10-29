# Commands and evidence

All Flutter commands were serialized from repository root using Flutter3.44.5 at C:/Users/ASUS V16/flutter_windows_3.44.5-stable/flutter/bin/flutter.bat. No upgrade was performed.

- `flutter test test/household_departure_recovery_test.dart` before changes: reproduced.txt/.exit,0passed/4failed, exit1.
- Focused household/layout files: focused.txt compilation failure; focused-final.txt28pass/3fail; focused-complete.txt31pass, exit0. Pending-animation test waits were replaced by bounded pumps plus an explicit pending-status assertion; late-navigation/session assertions retained.
- `flutter test`: flutter-tests.txt/.exit282pass, exit0,82s; before final heading repair.
- `flutter test test/household_departure_recovery_test.dart --plain-name 'member departure actions fit'`: layout-reproduced.txt/.exit0pass/2fail.
- `flutter test test/household_departure_recovery_test.dart`: layout-final.txt/.exit6pass, exit0 after heading repairs.
- `flutter analyze`: analyze.txt exit1 (two test-only annotations); analyze-final.txt clean23.4s; analyze-layout.txt/.exit clean7.7s on final sources.
- `start_backend.ps1`: demo project Standard Edition Auth9199/Firestore9180 imports/exports only ignored build/household-recovery-private/fixture-export. Original9099/8180 stayed closed. The prior fixture export was privately copied before testing.
- `firebase emulators:export build/household-recovery-private/after-import-before-tests --force --project demo-whatmeal-audit --config firebase.household-recovery.json`: exit0; five restored disposable IDs match the original export, normal account absent. Only equality/counts saved in fixture-restore-check.json.
- `node audit/stage15/departure-recovery/fixture_proxy.cjs`: loopback8183→9180, control8184. No decryption/payload logging/global firewall changes.
- `build_integration.ps1`: `flutter build apk --debug --flavor local --target integration_test/household_departure_recovery_test.dart --target-platform android-x64 --dart-define=WHATMEAL_EMULATOR_HOST=10.0.2.2 --dart-define=WHATMEAL_RECOVERY_AUTH_PORT=9199`. First build32.2s; final21.9s; exit0. verify_integration.ps1 checks package, demo project, existing certificate and native network/FCM/analytics safeguards.
- `run_android.ps1`: `flutter drive --driver=test_driver/household_departure_recovery.dart --target=integration_test/household_departure_recovery_test.dart --use-application-binary=build/stage15/departure-recovery/integration.apk --flavor=local -d emulator-5564 --keep-app-running`. First workflow exit1 after4checkpoints/31s; final exit0 after10checkpoints/84s. Raw secret-bearing action/invitation/native UID values redacted; no assertion/failure text hidden.
- `flutter test`: final run in flutter-tests-final.txt/.exit after all product edits. Do not infer completion until exit file/final passed line exists.
- `build_tester.ps1`: serialized final release-flavor demo build with existing tester signer; checks in verify_tester.ps1. No signing secrets generated/read. Artifact build/stage15/departure-recovery/whatmeal-local-tester.apk.
- `install_final.ps1`: verified hash/AVD, adb install-r, cold launch, bounded UI observation without any automatic dialog dismissal or data clearing. Home observations represent cached startup because the normal backend is stopped.
- Final disposable-only export: fixture-export.txt/.exit0. Temporary proxy/backend stopped intentionally after export; shell interruption exits are not test outcomes.

Process-only Java/Gradle settings match previous verified local setup (JBR, Unix-domain temp under audit/stage15,768MB Gradle heap, Kotlin compiler in-process). No OS security/firewall changes. Full65 security reset suite was not rerun; five protected file hashes remain unchanged.

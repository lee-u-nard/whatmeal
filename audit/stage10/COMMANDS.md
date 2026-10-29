# Stage 10 commands and evidence

Working directory is the WhatMeal repository. Flutter commands are serialized. Matching `.exit` files record completed exit codes; a missing file, interrupted run or partial checkpoints do not establish a pass. No production commands were run.

Installed Flutter: `C:/Users/ASUS V16/flutter_windows_3.44.5-stable/flutter/bin/flutter.bat`.
Java/Gradle process-local setup (no system settings changed):

```powershell
$env:JAVA_HOME='C:/Program Files/Android/Android Studio/jbr'
$env:PATH="$env:JAVA_HOME/bin;$env:PATH"
$env:JAVA_TOOL_OPTIONS='-Djdk.net.unixdomain.tmpdir="' + (Resolve-Path audit/stage10).Path + '"'
$env:GRADLE_OPTS='-Dorg.gradle.jvmargs=-Xmx768m'
Set-Item Env:ORG_GRADLE_PROJECT_kotlin.compiler.execution.strategy -Value 'in-process'
```

| Command | Logs / evidence |
|---|---|
| `flutter test test/grocery_editor_test.dart` | `grocery-editor-tests.txt` / `.exit`: 4 passed, exit 0 |
| `flutter test test/grocery_editor_test.dart test/notification_inbox_test.dart` | `focused-tests.txt`: 6 passed, exit 0 |
| Same focused command after adding actual grocery-tile enlarged-text regression | `focused-expanded-tests.txt`: 6 passed / 1 failed, exit 1; reproduced 35 px overflow |
| Same command after tile repair | `focused-fixed-tests.txt`: 7 passed, exit 0 |
| `flutter build apk --debug --flavor local --target integration_test/stage10_workflow_test.dart --target-platform android-x64 --dart-define=WHATMEAL_EMULATOR_HOST=10.0.2.2` | `build-integration.txt`: exit 0, 95.9 s; copied to `build/stage10/integration.apk` |
| `android/gradlew.bat --stop` | `gradle-stop.txt`; audit Gradle daemon stopped before driving |
| `adb -s emulator-5564 emu avd name` | Confirmed `whatmeal-stage9-aosp`; boot property 1, demo backend ports 9099/8180 listening |
| `adb -s emulator-5564 shell pm clear com.example.whatmeal.local` | `app-reset.txt`: Success; only isolated app test state cleared |
| `flutter drive --driver=test_driver/stage10_workflow.dart --target=integration_test/stage10_workflow_test.dart --use-application-binary=build/stage10/integration.apk --flavor=local -d emulator-5564` | `android-ui-first.txt`: exit 1, 3:36; route-information assertion failed after opening history. Later phases did not run. `android-phases-first-failed.json` preserved |
| `adb -s emulator-5564 emu kill` | Stopped only confirmed audit AVD before next verification/build batch |
| `flutter test` then `flutter analyze` | `flutter-tests.txt` / `.exit`, `flutter-analyze.txt` / `.exit`; consult completed results |

The first integration build used the existing Stage 9 AVD/backend still running; process inspection confirmed that only afterward. No concurrent Flutter commands ran. The AVD was explicitly stopped for the subsequent full-suite/analysis/build batch. Backend remains demo Auth/Firestore only, using `firebase.audit.json`; generated email action links are not copied to this report.

The history assertion used GoRouter's route-information URL, which did not expose the imperatively pushed detail's query parameters. The replacement assertion inspects the actual rendered `MealDetailPage.planPath` and `mealId`, retaining exact-identity coverage. This is a harness correction, not evidence that the application's history navigation was broken.

## Subsequent targeted verification

- Full suite `flutter-tests.txt`: 203 passed, exit 0, 1:50. Initial analysis `flutter-analyze.txt`: exit 1, 1 warning / 5 infos, 42.3 s. Fixed missing confirmation wiring, interpolation and braces. `targeted-final.txt`: 9 passed, exit 0. `analyze-fixed.txt`: clean, exit 0, 11.4 s.
- Same integration build: `build-integration-final.txt`, exit 0, 82.6 s. Gradle stopped; confirmed AOSP AVD booted with host graphics on 5564. `pm clear` returned Failed; `pre-run-packages.txt` confirmed local package absent, so the new APK could be installed into a clean state. No permission bypass or system dialog dismissal.
- Same drive command: `android-ui-final.txt`, exit 1, 3:43. History opened the exact reused plan/meal. Subsequent logout failed because the helper assumed the current route was Family Sharing; it searched for a nonexistent Back control and selected an off-screen calendar scroller. `android-phases-navigation-failed.json` preserves completed checkpoints. No later phases counted as passes.
- Helper now explicitly distinguishes household versus shell logout. Scroll searching uses only visible vertical scrollables; missed taps remain fatal. Added actual visible unread-badge assertions using a nonvisual widget key. Stage 9 fixture and driver were not changed.
- Same serialized integration build after this correction: `build-navigation-fixed.txt`, exit 0, 102.9 s. Confirmed audit AVD stopped for the build, then relaunched with identical isolated settings and verified free 5564/5565 ports (`avd-navigation-*`).

The expanded fixture's offline check uses `FirebaseFirestore.disableNetwork()` on the already asserted demo project, restores it in `finally`, and retries the retained draft. Firestore transactions require connectivity; this tests visible failure/retry, not a claim that transactions queue offline. The local AI guard check calls the app service directly and asserts unchanged demo quota; it is not an AI provider or AI-generation UI test.

- `android-ui-navigation-fixed.txt`: exit 1, 5:30, 33 checkpoints. No inline error arrived within the deadline after SDK networking was disabled; the operation state was not established. Network was restored by `finally`. Later sharing/clear/delete/settings/AI-guard checks did not run. The focused fixture explicitly asserts the observed pending state and then recovery after reconnect; it records an ordinary retry if the SDK reports a visible failure. No application operation is abandoned using `Future.timeout`.
- `flutter test test/ai_provider_retry_test.dart`: `provider-retry-before.txt` records a test compilation failure; `provider-retry-reproduced.txt` records the corrected test failing on absent Retry Settings (0 passes / 1 failure).
- `flutter test test/ai_provider_retry_test.dart test/ai_provider_sync_test.dart`: `provider-retry-fixed.txt`, 11 passed, exit 0, 14 s. `flutter analyze`: `analyze-recovery.txt`, clean, exit 0, 63.6 s.
- Focused build, with AVD stopped: `build-grocery-recovery.txt`, exit 0, 114.3 s. Same Java/Gradle settings; target `integration_test/stage10_grocery_recovery_test.dart`, plus `--dart-define=STAGE10_MEMBER_EMAIL=<fixture email>` and `--dart-define=STAGE10_FAMILY_ID=<fixture household>`. Identifiers come from the preceding isolated run and are in `fixture.json`; they are validated as demo-only strings before building. No password/key/token is supplied as a build argument. Output copied to `build/stage10/grocery-integration.apk`; Gradle stopped.

The focused fixture reuses an existing authorized demo member and exact household to avoid repeating completed lifecycle checks. It uses ordinary login, deletes only named prior groceries through UI confirmations, then repeats manual grocery mutations and remaining recovery/sharing/clearing assertions. The fixture identifiers are ephemeral: a security-suite database reset invalidates its membership data; recreate through the combined UI fixture before reproducing it after such a reset.

## Resumed isolated transport test

- Prior AVD/backend were absent on continuation (connection refused; no 8180/9099 listener). Restarted only approved demo Auth/Firestore: same emulator command above with process-local Java workaround. Generated email action URLs are redacted in backend.txt.
- node --test audit/stage10/firestore_relay.test.mjs: initial sandbox run failed EACCES, preserved relay-tests-sandbox-failed.*; authorized local run relay-tests.* passed 1 test, exit 0.
- Started node audit/stage10/firestore_relay.mjs hidden, fixed loopback ports 8181/8182, fixed target 8180. It never logs payloads.
- flutter analyze: analyze-relay.* exit 1, 9 unused import/helper warnings in newly composed fixture; removed those imports/helper.
- flutter build apk --debug --flavor local --target integration_test/stage10_grocery_recovery_test.dart --target-platform android-x64 --dart-define=WHATMEAL_EMULATOR_HOST=10.0.2.2 --dart-define=WHATMEAL_FIRESTORE_EMULATOR_PORT=8181: build-relay-integration.*. Fresh fixture registers/verifies owner and member and redeems invitation through app UI; no dependency on lost in-memory fixture.

- build-relay-integration.*: exit 0, 162.6 s. A pending button shows a spinner instead of Save Changes text; corrected the test selector to inspect the sheet button itself. Rebuilt serially to ensure APK includes that correction: build-relay-final.* exit 0, 101.5 s. Gradle stopped after each build; no AVD ran during these builds.
- Launched only whatmeal-stage9-aosp with the same host-graphics/dedicated-port settings (avd-relay-*).

- flutter drive --driver=test_driver/stage10_workflow.dart --target=integration_test/stage10_grocery_recovery_test.dart --use-application-binary=build/stage10/relay-integration.apk --flavor=local -d emulator-5564: android-relay-recovery.* exit 1, 2:51; all grocery checkpoints finished, then off-screen lazy AI-settings text wait timed out. android-phases-relay-result.json retained. Relay restored online with dropped=3; no ANR reported.
- Added ordinary scrolling before exact default-provider text assertion. Stopped confirmed AVD; same serialized integration build to build-recovery-scroll.*, Gradle stopped afterward.

- flutter test test/ai_provider_retry_test.dart: provider-layout-reproduced.* exit 1 (1 pass/2 failures); provider-layout-compile-failed.* exit 1 (syntax error); provider-layout-fixed-final.* exit 1 (1 pass/2 failures, additional heading overflow); provider-layout-complete.* exit 0, 3 passed.
- FIRESTORE_EMULATOR_HOST=127.0.0.1:8180 node audit/stage3/security_acceptance.mjs: security-acceptance.* exit 1, 64/65 (initial reset HTTP 499); unchanged rerun security-acceptance-rerun.* exit 0, 65/65. Database resets affect demo emulator only and occurred with the AVD stopped.
- Final serialized flutter test and flutter analyze: flutter-tests-final.* and flutter-analyze-final.*; then same isolated relay integration build to build-recovery-layout-fixed.* with Gradle stopped afterward.

- flutter-tests-final.*: exit 0, 206 passed, 1:31. flutter-analyze-final.*: exit 1, one unused integration-fixture import, 50.2 s; removed import only. flutter-analyze-clean.*: exit 0, no issues, 4.7 s. No repeated full suite was needed for this import-only fixture cleanup.

- build-recovery-layout-fixed.*: same isolated relay integration build, exit 0, 53.6 s; Gradle stopped, AVD restarted after confirming dedicated ports free.
- Same focused flutter drive command: android-recovery-layout-fixed.* **exit 0**, one workflow, 13 checkpoints, 1:58 (framework +2 includes teardown). android-phases-recovery-passed.json retained; no ANR. Relay restored online and stopped by verified PID/command identity; AVD stopped before standalone compilation.
- WHATMEAL_TESTER_SIGNING=true flutter build apk --release --flavor local --target lib/main.dart --dart-define=WHATMEAL_EMULATOR_HOST=10.0.2.2: build-tester.* exit 0, 76.5 s, 55.2 MB. Default Firestore 8180, no alternate port define. Existing keystore confirmed; release credential file absent. Gradle stopped, copied to build/stage10/whatmeal-local-tester.apk.
- audit/stage10/verify_tester.ps1 runs aapt2 dump badging/xmltree/resources, apkanalyzer project_id only, apksigner verify --verbose --print-certs and Get-FileHash SHA256. First helper attempt failed argument binding before installation; apk-verification-first-failed.* retained. Corrected helper apk-verification.* exit 0. No private resource or key material printed.

- Confirmed whatmeal-stage9-aosp on 5564; boot=1; adb install -r build/stage10/whatmeal-local-tester.apk: tester-install.* exit 0. adb shell am start -W -n com.example.whatmeal.local/com.example.whatmeal.MainActivity: tester-launch.* exit 0, COLD, TotalTime 1151 ms. dumpsys window/activity lastanr, screencap and pull recorded tester-focus.txt, tester-anr.txt and tester-startup.png (screenshot exit 0). Image visually inspected. No system dialogs or permissions were bypassed.
- git diff --check: diff-check.*; protected-final.json confirms four security/native files unchanged, with only the explicitly documented main.dart local relay option changing its baseline hash.

- After evidence capture: confirmed AVD name then adb emu kill (tester-avd-stop.* exit 0); intentionally interrupted this continuation's demo backend. Final Get-NetTCPConnection inspection found no remaining test listeners on 8180/8181/8182/9099/5564/5565. Recomputed artifact SHA-256 and checked final result exit files: all final tests/analysis/security/Android/build/verification/install/startup/diff-check are 0. Backend interruption is resource cleanup, not an acceptance result.

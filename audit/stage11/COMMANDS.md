# Reproduction commands

Run from the repository root. Toolchain and AVD settings match audit/stage10/COMMANDS.md and TESTER.md. Logs have matching .exit files; interrupted or failed commands remain failures.

- flutter test test/account_recovery_test.dart: account-reproduced.*, account-fixed.* (compile failure), account-fixed-final.*.
- flutter test test/profile_pantry_recovery_test.dart test/pantry_edit_test.dart test/account_recovery_test.dart: recovery-focused.*.
- flutter test test/account_recovery_test.dart test/profile_pantry_recovery_test.dart: recovery-expanded.* and recovery-expanded-fixed.*.
- flutter test test/profile_pantry_recovery_test.dart: profile-layout-reproduced.*.
- flutter analyze: analyze-initial.* and analyze-device-fixture.*. dart fix --apply was restricted to curly_braces_in_flow_control_structures and unnecessary_non_null_assertion; lint-fixes.txt/lint-final-fixes.txt identify exact files.
- Final flutter test then flutter analyze: flutter-tests.* / flutter-analyze.*. One serialized command at a time, AVD stopped.
- firebase emulators:start --only auth,firestore --project demo-whatmeal-audit --config firebase.audit.json: backend.txt, generated action URLs redacted. Only fixed loopback Auth9099/Firestore8180.
- node audit/stage10/firestore_relay.mjs: fixed loopback8181 to8180 and control8182; no payload inspection or logging.
- flutter build apk --debug --flavor local --target integration_test/stage11_recovery_test.dart --target-platform android-x64 --dart-define=WHATMEAL_EMULATOR_HOST=10.0.2.2 --dart-define=WHATMEAL_FIRESTORE_EMULATOR_PORT=8181: build-integration.*; copied to build/stage11/recovery-integration.apk; Gradle stopped afterward.

Build process-local settings (same safe Java selector workaround): JAVA_HOME=C:/Program Files/Android/Android Studio/jbr; JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=<absolute audit/stage11 path>; GRADLE_OPTS=-Dorg.gradle.jvmargs=-Xmx768m; ORG_GRADLE_PROJECT_kotlin.compiler.execution.strategy=in-process. Backend uses an additional -Xmx512m. No system configuration was changed.

- AVD: existing emulator36.6.11, ANDROID_AVD_HOME=<workspace>/build/audit-avds, ANDROID_HOME/ANDROID_SDK_ROOT=<workspace>/build/android-sdk-audit. Launch hidden: -avd whatmeal-stage9-aosp -no-window -no-audio -no-snapshot -gpu host -memory 1536 -cores 2 -port 5564. Confirm name and boot=1. Only com.example.whatmeal.local data was cleared (app-reset.* exit 0).
- flutter drive --driver=test_driver/stage11_recovery.dart --target=integration_test/stage11_recovery_test.dart --use-application-binary=build/stage11/recovery-integration.apk --flavor=local -d emulator-5564: android-recovery.* and android-phases-first.json. Pass/count only after final completion.
- Full Flutter suite exit 0: 219 passed (1:02); analysis exit 0: no issues (26.5 s); integration build exit 0 (62.6 s).

- First Android run android-recovery.* exit 1, 2:36, 13 checkpoints before pantry retry timed out; preserved android-phases-first.json and no-ANR result. Relay remained online.
- Added strict authorized Source.server read/scope diagnostics before retry. flutter analyze: analyze-recovery-probe.* exit 0, no issues, 20.7 s. Same serial debug build: build-recovery-probe.* exit 0, 52.5 s.
- Same drive command: android-recovery-probe.* exit 0, 17 checkpoints, 2:14. Recovery showed one unavailable read before server success; scope/household unchanged. android-phases-probe.json retained. AVD stopped before release build; test relay stopped by verified PID/command identity.
- FIRESTORE_EMULATOR_HOST=127.0.0.1:8180 node audit/stage3/security_acceptance.mjs: security-acceptance.* exit 1, 64/65, initial fixture-reset HTTP499; unchanged rerun security-acceptance-rerun.* exit 0, 65/65. Emulator-only fixture resets occurred after UI testing.
- WHATMEAL_TESTER_SIGNING=true flutter build apk --release --flavor local --target lib/main.dart --dart-define=WHATMEAL_EMULATOR_HOST=10.0.2.2: build-tester.*. Existing debug key required; release credential file confirmed absent. Default Firestore8180; no relay define; normal platform regeneration enabled. verify_tester.ps1 targets build/stage11 and records public package/project/certificate/network/hash evidence.

- build-tester.* exit0, 80.2s, 55.2MB; verify_tester.ps1 exit0. Public package/project/signature/native policy/hash evidence saved. Stage 10 artifact/evidence not overwritten.
- Confirmed whatmeal-stage9-aosp boot=1 on5564; adb install -r build/stage11/whatmeal-local-tester.apk exit0; adb shell am start -W -n com.example.whatmeal.local/com.example.whatmeal.MainActivity exit0, COLD TotalTime1592ms. dumpsys window/activity lastanr, screencap/pull recorded tester-focus.txt, tester-anr.txt, tester-startup.png; image visually inspected.

- Final code identity check inspected only two public fixed-message booleans in lib/x86_64/libapp.so (apk-code-check.json), not private resource values. New messages are present only in the new artifact. git diff --check exit0; tester-avd-stop.* exit0. Demo backend intentionally interrupted after testing; this is cleanup, not a failed acceptance test. No test listeners remained.

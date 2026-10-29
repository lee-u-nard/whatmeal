# Stage 14 command ledger

All commands run from repository root. Each child exit is stored in matching .exit; PowerShell wrapper exit alone is not a test result. Only demo-whatmeal-audit and dedicated emulator-5564; no production/live AI commands.

- flutter test test/notification_recovery_test.dart -> notification-reproduced.* exit1, fixture compile error; no product test executed.
- Same corrected fixture -> notification-reproduced-valid.* exit1,0pass/3fail: atomic account state, Retry session version, disposal subscriptions.
- flutter test test/notification_recovery_test.dart test/notification_inbox_test.dart test/household_activity_store_test.dart -> notification-fixed.* exit0,7pass.
- Above plus test/ai_provider_retry_test.dart -> recovery-expanded.* exit0,12pass (before sixth new test added).
- flutter analyze -> analyze-initial.* exit1, one protected-member test warning; fixed without suppression.
- flutter test -> flutter-tests.* exit0,243pass,1:05. Then flutter analyze -> analyze.* exit1,one unnecessary test import. Removed that import only; flutter analyze -> analyze-clean.* exit0,clean3.3s. No product change after full suite.
- Escalated cached Dart format -> format.* exit0. Prior non-escalated Dart formatter failed with resolvedExecutable environment error; not a test pass. Initial JavaScript fixture wrapper failed before creating file due interpolation; literal construction fixed, analysis checked actual fixture.
- firebase emulators:start --only auth,firestore --project demo-whatmeal-audit --config firebase.audit.json. Backend console action URLs redacted in backend.txt.
- flutter build apk --debug --flavor local --target integration_test/stage14_inbox_settings_test.dart --target-platform android-x64 --dart-define=WHATMEAL_EMULATOR_HOST=10.0.2.2 -> build-integration.*. Normal platform regeneration, no --no-pub. AVD stopped during build.

Process-local Java: Android Studio bundled jbr; JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir="<absolute audit/stage14>"; backend additionally -Xmx512m. GRADLE_OPTS=-Dorg.gradle.jvmargs=-Xmx768m; ORG_GRADLE_PROJECT_kotlin.compiler.execution.strategy=in-process. No system/security changes.
- Debug integration build -> build-integration.* exit0,62.5s. Native demo project checked with apkanalyzer resources value project_id. Install/reset only com.example.whatmeal.local exited0. flutter drive --driver=test_driver/stage14_inbox.dart --target=integration_test/stage14_inbox_settings_test.dart --use-application-binary=build/stage14/inbox-integration.apk --flavor=local -d emulator-5564 --keep-app-running -> android-inbox.* exit0,42s,9checkpoints/one combined workflow. Screenshot inspected; dumpsys activity lastanr -> android-anr.txt. Confirmed AVD name before emu kill, exit0.
- flutter build apk --release --flavor local --target lib/main.dart --dart-define=WHATMEAL_EMULATOR_HOST=10.0.2.2 with WHATMEAL_TESTER_SIGNING=true -> build-tester.*. Existing debug.keystore presence checked only; android/key.properties absent. No signing secret generated or printed.

- build-tester.* exit0,79.1s. audit/stage14/verify_tester.ps1 -> apk-verification.* exit0. Final tester install/reset/cold-start each exit0; COLD TotalTime1156ms; screencap/pull -> tester-startup.png (visually inspected), dumpsys activity lastanr -> no ANR.
- Confirmed AVD whatmeal-stage9-aosp before emu kill -> avd-stop-tester.* exit0. Demo backend deliberately interrupted (wrapper exit1). Test services stopped after evidence; ports/protected hashes checked separately.

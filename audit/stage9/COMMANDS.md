# Stage 9 commands

Working directory is the WhatMeal repository. Commands run serially for Flutter. Exit codes are recorded in matching `.exit` files; logs alone do not imply success. SDK image download may overlap compilation, but no Android VM runs during compilation.

Installed tools:

```powershell
$flutter = 'C:/Users/ASUS V16/flutter_windows_3.44.5-stable/flutter/bin/flutter.bat'
$env:JAVA_HOME = 'C:/Program Files/Android/Android Studio/jbr'
$env:PATH = "$env:JAVA_HOME/bin;$env:PATH"
$env:JAVA_TOOL_OPTIONS = '-Djdk.net.unixdomain.tmpdir="' + (Resolve-Path audit/stage9).Path + '"'
$env:GRADLE_OPTS = '-Dorg.gradle.jvmargs=-Xmx768m'
Set-Item Env:ORG_GRADLE_PROJECT_kotlin.compiler.execution.strategy -Value 'in-process'
```

Compiled before starting the AVD:

```powershell
& $flutter build apk --debug --flavor local --target integration_test/local_workflow_test.dart --target-platform android-x64 --dart-define=WHATMEAL_EMULATOR_HOST=10.0.2.2
& android/gradlew.bat --stop
Copy-Item build/app/outputs/flutter-apk/app-local-debug.apk build/stage9/household-integration.apk
& $flutter analyze
```

Workspace-only official system image installation:

```powershell
& build/android-sdk-audit/cmdline-tools/latest/bin/sdkmanager.bat "--sdk_root=$((Resolve-Path build/android-sdk-audit).Path)" 'system-images;android-35;default;x86_64'
```

First device execution (`household-ui.txt`, exit 1; emulator access violation, incomplete):

```powershell
& $flutter drive --driver=test_driver/local_workflow.dart --target=integration_test/local_workflow_test.dart --use-application-binary=build/stage9/household-integration.apk --flavor=local -d emulator-5554
```

This runs a previously compiled actual Android app, not mocked Flutter repositories. Firebase must separately run only Auth/Firestore with `--project demo-whatmeal-audit --config firebase.audit.json`. Emulator-generated email links must be redacted from captured logs. No automatic dismissal of system dialogs or weakening of clipboard permissions is part of this workflow.

## October 14 continuation

- `flutter test test/profile_headings_test.dart`: 2 passed, exit 0 (`profile-tests.txt`).
- Same integration APK build command above after profile fixes: exit 0 (`build-profile-fixed.txt`, 106.6 s); copied to `build/stage9/household-integration.apk`; Gradle daemon stopped.
- Existing emulator 36.6.11 launched with `-avd whatmeal-stage9-aosp -no-window -no-audio -no-snapshot -gpu swiftshader -memory 1536 -cores 2 -port 5554`. Boot reported 35,509 ms, but no ADB connection. Port inspection identified unrelated MuMuNxDevice.exe listening on 5555. A loopback ADB connection was immediately disconnected without app/device interaction. Only the audit QEMU process was stopped. This is not a passed device run.
- Relaunched with identical arguments except `-port 5564`, checked unused first. Output: `avd-runtime36-port5564-stdout.txt`, stderr and monitored `.exit` alongside it.
- Backend: `firebase emulators:start --only auth,firestore --project demo-whatmeal-audit --config firebase.audit.json`, same process-local Java workaround plus `-Xmx512m`; sanitized `backend-runtime36.txt`. Ready on 9099/8180.

## October 15 input investigation

`household-ui-input-focus.txt`: exit 1, owner registration/verification completed; input-retention assertion failed for the prefilled household name. No persisted-name or full household pass. Installed Flutter `flutter_test/lib/src/test_text_input.dart` explicitly warns that injected editing updates with a real IME can confuse input state. The integration harness now registers Flutter's deterministic test text-input handler and unregisters at teardown. This is simulated typing, not native-keyboard acceptance. Android navigation/rendering, clipboard and Firebase SDK calls remain real; no permission changes.

`build-test-input.txt` records the subsequent serial integration build with the same arguments above.

## October 16 serialized verification

- `build-member-core.txt`: interrupted, no exit result; not passed.
- Same debug integration build resumed to `build-member-core-resumed.txt`: exit 0, 133.8 s. Copied binary and stopped Gradle before booting AVD.
- AVD: existing emulator 36.6.11, same AOSP image, `-gpu host`, dedicated `-port 5564`, 1536 MB/2 cores. No system/driver/security changes.
- Same `flutter drive` command with `-d emulator-5564`, `household-ui-member-core.txt`: exit 1; 2:10 test failure. Completed through owner removal; next invitation finder timed out because its lazy-list child was off screen. `after-removal.png` shows the remaining owner and repaired member row. Subsequent core phases did not execute.
- Added ordinary scrolling for off-screen controls. Same integration build logs `build-scroll.txt`, then serial `flutter test` to `tests-member-final.txt` and `flutter analyze` to `analyze-member-final.txt`. AVD remains stopped for all three commands. Counts/results are valid only when matching exit files exist.

Latest serialized commands use the same environment/build arguments above:

- `flutter test`: `tests-meal-actions-final.txt`, exit 0, 188 passed.
- `flutter analyze`: `analyze-meal-actions-final.txt`, exit 0, no issues.
- `flutter drive --driver=test_driver/local_workflow.dart --target=integration_test/local_workflow_test.dart --use-application-binary=build/stage9/household-integration.apk --flavor=local -d emulator-5564`: `core-ui-expanded.txt`; count/pass only after completion. Installed app was absent before this run. Same confirmed AVD name, demo backend and host graphics launch option.

## Final completed verification (supersedes intermediate pending results)

After the saved-plan action repair, the same serialized debug integration build completed (`build-saved-final.txt`, exit 0). The AVD was stopped during compilation, tests and analysis; Gradle was stopped before AVD boot.

| Command | Evidence | Actual result |
|---|---|---|
| `flutter test` | `tests-saved-final.txt` / `.exit` | Exit 0; 194 passed, 1:33 |
| `flutter analyze` | `analyze-saved-final.txt` / `.exit` | Exit 0; no issues, 49.5 s |
| `flutter drive --driver=test_driver/local_workflow.dart --target=integration_test/local_workflow_test.dart --use-application-binary=build/stage9/household-integration.apk --flavor=local -d emulator-5564` | `core-ui-saved-final.txt` / `.exit`, `android-phases-core-passed.json` | Exit 0; one combined workflow, 28 checkpoints, 3:18; framework +2 includes teardown |

AVD launch used existing `C:/Android/Sdk/emulator/emulator.exe` 36.6.11 with `ANDROID_AVD_HOME` pointing to workspace `build/audit-avds`, SDK environment pointing to `build/android-sdk-audit`, and arguments:

```powershell
-avd whatmeal-stage9-aosp -no-window -no-audio -no-snapshot -gpu host -memory 1536 -cores 2 -port 5564
```

The prior 65 passing security cases were preserved, not rerun. No live AI call or push test was run. A host-GPU attempt stalled at the native splash and was interrupted; its shell exit 0 is not counted as test success. Only the final completed workflow above is the Android acceptance pass.

With the AVD stopped, using the process-local Java/Gradle settings above:

```powershell
$env:WHATMEAL_TESTER_SIGNING = 'true'
flutter build apk --release --flavor local --target lib/main.dart --dart-define=WHATMEAL_EMULATOR_HOST=10.0.2.2
```

`build-tester.txt` / `.exit`: exit 0, 118.3 s, 55.8 MB. Copied output to `build/stage9/whatmeal-local-tester.apk`; existing debug signer reused. Normal platform regeneration remained enabled.

Android SDK verification commands below use `C:/Android/Sdk/build-tools/36.0.0/` for aapt2/apksigner and `C:/Android/Sdk/cmdline-tools/latest/bin/` for apkanalyzer:

```powershell
aapt2 dump badging build/stage9/whatmeal-local-tester.apk
apksigner verify --verbose --print-certs build/stage9/whatmeal-local-tester.apk
apkanalyzer resources value --config default --name project_id --type string build/stage9/whatmeal-local-tester.apk
aapt2 dump xmltree build/stage9/whatmeal-local-tester.apk --file AndroidManifest.xml
aapt2 dump resources build/stage9/whatmeal-local-tester.apk
aapt2 dump xmltree build/stage9/whatmeal-local-tester.apk --file res/M2.xml
Get-FileHash build/stage9/whatmeal-local-tester.apk -Algorithm SHA256
```

These checks passed; corresponding `apk-*.txt` logs record package, SDK/ABIs, certificate, demo project, manifest guards, compiled network XML and SHA-256. No API-key resource was queried. The first lookup by source XML name failed because release optimization renamed it; `apk-network-security-path-attempt.txt` retains that failure. Resource-ID resolution established `res/M2.xml` before its successful inspection.

After booting and confirming only the intended AVD:

```powershell
adb -s emulator-5564 emu avd name
adb -s emulator-5564 install -r build/stage9/whatmeal-local-tester.apk
adb -s emulator-5564 shell am start -W -n com.example.whatmeal.local/com.example.whatmeal.MainActivity
adb -s emulator-5564 shell dumpsys activity lastanr
```

Install and launch both exit 0 (`tester-install.txt`, `tester-launch.txt` and matching exit files). Cold-start status OK, TotalTime 2008 ms. `tester-startup.png` visibly shows Sign In; `tester-focus.txt` confirms the WhatMeal activity; `tester-anr.txt` reports no ANR since boot. This standalone release-mode startup is separate from the debug integration workflow.

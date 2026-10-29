# Stage 8 — isolated Android startup and household verification

Updated 2026-10-13. Work remains local; this is not a production release or full application certification.

## Implemented repairs

- **Tester configuration isolation:** Stage 7 selected demo Firebase in Dart but retained the existing native Google Services configuration. Added separate `local` / `production` Android flavors, a `.local` package, matching dummy native demo resources, and startup project validation. Do not launch the superseded Stage 7 APK for isolated testing.
- **Local messaging isolation:** centralized the emulator flag and disabled native FCM auto-init plus token initialization/refresh/logout cleanup for local builds. Local HTTP is permitted only for localhost and Android's host alias. Live AI and native push are not verified by this mode.
- **Registration:** preserved sanitized repository messages and fixed the checkbox's missing local Material ancestor. The new widget regression reproduces retry/error handling and checks that internal exceptions are not shown.
- **Household narrow-screen layout:** the real 320-pixel Android run reproduced three horizontal overflows after creating a household (name, invitation card, member heading). Constrained text with Expanded so it wraps while retaining styling and controls. The subsequent session-fixed device run reached invitation copying without those layout exceptions; the complete household test still did not pass.

## Actual execution evidence

- Local debug integration APK built and installed; Android activity and Dart VM started on the workspace-local API 35 AVD.
- Generated native project/app/sender resources were checked and match the demo Dart values.
- Real Flutter application registration and email verification reached the household screen against demo Auth/Firestore. Household creation and invitation issuance were reached in the later test, which failed on layout exceptions and reading the clipboard before copy completion.
- Earlier test failures were retained: email fixture case normalization, an underlying-page button selected instead of the open sheet, and a first runner connection stall. Selectors now target the sheet, wait for settled layout, and fail on missed taps. The clipboard check waits for the app's success message.
- `registration-fixed.txt`: 1 widget regression passed.
- `analyze-current.txt` and final `analyze-final.txt`: analysis passed, no issues; final run includes the session-reset and non-sensitive checkpoint markers in the device test.
- `tests-current.txt`: all 176 Flutter tests passed; process exit 0. Analysis also exited 0.
- `device-workflow-responsive-fixed.txt`: interrupted after the test began; no final pass/fail. Android processes were gone on continuation. Do not count this as a pass.
- `device-workflow-final.txt`: failed because a retained native session from the interrupted run changed the initial route. Added ordinary app logout during test setup.
- `device-workflow-session-fixed.txt`: reached household creation/copy-success without layout errors, but clipboard read was denied. Android ClipboardService logs showed the app lacked focus because bundled Messaging/Wellbeing/System UI ANR dialogs were on top. These dialogs were dismissed only in the disposable AVD; no permissions were bypassed.
- `device-workflow-focus-fixed.txt`: device went offline during the test; exit 79, test and teardown did not complete. No full two-account UI pass. Added non-sensitive phase markers for the next run.
- `build-local-resumed.txt`: serial release still failed with stale integration-test plugin registration. This corrected the earlier concurrency-only hypothesis: the installed Flutter skips platform tooling regeneration when `--no-pub` is used. Its release Gradle excludes dev plugins, leaving an incompatible debug registrant.
- `build-local-regenerated.txt`: normal serial release build **passed**, exit 0, 55.8 MB `build/app/outputs/flutter-apk/app-local-release.apk`. Regenerated release registrant contains no integration-test plugin. No tests were removed and generated source was not hand-edited.
- `apk-signature.txt`: APK signature verification passed. `apk-identity.txt`: separate `com.example.whatmeal.local` package, minimum SDK 24, target SDK 36. `apk-sha256.txt` records artifact identity. This standalone release-mode tester APK has not been installed/verified after the AVD went offline; prior device execution used the debug integration APK.
- Prior 65 security acceptance cases remain unchanged; they were not rerun because no security rules changed in this batch. Stage 7 backend REST acceptance remains historical evidence, not device evidence.

## Files changed in this stage

`android/app/build.gradle.kts`, `android/app/src/local/{google-services.json,AndroidManifest.xml,res/xml/local_network_security.xml}`: isolated native build configuration and flavor-aware signing gate.

`lib/main.dart`, `lib/core/config/runtime_environment.dart`, `lib/core/services/notification_service.dart`: matching demo startup and local-mode messaging safeguards.

`lib/features/auth/pages/register_page.dart`, `test/register_failure_feedback_test.dart`: registration repairs and regression.

`lib/features/family/pages/family_space_page.dart`: reproduced narrow-screen overflows.

`pubspec.yaml`, `pubspec.lock`, `integration_test/local_workflow_test.dart`: Android SDK/UI acceptance harness using only demo email actions and normal application controls.

`README.md`, `WHATMEAL_FUNCTIONALITY.md`, `audit/stage7/TESTER.md`, `audit/stage8/*`: current instructions, superseded artifact warning, and honest execution records.

## Remaining work and boundaries

1. Finish the responsive household device rerun, then removal/rejoin and member/account isolation. One AVD with sequential accounts is not simultaneous two-device synchronization.
2. Exercise meal/pantry/grocery and history/read/routing behavior through the app; local regression tests do not establish device behavior.
3. Install the completed standalone local tester APK on a stable isolated device/AVD. Build and signature checks passed, but they do not establish device functionality. Keep platform generation enabled when switching build modes and avoid concurrent Flutter commands.
4. Live Gemini/custom provider tests remain pending explicit confirmation of a non-production test project/configuration. No live calls were made.
5. Native background push requires an approved trusted sender and appropriate test configuration. Local mode intentionally skips FCM.
6. Production signing identity and credential rotation remain owner actions; no signing secrets were generated or exposed and no key-storage migration occurred.

The host has approximately 8 GB RAM and severe paging during AVD/build overlap. Only audit processes were stopped to free memory; unrelated applications and system security settings were not changed. Existing Java workaround remains process-local. No production data was read for migration, modified, or deployed; no paid services or Cloud Functions were introduced.

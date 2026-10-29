# Stage 9 execution record

Local-only work, started 2026-10-13. Stage 8 files and all user changes are preserved. No production Firebase use, rule changes, live AI credentials, paid services, Functions, or automatic dismissal of failures is authorized.

## Environment diagnosis

Confirmed from Stage 8: Android ANR dialogs stole focus; ClipboardService denied WhatMeal clipboard reads. The final AVD disappeared/offlined and the UI test exited 79 without completion. The captured emulator stdout ends after successful boot and contains no definitive process-exit cause. A Stage 9 read-only Application event-1000 query found no matching emulator/qemu crash metadata in the prior three days. Absence of this event does not rule out a crash or external termination.

Host: about 8 GB physical RAM, only 575,640 KiB available at Stage 9 initial inspection. Stage 8 recorded paging and guest memory/CPU pressure. Resource contention is a supported hypothesis for instability, not a proven explanation of the process exit.

Targeted changes: prebuild an x86-64 test APK with the AVD stopped; stop the resulting Gradle daemon; execute that binary with Flutter drive. No concurrent Flutter platform regeneration. Create a separate plain AOSP API 35 AVD using the official image listed in the existing SDK catalog. Preserve the Google APIs Stage 8 AVD and do not disable its apps or any security controls.

## Tests

The household harness now uses actual Profile / Family Sharing navigation, native clipboard comparison without printing token values, and normal UI controls for returning-account login, removal, rejoin and departure. Every phase must finish; no timeout or interruption counts as a pass. The driver saves completed phase metadata even on test failure. The driver is not a mock backend; it connects to the test app on Android.

Core meal/pantry/grocery UI acceptance and final standalone APK startup remain pending the stable household run. Existing 176 Flutter tests and 65 security cases are historical evidence and are not rerun without a relevant change.

## Continued diagnosis (2026-10-14)

The monitored AOSP run exited with -1073741819 (0xC0000005). Windows Application event 1000 confirms access violations in workspace emulator 37.2.12's `qemu-system-x86_64-headless.exe` on October 12 and 13; the faulting module is unknown. See `windows-emulator-crashes.txt`. This supersedes the initial event-query result above. Memory pressure remains a hypothesis, not a proven crash cause.

`household-ui.txt` / `.exit` records a failed run (exit 1), with owner registration/verification, household creation and native invitation clipboard comparison completed before loss of the VM service. No complete household acceptance pass or driver response JSON was produced. The new Profile navigation exposed two actual narrow-screen overflows. The title now wraps beside Add, and the settings badge fits beside its icon. Both regression cases (normal and 2x text) passed: `profile-tests.txt`, exit 0.

A controlled comparison will use the already-installed emulator 36.6.11 runtime with the same disposable AOSP AVD. No host drivers, Android permissions, security settings, or unrelated apps are changed. The integration binary is rebuilt with the AVD stopped before this comparison.

## Firebase approval (unchanged)

No non-production live Firebase project has been explicitly confirmed and approved. Only the emulator demo ID `demo-whatmeal-audit` is approved, configured by `firebase.audit.json`, `android/app/src/local/google-services.json`, and the local-mode options in `lib/main.dart`. No live AI calls are authorized or made.

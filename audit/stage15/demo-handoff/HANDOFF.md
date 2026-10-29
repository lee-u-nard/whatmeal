# WhatMeal demonstration handoff — 2026-10-18

This is a bounded Stage 15 handoff, not a new development stage. Preserve the original account cache and private AVD backup. No production access, deployment, rule changes or live AI are authorized.

## Demonstration status

The original account's complete connected demonstration is **blocked**: original local Auth 9099 / Firestore 8180 are stopped, and no original paired server export is confirmed. Cached Home startup does not establish backend recovery. Do not start an empty primary backend, substitute the disposable fixture export, recreate the account or sign out the normal cached user.

| Demonstration step | Direct evidence and limits |
|---|---|
| Launch | Stage 15 food-recovery tester update-installed and cold-launched to cached Home without data clearing or visible ANR. Current launch check recorded separately below. |
| Authentication | Earlier Stage 15 32-checkpoint actual Android UI registration, emulator-only email action, login/logout; no real Gmail delivery. New shared test uses named native SDK accounts, not login-page typing. |
| Household access | Earlier actual Android UI create/copy/join/remove/rejoin/leave; departure follow-up used two named clients on one AVD. New shared food test result is recorded below. |
| Manual planning and saved plans | Earlier actual Android UI manual creation, identity/dates, favorites, reuse and statuses. New test seeds manual content through the real repository; it is not a repeat of the entire routed UI journey. |
| Pantry and groceries | Prior real editor/GroceryPage recovery: ten checkpoints. New shared account recovery result is recorded below; do not infer two physical devices. |
| Notifications | Earlier actual in-app history/read/routing and denied-feed Retry evidence. No native push/background/cold-start delivery certification. |
| AI | Live Gemini/custom providers pending an explicitly approved non-production project. No approved live project is configured. |

Historical sources: `../FINAL_REPORT.md`, `../departure-recovery/REPORT.md`, `../food-recovery/RESULTS.json`. Previous 294 passing Flutter tests, clean analysis and 65 historical security cases are retained; none proves live provider or device behavior.

## Current bounded test

`shared_food_recovery_test.dart` uses two disposable named native Firebase clients on one existing AVD, real SDK household invitation/membership operations, shared meal/pantry/grocery repositories, GroceryPage Retry/checkbox, NotificationsPage read actions, and a raw loopback member-connection gate. Only demo project `demo-whatmeal-audit`, separate Auth 9199 / Firestore 9180. Normal cached Auth is only checked for unchanged identity. Backup never overwritten/restored.

The first build was interrupted with a missing extension import in the new test harness; it has no completed exit result and is not a pass. Import corrected. Initial AVD launcher used the wrong process-local SDK root; corrected to the existing workspace system image, without changing its configuration or wiping data. Logs remain under ignored build/avd-handoff-*.

**Current Android result: PASS, exit 0, 56 seconds, all 10 checkpoints.** One workflow with teardown (the binding displays +2; this is not two independent workflows). The failed member transaction reported unavailable and server status stayed accepted. Exact saved dates/shortages, real denied-query Retry, owner-to-member pantry changes, member-to-owner purchased provenance, concurrent duplicate prevention, private read receipts, meal completion/deletion and removal/rejoin all passed. Cached default Auth identity was unchanged. `android-phases.json` and `android.txt` retain the evidence; `shared-food-recovered.png` was visually inspected.

No product defect was reproduced, so no application/rules/configuration change was needed. Changes are the new shared integration test/driver, bounded execution scripts and handoff evidence. The first import error was confined to the new harness. The final test APK built in 196.8 seconds, exit 0; package/native demo/signature verified, SHA-256 `81950980655DC78DC765EE9F95160DF0084FF893469689066484CB75EFBA5C9D`. This test APK is not the normal tester artifact.

The disposable export completed, exit 0: all 14 earlier fixture accounts retained plus two new accounts; normal cached account absent. Temporary services were stopped after export. Original backend ports remained stopped. The five protected rules/security-suite/native/main hashes match the Stage 15 baseline; private AVD backup untouched. Earlier 65 security acceptance cases were preserved, not rerun. Fresh complete Flutter/analysis and final tester results follow below after completion.

## Final artifact and readiness

- Complete Flutter suite: **294 passed, exit 0, 110 seconds**, once after final test edits. Analysis: **no issues, exit 0, 64.5 seconds**. Logs: flutter-tests-final.txt/.exit and analyze-final-complete.txt/.exit.
- Release-mode local tester: **build exit 0, 47.4 seconds, 55.4 MB**. Compiled package/demo/loopback policy/native analytics and messaging guards/existing v2 tester certificate verified. SHA-256 equals the previous verified tester: product artifact unchanged by the new test-only coverage.
- Exact APK: `C:\Users\ASUS V16\Desktop\jabez_projects\3RD_YEAR_SUBJECTS\App Dev\whatmeal\build\stage15\demo-handoff\whatmeal-local-tester.apk`
- SHA-256: `D80D00FB8A7D2652B6B2558A84D5CD4059A220B90C7709125C1B8A349F3FB06B`.
- Install and cold launch: both exit 0. Existing emulator-5564 / whatmeal-stage9-aosp; cached Home visible, app foreground, no visible ANR, no app-data clearing, normal backend ports still stopped. This is cached startup, not original server recovery. AVD/app left running; disposable services exported and stopped.

PowerShell install/run for the existing emulator:

```powershell
$adb = 'C:\Android\Sdk\platform-tools\adb.exe'
& $adb -s emulator-5564 install -r 'C:\Users\ASUS V16\Desktop\jabez_projects\3RD_YEAR_SUBJECTS\App Dev\whatmeal\build\stage15\demo-handoff\whatmeal-local-tester.apk'
& $adb -s emulator-5564 shell am start -W -n com.example.whatmeal.local/com.example.whatmeal.MainActivity
```

Do not uninstall/clear data. This APK is configured for Android-emulator host 10.0.2.2; physical-device connectivity is not verified and these commands do not establish it. The normal backend must only be restored from confirmed original data, not the disposable export.

**Readiness answer: not ready for the complete connected demonstration with the original cached account.** A limited cached/offline walkthrough is available. The earlier full routed UI path has direct historical Android evidence; today's two-account shared recovery has direct native SDK/GroceryPage/NotificationsPage evidence, not a fresh full routed app journey. Original backend recovery is the connected-demo blocker. Live AI still requires explicit approval of a separate non-production Firebase project; none is confirmed. Native push, two-device synchronization and production readiness are not claimed. Current emulator project: demo-whatmeal-audit, android/app/src/local/google-services.json and firebase.household-recovery.json. No production resources or secrets accessed, changed or deployed.

Reproducibility: build_integration.ps1 -> verify_integration.ps1 -> run_android.ps1; final_checks.ps1 -> build_tester.ps1 -> install_final.ps1, all serialized. New files: integration_test/shared_food_recovery_test.dart, test_driver/shared_food_recovery.dart, and this bounded demo-handoff evidence/scripts folder. No product implementation or security-rule change was necessary. Earlier failures/evidence preserved; no automatic follow-on stage is scheduled.

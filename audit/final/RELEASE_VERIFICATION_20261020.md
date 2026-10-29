# WhatMeal isolated release verification — 2026-10-20

**Provisional: the repaired Showcase release builds, installs and launches; eight native meal-action checkpoints and four pantry/grocery checkpoints pass. Remaining core workflows are still under test.** This is the isolated local tester, not a production release or the separate live-Gemini cloud-test APK.

## A. Build Result

The approved command passed: `flutter build apk --release --flavor showcase --target lib/main.dart --dart-define=WHATMEAL_EMULATOR_HOST=10.0.2.2` (exit **0**, **358.6 seconds**). It ran from an exact source copy at `build/rf-20261020/source`, using the existing tester signer and approved process-only settings, to protect the original raw APK outputs. The exact unflavored `flutter build apk --release` was not rerun; it aggregates other environments and is not interchangeable with this isolated target.

New APK: [build/release-request/showcase-footer-20261020/whatmeal-showcase-release.apk](../../build/release-request/showcase-footer-20261020/whatmeal-showcase-release.apk)

- Size: **58,223,121 bytes** (console: 55.5 MB).
- SHA-256: **`B44C4027223A6AC433F893E54BEDFC93807C936AD5A327A5DD6857A2F11A19C2`**.
- Package/version: `com.example.whatmeal.showcase`, `1.0.0`, code `1`; **non-debuggable**.
- Native Firebase project: `demo-whatmeal-showcase`; existing tester certificate/signature verified.
- Messaging and analytics auto-initialization remain disabled. Default cleartext is denied; local HTTP allowlist remains `127.0.0.1`, `localhost`, `10.0.2.2`.

[Build result](../../build/release-safety-audit/approved-20261019-210820650/runtime-20261020-8995b7c2/footer-build.txt), [artifact receipt](../../build/release-safety-audit/approved-20261019-210820650/runtime-20261020-8995b7c2/footer-built-artifact.json), [native/signature inspection](../../build/release-safety-audit/approved-20261019-210820650/runtime-20261020-8995b7c2/footer-apk-verification.json).

## B. Installation and Launch

The repaired APK installed with exit **0** on fresh Android API 35 AVD `whatmeal-release-20261019-211206`, serial **`emulator-5570`**. The installed APK hash matches the new artifact. No uninstall or data clear occurred. Its resolved full launcher cold-started successfully (exit **0**, **8,291 ms**); this proves native launch, not completion of the app workflows below. [Installation receipt](../../build/release-safety-audit/approved-20261019-210820650/runtime-20261020-8995b7c2/footer-installation.json), [corrected launch](../../build/release-safety-audit/approved-20261019-210820650/runtime-20261020-8995b7c2/footer-launch-corrected.txt).

Two harness failures are preserved separately: a piped native-command check incorrectly treated a null exit value as a device-identity failure and stopped before installation; a shorthand `.MainActivity` launch then resolved the wrong class and exited **1**. Reading the complete native result confirmed the intended AVD, and Android's resolved full activity corrected the launch command. Neither failure is counted as a pass. [Guard evidence](../../build/release-safety-audit/approved-20261019-210820650/runtime-20261020-8995b7c2/footer-install-guard-pipeline.json), [failed shorthand launch](../../build/release-safety-audit/approved-20261019-210820650/runtime-20261020-8995b7c2/footer-launch.txt).

Install/run from the repository root **only on the separate AVD above**. The copied local Showcase backend must be running: Auth **9299**, Firestore **9280**, project `demo-whatmeal-showcase`. This APK uses emulator-host `10.0.2.2`; these commands do not establish physical-device compatibility.

```powershell
$adb = 'C:/Android/Sdk/platform-tools/adb.exe'
$apk = (Resolve-Path 'build/release-request/showcase-footer-20261020/whatmeal-showcase-release.apk').Path
& $adb -s emulator-5570 emu avd name
# Verify: whatmeal-release-20261019-211206
& $adb -s emulator-5570 install -r $apk
& $adb -s emulator-5570 shell am force-stop com.example.whatmeal.showcase
& $adb -s emulator-5570 shell am start -W -n com.example.whatmeal.showcase/com.example.whatmeal.MainActivity
```

## C. Feature Regression Audit

The actual pre-fix release successfully favorited a saved meal, opened its completion confirmation and completed it. The undo step then failed: the Meal Details footer extended into Android's 48px three-button navigation region, affecting **Undo / Mark Accepted** and **Replace with AI**. That scenario remains **3 passing action checkpoints, 1 failed step**, not a completed workflow. The accompanying diagnostic found zero fatal-exception, Showcase ANR or System UI ANR lines. [Failed scenario](../../build/release-safety-audit/approved-20261019-210820650/runtime-20261020-8995b7c2/scenario-20261019T170645778232Z-369b444c/results.json), [diagnostic](../../build/release-safety-audit/approved-20261019-210820650/runtime-20261020-8995b7c2/meal-action-stop-diagnostic.json).

The user approved only the minimal footer repair. [meal_detail_page.dart](../../lib/features/meal/pages/meal_detail_page.dart) now wraps the existing footer content in `SafeArea(top: false)`. Normalized comparison found exactly that wrapper and its closing delimiter; labels, callbacks, lifecycle logic and all other non-whitespace source are identical. The source-copy build uses that exact repaired source. [Source diff proof](../../build/release-safety-audit/approved-20261019-210820650/runtime-20261020-8995b7c2/footer-source-diff.json).

| Check | Actual result | Scope |
|---|---|---|
| Pre-fix full suite | 488 passed; exit 0 | Baseline before the footer repair |
| Post-fix focused regressions | 12 passed; exit 0 | Real Meal Details page with mocked Firebase/display fixtures |
| Post-fix full Flutter suite | **500 passed; exit 0** | Includes the 12 focused tests; do not add the counts |
| Post-fix `flutter analyze` | **No issues; exit 0; 71.9 seconds** | Current repaired workspace |
| Host UI harness suite | 26 passed; exit 0 | Synthetic Python tests, not device acceptance |
| Post-fix native meal actions | **8 action checkpoints passed** | Actual release: saved-meal reopening, undo, not completed, re-accept and confirmation dialogs |
| Post-fix native pantry/grocery | **4 action checkpoints passed** | Actual release: pantry edit/save and sufficient-stock grocery recalculation |

[Full tests](../../build/release-safety-audit/approved-20261019-210820650/runtime-20261020-8995b7c2/footer-full-tests.txt), [analysis](../../build/release-safety-audit/approved-20261019-210820650/runtime-20261020-8995b7c2/footer-analyze.txt), [focused tests](../../build/release-safety-audit/approved-20261019-210820650/runtime-20261020-8995b7c2/footer-focused.txt), [26 host tests](../../build/release-safety-audit/approved-20261019-210820650/runtime-20261020-8995b7c2/host-clear-fix-tests.txt).

The new [meal_detail_insets_test.dart](../../test/meal_detail_insets_test.dart) covers pending, accepted, completed and not-completed statuses at 320×640, 411×891 and 640×360. All lifecycle/replacement footer buttons must remain hit-testable, fit horizontally and lie wholly above `displayHeight - 48`, with no framework exception. These mocked tests do not prove live Firebase, AI, notifications or device behavior.

On the repaired APK, the existing completed meal reopened from its exact saved plan. **Undo / Mark Accepted → Confirm**, **Not Completed → Confirm**, and **Re-accept → Confirm** all completed through ordinary UI controls. Native geometry independently placed the entire undo button at physical bounds `[42,1616][1038,1742]`, above the navigation region beginning at physical y=1794. This directly verifies the reproduced overlap repair. [Eight native checkpoints](../../build/release-safety-audit/approved-20261019-210820650/runtime-20261020-8995b7c2/scenario-20261019T173006869329Z-cc805b7b/results.json), [native geometry](../../build/release-safety-audit/approved-20261019-210820650/runtime-20261020-8995b7c2/footer-native-layout-proof.json).

The native grocery baseline showed rice demand **3 cup**, pantry stock **1 cup**, shortage **2 cup**. Through the actual pantry editor, stock was changed to **3 cups** and saved. Grocery then showed rice **0 cup**, **Available**, and **1 remaining item** (the separate carrot requirement). These are actual Flutter/Firebase-emulator UI results on the new release, not substituted repository calls. [Baseline capture](../../build/release-safety-audit/approved-20261019-210820650/runtime-20261020-8995b7c2/corrected-grocery-baseline-inspect-20261019T173239694379Z-d14e2e47/before.json), [four native checkpoints](../../build/release-safety-audit/approved-20261019-210820650/runtime-20261020-8995b7c2/scenario-20261019T173925923265Z-1c05b84a/results.json).

A host input failure was preserved: rapid delete events left residual quantity text, producing an incorrect unsaved draft. Exact-value verification stopped before **Save Changes**, so the failed input did not change Firestore. A separate Ctrl+A/Delete probe also failed and was not counted as a pass. The corrected helper uses ordinary move-end plus paced delete events, then verifies the freshly focused field is empty before inserting and checking the requested value. A real native probe confirmed empty focused text with `saved: false`; the subsequent four-checkpoint UI workflow saved the correct quantity. This is a test-harness repair, with no further app change or weakened assertion. [Native paced-clear proof](../../build/release-safety-audit/approved-20261019-210820650/runtime-20261020-8995b7c2/quantity-clear-delayed-probe-20261019T173825237074Z-fa8259cd/clear-probe.json).

Post-fix native checks still pending: manual plan creation/save/reopen/delete; remaining pantry/grocery CRUD and restoration; household/account switching and in-app notification history. Earlier evidence remains useful but is not relabeled as verification of this exact repaired APK. Checkpoint counts are UI actions, not counts of complete independent workflows.

## D. Safety and Integrity

The fresh AVD initially had no WhatMeal packages. The original AVD was not opened/copied; no original account was signed out, and no data clear was used. The test backend uses a separate copy of the Showcase export. [Setup](../../build/release-safety-audit/approved-20261019-210820650/runtime-20261020-8995b7c2/setup.json).

The recorded preservation comparison found **2,526 of 2,527 existing project files unchanged**; only the approved `meal_detail_page.dart` differed. All **4 previously verified APKs**, **8 protected files** (including Firebase configuration/rules and the original private AVD backup manifest), and **6 original Showcase export files** remained unchanged. Fourteen raw APK outputs were hashed: six match preserved named APK references; eight have no earlier raw-path hash baseline, so only their current hashes are recorded. No missing files or hash errors. This comparison preceded the isolated-copy rebuild; the final post-build preservation recheck remains pending. [Comparison](../../build/release-safety-audit/approved-20261019-210820650/runtime-20261020-8995b7c2/preservation-current-20261020-011910120.json).

The old 58,223,225-byte release with SHA-256 `5D8C0A30006174443C67296AE94C4B2B77B4DF18EC1FB276319F3B4828D9B0C9` remains preserved at its original path. The repaired artifact has a new path; it does not replace the old APK.

Host failures remain recorded: Windows sandbox temp-directory permissions, ADB's 260-character destination limit, the native-exit guard, and the shorthand launcher. Their fixes affect the new test harness; no meaningful assertion or permission was bypassed. The app repair changes no dependencies, Firebase configuration/rules, signing setup, AI providers, branding or unrelated functionality. No production or GitHub operation is part of this verification.

## E. Final Verdict — provisional

**BUILD, INSTALLATION, NATIVE LAUNCH, REPAIRED MEAL ACTIONS AND PANTRY/GROCERY RECALCULATION VERIFIED; REMAINING CORE ACCEPTANCE PENDING.** All 500 Flutter tests and analysis pass. A final demonstration verdict must wait for the remaining direct native workflows and final preservation recheck; these bounded passes do not establish every app feature.

Live AI and native push are intentionally unavailable in Showcase. Separate cloud-test Gemini evidence does not establish release parity. Physical-device operation, simultaneous multi-device behavior and production readiness remain unverified. Production configuration/data/rules and the original account/cache/backups must remain untouched.

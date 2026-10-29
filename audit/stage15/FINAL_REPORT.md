# WhatMeal — Stage 15 final handoff

Latest local continuation: [form repairs and native keyboard checks](forms-followup/REPORT.md), with 265 passing Flutter tests, clean analysis and a newly installed isolated APK. User account/data and all older evidence are retained; live AI remains pending.

Subsequent manual-session repair: see [Android navigation/accessibility follow-up](manual-followup/REPORT.md) for the updated253-test suite, installed APK and retained local session. The original Stage15 evidence below remains historical and unchanged.

**Local use:** runnable on the configured Android emulator with the demo backend. Live AI and native push are unavailable; this is not a production release. All final checks below executed; no further stage will start automatically.

## Fixes implemented

- Household confirmations/sheets retain their opening account, household and membership identity. Old archive/remove/leave/role/ownership/invitation actions cannot operate on a replacement account's household.
- Late create/join completion checks both account generation and sheet lifetime before navigation; stale completions cannot close the new screen. Other late dialog feedback is scoped to its initiating session.
- Delayed invitation results cannot refill a cleared token after A–B–A or lost household authority. Late departure errors cannot dispatch orphan-index cleanup after the account/household changes.
- Household membership/index/document errors publish an unavailable state with the error already set. Terminal listeners cancel and explicit Retry reopens current sources.
- Receipt/activity failure reports an error directly, closes both sources and requires resubscription. It no longer emits a misleading healthy empty inbox first.

Eight new regression cases reproduce these paths. The delayed operations are controlled mock gates, not real network-outage proof. The page's optional repository and store's optional receipt-query boundary preserve their existing production defaults; no architectural service layer, rule/schema change or redesign was introduced.

## Final automated checks

| Check | Actual result | Evidence |
|---|---|---|
| Final full Flutter suite | **251 passed, exit0,49s** | flutter-tests-delivery.txt / .exit |
| Final analysis | **Clean, exit0,15.2s** | analyze-delivery.txt / .exit |
| Local Firestore security | **65/65, exit0** unchanged cases | security-final-rerun.txt / .exit |
| Household focused checks | 16 passed before the late-sheet addition | household-fixed.txt |
| Receipt/notification checks | 9 passed | receipt-fixed.txt |
| Final focused regressions | 8 passed | last-regressions.txt |

The intermediate250-test pass preceded the newly reproduced late-sheet repair. Earlier251-test and style-check results remain preserved; the authoritative delivery suite and analysis ran after every source/style change. No code changed afterward. No assertion or authorization check was removed.

## Android acceptance

**PASS: exit0,199s, one combined Android UI workflow /32 checkpoints** (`android-verified.txt`, `android-phases.json`). This includes the full core journey plus index/family/member terminal denials and the receipt-source denial, each recovered through visible Retry. The fixture explicitly retained the invited member role. Four captured SDK permission-denied observations are not four new security cases. `final-recovery.png` was captured before teardown and visually inspected. No ANR. Native Auth/Firestore and clipboard were real; typing was simulated by Flutter and email actions were emulator-only.

| Main journey | Verification status |
|---|---|
| Registration, emulator email verification, login/logout/account isolation | Actual Android UI; emulator action codes, simulated typing; not real email delivery |
| Household creation, invitation copying/join, removal/revocation, rejoin/departure | Actual Android UI with two disposable accounts used sequentially |
| Dietary profile | Actual Android UI creation; prior Stage11 edit/delete evidence preserved |
| Manual plans, exact identity/dates, favorites, status changes, reuse/deletion | Actual Android UI; live AI replacement remains unverified |
| Pantry quantities/units/expiration and stock edits | Actual Android UI |
| Grocery consolidation, covered stock/shortage, shared state, deletion provenance | Actual Android UI; prior Stage10 editor/check/recovery evidence retained |
| Household/receipt terminal errors and visible Retry | Final run status above; real SDK/emulator denials through injected queries |
| Password/reset/profile/settings/notifications recovery | Prior Stage11–14 device evidence preserved; provider metadata only, no live calls |
| Admin/viewOnly/outsider/unauthenticated authorization |65 local security cases; not full UI acceptance for every role |

A single AOSP AVD switching accounts is not simultaneous-device synchronization. Native typing, real email delivery and whole-device offline/reboot are not established. Prior Stage10–12 outage/restart results retain their original bounded scope.

## Latest standalone tester

- Path: `build/stage15/whatmeal-local-tester.apk`; **57,895,529 bytes**.
- Package: `com.example.whatmeal.local`, version1.0.0/code1, minSDK24/target36; native/Dart demo project safeguards preserved.
- SHA-256: `CAEA1B80B01080635732D9AA9B94BFC9A1DEE69D14304BA080F8006849B5385B`.
- Release-mode local build: **exit0,66.3s**. Package/demo/network policy verification:exit0. Signature v2 verified, existing Android Debug certificate (not production signing).
- Install/reset/cold-start:all exit0; Android reported COLD,TotalTime1424ms. `tester-startup.png` was visually inspected: original WhatMeal Sign In branding, local app focused, no ANR. Build success and runtime evidence are separate.

Run instructions and exact local commands: **[TESTER.md](TESTER.md)**. Backend uses Auth9099/Firestore8180; the APK uses emulator host10.0.2.2. Reuse only the existing debug tester signer. No production signing material was generated or exposed.

## Preserved failures

- household-reproduced.*:0pass/6fail before repair; receipt-reproduced.*:0pass/1fail; late-sheet-reproduced.*:0pass/1fail (the newer account's page was popped).
- analyze-preflight.*:8 style/context findings; analyze-final.*:3 style findings; all corrected, final clean result above.
- security-final.*:64/65, initial fixture-reset HTTP500 instead of200. The authorization case did not execute. Root cause is unconfirmed; unchanged complete rerun passed65/65. The earlier65/65 pass is also retained.
- android-final.*:exit1 after28 completed core checkpoints,198s. The new recovery fixture incorrectly expected owner although the workflow ended as the invited member. Corrected to explicitly require the member role unchanged; no permission was granted or assertion bypassed. First phases, failure screenshot, ANR report and APK preserved.

## Remaining limits and owner actions

1. **Live AI remains pending approval.** Only `demo-whatmeal-audit` is approved, through `firebase.audit.json`, `android/app/src/local/google-services.json` and guarded `lib/main.dart`. No separate live test project is configured/approved. Supply only its non-production project ID and local configuration paths, plus explicit bounded/no-charge test authorization; never paste keys. It requires compatible Auth/Firestore rules, Firebase AI Logic/Gemini model eligibility and App Check registration. Each custom provider requires its own approved account/configuration and request cap. Adapter mocks do not establish live model availability, protocol compatibility or allergy/preference adherence; participant/custom-note and replacement-context coverage remains incomplete (R023–R025). See ../stage10/LIVE_AI_APPROVAL.md; proposed aiTest paths there do not exist yet.
2. Native push needs an approved trusted sender/device setup; foreground/background/cold-start delivery and native permission/initialization/token recovery remain unverified. No paid service or Cloud Function was introduced.
3. Simultaneous devices, physical-device/release attestation, OS-wide offline/reboot, removal during outage and overlapping native Auth RPCs remain unverified. Client scope checks cannot cancel already-dispatched server/native operations. Broader producer and role-specific UI coverage is not certified complete.
4. Imported keys still use owner-only Firestore storage, not an OS credential vault. Secure-storage migration/credential decisions, production signing, backend migration and deployment require separate owner decisions/approval. None occurred.

Important files: `lib/features/family/data/family_repository.dart` (state/session/error/continuation guards); `lib/features/family/pages/family_space_page.dart` (reactive canonical UID, scoped dialogs/sheets/navigation); `lib/core/services/household_activity_store.dart` (receipt errors/cancellation); `test/household_final_recovery_test.dart`, `test/receipt_terminal_recovery_test.dart`, `integration_test/stage15_final_test.dart` and `test_driver/stage15_final.dart` (regressions/device evidence). WHATMEAL_FUNCTIONALITY.md and this handoff reflect actual evidence. All earlier work and failure records are preserved.

## Exact validation commands

Run from repository root after starting the local services/AVD in TESTER.md. The security suite resets the disposable emulator database; run it before manual use, not while preserving a demo session.

```powershell
$flutter='C:/Users/ASUS V16/flutter_windows_3.44.5-stable/flutter/bin/flutter.bat'
$node='C:/Program Files/nodejs/node.exe'
& $flutter test test/household_final_recovery_test.dart test/receipt_terminal_recovery_test.dart
& $flutter test
& $flutter analyze
$env:FIRESTORE_EMULATOR_HOST='127.0.0.1:8180'
& $node audit/stage3/security_acceptance.mjs
& $flutter build apk --debug --flavor local --target integration_test/stage15_final_test.dart --target-platform android-x64 --dart-define=WHATMEAL_EMULATOR_HOST=10.0.2.2
& $flutter drive --driver=test_driver/stage15_final.dart --target=integration_test/stage15_final_test.dart --use-application-binary=build/stage15/final-integration.apk --flavor=local -d emulator-5564 --keep-app-running
$env:WHATMEAL_TESTER_SIGNING='true'
& $flutter build apk --release --flavor local --target lib/main.dart --dart-define=WHATMEAL_EMULATOR_HOST=10.0.2.2
./audit/stage15/verify_tester.ps1
```

Flutter commands ran serially, with normal platform regeneration (no --no-pub), and the AVD stopped during builds. Process-local Java used Android Studio jbr, a workspace audit/stage15 Unix-domain temporary directory, Gradle-Xmx768m/in-process Kotlin; backend-Xmx512m. No global firewall/security configuration changed. Backend wrapper exit1 reflects deliberate shutdown after verification, not an acceptance failure. Production was not read, modified, migrated or deployed.

Final consistency: all89 requirement IDs are unique; all5 protected rules/security-suite/native/Dart guard files match the Stage14 baseline;12 authoritative final child exit files are0; final APK hash matches; all3 tester command blocks parse; diff check0. Dedicated ports8180/8181/8182/9099/5564/5565 are closed (`cleanup-ports.json`). No unrelated service was stopped.

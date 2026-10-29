# Stage15: household departure recovery and local backend recovery check

2026-10-18, local-only continuation. Existing work preserved. Live AI remains pending. No production access/data changes/deployments, Cloud Functions, paid services, security-rule changes, account recreation, or app-data clearing.

## Recovery finding

A pre-test filename-only search of the WhatMeal workspace/project area, normal Windows temporary folder and Firebase emulator cache found only the known disposable export. Its Auth export contains 5 disposable accounts and no normal-account record. No recoverable export of the former Auth9099/Firestore8180 dataset was found in these searched locations. This is a bounded search, not a claim that no user-held archive exists anywhere.

The previous whole-AVD backup remains private/ignored under build/private-state-snapshots/20261018-household-interruption. Cached Auth/device data is not a complete server backup. Original backend ports remain stopped; no empty replacement or normal account creation/reset was performed. Complete recovery without resetting cannot currently be established. An original paired Auth/Firestore emulator export is required to restore the complete original server state reliably.

The independent test export was copied privately before testing, imported on9199/9180, and re-exported before new fixtures. All5 account IDs matched unchanged (fixture-restore-check.json), and native startup logs identify Standard Edition. This verifies disposable export/import only; it does not recover the user's normal backend.

## Reproduced defects and fixes

1. Household removal/departure had no persistent pending indication after its confirmation dialog closed. Offline batched writes may remain unacknowledged; showing an apparently finished interactive screen is misleading. Family Sharing Space now pins an accessible waiting-for-confirmation indicator above the system inset while any household operation is pending. The body absorbs conflicting controls while keeping normal navigation available. It makes no success/timeout/cancellation claim before acknowledgement. Original UI/branding preserved.
2. Terminal membership-index listener errors still used meal-generation error mapping, including “Your plan may not have been saved.” The listener now uses the existing safe household-specific error mapper. Terminal cancellation, retry, session scoping and redaction remain intact.

3. Actual320px Android scrolling exposed a0.313px overflow in the non-owner Archive Household header. Two new320px widget regressions at1x/2x text also reproduced unconstrained role/invitation headings. The affected labels/badge now flex and wrap without changing text, colors or permissions. The leave action remains reachable.
Important files:
- lib/features/family/pages/family_space_page.dart: pending status and conflicting-control guard.
- lib/features/family/data/family_repository.dart: terminal household-index error mapping; removes AI failure dependency.
- test/household_departure_recovery_test.dart:6 new mock/widget cases for removal/departure pending→safe failure→ordinary retry and terminal unavailable/permission-denied→retry.
- test/household_final_recovery_test.dart and test/household_submit_recovery_test.dart: bounded frame waits explicitly assert the new pending status after sheet dismissal; existing late completion/account isolation checks remain unchanged.
- integration_test/household_departure_recovery_test.dart and matching driver: two named native Firebase clients on one AVD, disposable verified local accounts; actual member UI and owner SDK listener/operations. This is not simultaneous-device evidence.
- Adjacent scripts and evidence; README, TESTER and functionality matrix updated with actual outcomes.

## Automated results

| Evidence | Actual result |
|---|---|
| reproduced.txt |0 passed /4 failed, exit1; before fixes |
| focused.txt | Compilation failed for4 files, exit1; non-const Semantics under const parent corrected |
| focused-final.txt |28 passed /3 failed, exit1; old pumpAndSettle assumptions timed out while new pending indicator legitimately animated |
| focused-complete.txt |31 passed, exit0; affected regression/layout suites |
| flutter-tests.txt |282 passed, exit0,82seconds |
| analyze.txt |exit1; two test-only annotation warnings |
| analyze-final.txt |No issues, exit0,23.4seconds; before final heading fix |
| layout-reproduced.txt |0 passed /2 failed, exit1;320px normal/enlarged member layout |
| layout-final.txt |6 passed, exit0; departure/listener/layout cases |
| analyze-layout.txt |No issues, exit0,7.7seconds; final product code |
| flutter-tests-final.txt |284 passed, exit0,161seconds; after all product fixes |

The final annotation changes are test-only. All final product/layout changes were included in the 284-case suite. No failed, interrupted or partial run is counted as a pass. Historical 65 security acceptance cases remain intact; no reset-based security suite was rerun against user data.

## Android/build evidence

The first Android run failed (exit1,31seconds), after 4 checkpoints. It found the header overflow and a failed hit check on the leave action. Logs, phase report and APK are preserved as first artifacts. The overflow is proven; snackbar interference with the hit check was a hypothesis, not a proven root cause. The harness now waits for the preceding success snackbar to expire naturally before attempting leave; no dialog/permission/failure is dismissed automatically.

The final Android workflow passed all 10 checkpoints (exit0,84seconds). Two named clients on one AVD received real Auth/Firestore emulator responses. It verified owner removal during member outage, revoked UI/server access on reconnect, fresh-token UI rejoining, visible pending offline departure, acknowledged departure observed by the owner listener, a denied queued departure racing with removal, no false leave success, fresh-token recovery to exactly two members, and unchanged default cached Auth identity. The observed queued departure error was permission-denied; no rules bypass/fallback privilege was introduced.

Setup registration/email verification and owner mutations use SDK fixture actions; invited member rejoining/leave use the real Family Sharing Space UI with Flutter text/tap automation and native Firebase listeners. This is not physical keyboard, real email or simultaneous-device verification. The post-recovery screenshot was visually inspected: correct household/two-member content is present while the earlier legitimate denial snackbar is still expiring; the snapshot is not a new failure or native push test.

Final integration build21.9seconds, exit0; isolated package/demo configuration/signature/network guards verified before installation. Build success alone does not establish runtime acceptance. Standalone final tester verification follows below. The test uses local demo-whatmeal-audit only; owner client connects to9180, member client passes through a reversible loopback connection gate8183→9180/control8184. Both Auth clients use9199. The normal default Auth instance is only checked for unchanged cached identity on9099. No payloads/tokens are logged by the gate; no permissions are bypassed. Named disposable accounts are verified using local emulator action codes; no real email is sent.

## Remaining scope

Normal backend recovery remains blocked by the absence of an original export in searched locations. Live AI has no approved/configured non-production project and remains untested. Only demo-whatmeal-audit is configured locally, in android/app/src/local/google-services.json and firebase.household-recovery.json, guarded by lib/core/config/runtime_environment.dart. Native push/trusted sender, true simultaneous devices, whole-device reboot/network conditions and production signing/deployment remain separate.



## Final tester artifact

Final full suite:284 passed, exit0,161seconds. Final analysis: clean, exit0,7.7seconds. Local tester build:47.3seconds, exit0. Package com.example.whatmeal.local and native demo-whatmeal-audit, existing tester certificate/v2 signature and native safeguards verified. Artifact: build/stage15/departure-recovery/whatmeal-local-tester.apk. SHA-256: 71E01843ED8700461F1A81BFE0C23E8E222C4483DEADCBD7D55DE9DB6CC147C7. No signing secrets generated/read. Prior artifacts remain preserved.

Temporary disposable services were manually exported (exit0) and stopped. All 8180/9099/8183/8184/9180/9199 were confirmed closed. Original backend was not restarted, and no normal account was reset/recreated. Five protected rules/security-suite/native/startup hashes are unchanged. Historical 65 security cases are retained, not rerun/reset.

Startup/install observations are recorded in install-final.exit, launch-final.exit and startup-final.json; build success alone is not runtime evidence.

Final update install and cold launch both exited0; launch Status:ok/COLD,4317ms. The bounded UI check recorded foreground=true/Home=true, no ANR observed, no data clear, and original backend ports closed. The AVD remains connected with normal local tester Home open. This confirms cached-session startup only; original server dataset recovery remains unverified. Final disposable export contains 9 accounts and retains the five original fixture IDs; no normal-account record is present.

Prioritized continuation: obtain an original paired Auth/Firestore export if one exists outside the searched folders, validate its normal UID/data in an isolated restore before touching the primary ports; otherwise recovery of complete server state without recreation remains blocked. Continue true two-device/whole-device network acceptance separately. Keep live AI, native push, production signing/migration/deployment pending their required configuration and approval.

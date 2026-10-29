# Stage 15 household create/join recovery follow-up

Local-only continuation, 2026-10-18. Existing staged/unstaged work was preserved. No production reads, migration, deployment, live AI, paid services, Cloud Functions, or security-rule changes.

## Repairs and reproduced causes

- Create/join sheets previously closed even when the repository returned false. Drafts disappeared, submit remained enabled during writes, and blank input failed silently. The shared access sheet now validates input, retains failed drafts, disables duplicate submissions, presents safe inline feedback and closes only on success.
- Pending create/join sheets exposed obsolete drafts/spinners across A→B→A. Auth-session epoch notifications now replace the obsolete editor with a Close message; late results cannot navigate another session.
- Household operations used unrelated AI/meal-plan errors and could display unknown exception text. A dedicated error mapper permits only exact business messages and safe SDK-code messages, including uncertain timeout/commit outcomes.
- Actual Android investigation exposed cached absence being treated as deletion immediately after successful creation. The family stream now suppresses missing cache snapshots and requests metadata changes so server-confirmed absence still propagates. Existing cached families and terminal permission errors still propagate.

## Changed implementation and tests

- `lib/features/family/pages/family_space_page.dart`: integrates the scoped reusable editor; preserves original branding, defaults and other household controls.
- `lib/features/family/widgets/household_access_sheet.dart`: editor lifecycle, validation, busy state, failure draft and stale-session protection.
- `lib/features/family/data/family_repository.dart` and `models/household_action_error.dart`: safe household operation failures.
- `lib/core/services/family_service.dart`: server-authority-aware family stream and injectable snapshot test boundary.
- `test/household_submit_recovery_test.dart`: 8 widget/repository regression cases.
- `test/household_action_error_test.dart`: 3 redaction/context/timeout cases.
- `test/family_snapshot_authority_test.dart`: 2 cache/server/error stream cases, using existing fake Firestore snapshots.
- `integration_test/household_submit_recovery_test.dart`, matching driver and local scripts: actual Android rendering/native Firebase SDK, disposable secondary Auth client, independent emulator ports, reversible connection interruption, phase evidence and token redaction.
- `firebase.household-recovery.json`: separate disposable emulator backend on Auth9199/Firestore9180. Normal Auth9099/Firestore8180 are not replaced.

## Actual automated evidence

| Run | Result |
|---|---|
| Original UI reproduction | 0 passed / 6 failed, exit1; preserved in reproduced.txt |
| Obsolete-session reproduction | 0 passed / 2 failed, exit1; spinner prevented settling before draft assertion |
| Initial focused regressions | 23 passed / 2 failed, exit1; duplicate banner/sheet message matcher |
| Focused regressions after sheet-scoped matcher | 30 passed, exit0 |
| Earlier complete suite | 276 passed, exit0, before cache fix |
| Post-brace focused cases | 11 passed, exit0 |
| Cache-authority reproduction | 1 passed / 1 failed, exit1 |
| Interrupted full suite | 266 completed cases, no final exit; NOT a pass |
| Resumed full suite | 278 passed, exit0, 200 seconds |
| Resumed analysis | exit1: test fixture directly implemented sealed Firestore class |
| Final cache regressions after supported fake snapshot fixture | 2 passed, exit0 |
| Final analysis | No issues, exit0, 55.5 seconds (analyze-handoff); prior complete analysis7.6s |

The final fixture-only change does not change production behavior. The complete278-case suite is followed by the two affected fixture tests and clean analysis. The sandbox-only attempt to start those focused tests produced no output and was interrupted, not counted as a pass.

## Android failures retained and test correction

Both earlier Android runs failed (exit1), with zero completed checkpoints. Their APKs/logs/phase reports remain as first/second artifacts. The original outage assumption was wrong: SDK disableNetwork did not prevent transaction RPCs. A read of only the disposable account's own local membership index proved its transaction committed. The second run's frame barrier did not resolve that cause. No failed run is counted as passing.

The third Android run passed the create outage checkpoint, then failed on an immediate server read after gate resume (exit1, one checkpoint). Native reconnect backoff had not completed. A bounded server-read probe now retries only unavailable/deadline-exceeded; authorization errors and exhausted retries still fail.

The fourth Android run passed create failure and successful retry (exit1, two checkpoints), then asserted UI text immediately after the repository had switched accounts but before Flutter rendered the notification. An explicit render settle was added before the unchanged previous-household-absence assertion. This was a harness timing defect; it does not establish an app isolation vulnerability. Third/fourth logs, exits, phase reports and APKs are retained.
The corrected harness uses a loopback TCP connection gate for only the secondary test client. It destroys/refuses that client's connections during each outage, forwards to independent Firestore9180 otherwise, and leaves ordinary security rules/Auth checks intact. It never reads/logs payloads. The normal default Auth instance is only read for an identity-preservation comparison. UI actions use Flutter test text/taps with Android rendering/native SDK; this does not establish physical keyboard typing, live AI, native push, or simultaneous-device behavior.

## Backend interruption and account preservation

The former in-memory backend and AVD stopped during an execution interruption; cause is unconfirmed. No workspace emulator export was found. The original9099/8180 ports remain stopped; no empty replacement backend or account recreation was performed. The answer “just local” did not establish a recoverable export.

Before using the AVD again, its complete stopped-state directory was copied to the ignored `build/private-state-snapshots/20261018-household-interruption/` folder and relevant userdata/encryption hashes were verified. This protects local device/cache state, NOT recovery of the former Firebase server dataset. Original backend data recovery remains unverified.

Only disposable accounts use the independent9199/9180 backend. Its export destination is ignored `build/household-recovery-private/fixture-export`; it is not an export of the user's old backend. No user password, signing secret, API key, invitation token or action link is included in this report.

## Security and remaining scope

The historical 65 passing security cases are retained. The reset-based security suite is deliberately not rerun against a manual backend. Protected rules, suite, native local Firebase/network configuration and main startup file are hash checked. No non-production live-AI project is approved/configured; only demo-whatmeal-audit with local native configuration exists. Live AI, native push/trusted sender, simultaneous devices and production signing remain pending separate configuration/approval.

## Current device/build result

The final Android run passed (exit0,81 seconds): one household recovery workflow with all 8 checkpoints. Actual failure codes were unavailable, permission-denied, unavailable. It proved server absence after failed create/join, retained drafts and safe visible errors, successful ordinary retries, invalid legacy-token validation, real rules rejection of a revoked invitation, account isolation after rendering, the expected member role/two-member count, and unchanged default cached Auth UID. Screenshots `create-offline.png` and `joined-member.png` were captured and the create failure screenshot visually inspected.

The final native local tester built in44.0s, exit0; integration final build39.5s, exit0. Tester package is com.example.whatmeal.local, native project demo-whatmeal-audit, existing tester certificate SHA256371ccb837f5379cc570eee0808710d3ca1cc36cbabef112e0a3d7960274b25bb, APK v2 signature valid, local network/FCM/analytics guards verified. No signing secret was generated or read.

Tester artifact: `build/stage15/household-recovery/whatmeal-local-tester.apk`.

SHA-256: `7A0FE24C248747ED29C0ECDA7FA4A8AB5DB8ECECD1B34F3EFC024530B2BB24C8`.

The tester was installed with adb install-r (exit0), without uninstall/clear. Cold launch returned Status:ok (exit0,5174ms). Initial8-second UI evidence was incomplete (startup-initial.json); the foreground probe also used an obsolete activity label. A subsequent probe had a read-only PowerShell variable collision and is retained as invalid (startup-probe-invalid.json), not a pass. After correcting the probe, startup-final.json records foreground=true, HomeVisible=true, no ANR observed. A private ignored screenshot was visually inspected and shows original WhatMeal Home. This is cached-session startup evidence only: original backend ports remained closed throughout, so no server-data recovery is claimed.

The independent disposable export completed (exit0), with metadata saved under ignored build/household-recovery-private/fixture-export. Test proxy and disposable backend were stopped after export; their interrupted shell sessions returned1 on intentional stop, not test failures. Final8183/8184/9180/9199 and original8180/9099 all closed. AVD remains connected with the normal local tester open.

Protected-complete.json confirms all 5 protected files unchanged. Historical 65 security acceptance cases remain intact and were not rerun/reset. Final analysis after the last harness edit is clean, exit0,55.5s.

## Prioritized continuation / genuine blockers

1. Recover the former local backend only from a confirmed saved emulator export. None was found in the workspace; no account recreation or empty primary restart was performed. Device backup/cached login cannot reconstruct or certify the complete server dataset. If no export exists, recreating the normal local backend/account is a separate explicit user decision because it cannot preserve unknown server-only data.
2. Use the saved independent disposable fixture export for further household tests; preserve normal ports/account. Simultaneous devices, removal during outage, whole-device network/OS restart and concurrent native Auth requests remain outside this follow-up's verification.
3. Live AI remains pending an explicitly approved isolated project/configuration. No approved live project ID exists. Current demo-only project ID: demo-whatmeal-audit; local native config: android/app/src/local/google-services.json; runtime guard: lib/core/config/runtime_environment.dart; disposable backend config: firebase.household-recovery.json. No keys printed.
4. Native push foreground/background/cold-start delivery still requires an approved trusted sender and device configuration. Production signing/attestation, migration and deployment remain separate approvals.

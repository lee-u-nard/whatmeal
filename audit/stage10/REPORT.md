# Stage 10 — local acceptance and targeted repairs

Local repair and grocery/recovery acceptance complete; standalone tester runtime verification recorded below. Broader application certification remains incomplete. Stage 9 baseline: 194 Flutter tests, clean analysis, 28 Android UI checkpoints; prior 65 security cases preserved. Production and live AI are not authorized. Root TESTER.md now links audit/stage10/TESTER.md; the Stage 9 guide is preserved.

## Repair batches and reproduction evidence

| Area | Root cause and targeted change | Evidence / scope |
|---|---|---|
| Manual grocery quantity | Editor invented `1 unit` for blank quantity. Preserve unknown quantity as empty text. | Focused editor regressions and passing Android blank-quantity check verify this. |
| Grocery validation and recovery | Blank names silently returned; no pending-submit guard or inline write failure. Extracted the same editor into a scrollable Form, with validation, pending state and retained draft/retry. | Widget tests pass for blank input, pending write, sanitized failure/retry, narrow screen/2x text with keyboard inset. Typing in integration uses Flutter's test handler. |
| Duplicate groceries | Nonfatal duplicate outcome was assigned to the feed's global `error`, replacing the visible list and potentially clearing projection on a later publish. Keep duplicate feedback at the caller. | Store regressions retained; passing Android fixture attempted a normalized duplicate with incompatible quantity, retained the original and edited it. No automatic quantity merge is claimed. |
| Grocery row accessibility | Real widget at 320 px / 2x text overflowed by **35 px**. Wrap controls beneath the item text. | `focused-expanded-tests.txt`: 6 passes / 1 failure; `focused-fixed-tests.txt`: 7 passes. |
| Grocery clear | Clear Used invoked deletion immediately. Added confirmation, retaining meal-derived requirements and unchecked manual items. | Dialog cancellation/confirmation widget and Android tests pass. Analysis exposed that the helper initially was not wired; fixed before the final Android build. |
| Grocery loading/retry | Loading appeared as empty data and terminal errors had no operative retry control. Add loading state and explicit listener reinitialization. | Source review; full suite and focused regressions pass. Terminal listener-error recovery is not yet directly exercised on device. |
| History reachability | `/meal-history` existed but had no visible entry point. Add a history action to Saved Meal Plans, preserving exact source identity. | Source route/caller search; exact rendered plan path/meal ID passed later Android history checkpoints; those combined runs subsequently failed in unrelated phases (see journal). |
| Notification feed | Personal errors were logged only; shared errors silently emptied history. Add loading/error states and a retry that cancels/resubscribes both streams. | Inbox widget tests distinguish loading/error/empty and exercise Retry. Real terminal SDK listener error injection remains unverified. |
| Notification actions | Mark all read lacked awaited error feedback. Catch failures with a fixed safe message; guard post-await routing against changed account session. | Failed callback and exact target widget regression pass. Session check is defensive hardening; no data leak was reproduced. |
| Local AI boundary | Demo Firebase routing did not itself prevent imported-key/provider HTTP calls through LlmService. Block generation, replacement, connection validation and model discovery before provider/quota work in emulator mode. | Two policy regressions pass; no live provider request used to reproduce risk. Actual Android service/quota guard check passed in the final fixture. |

## Execution journal

- First focused editor run: 4 passed, exit 0.
- Initial combined focused tests: 6 passed, exit 0.
- Enlarged grocery controls regression: 6 passed / 1 failed, exit 1; retained failure log.
- After row fix: 7 passed, exit 0.
- First integration build: exit 0, 95.9 s. First Android run: **failed**, exit 1, 3:36. It completed Stage 9 workflows through reuse/status isolation, then a harness assertion expected a pushed detail's query parameters on GoRouter's route-information URL. That URL returned no `plan`; subsequent notification/grocery phases did not execute. Changed assertions to inspect the rendered `MealDetailPage.planPath` and `mealId`, not a looser title assertion. Preserved `android-phases-first-failed.json` and full failed log.
- Full Flutter suite: **203 passed**, exit 0, 1:50. Analysis then failed, exit 1, with 1 warning / 5 infos (including an unconnected confirmation helper). Fixed wiring and style findings. Nine focused cases passed afterward (`targeted-final.txt`, exit 0); analysis clean (`analyze-fixed.txt`, exit 0, 11.4 s).
- Corrected integration APK rebuilt: exit 0, 82.6 s (`build-integration-final.txt`). Final workflow pending completion; no partial phases count as a complete pass.
- That corrected Android run failed, exit 1, 3:43 (`android-ui-final.txt`): exact reused-plan history navigation passed; a household-specific logout helper then searched for a nonexistent Back control from the shell. Its fallback picked an off-screen calendar scroller; fatal hit testing correctly stopped the run. Fixed the helper's screen assumption and restricted scrolling to visible vertical controls. Preserved completed phases separately; this was a harness failure, not a relaxed assertion or automatic dismissal.
- Third integration build passed, exit 0, 102.9 s (`build-navigation-fixed.txt`). The original Stage 9 fixture and all 65 security cases remain unchanged. Added a nonvisual key for actual unread-badge assertions in the new Stage 10 fixture.
- Third Android run (`android-ui-navigation-fixed.txt`) failed, exit 1, 5:30, after **33 completed checkpoints**: exact history and notification meal identity, persisted read receipts, visible unread badge/count clearing, manual grocery add/normalized duplicate prevention/edit/check/uncheck all completed. The new offline assertion expected an inline error within its deadline, but no inline error arrived before the deadline. That run did not establish whether the operation remained pending. The test's `finally` restored SDK networking; sharing/clear/delete/settings/AI-guard phases did not run. This is not an overall acceptance pass. Preserved `android-phases-offline-failed.json`.
- Focused recovery fixture now logs into that same isolated demo member through the ordinary UI, asserts its exact expected household, and cleans only its named test groceries through ordinary controls. It tests an explicitly disabled submit/progress indicator while SDK networking is off, restores networking in `finally`, and verifies saved quantity after completion or an ordinary visible-error retry. The earlier failed run remains failed; immediate offline failure is not assumed. No `Future.timeout` was added to abandon an uncancellable write.
- Provider-settings listener retry reproduced separately: first new test failed to compile (retained `provider-retry-before.txt`); corrected test then failed on missing Retry Settings (`provider-retry-reproduced.txt`, 0 passes / 1 failure). Added guarded resubscription and the control, preserving outstanding writes and account epochs. The new test plus existing provider-sync tests passed **11 cases**, exit 0 (`provider-retry-fixed.txt`). This is injected-stream/widget evidence, not a live provider call or live terminal-listener test.

All builds/tests are serialized. The existing AVD was still running during the first build (confirmed by process/device inspection afterward); it was explicitly stopped for the subsequent full-suite/analysis/build batch. The same existing plain AOSP AVD is restarted with dedicated ports and host graphics. No unrelated application, security control, driver or system network setting was changed.

## Infrastructure limits

No approved live-AI environment is configured. Only `demo-whatmeal-audit` is approved, with local paths `firebase.audit.json`, `android/app/src/local/google-services.json` and local options in `lib/main.dart`. See `LIVE_AI_APPROVAL.md` for the minimal future request. Do not reuse the default production flavor for live testing. No AI result was fabricated or live provider compatibility certified.

Native FCM remains disabled in local mode. In-app Firestore history/read receipts are separate from push delivery. No trusted background sender is approved. One isolated AVD is available; sequential accounts do not establish simultaneous two-device sync. Production signing/credential rotation and storage migration remain owner decisions. Rules/schema/security suite and native demo safeguards are unchanged in this stage; protected-final.json confirms unchanged rules, security suite and native demo safeguards.

## Resumed recovery verification

The focused SDK-toggle run failed (android-grocery-recovery.txt, exit 1): after two seconds the editor had closed, disproving the harness assumption that this toggle necessarily holds this operation pending. It is not an offline-recovery pass. Its phases are preserved in android-phases-sdk-toggle-failed.json. Earlier reports inferring a pending operation from absence of an error have been corrected.

On continuation, AVD 5564 and demo backend ports were no longer active; no process disappearance cause was established. A fresh fixture now registers/verifies an owner and member and joins through ordinary app controls, rather than assuming the old in-memory fixture survived.

A fixed loopback TCP relay (8181 to demo Firestore 8180; local control 8182) drops existing connections and blocks new ones during the recovery probe. It never inspects/logs payloads. Its Node regression first failed under sandbox loopback restrictions (EACCES); the authorized local execution passed 1/1. The local-only app port option accepts only 8180/8181, defaults to 8180 and leaves flavor/project/native guards intact. It is not a production routing option.

The first relay Android run completed all grocery assertions (including actual pending state, visible transaction error with retained draft, ordinary retry, correct saved quantity/no duplicate, native clipboard, Clear Used cancellation/confirmation and deletion), then failed on an off-screen AI-settings text finder. android-relay-recovery.* and android-phases-relay-result.json retain this overall failure (exit 1; 2:51). The settings page is a lazy ListView; the fixture waited without scrolling. Changed the assertion to use the existing strict visible-scroll helper and then assert the same default-provider text. No app assertion was weakened, and the grocery checkpoints are not counted as an overall pass.

The next Android run (android-recovery-final.*, exit 1, 1:58) reached all 13 checkpoints but strict exception checking caught actual AI-settings overflows: 5.6 px at the default-provider heading (Row at line 297) and 72 px at the connection-status Row (line 652). android-phases-recovery-final.json preserves the checkpoints; this is still an overall failure. Reproducing both via narrow/enlarged-text widgets before repairing their constraints.

Provider-layout regressions: provider-layout-reproduced.* failed 1 pass / 2 failures at 320px normal/2x text. A first patch failed compilation (provider-layout-compile-failed.*); corrected compilation then exposed another unconstrained provider-key heading (provider-layout-fixed-final.*, 1 pass / 2 failures). Constrained both headings/status text and wrapped status/action controls on narrow widths, preserving labels/colors. provider-layout-complete.* passed all 3 cases (retry/isolation plus both layout scales), exit 0. The combined fixture now uses the same verified relay procedure rather than the disproven SDK-toggle assumption; it requires the relay build flag if run in future.

Security rerun: security-acceptance.* returned exit 1, 64/65 because the first fixture reset returned HTTP 499 rather than 200; that owner-read case did not reach its authorization assertion. Exact cancellation cause is unconfirmed. The unchanged script/rules reran successfully (security-acceptance-rerun.*, exit 0, 65/65). Both results are retained; no rule or test assertion was weakened.

Final full Flutter suite: flutter-tests-final.* passed **206 tests**, exit 0, 1:31, after all app-source repairs. This is unit/widget/repository evidence, separate from Android, security-emulator and live-provider evidence.

## Important files changed in Stage 10

- lib/features/grocery/pages/grocery_page.dart: shared validated editor, safe mutation feedback, visible loading/Retry, Clear Used confirmation and wrapping rows/clipboard feedback.
- lib/features/grocery/widgets/grocery_item_editor.dart and clear_used_dialog.dart: retained drafts, guarded asynchronous submit, safe errors, validation, unknown quantities and explicit clearing confirmation.
- lib/features/grocery/data/grocery_repository.dart: nonfatal duplicate handling and explicit listener loading/retry lifecycle.
- lib/features/meal_plan/pages/saved_meal_plans_page.dart and meal_history_page.dart: reachable history and stable per-source meal keys.
- lib/core/services/notification_service.dart and lib/features/notifications/pages/notifications_page.dart: distinct loading/error states, operative retry, awaited read-action feedback and session-safe navigation; injectable inbox presentation for regression tests.
- lib/core/widgets/app_shell.dart: nonvisual unread-badge test key.
- lib/core/services/ai/live_ai_policy.dart, ai/generation_failure.dart and llm_service.dart: emulator-only refusal of live generation/replacement/validation/discovery before credentials, provider requests or quota changes.
- lib/features/ai_settings/data/ai_provider_repository.dart and pages/ai_settings_page.dart: guarded terminal-listener retry, safe provider failure messages and constrained/wrapping narrow-screen headings/status/actions.
- lib/main.dart: local-only Firestore port 8180 default / 8181 acceptance relay allowlist; existing demo/flavor/project/native safeguards remain.
- test/grocery_editor_test.dart, notification_inbox_test.dart, live_ai_policy_test.dart and ai_provider_retry_test.dart: 12 new unit/widget cases across this stage; final total 206 versus Stage 9's 194.
- integration_test/stage10_workflow_test.dart and stage10_grocery_recovery_test.dart, test_driver/stage10_workflow.dart: strict ordinary-UI assertions, exact meal identity, notification read/badge checks, grocery mutations and verified transport recovery. Existing Stage 9 fixture/driver retained.
- audit/stage10/firestore_relay.mjs and firestore_relay.test.mjs: fixed loopback test transport and forwarding/disconnect/reconnect regression. No payload inspection/logging.
- audit/stage10/verify_tester.ps1, TESTER.md, COMMANDS.md, REPORT.md, LIVE_AI_APPROVAL.md and retained logs/phase files: reproducibility, isolated artifact verification and honest evidence/approval limits.
- Root TESTER.md, README.md and WHATMEAL_FUNCTIONALITY.md: current local tester links, evidence updates and removal of a duplicated 89-row matrix copy. All 89 unique requirement groups remain tracked.

No dependency upgrade, Firestore rule/schema change, backend deployment, paid service, credential-storage migration, signing-key generation or unrelated UI redesign is part of Stage 10. Earlier-stage staged/unstaged changes remain intact.

Final analysis initially reported one unused cloud_firestore import in the combined integration fixture after relay conversion (flutter-analyze-final.*, exit 1, 50.2 s). Removed only that import; flutter-analyze-clean.* passed with no issues, exit 0, 4.7 s. No app-source change followed the 206-test pass. Protected hashes confirm rules, unchanged 65-case suite, local native manifest and demo Google Services configuration match the Stage 10 baseline; main.dart changed only for the restricted local relay port and formatting.

## Completed Android recovery acceptance

android-recovery-layout-fixed.* passed, exit 0, 1:58. One combined actual Android workflow completed **13 checkpoints**; framework +2 includes teardown, not two independent workflows. android-phases-recovery-passed.json retains exact phases. Two fresh demo accounts registered/verified, an invitation was copied via native clipboard and redeemed through ordinary UI, and the member operated on the expected shared household groceries. The relay disconnected existing SDK sockets (counter increase asserted), the editor retained pending state with duplicate submit disabled, a real transaction failure kept the draft visible, an ordinary retry after reconnect persisted 2 pieces exactly once. Blank quantity, normalized duplicate rejection, rename/quantity updates, check/uncheck, native list clipboard, Clear Used cancellation/confirmation preserving unchecked items, and item deletion passed. The default-provider settings screen scrolled into view without suppressed layout exceptions; the actual LlmService guard rejected a live-generation request with unchanged demo quota. This last step is a local service guard check, not AI generation through the UI or provider verification.

The relay was restored online in finally, then stopped by verified local process identity. No ANR occurred since AVD boot. AVD stopped before release compilation. Stage 9 household lifecycle/core acceptance remains valid and was not rerun wholesale; Stage 10 earlier history/notification checkpoints remain bounded observations in failed combined runs.

## Standalone tester build and artifact verification

Release-mode local build passed, exit 0, **76.5 s**, 55.2 MB (build-tester.*), with normal platform regeneration after integration/debug. Existing tester debug keystore was checked before building; android/key.properties remained absent. No signing secret was generated, read into reports or printed. This is an emulator tester, not a production release.

- Package: com.example.whatmeal.local; version 1.0.0 / code 1; min SDK 24, target/compile SDK 36.
- Native Firebase project: demo-whatmeal-audit, matching guarded local Dart options. Standalone host 10.0.2.2, Firestore 8180/Auth 9099; no relay required.
- APK v2 signature verifies against the existing Android Debug certificate SHA-256: 371ccb837f5379cc570eee0808710d3ca1cc36cbabef112e0a3d7960274b25bb.
- APK SHA-256: **B2BD5AB7C69FF52A27CDE727350521FB9826DF05591D2917B4EF7B5F9BAC5D88**.
- Native manifest references the verified local network policy: general HTTP denied, only 127.0.0.1/localhost/10.0.2.2 allowed; FCM and analytics auto-init both false.
- The first verification helper terminated due to PowerShell positional Select-String argument binding (preserved apk-verification-first-failed.*); corrected explicit parameters. Artifact verification then passed, exit 0 (apk-verification.*). No installation occurred before verification succeeded.

APK: build/stage10/whatmeal-local-tester.apk. Reproducible checks: verify_tester.ps1 and apk-identity/project/signature/native-guards/network-security/sha256 evidence files. Runtime startup is separate from these build/static checks.

## Standalone Android runtime result

The verified APK installed successfully (tester-install.*, exit 0), then cold-started successfully (tester-launch.*, exit 0, TotalTime 1151 ms). tester-focus.txt confirms the isolated package's activity; tester-anr.txt reports no ANR since boot. tester-startup.png was captured and visually inspected: original WhatMeal branding and Sign In form rendered. This is separate from the passing debug integration workflow and does not certify every release-mode interaction.

## Remaining blockers and prioritized continuation

1. **Live AI configuration/approval:** no approved non-production live-AI project exists in this workspace. Only emulator project demo-whatmeal-audit is approved, configured by firebase.audit.json, android/app/src/local/google-services.json and local options in lib/main.dart. Follow LIVE_AI_APPROVAL.md: confirm only a test project ID and private local configuration locations before preparing a distinct allowlisted flavor; no production credentials or calls. Real Gemini/custom provider success, real quotas/errors, model availability, AI replacement and recipe/image correctness remain unverified. No fabricated provider output was used.
2. **Simultaneous devices:** one isolated AOSP AVD with two sequential accounts was used. Stage 9 household lifecycle/core acceptance and Stage 10 groceries are actual SDK/UI evidence; simultaneous listener propagation, contention and account switching during prolonged outages still need two isolated devices. Use the existing identity/provenance/security regressions as prerequisites.
3. **Native push:** local FCM remains intentionally disabled. No trusted sender/approved push configuration; background/terminated delivery, permission denial/retry and cold-start taps remain unverified. In-app shared history/private receipts do not establish push delivery. No Functions or paid service was added.
4. **Broader UI/recovery:** terminal SDK listener errors currently have injected-stream/widget/source evidence; only the grocery write outage/retry was verified on Android. Password/reauthentication, dependent-profile edit/delete, viewOnly empty-household UI, pantry deletion, other offline operations and wider accessibility/native keyboard testing remain bounded gaps in the 89-row matrix. The typing handler is simulated; Android rendering, navigation, clipboard and Firebase SDKs are real.
5. **Production release and credential ownership:** keep local v2 rules/migration/cutover/deployment separate and approval gated. No production signing credentials are configured; current artifact uses the existing debug tester certificate. Owner must approve/configure production signing, registrations and attestation privately; perform credential cleanup/rotation as needed. API-key persistence remains owner-only Firestore, not an OS vault; storage migration requires separate approval. Do not introduce live keys merely to complete local testing. iOS/web builds and production compatibility remain unverified.

All completed and failed test evidence is retained. No production Firebase data was read, migrated, modified or deleted; no rules/backend changes were deployed; no paid service/Blaze/Cloud Functions was enabled; no live AI call was made. Existing user work remains in place. The application is not declared fully complete.

Requirement classification totals (89 groups, evidence scope stated per row): 21 Implemented and verified; 59 Implemented but partially verified; 0 currently unresolved Broken and reproduced; 1 Missing; 5 Blocked by configuration/infrastructure; 3 Not tested. These are requirement groups, not defect totals. Historical reproduced failures remain in the journal. Final git diff --check exit 0; only existing LF/CRLF conversion notices were emitted.

## Handoff state

The dedicated headless AVD was explicitly stopped after successful startup capture (tester-avd-stop.*, exit 0), retaining its installed tester and disk state. The demo backend launched for this continuation was interrupted intentionally after testing; this is not a failed acceptance test. A final listener check found no services on 8180/8181/8182/9099/5564/5565. Restart demo services and the dedicated AVD as documented before manual use. Exact APK bytes: 57,879,145; final SHA-256 was recomputed and matches verification. RESULTS.json records the final checkpoint. No additional app source change followed the passing full suite and Android run.

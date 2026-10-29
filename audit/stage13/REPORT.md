# Stage 13 — Auth, grocery and saved-plan terminal recovery

Continues the preserved Stage12 checkpoint. Only demo-whatmeal-audit local emulators and the dedicated AOSP AVD are authorized. No production access/data/deployment, live AI, paid services, Cloud Functions or signing changes. Original rules/security65 and native/Dart guards protected by baseline hashes.

## Implemented repairs

- Auth canonical profile errors previously silently fell back to Auth fields and never reopened. Added fixed safe error state, an explicit Retry Account Profile action and a separate listener generation. Retry does not change the account session or invalidate unrelated editors. Old sessions/retries/disposed callbacks cannot publish profile data. Firebase identity remains available during profile failure.
- Logout captured A but awaited notification cleanup before unconditional signOut. Added session/UID checks so delayed cleanup cannot sign out B or a later A session; guarded post-signout identity. Profile/verification signout surfaces fixed safe feedback on failure instead of an uncaught exception or unconditional navigation.
- Saved-plan personal/household listener errors previously became empty lists without error/loading/retry. Track each feed independently, preserve a healthy feed's data alongside the failed-feed notice, and reopen streams through Retry Saved Plans. Failed feeds cancel nested subscriptions; reset resolves root before publication. No false empty-state claim while a failed feed is empty.
- Grocery initialization/reset published old list/scope/error state before completing reset; terminal item/parent errors also notified before setting error. Publish consistent state, invalidate item epoch on parent failure, cancel terminal streams and reopen real queries on Retry. Own Auth/household/plans/pantry subscriptions detach on disposal. Existing projection and Firestore query/order/default-list behavior retained.
- Several grocery/saved-meal mutation paths returned late success or proceeded after an awaited read without checking account scope. Added checks around delayed initialization, bulk-add completion, clear-used reads, grocery edits/status completion and saved rename/edit/delete completion. Saved meal edit transaction checks the session after reads before dispatching writes.

Dependency injection is limited to existing account/storage/query boundaries and optional page repositories; production singleton defaults remain the same. No permission/rule bypass or new database schema.

## Local execution evidence

- analyze-initial.* exit1: five style infos and two compile errors (nullable injected initializer and test UserInfo constructor); retained. Fixed nullable invocation and used an explicit fake UserInfo implementation. Scoped dart fix applied five curly-brace fixes in three changed files (lint-fixes.txt).
- recovery-focused.* exit0: seven tests passed (Auth3, saved2, grocery2).
- recovery-expanded.* exit0: twelve passed, including added delayed meal transaction case, existing nested plan streams and account-scope cases.
- flutter-tests.* exit0: **233 passed**,1:51; eight new tests versus Stage12's225. These use controlled streams/fake Firestore/Auth; they do not alone verify Android Firebase SDK, rules contention or live provider behavior.

No pre-fix test run is claimed for these source-traced defects. All actual failed compilation/analysis attempts remain failures. Android fixture and subsequent results follow below.

## Additional reproduced account-isolation defect

stale-editor-reproduced.* exit1: two repository tests passed, one new widget regression failed. A grocery editor opened under A then submitted under B created an item in B's private list. This is a fake-Firestore/UI reproduction, not production data access. The old callback resolved the repository's current root when Save was pressed instead of retaining/checking its opening session.

Grocery add/edit now captures scope on open, checks before dispatch and displays a specific close/reopen message for stale sessions. Remove and Clear Used confirmations also retain their opening scope, preventing an old prompt from deleting B's items (including identical deterministic IDs). Saved-plan deletion now supplies the dialog's expected session to its existing guarded repository API. Late grocery deletion completion now rejects rather than returning apparent success.

stale-actions-fixed.* exit0,9 passed: retained grocery-editor cases plus new A-B/ABA stale draft and old remove/clear prompt regressions. The saved-plan stale confirmation is added to Android acceptance. Full suite rerun is justified by these additional app fixes; the earlier233 pass remains recorded, not substituted for the later source state.

## Tooling attempts

analyze-fixture.* exit1, four unused integration imports, removed. A fixture-writing/formatting wrapper was interrupted after it produced the fixture but did not complete formatting; this is not a test result. Direct cached Dart formatting succeeded afterward. flutter-analyze.* exit0, clean80.3s (before the later stale-action fixes).

build-integration.txt is an interrupted attempt: a build wrapper was started before that analysis finished, detected and stopped, child exit not captured (build-integration-interrupted.json). It is not a pass. The subsequent serialized build-integration-serial.* exited0,70.8s, with the AVD stopped and normal platform regeneration, but its APK is superseded by the later stale-action fixes and will not be installed. The final integration build follows after the final suite/analysis.

## Final pre-device results

flutter-tests-final.* exit0: **235 tests passed**,1:26, ten additional cases versus Stage12. analyze-final.* exit1: three curly-brace infos in the new UI guards and one redundant test import; repaired without changing behavior. analyze-clean.* exit0: **no issues**,38.0s. The final integration build includes the stale grocery/editor/delete/clear and saved-delete guards; the earlier binary remains superseded and uninstalled.

Android fixture details: original app UI registers/verifies two disposable demo accounts. Terminal faults deliberately bind otherwise unchanged repository listeners to forbidden demo paths. Visible Retry controls then reopen authorized queries. Grocery and saved-plan fixtures use actual Firestore SDK/store operations, not UI creation and not fake live-AI generation. Test typing is simulated by Flutter; rendered pages, controls and Firebase SDKs are actual Android. Custom page/repository injection remains confined to the test fixture; production singleton wiring unchanged.

Auth profile Retry is first exercised while permission remains denied, then after selecting the authorized own-profile path. Grocery items and parent feed are tested separately. Saved-plan parent and nested-meal listeners fail separately, then recover with exact plan/meal identity. Stale grocery editor and saved-delete dialogs stay open across real native A-B-A transitions; original server data must remain intact. Delayed logout cleanup and a failing delayed grocery initializer use explicit local Completers around real SDK transitions. These are controlled application delays/failures, not claims of real network outage. Existing Stage10-12 transport/restart evidence remains separate.

## First Android attempt — retained failure

android-terminal.* exit1, six completed checkpoints in android-phases-terminal.json. Two demo registrations/verification, visible Auth profile Retry, grocery item and parent Retry, and a stale grocery editor across native A-B-A passed before the workflow failed. android-progress.png shows the saved plan without a failure notice; no ANR. The nested fault never occurred: the new optional watchMeals parameter had been added but not called in the child subscription. This was an incomplete test-boundary implementation, not evidence that a real nested denial recovered.

nested-hook-reproduced.* exit1,2 passed/1 failed: expected one injected child watcher call, observed zero. Replaced the direct child snapshots source with the supplied watcher when present; the default query/order/decoding remains identical. Added a regression checking both actual hook invocation and terminal error propagation. Full suite is rerun because stream source wiring changed. No permission assertion was removed, and nested recovery is still unverified until the corrected Android workflow finishes.

The clean-room Android rerun repeats its two-account setup because the first fixture did not persist reusable account/plan identifiers. Old emulator-only records and all evidence remain intact; only the .local application's disposable cache/session will be cleared before the new fixture. No production data is involved.

After connecting the child watcher, flutter-tests-verified.* exited0: **236 tests passed**,2:21 (eleven more than Stage12). All earlier233/235 results remain valid only for their earlier source states; this is the latest full suite. The added nested hook case passed, as did the original nested edit/status/add/delete/cancel cases. Final analysis is analyze-verified.*. No product behavior was replaced with a fake success or permission exemption.

## Issue groups and verification scope

- HIGH: stale grocery editor/destructive prompts could resolve the new account's current list; reproduced cross-account add before repair, widget A-B/ABA and confirmation guards pass. Android stale-editor checkpoint passed before the first run's later fixture failure; rerun still required for the complete workflow.
- HIGH: delayed logout cleanup could sign out a newer session; controlled Auth regressions pass. Local mode skips native FCM cleanup, so the real native token lifecycle is not claimed verified.
- MEDIUM: terminal canonical profile listener had no visible recovery; fixed safe error, explicit Retry and generation guard; Android visible Retry checkpoint passed in the failed combined run.
- MEDIUM: grocery terminal/reset state was inconsistent; fixed atomic publication, cancellation/resubscription and owned source cleanup; Android item/parent visible Retry checkpoints passed in the failed combined run.
- MEDIUM: saved-plan terminal failure looked empty; added independent feed errors/loading/retry and preserved healthy partial data; parent/nested complete Android recovery still pending rerun.
- MEDIUM: stale async mutation continuation/success; scoped guards added; delayed init/add, password reauth and saved transaction tests pass. Already dispatched server writes cannot be cancelled or rolled back by these guards.
- LOW (test infrastructure): optional nested-listener injection was disconnected; reproduced, corrected and covered by new invocation/error-forwarding regression.

Seven grouped findings; verification is limited to the explicit evidence above. No new Firestore schema/rules, indexes, backend services or migration. The original65 cases retain their Stage11 passing result and remain unchanged.

## Dependent grocery recovery and draft preservation

dependency-reproduced.* exit1,4 passed/1 failed: a saved-plan terminal failure produced no grocery failure even though meal requirements could be incomplete. Groceries now expose a fixed safe upstream failure/loading state, and Retry restarts the failed saved-plan stream as well as the grocery stream. No stored grocery records are deleted. dependency-fixed.* exit0,5 passed.

retry-session-reproduced.* exit1,2 passed/1 failed: SavedPlansRepository.retry incremented sessionVersion under the same account, which could invalidate an unrelated generated draft. Listener generations are now separate from account/household sessions: Retry rotates only the feed generation; real workspace changes still invalidate sessions and pending actions. The strengthened regression requires stable sessionVersion during Retry while retaining A-B-A stale-feed and mutation protections.

These add two MEDIUM product findings to the seven groups above: **nine grouped findings total (eight product issues, one test-hook defect)**. New Android coverage links a failed saved-plan source to a real GroceryPage and requires its visible Retry to restore both feeds without changing the account session.

Latest full suite: flutter-tests-complete.* exit0,**237 passed**,1:16 (twelve more than Stage12). analyze-complete.* records the following serialized analysis. The earlier successful 11-checkpoint Android workflow (android-terminal-verified.*,exit0,45s,7 captured SDK permission denials) is preserved but predates these last two dependent-recovery changes; the final device acceptance will run their new checkpoint as well.

## Final Android result

android-terminal-complete.* exited0,**47s**, one combined test/**12 checkpoints** (framework +2 includes teardown). android-phases-complete.json records the phases. All requested Auth/grocery/saved parent/nested Retry cases, stale grocery editor and saved-delete confirmation across native A-B-A, upstream saved-plan grocery recovery, session-preserving retry, delayed logout cleanup and failing delayed initializer/pending add completed. Rules were unchanged. The fixture records8 captured permission-denied observations; nested errors are forwarded through more than one layer, so this is not8 independent security cases.

No ANR (android-anr-complete.txt). android-progress.png is a real page capture from the failed first workflow; android-complete.png was captured after teardown and is blank, so it is not visual acceptance evidence. The standalone tester startup screenshot will supply final runtime/branding evidence. There was no concurrent physical/two-device test, live AI, native push, real email delivery, native keyboard test or production certification.

## Important files changed

- Auth repository: injectable existing SDK boundaries; safe profile error/retry; separate profile generation; owned cancellation/disposal; stale logout session/UID checks. Auth verification/profile pages: safe logout failure feedback and visible profile Retry. Profile edits retain the supplied repository/session boundary.
- Grocery repository: scoped injected feeds/dependencies; atomic root/error publication; terminal resubscription and proper disposal; scoped async continuation checks; upstream saved-plan error/loading propagation and coordinated Retry. GroceryPage/editor: opening-session guards for add/edit/remove/clear, with retained stale-draft feedback. Existing pantry/meal requirements, units/provenance and duplicate store logic remain intact.
- SavedPlansRepository: separate personal/household readiness/error, cancel terminal source, visible recovery through page, separate feed and account session generations, scoped mutation continuations. saved_plan_stream.dart: injectable child source actually used, original production query/order preserved. Saved page: loading/error/Retry, healthy partial results, no false empty state; delete dialog passes expected session and exact path.
- core/widgets/listener_recovery_notice.dart: small shared existing-theme Retry notice, no branding/navigation redesign.
- test/auth_terminal_recovery_test.dart (3), test/saved_plan_recovery_test.dart (3), test/grocery_feed_recovery_test.dart (5), added child-boundary case in test/saved_plan_stream_test.dart (1):12 added cases,237 total.
- integration_test/stage13_terminal_recovery_test.dart and test_driver/stage13_terminal.dart: isolated real SDK/UI fault/retry and native account transitions, with controlled local delay/failure boundaries clearly identified.
- WHATMEAL_FUNCTIONALITY.md, latest tester/report links and audit/stage13/: exact results, fixture limitations, failed/interrupted attempts and continuation. Historical work/artifacts preserved.

## Remaining genuine limits / next steps

1. Exercise shared-household/role variants, simultaneous devices, native signIn/signOut RPC overlap and wider in-flight operations. Already dispatched SDK writes cannot be cancelled/rolled back by client scope checks.
2. Add direct device terminal-error/retry cases for settings/notification feeds and native notification/token cleanup. Emulator mode disables FCM; the delayed Auth logout test injects cleanup delay and does not establish native FCM behavior.
3. Broaden offline/cache/OS restart and revocation-during-outage coverage, keeping Stage10-12 bounded evidence distinct. Cached membership is not fresh server authorization.
4. Live AI needs an explicitly approved non-production Firebase project/configuration. Only demo-whatmeal-audit is approved, at firebase.audit.json, android/app/src/local/google-services.json and guarded lib/main.dart. No live provider keys/project were used.
5. Production signing/attestation, credential rotation/storage decisions, trusted push sender, migration and deployment remain separate owner actions/approvals. No paid services or Cloud Functions introduced. Production was not read, modified, migrated or deployed.

## Final standalone tester and cleanup

Local release build exited 0 in 94.4s, with normal platform regeneration and AVD stopped. `build/stage13/whatmeal-local-tester.apk` is 57,895,529 bytes, SHA-256 `0C5E59E0E7824BC153D7ACAD1C8CEFDCBBBF6DD2BB93D46B90BAE988FF5AFC7C`. Package `com.example.whatmeal.local`, native/Dart project `demo-whatmeal-audit`, existing debug tester signature, local network restrictions and disabled FCM/analytics passed verification (exit 0). No production signing material was created or printed.

Install/reset/cold-start each exited 0 on confirmed `whatmeal-stage9-aosp` (port 5564). Cold launch reported COLD, TotalTime 2256ms. `tester-startup.png` was visually inspected and shows the original WhatMeal Sign In screen; focus is the local package and Android reports no ANR since boot. Runtime startup evidence is separate from build success. The dedicated AVD and local backend were intentionally stopped afterward; backend wrapper exit 1 reflects deliberate interruption, not a failed acceptance test. Start demo services using TESTER.md before manual use.

Latest authoritative evidence: 237 Flutter tests passed; analysis clean (17.3s); final Android combined workflow passed 12 checkpoints (47s); no production access, modification, migration or deployment. Earlier chronological pending statements and intermediate counts above describe historical attempts, not the final result.

Final consistency check: all 89 requirement IDs are unique; nine authoritative exit files are 0; final APK hash matches; all five protected security/native guard files are unchanged; `git diff --check` exited 0. `cleanup-ports.json` confirms no listeners remain on dedicated ports 8180/8181/8182/9099/5564/5565. Existing unrelated processes were not stopped.

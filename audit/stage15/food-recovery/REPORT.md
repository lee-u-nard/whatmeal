# Stage15 food failure recovery follow-up

2026-10-18. Local-only continuation using fake data and isolated demo Firebase fixtures. Existing changes, normal cached account and private AVD backup are preserved. No normal backend restart, account reset/recreation, production access/migration/deployment, rule change, paid service, Cloud Functions or live AI.

## Defects reproduced and repaired

1. MEDIUM: Grocery completeness considered failed/loading saved plans but ignored failed/loading pantry. A loading/error pantry cleared its stock, allowing an apparently healthy full-quantity shopping requirement. Typed PantryRepository dependencies now contribute safe error/loading/workspace-readiness state. Grocery Retry reopens a failed pantry feed, and incomplete sources publish no calculated requirements.
2. MEDIUM: A delayed purchase callback could persist an inflated derived receipt after pantry denial. Purchase/delete operations now reject incomplete/error grocery feeds before writing, and unpublished requirements are cleared. Manual-source provenance and permission checks remain intact.
3. MEDIUM: Pantry subscriptions did not cancel on an error, so a controlled obsolete callback could clear terminal failure without Retry. Failed subscriptions now cancel; explicit Retry creates a new scoped listener, retaining existing account/household epoch guards.

4. HIGH: Actual Android offline meal acceptance exposed a FlutterFire transaction-completer race: a native error completed the Future while Dart awaited failure storage, then Dart completed it again. The first Android run failed after1 checkpoint with an unhandled StateError and an SDK unknown error. Upstream confirms this race in [issue18551](https://github.com/firebase/flutterfire/issues/18551) and [merged fix18554](https://github.com/firebase/flutterfire/pull/18554). A deterministic native-channel regression reproduced it (1pass/1fail before patch); the ordinary failure test continued passing. Both SDK cases and all6 pantry cases pass after the local backport.

The root path override uses a workspace copy of the existing6.6.12 Dart platform interface. Of52 library files,51 match the installed published package byte-for-byte; only method_channel_firestore.dart adds completion guards. BSD license and provenance retained; global SDK cache, native Firebase versions and Pigeon protocol were not changed. Two existing transitive packages are declared as test dependencies without version changes. Offline Pub resolution changed only dependency source/directness. The original transaction failure is still delivered; no zone-error filtering or assertions are disabled.

Initial analysis of the copied published SDK produced15 pre-existing application-style lint suggestions, preserved in analyze-sdk.txt. The dependency now owns a neutral analysis context: no source files or compile/error/warning diagnostics are excluded/suppressed. App flutter_lints remain unchanged. Final analysis is clean. See third_party/cloud_firestore_platform_interface/WHATMEAL_PATCH.md for maintenance/removal conditions; a future compatible Firebase upgrade must retain the race regression.
5. HIGH: The second Android run failed after8 checkpoints on actual replacement authorization. Meal.copyWith treated null as “keep the proposed value,” so a prior unset meal slot became the GeneratedMeal placeholder rather than retaining null; the strict replacement-link rules correctly denied the mismatch. Two mock regressions reproduced explicit-null/missing-field predecessors (5pass/2fail before fix). An explicit clearMealType option now preserves null in the successor; the predecessor's slot is canonicalized in the same atomic update for absent legacy fields. No rule changes or data migration are required. Only local implementation/disposable records were changed. The final meal-identity/race/pantry/replacement batch passed18 tests; analysis clean8.0s.
## Files changed

- lib/features/grocery/data/grocery_repository.dart: pantry dependency error/loading/scope checks, linked Retry, stale requirement cleanup and purchase/delete guards.
- lib/features/pantry/data/pantry_repository.dart: terminal subscription cancellation.
- test/pantry_grocery_dependency_test.dart: six new mock/widget cases: loading completeness, visible failure/Retry, stale purchase, terminal callback rejection, A-B-A stock isolation, stale receipt deletion.
- integration_test/food_failure_recovery_test.dart and test_driver/food_failure_recovery.dart: actual Android GroceryPage and AddPantryItemSheet with a named disposable native Firebase client. Real local SDK transactions/permission denials, visible Retry and editor draft recovery. Fixture hooks are described explicitly below.
- lib/features/meal/models/meal.dart, lib/core/services/meal_replacement_store.dart and test/meal_replacement_store_test.dart: null-slot preservation and2 regressions.
- third_party/cloud_firestore_platform_interface, pubspec.yaml/pubspec.lock and test/firestore_transaction_race_test.dart: current-version bridge backport and deterministic failure-race regression.
- Adjacent scripts/evidence and README/TESTER/WHATMEAL_FUNCTIONALITY.md updates.

## Actual regression evidence

| Run | Result |
|---|---|
| reproduced-interrupted.txt | First loading assertion failed; later widget fixture fake-clock wait hung; interrupted, not a pass |
| reproduced-widget-interrupted.txt and reproduced-cleanup-interrupted.txt | Two observed failures then fixture cleanup hung; interrupted, not complete runs |
| reproduced-verified.txt |0 passed/4 failed, exit1, before product changes |
| focused.txt |14 passed/2 failed, exit1; expected test string incorrectly used1 cups instead of normalized1 cup |
| focused-final.txt |18 passed, exit0,10s: new cases plus grocery-feed, scoped-feed and shared meal/pantry regressions |
| analyze.txt |exit1: pantry editor returns NewPantryItem wrapper; harness conversion corrected to its item/category |
| analyze-final.txt |No issues, exit0,6.4s; later harness-only server-ack barrier is checked again before handoff |

The widget fixture now cancels/disposes synchronously, requests stream closure and drains a frame, avoiding waits on futures scheduled in the fake clock. Late error/cancellation assertions remain strict. No interrupted or partial result counts as success. Existing historical65 security cases are preserved and not reset/rerun against manual data.

| Run | Result |
|---|---|
| SDK race first test |1pass/2fail including unsupported mocked app-delete cleanup; exit1 |
| sdk-race-reproduced-final.txt |1pass/1fail, exit1; deterministic duplicate-completion race |
| sdk-race-final.txt |8passed, exit0;2bridge +6pantry regressions |
| analyze-sdk-final.txt |No issues, exit0,7.8s |

## Android isolation and boundaries

Only demo-whatmeal-audit: disposable Auth9199/Firestore9180, reversible member/test-client transport gate8183/control8184. The native default Firestore instance is explicitly routed to the stopped normal8180 port to prevent incidental singleton traffic outside emulators. Its default Auth is only compared for unchanged cached identity; no normal sign-in/sign-out/account changes. The paired disposable export was privately copied before importing. Normal9099/8180 were not started. Private AVD backup was not modified.

A single named test app owns one disposable personal account. Registration/email verification and manual-plan seeding use the local SDK, with no real email. The actual GroceryPage handles Retry/checkbox actions; the actual pantry editor is mounted through a test-only button and saves through the same transactional PantryStore as the app. This does not claim full PantryPage singleton wiring, physical keyboard typing, household food sharing on two devices, whole-device offline, native push or live AI.

Terminal failures use real denied SDK queries at injected watch boundaries. Recovery reconnects authorized queries without any rule changes or elevated Firestore writes. Network interruption is a raw loopback connection gate, not a simulated provider success. Meal acceptance/replacement/completion/deletion use real saved-plan repository/store operations; no AI generation is substituted.

## Preserved Android failures

- First run: exit1,27s,1 completed checkpoint, unhandled upstream SDK double completion. APK/log/phase files retained as first artifacts; not a workflow pass.
- Second run after SDK backport: exit1,64s,8 completed checkpoints. Actual offline acceptance and pantry save failures recovered; all3 terminal feed denials/retries and receipt server acknowledgement passed. Final replacement was denied by unchanged rules because of the slot serialization bug. No unhandled SDK completion error recurred. Files retained as second artifacts; not a workflow pass.

- Third run: exit1,26s,1 completed checkpoint. The transaction correctly failed with the SDK generic unknown code; a harness assertion allowed only unavailable/deadline-exceeded. That assertion list was corrected to include the observed SDK failure while retaining failed-RPC/no-unhandled-error/server-unchanged/ordinary-retry requirements. No generic error is treated as success; all raw codes remain in the phase report. Third artifacts are preserved, not counted as a pass.
- Fourth run: completed exit 1 after eight checkpoints, 228 seconds. Replacement committed but the harness waited for plural beans while the canonical grocery name is bean. The bounded expectation failed. An attempted interruption happened after the process had already completed; the retained status note corrects the initial interrupted filename. No workflow pass is claimed for that run.
- Final fifth run: exit 0, 87 seconds, all 10 checkpoints. Both induced transaction failures reported unavailable. The actual GroceryPage Retry and checkbox, pantry editor draft/save retry, real permission-denied queries, replacement/completion/deletion and unchanged cached login checks passed. `android-phases.json` records every checkpoint and raw failure code; `food-recovered.png` was visually inspected and shows the clean grocery state after deleting the final source. The Flutter binding's displayed +2 includes teardown: this is one workflow, not two independent acceptance workflows. Final integration build: exit 0, 23.3 seconds; SHA-256 `4DDA8A96249BD380F1EEBADCBCEFEB644306E2039FB3E5B9E515E62883304198`.

## Results and remaining work

Final local tester release-mode build succeeded, exit 0, 47.9 seconds, 55.4 MB. Artifact: `build/stage15/food-recovery/whatmeal-local-tester.apk`; SHA-256 `D80D00FB8A7D2652B6B2558A84D5CD4059A220B90C7709125C1B8A349F3FB06B`. Compiled package `com.example.whatmeal.local`, native demo project, loopback policy, disabled native analytics/FCM safeguards and existing v2 tester certificate were verified. Certificate SHA-256: `371ccb837f5379cc570eee0808710d3ca1cc36cbabef112e0a3d7960274b25bb`. No signing secrets were generated or exposed. This remains an emulator-only tester, not a production release.

Android: all 10 checkpoints passed, exit 0, 87 seconds. Final complete Flutter suite: **294 passed, exit 0, 173 seconds**, including the SDK and replacement changes (`flutter-tests-final.txt/.exit`). Final analysis: **no issues, exit 0, 32.5 seconds** (`analyze-final-complete.txt/.exit`). Ten new regression cases extend the previous 284-test checkpoint: six pantry/grocery dependency cases, two SDK completion cases and two replacement slot cases. Consult exit and phase files rather than inferring runtime success from compilation.

Disposable export completed, exit 0: all 9 pre-existing disposable users retained, 14 after the five new runs. The normal account is absent from the fixture export. Temporary transport/backend services were stopped intentionally after export; interruption shell exits are not test failures. Final host checks found no listeners on 8180/9099/8183/8184/9180/9199/4490. Five protected rule/security/native/main hashes remain unchanged. SDK provenance confirms 51 of 52 library files remain byte-identical to the installed published package. The private whole-AVD backup was not modified.

Normal backend recovery remains blocked: prior project/temp/cache search found no original paired Auth/Firestore export. The available export contains disposable fixtures, not the normal account. Keeping cached Auth and the private backup does not establish that the former server dataset can be restored. No empty normal backend or replacement account was created.

Live AI remains pending an explicitly approved non-production project; none has been confirmed/configured for live testing. Current emulator-only project is `demo-whatmeal-audit`, configured at `android/app/src/local/google-services.json` and `firebase.household-recovery.json`; no credentials printed. Native push, simultaneous devices, physical keyboard, whole-device outage/reboot and production readiness are not established by this personal-account harness. Production was not accessed, modified, migrated or deployed.




## Final startup and continuation

`install-final.exit` and `launch-final.exit` are both 0. The verified APK was update-installed without clearing data on the existing whatmeal-stage9-aosp AVD (emulator-5564), then cold-launched. `startup-final.json`: app foreground, cached Home visible, Sign In absent, no visible ANR, normal Auth/Firestore ports stopped, no data clearing. This is cached startup evidence only. The private AVD backup was not restored, edited or replaced.

Targeted whitespace review passed (`diff-check-final.exit` 0); the initial extra trailing blank in pubspec.yaml was removed, with no dependency/value change. This formatting-only cleanup followed analysis/build and does not change their semantic inputs. Windows line-ending notices are retained.

Next work, in priority order:
1. Preserve the current normal cache/backup and locate an original paired Auth/Firestore export before attempting original backend recovery. No recovery source is currently confirmed; do not substitute the disposable export or create an empty backend.
2. Extend native food recovery acceptance to two authorized household accounts/devices, including concurrent receipt/pantry mutations and revocation during pending writes. This stage is personal-account coverage on one AVD, with account-switch/stale scope behavior also covered by the mock regressions and prior stages.
3. Verify physical keyboard, complete PantryPage wiring, whole-device offline/reboot, and wider date/quantity formats. The real pantry editor/native store were exercised here; that does not certify every page and device configuration.
4. Await an approved non-production Firebase project before live AI success/error/recovery tests. None is currently confirmed. Native push still needs an approved trusted sender/device environment. Production signing, migration/deployment and readiness require separate owner approval.

See COMMANDS.md, RESULTS.json and the retained logs for exact distinctions between unit/widget mocks, actual Android SDK/UI and prior security evidence. No production access, data modifications, deployment, paid services, Cloud Functions or live AI occurred.

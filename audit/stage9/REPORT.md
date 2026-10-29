# Stage 9 — passing local Android core acceptance

Updated 2026-10-16. The combined household/core Android workflow **passed**, including its final exception assertion. The standalone local tester APK also built, verified, installed and cold-started to Sign In. No production data was read or modified, no backend changes deployed, and no paid services or Cloud Functions enabled. No live test Firebase project is approved. The only configured test project is `demo-whatmeal-audit`, in `firebase.audit.json`, `android/app/src/local/google-services.json`, and local options in `lib/main.dart`.

## Current results (supersede the execution journal below)

| Check | Actual result |
|---|---|
| Full Flutter suite | **194 passed**, exit 0, 1:33; `tests-saved-final.txt` |
| Flutter analysis | **No issues**, exit 0, 49.5 s; `analyze-saved-final.txt` |
| Actual Android app + demo Auth/Firestore SDKs | **One combined workflow passed**, exit 0, 3:18; framework reports +2 including teardown; `core-ui-saved-final.txt` |
| Completed UI checkpoints | **28**, recorded in `android-phases-core-passed.json` |
| Security acceptance | Prior **65 passing cases preserved**; rules/suite unchanged and not rerun in Stage 9 |
| Standalone local tester build | **Passed**, exit 0, 118.3 s, 55.8 MB; `build-tester.txt` |
| APK identity/signature/config | `.local` package, demo native project, existing Android Debug certificate, compiled local-only HTTP exceptions; verified with Android SDK tools |
| Standalone APK install/startup | Both exit 0; cold start to actual Sign In screen, focused WhatMeal activity, no ANR; `tester-startup.png` |

The Android workflow used ordinary app controls and actual Firebase SDK listeners. Only typing used Flutter's deterministic test handler. Local REST retrieved emulator-generated verification actions; normal Firebase Auth action-code verification and the app verification button were used. This does not verify real email delivery, native-keyboard behavior, live AI, native push, offline recovery, or simultaneous two-device synchronization.

Verified UI steps: registration/verification/login/logout; create/copy/join/remove/rejoin/leave; member access revocation; account state clearing; dietary-profile creation; manual meal editing/saving; exact household plan identity and one-day dates; favorite persistence; pending/accepted/completed/not-completed transitions and confirmations; two-meal ingredient consolidation; pantry quantities/units/expiration selection; sufficient-stock exclusion and shortage recalculation; member access to shared pantry/grocery/plan data; nested meal deletion preserving another contribution; plan reuse with new identities and independent status; deleting copy/original with correct provenance cleanup.

## Defects repaired

Twelve application defects were repaired: **1 HIGH, 9 MEDIUM, 2 LOW**. No new critical security issue was claimed or security rule changed. Test-harness races and emulator failures are recorded separately, not counted as app defects.

| ID | Severity | Defect / repair |
|---|---|---|
| S09-01 | MEDIUM | Profile dietary heading overflow; constrained wrapping preserves Add. |
| S09-02 | LOW | Settings icon/badge overflow; flexible badge retains text. |
| S09-03 | MEDIUM | Household member name/role overflow; wrapping identity. |
| S09-04 | MEDIUM | Dietary profile name/age/menu overflow; wrapping identity/actions. |
| S09-05 | LOW | Pantry-priority explanation overflow; constrained label beside switch. |
| S09-06 | MEDIUM | Participant checkbox ink hidden by decorated card / framework assertion; local Material surface. |
| S09-07 | MEDIUM | Meal action bar overflow; wrapping controls. |
| S09-08 | MEDIUM | Enlarged-text meal type/status overflow; wrapping header. |
| S09-09 | MEDIUM | Enlarged-text ingredient toggle overflow; constrained label. |
| S09-10 | HIGH | Persistent Save/View feedback obscured meal actions and blocked queued feedback; explicit six-second expiry. |
| S09-11 | MEDIUM | Grocery count/share/clear overflow; wrapping toolbar. |
| S09-12 | MEDIUM | Saved-plan Delete/Reuse/Load overflow; wrapping actions. |

Seven new regression files add **18 widget cases** to the Stage 8 baseline of 176. Failed first attempts and interrupted runs remain in the journal/logs; no interrupted run is counted as passed.

## Tester artifact

`build/stage9/whatmeal-local-tester.apk`: `com.example.whatmeal.local`, version 1.0.0 (1), min SDK 24 / target 36, ARMv7/ARM64/x86-64. SHA-256:

`F2CCEBB8BE48BE08C06A10C1061F2721B07DD4EA57345B954CFAC4E49279B5B2`

Signature verified (v2) and matches the existing Stage 8 Android Debug certificate. No signing secret was generated or printed. This is a demo-emulator tester, not a production release. See `TESTER.md`, `apk-*.txt`, `tester-install.txt`, `tester-launch.txt`, `tester-focus.txt`, `tester-anr.txt` and the startup screenshot. The first compiled XML lookup failed because release optimization renamed the resource; the failed attempt is retained, and the resource ID was resolved to `res/M2.xml` before verifying its actual contents.

## Remaining work and limits

1. Native-keyboard typing, offline/reconnect/failure recovery, manual grocery CRUD/checking/duplicate UI interactions, history/notification history/badges, and broader accessibility/screens need further device sessions. Existing unit tests do not establish those workflows.
2. Simultaneous two-device SDK synchronization remains unverified. This acceptance used one AVD switching two accounts and observing authorized shared updates.
3. Live Gemini/custom-provider generation, replacement and provider recovery remain pending an explicitly approved non-production project/configuration. None has been confirmed; no live calls were made or mocked AI substituted into the app.
4. Native push/permission/foreground/background/cold-start tests need appropriate approved configuration and a trusted sender. Local mode intentionally disables FCM; background push was not faked.
5. Production signing credentials, historical credential rotation and any secure-key storage migration remain owner actions/separate approval. `android/key.properties` is absent; tester signing reused the existing debug identity. No production migration/deployment is authorized.
6. Emulator access violations are proven; the faulting module/root cause remains unknown. Both runtime versions crashed with SwiftShader. Dedicated ports and host graphics supported the final complete Android run and standalone startup, but do not prove long-term stability or a definitive graphics root cause. No unrelated apps or security controls were changed.

## Execution journal (historical intermediate results)

## Repairs and evidence

- Actual Android navigation through Profile exposed two overflows: family-profile heading beside Add (77 px), and settings icon/badge row (10 px). Constrained text/badge widths in reusable `profile_headings.dart`, used by `profile_page.dart`, retaining existing text, styling and controls. Two widget regression cases passed at normal and 2x text scale (`profile-tests.txt`, exit 0). Device verification after the fix has not yet reached Profile.
- Expanded `integration_test/local_workflow_test.dart` to use normal Profile/Family Sharing UI navigation, focused native clipboard checks without printing tokens, and removal/rejoin/departure/account switching. `test_driver/local_workflow.dart` records completed phases when the app can return its test response. A process crash can prevent response creation; stdout checkpoints remain partial evidence only.
- First AOSP device run reached owner registration/email verification, household creation, and invitation copying before the AVD crashed (`household-ui.txt`, exit 1). No complete acceptance pass.
- Monitored QEMU exit -1073741819 and Windows Application events confirm 0xC0000005 access violations in emulator 37.2.12 (October 12/13). Fault module unknown. Memory pressure is observed but is not a proven cause. See `windows-emulator-crashes.txt`.
- Tested existing emulator 36.6.11 with the same AOSP AVD. Initial boot reported success but ADB failed because unrelated MuMu occupied port 5555. Disconnected the incidental loopback connection without interacting with that device; stopped only the audit AVD and restarted it on unused 5564/5565. Confirmed AVD name `whatmeal-stage9-aosp` and boot completion before app installation. Unrelated apps and Android security settings were not changed.
- On dedicated ports, `household-ui-runtime36.txt` returned a real test failure (exit 1), rather than losing its VM connection: Create Account was not hit-testable after native keyboard layout changes. No household phase passed (`android-phases-runtime36-first.json`). Added bounded re-scrolling after native inset updates, preserving fatal missed taps and an explicit hit-testability assertion.
- `household-ui-ime-wait.txt` (exit 1) subsequently completed both account registrations/email verification, household creation, invitation copy and the new account's initial no-household assertion. Join reached the expected two-member repository state, but the screen-title assertion ran before the UI rendered. Preserved partial phases in `android-phases-ime-wait.json`; added explicit waits for visible join/departure results. This is still not a passed household test. No profile overflow was reported in this rerun.
- The visible-state rerun (`household-ui-visible-state.txt`, exit 1) disproved a simple rendering-delay explanation: `join-screen.png` shows the two correct members but the creation form's default name, "The Miller Household". The page reads the repository name, not a hardcoded heading. The reason the entered value did not persist is still under investigation. Added native field-focus settling, secret-safe input-retention assertions and an exact saved-name assertion immediately after creation. No backend/permission workaround was introduced.
- Full Flutter regression suite: **178 passed**, exit 0 (`tests-final.txt`). Analysis: **no issues**, exit 0 (`analyze-final.txt`). These include the layout fixes and visible-state harness, but predate the subsequent input-focus harness-only changes.

## Files changed

- `lib/features/profile/widgets/profile_headings.dart`, `lib/features/profile/pages/profile_page.dart`: the two narrow-screen repairs.
- `test/profile_headings_test.dart`: two layout/control regression cases.
- `integration_test/local_workflow_test.dart`, `test_driver/local_workflow.dart`: actual Android household acceptance and phase evidence.
- `audit/stage9/*`, `WHATMEAL_FUNCTIONALITY.md`, `README.md`: commands, failures and bounded evidence.

No Firestore rules or security acceptance cases changed in this stage. Historical 65 passing security cases remain intact; they have not been rerun unnecessarily.

## Remaining acceptance

1. Complete the household UI run from a clean app session: second-account registration/join, removal, revoked access, rejoin, leave and restored owner session.
2. Exercise manual meal creation/save, exact plan identity, statuses, favorites/replacement/history/calendar/deletion, pantry/grocery quantities and provenance through actual UI. Existing unit/backend results do not establish these device workflows.
3. Run final analysis and Flutter suite after repairs; rebuild/verify/install the standalone local tester APK. Integration APK success is not standalone runtime evidence.
4. Live AI, native background push, simultaneous two-device updates, production signing and production migration remain separate approvals/configuration. Local mode intentionally disables FCM. Do not install the superseded Stage 7 APK.

See `COMMANDS.md` and matching log/exit files for actual execution. A missing exit file or interrupted run never counts as a pass.


## October 15 environment comparison

The deterministic-typing build passed (exit 0, 243.9 seconds). `household-ui-test-input.txt` reached owner verification, exact saved household name, clipboard copy, member verification, initial account isolation and visible joining. Then emulator 36.6.11 also crashed with 0xC0000005 (`avd-test-input.exit`, `windows-runtime36-crash.txt`); driver exit 1. Changing runtime version alone is therefore not a demonstrated fix.

A per-launch `-gpu host` comparison uses the existing NVIDIA driver without installing/updating drivers or changing security settings. The AVD booted and stayed connected, but the first run remained on the launch screen waiting for the Flutter Driver extension. No ANR was reported. After five minutes only the local test app was force-stopped. **The shell returned exit 0 despite this interruption; it is NOT a passing test.** See `household-ui-host-gpu.interruption.txt`, `host-startup.png`, and the run log. One identical-binary retry is recorded separately.

## October 16 continuation

The October 15 host-graphics retry (`household-ui-host-retry.txt`, exit 1) completed member joining and owner removal. It then reproduced a 30 px horizontal overflow in `family_space_page.dart`'s member-name/role Row. Replaced that Row with `MemberIdentity`, which wraps the name and role while preserving their styles. Two targeted widget regressions passed at normal/2x text (`member-tests.txt`, exit 0). The harness now waits for the next visible control after membership refresh rather than assuming repository completion implies rendered UI completion.

The subsequent `build-member-core.txt` had no final result when execution was interrupted. It is not a passed build; `build-member-core.interruption.txt` records this. Resumed build has a separate log and exit file. The Android harness additionally attempts profile creation and a one-day, one-meal manual plan save after all household phases pass. Those added steps are not yet verified.

## Household completion and creator repairs

`household-ui-scroll.txt` completed every household checkpoint: owner/member registration and verification, household creation with the exact entered name, native invitation copy, initial account isolation, visible joining, owner removal, removed-account no-access screen, legitimate rejoin, departure and restored owner membership. The harness checks for accumulated exceptions before marking `household UI workflow completed`. This is one Android AVD switching between two demo accounts; it does not establish simultaneous two-device behavior. Test typing is simulated using Flutter's registered handler; native-keyboard behavior remains unverified.

Profile creation then completed. The combined test reported three new real UI defects: profile card name/age/menu overflow (24 px), pantry-priority label/switch overflow (1.9 px), and participant checkbox ink hidden beneath a decorated card. Execution was stopped after these confirmed errors; combined exit 1, not a test pass (`household-ui-scroll.interruption.txt`).

Repairs: profile name and age/actions wrap; `LabeledActionRow` constrains the pantry label; `MealParticipantTile` provides its own transparent Material. Six focused widget cases exercise normal/2x text, preserved edit/switch callbacks and checkbox selection beneath an opaque card. First run had 5 passes/1 failure at enlarged profile text; after the wrapping correction, all 6 passed (`creator-tests-fixed.txt`, exit 0). `creator-tests.txt` retains the failure. Device rerun is pending the serial rebuilt integration APK.

The prior full suite after the member repair passed **180 tests**, exit 0, with clean analysis (`tests-member-final.txt`, `analyze-member-final.txt`). Those results predate these latest creator repairs; final full verification must include them.


`household-ui-creator-fixed.txt` again completed household and profile creation without the prior rendering/Material failures. It failed (exit 1, 2:48) because the one-day Monday plan editor initially selected today, Thursday, and the harness searched for an Edit Dish action on that empty date. `creator-current.png` records this state. Calendar source intentionally displays all seven days and selects today in the current week; the harness now explicitly selects Monday before editing. No calendar behavior was altered to satisfy the test. `build-calendar-selection.txt` and final creator verification logs record the subsequent serial checks.

## Meal card and expanded core acceptance

The full Flutter suite after creator repairs passed **186 tests**, exit 0 (`tests-creator-final.txt`); analysis was clean. A later harness-only email-action wait initially had one style lint, corrected with braces; `analyze-email-fixed.txt` passed.

`household-ui-calendar.txt` failed during member verification because its emulator email-action entry was not yet available (`lastWhere` on an empty match). The harness now waits for the actual demo action before applying it, retaining a deadline and normal verification. `household-ui-email-wait.txt` then completed the household/profile sequence and opened/edited the Monday meal. It failed (exit 1) on a 46 px meal-card action overflow and a Save Plan finder selecting an underlying page button instead of the modal. The finder is now scoped to AlertDialog.

Meal-card controls now wrap. The new whole-card widget regression passed at normal text but exposed two additional enlarged-text overflows in the type/status header and ingredient toggle. Those now wrap too; `meal-actions-tests-fixed.txt` passed both cases, including edit and completion callbacks. No actions were removed and font sizes are unchanged. `meal-actions-tests.txt` retains the first failure. `GeneratedMealCard` is public so this actual app widget can be tested directly.

Expanded Android steps additionally check exact saved-plan path/dates, favorite persistence, completed/accepted/not-completed status transitions and confirmations, pantry quantity/unit/expiration entry, sufficient-stock shopping exclusion, meal document provenance, and shortage recalculation after reducing stock. These are added tests, not yet passing device evidence. Build/full suite/analysis logs have the `meal-actions` suffix. The app remains local-only; no live AI or push testing is implied.

Latest full regression verification after all current app repairs: **188 Flutter tests passed**, process exit 0 (`tests-meal-actions-final.txt`, 1:57); **analysis clean**, exit 0 (`analyze-meal-actions-final.txt`, 53.2 s). `build-meal-actions.txt` built the expanded debug integration APK successfully, exit 0, 113.6 s. These are local automated checks, not a live AI, push, production or simultaneous multi-device certification.

## Persistent save-feedback defect

`core-ui-expanded.txt` saved the manual plan, verified its exact household source path and one-day dates, opened that meal, and persisted a favorite. It failed on a blocked Mark Completed text target. `core-ui-status-target.txt` then timed out waiting for snackbars to disappear. Installed Flutter source establishes the cause: `SnackBar.persist` defaults to true when an action exists, and ScaffoldMessenger skips its timeout. The saved-plan message had a View action and a six-second duration but stayed indefinitely, obscuring controls and queuing favorite feedback.

`PlanSavedSnackBar` now explicitly uses `persist: false`, retaining the six-second duration, text, styling and View action. This changes success feedback only; no errors or security failures are dismissed. Two actual-widget regressions passed (`save-feedback-tests.txt`, exit 0): timeout releases queued feedback, and View still executes/dismisses. The driver also captures blocked-control screenshots before failure; targets are scoped to actual buttons and modal actions. Device status/pantry rerun is pending the feedback-fix build.

## Successful core checkpoints before final grocery layout repair

`core-ui-feedback-fixed.txt` completed all household checks, manual plan saving, identity/dates, favorite persistence, completed/accepted/not-completed transitions, pantry quantity/unit/expiration entry, sufficient-stock exclusion from shopping needs, exact meal-document provenance, and shortage recalculation after reducing stock. Its final exception assertion failed on one retained 62 px RenderFlex overflow (exit 1). It is **not** an overall pass. The grocery counter/actions still shared an unconstrained Row; `GroceryToolbar` now wraps them. Both toolbar regression cases passed at normal/2x text (`grocery-toolbar-tests.txt`, exit 0), preserving Share/Clear callbacks.

The final expanded harness additionally adds a second accepted meal, checks consolidated quantities with two source documents, switches to the departed member and asserts previous meal/pantry/grocery state is cleared, rejoins through a fresh invitation, views authorized shared data, loads the exact saved plan, removes one meal and checks the remaining grocery contribution, then deletes the plan and checks provenance removal. Those additional checks are pending actual execution; no UI or backend success is inferred from their source.

## Important app files changed in Stage 9

| File | Reason |
|---|---|
| `lib/features/profile/pages/profile_page.dart` | Heading/badge constraints and profile name/age/action wrapping; expose the actual profile card for regression testing. |
| `lib/features/profile/widgets/profile_headings.dart` | Preserve Add and settings identity controls at narrow widths. |
| `lib/features/family/pages/family_space_page.dart` and `widgets/member_identity.dart` | Wrap member identity and role without losing management actions. |
| `lib/core/widgets/labeled_action_row.dart` | Constrain the pantry-priority explanation beside its switch. |
| `lib/features/meal_plan/pages/meal_plan_page.dart` and `widgets/meal_participant_tile.dart` | Correct participant Material painting and pantry-priority layout. |
| `lib/features/meal_plan/pages/generated_meal_plan_page.dart` | Wrap action/header/ingredient rows and use expiring save feedback; expose actual meal card for tests. |
| `lib/features/meal_plan/widgets/plan_saved_snack_bar.dart` | Explicit six-second expiry while preserving View and subsequent feedback. |
| `lib/features/grocery/pages/grocery_page.dart` and `widgets/grocery_toolbar.dart` | Keep count and both actions visible on narrow screens. |
| `lib/features/meal_plan/pages/saved_meal_plans_page.dart` and `widgets/saved_plan_actions.dart` | Wrap Delete/Reuse/Load; identify each plan's controls by source path without changing handlers. |
| `integration_test/local_workflow_test.dart`, `test_driver/local_workflow.dart` | Real demo SDK/UI workflows, strict interaction checks, deterministic typing, bounded email-action waits, phase/failure screenshot evidence. |
| Seven Stage 9 regression test files | `profile_headings_test.dart`, `member_identity_test.dart`, `meal_creator_ui_test.dart`, `generated_meal_card_test.dart`, `plan_saved_snack_bar_test.dart`, `grocery_toolbar_test.dart`, `saved_plan_actions_test.dart`: 18 cases. |
| `WHATMEAL_FUNCTIONALITY.md`, `README.md`, `audit/stage9/REPORT.md`, `TESTER.md`, `COMMANDS.md` | Current bounded evidence, tester instructions and reproducible commands; preserve historical failed runs. |

No rules, production data, branding assets, signing secrets or paid dependencies were changed by Stage 9.

## Shared two-meal and deletion device evidence

`tests-final-core.txt`: **192 passed**, exit 0 (2:21); `analyze-final-core.txt`: clean, exit 0 (51.7 s). `core-ui-final.txt` completed every functional assertion through shared data access, consolidated quantities, pantry-shortage recalculation, account-state clearing, invited-member shared pantry/grocery visibility, exact saved-plan loading, deleting one meal while retaining the other contribution, and deleting the plan's remaining grocery provenance. It still failed overall (exit 1, 3:08) on the saved-plan action Row's 21 px overflow at width 246. Widget-inspector deactivated-element errors occurred while reporting that retained/disposed overflow, not as evidence of an independently reproduced app lifecycle defect.

`SavedPlanActions` now wraps Delete/Reuse/Load while retaining the original handlers and styles. Both actual-widget regression cases passed (`saved-actions-tests.txt`, exit 0), normal/2x text. The harness also exercises offline reuse, checks new plan/meal identity, accepts its pending meal, completes it and verifies the original remains accepted, then deletes the exact copy and original separately. No AI request is made for reuse. These newly added reuse checks are pending execution. Latest serial rebuild/full-suite/analysis logs are `build-saved-final.txt`, `tests-saved-final.txt`, `analyze-saved-final.txt`.

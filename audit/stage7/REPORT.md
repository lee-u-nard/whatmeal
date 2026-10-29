# Stage 7 — plan identity and isolated acceptance

2026-10-11. Continues Stage 6 without resetting prior changes. No production access for migration, data writes, deployments, paid services or Cloud Functions.

## Repairs implemented

1. **Meal detail identity:** the old page flattened all plans and selected the first matching meal ID. Home, calendar, history and generated-plan navigation now carry the full saved-plan path in the route. The detail resolver binds to that plan, follows replacement links only inside it, rejects ambiguous legacy references and fails closed on cycles or missing successors. It no longer displays an unvalidated route-extra meal after its backing plan disappears.
2. **Favorites after replacement:** the old action optimistically changed the UI then wrote `widget.mealId`, which could identify the predecessor or collide with another plan. It now awaits the displayed successor's scoped write, exposes failures and uses persisted listener state for success.
3. **Status and AI replacement:** plan identity now reaches status writes, selected participant/cuisine lookup and replacement commits. Calendar writes also carry the plan path and catch failures. Opening a generated/manual draft first awaits its existing persistence flow, preventing detail actions against an unsaved recipe.
4. **Stale sessions:** detail resolution and operations retain the opening repository session. Favorites/status/replacement APIs can reject an expected session mismatch, including A→logout→A. Deletion checks its captured session again after reading children and after commit. Delayed image responses check the active session and meal before display. These guards cannot cancel a write already accepted by a backend; they prevent dispatch from stale state and stale UI publication where checked.
5. **Notification identity:** shared meal activity derives the household plan path and meal ID for navigation without changing the event schema or rules. The route helper carries that identity; native delivery/taps are not verified by these tests.
6. **Bundled credentials:** removed Gemini/Unsplash key literals from `constants.dart`. Default Gemini's existing Firebase AI/account-key path is unchanged. Optional Unsplash configuration uses a build-time define and existing missing-key image fallback. Defines are extractable from binaries, not secure secret storage. Existing cloud-stored account keys were not migrated. Older APKs/history and owner-side rotation remain outstanding.
7. **Signing:** release configuration supports an ignored `android/key.properties`; no signing material was read or generated. Debug signing requires explicit `WHATMEAL_TESTER_SIGNING=true`. No real release configuration is present on this host. Packaging without keys/tester opt-in is configured to fail; that negative packaging branch has not been separately executed.

## Actual tests and environment evidence

- **175/175 full Flutter tests passed**, `tests-verified.txt`.
- **Flutter analysis: no issues found**, `analyze-verified.txt`.
- **65/65 existing local security acceptance cases passed unchanged**, `emulator.txt`. Neither rules nor the Stage 3 acceptance source changed in this stage.
- **Separate two-account Auth/Firestore emulator acceptance passed**, same log: actual Auth-emulator registrations, owner bootstrap, outsider denial, invitation issuance/redemption, reads and writes visible to both accounts, owner removal, fresh-invitation rejoin, self-departure and reused-token denial. No admin bypass or seeded membership was used in this new workflow. It uses REST, not Flutter SDK listeners or devices.
- **New regression tests:** `test/meal_identity_test.dart` covers duplicate IDs across plans, favorite/status/replacement targeting, successor resolution, stale A→logout→A rejection, plan-preserving notification routes and replacement cycles/missing links.
- Focused identity/saved-plan/activity/audit regressions passed 23 tests before broader runs. Intermediate analysis errors introduced while wiring draft navigation were corrected; only the final clean analysis is the current result.
- `adb devices -l` returned no devices; `emulator -list-avds` returned no virtual devices. No Android system-image directory was present. No installation or device launch was attempted.
- **Tester release APK built successfully (55.8 MB)**, `build-tester.txt`, at `build/app/outputs/flutter-apk/app-release.apk`. The build explicitly selects demo-emulator mode and tester signing, not a production release. Follow `TESTER.md` before any device installation. Signature verification and artifact hash are recorded separately in this directory.

An automatic approval review rejected an earlier combined helper-copying/test command because it interpreted it as modifying the trusted suite. It did not execute. The replacement used a self-contained separate script and the unchanged original suite; that safer command was approved and passed.

## Files changed in this stage

| Files | Purpose |
|---|---|
| `lib/core/routing/meal_route.dart` (new), `app_router.dart`, `notification_route.dart` | Plan-preserving route and resolver, router parameter, notification mapping. |
| `lib/features/meal/pages/meal_detail_page.dart` | Scoped resolution, status/favorites/replacement, participant lookup, session/image guards and honest favorite feedback. |
| `lib/features/meal_plan/data/saved_plans_repository.dart` | Expected-session validation and scoped favorite/deletion completion checks; existing path authorization retained. |
| `lib/features/home/pages/home_page.dart`, `lib/features/meal_plan/pages/meal_history_page.dart` | Preserve selected meal's owning plan during navigation. |
| `lib/features/meal_plan/pages/generated_meal_plan_page.dart` | Await saved identity before detail navigation; card delegates opening to parent. |
| `lib/features/meal_plan/widgets/meal_calendar_workspace.dart` | Scoped navigation/status write and failure feedback. |
| `lib/core/services/household_activity_store.dart` | Derive exact saved-meal target from existing activity fields. |
| `lib/core/constants.dart` | Remove embedded key literals; optional image configuration. |
| `android/app/build.gradle.kts`, `android/key.properties.example` | Explicit tester/release signing separation and nonsecret setup template. |
| `test/meal_identity_test.dart` | Three regression scenarios described above. |
| `audit/stage7/two_account_acceptance.mjs`, `run-acceptance.ps1` | Isolated demo Auth/Firestore workflow and unchanged security suite execution. |
| `WHATMEAL_FUNCTIONALITY.md`, `audit/stage7/update_inventory.py`, `requirements.json`, `TESTER.md`, this report, `README.md` | Current bounded evidence, setup and remaining requirements. |

## Remaining work, in priority order

1. **Actual two-device session:** configure isolated test devices/AVDs; validate SDK streams, dialogs/account switches, offline/reconnect, membership removal/rejoin, quantities/provenance and all meal lifecycle transitions in the visible app. Backend REST success is not this evidence.
2. **Live AI:** default Firebase AI/App Check and supported provider calls need isolated configuration/credentials. None were called here. Existing parser/adapter/error tests pass, but do not prove endpoints/models or account-specific availability.
3. **UI and native notifications:** verify permission denial/retry, loading and failure recovery, badge/history/private receipts, foreground/background/cold-start taps and accessibility on device. Reliable closed-app household push remains without an approved trusted sender; no paid backend workaround was introduced.
4. **Release:** provide the existing intended keystore and release attestation configuration; rotate previously exposed credentials where appropriate. Test native demo startup and transport before claiming the emulator-only APK is usable on a device. iOS remains unverified on Windows.
5. **Remaining matrix:** all 89 groups remain tracked. The other Stage 6 pantry/grocery, provider synchronization and meal workflow tests still pass, but maximum-size rule budgets, real contention and all partial UI/recovery cases are not complete. No blanket completion claim is made.
6. **Production remains separate:** migration/cutover/rollback rehearsal and deployment require separate future approval. OS-backed key migration also remains a separate product/storage decision.

**All work stayed local. Production data and deployed rules were not modified.**

# WhatMeal audit report — stage 1

Date: 2026-10-05 (Asia/Manila). Status: **verified source/test checkpoint; the
whole-app audit is not complete and the application is not release-ready**.

## Results at this checkpoint

32 tracked findings: **2 critical, 12 high, 14 medium, 4 low**.
13 fixes implemented, 5 partial mitigations, 14 open findings. “Fixed” below
means the identified code defect was corrected; it does not mean the full feature
was verified on a device. Pure logic regression tests and one widget test ran;
authenticated repository, emulator, and cross-device tests did not.

The work preserved branding and existing features, added no dependency, did not
upgrade packages, and made no production-data writes, migrations, rules changes,
Cloud Functions deployments, or billing changes. Firebase metadata and deployed
rules were read without reading user documents or API-key documents.

## Finding register

| ID | Severity | Finding / root cause | Result and verification limits |
|---|---|---|---|
| C01 | Critical | Authenticated users can list families, obtain invitation codes, and append themselves without proving an invitation. Family updates also permit ownership-field changes. | OPEN. Confirmed in local and deployed rules. Requires coordinated private-family/invitation-capability design. No exploit executed. |
| C02 | Critical | Recursive shared write permission overrides role-specific intent, enabling member role escalation and view-only writes. | OPEN. Client permission checks are not authorization. Must replace overlapping rules and test malicious clients. |
| H01 | High | FamilyRepository keeps its family ID across logout, so logging into the same household can skip listener reattachment. | FIXED: reset cached scope, listeners, and state on auth changes; discard callbacks for wrong scope. Device verification pending. |
| H02 | High | Asynchronous saved-plan/config reads can finish after account/scope switches; cached meal plans remain visible until new snapshots. | FIXED: scope/revision guards, immediate resets, auth snapshot UID check, queued-save session guard. Emulator race tests pending. |
| H03 | High | Selecting another AI provider keeps the old provider credential and endpoint. | FIXED: provider transition drops credentials, endpoint, and fetched model list. Regression tests exercise every different provider and same-provider reselection. |
| H04 | High | LlmService prefers an old in-memory credential over the credential accompanying the persisted provider. | FIXED: read provider and credential from the same Firestore snapshot; update memory only after successful persistence; clear on logout. Multi-device verification pending. |
| H05 | High | Release startup selects debug App Check; web ships a pinned debug token and placeholder site key. | PARTIAL: removed pinned token, use release Play Integrity/Device Check and web build configuration. Previously registered debug token must be revoked; real attestation setup and device tests remain. |
| H06 | High | Both AI replacement UI flows omit household dietary restrictions. | PARTIAL: both now pass restrictions from loaded family profiles. Cold/loading profile state, saved-plan participant scope, dietary preferences/cuisines, and semantic allergen safety still need validation. |
| H07 | High | Removing another member and deleting a multi-member household batch writes other users' private documents, which rules reject. Deletion assumes a backend cascade not provided on Spark. | OPEN. Needs membership/unlink protocol and a non-destructive cleanup design. Do not grant blanket cross-user access. |
| H08 | High | Household notification fan-out batches writes into private recipient collections. One denied write rejects the whole batch and the error is only logged. | OPEN. Shared household events plus per-user read receipts proposed; foreground and terminated push capabilities must be distinguished. |
| H09 | High | Two replacement operations can mark the same old meal and each create a successor. The low-level repository also writes empty replacedByMealId when it generates a document ID. | OPEN. Use transaction/precondition with stable replacement ID in both repository paths; test concurrency. |
| H10 | High | Parsed AI output can be incomplete, duplicate meal slots, or assign replacement meals to the wrong day/type. | FIXED: validate count/slot uniqueness/day range/recipe completeness before returning plans; preserve replacement day/type. Pure validation and copy tests pass; no nutrition/allergen guarantee. |
| H11 | High | Fatal Firebase initialization errors are swallowed, then Firebase-dependent singletons still construct. App Check failure also skips notification initialization. | FIXED: show startup failure UI and stop after core failure; isolate optional App Check and notification setup. Failure-injection/device tests pending. |
| H12 | High | Android release uses debug signing and example application ID; no verified release artifact or iOS provisioning. | OPEN. Build blocked by local Gradle loopback failure before compilation. Release attestation and signing must be coordinated. |
| M01 | Medium | FCM navigation uses Navigator named routes with GoRouter, casts string parameters to Map, and routes plan notifications to empty drafts. | PARTIAL: safe route resolver and GoRouter navigation added; supports flattened/JSON parameters and saved-plan destination. Cold-start delivery while auth initializes and foreground local-notification taps still need integration work. |
| M02 | Medium | Logout never calls token cleanup; the unused cleanup removes registrations for all devices. | FIXED: invoke cleanup before sign-out, remove only matching installation tokens, compare legacy token transactionally, await logout in profile UI. Best-effort timeouts do not guarantee offline revocation; device tests pending. |
| M03 | Medium | Grocery initialization is a one-time latest-list read with racing auto-create operations; deduplication relies on cached item names. | OPEN. Need deterministic shared list selection and atomic deduplication, including existing lists, rapid repeated taps, and simultaneous members. |
| M04 | Medium | Daily Gemini quota uses a nontransactional read/write after requests complete; concurrent requests exceed limits and overwrite counts. | OPEN. Reserve quota transactionally before calls with a documented failure policy; owner-editable counters are not anti-abuse enforcement. |
| M05 | Medium | Provider secrets persist in Firestore and its offline cache. SecureKeyStore is an in-memory map, not an OS vault. | OPEN. Owner-only rules protect remote reads, but at-rest/device handling needs an explicit storage decision. Avoid embedding private keys via dart-define in distributed builds. |
| M06 | Medium | Provider settings fire concurrent unawaited saves, swallow errors, and removeKey writes defaults twice. | FIXED: serialize writes, capture UID/session, surface save failures, remove duplicate reset write. Persistence is not live-synchronized across devices and still needs integration tests. |
| M07 | Medium | AI diagnostics log raw exception text and custom endpoint paths/userinfo; custom HTTP errors expose raw bodies. | PARTIAL: AI logger uses error type/origin only; custom HTTP error body removed; regression test uses arbitrary opaque secrets. Other UI/service exception surfaces and transport exceptions need a complete redaction review. |
| M08 | Medium | Household/profile avatars index empty member names, causing RangeError for malformed records. | FIXED: safe fallback and Unicode grapheme initial. Static verification only. |
| M09 | Medium | Claimed auth/isolation/sync tests mostly assert model fields or strings; widget test only asserts 1 + 1. | PARTIAL: added 16 focused regression tests and a real widget test. No emulator, repository failure-injection, or full-screen interaction suite yet. |
| M10 | Medium | Rules lack schema/type/size validation and field allowlists for creates and updates. | OPEN. Design validators from actual records and preserve compatibility; do not blindly enforce a guessed schema. |
| M11 | Medium | Core Family.isOwner compares createdBy with itself, always returning true. | FIXED: caller UID comparison with outsider/null tests. This getter was not used by current screen permission checks. |
| M12 | Medium | FamilyRepository.regenerateInviteKey is a no-op. | OPEN. Not wired to a visible action in inspected code; implement with secure invitation rotation when that design is approved. |
| M13 | Medium | Custom adapter's non-OpenAI-compatible switch only changes URL handling while request/response format remains OpenAI. | OPEN. Do not claim native Ollama/other arbitrary API compatibility; define supported protocols and transport contract tests. |
| M14 | Medium | Saved-plan real-time updates fetch nested meals once per parent snapshot and depend on every writer touching the parent. | OPEN. Add nested listeners or enforce/test the parent-update protocol across all writers, concurrent edits, and deletion. |
| L01 | Low | README inaccurately describes placeholder screens and missing data layer. | FIXED: actual architecture, setup, verification records, and release caveats documented. |
| L02 | Low | Seven baseline analysis findings: five brace lints and two unsafe post-dialog context uses. | FIXED: braces and mounted guard; final analysis has no issues. |
| L03 | Low | Router is not disposed with the owning app State. | FIXED: dispose GoRouter. |
| L04 | Low | pubspec SDK lower bound claims Dart 3.0 while code uses newer Flutter/Dart APIs. | OPEN. Establish supported minimum toolchain from dependency graph and CI; do not lower dependencies speculatively. |

## Functional coverage and missing pieces

| Area | What was inspected | What is actually verified |
|---|---|---|
| Auth/account | Firebase UID paths, register/login/reset, verification gate, password reauthentication, profile writes, logout | Static code paths; model unit tests. No live account creation/reset/email delivery. Passwords are not written to Firestore in inspected auth code. Account deletion and Google sign-in flows were not found in AuthRepository despite google_sign_in dependency. |
| Household | Creation/join/leave/remove/delete, role UI, membership rules | Deployed rule contents read; flaws confirmed by source reasoning, not production exploits. No two-account walkthrough. |
| Profiles/preferences | Dietary profile repository and replacement/generation inputs | Model tests and passed restrictions in source. Loading/offline profile context and preference persistence need validation. |
| Pantry/groceries | Scoped listeners, statuses, add/delete, export/dedupe | Models and code inspection only. Concurrent/offline writes and real-time devices untested. |
| Meals/calendar | Manual draft creation, generated plans, details, replacement/status/favorites, saved/history repositories | Parser/model/validation tests and status widget render. Full save/reuse/delete and calendar interaction tests remain. |
| AI | Factory and all five adapters, endpoints/config/key flow, fallback, timeouts, parser, quotas | Unit tests only; documented Gemini/Groq IDs checked. No live provider credentials read or requests made. Connection status often says connected before validation; fallback behavior remains automatic. |
| Notifications | Feed/badge, household fan-out, FCM, local display, navigation, token cleanup | Route tests only. Household fan-out is blocked by rules; foreground taps and cold start remain partial. |
| UI/accessibility | Targeted dialogs, forms, name avatars, lifecycle badges, error paths | One actual widget test; no broad screenshots, screen-reader audit, responsive/device walkthrough, or golden tests. |
| Platforms | Android Gradle/manifest, iOS plist/project scaffolding, web bootstrap, Firebase options | Android build attempted but blocked. iOS cannot be built on this Windows host. Desktop Firebase options are explicitly unsupported. |

Confirmation dialogs already exist for logout, replacement, household removal,
leaving, and deletion. Their presence alone does not verify successful actions.
No unrelated visual redesign or new feature was introduced.

## Verification performed

- Baseline `flutter analyze --no-pub`: exit 1, seven informational lint findings.
- Baseline `flutter test --no-pub`: exit 0, 31 passed (one was the placeholder test).
- Intermediate tests: 40 passed, then 45 passed. Intermediate analysis caught four
  missing Meal.copyWith parameters introduced during repair; corrected before final checks.
- Final `flutter analyze --no-pub`: exit 0, **No issues found**. Full output in
  [flutter-analysis.txt](flutter-analysis.txt).
- Final `flutter test --no-pub`: exit 0, **47 passed**. Full output in
  [flutter-tests.txt](flutter-tests.txt). Passing does not prove live Firebase authorization.
- `flutter pub outdated`: exit 0. Three locked packages upgradable; 27 dependencies
  constrained below resolvable versions. Major FlutterFire upgrades intentionally
  deferred to a separately verified change; no dependency conflict observed.
- `node --check functions/index.js`: exit 0. Syntax only, not trigger execution.
- Gradle version: 9.3.1; JDK 17.0.12. Flutter 3.44.5; Dart 3.12.2.
- `flutter build apk --release --no-pub`: exit 1 before compilation:
  `java.io.IOException: Unable to establish loopback connection`. IPv4 retry same result.
  No new release APK verified; an older file in build/ must not be mistaken for this run.
- `git diff --check`: exit 0; only informational Windows line-ending warnings.
- Firebase read-only metadata: active project whatmeal-101, billing disabled,
  default database STANDARD, FIRESTORE_NATIVE, freeTier=true, real-time updates enabled.
- Deployed Firestore rules read: same critical authorization patterns as local rules.
- Not run: Firestore emulator tests, database writes, live auth, owner/invitee/outsider
  sessions, live AI calls, device notifications, offline recovery, APK installation,
  iOS builds, complete visual QA, or backend deployments.

## Important file changes

- `lib/main.dart`, `web/index.html`: fail-safe Firebase startup, separate optional
  initialization, production App Check providers, remove committed web debug token,
  and GoRouter-based notification handling.
- `lib/core/routing/notification_route.dart`: validated notification payload routing.
- `lib/app.dart`: router disposal.
- `lib/features/auth/data/auth_repository.dart`: snapshot UID isolation, logout key
  and device-token cleanup; `profile_page.dart` awaits logout and handles empty names.
- `lib/features/family/data/family_repository.dart`: auth/family listener resets;
  `family_space_page.dart`: empty-name-safe avatar.
- `lib/features/meal_plan/data/{meal_plan_repository,saved_plans_repository}.dart`:
  clear stale lists and reject obsolete asynchronous loads.
- `lib/features/ai_settings/data/ai_provider_repository.dart`: serialized saves,
  session/revision guards, visible failures, single reset write.
- `lib/features/ai_settings/models/ai_provider.dart`: tested provider transition.
- `lib/core/services/llm_service.dart`: coherent provider/key reads, validate AI
  responses, preserve replacement calendar slot.
- `lib/core/services/ai/{ai_models,ai_logger}.dart`: output validation and safer diagnostics;
  `adapters/custom_adapter.dart`: suppress raw response bodies/endpoint details.
- `lib/features/meal/models/meal.dart`: optional calendar/type copy fields.
- `lib/features/meal/pages/meal_detail_page.dart` and
  `lib/features/meal_plan/pages/generated_meal_plan_page.dart`: replacement restrictions;
  latter also guards context after confirmation dialog.
- `lib/core/services/notification_service.dart`: account feed reset and device-scoped
  cleanup; preserve the properly initialized background handler registered by main.
- `lib/core/models/family.dart`: UID-aware ownership helper.
- Auth login/register pages: lint fixes only.
- `test/audit_regression_test.dart`: 16 regression tests; `test/widget_test.dart`:
  actual status badge widget test replaces placeholder arithmetic.
- `README.md`, `AUDIT.md`, `audit/`: reproducible setup, findings, evidence, next steps.
- `firestore.rules`, Firebase production data/configuration, backend source,
  dependencies, logo, colors, and navigation structure were not changed.

## Security/data design decision and next stage

A partial role patch is insufficient: any signed-in outsider can still join, and
an already compromised member can access shared data. Tightening family reads
alone breaks the present invite-code query. The recommended coordinated change:

1. Member-only household reads and immutable creator; validated member/admin/owner
   permissions with no recursive membership-rule bypass.
2. Separate non-listable invitation documents keyed by a strong random capability;
   validate the supplied invitation proof and all membership changes atomically.
   Define revocation, expiry, rejoin, and legacy-code behavior before coding rollout.
3. Shared household activity documents and private per-user read receipts instead
   of cross-writing users' private collections.
4. Explicit owner/member departure and unlink protocol, with no Cloud Function or
   destructive cascade assumed. Preserve data until cleanup policy is approved.
5. Local emulator tests for owner/admin/member/view-only/outsider, guessed IDs,
   privilege escalation, invalid schema, membership removal, concurrent joins,
   and cross-household queries before any deployment proposal.

Approval was requested for preparing this coordinated invitation change locally;
no explicit design choice has been recorded. Production migration/deployment
requires separate explicit approval under the task constraints. No skill or tool
approval rejection is blocking the safe code fixes.

## Prioritized manual actions and continuation

P0: Decide on the invitation/membership design above. Treat C01/C02 as release
blockers. Inspect unexpected household members and ownership changes through an
approved incident review; this audit did not inspect or alter production records.
Revoke the previously committed App Check debug token if registered.

P1: Configure release signing and App Check attestation and provide the public web
site key. Diagnose local Java loopback/firewall restrictions; rerun the release
build, install on a test device, and validate startup before claiming APK readiness.

P1: Build an emulator harness with isolated fixtures and injectable repositories;
fix H07/H08/H09 and grocery initialization/deduplication against actual concurrency
and permission tests. Run with a demo project ID, never production test writes.

P2: Finish dietary context loading and participant-scoped preferences; atomic AI
quota reservations; transport-level tests for every claimed provider/protocol;
user-approved live provider smoke tests without logging keys. Make fallback and
connection-status semantics explicit and verify provider removal persistence.

P2: Two-device shared-data and offline/reconnect tests, full-screen interaction and
accessibility checks, deep links during auth startup, empty/error states, saved
plan reuse/deletion and linked grocery cleanup. Add a real CI job after tests exist.

P3: Evaluate FlutterFire upgrades as a separate change, set a truthful SDK minimum,
and decide on an OS-backed secret-storage design with migration/compatibility.

## References checked

- [Firebase rule matching](https://firebase.google.com/docs/rules/rules-behavior):
  overlapping allow rules are permissive if any match grants access.
- [Flutter App Check providers](https://firebase.google.com/docs/app-check/flutter/default-providers)
  and [debug provider guidance](https://firebase.google.com/docs/app-check/flutter/debug-provider).
- [Firebase AI supported models](https://firebase.google.com/docs/ai-logic/models)
  and [Gemini model documentation](https://ai.google.dev/gemini-api/docs/latest-model):
  gemini-3.8-flash is documented; project-specific availability not tested.
- [Groq supported models](https://console.groq.com/docs/models):
  openai/gpt-oss-20b is documented; credentials/quotas not tested.

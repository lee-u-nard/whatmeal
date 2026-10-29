# WhatMeal Stage 2 repair report — 2026-10-05

Baseline: `audit/REPORT.md` (Stage 1). Its 32 findings are not reclassified as a new
audit. Stage 1 changes remain in the existing working tree. No Git reset/revert,
production data access/write, deployment, paid service or security-rule edit was
performed. Changes are separated by storage helpers, tests and these documents.

## Repair status

| Finding | This stage | Remaining verification/limits |
|---|---|---|
| H09 replacement races | Both replacement writers use one Firestore transaction; predecessor checked, linked successor created once, slot retained, parent must exist, explicit-ID retry idempotent, actual generated ID returned | Real concurrent emulator/device test blocked; old/malicious writers not constrained by unchanged rules |
| M03 grocery initialization/duplicates | Stable default list initialization, legacy lists retained, normalized deterministic new item IDs, transactional existence checks, legacy duplicate detection, account-scope guards | Old clients can create random-ID duplicates; existing duplicates not consolidated; no real contention test; active-list selection is still initialized once per scope |
| M04 quota | Reserve in transaction before default Gemini/fallback dispatch; limit/day/account tests; malformed current counters fail closed | Failed/ambiguous requests consume reservation. Cooperative client quota only: clock/counter can be manipulated under current rules. Actual contention unverified |
| M14 saved-plan sync | Nested meal listeners now publish status/favorite/add/delete changes independently of parent edits; cancellation and scope guards | Fake-stream tests passed; offline, permission recovery, multi-device and large-feed costs unverified |
| M07 redaction | Removed raw AI parser output and public provider exception text; model-fetch and grocery UI failures use safe messages | Partial: full repository-wide exceptions/logs/notification payload review remains; internal provider exceptions may still contain bodies |
| M09 tests | 19 new store/stream/transport regressions, isolated emulator security probe | Existing widget regression rerun; no new full-screen widget or end-to-end integration tests. Emulator never reached assertions |
| M13 custom protocols | Explicit OpenAI Chat Completions contract, URL switch label corrected, URI path/query handling fixed, embedded URL credentials rejected, HTTP 200 must contain chat response | Custom transport tested with mock HTTP only; every claimed provider/model and real endpoint still needs independent/live verification |
| C01/C02 | Detailed approval-only design | Critical vulnerabilities remain open; no rules modified |
| H07/H08 | Root dependencies confirmed; coordinated removal/archive and shared activity design documented | No insecure cross-user permission workaround; functionality remains open |
| M05 | Storage options and migration risks documented | No storage migration/package installed |
| M06 | Existing Stage 1 persistence/session safeguards preserved; error text hardened | Provider settings still load once; cross-device settings listener and pending-edit conflict handling remain open |
| M10 | Permission/allowlist design and acceptance matrix documented | Rules implementation explicitly awaits approval |

Four functional repairs (H09/M03/M04/M14) are implemented with limited local
verification; they are not marked production-verified or unconditionally closed.
No new security finding count is claimed. All Stage 1 findings outside this
table retain their previous status, including dietary-context and release setup
work; see the original report.

## Important files changed in this stage

- `lib/core/services/meal_replacement_store.dart`: shared transactional replacement.
- `lib/features/meal/models/meal.dart`: optional ID in copyWith so committed IDs
  reach the UI; existing Stage 1 calendar/type fields retained.
- `lib/features/meal_plan/data/meal_plan_repository.dart`: transaction integration
  and account/household guard before post-write notification.
- `lib/features/meal_plan/data/saved_plans_repository.dart`: transaction integration,
  return actual successor, consume nested streams rather than one-shot child reads.
- `lib/features/meal/pages/meal_detail_page.dart`: use the returned committed meal.
- `lib/features/meal_plan/data/saved_plan_stream.dart`: child subscription lifecycle,
  metadata merge, removal and stale-callback protection.
- `lib/core/services/ai_quota_store.dart`, `llm_service.dart`: reservations before
  requests and safe public provider failures. Existing persisted-key coherence retained.
- `lib/features/grocery/data/grocery_store.dart`, `grocery_repository.dart`:
  stable initialization, non-destructive uniqueness checks and scope-safe loading.
- `lib/core/services/ai/adapters/custom_adapter.dart`: injectable transport for tests,
  precise URL handling and response-shape checks.
- `lib/core/services/ai/ai_json_parser.dart`: exceptions omit raw output/snippets.
- `lib/features/ai_settings/data/ai_provider_repository.dart`: safe error text only;
  the broader settings-sync repair is not claimed.
- `lib/features/ai_settings/pages/ai_settings_page.dart`: accurately label existing
  URL behavior; no visual redesign, branding, logo or color changes.
- `pubspec.yaml`, `pubspec.lock`: fake_cloud_firestore 3.1.0 and its development
  dependency graph; no production package upgrade.
- Five new test files: `meal_replacement_store_test.dart` (5),
  `ai_quota_store_test.dart` (3), `saved_plan_stream_test.dart` (2),
  `grocery_store_test.dart` (4), `custom_adapter_test.dart` (5).
- `firebase.audit.json`, `audit/stage2/emulator_security_probe.mjs`: isolated demo
  emulator harness reading the existing rules; no production configuration changes.
- `audit/stage2/*`: plan, protected-file hashes, proposals, diagnosis and evidence.

## Tests and actual results

- Replacement batch: 5 passed. Quota batch: 3 passed. Grocery batch: 4 passed.
- Saved-plan stream: initially failed recreating a deleted document using a stale
  fake reference. Inspection showed the fake removes its parent-map entry on
  delete. Reacquiring the same document path fixed the fixture; 2 passed, including
  recreation of the same ID. Production stream code was not weakened for the test.
- Custom adapter initially failed compilation because the repository's Dart
  language minimum does not support field promotion. Explicit non-null access
  after the null guard fixed compatibility; 5 tests passed in the full suite.
- Full automated suite: 66 passed (47 prior + 19 new). See `tests.txt`.
- Initial analysis identified five brace-style findings; fixed. Final analysis:
  **No issues found**. Evidence is in `analyze.txt`.
- Emulator attempt: failed during Java NIO selector startup. ZERO security probe
  assertions executed. No owner/invitee/outsider permission or real transaction
  concurrency results are claimed. Node syntax check passed for the harness.
- Final `git diff --check` passed. SHA-256 checks confirmed `firestore.rules` and
  the original `firebase.json` exactly match the Stage 2 starting hashes.
- No live AI calls, production Firebase tests, installed APK/device checks, iOS
  build, complete visual/accessibility audit, offline recovery or two-device tests.

## Build outcome

Gradle help fails before compilation with both tested JDK configurations.
Ordinary IPv4/IPv6 sockets pass but Java Selector.open fails. Firestore Emulator
fails through the same selector path. No safe remedy is proven; release APK was
not attempted in this stage under the user's precondition. See
`BUILD_DIAGNOSIS.md` for evidence and the outside-runner control test. No firewall
exceptions, antivirus changes or unrelated build configuration edits were made.

## Approval and prioritized continuation

1. Review `SECURITY_PROPOSAL.md`. Approve or amend the concrete local architecture:
   canonical membership/index, single-use expiring tokens, role matrix, shared
   in-app activity, legacy-client cutover, archival/removal behavior. Implementation
   and rule edits await approval; deployment/migration need separate later approval.
2. Resolve Java selector execution in a normal host control environment. Run the
   existing security probe against unchanged rules to reproduce critical failures,
   then add full proposed-rule acceptance fixtures after design approval. Real
   contention tests must execute the Dart helper paths, not just a JS reimplementation.
3. Finish M06 with an injectable settings repository and stream tests: remote
   changes, local pending saves, save failure, deletion/default Gemini, logout,
   A→B→A account switch, and late old-account callbacks. Do not overwrite pending
   edits with an older remote snapshot.
4. Complete M07 across adapters, logs, notifications and UI exception boundaries.
   Finish M13 transport tests for Gemini/Groq/OpenAI/Anthropic and live smoke tests
   using separately authorized credentials without recording keys or bodies.
5. Test repaired transactions under contention, offline failure, deleted parents,
   denied writes and network recovery. Expand widgets/integration for household
   owner/invitee flows, badges, saved-plan streams and account switching. Assess
   nested listener read volume before large-history use.
6. Decide M05 device-only versus encrypted sync and migration policy; native
   storage build/restore testing comes before any credential migration.
7. After the build host is fixed, produce/install a release APK and verify signing,
   App Check and startup. Continue remaining Stage 1 release blockers and UX tests.

No architectural approval has been inferred from the user's 'continue'.

# WhatMeal Stage 6 — local repair and verification checkpoint

Updated 2026-10-10. This continues the existing repairs; it does not replace historical reports or claim full live-app completion.

## Executed results

| Check | Actual result | Evidence |
|---|---|---|
| Firestore emulator acceptance | **65/65 passed**, exit 0 | `security-acceptance.txt` |
| Full Flutter suite | **172 passed** | `tests.txt` |
| Focused household/shared workflow tests | **3 passed** | `workflow-tests.txt` |
| Flutter analysis | **No issues found** | `analyze-clean.txt` |
| Android release APK | **Built, 55.8 MB** | `android-release.txt` |

APK: `build/app/outputs/flutter-apk/app-release.apk`. Existing Android configuration uses debug signing for this build. It is not a store-ready release. The APK was not installed or launched against production. The build preceded brace-only Dart formatting and final local rules refinements; rules are not deployed by building the APK.

## Security and rules

C01/C02 now have passing **local emulator** evidence for the approved canonical membership design. This is not a statement about deployed rules or production account safety. The suite tests owner/admin/member/viewOnly/outsider/unauthenticated access, membership/index coordination, bootstrap, self-join denial, role escalation, ownership transfer, invitation confidentiality/redemption/expiry/revocation/reuse/recipient restrictions, concurrent redemption and revocation, removal/leave/archive, cross-household access, shared activity, private receipts and field injection.

The first actual run passed 59/61 cases. Valid recipe creation and replacement failed because nested schema checks exceeded Firestore's expression budget. Short-circuiting unused list tails made the original 61 cases pass. Expanded realistic recipe tests exposed further expression-budget failures; the final strict validators and all 65 cases now pass. Intermediate failures remain recorded in this directory rather than being represented as successful runs.

Local `firestore.rules` changes reduce evaluation work without changing the approved role matrix or granting legacy access:

- Ingredient validation retains only `name`/`amount`, string types and length bounds. Validation stops after actual entries.
- String lists use a join/split equality check to reject coerced non-string values and a bounded pattern to validate each entry. A sentinel preserves empty-string entries. U+001F is now a reserved separator and is rejected inside these lists. Tests cover newline, empty and 1,000-character strings, malformed values, overlong values and separator injection. Nested arrays are rejected by Firestore's API before rule evaluation.
- Nullable meal text checks avoid repeated helper evaluation.
- Replacement creation uses the current resource's absence rather than an extra document read, preserving reciprocal-link and immutable-successor checks for updates.
- A representative eight-ingredient/six-instruction recipe, pantry-plus-activity transaction and a **21-meal weekly-plan batch** all pass. Extreme maximum-size recipes remain outside this representative budget verification.

The four added acceptance cases live in `audit/stage3/security_acceptance.mjs`. That script refuses to run without the exact local emulator host and uses only `demo-whatmeal-audit`.

## Java and Android build diagnosis

The expanded `LoopbackProbe.java` isolated the failure to Java's Unix-domain socket connection used by its NIO selector pipe. Ordinary IPv4 and IPv6 TCP loopback worked. The installed JDK's built-in fallback to TCP succeeds when its socket temporary directory is the long workspace-local `audit/stage6` path. `java-local-temp.txt` records successful selector, pipe and both loopback checks.

`run-security.ps1` applies `jdk.net.unixdomain.tmpdir` through process-local `JAVA_TOOL_OPTIONS`, uses the installed Android Studio Java runtime, and restores environment values in `finally`. The same process-local setting enabled the APK build. No firewall, security software, system Java installation or project Gradle configuration was changed. The setting depends on this Windows/JDK/path combination; rerun the probe if those change. Run the emulator once at a time; an intermediate overlapping invocation caused a port conflict and is not a test pass.

## Functional repairs and important files

| File | Change and purpose |
|---|---|
| `lib/features/family/data/family_repository.dart` | Injectable dependencies, subscription disposal, retry after listener failure, UID consistency guards and immediate committed-household listening. Error state clears before publishing successful data. |
| `lib/core/services/family_service.dart` | Membership stream includes metadata changes so server-confirmed empty membership can clear cached state. Earlier committed-ID and recipient fixes preserved. |
| `lib/features/family/pages/family_space_page.dart` | Explicit retry on household load failure; clipboard completion is awaited before success feedback. |
| `lib/features/pantry/data/pantry_store.dart` (new) | Pantry mutation and shared activity commit atomically; missing updates/deletes and duplicate adds fail instead of emitting false events. |
| `lib/features/pantry/data/pantry_repository.dart` | Uses the atomic store and existing account/household scope guards. |
| `lib/features/meal_plan/data/saved_plans_repository.dart` | Replacement with a known validated plan path no longer depends on a just-saved plan appearing in a listener cache first. Parent/meal validity remains transactional. |
| `lib/features/meal_plan/pages/meal_plan_page.dart` | Prevents duplicate generation interactions and blocks viewers before AI/quota work; clears busy state after failure. |
| `lib/features/meal_plan/pages/generated_meal_plan_page.dart` | Replacement resolves selected profile IDs and uses their preferences/restrictions; missing participants fail safely; categorized generation errors. |
| `lib/features/meal/pages/meal_detail_page.dart` | Same participant-context checks and safe generation error feedback for replacement. |
| `lib/main.dart` | Queued notification intent checks session version as well as UID, preventing reuse across A→logout→A sessions. |
| `test/household_repository_workflow_test.dart` (new) | Create, invite, join, remove, rejoin, logout/account isolation, leave, profile/UID mismatch and retry. |
| `test/shared_meal_pantry_workflow_test.dart` (new) | Two repository instances observe save/accept/pantry/shortage/replacement/completion/deletion changes; verifies private receipt and failed-write event behavior. |
| `firestore.rules`, `audit/stage3/security_acceptance.mjs` | Strict validation optimizations and the four additional emulator cases described above. |
| `audit/stage6/LoopbackProbe.java`, `run-security.ps1` | Reproducible local diagnostics and isolated emulator execution. |
| `WHATMEAL_FUNCTIONALITY.md`, `audit/stage6/update_inventory.py`, `requirements.json` | Updated bounded evidence and remaining gaps without rewriting historical Stage 4 data. |

Existing staged and unstaged repairs were preserved. This working tree contains multiple prior stages; this table identifies the Stage 6 changes rather than attributing the whole diff to this stage. Existing user changes to configuration/constants were not overwritten.

## What is still open

- **Live functionality:** fake-Firestore repository tests establish local synchronization logic, not real two-device Auth/offline/App Check/provider behavior. No live AI requests were made. No whole-app completion claim is warranted.
- **Release configuration:** debug signing remains; attestation and model/provider configuration need an isolated device acceptance session. iOS cannot be built/verified on this Windows host.
- **Credentials:** previously identified bundled credential configuration still needs removal/rotation where applicable. No keys are reproduced in this report. A breaking move of existing stored API keys to OS secure storage remains a separate decision.
- **Identity edge case:** meal detail lookup still begins with a meal ID across visible plans. Reused IDs across plans can be ambiguous; repository mutation guards do not constitute complete navigation verification. Carry explicit plan identity through routes in a follow-up.
- **Notifications:** shared in-app activity and private receipts are implemented and locally tested; reliable closed-app household push still has no approved trusted sender. Native tap/cold-start behavior requires device tests.
- **Scale and recovery:** recipe upper-bound expression budgets, real transaction contention for all grocery/replacement operations, sustained offline/reconnect behavior and all UI loading/error states need more coverage.
- **Production:** migration, legacy-client cutover, rollback rehearsal and deployment remain separate future approvals. See `audit/stage2/SECURITY_PROPOSAL.md`; local passing tests do not authorize production migration.

## Prioritized continuation

1. Carry explicit plan identity through meal-detail routes and favorite/replacement actions; add collision and stale-session tests.
2. Exercise real Flutter clients with two isolated emulator accounts, including removal/rejoin, offline/reconnect and stale callbacks. Keep production configuration out of that test launch.
3. Verify default Gemini and each claimed custom protocol on an approved isolated test configuration, including App Check, timeout, quota and malformed-response recovery.
4. Finish remaining UI/widget and notification-device acceptance; measure large recipe and concurrent-write limits before declaring those boundaries supported.
5. Complete credential configuration cleanup and release signing, then rebuild and run the resulting tester APK in the isolated environment.
6. Prepare a separately approved production migration/cutover/rollback rehearsal; do not weaken rules for old clients.

**Production was not read for migration, modified, migrated or deployed. No paid services, Cloud Functions or Blaze were enabled. All changes remain local and reversible.**

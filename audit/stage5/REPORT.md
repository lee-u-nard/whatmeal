# WhatMeal — household and generation repair checkpoint

Date: 2026-10-08. Local implementation only. This supersedes older Stage 5 logs for the targeted bugs; Stage 4 remains the baseline inventory, not a claim that all workflows are finished.

## Confirmed code defects and changes

1. **Household commit followed by a fallible read.** Create/join previously committed their atomic membership transaction, then fetched the household before returning. A failed fetch reported failure even though creation/redemption had succeeded. They now return the committed household ID. The repository explicitly starts canonical household listeners after success, guarded by the authentication epoch. It verifies that the profile UID matches the active authentication UID before submitting operations. Shared data still comes from authorized listeners, never optimistic invented members.
2. **Recipient validation.** Join now checks recipient UID before any writes in addition to state/expiration and existing membership. Server rules remain the independent authority; the fake database cannot demonstrate authorization. Invitation consumption, membership and index are still one transaction.
3. **Incorrect AI failure classification.** Default Gemini generation collapsed virtually every non-configuration error to a connection failure; Gemini connection testing also classified arbitrary exceptions as network failures. A shared safe failure classifier now distinguishes network, DNS, timeout, provider outage, credentials/configuration, quota, Firebase authentication/permissions/service failure, malformed response, safety rejection, validation, and unknown errors. No raw exception text is displayed by the generation page. Some SDK categories require internal text recognition, so unfamiliar errors deliberately stay unknown.
4. **Unexpected default-provider routing.** Gemini previously selected direct REST whenever a bundled Gemini key existed, even when this account had no custom key. Only an explicit account configuration key selects REST now. Default Gemini uses Firebase AI. Existing constants were not overwritten; bundled credential cleanup/rotation needs follow-up, without copying their values into reports.
5. **Generation stopped at an unsaved draft.** Successful AI output now receives stable meal IDs and is committed with its plan before navigation. Dates, meal types, actual participant IDs, cuisines, original recipe fields and ingredients are preserved. Household save activity is part of the same batch. The resulting page receives the persisted path so Save does not create another plan. Session changes suppress stale result navigation. The progress dialog is closed by its own context, avoiding a second pop of the underlying screen on a later failure.
6. **Name-only pantry availability.** Name-only meal ingredients now use usable pantry presence; measured ingredients still subtract compatible quantities. Zero stock, expired stock and used stock do not satisfy name-only demand. Available rows remain visible as pantry information, not shopping requirements. Incompatible measured units remain needed rather than guessing conversions.

## Important files in this targeted batch

- `lib/core/services/family_service.dart`: committed ID return, recipient check, no post-commit fetch.
- `lib/features/family/data/family_repository.dart`: account identity guard, listener activation, differentiated failures.
- `lib/core/services/ai/generation_failure.dart`: centralized safe categories/messages.
- `lib/core/services/llm_service.dart`: preserve categorized Gemini/provider failures.
- `lib/core/services/ai/adapters/gemini_adapter.dart`: account-specific REST selection and accurate connection-test failure categories.
- `lib/features/meal_plan/pages/meal_plan_page.dart`: awaited persistence, stable IDs, scoped navigation and progress-dialog handling.
- `lib/features/grocery/data/meal_grocery_projection.dart`: pantry presence for name-only ingredients, measured shortage calculation retained.
- `test/family_service_v2_test.dart`: recipient rejection leaves token/member/index unchanged and intended recipient can subsequently join.
- `test/generation_failure_test.dart`: thirteen failure categories, redaction and default/account-specific Gemini routing.
- `test/meal_grocery_projection_test.dart`: name-only presence, zero stock, updated explicit availability requirement.
- `test/saved_plan_account_scope_test.dart`: saved generated meal identity, dates, participant IDs and repository publication.

The wider existing Stage 5 changes include meal/pantry grocery projections and purchase provenance, atomic meal status/replacement activity, saved-plan identity and nested listeners, profile/pantry awaited mutations, provider persistence, and account-scope tests. Existing earlier-stage edits are preserved. This is a large existing working tree, not a clean single-stage diff.

## Verification and limitations

**Executed:** full Flutter suite — 169 tests passed; Flutter analysis — no issues found. Final command results are recorded in `tests-latest.txt` and `analyze-latest.txt` alongside this report. Earlier runs had an obsolete pantry expectation and brace-style diagnostics; those were corrected, not hidden.

Tests use local logic and fake Firestore. They do not prove live provider reachability, deployed rules compatibility, real transaction contention or owner/member device synchronization. No live AI request was made. The reported device-specific network failure cannot be reproduced conclusively without a device/provider response; the concrete routing and error-classification defects above have been repaired locally.

The recorded Java 21 probe succeeds for IPv4 and IPv6 loopback sockets but fails Java NIO selector creation with `Unable to establish loopback connection`. Emulator security assertions have not executed successfully. C01/C02 remain unverified; no security-pass claim is made. No firewall changes or release-build workaround was applied. No release APK was built in this batch.

No Firestore rules changes were made in this targeted batch. Earlier local v2 rules and acceptance tests remain pending real emulator verification. Production rules may differ from the local v2 client; no client can legitimately bypass that mismatch. Production migration/deployment remains a separate approval.

## Prioritized continuation

1. Restore a functioning Java NIO selector/emulator environment without weakening system security, then run the complete security acceptance suite: role matrix, cross-household denial, invitation lifecycle, concurrent joins, removal/leave, ownership and field injection. Fix any actual rule failures locally before deployment consideration.
2. Add injectable household-repository stream tests covering delayed A→B→A callbacks, removal/rejoin and stream errors. Existing UID/epoch guards and service tests are useful but are not complete household end-to-end verification.
3. Run a controlled two-account/two-device acceptance session against an approved isolated Firebase environment; verify create/join, both-direction meal/pantry updates and recovery. Do not use production migration data.
4. Verify actual default Firebase AI/App Check/project model configuration and custom provider calls on a test device, including timeout/quota/safety failures. No generated response or key should be logged. Review remaining provider adapter error categories and fallback behavior.
5. Remove bundled secrets from distributable builds through an explicit configuration cleanup and rotate exposed credentials where applicable. Continue the separately documented secure-storage migration decision.
6. Verify generation UI failure recovery (including save failures and offline retry), duplicate-click protection, and plan listener timing on-device. Current persistence regression is repository-level, not a full widget/provider/network integration test.
7. Reconcile the entire functionality matrix after these targeted bugs are verified, and resume release APK verification only after the Java/build environment issue has a safe resolution.

**Production was not read for migration, modified, migrated or deployed. No paid services were enabled.**

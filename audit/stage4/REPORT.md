# Stage 4 — functionality reconciliation and safe local repairs

Date: 2026-10-06. This is a stable continuation checkpoint, **not completion of the full audit**. Earlier verified repairs were preserved. The user-supplied requirements are retained in `WHATMEAL_CONTEXT.md`; the shared conversation was only partially accessible, so it is not claimed as a fully reviewed source.

## Inventory

`WHATMEAL_FUNCTIONALITY.md` records 89 grouped behaviors: 11 IMPLEMENTED, 31 PARTIALLY IMPLEMENTED, 37 UNVERIFIED, 5 BROKEN, 4 MISSING, and 1 CONFLICTING. Eighteen groups carry an overlapping BLOCKED flag. These are requirement groups, not a total of independent bugs or security vulnerabilities. IMPLEMENTED applies only to the bounded behavior described in its evidence column.

## Repairs in this batch

### M06 — provider configuration synchronization and account isolation

Root cause: provider state did not consistently follow remote configuration, and asynchronous persistence could race account switches or newer edits. The repository now subscribes to the active UID's configuration, rejects stale session callbacks, serializes writes per session, ignores outdated echoes while writes are pending, and guards reconciliation reads against newer remote snapshots. Switching accounts starts an independent write queue. Removing custom credentials restores the default configuration through the existing persistence path.

The settings editor updates its endpoint on remote changes and clears stale secret input. Save/removal feedback waits for the persistence result. Failed writes report a safe failure rather than success. A Material ancestor fixes a switch rendering assertion without changing the design.

Limitations: these behaviors passed injected-stream and widget tests, not a live two-device Firestore exercise. Already dispatched old-account writes cannot be cancelled, though they retain their original UID. LlmService cache refill, terminal listener resubscription, pre-persistence provider notifications and unvalidated “Connected” status still require follow-up. API keys remain in their existing storage; no credential migration occurred.

### Pantry edit integrity

Root cause: changing category deleted and recreated the ingredient, while the editor reconstructed identity metadata and expiry. A failed second write could lose the ingredient; date reconstruction could shift expiration.

Category changes now await an update to the same ingredient. The edit result preserves ID, author, creation time, status and exact expiration. Date-picker limits include an existing expired date, preventing a picker assertion. Success is reported after completion and failures use a safe message. General add/delete feedback remains a separate open issue.

## Files changed in this batch

| File | Reason |
|---|---|
| `lib/features/ai_settings/data/ai_provider_repository.dart` | Injectable configuration stream/persistence, session guards, serialized writes and truthful outcomes |
| `lib/features/ai_settings/pages/ai_settings_page.dart` | Remote editor synchronization, awaited key save/removal, safe feedback and Material switch parent |
| `lib/features/pantry/pages/pantry_page.dart` | Await same-document category edit instead of delete/recreate |
| `lib/features/pantry/widgets/add_pantry_item_sheet.dart` | Preserve metadata and exact expiry; allow editing expired items |
| `test/ai_provider_sync_test.dart` | Seven repository and two widget regression tests |
| `test/pantry_edit_test.dart` | Two widget regressions for metadata and expired-date editing |
| `WHATMEAL_CONTEXT.md` | Preserve supplied requirements with balanced code fences |
| `WHATMEAL_FUNCTIONALITY.md` | Generated evidence/status inventory and continuation workflows |
| `audit/stage4/build_inventory.py`, `requirements.json` | Reproducible inventory with validated source-code paths |
| `audit/stage4/*.txt`, `REPORT.md` | Actual test/analysis outputs and this checkpoint |
| `README.md` | Link current checkpoints without rewriting historical Stage 1 results |

The working tree also contains earlier stages' changes. That full working-tree diff must not be mistaken for this batch alone. No commits were created and no prior work was reset.

## Verification actually executed

| Check | Result and scope |
|---|---|
| Full Flutter suite, no dependency resolution | **86 passed**, `tests.txt` |
| Provider focused suite | **9 passed**, `provider-tests.txt`; includes failure, delayed persistence, session switch and remote editor cases |
| Pantry focused suite | **2 passed**, `pantry-tests.txt` |
| Flutter analysis after final handler correction | **No issues found**, `analyze.txt` |
| Existing security suite JavaScript syntax | `node --check audit/stage3/security_acceptance.mjs` passed; executes no security assertions |
| Working-tree whitespace check | `git diff --check` passed; line-ending warnings only |
| Inventory generation | 89 rows generated; referenced code paths validated |

During development, widget tests exposed a genuine missing Material ancestor and a test-fixture asynchronous scheduling issue; both were corrected before the recorded successful runs. Full analysis then identified braces and context-lifetime findings in the save handler; both were corrected. The full 86-test pass preceded that final small handler correction; the focused provider rerun is recorded separately in `provider-tests-final.txt`.

## Security and build status

**C01/C02 remain OPEN/UNVERIFIED.** The existing 60-case Stage 3 acceptance suite still needs actual execution against Firestore Emulator rules. This batch adds provider/pantry tests, not new security acceptance assertions. The prior Java selector/loopback startup failure prevented rule compilation and execution; this stage did not rerun the blocked emulator or claim a pass from mocks or syntax checks. See `audit/stage3/README.md` and its logs for the existing matrix and blocker.

No Firestore rules, indexes, Firebase configuration or database schema were changed in this batch. The approved local v2 rules from Stage 3 remain local. H07/H08/M10 architecture is implemented locally but cannot be certified while rules tests are blocked. No security permission was weakened to make a functional test pass.

Android release build was not attempted again: the earlier Gradle loopback failure has no newly identified safe remedy. No firewall, security software, system networking or unrelated Gradle configuration was changed. iOS verification is unavailable on this Windows host; web and device release readiness remain unverified.

**Production was not read for migration, modified, migrated, or deployed to. No backend deployment, Cloud Functions, paid service, or billing change occurred.** No live provider calls or production app launches were used for these tests.

## Open findings and prioritized continuation

1. **Critical release gate:** execute the full existing emulator suite on a host with functioning Java networking. Include owner/admin/member/viewOnly/outsider/anonymous, invitation reuse/expiry/revocation, concurrent join, escalation, ownership, leave/removal, cross-household and field injection. Fix any rules failures locally before closing C01/C02.
2. **High account/data integrity:** guard all saved-plan post-await mutations and notifications with captured UID/family/session; use scope-aware merged identities. Test delayed A→B→A callbacks and duplicate document IDs. Review the Auth callback and LlmService cache gaps.
3. **Plan lifecycle:** retain saved-plan identity when viewing/editing, add repeated-save protection, persist participant IDs rather than names, and pass complete preferences into replacement. Grocery cleanup needs exact provenance; do not delete based on ambiguous titles.
4. **Confirmed functional defects:** distinguish needed groceries from available pantry ingredients; date-filter today's recommendations; implement grocery editing; await remaining mutation handlers and report duplicate no-ops truthfully. Remove fabricated manual nutrition and validate blank slots.
5. **Notifications:** implement history/foreground tap routing and queued cold-start readiness; preserve useful event text; use stable operation IDs and define domain-write/event-failure recovery. Background delivery requires a separately approved sender design.
6. **Security hygiene:** complete raw exception/secret redaction, tighten any schema gaps revealed by emulator execution, and test active-listener revocation plus platform cache isolation. Do not infer security from fake-store tests.
7. **Product decisions:** reconcile blank/unset cuisine with current Any behavior; decide exact associated grocery/notification retention. Secure OS credential storage requires an explicit migration decision: device-local vaults improve local secret protection but do not automatically preserve cross-device configuration/key availability; web has different protection constraints. No breaking migration is authorized by this checkpoint.
8. **Release verification:** two-account/two-device owner and invited-member workflows, view-only paths, offline/reconnect, provider network failures, platform notifications, visual/accessibility checks, then a safely diagnosed Android release build.

Production migration rehearsal, minimum-client cutover, deployment, destructive cleanup, paid services and breaking credential migration remain separate future approvals. Continue with safe local repairs without waiting for those approvals where dependencies permit.

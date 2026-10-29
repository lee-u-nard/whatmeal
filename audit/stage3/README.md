# Stage 3 — local membership/security implementation

The user approved local implementation of the Stage 2 security proposal on
2026-10-05. Production migration, production reads for migration, deployment,
Cloud Functions, paid services and security weakening remain prohibited.

**C01/C02 remain OPEN / UNVERIFIED.** The Firestore Emulator fails at Java NIO
selector startup. The new rules have not compiled/evaluated successfully in the
emulator, and no security acceptance assertion has executed. Do not deploy them.

## Implemented locally

- Canonical `families/{id}/members/{uid}` plus `membershipIndex/{uid}`. Creator,
  membership identity and join provenance cannot be changed by ordinary edits.
  Legacy `memberUids`, private `users.familyId`, and short invite-code queries no
  longer authorize access. Unknown shared collections have no grant.
- Household creation writes the household, owner membership and index together.
  Membership/index create/delete rules require matching atomic changes; a direct
  index or membership write is not sufficient. One index per UID prevents a user
  joining two households through compliant atomic writes.
- 192-bit secure random, case-sensitive invitation tokens. Single-use redemption
  writes invitation consumption, membership and index atomically. Default expiry
  48 hours, server-rule maximum 7 days; optional recipient UID binding. Issuer's
  current authority is rechecked at redemption. Collection enumeration is denied.
- Manager-only invitation references support revocation after an app restart.
  Tokens are not stored in family documents, shared activity or log messages.
  The explicit create/copy action is restricted to managers in the existing UI.
- Owner/admin/member/viewOnly permissions replace overlapping recursive grants.
  Owners can appoint admins; admins can manage member/viewOnly roles only.
  Self-role changes, active last-owner departure, direct owner reassignment and
  creator changes are denied by the proposed local rules.
- Ownership transfer requires an owner offer and acceptance by the target member;
  ownership and both role records change atomically, and the offer is consumed.
- Removal and departure delete the member/index pair, without writing another
  user's private tree. Household deletion is now explicitly labelled archival;
  data is retained. Shared access stops, members may leave, and an owner retaining
  membership may restore the household. Hard-delete is denied. If the owner also
  leaves an archive, ordinary-client restoration is no longer possible; data
  remains retained for a separately approved recovery/purge process.
- Shared activity replaces private-notification fan-out. Events have authenticated
  actor IDs and bounded allowlisted fields; arbitrary body/provider/token payloads
  are not accepted. Private read receipts control each user's badges. The feed
  waits for receipts before displaying unread state, filters pre-join events,
  limits activity to 50 records and detaches on scope changes. Existing private
  notifications are merged without migrating them. There is no new background
  push sender or claim of reliable remote push.
- Client listener callbacks are guarded against old account/household generations;
  inaccessible shared data is cleared. The obsolete app-level legacy-pointer
  listener was removed. The new local demo mode uses a demo Firebase project.

## Files changed in this stage

| File | Purpose |
|---|---|
| `firestore.rules` | Local v2 authority model, invitation/member/index coupling, role matrix, archival and transfer rules, explicit collection/schema validation |
| `lib/core/services/family_service.dart` | Injectable atomic v2 create/join/remove/leave, invitation issuance/revocation, archive/restore and ownership transfer |
| `lib/features/family/data/family_repository.dart` | Index discovery, canonical member streams, cutover notice, access-revocation clearing, guarded asynchronous operations |
| `lib/core/models/family.dart` | Read schemaVersion/state/ownerUid; ownership uses ownerUid for v2; serialize v2 without legacy membership arrays or invite codes |
| `lib/features/family/models/family_space.dart` | Membership joinedAt used for notification eligibility |
| `lib/features/family/pages/family_space_page.dart` | Token creation/revocation management, role restrictions, ownership consent, truthful archive/restore/departure controls and result messages |
| `lib/core/services/household_activity_store.dart` | Shared event publishing, optional idempotency key, private receipts and bounded combined stream |
| `lib/core/services/notification_service.dart` | Replace cross-user writes with shared activity, merge feeds, route read updates to receipts, clear account state |
| `lib/core/services/household_notification_service.dart` | Avoid asynchronous actor lookup before choosing destination scope |
| `lib/features/pantry/data/pantry_repository.dart` | Scope guards and clear inaccessible pantry state |
| `lib/features/profile/data/family_member_repository.dart` | Scope guards and clear inaccessible dietary profile state |
| `lib/features/meal_plan/data/meal_plan_repository.dart` | Ignore obsolete listener callbacks and clear denied plan feeds |
| `lib/app.dart` | Remove unused legacy household-pointer listener; preserve router disposal |
| `lib/main.dart` | Explicit demo/emulator mode; production App Check path unchanged outside this mode |
| `firebase.audit.json` | Local Auth emulator configuration alongside local Firestore |
| `test/family_service_v2_test.dart` | Seven client-store tests |
| `test/household_activity_store_test.dart` | Two shared-feed/receipt tests |
| `audit/stage3/security_acceptance.mjs` | 60 real-emulator acceptance cases, loopback/demo-only guard |
| `audit/stage3/*` | Evidence, pre-change rules backup, this report and release gates |

No dependency upgrade, production Firebase configuration edit, logo/color change,
database migration or deployment was made in this stage. Stage 1/2 edits already
present in the working tree were preserved. No Git reset or commit was performed.

## Validation and actual results

- **9 new fake-Firestore client tests passed:** canonical bootstrap, single-household
  client guard, token format and legacy rejection, single-use join/reuse, expiry
  and revocation client checks, private-account preservation, archival data
  retention, ownership acceptance, shared-event retry behavior and receipt scope.
- **Complete Flutter suite: 75 passed** in the recorded run, including existing
  regressions. The final verification output is `tests.txt`.
- After the final v2 model serialization change, **13 focused family/model tests
  passed** (`model-regression.txt`).
- **Final Flutter static analysis: no issues found** (`analyze.txt`). Earlier
  brace-style findings were repaired without suppressions.
- **Git diff whitespace check passed** (`diff-check.txt`). The production
  `firebase.json` configuration remains unchanged; hashes are recorded in
  `file-hashes.json`.
- Node syntax check passed; `--list` enumerated **60 acceptance cases** without
  contacting any service. This is not an executed security test result.
- Emulator attempt using Java 21 and `demo-whatmeal-audit`: **startup failed** with
  `Unable to establish loopback connection`, caused by
  `UnixDomainSockets.connect: Invalid argument: connect`. Logs:
  `emulator-attempt.txt` and `firestore-startup-failure.txt`. **Zero acceptance cases
  executed.** No rule compilation success is claimed.
- No full device UI, live Firebase, live AI, cross-device/offline, APK or iOS
  verification occurred. No firewall, antivirus, Java installation or unrelated
  Gradle settings were changed to work around the blocker.

## Acceptance coverage prepared

See `acceptance-cases.txt`: all six identities (owner/admin/member/viewOnly/
outsider/unauthenticated), shared reads/writes, non-listable household/invitations,
legacy-pointer rejection, atomic bootstrap, self-join, standalone index attacks,
invitation issue/redeem/revoke/expire/recipient binding/reuse, issuer demotion,
concurrent redeemers, simultaneous cross-household joins, join-versus-revoke,
role escalation, creator/owner edits, accepted and incomplete ownership transfer,
removal/leave pairing and last-owner protection, archive/restore, cross-household
and private-secret denial, field/type/nested schema injection, event impersonation,
private receipts and reciprocal meal replacement links.

The suite uses REST atomic commits against the actual emulator rules with mock
authenticated identities; admin bypass is confined to isolated fixture seeding.
It does not substitute for real Flutter transaction retry/device integration tests.
Any failing expectation must remain a failure; do not change assertions to accept
unauthorized behavior.

## Cutover and remaining release gates

1. Get a working emulator execution environment without weakening security, then
   run the full suite and fix all rule compiler/runtime, access-call budget and
   concurrency failures. C01/C02 cannot be marked fixed before this succeeds.
2. Add boundary fixtures for maximum recipe/list sizes and transaction access-call
   budgets. Rules validate list elements through bounded short-circuit checks;
   large lists/atomic writes may reach evaluation limits. Large grocery batches
   also require budget testing. No capacity guarantee is claimed yet.
3. Reconcile schema compatibility against approved migration fixtures, not live
   records. Legacy malformed/extra fields, legacy string ingredient forms and
   stale/orphan member/index pairs may require explicit migration shaping. No
   legacy bypass was introduced. Invalid authoritative records require approved
   repair rather than client self-promotion or permission broadening.
4. Test the actual Flutter client against Auth+Firestore emulators: owner/invitee
   flows, UI confirmations, account A→B→A, revoked listeners, badge receipts,
   offline/reconnect, failed writes and ownership races. Fake tests do not prove
   real rule compatibility or transaction isolation.
5. Activity is an in-app informational feed, not a trusted server audit trail.
   Event writes are generally separate from domain writes; failures can omit an
   event without undoing the successful domain operation. Only callers supplying
   stable operation IDs get cross-invocation idempotency. Extend atomic domain+
   event integration before requiring guaranteed delivery. No claim of background
   FCM delivery is made.
6. Receipt history is currently subscribed per account; scale/retention needs a
   separate bounded strategy before large histories. Firestore offline cache can
   contain previously authorized data; server revocation cannot remotely erase
   it. Verify logout/cache behavior on actual platforms.
7. Archival has no automatic purge or guaranteed retention deadline. Restore is
   available while the owner retains membership; a retention/purge/recovery policy
   and production data recovery require separate approval.
8. Only after local validation should a reviewed migration dry-run and coordinated
   minimum-client cutover be proposed. **Production reads for migration, migration
   writes and deployment remain separately unapproved.** Do not deploy the new
   rules against existing records or ship the new client against legacy rules.

## Local-only reproduction

From the repository root on a working host:

```powershell
$env:JAVA_HOME = 'C:/Program Files/Android/Android Studio/jbr'
$env:PATH = "$env:JAVA_HOME/bin;$env:PATH"
firebase emulators:exec --only firestore --project demo-whatmeal-audit --config firebase.audit.json 'node audit/stage3/security_acceptance.mjs'
```

For later manual Flutter testing, start only Auth+Firestore with the same demo
project/config, then launch with `--dart-define=WHATMEAL_EMULATORS=true`.
Default host is 127.0.0.1; Android emulators need
`--dart-define=WHATMEAL_EMULATOR_HOST=10.0.2.2`. The local flag selects demo Firebase
options and skips App Check/FCM initialization; it does not relax Firestore rules.
Do not launch without that flag as an audit test: normal mode retains the existing
project configuration. No app was launched against production during this work.

The previous local rules are saved as `firestore.before.rules` for review, not
deployment. Rollback must never restore vulnerable rules to production. All
changes here are local source/test/document edits; there is no database rollback
to perform because no production or migration data was modified.

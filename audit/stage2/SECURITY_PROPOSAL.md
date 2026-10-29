# Coordinated membership and invitation proposal — approval required

Status: design only. No local or deployed rules have been changed. No production
records were read or migrated in Stage 2. C01/C02 remain release blockers.
H07/H08 and enforcement of M10 depend on this change. This proposal uses client
transactions and Firestore rules; no Cloud Functions, paid service or trusted
server is required for the proposed in-app behavior.

## 1. Canonical data and compatibility

Keep existing `families/{familyId}` IDs and shared collection paths. Introduce
`schemaVersion: 2`, immutable `createdBy`, `ownerUid`, `state: active|archived`,
`createdAt`, `updatedAt`, and the existing editable household name. The exact
metadata allowlist must be inventoried against existing records before rollout.
Remove invitation secrets from the household document. Do not derive authority
from the client-controlled `users/{uid}.familyId` or legacy `memberUids` array.

Canonical authority: `families/{familyId}/members/{uid}` with exactly `uid`, `role`
(`owner|admin|member|viewOnly`), `joinedAt`, `invitedBy`, `invitationId` and bounded
display fields (`name`, optional `avatarUrl`). Membership is distinct from family
dietary/dependent profiles: a child profile is not an authenticated member.
Exactly one owner must match `ownerUid`. Identity and join provenance are immutable.

Discovery: `membershipIndex/{uid}` with exactly `uid`, `familyId`, `joinedAt`.
It supports the current one-household-per-account behavior and is readable only
by that UID. It is a navigation index, never sufficient authority. Its create and
delete permissions are narrowly coupled to the matching membership change in
the same atomic operation. A manager may delete this projection for a removed
member only when the previous family matches and the canonical membership is
also removed. This gives no access to the user's private document or secrets.
An existing index prevents concurrent joins into two different households.

Legacy `users.familyId` can remain as non-authoritative compatibility data while
the new client transitions. Clients must resolve membership before attaching
shared listeners and clear caches on denied/revoked access. Legacy clients cannot
remain fully write-compatible with secure invitation rules: a minimum client
version and a coordinated rollout are necessary, not a permissive legacy bypass.

## 2. Invitation capability and atomic redemption

Use a cryptographically random 192-bit token (24 secure random bytes, base64url).
The token is the document ID of `householdInvitations/{token}`. Do not use a short
guessable code, family-ID lookup, public collection query, log, or notification
body containing the token. Share through an explicit copy/share action. The
token is a bearer capability; anyone it is forwarded to may redeem it unless
the optional recipient UID binding is supplied.

Invitation fields: `familyId`, `issuedBy`, `role`, `createdAt`, `expiresAt`,
`state: pending|redeemed|revoked`, optional `recipientUid`, and `redeemedBy`,
`redeemedAt` initially null. Default expiry: 48 hours; maximum: 7 days. Single use.
Only owner/admin may issue. Admin may issue member/viewOnly invitations; only
owner may issue admin invitations. Owner invitations are forbidden.

Allow authenticated exact-document get for a valid pending token (or its issuer/
authorized manager for management); deny collection list to everyone. Response
contains minimal metadata, no member roster or private household data. A separate
`families/{id}/invitationRefs/{token}` management list, restricted to owner/admin,
supports listing/revocation. It contains token and expiry, so it is explicitly
not readable by ordinary members. Issuance writes both documents atomically.

Joining transaction reads the invitation and the caller's membership index.
It does not need to read the protected household before membership exists.
It atomically marks the invitation redeemed, creates the caller's membership
with the exact invited role, and creates their index. Rules use before/after
state checks to require all three changes, the caller UID, matching family and
token, an active household, current issuing-manager authority, an unexpired
pending invitation, and server `request.time`. Direct membership writes without
this proof are rejected. Initial household creation is a separate atomic path:
new household + creator owner membership + creator index.

Transactions resolve two redeemers of one token and simultaneous joins by one
UID; only one can commit. Do not increment/update a shared member array on every
join. Rules must validate the reverse direction too: invitation consumption
requires the corresponding member/index after-state, and membership creation
requires consumption. Validate the rules access-call budget with emulator tests.

Revocation is a manager-only pending-to-revoked transition. Role, destination,
issuer, and expiry cannot be edited after issuance. Reissuing makes a new token.
Expiry uses server time, so clock changes do not extend validity. Do not depend
on TTL deletion (or paid cleanup) for security. Consumed/revoked documents remain
as bounded audit history until an explicit retention policy is approved.

## 3. Permissions and field validation (C02/M10)

| Operation | Owner | Admin | Member | View only | Outsider |
|---|---|---|---|---|---|
| Read active household, roster, shared data | Yes | Yes | Yes | Yes | No |
| Edit pantry, groceries, meals, dietary profiles | Yes | Yes | Yes | No | No |
| Edit household name | Yes | Yes | No | No | No |
| Invite/remove member or viewer | Yes | Yes | No | No | No |
| Appoint/remove admin | Yes | No | No | No | No |
| Change own role | No | No | No | No | No |
| Transfer ownership/archive | Yes | No | No | No | No |
| Leave | After transfer/archive | Yes | Yes | Yes | N/A |
| Write private account settings/keys | Own UID only for every role |

Explicit collection rules replace recursive shared read/write grants. A narrow
rule is ineffective while a broader overlapping allow grants the same write.
Unknown collections/fields are denied by default. Separate create, update and
delete validation; updates preserve immutable fields using changed-field lists.
Validate field types, role/status enums, bounded strings/lists, timestamps and
reference identity. Meal fields include the existing optional recipe/nutrition
fields; do not reject legitimate null/legacy values without migration fixtures.
Validate replacement links and slot invariants atomically. Grocery statuses and
normalized identities need tests including legacy random IDs. No arbitrary role,
ownership, counter or invitation fields may be smuggled through a profile edit.

Client quota reservations remain cooperative: the current owner-writable usage
counter and client clock are not anti-abuse enforcement. Server-time quota rules
and how to bind actual AI dispatch to reservation are separate limitations; do
not claim trusted provider billing protection on this Spark/client-only design.

## 4. Departure, removal and deletion (H07)

Non-owner departure atomically deletes own canonical membership and index.
Owner/admin removal deletes the target membership and matching index; admin may
only remove member/viewOnly. No writes to another user's private `users` tree.
Owner departure requires an explicit ownership transfer accepted by an existing
member, atomically changing ownerUid and both role documents, or archival.
Prevent zero/two owners, self-promotion and concurrent transfer/removal races.

Proposed household deletion behavior is archival, requiring product approval:
owner changes `state` to archived, immediately disabling shared writes and normal
member access. Preserve nested data. Members may remove their own now-stale index
and membership; archived membership must never authorize shared reads. An owner
can inspect narrowly scoped archive metadata and restore it during an approved
retention window. Do not show 'permanently deleted' when data is retained.
Full recursive purge is a separate, approved, resumable cleanup tool with dry run,
backup, pagination and audit log. No nonexistent Function cascade is assumed.

All household consumers must handle permission-denied, clear old household UI
and stop listeners immediately. Offline cached data previously received cannot
be remotely erased by Firestore rules; logout/cache policy needs explicit tests.

## 5. Shared activity and notification receipts (H08)

Write once to `families/{id}/activity/{eventId}` with allowlisted event type,
actorUid, server timestamp, affected record IDs and a minimal safe summary.
Actor must equal the authenticated UID and have permission for the action.
Use a stable operation/event ID so retries do not duplicate activity. Where
feasible, couple the event to its domain write; never allow arbitrary impersonated
system events. A notification failure must not report the already committed
domain operation as failed and encourage duplicate actions.

Household members subscribe to this feed. Per-user read/dismiss receipts remain
at `users/{uid}/notificationReceipts/{eventId}` with owner-only writes and no
secret payload. Badges derive from visible events and receipts; consider a
bounded feed and joinedAt eligibility so newly joined users do not receive all
historical badges. On departure, detach the feed and clear badge state.
Old private notifications remain readable by their owner and can be merged with
stable deduplication; no mass migration is required.

This delivers in-app real-time activity and optional foreground local alerts.
It does NOT provide reliable remote background push on Spark by itself. FCM
server credentials must never be placed in the app. Background push remains
explicitly unavailable until a separately approved trusted sender exists.

## 6. Migration and rollback

1. Before any production action, approve design and implement fixtures, rules,
   client changes and migration dry-run locally. Keep migration/deployment as
   separate explicit approvals.
2. Approved read-only inventory/export: household sizes, owner evidence, duplicate
   memberships, orphan member docs, invalid roles, pointers, invite codes and
   all field shapes. Existing membership is not trustworthy merely because the
   old rules allowed it. Resolve suspicious/ambiguous ownership with the user;
   never auto-promote a claimed creator from compromised data.
3. Produce per-household proposed mappings and backups. Preserve household IDs,
   meals, groceries and dietary profiles. Backfill canonical verified membership
   and index documents with idempotent checkpoints; quarantine conflicts for
   manual review. Revoke legacy short codes; issue new tokens on demand.
4. Test upgraded client and emulator rules together, including legacy fixtures.
   Arrange a controlled maintenance/write-freeze window and minimum client
   version. No transition period permitting the old self-join path.
5. Separately approve production migration/deployment. Monitor permission errors,
   reads/quota and member reconciliation, with a restoration rehearsal first.

Rollback must not restore the vulnerable rules. Retain a tested restrictive
maintenance ruleset and last secure client, plus exported data and operation
checkpoints. Stop writes, reconcile any post-cutover records, then restore the
reviewed backup selectively under explicit approval. Rolling back only the app
against new rules is unsafe operationally; old clients will lose functionality.
Risk areas: unauthorized legacy members, incompatible clients, multi-household
conflicts, listener read volume, orphan nested records, interrupted migration,
and divergence between canonical membership and discovery index.

## 7. Required emulator acceptance suite before deployment

- Owner/admin/member/viewOnly/outsider/unauthenticated across every collection,
  direct get, list/query, create/update/delete and nested path.
- Enumeration of families/invitations, guessed tokens, wrong recipient, expired,
  revoked, consumed and malformed invitations; issuer demoted/removed before join.
- Self-add, role escalation, creator change, unknown field injection, broad-rule
  overlap, batch/transaction bypass and direct index creation/deletion.
- Two redeemers, one user joining two families, join versus revoke/archive, leave
  versus edit, owner transfer versus removal; assert exactly one valid outcome.
- Atomic member/index pairing, admin cannot manage owner/admin, last-owner safety,
  index recovery after removal/archive and rejoin requires a fresh invitation.
- Event impersonation, cross-household reads, receipt privacy, duplicate retries,
  badges/account switch and listener cleanup after revocation.
- Legacy data fixtures and every migration failure/restart/rollback checkpoint;
  rules access-call limits, large households and bounded document sizes.
- Actual contention for replacement/quota/grocery transactions, permission/network
  failures with no partial records, and nested stream offline/reconnect behavior.

The Stage 2 emulator probe uses unchanged rules and is deliberately expected to
fail security assertions for C01/C02. It could not execute because Java selector
startup failed. Fakes do not establish any authorization/concurrency guarantee.

References: [atomic writes and getAfter](https://firebase.google.com/docs/firestore/manage-data/transactions),
[overlapping rules and limits](https://firebase.google.com/docs/rules/rules-behavior),
[isolated emulator projects](https://firebase.google.com/docs/emulator-suite/connect_firestore).

Approval requested: approve this design for LOCAL implementation and emulator
verification only, including single-use invitation behavior, canonical membership
and discovery index, role matrix, legacy-client cutover, shared in-app activity,
and archival semantics. Production migration/deployment remain unapproved.

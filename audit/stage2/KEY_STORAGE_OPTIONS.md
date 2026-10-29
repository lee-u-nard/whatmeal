# M05 — storage decision, no migration implemented

Current source: `SecureKeyStore` is a UID-indexed memory cache. The durable copy
is plaintext at the application layer in owner-only Firestore
`users/{uid}/secrets/llmConfig`. It is not OS-backed secure storage. Firestore
transport/service encryption does not prevent an authorized client, compromised
session, project administrator or local persistent cache from accessing it.
The existing comment attributing secure-storage incompatibility to spaces in a
Windows username is not established by a reproducible test in this audit.

| Option | Benefits | Trade-offs |
|---|---|---|
| Keep current cloud credentials, tighten rules and disclosure | Existing cross-device behavior preserved | Cloud account/admin access and persistent-cache exposure remain; logout of the memory cache alone is insufficient |
| Device-only OS-backed credentials; sync provider/model/endpoint separately | Smaller cloud exposure; uses native secure storage | Each device must import its key; must define logout, reinstall, backup/restore, locked-device and unavailable-store behavior |
| End-to-end encrypted cloud credential sync | Cross-device convenience without a cloud plaintext copy | Recovery/key transfer and lost-device revocation are substantial new architecture; do not invent custom cryptography |
| Trusted server proxy | Client need not receive provider credentials | Hosting, abuse controls and operational/billing implications; outside the approved Spark-only work |

Recommendation for approval: prototype device-only storage on Android/iOS first,
with account+provider namespacing and separate nonsecret settings sync. Do not
silently fall back to plaintext if the secure store is unavailable. Web storage
requires a separate threat model: JavaScript running in the origin can access
credentials even if bytes at rest are encrypted. A memory-only web option loses
keys on refresh but reduces persistence. This changes product behavior and needs
approval before implementation.

Migration must be opt-in and restart-safe: read legacy credential only for the
signed-in user, write secure store, read back and verify without logging, persist
migration marker, then separately confirm cloud deletion policy and other-device
effects. Do not auto-delete the only working copy or change a user's selected
provider on storage failure. Old clients must be prevented from re-uploading
plaintext. Plan for Firestore's old local cache, backup copies, account switching,
provider removal and reinstall. Test native read/write/delete failures and device
restore before considering the migration safe.

No package was installed for secure storage and no credential data was moved.
The package documentation describes platform-specific encryption, minimum OS
requirements and backup considerations; selecting a compatible version and
native build verification are still required. See
[flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage).
Firestore's documented cache behavior must be evaluated separately from the
memory cache: [offline persistence](https://firebase.google.com/docs/firestore/manage-data/enable-offline).

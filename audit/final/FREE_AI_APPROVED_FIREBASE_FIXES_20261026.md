# Approved built-in Gemini Firebase correction — October 26, 2026

**Current owner boundary:** phone access is revoked. Do not run ADB, install/launch apps, switch users, change phone settings or perform any other phone operation. Work is limited to the specific Free Gemini error in local code and existing approved Firebase corrections. Earlier phone-testing steps below are historical/pending descriptions, not current authorization. Live phone verification remains unperformed and requires separate explicit authorization if ever resumed.

The owner explicitly approved the three configuration corrections in `whatmeal-101` (321735824503), while retaining App Check enforcement, disabled billing and existing data. These changes supersede only the pending-approval status of the earlier read-only preflight.

## Applied and read back

1. Enabled only `playintegrity.googleapis.com`. The other three inspected AI/App Check APIs were already enabled and remained enabled.
2. Registered the existing APK's public SHA-256 signing certificate on Android app `1:321735824503:android:9a4bf975671f2b46e42272` / `com.example.whatmeal`: `371ccb837f5379cc570eee0808710d3ca1cc36cbabef112e0a3d7960274b25bb`. No signing key was changed or generated.
3. Patched only `appIntegrity.allowUnrecognizedVersion=true` and `deviceIntegrity.minDeviceRecognitionLevel=MEETS_DEVICE_INTEGRITY`. The latter is the official REST enum for the approved device-integrity requirement; `DEVICE_INTEGRITY` is not the accepted REST value. Token TTL (`3600s`), licensing requirement (false) and other provider fields were preserved.

Firebase AI Logic (`firebaseml.googleapis.com`) App Check **enforcement and replay protection remain ENFORCED**. Every other observed service policy was preserved exactly; Auth/Firestore were already UNENFORCED and were not changed. Billing readback remains **disabled**. No rules, billing setting, App Check debug registration, API key, production user record, private backup or original account was modified. No Firebase deployment or GitHub operation occurred.

References: [off-Play distribution guidance](https://firebase.google.com/docs/app-check/android/play-integrity-provider), [Play Integrity configuration and enums](https://firebase.google.com/docs/reference/appcheck/rest/v1/projects.apps.playIntegrityConfig), [narrow PATCH](https://firebase.google.com/docs/reference/appcheck/rest/v1/projects.apps.playIntegrityConfig/patch), [App Check service IDs](https://firebase.google.com/docs/reference/appcheck/rest/v1/projects.services).

## Actual verification

Private/sanitized before and after receipts are preserved separately under ignored `build/free-ai-config-20261026-a77f4b/`.

- `node snapshot.cjs before`: exit 0; metadata only, no user-record reads.
- `node apply-approved.cjs enable-integrity`: exit 0; service readback ENABLED.
- Firebase connector `firebase_create_android_sha`: succeeded for the exact approved app/certificate.
- `node apply-approved.cjs configure-integrity`: exit 0; narrow policy PATCH.
- `node snapshot.cjs after`: exit 0.
- `node verify-readback.cjs`: exit 0; **9 configuration assertions passed**, including unchanged enforcement/replay policy, disabled billing, preserved unrelated provider fields, and only the intended API/certificate additions. These are live configuration readback assertions, **not meal-generation tests**.
- APK public signer verified with `apksigner`; SHA-256 rechecked. Phone-installed APK copied without reading account data and its hash matched the delivered APK exactly. No rebuild or app update was necessary.
- Existing local Firestore rules hash remains `DB759E4941F8B9C06B097FB7C4FE9F148F7C2ADCBB52DA6AAC9B4ED9E5F7BE77`.
- At the configuration-only checkpoint, Flutter source was unchanged. The subsequent client fix and its actual test/build results are recorded below; earlier 91 + 2 + 1 results remain historical evidence.

## Initial phone attempt — preserved evidence

An Android 11 TECNO LE6h was connected and authorized. It supports four Android users. Original user was 0. To preserve its signed-in account/cache, created ephemeral **WhatMealAITest**, ID 10, installed the already-present package for that user with `install-existing`, and switched only to that user. No original app data was cleared and no global APK replacement occurred.

USB authorization was lost on switching to the new Android user. Subsequent commands were rejected as `device unauthorized`; no app launch/account operation succeeded there. After owner-user approval resumed, a guarded command confirmed user 0 and stopped without opening the original account. User 10 was no longer listed. No user-removal command was issued. The later regular test-user attempt and correct authorization requirement are recorded below.

At this initial checkpoint no disposable account or inference request had been created. The later fixture creation below supersedes only the account-creation status. **Live Gemini Test Connection and meal generation remain NOT EXECUTED.** No generation quota reservation or inference request was sent. No fallback key, mock result or security bypass was used.

The previously installed APK is preserved:

`build/phone-release/20261026-free-ai-5a8b9a94/WhatMeal-release.apk`

59,337,041 bytes; package `com.example.whatmeal`; `production` release variant; Firebase project `whatmeal-101`; existing tester signer.

SHA-256: `AB3D251E9DC0C3021736A0E499F373235776778BD803B21F466996F4ECC86B56`.

## Additional client replay-protection incompatibility — fixed locally

Source inspection found a further confirmed compatibility issue: pinned `firebase_ai 2.3.0` calls `FirebaseAppCheck.getToken()` in its actual SDK header callback, which supplies a reusable session token. The observed server policy has replay protection ENFORCED. [Official Firebase AI guidance](https://firebase.google.com/docs/ai-logic/app-check#replay-protection) requires fresh limited-use tokens and rejects session tokens under that policy. This is a source/configuration incompatibility; no live request was made to reproduce the server response.

Small app-local repair, with no SDK/dependency upgrade or security-policy change:

- `lib/core/services/ai/firebase_ai_app_check.dart`: forward the existing App Check interface, routing only AI's `getToken()` requests to the existing native `getLimitedUseToken()` API. No token cache, session-token fallback, debug-provider activation or credential substitution.
- `lib/core/services/ai/adapters/gemini_adapter.dart`: use that delegate for both built-in Test Connection and generation/replacement. BYOK REST and other Firebase services retain their existing paths.
- `test/firebase_ai_app_check_test.dart`: six regressions, including the pinned SDK's actual header callback, fresh/concurrent tokens, errors/recovery, no fallback and unchanged non-AI behavior. Tokens/providers are synthetic; these are not native-attestation/live-provider tests.

Final focused command (exit 0, **97 passed**, 29 seconds):

```text
flutter test --no-pub --concurrency=1 test/firebase_ai_app_check_test.dart test/ai_settings_recovery_test.dart test/ai_generation_routing_test.dart test/live_ai_policy_test.dart test/generation_failure_test.dart test/generated_plan_persistence_test.dart test/gemini_custom_protocol_test.dart test/ai_quota_store_test.dart test/ai_provider_sync_test.dart --reporter expanded
flutter analyze --no-pub
```

Analysis: exit 0, no issues (67.6 seconds). No full-suite or security-suite rerun was performed for this isolated token-handling change; no authorization/rules logic changed.

Failure evidence preserved: first run failed a new test-fixture stream-identity assertion and was interrupted; the fake now holds a stable stream reference while preserving its forwarding assertion. The second run hit **OS error 112: C: disk full** and was interrupted. Neither is counted as a completed/pass run. Kept `focused.txt`, `focused-final.txt` and their status notes; the completed passing run is `focused-after-space.txt`. Cleared only regenerable non-APK intermediates under the exact resolved `build/fa-5a8b9a94/source/build/app/intermediates` and `build/app/intermediates` scopes, freeing approximately 7.93 GiB. Source snapshots, reports, all APKs, original app data and private backups were preserved. The previous APK hash was rechecked unchanged.

## Updated APK — built and verified, installation blocked

Built serially from a separate source snapshot using the existing tester signer and process-only build settings, unchanged locked dependencies:

```text
flutter pub get --offline --enforce-lockfile
flutter build apk --release --flavor production
```

Both exit 0. Build took 226.6 seconds. `apksigner verify --print-certs` passed and the certificate matches the newly registered public hash. `apkanalyzer manifest application-id` returned `com.example.whatmeal`; `apkanalyzer resources value --config default --type string --name project_id` returned `whatmeal-101`.

```text
APK: build/phone-release/20261026-free-ai-replay-a77f4b/WhatMeal-release.apk
Bytes: 59,337,041
SHA-256: 9362618D35992CD429B8BC13A87CBA46337018729B4C2E3A75D05577BC33538C
Variant: productionRelease, online Firebase, existing tester signer
```

Only one new synthetic admin-preverified Auth account was created successfully through `accounts:signUp`, explicitly scoped to `whatmeal-101`, with a random UID/email under `@example.test`. No original Auth accounts were listed/read/updated and no passwords were printed. Credentials remain only in ignored `build/free-ai-config-20261026-a77f4b/disposable-account-private.json`. Registration/email-delivery behavior is not being claimed verified.

A regular temporary Android user **WhatMealAITest**, ID **11**, was subsequently created and the existing package made available through `install-existing`. No original user was removed, no app data was cleared, no original account was opened or signed out. Entering user 11 again made ADB unauthorized. The final guarded installation command stopped before installation; **the new APK is not installed or runtime-verified**.

Android 11's [ADB confirmation implementation](https://android.googlesource.com/platform/frameworks/base/+/refs/tags/android-11.0.0_r1/services/core/java/com/android/server/adb/AdbDebuggingManager.java) routes non-admin users to an informational/denying dialog. Normal persistent trust must be approved in the primary user with “Always allow from this computer”; a new authorization cannot be granted inside the ordinary secondary user. This explains the permission obstacle; whether TECNO will retain primary-user trust across switching remains unverified. No restriction, admin role, trust key or setup flag was altered to bypass it.

Remaining action: return to original Android user 0, approve normal persistent USB trust if the owner trusts this PC, then install the new same-signature APK using `adb install --user 11 -r <APK>` and launch only in test user 11. Complete ordinary setup in that user, sign in with the disposable fixture, perform one connection check and one bounded one-day generation. If the device still revokes trust on switching, use ordinary phone controls for manual testing rather than bypassing authorization. Return to user 0 after testing; remove only the exact disposable user 11 when no longer needed. Existing original data/backup remain intact. No live success or runtime launch is claimed.

## Reversibility

Before-state receipts preserve the exact original provider fields and certificate list. Reverting the two policy fields would restore `allowUnrecognizedVersion=false` and `minDeviceRecognitionLevel=NO_INTEGRITY`; the added certificate can be removed by its exact returned SHA-resource name, and the newly enabled API can be disabled. **No rollback was executed**: it would restore the known connection blockers and requires a deliberate owner decision. No broad rollback, rules deployment, user-data restoration/import or key rotation is part of this change.

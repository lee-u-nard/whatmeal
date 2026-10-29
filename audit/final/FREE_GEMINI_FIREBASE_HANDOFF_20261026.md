# Keyless Firebase AI generation — final focused handoff, October 26, 2026

## Subsequent owner-requested APK build

Built the full online app using the existing signer and a separate source/output folder. **Build exit 0, 451.3 seconds**; locked offline dependency resolution exit 0. No app source, Firebase settings, signing configuration, original data or backup was changed for this build. No phone/device command or installation occurred.

- APK: `build/phone-release/20261026-free-gemini-95e620/WhatMeal-release.apk`
- SHA-256: `CFCD6F4C41BE55536FCCAF06813B9F8BBA5040E2396B380C45E10AB242669DF7`
- Size: **59,337,041 bytes** (56.6 MiB).
- Verified package/project: `com.example.whatmeal` / `whatmeal-101`; `productionRelease`, version `1.0.0+1`, debuggable false.
- `apksigner` passed; existing certificate SHA-256 `371ccb837f5379cc570eee0808710d3ca1cc36cbabef112e0a3d7960274b25bb` unchanged. Existing tester signing was authorized via a process-only setting; no signing key was generated.
- Emulator routing and tester debug App Check compile flags explicitly false. Release code uses Play Integrity; no runtime token/device verification is implied.
- Artifact source hashes match the verified working tree. Both unique updated-fix strings were found inside the actual compiled APK. All 200 ZIP entries were inspected for the four exact disposable fixture credential values; zero matches. This is a targeted credential check, not a general secret audit.
- All **four previous phone APKs** were rehashed unchanged; other existing APK locations/backups were not written. No old APK was replaced. Native/prod runtime limits stated below remain unverified.

Command: `flutter build apk --release --flavor production --target lib/main.dart --dart-define=WHATMEAL_EMULATORS=false --dart-define=WHATMEAL_TESTER_ANDROID_DEBUG_APP_CHECK=false`.

Build/verification receipts: `build/free-gemini-apk-20261026-95e620/`; public artifact details: `APK-INFO.json` beside the new APK. The earlier “no rebuild” statements below describe the source-fix checkpoint before this separately authorized build.

## Result

**Real keyless meal generation passed** with `gemini-3.5-flash-lite` through the current WhatMeal Gemini adapter and Firebase AI Logic SDK in the existing approved Spark project `whatmeal-gemini-test-20261019`. It returned **Filipino Sinangag (Garlic Fried Rice)**, one Dinner slot, and passed the existing recipe/slot/ingredient-restriction validator. Generation HTTP 200 completed in **3,395 ms**; SDK connection/token-count HTTP 200 completed in **580 ms**. No personal Gemini key or fallback model was supplied.

This is a **host SDK live-provider test**: Core/Auth/App Check native bridges were substituted, while disposable Auth sign-in, registered test App Check exchanges and Firebase AI requests/responses were real HTTPS. It is not an Android UI, Play Integrity, production-project or live persistence test. All those distinctions remain explicit in `result-4.json`.

No phone/ADB access, APK rebuild, production inference, user-data read/write, Firestore write, signing/configuration change, deployment, paid service or chat-pasted-key use occurred. Existing data, backups, APKs and unrelated working-tree changes were preserved. Normal sign-in updates only the existing disposable test account's Auth login metadata.

## Confirmed findings and corrections

- Default routing already correctly uses **`FirebaseAI.googleAI()`**, the Gemini Developer API backend, with optional Firebase Auth and App Check. The legacy `firebasevertexai.googleapis.com` proxy hostname does not mean WhatMeal selected the billed Vertex backend.
- The reported native **`firebase_app_check/unknown`** identifies token acquisition/verification. The pinned Android plugin maps native exceptions to `unknown`; that code alone does not identify a particular HTTP rejection or device failure. The prior App Check-specific diagnostics and limited-use-token compatibility delegate remain intact. Native production acquisition is still unverified without device access.
- `gemini-3.8-flash` is a valid documented model, but repeated isolated generation requests timed out at the existing deadlines. It is retained as an explicit selectable model, with the test limitation recorded. No quota or age-verification error was observed.
- **New/reset settings now default to the live-tested `gemini-3.5-flash-lite`.** Existing explicitly saved model selections are not rewritten. The model registry, settings labels and adapter/factory defaults agree; results still report the actual model used.
- **Test Connection now calls the selected model's SDK `countTokens` endpoint.** It verifies real access without waiting for a text completion or pretending a successful connection proves generation. The existing connection-success text still explicitly says generation has not been verified. BYOK remains available and separate.
- Errors retain the original exception for debugger inspection through `GenerationFailure.cause`. Public messages/logging remain sanitized; the raw cause must never be serialized or logged.

## Important files changed in this continuation

| File | Purpose |
| --- | --- |
| `lib/core/services/ai/adapters/gemini_adapter.dart` | Lightweight, real keyless model connection check via SDK token counting. Generation continues through SDK `generateContent`. |
| `lib/core/services/ai/model_registry.dart` | Verified Flash Lite default, truthful per-model test notes, preserved explicit Flash/model choices. |
| `lib/core/services/ai/generation_failure.dart` | Retain original cause without exposing native/provider response text. |
| `test/gemini_firebase_connection_test.dart` | Actual SDK request-builder regression: countTokens rather than text generation, selected default ID, fresh App Check token and correct failures. |
| `test/generation_failure_test.dart` | Original-cause retention, wrapping identity and secret redaction. |
| `test/model_registry_test.dart` | Keyless default, existing saved Flash selection preservation, accurate test notes. |
| `test/ai_provider_test.dart` | Expected verified default in provider factory. |

No Firebase initialization, dependencies, authentication, Firestore schema/rules, ownership, household, calendar, pantry/grocery, notifications, persistence implementation or visual layout was changed. The previous preparation/generation/save separation and retained-draft/save-only retry remain covered by regression tests.

## Actual verification

All logs/results are separate under ignored `build/free-gemini-host-20261026-cc42/`; failures were not overwritten.

- Final `flutter analyze --no-pub`: **exit 0, no issues, 90.0 s** (`final-analyze.txt`).
- Final focused suite: **153 passed, exit 0, 20 s** (`final-focused.txt`). Includes default/factory/model catalogue, App Check/timeout diagnostics, Gemini/BYOK HTTP contracts, quota, settings/account switching, generation validation and save-failure recovery. These use synthetic/mock data; they are not all live tests.
- Live comparison: **1 passed, exit 0** (`live-4-private.log`, `result-4.json`). One SDK token-count request plus one validated real meal-generation request, both HTTP 200, exact model `gemini-3.5-flash-lite`.
- Prior `gemini-3.8-flash` attempt remains **failed**, not a pass (`result-3.json`): both Auth/App Check exchanges completed; generation/old completion probe got no response bytes before their deadlines. Earlier safety-expiry/timeout failures and source snapshots also remain preserved.
- Independent token-count probe for `gemini-3.8-flash`: HTTP 200, 5 tokens, complete response in 419 ms; **connection metadata only, not generation** (`count-probe-result.json`).
- Test-project readbacks: billing disabled/no linked billing account, App Check enforced, AI Logic enabled; traffic filters `authRequired:false`, `templateOnly:false`. No changes were made.
- Public, credential-free endpoint checks responded promptly, so the old generation timeout did not establish a general DNS/HTTPS outage. SDK/current-upstream comparison found no evidence requiring a route rewrite or SDK upgrade.
- Read-only `whatmeal-101` Android-app/client-key policy inspection was rejected **HTTP 403** (`client-key-policy-readback.json`). No key string or user data was requested; no policy was changed. This is a metadata permission failure, **not evidence of an App Check runtime HTTP 403**.
- No Android build was run, respecting the instruction not to rebuild. Existing APKs do not include these latest source changes.

Commands (serial):

```text
flutter analyze --no-pub
flutter test --no-pub --concurrency=1 test/model_registry_test.dart test/ai_provider_test.dart test/provider_catalogue_contract_test.dart test/generation_failure_test.dart test/gemini_firebase_connection_test.dart test/firebase_ai_app_check_test.dart test/ai_settings_recovery_test.dart test/ai_generation_routing_test.dart test/live_ai_policy_test.dart test/generated_plan_persistence_test.dart test/gemini_custom_protocol_test.dart test/ai_quota_store_test.dart test/ai_provider_sync_test.dart --reporter expanded
flutter test --no-pub --concurrency=1 --dart-define=WHATMEAL_HOST_LIVE_AI=true --dart-define=WHATMEAL_HOST_MODEL=gemini-3.5-flash-lite build/free-gemini-host-20261026-cc42/host_live_test.dart --reporter expanded
```

The live call ran before the verified model was made the default; the outgoing model/configuration is identical, and final offline tests verify that default mapping. It was not repeated just to recreate passing evidence.

## Setup and remaining limits

1. **Existing saved Flash selection:** choose **Gemini 3.5 Flash Lite** in AI Settings if `gemini-3.8-flash` is explicitly saved. No personal key is required for the default Firebase AI route. This agent did not change the owner's saved settings or access the phone.
2. **Local development:** use the existing separate `aitest`/`cloudtest` configuration pointing to the approved test project. Debug builds use Android's debug App Check provider. In that **test project's** Firebase Console → App Check → the matching Android app → Manage debug tokens, register the SDK-generated token from private local development logs. Never paste/commit that token or register a test bypass in production. Existing registered test credentials were reused here.
3. **Production Android:** keep Play Integrity and App Check enforcement on. Package/Firebase app/signing certificate must match; the previously approved certificate/API/off-Play corrections are documented in `FREE_AI_APPROVED_FIREBASE_FIXES_20261026.md`. No further production change is justified by this host test. If `unknown` persists, inspect owner-side App Check metrics and client-key service restrictions; the metadata read was denied, so those restrictions remain unverified. Do not disable App Check, remove key restrictions or enable billing to conceal it.
4. **Runtime scope:** native Play Integrity, `whatmeal-101` inference, actual Android UI and live saved-plan persistence remain unverified. The phone-access prohibition is unchanged. Source changes need an owner-chosen build/update before an installed APK can use them; no existing APK was replaced.
5. **Free access:** provider/project/model eligibility and free-tier quotas still apply, plus WhatMeal's existing transactional daily budget. A keyless route is not unlimited or guaranteed access. No age, quota or billing problem was established by the observed timeouts.

Official references: [models and Spark eligibility](https://firebase.google.com/docs/ai-logic/models), [Firebase AI Logic setup](https://firebase.google.com/docs/ai-logic/get-started), [App Check/replay protection](https://firebase.google.com/docs/ai-logic/app-check), [Android Play Integrity setup](https://firebase.google.com/docs/app-check/android/play-integrity-provider), [debug-token exchange](https://firebase.google.com/docs/reference/appcheck/rest/v1/projects.apps/exchangeDebugToken).

## Subsequent owner-approved API-key metadata inspection and native diagnostics

Enabled **only `apikeys.googleapis.com`** in `whatmeal-101`, following explicit approval. No key values were requested. The associated Firebase client key has 27 API targets: App Check and Firebase AI are allowed; direct `generativelanguage.googleapis.com` is not allowed. Its Android restriction object is empty (`{}`). This does **not** establish a package mismatch or prove that the key caused a runtime rejection; the initial interpretation suggesting a mismatch was corrected. No restrictions or debug tokens were changed. Billing remains disabled, AI App Check/replay enforcement and the off-Play policy are unchanged. No account/data or phone access occurred.

Fresh readback confirms off-Play versions are already allowed, licensing is not required, and `MEETS_DEVICE_INTEGRITY` remains required. Sideloading is supported; switching the actual release to the debug provider is not an established fix. The screenshot's native `firebase_app_check/unknown` still does not expose the underlying attestation reason.

The pinned Android plugin collapses native errors into `unknown`. New `app_check_diagnostic.dart` extracts only documented HTTP statuses and fixed, allowlisted reason labels from the existing exception message. `generation_failure.dart` displays those safe labels/hints for both connection and generation; unknown reasons remain unknown. It never displays the raw body, keys, tokens, URLs, package or signing fingerprint. Classic/Standard Integrity numeric meanings are kept separate; SDK backoff is distinguished from Gemini quota. No provider, token policy, model, dependencies, save workflow or UI layout was changed.

Executed serially after the final source change:

```text
flutter test --no-pub --concurrency=1 test/app_check_diagnostic_test.dart test/generation_failure_test.dart test/gemini_firebase_connection_test.dart test/firebase_ai_app_check_test.dart test/ai_settings_recovery_test.dart test/ai_generation_routing_test.dart test/generated_plan_persistence_test.dart --reporter expanded
flutter analyze --no-pub
```

**86 focused tests passed, exit 0; analysis clean, exit 0 (63.5 s).** Eight new diagnostic tests cover attestation, native HTTP status, retry backoff, key/service/app restrictions, Integrity-code scope, unknown failures and sensitive-data redaction. These are offline tests, not native attestation verification. Independent read-only source review found no blocking issue. Earlier 85-test logs remain preserved separately.

Evidence: `build/appcheck-readonly-20261026-36b9/` contains `metadata-result.json`, `key-metadata-approved-result.json`, `key-policy-interpretation.json`, `final-tests.txt/.exit`, and `final-analyze.txt/.exit`. The interpretation receipt supersedes any inference from the earlier receipt's `currentPackageListed:false`: no nonempty Android app allowlist was observed. The actual remaining native cause and `whatmeal-101` inference remain unverified; the earlier isolated Spark host success is unchanged.

### Updated online diagnostic APK

- APK: `build/phone-release/20261026-appcheck-detail-36b9/WhatMeal-release.apk`.
- SHA-256: `3E523C30A378E74DE36D44F05892DDD5639A1A60420BE138D0EC643FB88F8212`; 59,337,041 bytes.
- Build: same `flutter build apk --release --flavor production --target lib/main.dart --dart-define=WHATMEAL_EMULATORS=false --dart-define=WHATMEAL_TESTER_ANDROID_DEBUG_APP_CHECK=false` command, exit 0, 208.5 s. Existing tester signer authorized with a process-only setting; no signing configuration/key changed.
- Offline `apksigner verify --print-certs` and `apkanalyzer` checks passed: `com.example.whatmeal`, native project `whatmeal-101`, non-debuggable release; certificate unchanged. This is the full online app, not an emulator/demo build. It retains Play Integrity.
- Source snapshot hashes match the tested workspace; four actual compiled fix/diagnostic markers found. All 200 APK entries scanned for the four existing disposable fixture credential values: zero matches. All five earlier phone APKs rehashed unchanged. This is a targeted credential scan, not a complete security audit.
- Build/inspection receipts remain under `build/appcheck-readonly-20261026-36b9/`; `APK-INFO.json` is beside the APK. No phone/ADB, installation, data/backup operation or further Firebase request occurred during the build/verification.
- Owner-only next verification: install as an update without uninstalling or clearing app data, then use Test Connection once. Report only the sanitized diagnostic label/status if it fails. This APK improves diagnosis; it does not establish that the remaining native App Check failure is fixed. A debug token is not required merely because the APK is sideloaded, and none was registered.

## Current-model live generation, save and reopen proof

The owner subsequently confirmed installing the diagnostic APK; the supplied screenshot still reports only `firebase_app_check/unknown`. **That phone connection remains FAIL (owner-reported), not fixed.** No native HTTP status or original exception message is available. Existing saved local logs contain no matching attestation/Integrity exception. Independent source review found no additional initialization or limited-use routing defect; Dart/native project, number, app ID and client-key equality checks all passed without displaying values. The app uses the Developer API backend, awaits App Check activation, and the SDK acquires App Check before dispatching inference. This supports investigating token acquisition, but does not identify the underlying rejection. An empty Android key-restriction object remains ambiguous under primary documentation; no speculative policy change is justified.

**PASS — directly verified against the separate Spark project:** one new keyless `gemini-3.5-flash-lite` token-count request (HTTP 200), one real generation (HTTP 200, 2,535 ms), one create-only atomic Firestore commit (HTTP 200), and two exact document reopens (HTTP 200 each). Generated **Filipino Sinangag (Garlic Fried Rice)** passed the existing meal/restriction validator. Actual `SavedPlansRepository.savePlan` produced the two-document payload; production `MealPlan`, `Meal` and `SavedMealPlan` parsers verified reopened identity, dates, status, ingredient quantities and instructions. The owner's explicitly selected `gemini-3.5-flash` was not changed; this proof explicitly selected Flash Lite.

Scope: Core/Auth/App Check native bridges were substituted on the host; Auth, registered-test token exchanges and AI HTTPS were real. Only native Firestore batching and reads were bridged to real authenticated REST with Firebase ID-token authorization. The existing rules decided the write/read requests. This is **not** Android UI, native listeners, Play Integrity, production inference, or enforced-replay certification. Fresh metadata confirmed no billing account, billing disabled and AI App Check enforced in `whatmeal-gemini-test-20261019`.

Exactly two **new disposable test documents** remain under the existing synthetic owner's newly allocated plan; both writes required `exists:false`. No list queries, original-record edits, deletions, production requests, configuration changes, phone/ADB access, shared credentials in source or generated signing keys occurred. No app source changed in this follow-up; the current APK hash remains `3E523C30A378E74DE36D44F05892DDD5639A1A60420BE138D0EC643FB88F8212`. A duplicate rebuild was not needed.

Executed:

```text
flutter analyze --no-pub build/free-gemini-proof-20261026-4de7/host_live_save_test.dart build/free-gemini-proof-20261026-4de7/persistence_support.dart
flutter test --no-pub --concurrency=1 --dart-define=WHATMEAL_HOST_LIVE_AI=true --dart-define=WHATMEAL_HOST_LIVE_SAVE=true --dart-define=WHATMEAL_HOST_MODEL=gemini-3.5-flash-lite build/free-gemini-proof-20261026-4de7/host_live_save_test.dart --reporter expanded
```

- **PASS:** final harness analysis, exit 0, no issues (4.6 s).
- **PASS:** one live host workflow, exit 0, 9 s; all four connection/generation/save/reopen flags true. Five bounded registered-test App Check exchanges succeeded; no token values were printed.
- **FAIL, preserved:** initial harness type check found a test-only missing AI-to-core conversion; second analysis found four brace-style issues. Both stopped before live traffic. Corrected only new harness files; first and second logs remain intact. Test-only native/snapshot interfaces are explicitly identified and do not supply invented server data.
- **Reused, not rerun:** 86 focused offline regressions and full app analysis from the preceding unchanged-source checkpoint; the existing verified release build.
- **BLOCKED:** direct inspection of the phone's original native rejection and real production generation. Phone access remains prohibited. The owner was asked to check the phone's Play Protect certification status (not app publication); no settings change is requested. The APK can remain distributed via Google Drive.

New isolated files/evidence: `build/free-gemini-proof-20261026-4de7/host_live_save_test.dart`, `persistence_support.dart`, `safety.json`, `harness-verified-analyze.txt/.exit`, `live.exit`, and `result.json`. Only documentation and new test-harness files changed; no additional app correction is claimed without an observed cause.

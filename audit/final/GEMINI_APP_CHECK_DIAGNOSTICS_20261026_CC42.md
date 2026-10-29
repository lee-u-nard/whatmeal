# Focused default Gemini diagnosis — October 26, 2026

**Later result:** keyless SDK generation with `gemini-3.5-flash-lite` subsequently passed live in the isolated Spark project. The earlier failures below remain history. See [current fixes, verified default, exact evidence and remaining native limitations](FREE_GEMINI_FIREBASE_HANDOFF_20261026.md).

## Outcome

**Live meal generation is not verified working.** This follow-up used no phone/ADB operations, production requests, original accounts, Firestore writes, configuration changes or deployments. All original data, backups and APKs were preserved. The existing approved separate Spark project was used only with its existing disposable account and registered test App Check credential. Normal test-account sign-in updates that disposable account's login metadata.

## Supported causes and limits

- The reported `firebase_app_check/unknown` identifies the **native App Check token stage**, before Gemini receives the SDK inference request. Pinned `firebase_app_check 0.3.2+10` Android `FlutterFirebaseAppCheckPlugin.getExceptionDetails` assigns `code: unknown` to every native exception. The diagnostic alone cannot prove the underlying HTTP status, failed integrity verdict, quota, network problem or certificate mismatch. No new Android exception was captured because phone access is prohibited.
- The previous approved readback in `whatmeal-101` confirmed/fixed three configuration blockers: disabled Play Integrity API, missing APK certificate and an incompatible off-Play policy. The previous app-local fix supplies limited-use tokens to the pinned Firebase AI SDK for enforced replay protection. These changes are preserved; none were repeated or reverted here. They do not by themselves establish successful native token acquisition on the phone.
- Current registry default and actual guarded test request both used **`gemini-3.8-flash`**, not just the UI label. It is a documented stable general-use Gemini Developer API model that does not require Blaze. No model was silently substituted. A user's private saved settings were not read. [Official model table](https://firebase.google.com/docs/ai-logic/models#model-names-general-use).
- Runtime path: provider settings/default config → `LlmService` configuration read and transactional quota reservation → `GeminiAdapter` → `FirebaseAI.googleAI(auth, FirebaseAiAppCheck)` → token acquisition → SDK `generateContent` → completion/JSON/recipe validation → separate save workflow. A custom Gemini key still selects its existing REST adapter. Demo mode still rejects live calls before quota/provider access. The reported native App Check diagnostic is different from that demo guard.
- **Confirmed error-handling bugs:** native App Check errors fell through to a generic Firebase error, and `testConnection` classified an actual `TimeoutException` as provider unavailable. The isolated live test reproduced the timeout misclassification. These are corrected without changing deadlines, retry behavior, selected model, quota reservation or security.

## Small local changes

| File | Purpose |
| --- | --- |
| `lib/core/services/ai/generation_failure.dart` | Distinct App Check category; preserve allowlisted plugin/code diagnostics through generation; actionable fixed verification message; prevent App Check throttling/authentication failures from becoming Gemini quota/sign-in errors; keep preparation and save stages separate. |
| `lib/core/services/ai/adapters/gemini_adapter.dart` | App Check failure maps to Connection Failed, not outage; timeouts keep timeout/network status and safe feedback. Existing Firebase AI, limited-use-token and BYOK paths remain. |
| `lib/features/ai_settings/data/ai_provider_repository.dart` | Preserve the App Check-specific failed status in the repository's catch path. |
| `test/generation_failure_test.dart` | Native/plugin stage, sanitized diagnostics, separate quotas/authentication, and pre-generation failure regressions. |
| `test/gemini_firebase_connection_test.dart` | Actual pinned SDK call chain with injected native token failures: connection failure, timeout, generation failure before inference/save. No network requests. |

No UI/layout, Firebase initialization/provider settings, dependencies, rules, App Check enforcement, billing, authentication, household, calendar, pantry, grocery, notification or persistence implementation changed.

## Actual live attempts — failures preserved

Ignored evidence: `build/free-gemini-host-20261026-cc42/`. It uses only `whatmeal-gemini-test-20261019` / Android test app `1:952163528165:android:9348c46aaa5943ff95530c`. Read-only billing/API/policy checks confirmed **billing disabled, no billing account, Firebase AI API enabled, App Check ENFORCED**. Test-project replay protection was unset; enforced production replay protection was not tested live.

The host harness substitutes only native Core/Auth/App Check bridges. Auth sign-in, fresh `limitedUse:true` exchanges, and the current adapter/Firebase AI SDK HTTP requests are real. The guard refuses production/other endpoints, requires matching account/app/project headers, and bounds inference to one connection check plus one one-meal generation. This is not an Android/native-attestation or UI test. [Official debug-token exchange request](https://firebase.google.com/docs/reference/appcheck/rest/v1/projects.apps/exchangeDebugToken).

| Attempt | Actual result |
| --- | --- |
| Initial harness | Exit 1: expired safety receipt; **zero network/inference requests**. Preserved `result.json` and `live-private.log`. |
| Refreshed host SDK run | Exit 1: disposable Auth sign-in HTTP 200; two real limited-use App Check exchanges HTTP 200; connection check timed out at its existing 15-second limit, generation timed out at its existing 90-second limit. Two inference requests dispatched. One HTTP 200 header was observed, but no successfully parsed/validated result completed; **no pass claimed**. `result-2.json`, `live-2-private.log`. |
| One independent bounded wire diagnostic | Exit 1: Auth HTTP 200, App Check HTTP 200; same test project/model Firebase AI endpoint, 32-output-token cap, 45-second deadline. Request timed out without a complete recorded response. **Not a successful connection or meal-generation test.** `wire-probe-result.json`. |

No quota, invalid-model or permission error response was observed. Timeouts do not prove any of those causes or a provider outage. No requests were repeated to force success, no longer deadlines were introduced, and no fallback model or custom Gemini secret was supplied. The three actual inference attempts are failures, not mock successes. Generated content was never fully parsed/validated, so there was no completed meal plan to save or preserve.

## Completed offline verification

```text
flutter test --no-pub --concurrency=1 test/gemini_firebase_connection_test.dart test/generation_failure_test.dart test/firebase_ai_app_check_test.dart --reporter expanded
flutter test --no-pub --concurrency=1 test/ai_settings_recovery_test.dart test/ai_generation_routing_test.dart test/live_ai_policy_test.dart test/generated_plan_persistence_test.dart test/gemini_custom_protocol_test.dart test/ai_quota_store_test.dart test/ai_provider_sync_test.dart --reporter expanded
flutter analyze --no-pub
```

Results: **19 passed, exit 0 (3 seconds); 83 passed, exit 0 (33 seconds); analysis no issues, exit 0 (95.2 seconds)**. Total **102 focused offline tests passed**. They cover provider/default-key separation, invalid-model/error handling, quota reservations, settings/account changes, parser/recipe checks, and save-failure recovery using synthetic/fake data. They do not establish live Firestore persistence or device success. No full-suite or Android build was repeated in this follow-up; previous APKs remain unchanged and do not include these new diagnostic changes.

## Remaining action

No further console/billing/security change is justified by the available evidence. Leave enforcement on. Owner-side evidence from [`whatmeal-101` App Check request metrics](https://console.firebase.google.com/project/whatmeal-101/appcheck/products) can distinguish verified/invalid/missing tokens without granting this agent phone access. See [official metric categories](https://firebase.google.com/docs/app-check/monitor-metrics). A native token's underlying rejection/status still needs evidence; the code must not guess it from `unknown`.

A complete successful live inference remains required. The current host route timed out despite valid disposable Auth/App Check exchanges. A subsequent bounded test is justified after network/provider availability changes; do not repeatedly consume requests or call a failure a pass. `whatmeal-101` native Play Integrity, its exact installed APK, real UI generation, and new-plan persistence remain unverified under the no-phone boundary. No permission to access the phone is requested or implied.

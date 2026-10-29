# WhatMeal academic release — 2026-10-26

The full online APK is built and verified. The configured direct Gemini default now works in a bounded live host test, including validated meal data and save/reopen in the approved test project. All five credentials passed a small live completion probe. This does not certify the new APK's Android UI: no phone was accessed or APK installed during this task.

The owner separately approved only the recipe-validation optimization for `whatmeal-101`. After a fresh 71-case emulator pass, the explicit project-scoped CLI deployment succeeded. Independent Rules API readback confirms the exact verified source is active. No production user documents were read, migrated, edited or deleted.

## Confirmed defects and repairs

| Defect | Repair and evidence |
| --- | --- |
| Default still attempted Firebase AI before the intended five-key Developer API | Configured pool now goes directly to the Developer API; BYOK takes priority. Live proof made **zero Firebase AI requests**. |
| Direct failures hidden behind the original Firebase exception | Removed duplicated service retries; the actual direct-provider failure reaches connection/generation feedback. Focused synthetic failure cases pass. |
| Fallback silently used a fixed model | Every credential attempt retains the selected model. Response/model-used values and endpoint tests agree. |
| Rotation retried permanent errors and shared mutable attempt state | Each request takes a distinct immutable key snapshot and tries a key at most once. Invalid model/input, malformed output and network/timeout failures stop; credential/quota errors have bounded failover. Concurrent request tests pass. |
| Google HTTP 400 invalid-key response was treated as a generic request failure | Structured `API_KEY_INVALID`/`API_KEY_EXPIRED` reasons map to a sanitized credential failure. Ordinary bad requests do not rotate. |
| Recent debug fallback used reusable App Check tokens | Restored fresh limited-use tokens in all modes for the retained Firebase AI path. Four SDK regressions reproduced this; final token tests pass. The configured direct default does not use this path. |
| Local web page embedded and automatically selected a debug credential | Removed the literal credential. Only explicit loopback `?appCheckDebug=true` requests SDK-generated development credentials. Five JavaScript regression cases pass. The old credential was accepted by Firebase during read-only diagnosis, so it was **not** proved invalid. |
| Web errors incorrectly blamed Android signing/Play Integrity | Generic App Check guidance now distinguishes web reCAPTCHA/development registration. Direct-API setup errors no longer claim Firebase setup is always required. |
| Detailed valid recipes could exceed Firestore rule evaluation budget | Applied only the exact approved optimized validator. Fresh **71/71** cases pass, including populated 10-ingredient and 21-meal plans, field/type injection, Unicode and immutable replacement links. Server and local source now match the candidate. |

## Feature audit and evidence scope

| Feature | Status | Evidence / limitation |
| --- | --- | --- |
| Default direct Gemini | **PASS — live host** | Five real completion probes; one validated full meal through the actual default pool. Native Android/browser UI for this new build is not verified. |
| BYOK/provider selection/reset/errors | **PASS — automated; partial live** | Focused and full Flutter suites; direct Gemini live. Other provider accounts/models were not called live. |
| Generation, parsing, restrictions and selected model | **PASS — bounded live + automated** | `gemini-3.5-flash-lite`, one Filipino Dinner, peanut exclusion, pantry context, schema validator. Other meal counts/models remain outside the new live proof. |
| Save and reopen | **PASS — live test-project repository/REST bridge** | Actual `SavedPlansRepository` batch, create-only two-document commit, exact server reopens and production model parsers verified IDs, dates, status, quantities and instructions. Native listener/UI behavior was not substituted for this evidence. |
| Production recipe-save validator | **PASS — deployment/readback + emulator** | Exact optimized source active in `whatmeal-101`; no production data write test was performed. |
| Manual plans, calendar, exact plan identity and lifecycle | **PASS — automated; partial Android evidence** | Current full suite plus earlier manual/calendar 34-case and retained Android status/save/reopen evidence. No new phone acceptance claim. |
| Authentication and account isolation | **PASS — automated; partial live** | Current session/isolation regressions, disposable real test-project sign-in, historical Android account workflows. Original account untouched. |
| Households, invitations, removal/rejoining and roles | **PARTIAL** | Current automated coverage, fresh 71-case authorization suite and earlier Android owner/member recovery workflows. No fresh two-physical-device test. |
| Pantry and groceries | **PARTIAL** | Current full-suite calculations/recovery tests; retained 10-checkpoint shared Android recovery evidence on one AVD. No new native contention acceptance. |
| In-app notifications/history/routing | **PARTIAL** | Current route, stale-target, loading/retry and receipt regressions; historical Android evidence. Native/background push remains unverified. |
| APK build and identity | **PASS — directly verified** | Release build, signature, package, project, compiled markers, hash and protected-artifact checks. |
| Installation/launch of this APK | **NOT RUN** | Phone access remains prohibited. No Android emulator was running; no valuable AVD state was booted/modified. Owner manual smoke test remains necessary. |

Historical evidence is retained in `WHATMEAL_FUNCTIONALITY.md`, `audit/stage15/demo-handoff/HANDOFF.md`, `MANUAL_PLAN_SAVE_CALENDAR_20261026_582c6495.md` and `CLOUD_TEST_HANDOFF.md`. Historical passes do not establish current production UI or multi-device behavior.

## Five credential results

Exact model: **`gemini-3.5-flash-lite`**. Each probe was a real Developer API `generateContent` request capped at 256 output tokens, validated as a completed text response. No values were printed.

| Credential ordinal | Live probe | Full meal |
| --- | --- | --- |
| 1 | PASS, HTTP 200 | PASS; Sinangag (Filipino Garlic Fried Rice), then isolated save/reopen |
| 2 | PASS, HTTP 200 | NOT RUN |
| 3 | PASS, HTTP 200 | NOT RUN |
| 4 | PASS, HTTP 200 | NOT RUN |
| 5 | PASS, HTTP 200 | NOT RUN |

Live failover was not forced because the first credential succeeded. Deterministic failure/retry/concurrency paths passed with synthetic keys and mock HTTP. Credential project identities and independent quota allocations are **unverified**. Five keys do not establish five separate quotas; Google applies limits per project. No billing or paid service was enabled.

The existing local credential file is preserved and now gitignored. The approved academic APK contains the five shared credentials; they are extractable. This is a private presentation prototype, not secured commercial credential distribution. No GitHub push/commit/release occurred. The previously exposed web development token was removed from source but not revoked remotely; revocation is a separate owner-controlled cleanup action.

## Files changed

- `lib/core/services/ai/adapters/gemini_adapter.dart`: direct-default routing, pool attempts, selected model and connection check.
- `lib/core/services/ai/bundled_key_pool.dart`: immutable bounded per-request ordering and retry eligibility.
- `lib/core/services/llm_service.dart`: remove duplicate retry/model-substitution paths; retain quotas, validation, save integration and BYOK fallback.
- `lib/core/services/ai/firebase_ai_app_check.dart`: retain limited-use tokens for legacy Firebase requests in debug and release.
- `lib/core/services/ai/adapters/http_response_support.dart`: structured Google invalid-credential classification.
- `lib/core/services/ai/app_check_diagnostic.dart`, `generation_failure.dart`: accurate sanitized platform/configuration messages.
- `lib/core/models/llm_config.dart`, `lib/features/ai_settings/pages/ai_settings_page.dart`: accurate default-provider text, same design/actions.
- `web/index.html`, new `web/app_check_debug.js`: remove embedded credential and make local debug opt-in explicit.
- `.gitignore`: protect the existing local credential file; its values were not edited.
- New pool/protocol/HTTP-error/web-bootstrap regressions; existing SDK tests explicitly exercise the legacy empty-pool path and settings tests assert the current direct default.
- `firestore.rules`: exact owner-approved optimized source, SHA-256 `49AA394DC5E125072AA73CB1DCF495CAD9185550D19532BA5037FA03AAC5B999`. Original preserved at `build/prototype-final-20261026-d8c1/whatmeal-101-rules-before.rules`.

## Actual verification

| Command / check | Result |
| --- | --- |
| Focused Flutter regression batch | **118 passed, exit 0** |
| `node --test test/web_app_check_debug_test.cjs` | **5 passed, exit 0** |
| Opt-in direct-provider/test-persistence harness | **1 live workflow passed, exit 0**; five probes, one full meal, one atomic commit and two exact server reads |
| `flutter test --no-pub --concurrency=1 --reporter expanded` | **675 passed, 1 opt-in test skipped, exit 0** |
| `flutter analyze --no-pub` | **No issues, exit 0**, 1431.0 s |
| `./audit/cloud-test/verify_candidate.ps1 -Check security` | **71/71 passed, exit 0**; dedicated demo project/ports, emulator shut down normally |
| Locked offline dependency resolution in the new build snapshot | **exit 0**, no application dependency upgrade |
| Release command below | **exit 0**, 555.6 s |
| APK signature/native identity/compiled markers | **PASS**; six previous phone APKs rehashed unchanged |
| Explicit approved Firestore CLI deployment | **exit 0**; independent Rules API active-source hash exactly matches verified candidate |

Preserved failures: first focused run **107 passed / 5 failed** (four exposed the debug session-token regression, one old wording assertion). They were corrected before the 118-case and full-suite passes. The connector deployment job reported success but did not change the active rules; that was **not** accepted as successful verification. Explicit CLI deployment and independent API readback resolved it. Older failed-run logs remain intact.

Release command, with only process-local existing tester-signing/JDK settings:

```text
flutter build apk --release --flavor production --target lib/main.dart --dart-define=WHATMEAL_EMULATORS=false --dart-define=WHATMEAL_TESTER_ANDROID_DEBUG_APP_CHECK=false
```

Approved rules command:

```text
node <installed firebase-tools>/lib/bin/firebase.js deploy --only firestore:rules --project whatmeal-101 --config build/cloud-test/firebase.json --non-interactive
```

All new receipts/logs are under `build/prototype-final-20261026-d8c1/`; live proof is under `live/`. Only disposable test documents were created. The only production change was the expressly approved rules optimization; Auth, indexes, App Check enforcement, billing and Functions were not changed. Temporary emulator services shut down, and live HTTP clients closed. The owner's existing Flutter/browser process was not stopped.

Disk pressure was resolved by deleting only checked, regenerable intermediate directories inside temporary build snapshots. No APK, source snapshot, signing file, account data, AVD backup or historical failure log was removed.

## Final APK and owner smoke test

**Full online app:** `C:\Users\ASUS V16\Desktop\jabez_projects\3RD_YEAR_SUBJECTS\App Dev\whatmeal\build\phone-release\20261026-prototype-gemini-d8c1\WhatMeal-release.apk`

- Size: **59,337,041 bytes** (56.6 MiB).
- SHA-256: **`76060693292D9193D94EBFE245CFF3FEF8A6D20E0A74B39D5FCEBDB00832F623`**.
- Package: `com.example.whatmeal`; native Firebase: `whatmeal-101`; `productionRelease`, version `1.0.0+1`, non-debuggable.
- Existing tester certificate unchanged; SHA-256 `371ccb837f5379cc570eee0808710d3ca1cc36cbabef112e0a3d7960274b25bb`. No signing secret was created or exposed.
- Actual compiled fixes and all five configured prototype credentials are present. All 200 ZIP entries were scanned for the four disposable Auth fixture values: zero matches. This is a targeted fixture check, not a claim that the intentionally bundled API credentials are secret.

Install as an **update** from the APK/Google Drive; do not uninstall or clear data. Select default Gemini and **Gemini 3.5 Flash Lite** for the live-verified model. Generate one one-day Dinner, save it, reopen it from Saved Plans, and check the scheduled date. Existing explicit model/provider choices were not overwritten, so select this model if another is saved.

The existing phone-access prohibition remains. The final manual phone workflow, native push and simultaneous physical-device synchronization are the remaining verification limits. No further Firebase setup is required for the demonstrated direct API route. Store publication is not needed for sideload installation.

Official references: [Gemini API keys](https://ai.google.dev/gemini-api/docs/api-key), [project-level quotas](https://ai.google.dev/gemini-api/docs/rate-limits), [request error/retry guidance](https://ai.google.dev/gemini-api/docs/troubleshooting).

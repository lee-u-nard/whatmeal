# Free AI repair — October 26, 2026

The screenshot confirms two separate faults. The settings banner always claimed that live AI was disabled in a local demo, even in the online app. Its actual Test Connection error was an unrecognized Firebase SDK exception, incorrectly labeled Provider Unavailable and described as a possible failed plan save. Test Connection does not save a meal plan. The real demo guard returns a different error before reading config/reserving quota, so it does not explain the screenshot's Firebase-error branch.

Actual default path: saved Gemini/no-key selection → LlmService → daily quota reservation → GeminiAdapter → `FirebaseAI.googleAI(auth: ..., appCheck: ...).generativeModel(model: 'gemini-3.8-flash')` → response parsing and recipe validation → unsaved editor → explicit Save Plan. A user-supplied Gemini key takes the separate direct REST route. The default model and SDK initialization match the [official model list](https://firebase.google.com/docs/ai-logic/models) and [Flutter setup](https://firebase.google.com/docs/ai-logic/get-started). Supported Developer API models have limited free-tier access; no paid key was introduced.

The pinned Firebase AI SDK awaits App Check and Auth tokens before sending inference HTTP. Such failures can escape as raw Firebase exceptions. The screenshot omits their original plugin/code; it does not prove App Check, disabled AI Logic, network failure, or exhausted quota specifically. The Firebase project metadata was read-only checked as `whatmeal-101`, lifecycle ACTIVE. That does not verify AI Logic enablement, phone attestation, or quotas. No user records or secrets were fetched.

Files changed:

- `lib/features/ai_settings/pages/ai_settings_page.dart`: show demo disablement only in actual emulator mode; accurate online Gemini notice.
- `lib/features/ai_settings/data/ai_provider_repository.dart`: confirm persisted selections before generation; prevent pending/failed optimistic Gemini selection from dispatching through an older saved provider; truthful connection failure status and diagnostics.
- `lib/features/meal_plan/pages/meal_plan_page.dart`: block generation with an actionable settings-save message when selection is not synchronized; distinguish preparation errors from inference errors.
- `lib/core/services/llm_service.dart`: identify configuration reads and quota-reservation failures before inference, preserving existing quota/security behavior.
- `lib/core/services/ai/generation_failure.dart`: safe operation-specific messages, recognized Auth/core/network categories, allowlisted plugin/code diagnostics, and no misleading save claim.
- `lib/core/services/ai/ai_models.dart`: represent an unidentified connection failure without claiming a provider outage.
- `lib/core/services/ai/adapters/gemini_adapter.dart`: contextualize Firebase SDK connection failures while retaining existing Firebase AI/REST implementations.
- Regression tests: `ai_settings_recovery_test.dart`, `ai_generation_routing_test.dart`, `live_ai_policy_test.dart`, `generation_failure_test.dart`, `manual_plan_editor_test.dart`.

Executed: targeted AI/settings/routing/quota/adapter/sync/persistence suite **91 passed**, exit 0; explicit emulator-mode service/banner checks **2 passed**, exit 0; generated recipe save-failure/save-only-retry widget regression **1 passed**, exit 0; analysis **no issues**, exit 0. Tests use synthetic adapters/fake Firestore, not live AI. The initial 88-pass run and style-only analysis failure remain preserved. No full suite rerun was performed for this focused repair.

Build: `flutter build apk --release --flavor production`, exit 0, 173.6 seconds, isolated source/output. APK signature matched the prior tester certificate; package/project verified as `com.example.whatmeal` / `whatmeal-101`.

```text
APK: build/phone-release/20261026-free-ai-5a8b9a94/WhatMeal-release.apk
Bytes: 59,337,041
SHA-256: AB3D251E9DC0C3021736A0E499F373235776778BD803B21F466996F4ECC86B56
Evidence: build/free-ai-repair-20261026-5a8b9a94/
```

Live generation is **not confirmed successful**. No live inference was sent and no phone was connected for verification. Install this full online APK as an update, tap Test Connection, and share only its new `Diagnostic:` value if it fails. The actual failing Firebase component must be identified before prescribing a configuration or quota change. Any Firebase AI Logic/App Check/signing-certificate setup must keep enforcement enabled and requires separate owner action/approval; billing/settings/rules were not changed. No deployment, GitHub operation, data migration, new provider credential, or fake generation was used. Existing data, prior APKs, and backups were preserved.

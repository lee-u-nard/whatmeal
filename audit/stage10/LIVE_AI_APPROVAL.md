# Live AI configuration request — pending, no live calls authorized

No separately approved non-production project is confirmed. `demo-whatmeal-audit` is emulator-only. Its existing native/Dart configuration must remain unchanged. The normal default flavor can select existing production configuration; it must not be used for this acceptance session.

Please provide only the explicitly approved **non-production Firebase project ID** and **local configuration-file locations**, together with permission for the bounded live tests below. Do not paste API keys, tokens, passwords or signing credentials into chat/reports.

1. Expected separate configuration: `android/app/src/aiTest/google-services.json` and `lib/firebase_options_ai_test.dart`, or approved existing equivalents. A distinct package/flavor and runtime project allowlist would be prepared for review before installation. These paths/flavor do not exist yet; this document does not authorize creating or selecting a cloud project.
2. Minimum setup: isolated disposable accounts and Auth/Firestore, app registration, Firebase AI Logic using the Gemini Developer API, an available text model, App Check registration/attestation and least-privilege test permissions. Any cloud rules/configuration changes require separate approval; local household rules passing does not establish that a cloud test project has compatible rules. Provider credentials must be entered privately through the app, never in reports. Current provider configuration persists at the owner's `users/{uid}/secrets/llmConfig`; no secure-storage migration is included.
3. Billing boundary: keep Spark and no linked Cloud Billing account; choose only currently eligible no-cost models/quotas. Vertex/Agent Platform and billable providers are outside current approval. Linking billing changes Gemini Developer API charging behavior. No intentional quota-exhaustion load test; use a tiny agreed request cap and stop on quota errors. Check current quota/model eligibility before any call. See [Firebase pricing](https://firebase.google.com/docs/ai-logic/pricing) and [setup/App Check](https://firebase.google.com/docs/ai-logic/get-started?platform=flutter).
4. Android App Check must validate this isolated package/certificate. Debug attestation requires a privately registered debug token for debug testing; release attestation needs supported Play Integrity distribution/device configuration. An AOSP AVD without Play services does not establish release attestation. Do not weaken enforcement or print debug tokens to bypass this requirement.
5. After explicit approval: a bounded successful Gemini plan and replacement, persisted exact identity/dates, dietary/pantry validation, custom-provider switching and removal/default restoration, invalid key/model/endpoint, safe retry without duplicate plans, account isolation and sanitized failures. Each additional provider needs its own approved no-cost account/configuration and call cap. Timeout/outage/malformed/safety/quota cases are live evidence only when actually observed; injected transport tests remain labeled offline and will not be achieved by flooding a real provider.

## Implemented adapter inventory (source inspection, not live certification)

| Adapter | Implemented route / authentication | Current default model |
|---|---|---|
| Gemini | `FirebaseAI.googleAI()` without an imported key; imported key uses Google `v1beta/models/{model}:generateContent` REST | `gemini-3.8-flash` |
| OpenAI | `/v1/chat/completions`, Bearer authorization | `gpt-4.1-mini` |
| Anthropic | `/v1/messages`, `x-api-key` and version header | `claude-haiku-4-5` |
| Groq | `/openai/v1/chat/completions`, Bearer authorization | `openai/gpt-oss-20b` |
| Custom | Explicit OpenAI Chat Completions compatible endpoint; optional Bearer key | User supplied (`default` is only a placeholder) |

The package constraint is `firebase_ai: ^2.3.0`. Model lists are fallbacks, not a promise that every account can use every model. Gemini/Groq documentation describes the implemented routes ([Firebase setup](https://firebase.google.com/docs/ai-logic/get-started?platform=flutter), [Groq reference](https://console.groq.com/docs/api-reference)); authenticated compatibility remains unverified. Native Ollama protocols/arbitrary JSON endpoints are not implemented. No live request was made while preparing this inventory.

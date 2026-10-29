# WhatMeal AI model catalogue and verification boundary

Checked against official public documentation on **2026-10-18**. This is the reviewed catalogue in `lib/core/services/ai/model_registry.dart`, not proof that a particular API account can use a model. **Every entry below is NOT LIVE-VERIFIED in WhatMeal.** Generation result metadata reports the exact requested model ID. It does not establish a server-confirmed snapshot; aliases can resolve to provider snapshots.

## Firebase Gemini

Default route: Firebase AI Logic Flutter SDK using the Gemini Developer API. Optional explicit user-key route: Google `generateContent` REST. Removing custom configuration restores `gemini-3.8-flash` through Firebase AI; it does not supply a missing approved Firebase project.

| Exact API model ID | Documented state / access | Normal picker |
| --- | --- | --- |
| `gemini-3.8-flash` | Stable; default | Yes |
| `gemini-3.7-flash` | Stable | Yes |
| `gemini-3.6-flash` | Stable | Yes |
| `gemini-3.5-flash` | Stable | Yes |
| `gemini-3.5-flash-lite` | Stable | Yes |
| `gemini-3.1-flash-lite` | Stable; newly catalogued | Yes |
| `gemini-3-flash-preview` | Preview; availability may change | Yes, labelled preview |
| `gemini-3.1-pro-preview` | Preview; requires Blaze billing | No |
| `gemini-2.5-flash` | Legacy; previously active projects only | No |
| `gemini-2.5-flash-lite` | Legacy; previously active projects only | No |

The listed stable Flash/Flash-Lite models do not require Blaze with the Gemini Developer API; limited free access, account quotas and Firebase setup still apply. Flash 3.6/3.7/3.8 have short-term availability. Gemini 4 Argon is intentionally not added because it requires billing. [Firebase supported models and lifecycle](https://firebase.google.com/docs/ai-logic/models)

## OpenAI

| Exact API model ID | Documented state / retirement | Normal picker |
| --- | --- | --- |
| `gpt-6-luna` | Current text model; newly catalogued | Yes |
| `gpt-4.1-mini` | Deprecated; 2027-01-14 | Yes, warning |
| `gpt-4.1` | Deprecated; 2027-01-14 | Yes, warning |
| `gpt-4o` | Deprecated; 2027-01-14 | Yes, warning |
| `gpt-4o-mini` | Deprecated; 2027-01-14 | Yes, warning |
| `o4-mini` | Deprecated; 2026-10-23 | Yes, warning |
| `o3` | Deprecated; 2026-12-11 | Yes, warning |

The legacy IDs are preserved until retirement rather than silently replaced. Recheck lifecycle before the listed dates. [Official deprecations](https://developers.openai.com/api/docs/deprecations)

GPT-6 Luna supports text, Chat Completions and structured outputs. Its API free tier is unsupported; own billed API access is required. It is the narrow current addition for this meal workflow, not a claim that every newer OpenAI family is integrated. [GPT-6 Luna specifications](https://developers.openai.com/api/docs/models/gpt-6-luna)

## Anthropic Claude

| Exact API model ID | Documented state / retirement | Normal picker |
| --- | --- | --- |
| `claude-haiku-4-5` | Active alias; snapshot `claude-haiku-4-5-20251001` | Yes |
| `claude-haiku-5-5` | Active; newly catalogued | Yes |
| `claude-sonnet-5-5` | Active; newly catalogued | Yes |
| `claude-sonnet-4-5` | Deprecated; snapshot `claude-sonnet-4-5-20250929`; 2026-11-30 | Yes, warning |
| `claude-opus-4-5` | Active alias; snapshot `claude-opus-4-5-20251101` | Yes |
| `claude-3-5-haiku-20241022` | Retired 2026-02-19 | No |
| `claude-3-5-sonnet-20241022` | Retired 2025-10-28 | No |

These are Claude text Messages API models. Haiku/Sonnet 5.5 are a narrow current addition; more costly/newer specialist families are unnecessary here. Uses the user's own billed API account; no free availability is asserted. [Current models and exact IDs](https://platform.claude.com/docs/en/models/overview), [Lifecycle and retirement dates](https://platform.claude.com/docs/en/about-claude/model-deprecations)

## Groq

| Exact API model ID | Documented state / access | Normal picker |
| --- | --- | --- |
| `openai/gpt-oss-20b` | Production; default | Yes |
| `openai/gpt-oss-120b` | Production | Yes |
| `llama-3.3-70b-versatile` | Production; Enterprise access | No |
| `llama-3.1-8b-instant` | Production; Enterprise access | No |
| `qwen/qwen3.8-27b` | Preview | Yes, labelled preview |
| `minimaxai/minimax-m2.7` | Preview; Enterprise access | No |

No speech, guard or unrelated specialist model is treated as meal generation merely because `/models` returned it. [Groq model catalogue](https://console.groq.com/docs/models)

Groq documents a limited free tier for GPT-OSS 20B/120B and Qwen, with account-specific limits and exceptions. Do not present free use as unlimited or guaranteed. [Rate limits](https://console.groq.com/docs/rate-limits)

## Implemented protocols

| Route | Endpoint / request / response contract |
| --- | --- |
| Firebase Gemini | Firebase AI Logic SDK `generateContent`; no custom key required by this route, but approved Firebase AI configuration is required. |
| Explicit Gemini REST key | `POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`; `contents`/`generationConfig`, candidate text parts. |
| OpenAI | `POST https://api.openai.com/v1/chat/completions`; Bearer authentication, `model`/`messages`, JSON response format; reads `choices[].message.content`. |
| Anthropic | `POST https://api.anthropic.com/v1/messages`; `x-api-key`, `anthropic-version: 2023-06-01`; `model`/`messages`/`max_tokens`; reads text content blocks. |
| Groq | `POST https://api.groq.com/openai/v1/chat/completions`; Bearer authentication and OpenAI-style messages/choices; JSON object output. |
| Custom | Explicit operator-provided OpenAI Chat Completions endpoint and model ID. No static model catalogue or claim of universal compatibility. Native Ollama, arbitrary JSON APIs and Responses-only endpoints are outside this adapter's contract. |

OpenAI uses `max_completion_tokens`; deprecated `max_tokens` is incompatible with o-series. GPT-6 permits `reasoning_effort: none`; o3/o4-mini require their own supported reasoning settings. A successful HTTP status alone does not establish complete, nonrefused text generation. [OpenAI Chat Completions reference](https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create)

Groq JSON object mode is distinct from strict JSON Schema support. This application still validates returned meal structure and requested slots. [Groq compatibility](https://console.groq.com/docs/openai), [Groq structured output](https://console.groq.com/docs/structured-outputs). Gemini REST uses its native format, not Chat Completions. [Google generateContent reference](https://ai.google.dev/api/generate-content)

## Local testing and remaining approval

- Local HTTP fakes can verify exact request fields, model selection, malformed/refused/truncated content, errors, timeouts and recovery. They do **not** verify vendor availability, actual model quality, dietary safety, billing, real account permissions or live saved-plan generation.
- Firebase emulators exercise isolated Auth/Firestore behavior; they do **not** emulate Gemini generation. Local demo AI remains disabled. Hand-authored demo recipes are not AI evidence.
- No non-production Firebase project has been explicitly approved/configured for live AI testing. `demo-whatmeal-audit` and `demo-whatmeal-showcase` remain emulator-only projects. Live testing stays pending; no production resource, deployment or paid service is part of this work.
- Future live setup requires the user to approve the non-production project ID and local configuration-file location. Configure credentials through the approved local mechanism, never by pasting keys into chat. No key, token, password or private configuration content belongs in this report, logs or screenshots.
- Existing per-user custom credentials remain in owner-only Firestore `users/{uid}/secrets/llmConfig`. Access rules reduce cross-account exposure but cannot make a client-readable secret nonextractable. Android keystore-backed storage would reduce local at-rest risk while changing cross-device persistence; a trusted proxy would change architecture/cost. No breaking credential migration or paid backend is authorized or introduced here.
- Keep known retired/restricted entries for explaining saved settings; require an explicit valid replacement instead of silently substituting another model. Documentation metadata and model discovery never confer a live-verified status.

Execution counts and final artifact evidence are recorded separately after the repair checks complete; this catalogue does not predeclare test success.

# WhatMeal final AI provider and model status

Handoff date: **2026-10-19**. The provider catalogue was checked on **2026-10-18**, matching `AiModelRegistry.checkedOn`; OpenAI Chat Completions and GPT-6 Luna documentation was also rechecked on **2026-10-19**. Availability remains subject to provider changes and the account's permissions.

The maintainable source of truth is [model_registry.dart](../../lib/core/services/ai/model_registry.dart). It contains **30 model IDs: 22 normal selectable choices and 8 retained restricted/retired entries** as of this handoff. The picker labels previews/deprecations and removes dated entries from normal selection when their retirement date is reached. Retained settings are not silently replaced.

**Follow-up (2026-10-19): `gemini-3.8-flash` is PASS — LIVE VERIFIED for one isolated Android Firebase AI Logic SDK meal smoke** in the approved, separate Spark project `whatmeal-gemini-test-20261019`. Existing WhatMeal response parsing and recipe/slot/peanut restriction checks passed. This does not establish full-app cloud generation/quota/persistence or live verification of any other model. All other rows retain automated-only/no-live evidence. No personal Gemini key was needed; enforced App Check used a privately registered device token. [Actual setup, scope, failed-first-run evidence and live result](../firebase-test/README.md). The original handoff's missing-project blocker is superseded only for this separate AI-only setup; the local/showcase apps still refuse live AI.

## Catalogue

“PASS — AUTOMATED TESTS ONLY” means the selected model ID passed the local adapter request/response contract with handwritten mock recipe data. It does not mean that the vendor accepted a request, that credentials are valid, or that real output meets household needs.

| Provider | Exact requested model ID | Lifecycle / access | Local status |
| --- | --- | --- | --- |
| Gemini | `gemini-3.8-flash` | Stable; application default | PASS — LIVE VERIFIED (separate Android SDK smoke; full-app persistence unverified) |
| Gemini | `gemini-3.7-flash` | Stable; short-term availability | PASS — AUTOMATED TESTS ONLY |
| Gemini | `gemini-3.6-flash` | Stable; short-term availability | PASS — AUTOMATED TESTS ONLY |
| Gemini | `gemini-3.5-flash` | Stable | PASS — AUTOMATED TESTS ONLY |
| Gemini | `gemini-3.5-flash-lite` | Stable | PASS — AUTOMATED TESTS ONLY |
| Gemini | `gemini-3.1-flash-lite` | Stable | PASS — AUTOMATED TESTS ONLY |
| Gemini | `gemini-3-flash-preview` | Preview; labelled; may change | PASS — AUTOMATED TESTS ONLY |
| Gemini | `gemini-3.1-pro-preview` | Preview; Blaze required; excluded | BLOCKED — APPROVAL REQUIRED; outside Spark scope |
| Gemini | `gemini-2.5-flash` | Legacy; previously active projects only; excluded | UNAVAILABLE FOR NEW PROJECTS; legacy access unverified |
| Gemini | `gemini-2.5-flash-lite` | Legacy; previously active projects only; excluded | UNAVAILABLE FOR NEW PROJECTS; legacy access unverified |
| OpenAI | `gpt-6-luna` | Current text model | PASS — AUTOMATED TESTS ONLY |
| OpenAI | `gpt-4.1-mini` | Provider default preserved; deprecated; ends 2027-01-14 | PASS — AUTOMATED TESTS ONLY |
| OpenAI | `gpt-4.1` | Deprecated; ends 2027-01-14 | PASS — AUTOMATED TESTS ONLY |
| OpenAI | `gpt-4o` | Deprecated; ends 2027-01-14 | PASS — AUTOMATED TESTS ONLY |
| OpenAI | `gpt-4o-mini` | Deprecated; ends 2027-01-14 | PASS — AUTOMATED TESTS ONLY |
| OpenAI | `o4-mini` | Deprecated; ends 2026-10-23 | PASS — AUTOMATED TESTS ONLY |
| OpenAI | `o3` | Deprecated; ends 2026-12-11 | PASS — AUTOMATED TESTS ONLY |
| Claude | `claude-haiku-4-5` | Active alias; provider default preserved | PASS — AUTOMATED TESTS ONLY |
| Claude | `claude-haiku-5-5` | Active | PASS — AUTOMATED TESTS ONLY |
| Claude | `claude-sonnet-5-5` | Active | PASS — AUTOMATED TESTS ONLY |
| Claude | `claude-sonnet-4-5` | Deprecated alias; ends 2026-11-30 | PASS — AUTOMATED TESTS ONLY |
| Claude | `claude-opus-4-5` | Active alias | PASS — AUTOMATED TESTS ONLY |
| Claude | `claude-3-5-haiku-20241022` | Retired 2026-02-19; excluded | UNAVAILABLE |
| Claude | `claude-3-5-sonnet-20241022` | Retired 2025-10-28; excluded | UNAVAILABLE |
| Groq | `openai/gpt-oss-20b` | Production; provider default | PASS — AUTOMATED TESTS ONLY |
| Groq | `openai/gpt-oss-120b` | Production | PASS — AUTOMATED TESTS ONLY |
| Groq | `qwen/qwen3.8-27b` | Preview; labelled | PASS — AUTOMATED TESTS ONLY |
| Groq | `llama-3.3-70b-versatile` | Production; Enterprise; excluded | BLOCKED — ACCOUNT ACCESS REQUIRED |
| Groq | `llama-3.1-8b-instant` | Production; Enterprise; excluded | BLOCKED — ACCOUNT ACCESS REQUIRED |
| Groq | `minimaxai/minimax-m2.7` | Preview; Enterprise; excluded | BLOCKED — ACCOUNT ACCESS REQUIRED |

The default Gemini model is also short-term availability. Eligible Gemini Flash/Flash-Lite models have limited Developer API free access without Blaze; setup and quotas apply. Groq documents limited free access for the two GPT-OSS choices and Qwen, with account-specific exceptions. OpenAI and Claude use the user's billed API account; no free API access is promised. No paid service was enabled.

Lifecycle/access sources: [Firebase models](https://firebase.google.com/docs/ai-logic/models), [OpenAI deprecations](https://developers.openai.com/api/docs/deprecations), [GPT-6 Luna specifications](https://developers.openai.com/api/docs/models/gpt-6-luna), [Claude models](https://platform.claude.com/docs/en/models/overview), [Claude deprecations](https://platform.claude.com/docs/en/about-claude/model-deprecations), [Groq models](https://console.groq.com/docs/models), [Groq limits](https://console.groq.com/docs/rate-limits).

## Protocols and exact test boundary

| Implemented route | Wire contract | Evidence |
| --- | --- | --- |
| Built-in Gemini | Firebase AI Logic Flutter SDK `generateContent` using Google AI backend | Synthetic SDK response parsing tested; **no Firebase AI Logic generation call executed** |
| Explicit Gemini user key | `POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`; `x-goog-api-key`, `contents`, JSON generation configuration, candidate text | Per-selectable-model HTTP mock generation contracts passed |
| OpenAI | `POST https://api.openai.com/v1/chat/completions`; Bearer key, exact `model`, `messages`, JSON object output; completion finish/refusal checks | Per-selectable-model HTTP mock generation contracts passed |
| Claude | `POST https://api.anthropic.com/v1/messages`; `x-api-key`, `anthropic-version: 2023-06-01`, `max_tokens`, text blocks and completion status | Per-selectable-model HTTP mock generation contracts passed |
| Groq | `POST https://api.groq.com/openai/v1/chat/completions`; Bearer key, exact `model`, `messages`, JSON object output, completion checks | Per-selectable-model HTTP mock generation contracts passed |
| Custom API | Explicit user-supplied OpenAI Chat Completions endpoint/model; no reviewed static model list | Local protocol/error tests passed; **endpoint/model compatibility remains unverified** |

The [catalogue contract tests](../../test/provider_catalogue_contract_test.dart) cover the 22 choices using injected HTTP clients, not external requests. [Gemini/custom tests](../../test/gemini_custom_protocol_test.dart) distinguish native Gemini REST envelopes from constructed Firebase SDK responses. [Routing tests](../../test/ai_generation_routing_test.dart) exercise quota reservation, configuration rejection, fallback disclosure, requested provider/model identity, validation and overlapping account operations with fakes. Those tests passed in the completed automated run; overall counts and APK evidence are in the separate final results.

Generation metadata reports the exact **requested** model ID. It does not certify the vendor's resolved snapshot. Claude model discovery recognizes the documented dated snapshots behind the retained 4.5 aliases. A connection probe is distinct from complete meal generation and persistence. Neither mocks nor an HTTP model catalogue establish real dietary safety, model availability or live output quality.

Protocol sources: [Google generateContent](https://ai.google.dev/api/generate-content), [OpenAI Chat Completions](https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create), [Groq compatibility](https://console.groq.com/docs/openai), [Groq API reference](https://console.groq.com/docs/api-reference), [Groq structured outputs](https://console.groq.com/docs/structured-outputs).

## Pending live configuration and credential handling

The newly approved non-production Spark project is `whatmeal-gemini-test-20261019`, configured privately at `android/app/src/aitest/google-services.json` (download copy: `build/firebase-gemini-test/google-services.json`). It is used only by the separate Android AI test harness. `demo-whatmeal-audit` and `demo-whatmeal-showcase` remain emulator-only; neither is eligible for live AI use. Their runtime AI gates remain enabled, and manual demo recipes are hand-authored.

Further model testing must remain bounded and explicitly select the intended model; no paid service or billing link is approved. Custom-provider live testing still needs approved credentials, supplied only through the approved local configuration mechanism; never paste keys into chat, commit them, or include them in logs/screenshots. Do not repoint either local demo to live Firebase or production. The successful Firebase SDK smoke does not require a separately embedded Gemini key.

Existing custom keys remain in owner-only Firestore `users/{uid}/secrets/llmConfig`. Owner-only rules do not make a client-readable secret nonextractable. Keystore-backed storage changes local persistence/cross-device behavior; a trusted proxy changes architecture and potentially cost. No breaking storage migration, paid backend, production access or deployment is approved or performed here.

Retired/restricted entries retain their explanatory metadata. Unknown discovered models are not promoted to verified compatibility, and fallback never claims that the originally selected model handled the request.

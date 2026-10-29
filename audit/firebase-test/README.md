# Isolated Firebase Gemini test project

Created **2026-10-19** specifically for the user's approved, bounded live Gemini verification.

- Project: **`whatmeal-gemini-test-20261019`** — [Firebase console](https://console.firebase.google.com/project/whatmeal-gemini-test-20261019/overview), [AI Logic](https://console.firebase.google.com/project/whatmeal-gemini-test-20261019/ailogic), [App Check](https://console.firebase.google.com/project/whatmeal-gemini-test-20261019/appcheck).
- Separate Android package: **`com.example.whatmeal.aitest`**.
- Firebase Android app ID: `1:952163528165:android:9348c46aaa5943ff95530c`.
- Backend: **Firebase AI Logic / Gemini Developer API**, not Vertex/Agent Platform.

This is a small AI verification app, **not the complete WhatMeal application or a production release**. It uses synthetic test input, not the original household's data. It does not replace/repoint `com.example.whatmeal.local`, `com.example.whatmeal.showcase`, their emulator projects, or their account/cache/export data.

## Confirmed provisioning

The new Firebase project and Android app were created, and AI Logic initialization succeeded. An actual Cloud Billing API read verified **`billingEnabled: false` and no linked billing account**. This is the required Spark/free-tier boundary; a linked but inactive billing account would not be equivalent.

AI Logic App Check initially reported enforcement off. Enforcement was explicitly enabled for this new project's AI Logic service and subsequently read back as **ENFORCED**. No original project's permissions or resources were changed. No billing account, Blaze upgrade, paid service or Cloud Function was introduced.

## Local configuration

- Downloaded native test-app configuration: `build/firebase-gemini-test/google-services.json` (private/ignored).
- Isolated Android flavor configuration location: `android/app/src/aitest/google-services.json` (ignored; populated only from the new test project's configuration).

Do not paste either file's contents, API keys, App Check debug tokens or authorization material into chat, source control, public logs or screenshots. Firebase AI Logic's default SDK route does not need a separately embedded Gemini provider key. Keep generated debug tokens private and register them only against this new Android app.

## Actual execution evidence

**`gemini-3.8-flash`: PASS — LIVE VERIFIED, isolated Android Firebase AI Logic SDK smoke only.** The real test returned **Filipino Chicken Afritada with Steamed Rice**, servings **2 persons**, including rice/carrot quantities. The same completion parser, recipe/slot validator and peanut ingredient restriction used by WhatMeal accepted the response. The model ID was explicitly requested, with no fallback. No original account, household or pantry data was used. Nothing was saved to Firestore. This does not verify full-app generation, quota persistence or saved-plan workflows against cloud Firebase, nor any other model.

Two Android attempts were executed. The first failed and remains recorded in `ui-result-first.xml` and `live-request-first-failed.json`. A separate private token exchange proved **HTTP 403 / SERVICE_DISABLED / firebaseappcheck.googleapis.com**: AI Logic provisioning and enforcement alone had not enabled that API for this app's key consumer. `enable_test_appcheck.cjs` enabled **only** the new project's App Check API. The registered token then exchanged successfully (**HTTP 200**), and the subsequent Android request passed. No attestation bypass, disabled enforcement, billing upgrade, automatic retry or model substitution was used. Raw SDK/token material stays under ignored `build/firebase-gemini-test/`; only sanitized results are retained here.

| Check | Actual result |
| --- | --- |
| Focused isolation tests | 13 passed, exit 0 |
| Complete Flutter unit/widget/fake-transport suite | 457 passed, exit 0, 111 seconds; no live provider calls from this suite |
| Flutter analysis | No issues, exit 0, 53.1 seconds |
| Separate debug APK build | Exit 0, 112.0 seconds |
| APK identity/signature/install/start commands | Passed; separate package/project verified before installation |
| Native wrong-entry-point guard | Expected Gradle exit 1; specifically rejected `lib/main.dart` for `aitest` before packaging |
| Android UI and real SDK generation | Passed after the missing App Check API repair; first failure preserved |
| Host attestation exchange | HTTP 200 after repair; no success token printed or stored |
| Billing/App Check readback | Billing disabled, no linked account, enforcement ENFORCED |
| Existing apps/configuration/backup manifest | Hash checks unchanged; no original app data read, cleared or signed out |

See `live-result.json`, `attestation-probe-disabled-api.json`, `attestation-probe.json`, `live-success.png`, `live-recipe.png`, `protected-after.json` and `installed-preservation.json`. The screenshots and XML show actual Android UI, not a mocked provider result. Historical 65 Firestore security cases/rules remain unchanged and were not rerun: no Firestore authorization implementation changed.

Relevant changes: `lib/main_ai_test.dart` and `lib/core/config/ai_test_environment.dart` implement the guarded smoke and two-attempt budget; `test/ai_test_environment_test.dart` covers ten launch/identity/budget cases; the Gradle flavor, its manifest and the early normal-entry-point guard isolate its package/native configuration. `.gitignore` excludes its private native config. No existing feature implementation or account storage was migrated.

## Build, install and launch

Commands executed serially from the workspace root:

```powershell
& './audit/firebase-test/run_checks.ps1'
& './audit/firebase-test/build_test_app.ps1'
& './audit/firebase-test/install_test_app.ps1'
```

Provisioning used Firebase MCP project/app creation and `firebase_init` with **ailogic only**, inside ignored `build/firebase-gemini-test/`. Native configuration was fetched with:

```text
npx -y firebase-tools@latest apps:sdkconfig ANDROID 1:952163528165:android:9348c46aaa5943ff95530c --project whatmeal-gemini-test-20261019 --out google-services.json --non-interactive
```

`check_test_project.cjs` reads billing and enforcement for the fixed new project. `register_test_device.cjs` registers the privately captured device token without placing its value in command arguments. App Check enforcement used `appcheck:services:set ailogic enforced` with the CLI's process-local `appcheckadmin` experiment; it did not modify a system setting or any existing Firebase project. The missing API repair is narrowly allowlisted in `enable_test_appcheck.cjs`.

APK: `build/firebase-gemini-test/whatmeal-ai-test.apk`, **155,667,964 bytes**.

SHA-256: `52B70751E25FD10D9619E455C98B6D8A4E2DCBE1898F3506BA9B1CE1FF9B9D27`.

Already installed and open on `emulator-5564`. To reopen without resetting data:

```powershell
& 'C:/Android/Sdk/platform-tools/adb.exe' -s emulator-5564 shell am start -W -n com.example.whatmeal.aitest/com.example.whatmeal.MainActivity
```

Tap **Generate one test dinner** deliberately. A process permits at most two attempts, including failures. A new physical/emulated device needs its own private debug-token registration. Do not share token material or use this debug attestation setup in production; revoke test debug tokens under this project's App Check when testing ends.

## Scope still pending

Full WhatMeal cloud Auth/Firestore setup, real-account workflows, seven-day generation/persistence, every other model, native push, two-device acceptance and production release remain unverified. No Auth provider, Firestore database/rules, production migration, deployment or Cloud Function was provisioned as part of this AI-only setup. The original and showcase packages retain their strict emulator-only/live-AI refusal. No full-app account or household state was copied into the new project.

Use only the reviewed default for this bounded result; an optional explicit `gemini-3.5-flash-lite` test must record its own actual requested ID and outcome. Do not silently switch models, disable App Check or link billing to resolve a failure. Only synthetic disposable data may be sent to the free service.

Official references checked **2026-10-19**: [Spark/free-tier requirements](https://firebase.google.com/docs/ai-logic/pricing), [Firebase AI Logic setup](https://firebase.google.com/docs/ai-logic/get-started), [supported models](https://firebase.google.com/docs/ai-logic/models), [Flutter App Check debug provider](https://firebase.google.com/docs/app-check/flutter/debug-provider), [billing verification](https://docs.cloud.google.com/billing/docs/how-to/verify-billing-enabled).

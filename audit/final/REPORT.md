# WhatMeal final local demonstration handoff

**Later approved Gemini setup (2026-10-19):** The separate Spark project `whatmeal-gemini-test-20261019` is now configured for the separate `com.example.whatmeal.aitest` Android harness. One `gemini-3.8-flash` SDK meal smoke passed live with synthetic data and enforced App Check after a preserved initial API-configuration failure. The subsequent suite passed 457 tests and analysis was clean. This supersedes only the missing-test-project/live-SDK blocker below; it does not establish full-app cloud generation/persistence. The historical demo APK/results below are preserved unchanged. [New setup, exact scope and evidence](../firebase-test/README.md).

Date: **2026-10-19**. Scope: local repairs and the separate disposable-account demo. Live AI remains pending.

## Artifact and readiness

**YES — ready for the local manual-workflow demonstration on the existing AVD.** The rebuilt release-mode demo is installed, open as the disposable owner, and saved. This is not a live-AI or production-readiness certification.

Final APK:

```text
C:\Users\ASUS V16\Desktop\jabez_projects\3RD_YEAR_SUBJECTS\App Dev\whatmeal\build\final\whatmeal-demo.apk
```

Launcher compatibility copy: `build/stage15/showcase/whatmeal-demo.apk`.

| Final artifact check | Result |
| --- | --- |
| Release build exit / duration | Exit 0; 134.0 seconds |
| APK byte size | 58,141,305 bytes (55.45 MiB) |
| APK SHA-256 | `56DDB70183DB9E8D4C6F3A345FAEFCA7A193A7B10AD72BA90E3E142279F693E9` |
| Package / native Firebase project / network guards | Passed: showcase package, demo project, loopback HTTP allowlist, disabled messaging/analytics auto-init |
| Tester certificate / signature | Passed: existing tester certificate; no production signer or signing secret created |
| Installation / cold startup / final screenshot | Update installed; COLD startup passed; owner Home and Demo Household visible; no fatal runtime error or ANR; screenshot in evidence directory |

Verified identity: **WhatMeal Demo**, `com.example.whatmeal.showcase`, Firebase project `demo-whatmeal-showcase`, local Auth **9299**, Firestore **9280**. The signer is the existing local tester signer, not production signing. Original app: `com.example.whatmeal.local`.

## Repairs completed

- Centralized the reviewed model catalogue: 30 retained IDs, 22 selectable; marked preview/deprecated access and retirement dates, removed retired/restricted models from ordinary selection. Unknown discovery results do not imply supported meal generation.
- Corrected provider probes, request parameters and response handling. HTTP 200, truncated/refused output or malformed catalogues no longer count as successful generation. Transport errors and provider bodies cannot expose keys through public errors/logs.
- Preserved exact requested provider/model identity and disclosed automatic Gemini fallback consistently for plans and replacement. Invalid provider configuration is rejected before built-in quota reservation; fallback failures retain safe classifications.
- Corrected settings status, model discovery, controller synchronization and stale operation handling. A saved configuration or connection probe does not claim live meal-generation success.
- Rejected missing/blank AI ingredient amounts while retaining explicit amounts such as `to taste`. The compact Groq prompt now requests separate ingredient name/amount objects. All three request paths retain known pantry amounts/units, excluding used/needed/expired stock without inventing quantities. Household context and conservative restriction checks have regression coverage; this is not a clinical allergy guarantee.

Important file groups: `lib/core/services/ai/` adapters, transport, registry, prompts and validators; `lib/core/services/llm_service.dart` routing/quota/result metadata; `lib/core/models/llm_config.dart` descriptions/defaults; `lib/features/ai_settings/` repository/model/settings UI; meal-plan and meal-detail fallback notices; corresponding provider, routing, settings, quantity/context and Android integration tests. Existing local flavor/native safeguards and Firestore permissions were preserved.

## Actual verification evidence

Evidence directory: [provider-local-fixes](../stage15/provider-local-fixes/). Logs and exit files retain failed runs as well as final passes.

| Check | Actual result / scope |
| --- | --- |
| Final complete Flutter suite | **447 passed, exit 0, 142 seconds**; unit/widget/fake-transport tests |
| Final Flutter analysis | **No issues, exit 0, 61.4 seconds** |
| Focused repair batches | 139 provider/settings cases; 4 result-notice cases; 15 quantity/context cases passed; these overlap the final suite, not extra final totals |
| All selectable model contracts | **22 passed** with injected HTTP mock responses; no provider requests |
| Android provider settings | **7 checkpoints, one workflow plus teardown, exit 0, 51 seconds**; real routed Flutter UI/native SDKs on one AVD; live calls blocked |
| Existing full manual demo workflow | Reused **31 Android checkpoints, exit 0, 218 seconds**; unchanged core workflows, not a fresh final-APK run |
| Existing shared recovery workflow | Reused **10 Android checkpoints, exit 0, 56 seconds**; account switching on one AVD, not simultaneous devices |
| Security acceptance | Historical **65 passing local cases** retained; rules unchanged; not rerun or reset here |

The Android settings run preceded the final notice/quantity changes; their behavior has automated regression evidence. The final release APK then passed cold startup and eight ordinary navigation checks: saved plans, exact saved-plan editor/dates, meal calendar, pantry, groceries, notification history, profile and Home. Screenshots/XML record rice stock 1 cup and a 2-cup shortage against 3 cups required, with separate carrot requirements. No new CRUD cycle or live AI generation is inferred from navigation. Authenticated localhost reads after restore verified both credentials, canonical owner/member roles, the same two-meal plan, pantry stock and retained private read receipts. See RESULTS.json and demo-data-check.json.

Preserved failures: initial repair compilation **71 passes / 7 load errors, exit 1**; initial analysis **7 style infos, exit 1**; quantity reproduction **4 passes / 7 failures, exit 1**, followed by the repair and passing targeted checks. The first Android settings attempt and earlier interrupted demo runs remain recorded and are not counted as passes. Gemini REST mocks and constructed Firebase SDK parsing tests do not establish a live Firebase AI Logic generation pass.

## Demonstration route and commands

From the workspace root, use the guarded launcher after final artifact verification:

```powershell
& './audit/stage15/showcase/OPEN_DEMO.ps1'
```

It starts/imports only the separate showcase backend, boots the existing AVD if needed, verifies the showcase APK and installs it without uninstalling or clearing data. Disposable account details remain in private ignored `build/showcase-private/accounts.json`.

Manual installation on the existing AVD, with the local backend already running:

```powershell
& 'C:/Android/Sdk/platform-tools/adb.exe' -s emulator-5564 install -r './build/final/whatmeal-demo.apk'
& 'C:/Android/Sdk/platform-tools/adb.exe' -s emulator-5564 shell am start -W -n com.example.whatmeal.showcase/com.example.whatmeal.MainActivity
```

Demonstrate Home/authentication → Profile/Family Sharing → Demo Household → manual Meal Plan → Saved/**Demo family week** → exact meal details/favorites/statuses → Pantry quantities/expiry → Grocery shortages/consolidation/provenance → notification bell/history/read state. Sign out of **WhatMeal Demo** and use the disposable member to demonstrate authorized sharing. Household creation, invitations/native copy, join, removal/access revocation, departure and rejoin have earlier actual UI evidence. Recipes are hand-authored examples; AI Generate/Replace remains blocked locally.

Before shutdown:

```powershell
& './audit/stage15/showcase/save_demo.ps1'
```

For an additional disposable registration, open its genuine local verification action:

```powershell
& './audit/stage15/showcase/open_verification.ps1' -Email 'new-person@example.test'
```

No Gmail delivery occurs. Finish the browser action, return to the demo and tap **I've Verified My Email**.

## Limits, preservation and next actions

The original cache/account and private backup were preserved; no reset, replacement dataset or sign-out was used to repair the original installation. Its pre-existing missing in-memory backend dataset **has not been recovered**. The disposable demo is a separate environment, not a restoration. Production was not accessed, modified, migrated or deployed; no rules weakened, paid services or Cloud Functions introduced.

[MODELS.md](MODELS.md) lists every model and its separate live status. No non-production Firebase project is explicitly approved/configured for live AI; both `demo-whatmeal-audit` and `demo-whatmeal-showcase` remain emulator-only. Native background/cold-start push, trusted sending infrastructure, physical devices, simultaneous two-device synchronization and production release/signing remain unverified.

1. Use the running local manual demo and save it before shutdown; no additional setup is required for this AVD.
2. If live AI is needed, approve a non-production project by **project ID and local configuration-file location only**; configure credentials locally, never in chat, before bounded provider tests.
3. Arrange two devices and a trusted push test environment, then approve production signing/deployment separately. Do not treat this emulator tester as a production release.


## Final environment recovery

The AVD and showcase backend unexpectedly stopped before the first final installation. That installation failed with device-not-found; APK build/identity verification had passed. The cause of process termination is unconfirmed. The latest paired showcase-only pre-test export was restored with the previous demo export archived; original cache/AVD backup were not imported or replaced. Reopen exited 0, cold startup passed, the eight release navigation checks and both-account read acceptance passed, and the final demo export exited 0. A first startup harness used an activity field absent from this Android dump; its exit-1 record was preserved and the check now uses the observed window-focus field. These failures are not passes. The demo backend and AVD remain running intentionally; test runners have finished.

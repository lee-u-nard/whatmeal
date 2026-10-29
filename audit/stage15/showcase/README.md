# Separate WhatMeal Demo

**Latest final handoff — 2026-10-19:** [Current demo APK, 447 tests, actual Android verification and limits](../../final/REPORT.md). Final artifact: build/final/whatmeal-demo.apk; SHA-256: 56DDB70183DB9E8D4C6F3A345FAEFCA7A193A7B10AD72BA90E3E142279F693E9. The earlier results below are historical; the separate demo remains local-only with live AI pending.

This demo is an additional app, **WhatMeal Demo**, package `com.example.whatmeal.showcase`. It has its own Android data folder/login, Firebase demo project `demo-whatmeal-showcase`, Auth 9299 and Firestore 9280. The original `com.example.whatmeal.local` installation, original backend ports and private AVD backup are not replaced or reused. Logo, colors and screens are preserved.

Open from the workspace root:

```powershell
& './audit/stage15/showcase/OPEN_DEMO.ps1'
```

The launcher imports the saved **showcase-only** backend, starts the existing AVD if needed, verifies and installs only the separate demo APK, then opens it. No uninstall, data wipe or original-account sign-out. Local login details are saved privately at `build/showcase-private/accounts.json`. The two accounts are disposable and already verified through the real local Auth action. No Gmail delivery occurs.

Demonstration route:

1. Start at Home as the demo owner. Profile → Family Sharing shows the shared Demo Household.
2. Meal Plan → Saved opens **Demo family week**. It contains hand-authored recipes, an accepted lunch and pending dinner. Open the current day to accept, favorite, complete or mark a meal not completed.
3. Pantry contains rice. Grocery shows exact rice shortage and separate meal provenance; edit the stock to show requirements changing. Accept the pending meal to add its requirements, then check a grocery item.
4. Open the bell for actual in-app notification history. Read state belongs to the signed-in demo account.
5. Sign out of **WhatMeal Demo** only, then sign in as the other disposable account to show authorized sharing. Create/copy/redeem a new single-use invitation if demonstrating removal/rejoining; tokens expire and cannot be reused.
6. To demonstrate registration, use another disposable `.test` address. After registration, run `open_verification.ps1 -Email 'new-person@example.test'`, complete the local browser action, return and tap **I've Verified My Email**.

Save demo changes before shutting down the PC:

```powershell
& './audit/stage15/showcase/save_demo.ps1'
```

An orderly backend shutdown also exports data. Unexpected termination can lose changes since the most recent export; the saved demonstration baseline can be reimported. Do not import this export into the original backend.

Live AI is intentionally disabled; Generate/AI replacement is not part of this manual demonstration. Recipes are explicit manual examples, not generated results. Native push, physical devices, simultaneous two-device behavior and production readiness remain unverified. Only in-app activity/history is demonstrated. No paid service, Cloud Function, production access or deployment is used.

## Verified handoff

Ready for the **local manual-workflow demonstration**. The separate release app is open as the owner with a two-member Demo Household, one saved hand-authored plan (accepted lunch/pending dinner), pantry stock and derived groceries. Account details: `build/showcase-private/accounts.json` (private/ignored, not uploaded).

- Actual routed Android UI: **31 checkpoints passed, exit 0, 218 seconds**. Registration/local verification, login/logout/isolation, creation/invitation/copy/join/removal/rejoining/departure, dietary profile, manual plan/details/favorites/statuses/reuse/deletion, pantry/grocery recalculation and notification history/read state. Simulated typing; real native clipboard/Firebase SDKs, one AVD.
- **297 Flutter tests passed**, exit 0, 127 seconds; analysis **no issues**, exit 0, 63.3 seconds. Five focused isolation/AI-policy tests and five launcher readiness cases also passed. The historical 65 security cases/rules were preserved, not rerun/reset against the prepared demo.
- Release-mode demo build: exit 0, 186.8 seconds, 55.4 MB. Native package/project/loopback policy/disabled auto-messaging and analytics/existing tester certificate verified. This uses the existing local tester signer, not production signing.
- Saved backend was stopped and imported again through **OPEN_DEMO.ps1**. Launcher exit 0; release app cold-started to Home with Demo Household/two members and no visible ANR. Authenticated local REST reads verified both credentials, canonical roles, same saved plan/meal states, stock and persisted read receipts after import. These server checks supplement the real UI evidence.
- Original installed APK hash unchanged; private AVD backup manifest unchanged; different Android app UIDs; original cache never cleared or signed out. Original backend remains stopped/unrecovered. Original local native guards, Firestore rules and security-suite hashes are unchanged. `main.dart` only gained the explicitly separate target selection; the original local target values and rejection of non-isolated Android flavors are regression-tested.

APK: `C:\Users\ASUS V16\Desktop\jabez_projects\3RD_YEAR_SUBJECTS\App Dev\whatmeal\build\stage15\showcase\whatmeal-demo.apk`

SHA-256: `6D9DB86B7F56AC22EC7E7C6C71EADD8EA419A14553DB70E8ED65DBAA2AAD14F9`.

The initial UI run stopped after 14 checkpoints when the VM connection disappeared; it remains an incomplete exit-1 run, with no certified root cause for termination. Desktop-owned local process lifetime was made independent of chat-tool interruption. An initial build-script copy selected the old APK; strict package verification rejected it **before installation**, and output selection was corrected. The first reopen check exposed the hub-before-services readiness race; the wait was corrected and both five-case regression and actual cold-backend restore passed. All failure records remain adjacent; none is counted as a pass.

Important changes: `lib/core/config/runtime_environment.dart` and `lib/main.dart` select fixed separate local targets; `android/app/build.gradle.kts` and `android/app/src/showcase/` add the separate package/native guards/demo label; `firebase.showcase.json` defines separate local services; `test/showcase_isolation_test.dart`, `integration_test/showcase_workflow_test.dart` and its driver verify isolation/UI and save disposable credentials privately. Local launch/save/verification helpers handle lifecycle and persistence. Full structured evidence: `RESULTS.json`.

Do not enter real AI provider keys. AI generation/replacement, native push, physical/multiple devices and production release readiness are not demonstrated. No production resources were accessed, changed or deployed. This demo does not recover or replace the original account's missing server dataset.

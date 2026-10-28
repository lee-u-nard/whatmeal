**Current contributor setup:** follow [SETUP.md](SETUP.md) before running Flutter commands. It explains the private AI configuration template, required vendored dependency, environment selection and signing. Current release evidence is in [the October 26 report](audit/final/ACADEMIC_RELEASE_20261026.md). The stage notes below are historical and do not describe the current default AI route or deployed rules.

Separate local demo is ready: **WhatMeal Demo** has its own package, backend and two disposable accounts. [Open/demo guide, private account-file location and verified APK](audit/stage15/showcase/README.md). Original account/cache/backup preserved; no production changes; live AI pending. The separate demo passed 31 actual Android UI checkpoints, 297 Flutter tests, analysis and a backend save/import/cold-start check.

**Latest final handoff — 2026-10-19:** [Current demo APK, 447 tests, actual Android verification and limits](audit/final/REPORT.md). Final artifact: build/final/whatmeal-demo.apk; SHA-256: 56DDB70183DB9E8D4C6F3A345FAEFCA7A193A7B10AD72BA90E3E142279F693E9. The earlier results below are historical; the separate demo remains local-only with live AI pending.

Latest bounded Stage 15 handoff (2026-10-18): [exact APK, install/run commands and readiness](audit/stage15/demo-handoff/HANDOFF.md). Shared two-account Android recovery passed 10 checkpoints; final 294 tests and analysis passed. Rebuilt tester installed to cached Home; original account/backup preserved. Complete original-account connected demo remains blocked by unrecovered original backend data. No production or live AI.

## Latest food recovery tester — 2026-10-18

The [food recovery evidence](audit/stage15/food-recovery/REPORT.md) records 294 passing Flutter tests, clean analysis, and all 10 Android recovery checkpoints passing with a disposable local account. Current artifact: `build/stage15/food-recovery/whatmeal-local-tester.apk`; SHA-256 `D80D00FB8A7D2652B6B2558A84D5CD4059A220B90C7709125C1B8A349F3FB06B`. It was verified, update-installed without clearing data, and cold-started to cached Home without a visible ANR.

The original cached account and private device backup are preserved. Original Auth9099/Firestore8180 remain stopped: no original paired server export was found, and no empty backend/account recreation was performed. Disposable services were exported privately and stopped. Local demo only; live AI remains pending an approved test project. No production changes or deployment.

# WhatMeal

Latest local tester: [Stage15 departure recovery follow-up](audit/stage15/departure-recovery/REPORT.md): 284 Flutter tests, clean analysis and 10 passing Android removal/outage/departure/race checkpoints. Updated isolated tester APK built, verified, installed without data clearing and cold-started to cached Home. **The original in-memory local backend is stopped and no original export was found in the searched locations; server-data recovery remains unverified. Do not replace it with an empty backend or recreate the account without an explicit decision.** Prior evidence is preserved.

Flutter meal planning and household food management app using Firebase Auth,
Cloud Firestore, Firebase AI Logic, Provider/ValueNotifier, and GoRouter.

Implemented screens include authentication/email verification, household spaces,
dietary profiles, pantry, groceries, manual/AI meal plans, saved plans/history,
meal details, notifications, and provider settings. Implementation does not imply
end-to-end verification: see the [latest local checkpoint](audit/stage15/FINAL_REPORT.md)
and [functionality matrix](WHATMEAL_FUNCTIONALITY.md) for evidence and remaining gaps.

## Development

Use the installed Flutter 3.44.5 / Dart 3.12.2 toolchain used for the audit:

```sh
flutter pub get
flutter analyze
flutter test
flutter run --flavor local -d emulator-5564 --dart-define=WHATMEAL_EMULATOR_HOST=10.0.2.2
```

Start the demo emulators and confirmed AVD using [TESTER.md](TESTER.md) before the local run command.

Code is grouped under `lib/features`; shared services, models, routing, and theme
are in `lib/core`. Personal documents are under `users/{uid}` and shared household
documents under `families/{familyId}`. Meal documents are nested under meal plans.

## Firebase and release configuration

- The existing project uses Spark; do not deploy `functions/` or enable billing
  as a prerequisite for development.
- Firebase is configured for Android, iOS, and web. Desktop options are absent.
- Android/iOS debug builds use App Check debug providers; register locally issued
  debug tokens privately in Firebase Console. Do not commit debug tokens.
- Android release builds always use Play Integrity. Debug-provider testing stays
  in debug builds or the separately guarded AI/cloud test flavors; no production
  release flag switches App Check to the debug provider.
- Release builds use Play Integrity / Device Check. Configure app registration,
  attestation, and signing in Firebase/Apple/Google consoles before device testing.
- Web uses Firebase App Check's reCAPTCHA Enterprise provider. Pass the public
  score-based site key registered for the web app. Startup stops with a
  configuration message if the key is missing or App Check cannot obtain a
  token:
  `flutter run -d chrome --dart-define=RECAPTCHA_SITE_KEY=YOUR_PUBLIC_SITE_KEY`.
- The VS Code `WhatMeal (Chrome)` launch profile passes the configured public
  site key automatically. Configure `localhost` as an allowed hostname on the
  reCAPTCHA key for local web development; browser hostnames are not Android
  package IDs.
  Use a separate development key for `localhost`; do not add `localhost` to a
  production key. Never pass the key's secret to Flutter.
- Android release uses ignored `android/key.properties`; debug signing requires
  explicit `WHATMEAL_TESTER_SIGNING=true`. Use `--flavor local` for isolated Android
  testing; see [tester setup](audit/stage15/TESTER.md). Do not use the superseded
  Stage 7 APK: Stage 8 found and corrected its native/Dart project mismatch.
- Local v2 rules pass 65 emulator acceptance cases. Deployed rules were not
  changed or verified; local client changes are not production migration approval.
- AI credentials currently persist in an owner-only Firestore document; this is
  not an operating-system secure credential vault. Never commit provider keys or
  embed private provider keys in release artifacts.

## Verification records

Current local checkpoint: [functionality reconciliation](WHATMEAL_FUNCTIONALITY.md)
and [Stage 15 final results](audit/stage15/FINAL_REPORT.md), preserving the [Stage 9 baseline](audit/stage9/REPORT.md). The approved local
security redesign is documented in [Stage 3](audit/stage3/README.md); its rules
have passed local emulator acceptance and have not been deployed. The records below
describe the earlier Stage 1 checkpoint.

See [audit/REPORT.md](audit/REPORT.md), [analysis results](audit/flutter-analysis.txt),
and [test results](audit/flutter-tests.txt). No Firebase rules or production data
were changed or deployed during this audit stage.
# Current academic release — 2026-10-26

The configured presentation build uses the existing five Google AI Studio credentials directly through the Gemini Developer API. Explicit BYOK takes priority; Firebase Auth/Firestore remain in use for accounts and persistence. The legacy Firebase AI path remains available when no prototype pool is configured; the older App Check setup guidance applies to that path and Firebase services, rather than being a prerequisite for direct Gemini requests.

The private credential file stays local and gitignored. Shared credentials are extractable from the presentation APK; this is not secured public commercial distribution. No credential values belong in Git or reports. Use Gemini 3.5 Flash Lite for the bounded live-verified model. [Final APK, actual verification, approved rules fix and remaining limits](audit/final/ACADEMIC_RELEASE_20261026.md).


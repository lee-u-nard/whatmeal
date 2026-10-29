# Stage 14 isolated Android tester

Artifact: `build/stage14/whatmeal-local-tester.apk`. Consult `REPORT.md` and matching command exit files for the completed build/runtime result. Package must be `com.example.whatmeal.local`, native and Dart project `demo-whatmeal-audit`, signed with the existing debug tester identity. This is not production signing or release approval.

Start only the approved local services:

```powershell
firebase emulators:start --only auth,firestore --project demo-whatmeal-audit --config firebase.audit.json
```

Use the process-local Java workaround in `COMMANDS.md` if required. Never capture emulator-generated verification URLs without redaction. No production data or cloud configuration is needed. Emulator restarts discard the in-memory fixture.

The standalone APK uses Android host alias `10.0.2.2`, Auth 9099 and Firestore **8180**. The alternate 8181 relay and 8182 control are used only by the separate integration recovery APK; do not require that relay for this tester. Local native policy permits HTTP only for localhost/127.0.0.1/10.0.2.2, disables FCM/analytics auto-init, and local app services refuse live AI.

With the AVD stopped and no other Flutter command running:

```powershell
$env:WHATMEAL_TESTER_SIGNING = 'true'
flutter build apk --release --flavor local --target lib/main.dart --dart-define=WHATMEAL_EMULATOR_HOST=10.0.2.2
```

Preserve platform regeneration when switching from integration/debug: do not add `--no-pub`. Reuse the existing debug keystore only. `android/key.properties` remains absent; no signing secret is generated or printed.

Before installing, run `audit/stage14/verify_tester.ps1` from the repository root and inspect its native network-policy/manifest evidence. Check the SHA-256 in `apk-sha256-value.txt`. Confirm AVD name `whatmeal-stage9-aosp` on dedicated port 5564 before using it; do not act on unrelated emulators on 5554/5555.

```powershell
adb -s emulator-5564 emu avd name
adb -s emulator-5564 install -r build/stage14/whatmeal-local-tester.apk
adb -s emulator-5564 shell am start -W -n com.example.whatmeal.local/com.example.whatmeal.MainActivity
```

Integration typing is simulated by Flutter; rendering, clipboard and Firebase SDKs run on the actual AOSP AVD. These tests do not establish live email delivery, native keyboard behavior, native push, simultaneous devices, live AI or production readiness. Production configuration, rules deployment/migration, signing and attestation require separate approval.

Verified result: local release-mode build exit 0,79.1s; native demo project, separate package, deny-default/local network allowlist, disabled FCM/analytics and existing debug tester signature verified (exit 0). APK SHA-256: `81BA3903697881E2173E577EC46827DDD693379E101971A5FF01E9249466772D`; size 57,895,529 bytes. Install/reset/cold-start exited 0. Cold start reported COLD, TotalTime1156ms. `tester-startup.png` was visually inspected: original WhatMeal Sign In screen, no ANR. This is an emulator tester, never a production release.

Separately, Stage14 passed243 Flutter tests, clean analysis and one actual Android inbox/settings workflow with9 checkpoints. Injected forbidden queries produced real SDK denials; visible Retry restored authorized feeds, UI Mark All Read persisted personal/shared receipts, and native A-B-A isolated history/routes and metadata-only provider settings. No AI credentials or provider calls were used. Typing was simulated by Flutter; native keyboard/email delivery/push, simultaneous devices and production readiness remain unverified.

Test services and dedicated AVD were intentionally stopped afterward; start local services before manual use. The unchanged65 security cases retain Stage11 passing evidence and were not rerun. See REPORT.md for precise boundaries and retained failures.

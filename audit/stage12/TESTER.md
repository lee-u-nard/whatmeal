# Stage 12 isolated Android tester

Artifact: `build/stage12/whatmeal-local-tester.apk`. Consult `REPORT.md` and matching command exit files for the completed build/runtime result. Package must be `com.example.whatmeal.local`, native and Dart project `demo-whatmeal-audit`, signed with the existing debug tester identity. This is not production signing or release approval.

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

Before installing, run `audit/stage12/verify_tester.ps1` from the repository root and inspect its native network-policy/manifest evidence. Check the SHA-256 in `apk-sha256-value.txt`. Confirm AVD name `whatmeal-stage9-aosp` on dedicated port 5564 before using it; do not act on unrelated emulators on 5554/5555.

```powershell
adb -s emulator-5564 emu avd name
adb -s emulator-5564 install -r build/stage12/whatmeal-local-tester.apk
adb -s emulator-5564 shell am start -W -n com.example.whatmeal.local/com.example.whatmeal.MainActivity
```

Integration typing is simulated by Flutter; rendering, clipboard and Firebase SDKs run on the actual AOSP AVD. These tests do not establish live email delivery, native keyboard behavior, native push, simultaneous devices, live AI or production readiness. Production configuration, rules deployment/migration, signing and attestation require separate approval.

Verified result: release-mode local build exit0,82.8s; native demo project, package, HTTP deny-default/loopback allowlist, disabled FCM/analytics and existing debug signature verified, exit0. APK SHA-256: 203BCA4E98C3FE4E022E1BA110DBF6EEC8E74714C940174EAB91ACA83BB311A0. Size 57879145 bytes. Check REPORT.md for the actual installation/cold-start result. This is an emulator tester, never a production release.

Stage 12 restart integration uses a separate debug APK on Firestore8181. Its first passing preparation and second passing recovery phase preserve native Auth/cache across an ADB force-stop; --keep-app-running prevents Flutter from uninstalling the app. Never clear app data between those phases. The test fixture file contains only disposable account identifiers and is ignored by the standalone app. Auth9099 remains reachable during the Firestore-only outage. The standalone tester always defaults to Firestore8180.
Standalone runtime verified: installation and isolated app reset exit0; cold launch exit0,COLD TotalTime1141ms; original Sign In screenshot inspected, no ANR. Test services were intentionally stopped afterward; start them using this guide before manual use. The original65 security cases remain unchanged and retain Stage11's passing evidence; Stage12 did not rerun them.

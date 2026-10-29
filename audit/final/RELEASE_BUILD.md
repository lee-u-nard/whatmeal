# Release-mode local demo APK — October 19, 2026

Built successfully with exit 0:

```powershell
$env:WHATMEAL_TESTER_SIGNING='true'
flutter build apk --release --flavor showcase --target lib/main.dart --dart-define=WHATMEAL_EMULATOR_HOST=10.0.2.2
```

The established process-local Java/Gradle memory and socket-directory settings were retained; no system settings or signing secrets were changed.

## Verified artifact

- Preserved output: `build/release-request/showcase-final-20261019-205721859/whatmeal-demo-release.apk`.
- Flutter output: `build/app/outputs/flutter-apk/app-showcase-release.apk`.
- Size: **58,223,225 bytes** (Flutter reports 55.5 MB).
- SHA-256: **`5D8C0A30006174443C67296AE94C4B2B77B4DF18EC1FB276319F3B4828D9B0C9`**.
- Package: `com.example.whatmeal.showcase`; native Firebase project: `demo-whatmeal-showcase`.
- Release mode (`debuggable=false`), existing tester debug signer; APK Signature Scheme v2 verification passed. This is **not a production-signed release**.
- Credential scanner passed: 201 decompressed ZIP entries, four disposable cloud-test credential literals checked in three encodings, zero matches. This is a bounded fixture check, not a comprehensive secret audit.
- Not installed or launched in this task. It requires the separate local showcase backend; live Gemini remains in the unchanged, debug-only cloud-test app.

## Build repair and checks

The exact requested `flutter build apk --release` exited 1 because it includes the deliberately prohibited AI-test Release flavor. The first explicit Showcase release also exited 1: shared `configureCMakeRelease[ABI]` tasks depended on `preCloudtestReleaseBuild`, activating its correct debug-only guard.

Added early `androidComponents.beforeVariants` filtering in `android/app/build.gradle.kts`: `aitest` and `cloudtest` non-debug variants are never created. All existing execution-time native configuration, entry-point and signing guards remain. Production/local/showcase variants and test Debug variants remain available. A copy of the complete pre-edit Gradle file is preserved under `build/release-request/gradle-preservation-20261019-205500896/`.

The real Gradle dry-run passed **11 variant/graph checks**: eight forbidden APK/AAB Release/Profile tasks absent, both allowed test Debug variants present, and Showcase release graph present without forbidden test variants. The repeatable inspection source is [verify_android_variants.init.gradle](verify_android_variants.init.gradle); run it with Gradle `:app:assembleShowcaseRelease --dry-run --init-script ../audit/final/verify_android_variants.init.gradle '-Ptarget=lib/main.dart'` from `android/`, using the existing tester build environment. These are Gradle configuration checks, not device acceptance tests.

The final Flutter release build passed in 144.1 seconds of Gradle execution. Post-build package/project/non-debuggable/signature/fixture-scan checks passed. Full Flutter tests were not repeated: no Dart, rule or runtime source changed; prior 488-test and analysis evidence is documented separately in [the cloud-test handoff](CLOUD_TEST_HANDOFF.md).

Failed build and inspection evidence remains under `build/release-request/`, including the initial malformed dry-run argument, included-build inspection error, and scanner output-directory rejection. Those interrupted/failed checks are not counted as passes; corrected checks actually executed successfully.

## Preservation

All eight protected configuration/artifact/backup hashes match. Existing `build/final/whatmeal-demo.apk` and `build/cloud-test/whatmeal-cloud-test.apk` remain byte-identical. No device installation, account/cache operation, backup overwrite, Firebase access/deployment, production operation, billing change or GitHub operation occurred.

Exact metadata and command logs are beside the preserved APK in `apk.json`, `build.txt`, `build.exit`, `signature-final.txt`, `fixture-credentials-absence.json`, and preservation reports. No production signing properties file exists; no signing secrets were generated.

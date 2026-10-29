# WhatMeal contributor setup

Use Flutter 3.44.5 / Dart 3.12.2, the versions used for the recorded checks.
Keep the committed pubspec.lock and third_party/cloud_firestore_platform_interface
source, license and patch notes. The latter is a required local dependency override.

## Private AI configuration

Before running Flutter commands, copy
lib/core/config/bundled_gemini_keys.dart.example to
lib/core/config/bundled_gemini_keys.dart only if that local file does not exist.
For PowerShell:

```powershell
$localConfig = 'lib/core/config/bundled_gemini_keys.dart'
if (-not (Test-Path -LiteralPath $localConfig)) {
    Copy-Item -LiteralPath "$localConfig.example" -Destination $localConfig
}
```

The template contains no credentials. An empty pool uses the existing Firebase AI
Logic path for default Gemini and retains optional personal BYOK. Firebase AI
requires an enabled project, valid App Check and available model quota. The local
emulator environment deliberately blocks live AI.

Only the existing private academic build supplies shared Gemini credentials in
the ignored file. Such credentials can be extracted from an APK or web bundle;
do not publish that file or those artifacts as a secure public deployment. Never
paste credentials into issues, reports, example files or source control. This
setup step neither changes an existing pool nor supplies free quota to a clone.

## Safe local development

For a fresh contributor checkout, use the separate `showcase` flavor on a fresh
Android virtual device. Its package and demo backend differ from the original
local tester. Install/configure the Firebase CLI, an Android SDK and JDK 21 before
starting; do not upgrade the app's dependencies. In one terminal:

```powershell
firebase emulators:start --only auth,firestore --project demo-whatmeal-showcase --config firebase.showcase.json
```

In another terminal, after the private-configuration template step above:

```powershell
flutter pub get --enforce-lockfile
flutter run --flavor showcase --dart-define=WHATMEAL_EMULATOR_HOST=10.0.2.2
```

Choose only the fresh AVD if Flutter asks for a device. Register disposable
accounts; emulator verification links appear in the local Auth emulator output.
This environment blocks live AI and native push deliberately. Do not run these
commands against the owner's original emulator/cache, reuse account exports,
clear app data or treat this as recovery of the original backend. The historical
TESTER/stage instructions refer to private existing-device state, not a portable
bootstrap. Cloud-test and AI-test native configuration files stay private; ask
the owner for the approved local configuration location if those flavors are
needed.

```powershell
flutter pub get --offline --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
```

If packages are not cached, use flutter pub get --enforce-lockfile with network
access; do not upgrade dependencies to work around a missing cache.

Optional Android integration drivers write screenshots into local audit output
folders. Before an opt-in driver run in a fresh checkout, create only the output
folders declared by those drivers:

```powershell
Get-ChildItem -LiteralPath test_driver -Filter '*.dart' | ForEach-Object {
    $driverText = Get-Content -LiteralPath $_.FullName -Raw
    [regex]::Matches($driverText, "destinationDirectory:\s*'([^']+)'") | ForEach-Object {
        $outputFolder = $_.Groups[1].Value
        if ($outputFolder -notmatch '^(audit|build)/') { throw 'Unexpected output folder' }
        New-Item -ItemType Directory -Force -Path $outputFolder | Out-Null
    }
}
```

The standalone 71-case rules suite is
`audit/cloud-test/security_acceptance_candidate.mjs`. On a disposable local
emulator only, run:

```powershell
firebase emulators:exec --only firestore --project demo-whatmeal-cloud-security --config firebase.security-test.json.example 'node audit/cloud-test/security_acceptance_candidate.mjs'
```

That configuration loads the repository rules on isolated port 9380; the suite
refuses other hosts/projects and resets only its disposable emulator database.
Do not point it at the owner's running backend. Historical machine-specific
verification wrappers, raw audit logs, screenshots, exports and build receipts
are intentionally outside the proposed source submission. Their links in older
reports are historical references, not required bootstrap files.

Android release builds require your own private android/key.properties and
keystore, or an explicit process-only WHATMEAL_TESTER_SIGNING=true for a tester.
Do not commit signing material or describe tester signing as store signing.
Select the flavor deliberately: local is emulator-only; production connects to
the existing whatmeal-101 configuration. Building does not authorize launching
against production or altering Firebase settings.

## Current verification

The October 26 evidence is in audit/final/ACADEMIC_RELEASE_20261026.md: 675 Flutter
passes, one skip, clean analysis, 71 rules acceptance passes, bounded direct
Gemini generation and test-project save/reopen, and a release APK build. The new
APK was not installed or launched. Native push and physical multi-device behavior
remain unverified. Earlier stage reports describe historical results, not the
current build or permission to deploy.

Separate local demo is ready: **WhatMeal Demo** has its own package, backend and two disposable accounts. [Open/demo guide, private account-file location and verified APK](showcase/README.md). Original account/cache/backup preserved; no production changes; live AI pending. The separate demo passed 31 actual Android UI checkpoints, 297 Flutter tests, analysis and a backend save/import/cold-start check.

Latest bounded Stage 15 handoff (2026-10-18): [exact APK, install/run commands and readiness](demo-handoff/HANDOFF.md). Shared two-account Android recovery passed 10 checkpoints; final 294 tests and analysis passed. Rebuilt tester installed to cached Home; original account/backup preserved. Complete original-account connected demo remains blocked by unrecovered original backend data. No production or live AI.

## Latest food recovery tester — 2026-10-18

The [food recovery evidence](food-recovery/REPORT.md) records 294 passing Flutter tests, clean analysis, and all 10 Android recovery checkpoints passing with a disposable local account. Current artifact: `build/stage15/food-recovery/whatmeal-local-tester.apk`; SHA-256 `D80D00FB8A7D2652B6B2558A84D5CD4059A220B90C7709125C1B8A349F3FB06B`. It was verified, update-installed without clearing data, and cold-started to cached Home without a visible ANR.

The original cached account and private device backup are preserved. Original Auth9099/Firestore8180 remain stopped: no original paired server export was found, and no empty backend/account recreation was performed. Disposable services were exported privately and stopped. Local demo only; live AI remains pending an approved test project. No production changes or deployment.

# Run the final isolated WhatMeal tester

This APK is for the local Android emulator, not production or Play Store distribution. It uses `com.example.whatmeal.local` and only `demo-whatmeal-audit` (Auth9099 / Firestore8180). Live AI and native push are intentionally unavailable. Do not enter real provider credentials. Do not install the superseded Stage7 APK.

Run all commands from:
`C:/Users/ASUS V16/Desktop/jabez_projects/3RD_YEAR_SUBJECTS/App Dev/whatmeal`

Verified artifact: `build/stage15/whatmeal-local-tester.apk`, existing debug signature v2 verified. SHA-256: `CAEA1B80B01080635732D9AA9B94BFC9A1DEE69D14304BA080F8006849B5385B`. Installed and cold-started to original Sign In without ANR. Test services were stopped; start them below.

## Current recovery safety gate

**Do not execute the historical primary-backend start command below while recovering the existing account.** It starts an empty in-memory backend when no import is supplied. The2026-10-18 search found no original paired Auth/Firestore export in the workspace/project area, Windows temporary folder or Firebase cache. The available export is disposable test data and contains no normal-account record. See [recovery evidence](departure-recovery/REPORT.md). Preserve the cached login and private AVD backup; no account reset/recreation is authorized. Independent disposable tests use9199/9180 with explicit private import/export.
## 1. Start the local backend — PowerShell terminal 1

```powershell
$env:JAVA_HOME='C:/Program Files/Android/Android Studio/jbr'
$env:PATH="$env:JAVA_HOME/bin;$env:PATH"
$env:JAVA_TOOL_OPTIONS='-Xmx512m -Djdk.net.unixdomain.tmpdir="' + (Resolve-Path audit/stage15).Path + '"'
& 'C:/Users/ASUS V16/AppData/Roaming/npm/firebase.cmd' emulators:start --only auth,firestore --project demo-whatmeal-audit --config firebase.audit.json
```

Wait for both emulators to report ready. Keep this terminal open. Registration/password-reset emails are not delivered: open the action link printed privately by the Auth emulator, then return to the app and tap **I've Verified My Email**. Never share these action links. Restarting the backend discards its in-memory demo data; use disposable accounts only.

## 2. Open the existing Android emulator — PowerShell terminal 2

```powershell
$env:ANDROID_AVD_HOME=(Resolve-Path build/audit-avds).Path
$env:ANDROID_HOME=(Resolve-Path build/android-sdk-audit).Path
$env:ANDROID_SDK_ROOT=$env:ANDROID_HOME
Start-Process -FilePath 'C:/Android/Sdk/emulator/emulator.exe' -WindowStyle Normal -ArgumentList @('-avd','whatmeal-stage9-aosp','-no-audio','-no-snapshot','-gpu','host','-memory','1536','-cores','2','-port','5564')
```

This opens a visible emulator for manual interaction. If that dedicated AVD is already running, reuse it instead of starting a duplicate. Do not change Android security settings or dismiss failures automatically.

## 3. Verify, install, and launch — terminal 2

```powershell
$adb='C:/Android/Sdk/platform-tools/adb.exe'
$boot=$false
for($n=0;$n -lt 36;$n++) {
  Start-Sleep -Seconds 5
  if((& $adb -s emulator-5564 shell getprop sys.boot_completed 2>$null) -eq '1') { $boot=$true; break }
}
if(!$boot) { throw 'Dedicated AVD did not boot; preserve its error instead of installing elsewhere.' }
$name=& $adb -s emulator-5564 emu avd name
if(($name | Select-Object -First 1) -ne 'whatmeal-stage9-aosp') { throw 'Unexpected AVD.' }
& ./audit/stage15/verify_tester.ps1
& $adb -s emulator-5564 install -r build/stage15/whatmeal-local-tester.apk
if($LASTEXITCODE -ne 0) { throw 'Install failed.' }
& $adb -s emulator-5564 shell am start -W -n com.example.whatmeal.local/com.example.whatmeal.MainActivity
```

Use the manual meal planner, pantry and grocery workflows. AI generation remains blocked until a separate non-production project is explicitly approved. See [FINAL_REPORT.md](FINAL_REPORT.md) for actual verification and artifact identity. This tester reuses the existing debug signer; it is not a production release.

When done, close this dedicated emulator (`adb -s emulator-5564 emu kill` after confirming its name), then press Ctrl+C in terminal1. No production deployment is needed to run this local app.

## Latest household recovery checkpoint — 2026-10-18

Use the rebuilt [household recovery tester and evidence](household-recovery/REPORT.md), artifact `build/stage15/household-recovery/whatmeal-local-tester.apk`, SHA-256 `7A0FE24C248747ED29C0ECDA7FA4A8AB5DB8ECECD1B34F3EFC024530B2BB24C8`. It is installed on the connected isolated AVD and cached Home was observed.

**Do not blindly restart the primary backend:** its former in-memory9099/8180 process stopped unexpectedly and no workspace export was found. The AVD's private stopped-state backup was verified, and cached Auth identity retained; server dataset recovery remains unverified. No account recreation was performed. Only disposable tests used independent9199/9180, with a separate ignored fixture export; those services are now stopped. Preserve the original device/data while resolving the backend recovery decision. Live AI remains pending, and production was untouched.


## Latest departure recovery tester — 2026-10-18

The [departure recovery evidence](departure-recovery/REPORT.md) records284 passing Flutter tests, clean analysis, and10 passing Android checkpoints with disposable accounts. Latest local-only artifact: build/stage15/departure-recovery/whatmeal-local-tester.apk. SHA-256: 71E01843ED8700461F1A81BFE0C23E8E222C4483DEADCBD7D55DE9DB6CC147C7. Original branding and existing tester signer retained; this is not a production release.

No original paired Auth/Firestore export was found in the project/temp/Firebase-cache search. The available exports are disposable fixtures, with no normal-account record. Original9099/8180 remain stopped, no normal account was recreated, and the private device backup remains protected. Live AI remains pending. Do not run the historical empty primary-backend start command as a recovery action.

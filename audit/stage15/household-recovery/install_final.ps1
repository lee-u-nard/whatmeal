$ErrorActionPreference = 'Stop'
$adb = 'C:/Android/Sdk/platform-tools/adb.exe'
$apk = (Resolve-Path 'build/stage15/household-recovery/whatmeal-local-tester.apk').Path
$expected = (Get-Content audit/stage15/household-recovery/apk-sha256-value.txt -Raw).Trim()
if ((Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash -ne $expected) { throw 'APK changed since verification' }
if ((& $adb -s emulator-5564 emu avd name | Select-Object -First 1) -ne 'whatmeal-stage9-aosp') { throw 'Wrong device' }
& $adb -s emulator-5564 shell am force-stop com.example.whatmeal.local
& $adb -s emulator-5564 install -r $apk *> audit/stage15/household-recovery/install-final.txt
$result = $LASTEXITCODE
Set-Content audit/stage15/household-recovery/install-final.exit $result
if ($result -ne 0) { throw 'Tester install failed; no uninstall/clear attempted' }
& $adb -s emulator-5564 shell am start -W -n com.example.whatmeal.local/com.example.whatmeal.MainActivity *> audit/stage15/household-recovery/launch-final.txt
$result = $LASTEXITCODE
Set-Content audit/stage15/household-recovery/launch-final.exit $result
if ($result -ne 0) { throw 'Tester startup failed' }
Start-Sleep -Seconds 8
& $adb -s emulator-5564 shell uiautomator dump /sdcard/whatmeal-startup.xml *> audit/stage15/household-recovery/ui-dump.txt
if ($LASTEXITCODE -ne 0) { throw 'UI capture failed; inspect device without dismissing system dialogs' }
$tree = (& $adb -s emulator-5564 shell cat /sdcard/whatmeal-startup.xml) -join ''
$foreground = [bool](& $adb -s emulator-5564 shell dumpsys activity activities | Select-String '(topResumedActivity|ResumedActivity).*com.example.whatmeal.local')
[pscustomobject]@{
  AppForeground = $foreground
  HomeVisible = $tree.Contains('Home')
  SignInVisible = $tree.Contains('text="Sign In"')
  RetryVisible = $tree.Contains('Retry') -or $tree.Contains('retry')
  SystemAnrVisible = $tree.Contains('isn''t responding') -or $tree.Contains('keeps stopping')
  PrimaryAuthListening = [bool](Get-NetTCPConnection -LocalPort 9099 -State Listen -ErrorAction SilentlyContinue)
  PrimaryFirestoreListening = [bool](Get-NetTCPConnection -LocalPort 8180 -State Listen -ErrorAction SilentlyContinue)
  DataCleared = $false
  Scope = 'Standalone local tester startup with former primary backend unavailable; not recovered server-data evidence'
} | ConvertTo-Json | Set-Content audit/stage15/household-recovery/startup-final.json
Get-Content audit/stage15/household-recovery/install-final.txt
Get-Content audit/stage15/household-recovery/launch-final.txt
Get-Content audit/stage15/household-recovery/startup-final.json



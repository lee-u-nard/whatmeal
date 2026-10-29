$ErrorActionPreference = 'Stop'
$adb = 'C:/Android/Sdk/platform-tools/adb.exe'
$device = 'emulator-5564'
$folder = 'audit/stage15/provider-local-fixes'
& $adb -s $device shell uiautomator dump /sdcard/whatmeal-provider-ready.xml *> "$folder/ui-dump.txt"
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect the current Android screen.' }
& $adb -s $device pull /sdcard/whatmeal-provider-ready.xml "$folder/ready.xml" *> "$folder/ui-pull.txt"
if ($LASTEXITCODE -ne 0) { throw 'Could not retrieve the Android screen state.' }
$screen = Get-Content -LiteralPath "$folder/ready.xml" -Raw
$activity = (& $adb -s $device shell dumpsys window | Select-String 'mCurrentFocus' | Out-String)
$appProcess = (& $adb -s $device shell pidof com.example.whatmeal.showcase).Trim()
if (!$appProcess) { throw 'The separate demo process is not running.' }
& $adb -s $device logcat -d --pid=$appProcess -v brief 2>&1 | ForEach-Object {
  $_.ToString() -replace '(?i)(Bearer\s+)[A-Za-z0-9._-]+','$1[redacted]' -replace '(?i)((?:apiKey|oobCode|token)=)[^&\s]+','$1[redacted]' -replace '(about user \()[^)]+\)','$1[uid-redacted])'
} | Set-Content "$folder/startup-log.txt"
$log = Get-Content -LiteralPath "$folder/startup-log.txt" -Raw
$originalApk = (& $adb -s $device shell pm path com.example.whatmeal.local) -replace '^package:', ''
if (!$originalApk -or @($originalApk).Count -ne 1) { throw 'Could not verify the original APK identity.' }
$originalDigest = ((& $adb -s $device shell sha256sum $originalApk) -split '\s+')[0]
$protected = Get-Content -LiteralPath "$folder/protected-before.json" -Raw | ConvertFrom-Json
$checks = @($protected | ForEach-Object { [pscustomobject]@{File=$_.File;Unchanged=((Get-FileHash -LiteralPath $_.File -Algorithm SHA256).Hash -eq $_.Sha256)} })
$checks | ConvertTo-Json | Set-Content "$folder/protected-after.json"
$status = [ordered]@{
  AppForeground = $activity.Contains('com.example.whatmeal.showcase')
  HomeVisible = $screen.Contains('Home')
  DemoHouseholdVisible = $screen.Contains('Demo Household')
  SystemAnrVisible = $screen -match 'isn.t responding|keeps stopping'
  FatalRuntimeError = $log -match 'FATAL EXCEPTION|Unhandled Exception|Fatal signal|Uncaught Error'
  OriginalApkUnchanged = $originalDigest -eq 'd80d00fb8a7d2652b6b2558a84d5cd4059a220b90c7709125c1b8a349f3fb06b'
  ProtectedFilesUnchanged = @($checks | Where-Object { !$_.Unchanged }).Count -eq 0
  OriginalDataClearedOrSignedOut = $false
  Scope = 'Actual cold-started showcase release app; original APK identity/hash only, no original cache read.'
}
$status | ConvertTo-Json | Set-Content "$folder/startup.json"
& $adb -s $device shell screencap -p /sdcard/whatmeal-provider-ready.png
& $adb -s $device pull /sdcard/whatmeal-provider-ready.png "$folder/ready.png" *> "$folder/screenshot-pull.txt"
if (!$status.AppForeground -or !$status.HomeVisible -or !$status.DemoHouseholdVisible -or $status.SystemAnrVisible -or $status.FatalRuntimeError -or !$status.OriginalApkUnchanged -or !$status.ProtectedFilesUnchanged) {
  throw 'Startup/preservation check failed. Inspect the saved evidence; no data reset was attempted.'
}
Write-Output 'Cold release startup, demo household, logs and original preservation verified.'

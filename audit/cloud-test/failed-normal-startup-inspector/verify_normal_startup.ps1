$ErrorActionPreference='Stop'
$workspace=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $workspace
try {
  $adb='C:/Android/Sdk/platform-tools/adb.exe'
  $device='emulator-5564'
  $package='com.example.whatmeal.cloudtest'
  $artifact=Get-Content (Join-Path $PSScriptRoot 'apk.json') -Raw | ConvertFrom-Json
  if($artifact.Package -cne $package -or $artifact.Project -cne 'whatmeal-gemini-test-20261019'){
    throw 'Unexpected final artifact identity.'
  }
  $appProcessId=((& $adb -s $device shell pidof $package) | Out-String).Trim()
  if($LASTEXITCODE -ne 0 -or $appProcessId -notmatch '^\d+$'){throw 'Normal cloud-test process is not running.'}
  $activity=& $adb -s $device shell dumpsys activity activities
  if($LASTEXITCODE -ne 0){throw 'Could not inspect the current activity.'}
  $resumed=($activity | Select-String 'mResumedActivity|topResumedActivity' | Out-String)
  if(!$resumed.Contains($package+'/')){throw 'Cloud-test is not foreground; do not capture another account/app.'}
  & $adb -s $device shell input keyevent KEYCODE_WAKEUP
  if($LASTEXITCODE -ne 0){throw 'Could not wake the test display; no lock/security setting changed.'}
  Start-Sleep -Seconds 3
  $stamp=(Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmssfff')
  $folder=Join-Path $workspace "build/cloudtest-private/evidence/normal-runtime-$stamp"
  New-Item -ItemType Directory -Path $folder | Out-Null
  $deviceXml="/sdcard/whatmeal-cloudtest-$stamp.xml"
  $devicePng="/sdcard/whatmeal-cloudtest-$stamp.png"
  & $adb -s $device shell uiautomator dump $deviceXml *> (Join-Path $folder 'dump.txt')
  if($LASTEXITCODE -ne 0){throw 'Native hierarchy dump failed; no dialog was dismissed.'}
  & $adb -s $device pull $deviceXml (Join-Path $folder 'home.xml') *> (Join-Path $folder 'pull-xml.txt')
  if($LASTEXITCODE -ne 0){throw 'Native hierarchy pull failed.'}
  & $adb -s $device shell screencap -p $devicePng
  if($LASTEXITCODE -ne 0){throw 'Native screenshot failed.'}
  & $adb -s $device pull $devicePng (Join-Path $folder 'home.png') *> (Join-Path $folder 'pull-image.txt')
  if($LASTEXITCODE -ne 0){throw 'Native screenshot pull failed.'}
  & $adb -s $device logcat -d "--pid=$appProcessId" -v brief *> (Join-Path $folder 'startup-private.log')
  if($LASTEXITCODE -ne 0){throw 'Scoped startup log capture failed.'}
  [xml]$tree=Get-Content (Join-Path $folder 'home.xml') -Raw
  $labels=@($tree.SelectNodes('//node') | ForEach-Object {
    $_.GetAttribute('text');$_.GetAttribute('content-desc')
  }) -join "`n"
  $home=$labels -match '(?m)^Home$'
  $saved=$labels -match '(?m)^Saved Plans$'
  $logs=Get-Content (Join-Path $folder 'startup-private.log') -Raw
  $fatal=[regex]::Matches($logs,'(?mi)FATAL EXCEPTION|Unhandled Exception').Count
  $flutterErrors=[regex]::Matches($logs,'(?mi)^E/flutter').Count
  $passed=$home -and $saved -and $fatal -eq 0 -and $flutterErrors -eq 0
  $result=[ordered]@{Package=$package;Project=$artifact.Project;Device=$device;PID=$appProcessId;
    NormalEntrypoint='lib/main.dart';ForegroundVerified=$true;HomeVisible=$home;SavedPlansVisible=$saved;
    FatalUnhandledCount=$fatal;FlutterErrorLineCount=$flutterErrors;Passed=$passed;
    APK_SHA256=$artifact.SHA256;EvidenceFolder=$folder;Screenshot=(Join-Path $folder 'home.png');
    NewAIRequest=$false;OriginalOrDemoOpened=$false;CapturedAt=(Get-Date -Format o)}
  $result | ConvertTo-Json | Set-Content (Join-Path $PSScriptRoot 'normal-runtime.json')
  $result | ConvertTo-Json
  if(!$passed){throw 'Normal startup evidence incomplete or errors present; inspect preserved private screenshot/logs.'}
} finally {Pop-Location}

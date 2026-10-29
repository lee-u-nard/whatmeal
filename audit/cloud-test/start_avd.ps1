$ErrorActionPreference='Stop'
$workspace=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $workspace
try {
  $avdHome=(Resolve-Path 'build/audit-avds').Path
  $expectedAvd=Join-Path $avdHome 'whatmeal-stage9-aosp.avd'
  $avdIni=Get-Content (Join-Path $avdHome 'whatmeal-stage9-aosp.ini')
  $configuredPath=($avdIni | Where-Object { $_ -like 'path=*' }) -replace '^path=',''
  if($configuredPath -cne $expectedAvd){throw 'Unexpected AVD path; never use the private backup as a checkout.'}
  $listeners=[Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners()
  if($listeners | Where-Object {$_.Port -eq 5564}){
    throw 'Dedicated AVD port is occupied; inspect it before launching another instance.'
  }
  $env:ANDROID_AVD_HOME=$avdHome
  $env:ANDROID_HOME=(Resolve-Path 'build/android-sdk-audit').Path
  $env:ANDROID_SDK_ROOT=$env:ANDROID_HOME
  $stamp=(Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmssfff')
  $logs=Join-Path $workspace "build/cloudtest-private/avd-$stamp"
  New-Item -ItemType Directory -Path $logs | Out-Null
  # Proven Stage 15 launch options; no wipe, snapshot load/save, or config edits.
  $avd=Start-Process -FilePath 'C:/Android/Sdk/emulator/emulator.exe' -WindowStyle Hidden -PassThru `
    -WorkingDirectory $workspace -RedirectStandardOutput (Join-Path $logs 'stdout.txt') `
    -RedirectStandardError (Join-Path $logs 'stderr.txt') `
    -ArgumentList @('-avd','whatmeal-stage9-aosp','-no-audio','-no-snapshot','-gpu','host','-memory','1536','-cores','2','-port','5564')
  $adb='C:/Android/Sdk/platform-tools/adb.exe'
  $boot=$false
  for($attempt=0;$attempt -lt 90;$attempt++){
    Start-Sleep -Seconds 2
    if((& $adb -s emulator-5564 shell getprop sys.boot_completed 2>$null) -eq '1'){$boot=$true;break}
    if($avd.HasExited){throw 'AVD process exited; private startup logs preserved.'}
  }
  if(!$boot){throw 'AVD boot incomplete; do not install on another device automatically.'}
  $name=& $adb -s emulator-5564 emu avd name
  if(($name | Select-Object -First 1) -cne 'whatmeal-stage9-aosp'){throw 'Unexpected connected AVD.'}
  # Never manually start the old integration binary and risk an extra AI call.
  & $adb -s emulator-5564 shell am force-stop com.example.whatmeal.cloudtest
  if($LASTEXITCODE -ne 0){throw 'Could not stop only the old cloud-test binary.'}
  [ordered]@{Device='emulator-5564';AVD='whatmeal-stage9-aosp';BootCompleted=$true;PID=$avd.Id;
    WipeData=$false;SnapshotLoadSave=$false;OriginalOrDemoAppOpened=$false} |
    ConvertTo-Json | Set-Content (Join-Path $PSScriptRoot 'avd-start.json')
  Write-Output 'Existing audit AVD booted; only cloudtest force-stopped. No account data reset or backup overwrite.'
} finally {Pop-Location}

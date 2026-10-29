$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Set-Location $workspace
$lock = $null
try {
    . "$PSScriptRoot/demo_health.ps1"
    New-Item -ItemType Directory -Force build/showcase-private | Out-Null
    $lock = [IO.File]::Open((Join-Path $workspace 'build/showcase-private/setup.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
    $shell = (Get-Content build/showcase-shell-path.txt -Raw).Trim()
    $hub = $null
    try { $hub = Invoke-RestMethod 'http://127.0.0.1:4492/emulators' -TimeoutSec 2 } catch { }
    if (!$hub) {
        Start-Process -FilePath $shell -WindowStyle Hidden -WorkingDirectory $workspace -ArgumentList @('-NoProfile','-File',('"' + "$PSScriptRoot/start_backend.ps1" + '"'))
    }
    $adb = 'C:/Android/Sdk/platform-tools/adb.exe'
    if (!((& $adb devices) -match '^emulator-5564\s+device$')) {
        $env:ANDROID_AVD_HOME = (Resolve-Path build/audit-avds).Path
        $env:ANDROID_HOME = (Resolve-Path build/android-sdk-audit).Path
        $env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
        Start-Process -FilePath 'C:/Android/Sdk/emulator/emulator.exe' -WindowStyle Normal -WorkingDirectory $workspace -ArgumentList @('-avd','whatmeal-stage9-aosp','-no-audio','-no-snapshot','-gpu','host','-memory','1536','-cores','2','-port','5564') -RedirectStandardOutput build/showcase-private/avd-stdout.txt -RedirectStandardError build/showcase-private/avd-stderr.txt
    }
    $booted = $false
    for ($attempt = 0; $attempt -lt 90 -and !$booted; $attempt++) {
        $state = & $adb -s emulator-5564 shell getprop sys.boot_completed 2>$null
        $booted = ($LASTEXITCODE -eq 0 -and "$state".Trim() -eq '1')
        if (!$booted) { Start-Sleep -Seconds 2 }
    }
    if (!$booted) { throw 'AVD boot failed; no wipe or reset attempted.' }
    for ($attempt = 0; $attempt -lt 30 -and !(Test-ShowcaseHubReady $hub); $attempt++) {
        try { $hub = Invoke-RestMethod 'http://127.0.0.1:4492/emulators' -TimeoutSec 2 } catch { Start-Sleep -Seconds 2 }
    }
    if (!(Test-ShowcaseHubReady $hub)) { throw 'Separate demo backend unavailable.' }
    & "$PSScriptRoot/verify_integration.ps1"
    if ($LASTEXITCODE -ne 0) { throw 'Integration artifact verification failed.' }
    & "$PSScriptRoot/run_android.ps1"
    if ($LASTEXITCODE -ne 0) { throw 'Full demo UI workflow did not pass.' }
    & "$PSScriptRoot/save_demo.ps1" *> audit/stage15/showcase/save-baseline.txt
    if ($LASTEXITCODE -ne 0) { throw 'Saving prepared demo failed.' }
    & "$PSScriptRoot/final_checks.ps1"
    if ($LASTEXITCODE -ne 0) { throw 'Final Flutter checks failed.' }
    & "$PSScriptRoot/build_tester.ps1"
    if ($LASTEXITCODE -ne 0) { throw 'Demo release build failed.' }
    & "$PSScriptRoot/install_demo.ps1" *> audit/stage15/showcase/install-final.txt
    if ($LASTEXITCODE -ne 0) { throw 'Demo install/start failed.' }
    Set-Content audit/stage15/showcase/setup.exit 0
} catch {
    $_ | Out-String | Set-Content audit/stage15/showcase/setup-failure.txt
    Set-Content audit/stage15/showcase/setup.exit 1
} finally { if ($lock) { $lock.Dispose() } }

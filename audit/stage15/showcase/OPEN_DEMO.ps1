$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Push-Location $workspace
try {
    . "$PSScriptRoot/demo_health.ps1"
    $adb = 'C:/Android/Sdk/platform-tools/adb.exe'
    $shell = (Get-Process -Id $PID).Path
    if (Test-Path build/showcase-shell-path.txt) {
        $savedShell = (Get-Content build/showcase-shell-path.txt -Raw).Trim()
        if (Test-Path -LiteralPath $savedShell) { $shell = $savedShell }
    }
    # Desktop-owned services survive closing this launcher/chat tool. No task,
    # registry setting, firewall rule or automatic recurring job is created.
    $desktopShell = New-Object -ComObject Shell.Application
    $hub = $null
    try { $hub = Invoke-RestMethod 'http://127.0.0.1:4492/emulators' -TimeoutSec 3 } catch { }
    if (!(Test-ShowcaseHubReady $hub)) {
        if (!$hub) {
            $desktopShell.ShellExecute($shell, ('-NoProfile -File "' + "$PSScriptRoot/start_backend.ps1" + '"'), $workspace, 'open', 0)
        }
        for ($attempt = 0; $attempt -lt 30 -and !(Test-ShowcaseHubReady $hub); $attempt++) {
            Start-Sleep -Seconds 2
            try { $hub = Invoke-RestMethod 'http://127.0.0.1:4492/emulators' -TimeoutSec 2 } catch { }
        }
    }
    if (!(Test-ShowcaseHubReady $hub)) {
        throw 'The separate demo backend is unavailable or has unexpected ports. Original backend was not started.'
    }
    $connected = (& $adb devices) -match '^emulator-5564\s+device$'
    if (!$connected) {
        $desktopShell.ShellExecute($shell, ('-NoProfile -File "' + "$PSScriptRoot/start_avd.ps1" + '"'), $workspace, 'open', 0)
    }
    $booted = $false
    for ($attempt = 0; $attempt -lt 60 -and !$booted; $attempt++) {
        $state = & $adb -s emulator-5564 shell getprop sys.boot_completed 2>$null
        $booted = ($LASTEXITCODE -eq 0 -and "$state".Trim() -eq '1')
        if (!$booted) { Start-Sleep -Seconds 2 }
    }
    if (!$booted) { throw 'AVD did not boot in time. No wipe or reset was attempted.' }
    & "$PSScriptRoot/install_demo.ps1"
} finally { Pop-Location }


param([string]$Device = 'emulator-5564')
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Push-Location $workspace
try {
    & "$PSScriptRoot/verify_tester.ps1"
    if ($LASTEXITCODE -ne 0) { throw 'Demo APK verification failed.' }
    $adb = 'C:/Android/Sdk/platform-tools/adb.exe'
    $apk = (Resolve-Path build/stage15/showcase/whatmeal-demo.apk).Path
    & $adb -s $Device install -r $apk
    if ($LASTEXITCODE -ne 0) { throw 'Demo install failed. No uninstall or data clear was attempted.' }
    & $adb -s $Device shell am force-stop com.example.whatmeal.showcase
    if ($LASTEXITCODE -ne 0) { throw 'Could not stop the demo process for its cold start.' }
    & $adb -s $Device shell am start -W -n com.example.whatmeal.showcase/com.example.whatmeal.MainActivity
    if ($LASTEXITCODE -ne 0) { throw 'Demo launch failed.' }
} finally { Pop-Location }

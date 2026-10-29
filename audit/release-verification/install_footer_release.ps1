param([Parameter(Mandatory = $true)][string]$EvidenceRoot)
$ErrorActionPreference = 'Stop'
$evidence = (Resolve-Path -LiteralPath $EvidenceRoot).Path
$adb = 'C:/Android/Sdk/platform-tools/adb.exe'
# Read all output before checking the native exit status. Select-Object -First
# can stop the pipeline before PowerShell receives LASTEXITCODE.
$nameLines = @(& $adb -s emulator-5570 emu avd name)
$nameExit = $LASTEXITCODE
if ($nameExit -ne 0 -or $nameLines[0].Trim() -ne 'whatmeal-release-20261019-211206') {
    throw 'Wrong or unavailable test AVD'
}
$verified = Get-Content -LiteralPath (Join-Path $evidence 'footer-apk-verification.json') -Raw | ConvertFrom-Json
if (!$verified.ExistingTesterCertificateMatched -or $verified.Package -ne 'com.example.whatmeal.showcase' -or $verified.VersionCode -ne '1') {
    throw 'APK approval guard failed'
}
if ((Get-FileHash -LiteralPath $verified.APK -Algorithm SHA256).Hash -ne $verified.SHA256) { throw 'APK changed after verification' }
$before = @(& $adb -s emulator-5570 shell dumpsys package com.example.whatmeal.showcase)
if ($LASTEXITCODE -ne 0 -or !($before -match '\bversionCode=1\b')) { throw 'Installed version is incompatible' }
$before | Set-Content -LiteralPath (Join-Path $evidence 'footer-installed-package-before.txt')
$paths = @(& $adb -s emulator-5570 shell pm path com.example.whatmeal.showcase)
if ($LASTEXITCODE -ne 0 -or $paths.Count -ne 1) { throw 'Unexpected installed package layout' }
$installedPath = ($paths[0] -replace '^package:', '').Trim()
$hashLines = @(& $adb -s emulator-5570 shell sha256sum $installedPath)
if ($LASTEXITCODE -ne 0 -or $hashLines[0].Split(' ')[0].ToUpperInvariant() -ne '5D8C0A30006174443C67296AE94C4B2B77B4DF18EC1FB276319F3B4828D9B0C9') {
    throw 'Installed APK is not the preserved pre-fix tester'
}
& $adb -s emulator-5570 install -r $verified.APK *> (Join-Path $evidence 'footer-install.txt')
$installExit = $LASTEXITCODE
Set-Content -LiteralPath (Join-Path $evidence 'footer-install.exit') -Value $installExit
if ($installExit -ne 0) { throw 'APK update failed' }
$launcher = @(& $adb -s emulator-5570 shell cmd package resolve-activity --brief com.example.whatmeal.showcase)
if ($LASTEXITCODE -ne 0 -or !($launcher -contains 'com.example.whatmeal.showcase/com.example.whatmeal.MainActivity')) {
    throw 'Unexpected launcher activity'
}
& $adb -s emulator-5570 shell am start -W -n com.example.whatmeal.showcase/com.example.whatmeal.MainActivity *> (Join-Path $evidence 'footer-launch.txt')
$launchExit = $LASTEXITCODE
Set-Content -LiteralPath (Join-Path $evidence 'footer-launch.exit') -Value $launchExit
if ($launchExit -ne 0) { throw 'APK launch failed' }
$paths = @(& $adb -s emulator-5570 shell pm path com.example.whatmeal.showcase)
if ($LASTEXITCODE -ne 0 -or $paths.Count -ne 1) { throw 'Unexpected updated package layout' }
$installedPath = ($paths[0] -replace '^package:', '').Trim()
$hashLines = @(& $adb -s emulator-5570 shell sha256sum $installedPath)
$hashExit = $LASTEXITCODE
$digest = $hashLines[0].Split(' ')[0].ToUpperInvariant()
if ($hashExit -ne 0 -or $digest -ne $verified.SHA256) { throw 'Installed artifact hash mismatch' }
[pscustomobject]@{
    AVD=$nameLines[0].Trim(); Device='emulator-5570'; InstallExit=$installExit
    LaunchExit=$launchExit; InstalledSha256=$digest; MatchesBuiltAPK=$true
    UpdatePreservesData=$true; NoUninstallOrClear=$true
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidence 'footer-installation.json')
Get-Content -LiteralPath (Join-Path $evidence 'footer-install.txt')
Get-Content -LiteralPath (Join-Path $evidence 'footer-launch.txt')
Get-Content -LiteralPath (Join-Path $evidence 'footer-installation.json')

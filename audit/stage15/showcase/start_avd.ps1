$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Set-Location $workspace
$env:ANDROID_AVD_HOME = (Resolve-Path build/audit-avds).Path
$env:ANDROID_HOME = (Resolve-Path build/android-sdk-audit).Path
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
Start-Process -FilePath 'C:/Android/Sdk/emulator/emulator.exe' -WindowStyle Normal -WorkingDirectory $workspace -ArgumentList @('-avd','whatmeal-stage9-aosp','-no-audio','-no-snapshot','-gpu','host','-memory','1536','-cores','2','-port','5564') -Wait

$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $workspace
try {
    $env:JAVA_HOME = 'C:/Program Files/Android/Android Studio/jbr'
    $env:PATH = "$env:JAVA_HOME/bin;$env:PATH"
    $apk = Join-Path $workspace 'build/firebase-gemini-test/whatmeal-ai-test.apk'
    $adb = 'C:/Android/Sdk/platform-tools/adb.exe'
    $device = 'emulator-5564'
    $analyzer = 'C:/Android/Sdk/cmdline-tools/latest/bin/apkanalyzer.bat'
    $package = (& $analyzer manifest application-id $apk | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $package -cne 'com.example.whatmeal.aitest') { throw 'Unexpected test APK package.' }
    $project = (& $analyzer resources value --config default --name project_id --type string $apk | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $project -cne 'whatmeal-gemini-test-20261019') { throw 'Unexpected native test Firebase project.' }
    $debuggable = (& $analyzer manifest debuggable $apk | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $debuggable -cne 'true') { throw 'AI test must be debug-only.' }
    & 'C:/Android/Sdk/build-tools/36.0.0/apksigner.bat' verify --verbose $apk *> "$PSScriptRoot/signature.txt"
    if ($LASTEXITCODE -ne 0) { throw 'AI test APK signature is invalid.' }
    $installedBefore = foreach ($appPackage in @('com.example.whatmeal.local', 'com.example.whatmeal.showcase')) {
        $installedPath = ((& $adb -s $device shell pm path $appPackage) -replace '^package:', '').Trim()
        if ($LASTEXITCODE -ne 0 -or !$installedPath) { throw 'Could not verify existing app preservation.' }
        $digest = ((& $adb -s $device shell sha256sum $installedPath) -split '\s+')[0]
        [ordered]@{Package=$appPackage; Sha256=$digest}
    }
    $installedBefore | ConvertTo-Json | Set-Content "$PSScriptRoot/installed-before.json"
    & $adb -s $device install -r $apk *> "$PSScriptRoot/install.txt"
    if ($LASTEXITCODE -ne 0) { throw 'AI test installation failed; no uninstall/reset attempted.' }
    & $adb -s $device shell am force-stop com.example.whatmeal.aitest
    & $adb -s $device shell am start -W -n com.example.whatmeal.aitest/com.example.whatmeal.MainActivity *> "$PSScriptRoot/launch.txt"
    if ($LASTEXITCODE -ne 0) { throw 'AI test startup failed.' }
    [ordered]@{Package=$package; Project=$project; Debuggable=$true; SignatureVerified=$true; InstallExit=0; LaunchExit=0} | ConvertTo-Json | Set-Content "$PSScriptRoot/install.json"
    Write-Output 'Separate AI test APK identity, signature, installation and launch commands passed. No existing app data was cleared.'
} finally { Pop-Location }

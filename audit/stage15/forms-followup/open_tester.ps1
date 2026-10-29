$ErrorActionPreference = 'Stop'
$adb = 'C:/Android/Sdk/platform-tools/adb.exe'
$env:ANDROID_AVD_HOME = (Resolve-Path build/audit-avds).Path
$env:ANDROID_HOME = (Resolve-Path build/android-sdk-audit).Path
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
if (Get-NetTCPConnection -LocalPort 5564 -State Listen -ErrorAction SilentlyContinue) {
    throw 'Dedicated AVD port already occupied; inspect before retrying.'
}
$avd = Start-Process -FilePath 'C:/Android/Sdk/emulator/emulator.exe' -WindowStyle Normal -PassThru -RedirectStandardOutput 'audit/stage15/forms-followup/avd-stdout.txt' -RedirectStandardError 'audit/stage15/forms-followup/avd-stderr.txt' -ArgumentList @('-avd','whatmeal-stage9-aosp','-no-audio','-no-snapshot','-gpu','host','-memory','1536','-cores','2','-port','5564')
Set-Content audit/stage15/forms-followup/avd.pid $avd.Id
$boot = $false
for ($n = 0; $n -lt 36; $n++) {
    Start-Sleep -Seconds 5
    if ((& $adb -s emulator-5564 shell getprop sys.boot_completed 2>$null) -eq '1') {
        $boot = $true
        break
    }
}
if (!$boot) { throw 'AVD boot incomplete; do not install elsewhere.' }
$name = & $adb -s emulator-5564 emu avd name
if (($name | Select-Object -First 1) -ne 'whatmeal-stage9-aosp') { throw 'Unexpected AVD' }
& $adb -s emulator-5564 install -r build/stage15/forms-followup/whatmeal-local-tester.apk > audit/stage15/forms-followup/install.txt
$installResult = $LASTEXITCODE
Set-Content audit/stage15/forms-followup/install.exit $installResult
if ($installResult -ne 0) { throw 'Install failed' }
& $adb -s emulator-5564 shell am start -W -n com.example.whatmeal.local/com.example.whatmeal.MainActivity > audit/stage15/forms-followup/launch.txt
$launchResult = $LASTEXITCODE
Set-Content audit/stage15/forms-followup/launch.exit $launchResult
if ($launchResult -ne 0) { throw 'Launch failed' }
Get-Content audit/stage15/forms-followup/install.txt
Get-Content audit/stage15/forms-followup/launch.txt


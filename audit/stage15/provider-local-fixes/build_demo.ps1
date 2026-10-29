$ErrorActionPreference = 'Stop'
$env:JAVA_HOME = 'C:/Program Files/Android/Android Studio/jbr'
$env:PATH = "$env:JAVA_HOME/bin;$env:PATH"
$env:JAVA_TOOL_OPTIONS = '-Djdk.net.unixdomain.tmpdir="' + (Resolve-Path audit/stage15).Path + '"'
$env:GRADLE_OPTS = '-Dorg.gradle.jvmargs=-Xmx768m'
[Environment]::SetEnvironmentVariable('ORG_GRADLE_PROJECT_kotlin.compiler.execution.strategy', 'in-process', 'Process')
$env:WHATMEAL_TESTER_SIGNING = 'true'
& 'C:/Users/ASUS V16/flutter_windows_3.44.5-stable/flutter/bin/flutter.bat' build apk --release --flavor showcase --target lib/main.dart --dart-define=WHATMEAL_EMULATOR_HOST=10.0.2.2 *> audit/stage15/provider-local-fixes/build-demo.txt
$result = $LASTEXITCODE
Set-Content audit/stage15/provider-local-fixes/build-demo.exit $result
Get-Content audit/stage15/provider-local-fixes/build-demo.txt -Tail 10
if ($result -ne 0) { exit $result }
$destination = 'build/stage15/showcase/whatmeal-demo.apk'
if (!(Test-Path build/stage15/showcase/whatmeal-demo-before-provider-fixes.apk)) {
  Copy-Item -LiteralPath $destination -Destination build/stage15/showcase/whatmeal-demo-before-provider-fixes.apk
}
Copy-Item -LiteralPath build/app/outputs/flutter-apk/app-showcase-release.apk -Destination $destination
& ./audit/stage15/provider-local-fixes/verify_tester.ps1
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
New-Item -ItemType Directory -Force build/final | Out-Null
Copy-Item -LiteralPath $destination -Destination build/final/whatmeal-demo.apk
$adb = 'C:/Android/Sdk/platform-tools/adb.exe'
& $adb -s emulator-5564 install -r build/final/whatmeal-demo.apk *> audit/stage15/provider-local-fixes/install-demo.txt
if ($LASTEXITCODE -ne 0) { throw 'Demo update failed; no data clear or uninstall was attempted.' }
& $adb -s emulator-5564 shell am force-stop com.example.whatmeal.showcase
& $adb -s emulator-5564 shell am start -W -n com.example.whatmeal.showcase/com.example.whatmeal.MainActivity *> audit/stage15/provider-local-fixes/launch-demo.txt
$result = $LASTEXITCODE
Set-Content audit/stage15/provider-local-fixes/launch-demo.exit $result
Get-Content audit/stage15/provider-local-fixes/launch-demo.txt
exit $result

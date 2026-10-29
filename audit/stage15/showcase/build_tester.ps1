$ErrorActionPreference = 'Stop'
$env:JAVA_HOME = 'C:/Program Files/Android/Android Studio/jbr'
$env:PATH = "$env:JAVA_HOME/bin;$env:PATH"
$env:JAVA_TOOL_OPTIONS = '-Djdk.net.unixdomain.tmpdir="' + (Resolve-Path audit/stage15).Path + '"'
$env:GRADLE_OPTS = '-Dorg.gradle.jvmargs=-Xmx768m'
[Environment]::SetEnvironmentVariable('ORG_GRADLE_PROJECT_kotlin.compiler.execution.strategy', 'in-process', 'Process')
$env:WHATMEAL_TESTER_SIGNING = 'true'
& 'C:/Users/ASUS V16/flutter_windows_3.44.5-stable/flutter/bin/flutter.bat' build apk --release --flavor showcase --target lib/main.dart --dart-define=WHATMEAL_EMULATOR_HOST=10.0.2.2 *> audit/stage15/showcase/build-tester.txt
$buildResult = $LASTEXITCODE
Set-Content audit/stage15/showcase/build-tester.exit $buildResult
Get-Content audit/stage15/showcase/build-tester.txt -Tail 10
if ($buildResult -ne 0) { exit $buildResult }
New-Item -ItemType Directory -Force build/stage15/showcase | Out-Null
Copy-Item build/app/outputs/flutter-apk/app-showcase-release.apk build/stage15/showcase/whatmeal-demo.apk
& ./audit/stage15/showcase/verify_tester.ps1









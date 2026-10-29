$ErrorActionPreference = 'Stop'
$env:JAVA_HOME = 'C:/Program Files/Android/Android Studio/jbr'
$env:PATH = "$env:JAVA_HOME/bin;$env:PATH"
$env:JAVA_TOOL_OPTIONS = '-Djdk.net.unixdomain.tmpdir="' + (Resolve-Path audit/stage15).Path + '"'
$env:GRADLE_OPTS = '-Dorg.gradle.jvmargs=-Xmx768m'
[Environment]::SetEnvironmentVariable('ORG_GRADLE_PROJECT_kotlin.compiler.execution.strategy', 'in-process', 'Process')
& 'C:/Users/ASUS V16/flutter_windows_3.44.5-stable/flutter/bin/flutter.bat' build apk --debug --flavor local --target integration_test/shared_food_recovery_test.dart --target-platform android-x64 --dart-define=WHATMEAL_EMULATOR_HOST=10.0.2.2 --dart-define=WHATMEAL_RECOVERY_AUTH_PORT=9199 *> audit/stage15/demo-handoff/build-integration.txt
$buildResult = $LASTEXITCODE
Set-Content audit/stage15/demo-handoff/build-integration.exit $buildResult
Get-Content audit/stage15/demo-handoff/build-integration.txt -Tail 8
if ($buildResult -ne 0) { exit $buildResult }
New-Item -ItemType Directory -Force build/stage15/demo-handoff | Out-Null
Copy-Item build/app/outputs/flutter-apk/app-local-debug.apk build/stage15/demo-handoff/integration.apk




$ErrorActionPreference = 'Stop'
$env:JAVA_HOME = 'C:/Program Files/Android/Android Studio/jbr'
$env:PATH = "$env:JAVA_HOME/bin;$env:PATH"
$env:JAVA_TOOL_OPTIONS = '-Djdk.net.unixdomain.tmpdir="' + (Resolve-Path audit/stage15).Path + '"'
$env:GRADLE_OPTS = '-Dorg.gradle.jvmargs=-Xmx768m'
[Environment]::SetEnvironmentVariable('ORG_GRADLE_PROJECT_kotlin.compiler.execution.strategy', 'in-process', 'Process')
& 'C:/Users/ASUS V16/flutter_windows_3.44.5-stable/flutter/bin/flutter.bat' build apk --debug --flavor showcase --target integration_test/showcase_workflow_test.dart --target-platform android-x64 --dart-define=WHATMEAL_EMULATOR_HOST=10.0.2.2 *> audit/stage15/showcase/build-integration.txt
$buildResult = $LASTEXITCODE
Set-Content audit/stage15/showcase/build-integration.exit $buildResult
Get-Content audit/stage15/showcase/build-integration.txt -Tail 8
if ($buildResult -ne 0) { exit $buildResult }
New-Item -ItemType Directory -Force build/stage15/showcase | Out-Null
Copy-Item build/app/outputs/flutter-apk/app-showcase-debug.apk build/stage15/showcase/integration.apk






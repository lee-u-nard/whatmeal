$ErrorActionPreference = 'Stop'
$env:JAVA_HOME = 'C:/Program Files/Android/Android Studio/jbr'
$env:PATH = "$env:JAVA_HOME/bin;$env:PATH"
$env:JAVA_TOOL_OPTIONS = '-Djdk.net.unixdomain.tmpdir="' + (Resolve-Path audit/stage15).Path + '"'
$env:GRADLE_OPTS = '-Dorg.gradle.jvmargs=-Xmx768m'
[Environment]::SetEnvironmentVariable('ORG_GRADLE_PROJECT_kotlin.compiler.execution.strategy', 'in-process', 'Process')
& 'C:/Users/ASUS V16/flutter_windows_3.44.5-stable/flutter/bin/flutter.bat' build apk --debug --flavor showcase --target integration_test/provider_settings_local_test.dart --target-platform android-x64 --dart-define-from-file=build/showcase-private/provider-defines.json *> audit/stage15/provider-local-fixes/build-settings.txt
$result = $LASTEXITCODE
Set-Content audit/stage15/provider-local-fixes/build-settings.exit $result
Get-Content audit/stage15/provider-local-fixes/build-settings.txt -Tail 10
if ($result -ne 0) { exit $result }
Copy-Item -LiteralPath build/app/outputs/flutter-apk/app-showcase-debug.apk -Destination build/stage15/showcase/provider-settings-test.apk
$badging = & 'C:/Android/Sdk/build-tools/36.0.0/aapt2.exe' dump badging build/stage15/showcase/provider-settings-test.apk
if ($LASTEXITCODE -ne 0 -or !($badging -match "package: name='com.example.whatmeal.showcase'")) { throw 'Refusing incorrect integration APK' }
Write-Output 'Separate showcase test APK prepared.'

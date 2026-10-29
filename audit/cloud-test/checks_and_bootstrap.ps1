$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $workspace
try {
  $flutter = 'C:/Users/ASUS V16/flutter_windows_3.44.5-stable/flutter/bin/flutter.bat'
  & $flutter test test/cloud_test_environment_test.dart test/ai_test_environment_test.dart test/showcase_isolation_test.dart --reporter expanded *> "$PSScriptRoot/guard-tests.txt"
  $result=$LASTEXITCODE; Set-Content "$PSScriptRoot/guard-tests.exit" $result
  Get-Content "$PSScriptRoot/guard-tests.txt" -Tail 4
  if ($result -ne 0) { exit $result }
  $env:JAVA_HOME = 'C:/Program Files/Android/Android Studio/jbr'
  $env:PATH = "$env:JAVA_HOME/bin;$env:PATH"
  $env:JAVA_TOOL_OPTIONS = '-Djdk.net.unixdomain.tmpdir="' + $PSScriptRoot + '"'
  $env:GRADLE_OPTS = '-Dorg.gradle.jvmargs=-Xmx768m'
  [Environment]::SetEnvironmentVariable('ORG_GRADLE_PROJECT_kotlin.compiler.execution.strategy','in-process','Process')
  & $flutter build apk --debug --flavor cloudtest --target lib/main.dart *> "$PSScriptRoot/build-bootstrap.txt"
  $result=$LASTEXITCODE; Set-Content "$PSScriptRoot/build-bootstrap.exit" $result
  Get-Content "$PSScriptRoot/build-bootstrap.txt" -Tail 8
  if ($result -ne 0) { exit $result }
  Copy-Item -LiteralPath build/app/outputs/flutter-apk/app-cloudtest-debug.apk -Destination build/cloud-test/bootstrap.apk
} finally { Pop-Location }

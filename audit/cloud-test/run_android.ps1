param([ValidateSet('generate','reopen')][string]$Phase='generate')
$ErrorActionPreference='Stop'
$workspace=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $workspace
try {
  & 'C:/Program Files/nodejs/node.exe' -e "require('./audit/cloud-test/candidate_evidence.cjs').readVerifiedDeployment(); console.log('Exact candidate and isolated deployed-source evidence verified before Android acceptance.');"
  if($LASTEXITCODE -ne 0){throw 'Android cloud acceptance requires verified test-project rules.'}
  $flutter='C:/Users/ASUS V16/flutter_windows_3.44.5-stable/flutter/bin/flutter.bat'
  $defines="build/cloudtest-private/defines-$Phase.json"
  if (!(Test-Path -LiteralPath $defines)) { throw 'Missing private test credentials/phase definitions.' }
  # Preserve each previous attempt before fixed-name Flutter/driver outputs are
  # replaced. Raw native payloads and logs must stay in the ignored directory.
  $stamp=(Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss-fff')
  $privateArchive=Join-Path $workspace "build/cloudtest-private/attempts/$stamp-$Phase"
  $publicArchive=Join-Path $PSScriptRoot "attempts/$stamp-$Phase"
  foreach($relative in @("build-$Phase-private.log","android-$Phase-private.log",
      "evidence/android-$Phase.json","evidence/android-$Phase-batch-private.json")){
    $source=Join-Path $workspace "build/cloudtest-private/$relative"
    if(Test-Path -LiteralPath $source){
      New-Item -ItemType Directory -Force $privateArchive | Out-Null
      Copy-Item -LiteralPath $source -Destination (Join-Path $privateArchive ([IO.Path]::GetFileName($source)))
    }
  }
  foreach($name in @("build-$Phase.txt","build-$Phase.exit","android-$Phase.txt","android-$Phase.exit","cold-stop-$Phase.txt")){
    $source=Join-Path $PSScriptRoot $name
    if(Test-Path -LiteralPath $source){
      New-Item -ItemType Directory -Force $publicArchive | Out-Null
      Copy-Item -LiteralPath $source -Destination (Join-Path $publicArchive $name)
    }
  }
  $env:JAVA_HOME='C:/Program Files/Android/Android Studio/jbr'
  $env:PATH="$env:JAVA_HOME/bin;$env:PATH"
  $env:JAVA_TOOL_OPTIONS='-Djdk.net.unixdomain.tmpdir="' + $PSScriptRoot + '"'
  $env:GRADLE_OPTS='-Dorg.gradle.jvmargs=-Xmx768m'
  [Environment]::SetEnvironmentVariable('ORG_GRADLE_PROJECT_kotlin.compiler.execution.strategy','in-process','Process')
  $privateBuild="build/cloudtest-private/build-$Phase-private.log"
  & $flutter build apk --debug --flavor cloudtest --target integration_test/cloud_generation_persistence_test.dart "--dart-define-from-file=$defines" *> $privateBuild
  $result=$LASTEXITCODE; Set-Content "$PSScriptRoot/build-$Phase.exit" $result
  & 'C:/Program Files/nodejs/node.exe' "$PSScriptRoot/sanitize_log.cjs" $privateBuild "$PSScriptRoot/build-$Phase.txt"
  if($LASTEXITCODE -ne 0){throw 'Build-log sanitization failed; refusing to display stale or private output.'}
  Get-Content "$PSScriptRoot/build-$Phase.txt" -Tail 8
  if ($result -ne 0) { exit $result }
  $binary="build/cloudtest-private/cloudtest-$Phase.apk"
  Copy-Item -LiteralPath build/app/outputs/flutter-apk/app-cloudtest-debug.apk -Destination $binary
  & 'C:/Android/Sdk/platform-tools/adb.exe' -s emulator-5564 shell am force-stop com.example.whatmeal.cloudtest
  if ($LASTEXITCODE -ne 0) { throw 'Could not stop only the cloudtest package before cold launch.' }
  Set-Content "$PSScriptRoot/cold-stop-$Phase.txt" ('Only com.example.whatmeal.cloudtest force-stopped at ' + (Get-Date).ToUniversalTime().ToString('o'))
  $privateRun="build/cloudtest-private/android-$Phase-private.log"
  & $flutter drive --driver=test_driver/cloud_generation_persistence.dart --target=integration_test/cloud_generation_persistence_test.dart "--use-application-binary=$binary" --flavor=cloudtest -d emulator-5564 --keep-app-running *> $privateRun
  $result=$LASTEXITCODE; Set-Content "$PSScriptRoot/android-$Phase.exit" $result
  & 'C:/Program Files/nodejs/node.exe' "$PSScriptRoot/sanitize_log.cjs" $privateRun "$PSScriptRoot/android-$Phase.txt"
  if($LASTEXITCODE -ne 0){throw 'Run-log sanitization failed; refusing to display stale or private output.'}
  Get-Content "$PSScriptRoot/android-$Phase.txt" -Tail 25
  exit $result
} finally { Pop-Location }

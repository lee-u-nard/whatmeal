$ErrorActionPreference='Stop'
$workspace=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $workspace
try {
  # Refuse a final build without executed evidence for this exact candidate.
  # This is a local evidence check only; it never deploys or accesses Firebase.
  & 'C:/Program Files/nodejs/node.exe' -e "require('./audit/cloud-test/candidate_evidence.cjs').readVerifiedDeployment(); console.log('Exact candidate security and isolated deployed-source evidence verified before final build.');"
  if($LASTEXITCODE -ne 0){throw 'Final APK is blocked until exact candidate security acceptance and test-project source verification pass.'}
  $env:JAVA_HOME='C:/Program Files/Android/Android Studio/jbr'
  $env:PATH="$env:JAVA_HOME/bin;$env:PATH"
  $env:JAVA_TOOL_OPTIONS='-Djdk.net.unixdomain.tmpdir="' + $PSScriptRoot + '"'
  $env:GRADLE_OPTS='-Dorg.gradle.jvmargs=-Xmx768m'
  [Environment]::SetEnvironmentVariable('ORG_GRADLE_PROJECT_kotlin.compiler.execution.strategy','in-process','Process')
  $flutter='C:/Users/ASUS V16/flutter_windows_3.44.5-stable/flutter/bin/flutter.bat'
  # Normal app entrypoint: no account/password integration defines in this APK.
  & $flutter build apk --debug --flavor cloudtest --target lib/main.dart *> "$PSScriptRoot/build-final.txt"
  $buildExit=$LASTEXITCODE; Set-Content "$PSScriptRoot/build-final.exit" $buildExit
  if($buildExit -ne 0){throw 'Final cloud test build failed.'}
  # Inspect the raw build first. A rejected binary must never receive the final
  # handoff filename, especially if integration credential defines leaked in.
  $apk=Join-Path $workspace 'build/app/outputs/flutter-apk/app-cloudtest-debug.apk'
  $analyzer='C:/Android/Sdk/cmdline-tools/latest/bin/apkanalyzer.bat'
  $package=(& $analyzer manifest application-id $apk | Out-String).Trim()
  if($LASTEXITCODE -ne 0 -or $package -cne 'com.example.whatmeal.cloudtest'){throw 'Unexpected package.'}
  $project=(& $analyzer resources value --config default --name project_id --type string $apk | Out-String).Trim()
  if($LASTEXITCODE -ne 0 -or $project -cne 'whatmeal-gemini-test-20261019'){throw 'Unexpected Firebase project.'}
  $appId=(& $analyzer resources value --config default --name google_app_id --type string $apk | Out-String).Trim()
  if($LASTEXITCODE -ne 0 -or $appId -cne '1:952163528165:android:e184bb528e406cff95530c'){throw 'Unexpected Firebase Android app.'}
  $debuggable=(& $analyzer manifest debuggable $apk | Out-String).Trim()
  if($LASTEXITCODE -ne 0 -or $debuggable -cne 'true'){throw 'Cloud test must stay debug-only.'}
  & 'C:/Android/Sdk/build-tools/36.0.0/apksigner.bat' verify --verbose $apk *> "$PSScriptRoot/signature.txt"
  if($LASTEXITCODE -ne 0){throw 'Signature verification failed.'}
  & 'C:/Program Files/nodejs/node.exe' "$PSScriptRoot/verify_no_fixture_credentials.cjs" $apk "$PSScriptRoot/fixture-credentials-absence.json"
  if($LASTEXITCODE -ne 0){throw 'Fixture credential absence verification failed; refusing to install or distribute the APK.'}
  $fixtureScan=Get-Content "$PSScriptRoot/fixture-credentials-absence.json" -Raw | ConvertFrom-Json
  $verifiedBuildHash=$fixtureScan.apkSha256
  if(!$fixtureScan.passed -or $verifiedBuildHash -cnotmatch '^[0-9A-F]{64}$' -or
     (Get-FileHash $apk -Algorithm SHA256).Hash -cne $verifiedBuildHash){
    throw 'Built APK changed after fixture credential scan; refusing final artifact.'
  }
  $finalApk=Join-Path $workspace 'build/cloud-test/whatmeal-cloud-test.apk'
  if(Test-Path -LiteralPath $finalApk){
    $previousApk=Join-Path $workspace ('build/cloud-test/previous-final-' + (Get-Date -Format 'yyyyMMdd-HHmmssfff') + '.apk')
    if(Test-Path -LiteralPath $previousApk){throw 'Previous final archive exists; refusing to overwrite.'}
    Copy-Item -LiteralPath $finalApk -Destination $previousApk
  }
  Copy-Item -LiteralPath $apk -Destination $finalApk
  if((Get-FileHash $finalApk -Algorithm SHA256).Hash -cne $verifiedBuildHash){throw 'Final APK copy differs from verified bytes.'}
  $apk=$finalApk
  $adb='C:/Android/Sdk/platform-tools/adb.exe';$device='emulator-5564'
  $preserved=foreach($appPackage in @('com.example.whatmeal.local','com.example.whatmeal.showcase')){
    $installedPath=((& $adb -s $device shell pm path $appPackage) -replace '^package:','').Trim()
    if($LASTEXITCODE -ne 0 -or !$installedPath){throw 'Could not verify preserved app.'}
    $digest=((& $adb -s $device shell sha256sum $installedPath) -split '\s+')[0]
    if($LASTEXITCODE -ne 0){throw 'Could not hash preserved APK.'}
    [ordered]@{Package=$appPackage;SHA256=$digest}
  }
  $preserved | ConvertTo-Json | Set-Content "$PSScriptRoot/installed-before-final.json"
  & $adb -s $device install -r $apk *> "$PSScriptRoot/install-final.txt"
  if($LASTEXITCODE -ne 0){throw 'Install failed; no uninstall/data reset attempted.'}
  & $adb -s $device shell am force-stop com.example.whatmeal.cloudtest
  if($LASTEXITCODE -ne 0){throw 'Could not stop only cloud test.'}
  & $adb -s $device shell am start -W -n com.example.whatmeal.cloudtest/com.example.whatmeal.MainActivity *> "$PSScriptRoot/launch-final.txt"
  if($LASTEXITCODE -ne 0){throw 'Launch command failed.'}
  $after=foreach($before in $preserved){
    $installedPath=((& $adb -s $device shell pm path $before.Package) -replace '^package:','').Trim()
    if($LASTEXITCODE -ne 0 -or !$installedPath){throw 'Could not verify preserved app after install.'}
    $digest=((& $adb -s $device shell sha256sum $installedPath) -split '\s+')[0]
    if($LASTEXITCODE -ne 0){throw 'Could not hash preserved APK after install.'}
    [ordered]@{Package=$before.Package;BeforeSHA256=$before.SHA256;AfterSHA256=$digest;Unchanged=($digest -ceq $before.SHA256)}
  }
  $after | ConvertTo-Json | Set-Content "$PSScriptRoot/installed-preservation.json"
  if(@($after | Where-Object { !$_.Unchanged }).Count -ne 0){throw 'Existing APK preservation check failed.'}
  [ordered]@{Path=$apk;Package=$package;Project=$project;AppId=$appId;Debuggable=$true;BuildExit=$buildExit;
    SignatureVerified=$true;FixtureCredentialsAbsent=$true;InstallExit=0;LaunchCommandExit=0;Bytes=(Get-Item $apk).Length;
    SHA256=(Get-FileHash $apk -Algorithm SHA256).Hash;Entrypoint='lib/main.dart; no integration credential defines'} |
    ConvertTo-Json | Set-Content "$PSScriptRoot/apk.json"
  Write-Output 'Separate normal cloud-test APK built, identity/signature verified, installed and launch command completed. Inspect runtime separately.'
} finally { Pop-Location }

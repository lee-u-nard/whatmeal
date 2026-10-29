$ErrorActionPreference='Stop'
$workspace=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $workspace
try {
  $flutter='C:/Users/ASUS V16/flutter_windows_3.44.5-stable/flutter/bin/flutter.bat'
  $checks=@(
    @{Name='draft-recovery-tests';Arguments=@('test','--no-pub','test/generated_plan_persistence_test.dart','test/generated_meal_roundtrip_test.dart','test/firestore_batch_capture_test.dart')},
    @{Name='flutter-analysis';Arguments=@('analyze','--no-pub')},
    @{Name='flutter-tests';Arguments=@('test','--no-pub')}
  )
  $archive=Join-Path $PSScriptRoot ('attempts/flutter-' + (Get-Date -Format 'yyyyMMdd-HHmmssfff'))
  New-Item -ItemType Directory -Path $archive | Out-Null
  foreach($check in $checks){
    $log=Join-Path $PSScriptRoot ($check.Name+'.txt')
    $exitFile=Join-Path $PSScriptRoot ($check.Name+'.exit')
    foreach($previous in @($log,$exitFile)){
      if(Test-Path -LiteralPath $previous){Copy-Item -LiteralPath $previous -Destination $archive}
    }
    $arguments=$check.Arguments
    & $flutter @arguments *> $log
    $result=$LASTEXITCODE
    Set-Content -LiteralPath $exitFile $result
    Write-Output ($check.Name + ': exit ' + $result)
    Get-Content -LiteralPath $log -Tail 14
    if($result -ne 0){exit $result}
  }
} finally {Pop-Location}

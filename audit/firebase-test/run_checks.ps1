$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $workspace
try {
    $flutter = 'C:/Users/ASUS V16/flutter_windows_3.44.5-stable/flutter/bin/flutter.bat'
    & $flutter test test/ai_test_environment_test.dart test/showcase_isolation_test.dart --reporter expanded *> "$PSScriptRoot/focused-tests.txt"
    $result = $LASTEXITCODE
    Set-Content "$PSScriptRoot/focused-tests.exit" $result
    Get-Content "$PSScriptRoot/focused-tests.txt" -Tail 5
    if ($result -ne 0) { exit $result }
    & $flutter test --reporter expanded *> "$PSScriptRoot/flutter-tests.txt"
    $result = $LASTEXITCODE
    Set-Content "$PSScriptRoot/flutter-tests.exit" $result
    Get-Content "$PSScriptRoot/flutter-tests.txt" -Tail 5
    if ($result -ne 0) { exit $result }
    & $flutter analyze *> "$PSScriptRoot/analyze.txt"
    $result = $LASTEXITCODE
    Set-Content "$PSScriptRoot/analyze.exit" $result
    Get-Content "$PSScriptRoot/analyze.txt" -Tail 8
    exit $result
} finally { Pop-Location }

$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $workspace
try {
    $env:JAVA_HOME = 'C:/Program Files/Android/Android Studio/jbr'
    $env:PATH = "$env:JAVA_HOME/bin;$env:PATH"
    $env:JAVA_TOOL_OPTIONS = '-Djdk.net.unixdomain.tmpdir="' + $PSScriptRoot + '"'
    $env:GRADLE_OPTS = '-Dorg.gradle.jvmargs=-Xmx768m'
    [Environment]::SetEnvironmentVariable('ORG_GRADLE_PROJECT_kotlin.compiler.execution.strategy', 'in-process', 'Process')
    & 'C:/Users/ASUS V16/flutter_windows_3.44.5-stable/flutter/bin/flutter.bat' build apk --debug --flavor aitest --target lib/main_ai_test.dart *> "$PSScriptRoot/build.txt"
    $result = $LASTEXITCODE
    Set-Content "$PSScriptRoot/build.exit" $result
    Get-Content "$PSScriptRoot/build.txt" -Tail 12
    if ($result -ne 0) { exit $result }
    $output = Join-Path $workspace 'build/firebase-gemini-test/whatmeal-ai-test.apk'
    Copy-Item -LiteralPath 'build/app/outputs/flutter-apk/app-aitest-debug.apk' -Destination $output
    $artifact = Get-Item -LiteralPath $output
    [ordered]@{Path=$output; Bytes=$artifact.Length; Sha256=(Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash; Package='com.example.whatmeal.aitest'; Project='whatmeal-gemini-test-20261019'; DebugOnly=$true} | ConvertTo-Json | Set-Content "$PSScriptRoot/apk.json"
} finally { Pop-Location }

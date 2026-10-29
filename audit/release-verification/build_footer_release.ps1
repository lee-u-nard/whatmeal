param([Parameter(Mandatory = $true)][string]$EvidenceRoot)
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$evidence = (Resolve-Path -LiteralPath $EvidenceRoot).Path
$allowedEvidence = Join-Path $workspace 'build/release-safety-audit'
if (!$evidence.StartsWith($allowedEvidence + [IO.Path]::DirectorySeparatorChar)) {
    throw 'Evidence directory must be inside the release audit workspace'
}
$source = (Get-Content -LiteralPath (Join-Path $evidence 'footer-build-source.txt') -Raw).Trim()
$expectedSource = Join-Path $workspace 'build/rf-20261020/source'
if ((Resolve-Path -LiteralPath $source).Path -ne (Resolve-Path -LiteralPath $expectedSource).Path) {
    throw 'Unexpected isolated source directory'
}
if (!(Test-Path -LiteralPath (Join-Path $evidence 'footer-full-tests.exit')) -or
    (Get-Content -LiteralPath (Join-Path $evidence 'footer-full-tests.exit') -Raw).Trim() -ne '0' -or
    !(Test-Path -LiteralPath (Join-Path $evidence 'footer-analyze.exit')) -or
    (Get-Content -LiteralPath (Join-Path $evidence 'footer-analyze.exit') -Raw).Trim() -ne '0') {
    throw 'Final regression suite and analysis must pass before building'
}
$output = Join-Path $workspace 'build/release-request/showcase-footer-20261020'
if (Test-Path -LiteralPath $output) { throw 'Refusing to replace an existing release output' }
New-Item -ItemType Directory -Path $output | Out-Null
$env:JAVA_HOME = 'C:/Program Files/Android/Android Studio/jbr'
$env:PATH = "$env:JAVA_HOME/bin;$env:PATH"
$env:JAVA_TOOL_OPTIONS = '-Djdk.net.unixdomain.tmpdir="' + $evidence + '"'
$env:GRADLE_OPTS = '-Dorg.gradle.jvmargs=-Xmx768m'
[Environment]::SetEnvironmentVariable('ORG_GRADLE_PROJECT_kotlin.compiler.execution.strategy', 'in-process', 'Process')
$env:WHATMEAL_TESTER_SIGNING = 'true'
$flutter = 'C:/Users/ASUS V16/flutter_windows_3.44.5-stable/flutter/bin/flutter.bat'
Push-Location -LiteralPath $source
try {
    & $flutter pub get --offline --enforce-lockfile *> (Join-Path $evidence 'footer-copy-pub-get.txt')
    $pubExit = $LASTEXITCODE
    Set-Content -LiteralPath (Join-Path $evidence 'footer-copy-pub-get.exit') -Value $pubExit
    if ($pubExit -ne 0) { throw "Source-copy dependency resolution failed: $pubExit" }
    & $flutter build apk --release --flavor showcase --target lib/main.dart --dart-define=WHATMEAL_EMULATOR_HOST=10.0.2.2 *> (Join-Path $evidence 'footer-build.txt')
    $buildExit = $LASTEXITCODE
    Set-Content -LiteralPath (Join-Path $evidence 'footer-build.exit') -Value $buildExit
    if ($buildExit -ne 0) { throw "Isolated release build failed: $buildExit" }
    $apk = Join-Path $source 'build/app/outputs/flutter-apk/app-showcase-release.apk'
    if (!(Test-Path -LiteralPath $apk)) { throw 'Built APK is missing' }
    $target = Join-Path $output 'whatmeal-showcase-release.apk'
    Copy-Item -LiteralPath $apk -Destination $target
    [pscustomobject]@{
        APK = $target
        SHA256 = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
        Bytes = (Get-Item -LiteralPath $target).Length
        Source = $source
        PubGetExit = $pubExit
        BuildExit = $buildExit
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidence 'footer-built-artifact.json')
    Get-Content -LiteralPath (Join-Path $evidence 'footer-build.txt') -Tail 8
    Get-Content -LiteralPath (Join-Path $evidence 'footer-built-artifact.json')
} finally {
    Pop-Location
}

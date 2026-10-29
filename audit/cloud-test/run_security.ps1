$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $workspace
try {
    $env:JAVA_HOME = 'C:/Program Files/Android/Android Studio/jbr'
    $env:PATH = "$env:JAVA_HOME/bin;$env:PATH"
    $env:JAVA_TOOL_OPTIONS = '-Djdk.net.unixdomain.tmpdir="' + $PSScriptRoot + '"'
    & 'C:/Program Files/nodejs/npx.cmd' -y firebase-tools@latest emulators:exec --only firestore --project demo-whatmeal-cloud-security --config build/cloud-test/security.firebase.json 'node build/cloud-test/security_acceptance.mjs' *> "$PSScriptRoot/security.txt"
    $result = $LASTEXITCODE
    Set-Content "$PSScriptRoot/security.exit" $result
    Get-Content "$PSScriptRoot/security.txt" -Tail 12
    exit $result
} finally { Pop-Location }

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Push-Location $projectRoot
$previousJavaHome = $env:JAVA_HOME
$previousJavaOptions = $env:JAVA_TOOL_OPTIONS
$previousPath = $env:PATH
try {
  $env:JAVA_HOME = 'C:/Program Files/Android/Android Studio/jbr'
  $env:PATH = "$env:JAVA_HOME/bin;$env:PATH"
  $env:JAVA_TOOL_OPTIONS = '-Djdk.net.unixdomain.tmpdir="' + $PSScriptRoot + '"'
  & firebase emulators:exec --only firestore,auth --project demo-whatmeal-audit --config firebase.audit.json 'node audit/stage3/security_acceptance.mjs && node audit/stage7/two_account_acceptance.mjs'
  if ($LASTEXITCODE -ne 0) { throw 'Local acceptance failed.' }
} finally {
  $env:JAVA_HOME = $previousJavaHome
  $env:JAVA_TOOL_OPTIONS = $previousJavaOptions
  $env:PATH = $previousPath
  Pop-Location
}

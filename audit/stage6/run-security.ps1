# Runs only the isolated demo emulator; never selects or deploys a real project.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Push-Location $projectRoot
$previousJavaHome = $env:JAVA_HOME
$previousJavaOptions = $env:JAVA_TOOL_OPTIONS
$previousPath = $env:PATH
try {
  $env:JAVA_HOME = 'C:/Program Files/Android/Android Studio/jbr'
  $env:PATH = "$env:JAVA_HOME/bin;$env:PATH"
  # The installed JDK fails in its Unix-domain socket connect path. This
  # workspace-local temp path allows its built-in TCP fallback; no firewall
  # or Windows security setting is changed. Verified with LoopbackProbe.java.
  $socketDirectory = (Resolve-Path -LiteralPath $PSScriptRoot).Path
  $env:JAVA_TOOL_OPTIONS = '-Djdk.net.unixdomain.tmpdir="' + $socketDirectory + '"'
  & firebase emulators:exec --only firestore --project demo-whatmeal-audit --config firebase.audit.json 'node audit/stage3/security_acceptance.mjs'
  if ($LASTEXITCODE -ne 0) { throw 'Local emulator acceptance tests failed.' }
} finally {
  $env:JAVA_HOME = $previousJavaHome
  $env:JAVA_TOOL_OPTIONS = $previousJavaOptions
  $env:PATH = $previousPath
  Pop-Location
}

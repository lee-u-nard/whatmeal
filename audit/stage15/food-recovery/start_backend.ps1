$ErrorActionPreference = 'Stop'
$env:JAVA_HOME = 'C:/Program Files/Android/Android Studio/jbr'
$env:PATH = "$env:JAVA_HOME/bin;$env:PATH"
$env:JAVA_TOOL_OPTIONS = '-Xmx512m -Djdk.net.unixdomain.tmpdir="' + (Resolve-Path audit/stage15).Path + '"'
foreach ($port in @(9180,9181,9199,4490,4590)) {
  if (Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue) { throw "Disposable port $port already occupied" }
}
$exportPath = 'build/household-recovery-private/fixture-export'
$fixtureArgs = @('emulators:start','--only','auth,firestore','--project','demo-whatmeal-audit','--config','firebase.household-recovery.json','--export-on-exit',$exportPath)
if (Test-Path "$exportPath/firebase-export-metadata.json") { $fixtureArgs += @('--import',$exportPath) }
& 'C:/Users/ASUS V16/AppData/Roaming/npm/firebase.cmd' @fixtureArgs 2>&1 | ForEach-Object {
  $_.ToString() -replace '(http://[^\s]+/emulator/action\?)[^\s]+','$1[action-redacted]'
} | Tee-Object -FilePath audit/stage15/food-recovery/disposable-backend.txt
exit $LASTEXITCODE



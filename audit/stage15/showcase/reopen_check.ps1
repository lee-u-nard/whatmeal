$ErrorActionPreference = 'Stop'
Set-Location (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
try {
    & "$PSScriptRoot/OPEN_DEMO.ps1" *> audit/stage15/showcase/reopen.txt
    if ($LASTEXITCODE -ne 0) { throw 'Demo launcher did not complete successfully.' }
    Set-Content audit/stage15/showcase/reopen.exit 0
} catch {
    $_ | Out-String | Set-Content audit/stage15/showcase/reopen-failure.txt
    Set-Content audit/stage15/showcase/reopen.exit 1
}

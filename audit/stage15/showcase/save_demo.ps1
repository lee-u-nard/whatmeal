$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Push-Location $workspace
try {
    & 'C:/Users/ASUS V16/AppData/Roaming/npm/firebase.cmd' emulators:export build/showcase-private/backend --force --project demo-whatmeal-showcase --config firebase.showcase.json
    if ($LASTEXITCODE -ne 0) { throw 'Demo export failed. Keep the backend running and retry.' }
} finally { Pop-Location }

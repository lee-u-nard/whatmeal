param([Parameter(Mandatory=$true)][string]$Email)
$ErrorActionPreference = 'Stop'
if (!$Email.EndsWith('.test')) { throw 'Use a disposable .test email in WhatMeal Demo.' }
$actions = Invoke-RestMethod 'http://127.0.0.1:9299/emulator/v1/projects/demo-whatmeal-showcase/oobCodes'
$action = @($actions.oobCodes | Where-Object { $_.email -eq $Email -and $_.requestType -eq 'VERIFY_EMAIL' }) | Select-Object -Last 1
if (!$action) { throw 'No local verification request yet. Use Resend in WhatMeal Demo first.' }
# Open the real emulator action without printing its bearer code in a report/log.
$url = 'http://127.0.0.1:9299/emulator/action?mode=verifyEmail&oobCode=' + [Uri]::EscapeDataString($action.oobCode) + '&apiKey=demo-api-key'
Start-Process -FilePath $url -WindowStyle Normal
Write-Output 'Local verification opened. Return to WhatMeal Demo and tap I have verified my email.'

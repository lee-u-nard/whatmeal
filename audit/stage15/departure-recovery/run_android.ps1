$ErrorActionPreference = 'Stop'
& 'C:/Users/ASUS V16/flutter_windows_3.44.5-stable/flutter/bin/flutter.bat' drive --driver=test_driver/household_departure_recovery.dart --target=integration_test/household_departure_recovery_test.dart --use-application-binary=build/stage15/departure-recovery/integration.apk --flavor=local -d emulator-5564 --keep-app-running 2>&1 | ForEach-Object {
    # Redact local bearer invitation/action material, never failures or exit codes.
    $_.ToString() -replace '(?<![A-Za-z0-9_-])[A-Za-z0-9_-]{32}(?![A-Za-z0-9_-])','[local-token-redacted]' -replace '(oobCode=)[^&\s]+','$1[redacted]' -replace '(about user \()[^)]+\)','$1[uid-redacted])'
} | Set-Content audit/stage15/departure-recovery/android.txt
$runResult = $LASTEXITCODE
Set-Content audit/stage15/departure-recovery/android.exit $runResult
Get-Content audit/stage15/departure-recovery/android.txt -Tail 18
exit $runResult


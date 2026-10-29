$ErrorActionPreference = 'Stop'
& 'C:/Users/ASUS V16/flutter_windows_3.44.5-stable/flutter/bin/flutter.bat' drive --driver=test_driver/showcase_workflow.dart --target=integration_test/showcase_workflow_test.dart --use-application-binary=build/stage15/showcase/integration.apk --flavor=showcase -d emulator-5564 --keep-app-running 2>&1 | ForEach-Object {
    # Redact local bearer invitation/action material, never failures or exit codes.
    $_.ToString() -replace '(?<![A-Za-z0-9_-])[A-Za-z0-9_-]{32}(?![A-Za-z0-9_-])','[local-token-redacted]' -replace '(oobCode=)[^&\s]+','$1[redacted]' -replace '(http://127\.0\.0\.1:\d+/)[^/\s]+/','$1[vm-session-redacted]/' -replace '(about user \()[^)]+\)','$1[uid-redacted])'
} | Set-Content audit/stage15/showcase/android.txt
$runResult = $LASTEXITCODE
Set-Content audit/stage15/showcase/android.exit $runResult
Get-Content audit/stage15/showcase/android.txt -Tail 18
exit $runResult






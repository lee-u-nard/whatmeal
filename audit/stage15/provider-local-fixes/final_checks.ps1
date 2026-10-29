$ErrorActionPreference = 'Stop'
$flutter = 'C:/Users/ASUS V16/flutter_windows_3.44.5-stable/flutter/bin/flutter.bat'
& $flutter test --reporter expanded *> audit/stage15/provider-local-fixes/flutter-final.txt
$result = $LASTEXITCODE
Set-Content audit/stage15/provider-local-fixes/flutter-final.exit $result
Get-Content audit/stage15/provider-local-fixes/flutter-final.txt -Tail 5
if ($result -ne 0) { exit $result }
& $flutter analyze *> audit/stage15/provider-local-fixes/analyze-final.txt
$result = $LASTEXITCODE
Set-Content audit/stage15/provider-local-fixes/analyze-final.exit $result
Get-Content audit/stage15/provider-local-fixes/analyze-final.txt -Tail 8
exit $result

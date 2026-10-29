$ErrorActionPreference = 'Stop'
$flutter = 'C:/Users/ASUS V16/flutter_windows_3.44.5-stable/flutter/bin/flutter.bat'
& $flutter test --reporter expanded *> audit/stage15/demo-handoff/flutter-tests-final.txt
$result = $LASTEXITCODE
Set-Content audit/stage15/demo-handoff/flutter-tests-final.exit $result
Get-Content audit/stage15/demo-handoff/flutter-tests-final.txt -Tail 4
if ($result -ne 0) { exit $result }
& $flutter analyze *> audit/stage15/demo-handoff/analyze-final-complete.txt
$result = $LASTEXITCODE
Set-Content audit/stage15/demo-handoff/analyze-final-complete.exit $result
Get-Content audit/stage15/demo-handoff/analyze-final-complete.txt -Tail 4
exit $result


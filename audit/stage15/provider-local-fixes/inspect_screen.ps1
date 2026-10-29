param([string]$TapLabel, [string]$Capture = 'screen')
$ErrorActionPreference = 'Stop'
$adb = 'C:/Android/Sdk/platform-tools/adb.exe'
$folder = 'audit/stage15/provider-local-fixes'
if ($Capture -notmatch '^[a-z-]+$') { throw 'Invalid evidence name.' }
$focus = (& $adb -s emulator-5564 shell dumpsys window | Select-String 'mCurrentFocus' | Out-String)
if (!$focus.Contains('com.example.whatmeal.showcase')) { throw 'Only the foreground demo may be inspected.' }
function Read-Screen {
  & $adb -s emulator-5564 shell uiautomator dump /sdcard/whatmeal-final-navigation.xml 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Could not inspect the Android controls.' }
  & $adb -s emulator-5564 pull /sdcard/whatmeal-final-navigation.xml "$folder/$Capture.xml" 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Could not save the Android controls.' }
  return [xml](Get-Content -LiteralPath "$folder/$Capture.xml" -Raw)
}
$ui = Read-Screen
if ($TapLabel) {
  $controls = @($ui.SelectNodes('//node') | Where-Object {
    $_.clickable -eq 'true' -and
      ($_.'content-desc' -eq $TapLabel -or $_.text -eq $TapLabel -or $_.'content-desc'.StartsWith($TapLabel + "`n"))
  })
  if ($controls.Count -ne 1) { throw 'Expected one visible, clickable demo control; no action was taken.' }
  $bounds = [regex]::Match($controls[0].bounds, '^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$')
  if (!$bounds.Success) { throw 'Could not resolve the visible control bounds.' }
  $pointX = [int]([int]$bounds.Groups[1].Value + [int]$bounds.Groups[3].Value) / 2
  $pointY = [int]([int]$bounds.Groups[2].Value + [int]$bounds.Groups[4].Value) / 2
  & $adb -s emulator-5564 shell input tap $pointX $pointY
  if ($LASTEXITCODE -ne 0) { throw 'Android did not accept the tap.' }
  Start-Sleep -Milliseconds 800
  $ui = Read-Screen
}
$labels = @($ui.SelectNodes('//node') | ForEach-Object {
  if ($_.'content-desc') { $_.'content-desc' } elseif ($_.text) { $_.text }
})
if (($labels -join ' ') -match 'isn.t responding|keeps stopping') { throw 'A system error is visible; no dismissal was attempted.' }
@{Screen=$Capture;Action=$TapLabel;VisibleLabels=$labels} | ConvertTo-Json -Depth 4 | Set-Content "$folder/$Capture.json"
& $adb -s emulator-5564 shell screencap -p /sdcard/whatmeal-final-navigation.png
& $adb -s emulator-5564 pull /sdcard/whatmeal-final-navigation.png "$folder/$Capture.png" 2>&1 | Out-Null
$labels | ConvertTo-Json

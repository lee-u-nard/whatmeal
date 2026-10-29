param([Parameter(Mandatory = $true)][string]$EvidenceRoot)
$ErrorActionPreference = 'Stop'
$evidence = (Resolve-Path -LiteralPath $EvidenceRoot).Path
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
if (!$evidence.StartsWith((Join-Path $workspace 'build/release-safety-audit') + [IO.Path]::DirectorySeparatorChar)) {
    throw 'Unexpected evidence directory'
}
$artifact = Get-Content -LiteralPath (Join-Path $evidence 'footer-built-artifact.json') -Raw | ConvertFrom-Json
$apk = (Resolve-Path -LiteralPath $artifact.APK).Path
$expected = Join-Path $workspace 'build/release-request/showcase-footer-20261020/whatmeal-showcase-release.apk'
if ($apk -ne $expected) { throw 'Unexpected APK destination' }
$env:JAVA_HOME = 'C:/Program Files/Android/Android Studio/jbr'
$env:PATH = "$env:JAVA_HOME/bin;$env:PATH"
$analyzer = 'C:/Android/Sdk/cmdline-tools/latest/bin/apkanalyzer.bat'
$tools = 'C:/Android/Sdk/build-tools/36.0.0'
function Read-ApkValue([string[]]$Arguments) {
    $result = & $analyzer @Arguments $apk
    if ($LASTEXITCODE -ne 0) { throw 'APK inspection failed' }
    return ($result | Out-String).Trim()
}
$package = Read-ApkValue @('manifest', 'application-id')
$version = Read-ApkValue @('manifest', 'version-name')
$code = Read-ApkValue @('manifest', 'version-code')
$debug = Read-ApkValue @('manifest', 'debuggable')
$project = Read-ApkValue @('resources', 'value', '--config', 'default', '--name', 'project_id', '--type', 'string')
if ($package -ne 'com.example.whatmeal.showcase' -or $project -ne 'demo-whatmeal-showcase' -or $debug -ne 'false') {
    throw 'Release package, demo environment or debuggable flag does not match approval'
}
& "$tools/apksigner.bat" verify --verbose --print-certs $apk *> (Join-Path $evidence 'footer-signature.txt')
if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed' }
$certificate = '371ccb837f5379cc570eee0808710d3ca1cc36cbabef112e0a3d7960274b25bb'
if (!(Select-String -LiteralPath (Join-Path $evidence 'footer-signature.txt') -SimpleMatch -Pattern $certificate)) {
    throw 'Tester certificate changed'
}
$manifest = & "$tools/aapt2.exe" dump xmltree $apk --file AndroidManifest.xml
if ($LASTEXITCODE -ne 0) { throw 'Manifest inspection failed' }
$manifest | Set-Content -LiteralPath (Join-Path $evidence 'footer-native-manifest.txt')
$guards = $manifest | Select-String 'networkSecurityConfig|firebase_messaging_auto_init_enabled|firebase_analytics_collection_enabled' -Context 0,1 | Out-String
if (([regex]::Matches($guards, 'value\([^\)]+\)=false')).Count -ne 2) { throw 'Local auto-init guards changed' }
$resources = & "$tools/aapt2.exe" dump resources $apk
if ($LASTEXITCODE -ne 0) { throw 'Resource inspection failed' }
$policy = $resources | Select-String 'xml/local_network_security' -Context 0,1 | Out-String
$resourceId = [regex]::Match($policy, 'resource (0x[0-9a-f]+) xml/local_network_security')
$resourcePath = [regex]::Match($policy, 'res/[^\s]+\.xml')
if (!$resourceId.Success -or !$resourcePath.Success -or !$guards.Contains('@' + $resourceId.Groups[1].Value)) {
    throw 'Manifest is not bound to the local network policy'
}
$network = & "$tools/aapt2.exe" dump xmltree $apk --file $resourcePath.Value | Out-String
if ($LASTEXITCODE -ne 0) { throw 'Network policy inspection failed' }
$network | Set-Content -LiteralPath (Join-Path $evidence 'footer-native-network-policy.txt')
$domains = [regex]::Matches($network, "T: '([^']+)'") | ForEach-Object { $_.Groups[1].Value }
if (!$network.Contains('cleartextTrafficPermitted=false') -or (($domains | Sort-Object) -join ',') -ne '10.0.2.2,127.0.0.1,localhost') {
    throw 'Local network policy changed'
}
[pscustomobject]@{
    APK=$apk; SHA256=(Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash
    Bytes=(Get-Item -LiteralPath $apk).Length; Package=$package; VersionName=$version
    VersionCode=$code; Debuggable=$false; NativeProject=$project
    SignatureVerified=$true; ExistingTesterCertificateMatched=$true
    MessagingAutoInit=$false; AnalyticsAutoInit=$false; CleartextDefaultDenied=$true
    LocalHttpAllowlist=$domains; InspectionExit=0
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidence 'footer-apk-verification.json')
Set-Content -LiteralPath (Join-Path $evidence 'footer-apk-verification.exit') -Value 0
Get-Content -LiteralPath (Join-Path $evidence 'footer-apk-verification.json')

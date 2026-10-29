$ErrorActionPreference = 'Stop'
$env:JAVA_HOME = 'C:/Program Files/Android/Android Studio/jbr'
$env:PATH = "$env:JAVA_HOME/bin;$env:PATH"
$apk = (Resolve-Path 'build/stage15/food-recovery/integration.apk').Path
$sdkTools = 'C:/Android/Sdk/build-tools/36.0.0'
$analyzer = 'C:/Android/Sdk/cmdline-tools/latest/bin/apkanalyzer.bat'

& "$sdkTools/aapt2.exe" dump badging $apk > audit/stage15/food-recovery/integration-verification/apk-identity.txt
$LASTEXITCODE | Set-Content audit/stage15/food-recovery/integration-verification/apk-identity.exit
if ($LASTEXITCODE -ne 0) { throw 'APK identity check failed' }
if (!(Select-String -Path audit/stage15/food-recovery/integration-verification/apk-identity.txt -SimpleMatch -Pattern "package: name='com.example.whatmeal.local'")) {
    throw 'Refusing unexpected APK package'
}
& $analyzer resources value --config default --name project_id --type string $apk > audit/stage15/food-recovery/integration-verification/apk-project.txt
$LASTEXITCODE | Set-Content audit/stage15/food-recovery/integration-verification/apk-project.exit
if ($LASTEXITCODE -ne 0 -or (Get-Content audit/stage15/food-recovery/integration-verification/apk-project.txt -Raw).Trim() -ne 'demo-whatmeal-audit') {
    throw 'Refusing APK with unexpected native Firebase project'
}
& "$sdkTools/apksigner.bat" verify --verbose --print-certs $apk > audit/stage15/food-recovery/integration-verification/apk-signature.txt
$LASTEXITCODE | Set-Content audit/stage15/food-recovery/integration-verification/apk-signature.exit
if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed' }
$expectedCertificate = '371ccb837f5379cc570eee0808710d3ca1cc36cbabef112e0a3d7960274b25bb'
if (!(Select-String -Path audit/stage15/food-recovery/integration-verification/apk-signature.txt -SimpleMatch -Pattern $expectedCertificate)) {
    throw 'Unexpected tester signing identity'
}
$manifest = & "$sdkTools/aapt2.exe" dump xmltree $apk --file AndroidManifest.xml
if ($LASTEXITCODE -ne 0) { throw 'Manifest inspection failed' }
$manifest | Select-String 'networkSecurityConfig|firebase_messaging_auto_init_enabled|firebase_analytics_collection_enabled' -Context 0,1 > audit/stage15/food-recovery/integration-verification/apk-native-guards.txt
$guards = Get-Content audit/stage15/food-recovery/integration-verification/apk-native-guards.txt -Raw
if (([regex]::Matches($guards, 'value\([^\)]+\)=false')).Count -ne 2) {
    throw 'Local FCM/analytics auto-init guards are not both disabled'
}
$resource = & "$sdkTools/aapt2.exe" dump resources $apk | Select-String 'xml/local_network_security' -Context 0,1
$resource | Set-Content audit/stage15/food-recovery/integration-verification/apk-network-resource-path.txt
$resourceId = [regex]::Match(($resource | Out-String), 'resource (0x[0-9a-f]+) xml/local_network_security')
if (!$resourceId.Success -or !$guards.Contains('@' + $resourceId.Groups[1].Value)) {
    throw 'Manifest does not reference the verified local network policy'
}
$match = [regex]::Match(($resource | Out-String), 'res/[^\s]+\.xml')
if (!$match.Success) { throw 'Missing local network policy resource' }
& "$sdkTools/aapt2.exe" dump xmltree $apk --file $match.Value > audit/stage15/food-recovery/integration-verification/apk-network-security.txt
$LASTEXITCODE | Set-Content audit/stage15/food-recovery/integration-verification/apk-network-security.exit
if ($LASTEXITCODE -ne 0) { throw 'Network policy inspection failed' }
$network = Get-Content audit/stage15/food-recovery/integration-verification/apk-network-security.txt -Raw
if (!$network.Contains('cleartextTrafficPermitted=false')) { throw 'Missing cleartext deny default' }
$domains = [regex]::Matches($network, "T: '([^']+)'") | ForEach-Object { $_.Groups[1].Value }
if (($domains | Sort-Object) -join ',' -ne '10.0.2.2,127.0.0.1,localhost') {
    throw 'Unexpected local HTTP domain allowlist'
}
$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $apk
$hash | Format-List > audit/stage15/food-recovery/integration-verification/apk-sha256.txt
$hash.Hash | Set-Content audit/stage15/food-recovery/integration-verification/apk-sha256-value.txt
Write-Output "Verified isolated package, demo project and existing tester certificate. SHA-256: $($hash.Hash)"









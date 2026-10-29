$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/demo_health.ps1"
$cases = @(
    @{Name='Absent hub'; Hub=$null; Expected=$false},
    @{Name='Hub exists before services'; Hub=@{hub=@{port=4492}}; Expected=$false},
    @{Name='Only Firestore registered'; Hub=@{firestore=@{port=9280}}; Expected=$false},
    @{Name='Wrong Auth port'; Hub=@{auth=@{port=9099};firestore=@{port=9280}}; Expected=$false},
    @{Name='Both showcase services registered'; Hub=@{auth=@{port=9299};firestore=@{port=9280}}; Expected=$true}
)
foreach ($case in $cases) {
    if ((Test-ShowcaseHubReady $case.Hub) -ne $case.Expected) { throw "Readiness regression: $($case.Name)" }
}
Write-Output '5 launcher readiness cases passed.'

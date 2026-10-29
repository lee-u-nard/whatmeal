$ErrorActionPreference='Stop'
$workspace=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $workspace
try {
  # Fixed isolated project/config; never use a root alias or deploy Auth/indexes.
  & 'C:/Program Files/nodejs/node.exe' -e "const fs=require('fs');const e=require('./audit/cloud-test/candidate_evidence.cjs');const v=e.readVerifiedCandidate();const c=JSON.parse(fs.readFileSync('build/cloud-test/firebase.json','utf8'));if(c.firestore?.rules!=='verified-candidate.rules'||e.sha256(fs.readFileSync('build/cloud-test/verified-candidate.rules'))!==v.sha256)throw Error('Isolated config/source mismatch');console.log('Exact 71-case candidate and isolated config verified.');"
  if($LASTEXITCODE -ne 0){throw 'No deployment without verified exact source.'}
  foreach($check in @('flutter-analysis','flutter-tests')){
    if((Get-Content (Join-Path $PSScriptRoot ($check+'.exit')) -Raw).Trim() -cne '0'){
      throw 'Final Flutter checks must pass before test-project promotion.'
    }
  }
  if((Get-Content (Join-Path $PSScriptRoot 'flutter-tests.txt') -Raw) -notmatch '(?m)\+\d+: All tests passed!\s*$' -or
     (Get-Content (Join-Path $PSScriptRoot 'flutter-analysis.txt') -Raw) -notmatch 'No issues found!'){
    throw 'Incomplete Flutter output cannot authorize promotion.'
  }
  $stamp=(Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmssfff')
  $privateLog=Join-Path $workspace "build/cloudtest-private/deploy-verified-$stamp.log"
  $publicLog=Join-Path $PSScriptRoot "deploy-verified-$stamp.txt"
  Push-Location (Join-Path $workspace 'build/cloud-test')
  try {
    & 'C:/Program Files/nodejs/npx.cmd' -y firebase-tools@latest deploy --only 'firestore:rules' `
      --project whatmeal-gemini-test-20261019 --config firebase.json --non-interactive *> $privateLog
    $deployExit=$LASTEXITCODE
  } finally {Pop-Location}
  Set-Content (Join-Path $PSScriptRoot "deploy-verified-$stamp.exit") $deployExit
  & 'C:/Program Files/nodejs/node.exe' "$PSScriptRoot/sanitize_log.cjs" $privateLog $publicLog
  if($LASTEXITCODE -ne 0){throw 'Deployment log sanitization failed; private output withheld.'}
  Get-Content -LiteralPath $publicLog -Tail 14
  if($deployExit -ne 0){exit $deployExit}
  & 'C:/Program Files/nodejs/node.exe' "$PSScriptRoot/check_deployed_rules.cjs"
  if($LASTEXITCODE -ne 0){throw 'Test-project active source did not match the verified candidate.'}
  & 'C:/Program Files/nodejs/node.exe' -e "require('./audit/cloud-test/candidate_evidence.cjs').readVerifiedDeployment(); console.log('Only approved test-project rules promoted and source verified.');"
  if($LASTEXITCODE -ne 0){throw 'Test deployment evidence failed verification.'}
} finally {Pop-Location}

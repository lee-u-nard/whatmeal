param([ValidateSet('replay','security')][string]$Check='replay')
$ErrorActionPreference='Stop'
$workspace=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $workspace
try {
  # Separate ports/project and candidate-only rules. Never change normal rules.
  $candidate=Join-Path $PSScriptRoot 'recipe-budget-candidate.rules'
  if((Get-FileHash $candidate -Algorithm SHA256).Hash -cne '49AA394DC5E125072AA73CB1DCF495CAD9185550D19532BA5037FA03AAC5B999'){
    throw 'Candidate changed; review and record its identity before execution.'
  }
  $suite=Join-Path $PSScriptRoot 'security_acceptance_candidate.mjs'
  $suiteHash=(Get-FileHash $suite -Algorithm SHA256).Hash
  $candidateHash=(Get-FileHash $candidate -Algorithm SHA256).Hash
  $outputPath=Join-Path $PSScriptRoot "candidate-$Check.txt"
  $exitPath=Join-Path $PSScriptRoot "candidate-$Check.exit"
  $receiptPath=Join-Path $PSScriptRoot 'candidate-security-receipt.json'
  # Preserve prior executed attempts, including failures, before replacing logs.
  $priorPaths=@($outputPath,$exitPath)
  if($Check -eq 'security'){$priorPaths+=@($receiptPath)}
  $priorPaths=@($priorPaths | Where-Object {Test-Path -LiteralPath $_})
  if($priorPaths.Count -gt 0){
    $archive=Join-Path $PSScriptRoot ('attempts/candidate-' + $Check + '-' + (Get-Date -Format 'yyyyMMdd-HHmmssfff'))
    if(Test-Path -LiteralPath $archive){throw 'Attempt archive already exists; refusing to overwrite.'}
    New-Item -ItemType Directory -Path $archive | Out-Null
    foreach($priorPath in $priorPaths){Copy-Item -LiteralPath $priorPath -Destination $archive}
  }
  $config=[ordered]@{
    emulators=[ordered]@{
      firestore=@{host='127.0.0.1';port=9380;websocketPort=9381}
      ui=@{enabled=$false};hub=@{host='127.0.0.1';port=4494}
      logging=@{host='127.0.0.1';port=4594};singleProjectMode=$true
    }
    firestore=@{rules='candidate.rules'}
  }
  New-Item -ItemType Directory -Force build/cloud-test | Out-Null
  Copy-Item -LiteralPath $candidate -Destination build/cloud-test/candidate.rules
  if((Get-FileHash build/cloud-test/candidate.rules -Algorithm SHA256).Hash -cne $candidateHash){
    throw 'Isolated emulator rules copy differs from the reviewed candidate.'
  }
  $config | ConvertTo-Json -Depth 6 | Set-Content build/cloud-test/candidate-security.firebase.json
  $env:JAVA_HOME='C:/Program Files/Android/Android Studio/jbr'
  $env:PATH="$env:JAVA_HOME/bin;$env:PATH"
  $env:JAVA_TOOL_OPTIONS='-Djdk.net.unixdomain.tmpdir="' + $PSScriptRoot + '"'
  $command=if($Check -eq 'replay'){'node audit/cloud-test/replay_captured_batch.mjs'}else{'node audit/cloud-test/security_acceptance_candidate.mjs'}
  & 'C:/Program Files/nodejs/npx.cmd' -y firebase-tools@latest emulators:exec --only firestore --project demo-whatmeal-cloud-security --config build/cloud-test/candidate-security.firebase.json $command *> $outputPath
  $result=$LASTEXITCODE; Set-Content $exitPath $result
  Get-Content $outputPath -Tail 20
  if($Check -eq 'security' -and $result -eq 0){
    if((Get-FileHash $candidate -Algorithm SHA256).Hash -cne $candidateHash -or
       (Get-FileHash build/cloud-test/candidate.rules -Algorithm SHA256).Hash -cne $candidateHash -or
       (Get-FileHash $suite -Algorithm SHA256).Hash -cne $suiteHash){
      throw 'Candidate or suite changed during execution; no verified receipt can be issued.'
    }
    # This records an executed run only. The helper separately requires all 71
    # unique PASS lines, no failures, and the successful exact-recipe replay.
    $receipt=[ordered]@{
      formatVersion=1;check='security';project='demo-whatmeal-cloud-security'
      exitCode=0;passed=71;total=71;completedAt=(Get-Date -Format o)
      candidateSha256=$candidateHash;suiteSha256=$suiteHash
      securityLogSha256=(Get-FileHash $outputPath -Algorithm SHA256).Hash
      replayLogSha256=(Get-FileHash (Join-Path $PSScriptRoot 'candidate-replay.txt') -Algorithm SHA256).Hash
    }
    [IO.File]::WriteAllText($receiptPath,($receipt | ConvertTo-Json),[Text.UTF8Encoding]::new($false))
    & 'C:/Program Files/nodejs/node.exe' -e "require('./audit/cloud-test/candidate_evidence.cjs').readVerifiedCandidate(); console.log('Exact candidate and 71-case executed evidence verified locally.');"
    if($LASTEXITCODE -ne 0){throw 'Executed evidence did not pass validation; candidate is not verified.'}
  }
  # Replay is diagnostic: an exit0 is not proof of a successful write. Inspect
  # atomicHttp==200 and atomicDocumentsPresent==2 before promotion.
  exit $result
} finally { Pop-Location }

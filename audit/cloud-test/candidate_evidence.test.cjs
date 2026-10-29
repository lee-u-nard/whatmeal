'use strict';

// SYNTHETIC evidence-validator tests, NOT execution of the 71-case security
// suite. No real acceptance receipt or security/replay pass artifact is written.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {
  EXPECTED_CANDIDATE_SHA256, EXPECTED_CASES, sha256,
  validateEvidence, readVerifiedCandidate, validateDeployment, readVerifiedDeployment,
} = require('./candidate_evidence.cjs');

// Only this local reviewed public rules source is real. Logs, suite bytes and
// receipts below are disposable in-memory synthetic fixtures, never real proof.
const candidate = fs.readFileSync(path.join(__dirname, 'recipe-budget-candidate.rules'));
const syntheticSuite = Buffer.from('// SYNTHETIC VALIDATOR FIXTURE; NO SECURITY SUITE EXECUTED.\n');
function securityText() {
  return Array.from({ length: EXPECTED_CASES }, (_, index) =>
    `PASS SYNTHETIC_validator_case_${String(index + 1).padStart(3, '0')}`)
    .concat(`${EXPECTED_CASES}/${EXPECTED_CASES} emulator acceptance cases passed`, '')
    .join('\n');
}
function replayObject() {
  return {
    capturedWriteCount: 2, capturedBatchCount: 1,
    schemaDiagnostics: [
      { document: 0, kind: 'plan', violations: [] },
      { document: 1, kind: 'meal', violations: [] },
    ], atomicHttp: 200, atomicDocumentsPresent: 2,
  };
}
function replayText(value = replayObject()) {
  return `i SYNTHETIC validator fixture only\n${JSON.stringify(value, null, 2)}\ni SYNTHETIC end\n`;
}
function fixture() {
  const value = {
    candidate: Buffer.from(candidate), suite: Buffer.from(syntheticSuite),
    securityLog: Buffer.from(securityText()), replayLog: Buffer.from(replayText()),
    exitCode: '0\r\n', receipt: {},
  };
  bind(value);
  return value;
}
function bind(value) {
  value.receipt = {
    formatVersion: 1, check: 'security', project: 'demo-whatmeal-cloud-security',
    exitCode: 0, passed: EXPECTED_CASES, total: EXPECTED_CASES,
    candidateSha256: sha256(value.candidate), suiteSha256: sha256(value.suite),
    securityLogSha256: sha256(value.securityLog), replayLogSha256: sha256(value.replayLog),
    syntheticFixtureOnly: true,
  };
  return value;
}
function rejected(value) {
  assert.throws(() => validateEvidence(value), {
    message: 'Candidate acceptance evidence is missing or invalid.',
  });
}
function replaceSecurity(value, change) {
  value.securityLog = Buffer.from(change(value.securityLog.toString('utf8')));
  return bind(value);
}
function replaceReplay(value, change) {
  value.replayLog = Buffer.from(replayText(change(replayObject())));
  return bind(value);
}

test('SYNTHETIC validator accepts complete internally bound in-memory evidence', () => {
  const input = fixture();
  const result = validateEvidence(input);
  assert.equal(result.candidateSha256, EXPECTED_CANDIDATE_SHA256);
  assert.equal(result.passed, 71);
  assert.equal(result.total, 71);
  assert.equal(Object.isFrozen(result), true);
});

for (const encoding of ['utf8-bom', 'utf16le-bom']) {
  test(`SYNTHETIC validator decodes ${encoding} but hashes raw log bytes`, () => {
    const input = fixture();
    for (const field of ['securityLog', 'replayLog']) {
      const text = input[field].toString('utf8').replaceAll('\n', '\r\n');
      input[field] = encoding === 'utf8-bom'
        ? Buffer.concat([Buffer.from([0xef, 0xbb, 0xbf]), Buffer.from(text)])
        : Buffer.concat([Buffer.from([0xff, 0xfe]), Buffer.from(text, 'utf16le')]);
    }
    input.exitCode = '\ufeff 0\r\n';
    bind(input);
    const result = validateEvidence(input);
    assert.equal(result.securityLogSha256, sha256(input.securityLog));
    assert.equal(result.replayLogSha256, sha256(input.replayLog));
  });
}

for (const field of ['candidate', 'suite', 'securityLog', 'replayLog', 'receipt', 'exitCode']) {
  test(`SYNTHETIC validator rejects missing ${field}`, () => {
    const input = fixture(); delete input[field]; rejected(input);
  });
}
for (const field of ['candidate', 'suite', 'securityLog', 'replayLog']) {
  test(`SYNTHETIC validator rejects stale ${field} bytes`, () => {
    const input = fixture();
    input[field] = Buffer.concat([input[field], Buffer.from('\nchanged')]);
    rejected(input);
  });
}
test('SYNTHETIC validator rejects changed candidate even with rebound hashes', () => {
  const input = fixture();
  input.candidate = Buffer.concat([input.candidate, Buffer.from('\n// change')]);
  rejected(bind(input));
});
for (const [field, changed] of Object.entries({
  formatVersion: 2, check: 'replay', project: 'unapproved-project', exitCode: 1,
  passed: 70, total: 72, candidateSha256: '0'.repeat(64), suiteSha256: '0'.repeat(64),
  securityLogSha256: '0'.repeat(64), replayLogSha256: '0'.repeat(64),
})) {
  test(`SYNTHETIC validator rejects mismatched receipt ${field}`, () => {
    const input = fixture(); input.receipt[field] = changed; rejected(input);
  });
}
test('SYNTHETIC validator rejects missing required receipt fields', () => {
  const input = fixture(); delete input.receipt.securityLogSha256; rejected(input);
});
test('SYNTHETIC validator rejects inherited receipt proof', () => {
  const input = fixture(); input.receipt = Object.create(input.receipt); rejected(input);
});
test('SYNTHETIC validator rejects failed or malformed exit evidence', () => {
  for (const exit of ['1', '', '0\n1', '00', 0, null]) {
    const input = fixture(); input.exitCode = exit; rejected(input);
  }
});

for (const [name, change] of [
  ['missing pass', text => text.replace(/^PASS[^\n]*\n/, '')],
  ['duplicate case', text => text.replace('case_002', 'case_001')],
  ['extra pass', text => `PASS SYNTHETIC_extra\n${text}`],
  ['failure line', text => `${text}FAIL SYNTHETIC_failure\n`],
  ['indented failure', text => `${text}  FAIL SYNTHETIC_failure\n`],
  ['duplicate summary', text => `${text}71/71 emulator acceptance cases passed\n`],
  ['conflicting summary', text => `${text}70/71 emulator acceptance cases passed\n`],
  ['failed summary', text => text.replace('71/71 emulator', '70/71 emulator')],
  ['summary only', () => '71/71 emulator acceptance cases passed\n'],
  ['empty pass marker', text => text.replace(/^PASS[^\n]*/, 'PASS ')],
]) {
  test(`SYNTHETIC validator rejects ${name} even with matching receipt hashes`, () => {
    rejected(replaceSecurity(fixture(), change));
  });
}

for (const [name, change] of [
  ['atomic denial', object => ({ ...object, atomicHttp: 403 })],
  ['missing document', object => ({ ...object, atomicDocumentsPresent: 1 })],
  ['missing diagnostics', object => { delete object.schemaDiagnostics; return object; }],
  ['empty diagnostics', object => ({ ...object, schemaDiagnostics: [] })],
  ['schema violation', object => { object.schemaDiagnostics[1].violations = ['synthetic']; return object; }],
  ['missing violations', object => { delete object.schemaDiagnostics[0].violations; return object; }],
  ['duplicate document diagnostic', object => { object.schemaDiagnostics[1].document = 0; return object; }],
  ['diagnostic error', object => ({ ...object, diagnosticError: 'synthetic failure' })],
  ['nested extra status', object => ({ ...object, nested: { atomicHttp: 403 } })],
]) {
  test(`SYNTHETIC validator rejects replay ${name}`, () => {
    rejected(replaceReplay(fixture(), change));
  });
}

for (const [name, change] of [
  ['duplicate atomic key', text => text.replace('"atomicHttp": 200', '"atomicHttp": 403, "atomicHttp": 200')],
  ['shadowed violation key', text => text.replace('"violations": []', '"violations": ["synthetic"], "violations": []')],
  ['second JSON report', text => `${text}\n{"atomicHttp":403,"atomicDocumentsPresent":0}`],
  ['extra status declaration', text => `${text}\natomicHttp:403\n`],
  ['malformed JSON', text => text.replace('"atomicHttp": 200', '"atomicHttp": invalid')],
]) {
  test(`SYNTHETIC validator rejects replay ${name}`, () => {
    const input = fixture(); input.replayLog = Buffer.from(change(replayText())); rejected(bind(input));
  });
}
test('SYNTHETIC validator handles escaped braces/quotes structurally', () => {
  const input = replaceReplay(fixture(), object => ({
    ...object, syntheticNote: 'Not a container: { "quoted" } \\ escape',
  }));
  assert.equal(validateEvidence(input).passed, EXPECTED_CASES);
});
test('SYNTHETIC validator rejects invalid log encoding', () => {
  const input = fixture(); input.securityLog = Buffer.from([0xff]); rejected(bind(input));
});
test('SYNTHETIC readVerifiedCandidate fails closed on missing fixed local evidence', () => {
  assert.throws(() => readVerifiedCandidate(path.join(__dirname, '__synthetic_missing_root__')),
    { message: 'Candidate acceptance evidence is missing or invalid.' });
});

function deploymentFixture() {
  const verified = Object.freeze({
    source: candidate.toString('utf8'), sha256: EXPECTED_CANDIDATE_SHA256,
    verification: validateEvidence(fixture()),
  });
  const source = Buffer.from(candidate);
  return {
    verified, source,
    report: {
      project: 'whatmeal-gemini-test-20261019',
      activeSourceMatchesReviewedRules: true,
      candidateSha256: verified.sha256,
      securityPassed: 71, securityTotal: 71,
      sourceSha256: sha256(source).toLowerCase(),
      comparedAgainst: 'audit/cloud-test/recipe-budget-candidate.rules',
      syntheticFixtureOnly: true,
    },
  };
}
function deploymentRejected(input) {
  assert.throws(() => validateDeployment(input), {
    message: 'Candidate acceptance evidence is missing or invalid.',
  });
}

test('SYNTHETIC deployment validator returns the verified candidate unchanged', () => {
  const input = deploymentFixture();
  assert.equal(validateDeployment(input), input.verified);
});
test('SYNTHETIC deployment validator permits LF/CRLF normalization with bound raw hashes', () => {
  for (const eol of ['\n', '\r\n']) {
    const input = deploymentFixture();
    input.source = Buffer.from(input.verified.source.replace(/\r\n/g, '\n').replace(/\n/g, eol));
    input.report.sourceSha256 = sha256(input.source).toLowerCase();
    assert.equal(validateDeployment(input), input.verified);
  }
});
test('SYNTHETIC deployment validator rejects missing inputs', () => {
  for (const field of ['verified', 'report', 'source']) {
    const input = deploymentFixture(); delete input[field]; deploymentRejected(input);
  }
});
test('SYNTHETIC deployment validator rejects wrong or absent project identity', () => {
  for (const project of ['whatmeal-101', 'demo-whatmeal-cloud-security', undefined]) {
    const input = deploymentFixture(); input.report.project = project; deploymentRejected(input);
  }
});
test('SYNTHETIC deployment validator rejects stale source/candidate hash reports', () => {
  for (const field of ['sourceSha256', 'candidateSha256']) {
    const input = deploymentFixture(); input.report[field] = '0'.repeat(64); deploymentRejected(input);
  }
});
test('SYNTHETIC deployment validator rejects a false source match report', () => {
  const input = deploymentFixture(); input.report.activeSourceMatchesReviewedRules = false;
  deploymentRejected(input);
});
test('SYNTHETIC deployment validator rejects wrong rules even after rebinding raw hash', () => {
  const input = deploymentFixture();
  input.source = Buffer.concat([input.source, Buffer.from('\n// synthetic changed rules')]);
  input.report.sourceSha256 = sha256(input.source).toLowerCase();
  deploymentRejected(input);
});
test('SYNTHETIC deployment validator rejects incorrect security acceptance counts', () => {
  for (const field of ['securityPassed', 'securityTotal']) {
    const input = deploymentFixture(); input.report[field] = 70; deploymentRejected(input);
  }
});
test('SYNTHETIC deployment validator rejects missing/wrong comparison source path', () => {
  for (const comparedAgainst of ['firestore.rules', undefined]) {
    const input = deploymentFixture(); input.report.comparedAgainst = comparedAgainst;
    deploymentRejected(input);
  }
});
test('SYNTHETIC readVerifiedDeployment fails closed on missing fixed local evidence', () => {
  assert.throws(() => readVerifiedDeployment(path.join(__dirname, '__synthetic_missing_root__')),
    { message: 'Candidate acceptance evidence is missing or invalid.' });
});

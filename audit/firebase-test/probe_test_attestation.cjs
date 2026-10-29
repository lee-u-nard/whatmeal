// One bounded exchange against the new test app; token/key never leave RAM or
// the private files. Never print a success token or a raw error response.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const privateDir = path.resolve(__dirname, '../../build/firebase-gemini-test');
(async () => {
  const config = JSON.parse(fs.readFileSync(path.join(privateDir, 'google-services.json'), 'utf8'));
  assert.equal(config.project_info.project_id, 'whatmeal-gemini-test-20261019');
  const app = config.client.find(c => c.client_info.android_client_info.package_name === 'com.example.whatmeal.aitest');
  assert.equal(app.client_info.mobilesdk_app_id, '1:952163528165:android:9348c46aaa5943ff95530c');
  const debugToken = fs.readFileSync(path.join(privateDir, 'appcheck-debug-token.txt'), 'utf8').trim();
  const response = await fetch('https://firebaseappcheck.googleapis.com/v1/projects/952163528165/apps/1:952163528165:android:9348c46aaa5943ff95530c:exchangeDebugToken', {
    method: 'POST', signal: AbortSignal.timeout(15000),
    headers: {'Content-Type': 'application/json', 'x-goog-api-key': app.api_key[0].current_key},
    body: JSON.stringify({debugToken}),
  });
  const body = await response.json();
  const message = String(body.error?.message ?? '').toLowerCase();
  const status = {
    httpStatus: response.status, tokenReceived: response.ok && typeof body.token === 'string' && body.token.length > 0,
    errorStatus: /^[A-Z_]+$/.test(body.error?.status ?? '') ? body.error.status : null,
    reasons: (body.error?.details ?? []).map(d => d.reason).filter(r => /^[A-Z_]+$/.test(r ?? '')),
    services: (body.error?.details ?? []).map(d => d.metadata?.service).filter(s => /^[a-z0-9.]+\.googleapis\.com$/.test(s ?? '')),
    appAttestationRejected: message.includes('attestation'),
    apiKeyRejected: message.includes('api key'),
    apiDisabled: message.includes('disabled') || message.includes('not been used'),
    debugTokenRejected: message.includes('debug token'),
  };
  fs.writeFileSync(path.join(__dirname, 'attestation-probe.json'), JSON.stringify(status, null, 2));
  console.log(JSON.stringify(status));
  if (!status.tokenReceived) process.exitCode = 1;
})().catch(() => { console.error('Private attestation probe failed; no credentials or raw response printed.'); process.exitCode = 1; });

// Read-only checks, deliberately restricted to the newly approved Spark project.
// No credentials, billing account identifiers, or API response bodies are printed.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const cliRoot = path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib');
const { getGlobalDefaultAccount } = require(path.join(cliRoot, 'auth'));
const { requireAuth } = require(path.join(cliRoot, 'requireAuth'));
const { Client } = require(path.join(cliRoot, 'apiv2'));
const { cloudbillingOrigin } = require(path.join(cliRoot, 'api'));
const { getService } = require(path.join(cliRoot, 'appcheck/api'));
const projectId = 'whatmeal-gemini-test-20261019';
const projectNumber = '952163528165';

(async () => {
  await requireAuth({ project: projectId, nonInteractive: true, ...getGlobalDefaultAccount() });
  const client = new Client({ urlPrefix: cloudbillingOrigin(), apiVersion: 'v1' });
  const [billing, appCheck] = await Promise.all([
    client.get(`projects/${projectId}/billingInfo`, { retries: 0 }),
    getService(projectNumber, 'firebaseml.googleapis.com'),
  ]);
  const status = {
    checkedAt: new Date().toISOString(), projectId,
    billingEnabled: billing.body.billingEnabled === true,
    billingAccountLinked: Boolean(billing.body.billingAccountName),
    appCheckEnforcement: appCheck.enforcementMode,
  };
  assert.equal(billing.body.billingEnabled, false, 'Billing must be disabled.');
  assert.equal(status.billingAccountLinked, false, 'No billing account may be linked.');
  assert.equal(status.appCheckEnforcement, 'ENFORCED', 'App Check must remain enforced.');
  const target = path.resolve(__dirname, '../../build/firebase-gemini-test/status.json');
  fs.writeFileSync(target, JSON.stringify(status, null, 2));
  console.log(JSON.stringify(status));
})().catch((error) => {
  console.error(`Isolated test-project verification failed (${error.name || 'Error'}). No credentials or API body printed.`);
  process.exitCode = 1;
});

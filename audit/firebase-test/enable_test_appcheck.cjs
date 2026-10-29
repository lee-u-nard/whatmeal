// Provision only the missing Spark-compatible App Check API in the new project.
const path = require('node:path');
const cliRoot = path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib');
const { getGlobalDefaultAccount } = require(path.join(cliRoot, 'auth'));
const { requireAuth } = require(path.join(cliRoot, 'requireAuth'));
const { ensure } = require(path.join(cliRoot, 'ensureApiEnabled'));
(async () => {
  const project = 'whatmeal-gemini-test-20261019';
  await requireAuth({project, nonInteractive: true, ...getGlobalDefaultAccount()});
  await ensure(project, 'firebaseappcheck.googleapis.com', 'isolated-ai-test');
  console.log('Enabled only the new test project App Check API.');
})().catch(() => {
  console.error('Test-project App Check API provisioning failed; no secrets or raw response printed.');
  process.exitCode = 1;
});

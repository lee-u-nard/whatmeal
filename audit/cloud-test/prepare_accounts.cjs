// Create new random, preverified, synthetic Auth fixtures in the approved test
// project only. This never reads or imports any original/emulator account data.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const cli = require(path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools'));
const workspace = path.resolve(__dirname, '../..');
const privateDir = path.join(workspace, 'build/cloudtest-private');
const project = 'whatmeal-gemini-test-20261019';
(async () => {
  fs.mkdirSync(privateDir, {recursive:true});
  const fixturePath = path.join(privateDir, 'accounts.json');
  if (fs.existsSync(fixturePath)) {
    if (!process.argv.includes('--resume-import')) throw new Error('Preserve existing disposable fixtures; do not overwrite.');
    await cli.auth.import(path.join(privateDir,'auth-import.json'),{project,
      hashAlgo:'PBKDF2_SHA256',rounds:100000,cwd:path.join(workspace,'build/cloud-test'),nonInteractive:true,json:true});
    console.log('Resumed import of the same preserved disposable fixtures; no credentials printed.');
    return;
  }
  const accounts = {};
  const users = [];
  for (const role of ['owner', 'outsider']) {
    const suffix = `${Date.now()}-${crypto.randomBytes(4).toString('hex')}`;
    const uid = `cloud-${role}-${suffix}`;
    const email = `${uid}@example.test`;
    const password = `Cloud!${crypto.randomBytes(18).toString('base64url')}`;
    const salt = crypto.randomBytes(16);
    accounts[role] = {uid, email, password};
    users.push({localId:uid, email, emailVerified:true, displayName:`Cloud ${role}`,
      passwordHash:crypto.pbkdf2Sync(password,salt,100000,32,'sha256').toString('base64'),
      salt:salt.toString('base64')});
  }
  fs.writeFileSync(fixturePath, JSON.stringify({project, accounts}, null, 2));
  const importPath = path.join(privateDir, 'auth-import.json');
  fs.writeFileSync(importPath, JSON.stringify({users}));
  fs.writeFileSync(path.join(privateDir, 'defines-generate.json'), JSON.stringify({
    CLOUD_OWNER_EMAIL:accounts.owner.email, CLOUD_OWNER_PASSWORD:accounts.owner.password,
    CLOUD_OUTSIDER_EMAIL:accounts.outsider.email, CLOUD_OUTSIDER_PASSWORD:accounts.outsider.password,
    CLOUD_ACCEPTANCE_PHASE:'generate', CLOUD_ACCEPTANCE_PLAN_TITLE:'Cloud Gemini Acceptance',
  },null,2));
  await cli.auth.import(importPath,{project,hashAlgo:'PBKDF2_SHA256',rounds:100000,
    cwd:path.join(workspace,'build/cloud-test'),nonInteractive:true,json:true});
  console.log('Prepared two disposable admin-preverified test accounts. No credentials printed.');
})().catch(error => {
  let message = String(error.message ?? 'Unknown setup failure');
  for (const file of ['accounts.json','auth-import.json']) {
    const filePath = path.join(privateDir,file);
    if (fs.existsSync(filePath)) {
      const scrub = value => {if (typeof value==='string' && value.length>3) message=message.split(value).join('[REDACTED]'); else if(value && typeof value==='object') Object.values(value).forEach(scrub);};
      scrub(JSON.parse(fs.readFileSync(filePath,'utf8')));
    }
  }
  message=message.replace(/AIza[\w-]+/g,'[REDACTED]').replace(/eyJ[\w.-]+/g,'[REDACTED]');
  console.error(`Disposable fixture setup failed (${error.name}): ${message.slice(0,400)}`);process.exitCode=1;
});

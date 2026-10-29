// Diagnostic against unchanged rules. A failing denial assertion is a real
// release blocker, not a passing security test. Never accepts production hosts.
import assert from 'node:assert/strict';
const host = process.env.FIRESTORE_EMULATOR_HOST;
assert.equal(host, '127.0.0.1:8180', 'Only the isolated local emulator is allowed');
const project = 'demo-whatmeal-audit';
const base = `http://${host}/v1/projects/${project}/databases/(default)/documents`;
const token = uid => [
  {alg: 'none', typ: 'JWT'},
  {aud: project, iss: `https://securetoken.google.com/${project}`, sub: uid,
   user_id: uid, iat: Math.floor(Date.now()/1000), exp: Math.floor(Date.now()/1000)+3600,
   firebase: {sign_in_provider: 'custom', identities: {}}},
].map(x => Buffer.from(JSON.stringify(x)).toString('base64url')).join('.') + '.';
const encode = value => {
  if (typeof value === 'string') return {stringValue: value};
  if (Array.isArray(value)) return {arrayValue: {values: value.map(encode)}};
  return {mapValue: {fields: Object.fromEntries(Object.entries(value).map(([k,v]) => [k, encode(v)]))}};
};
async function request(uid, path, method='GET', data) {
  const response = await fetch(`${base}/${path}`, {method,
    headers: {Authorization: `Bearer ${uid === 'seed' ? 'owner' : token(uid)}`, 'Content-Type':'application/json'},
    body: data ? JSON.stringify({fields: encode(data).mapValue.fields}) : undefined});
  return response.status;
}
for (const [path, data] of Object.entries({
  'families/f': {createdBy:'owner', memberUids:['owner','member','viewer'], inviteCode:'TEST_ONLY'},
  'families/f/members/member': {role:'member'},
  'families/f/members/viewer': {role:'viewOnly'},
  'users/owner/secrets/llmConfig': {apiKey:'FAKE_TEST_VALUE'},
  'families/f/pantryItems/item': {name:'Rice'},
})) assert.equal(await request('seed',path,'PATCH',data),200);
const checks = [
  ['owner reads private settings', await request('owner','users/owner/secrets/llmConfig'),200],
  ['outsider cannot read private settings', await request('outsider','users/owner/secrets/llmConfig'),403],
  ['outsider cannot read household invite (C01)', await request('outsider','families/f'),403],
  ['member cannot elevate own role (C02)', await request('member','families/f/members/member','PATCH',{role:'owner'}),403],
  ['viewer cannot edit shared pantry (C02)', await request('viewer','families/f/pantryItems/item','PATCH',{name:'Changed'}),403],
  ['owner cannot cross-write private notification (H08)', await request('owner','users/member/notifications/n','PATCH',{title:'Test'}),403],
  ['outsider cannot self-add without invitation (C01)', await request('outsider','families/f','PATCH',
    {createdBy:'owner', memberUids:['owner','member','viewer','outsider'], inviteCode:'TEST_ONLY'}),403],
];
let failures = 0;
for (const [name, actual, expected] of checks) {
  const passed = actual === expected;
  if (!passed) failures++;
  console.log(`${passed ? 'PASS' : 'FAIL'} ${name}: HTTP ${actual}, expected ${expected}`);
}
console.log(`${checks.length-failures}/${checks.length} security expectations passed`);
process.exitCode = failures ? 1 : 0;

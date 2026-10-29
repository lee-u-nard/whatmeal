// Read-only acceptance of the saved demo, authenticated as its disposable users.
// Never prints passwords, ID tokens, action codes, or user IDs.
const fs = require('node:fs');
const assert = require('node:assert/strict');
const project = 'demo-whatmeal-showcase';
const base = `http://127.0.0.1:9280/v1/projects/${project}/databases/(default)/documents/`;
async function json(url, options) {
  const response = await fetch(url, options);
  if (!response.ok) throw new Error(`Local demo request failed (${response.status})`);
  return response.json();
}
(async () => {
  const accounts = JSON.parse(fs.readFileSync('build/showcase-private/accounts.json', 'utf8'));
  assert.equal(accounts.length, 2);
  const identities = [];
  for (const account of accounts) {
    const login = await json('http://127.0.0.1:9299/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-api-key', {
      method: 'POST', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({email: account.email, password: account.password, returnSecureToken: true})
    });
    const headers = {Authorization: `Bearer ${login.idToken}`};
    const membership = await json(base + `membershipIndex/${login.localId}`, {headers});
    const family = membership.fields.familyId.stringValue;
    const own = await json(base + `families/${family}/members/${login.localId}`, {headers});
    assert.equal(own.fields.role.stringValue, account.role);
    const members = await json(base + `families/${family}/members`, {headers});
    assert.equal(members.documents.length, 2);
    const plans = await json(base + `families/${family}/mealPlans`, {headers});
    const plan = plans.documents.find(p => p.fields.title.stringValue === 'Demo family week');
    assert.ok(plan);
    const meals = await json(`http://127.0.0.1:9280/v1/${plan.name}/meals`, {headers});
    assert.equal(meals.documents.length, 2);
    assert.deepEqual(meals.documents.map(m => m.fields.status.stringValue).sort(), ['accepted', 'pending']);
    const stock = await json(base + `families/${family}/pantryItems`, {headers});
    assert.ok(stock.documents.some(p => p.fields.name.stringValue === 'rice' && p.fields.quantity.stringValue === '1 cup'));
    if (account.role === 'owner') {
      const receipts = await json(base + `users/${login.localId}/notificationReceipts`, {headers});
      assert.ok(receipts.documents?.some(r => r.fields.read.booleanValue === true));
    }
    identities.push({family, plan: plan.name});
  }
  assert.ok(identities[0].family === identities[1].family, 'Accounts must share the same demo household');
  assert.ok(identities[0].plan === identities[1].plan, 'Accounts must read the same saved demo plan');
  const result = {accountsAuthenticated: 2, canonicalRolesVerified: true,
    sharedHouseholdMembers: 2, sameSavedPlanForBothAccounts: true,
    savedMeals: 2, statuses: ['accepted', 'pending'], pantryStockVerified: true,
    ownerReadReceiptsPersisted: true, scope: 'Authenticated local REST server reads; supplements actual routed Android UI evidence'};
  fs.writeFileSync('audit/final/demo-data-check.json', JSON.stringify(result, null, 2));
  process.stdout.write(JSON.stringify(result));
})().catch(error => { process.stderr.write(error.message); process.exitCode = 1; });


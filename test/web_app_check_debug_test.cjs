const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const {test} = require('node:test');
const source = fs.readFileSync('web/app_check_debug.js', 'utf8');
function run(hostname, search = '') {
  const self = {};
  vm.runInNewContext(source, {self, location: {hostname, search}, URLSearchParams});
  return self.FIREBASE_APPCHECK_DEBUG_TOKEN;
}
test('ordinary localhost uses the configured real provider', () => {
  assert.equal(run('localhost'), undefined);
});
test('explicit localhost debugging asks the SDK to generate a token', () => {
  assert.equal(run('localhost', '?appCheckDebug=true'), true);
  assert.equal(run('127.0.0.1', '?appCheckDebug=true'), true);
  assert.equal(run('[::1]', '?appCheckDebug=true'), true);
});
test('production and lookalike domains cannot enable the debug provider', () => {
  assert.equal(run('whatmeal.example', '?appCheckDebug=true'), undefined);
  assert.equal(run('localhost.example', '?appCheckDebug=true'), undefined);
});
test('debug mode requires an exact explicit opt-in', () => {
  assert.equal(run('localhost', '?appCheckDebug=false'), undefined);
  assert.equal(run('localhost', '?appCheckDebug=1'), undefined);
});
test('the web shell contains no embedded debug credential', () => {
  const html = fs.readFileSync('web/index.html', 'utf8');
  assert.match(html, /src="app_check_debug\.js"/);
  assert.doesNotMatch(html + source, /FIREBASE_APPCHECK_DEBUG_TOKEN\s*=\s*['"]/);
});
test('normal Android release bootstrap has no debug-provider override', () => {
  const main = fs.readFileSync('lib/main.dart', 'utf8');
  assert.doesNotMatch(main, /WHATMEAL_TESTER_ANDROID_DEBUG_APP_CHECK/);
  assert.match(main,
    /androidProvider:\s*kDebugMode\s*\?\s*AndroidProvider\.debug\s*:\s*AndroidProvider\.playIntegrity/);
  assert.match(main,
    /appleProvider:\s*kDebugMode\s*\?\s*AppleProvider\.debug\s*:\s*AppleProvider\.deviceCheck/);
});

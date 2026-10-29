// Register only this separate test app's SDK-generated debug token.
// The token is read privately, never included in process arguments or output.
const fs = require('node:fs');
const path = require('node:path');
const cli = require(path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools'));
const project = 'whatmeal-gemini-test-20261019';
const app = '1:952163528165:android:e184bb528e406cff95530c';
const privateDir = path.resolve(__dirname, '../../build/cloud-test');

(async () => {
  const token = fs.readFileSync(path.join(privateDir, 'appcheck-debug-token.txt'), 'utf8').trim();
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(token)) {
    throw new Error('Invalid private token format.');
  }
  const registrationFile = path.join(privateDir, 'device-registration.json');
  if (fs.existsSync(registrationFile)) {
    throw new Error('Registration evidence already exists; refusing an automatic overwrite.');
  }
  const registration = await cli.appcheck.debugtokens.create(token, {
    project, app, cwd: privateDir, nonInteractive: true, json: true,
    displayName: 'WhatMeal full cloud test AVD 2026-10-19',
  });
  // Retain the resource name privately for later revocation. Discard token value.
  fs.writeFileSync(registrationFile, JSON.stringify({ project, app,
    name: registration.name, registeredAt: new Date().toISOString() }, null, 2));
  console.log('Registered the separate test-device token; no secret was printed.');
})().catch(() => {
  console.error('Test-device registration failed. No token or raw API response printed.');
  process.exitCode = 1;
});


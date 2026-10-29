'use strict';

// LOCAL evidence validation only. This module never runs a suite, writes a
// receipt, launches an emulator, reads credentials, or contacts Firebase.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { TextDecoder } = require('node:util');

const EXPECTED_CANDIDATE_SHA256 = '49AA394DC5E125072AA73CB1DCF495CAD9185550D19532BA5037FA03AAC5B999';
const EXPECTED_CASES = 71;
const PROJECT = 'demo-whatmeal-cloud-security';
const INVALID = 'Candidate acceptance evidence is missing or invalid.';
function reject() { throw new Error(INVALID); }
function requireValid(condition) { if (!condition) reject(); }

function sha256(bytes) {
  requireValid(Buffer.isBuffer(bytes));
  return crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
}

function decode(bytes) {
  requireValid(Buffer.isBuffer(bytes));
  try {
    if (bytes[0] === 0xff && bytes[1] === 0xfe) {
      return new TextDecoder('utf-16le', { fatal: true }).decode(bytes.subarray(2));
    }
    const start = bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf ? 3 : 0;
    return new TextDecoder('utf-8', { fatal: true }).decode(bytes.subarray(start));
  } catch (_) { reject(); }
}

function object(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}
function own(value, key) { return Object.prototype.hasOwnProperty.call(value, key); }

// JSON.parse silently accepts duplicate object keys. Reject those explicitly,
// honoring escaped strings and separate nested object scopes before parsing.
function parseUniqueJson(text) {
  const stack = [];
  try {
    for (let i = 0; i < text.length; i++) {
      const char = text[i];
      if (char === '{') stack.push(new Set());
      else if (char === '}') { requireValid(stack.length > 0); stack.pop(); }
      else if (char === '"') {
        const start = i++;
        for (; i < text.length; i++) {
          if (text[i] === '\\') i++;
          else if (text[i] === '"') break;
        }
        requireValid(i < text.length);
        const token = JSON.parse(text.slice(start, i + 1));
        let next = i + 1;
        while (/\s/.test(text[next] ?? '') && next < text.length) next++;
        if (text[next] === ':') {
          const keys = stack.at(-1);
          requireValid(keys && !keys.has(token));
          keys.add(token);
        }
      }
    }
    requireValid(stack.length === 0);
    return JSON.parse(text);
  } catch (_) { reject(); }
}

function validateSecurityLog(bytes) {
  const lines = decode(bytes).split(/\r\n|\n|\r/);
  requireValid(!lines.some(line => /^\s*FAIL/i.test(line)));
  const passes = lines.filter(line => line.startsWith('PASS'));
  requireValid(passes.length === EXPECTED_CASES);
  const names = passes.map(line => {
    const match = /^PASS[ \t]+(.+?)\s*$/.exec(line);
    requireValid(match && match[1].trim().length > 0);
    return match[1].trim();
  });
  requireValid(new Set(names).size === EXPECTED_CASES);
  const summaries = lines.map(line =>
    /^(\d+)\/(\d+) emulator acceptance cases passed\.?$/.exec(line.trim()))
    .filter(Boolean);
  requireValid(summaries.length === 1 &&
    Number(summaries[0][1]) === EXPECTED_CASES &&
    Number(summaries[0][2]) === EXPECTED_CASES);
}

function validateReplayLog(bytes) {
  const text = decode(bytes);
  const first = text.indexOf('{');
  const last = text.lastIndexOf('}');
  requireValid(first >= 0 && last >= first);
  const replay = parseUniqueJson(text.slice(first, last + 1));
  requireValid(object(replay) && replay.atomicHttp === 200 &&
    replay.atomicDocumentsPresent === 2 && !own(replay, 'diagnosticError'));
  // Also reject extra/conflicting status declarations outside the JSON block
  // or hidden in nested data, rather than accepting the last successful value.
  for (const [key, expected] of [['atomicHttp', 200], ['atomicDocumentsPresent', 2]]) {
    const values = [...text.matchAll(new RegExp(`\\b${key}\\b["']?\\s*[:=]\\s*(-?\\d+)`, 'g'))];
    requireValid(values.length === 1 && Number(values[0][1]) === expected);
  }
  requireValid(Array.isArray(replay.schemaDiagnostics) &&
    replay.schemaDiagnostics.length === 2);
  const documents = new Set();
  for (const entry of replay.schemaDiagnostics) {
    requireValid(object(entry) && Number.isInteger(entry.document) &&
      entry.document >= 0 && entry.document < 2 && !documents.has(entry.document) &&
      own(entry, 'violations') && Array.isArray(entry.violations) &&
      entry.violations.length === 0);
    documents.add(entry.document);
  }
}

function validateEvidence(input) {
  try {
    requireValid(object(input));
    const { candidate, suite, securityLog, replayLog, exitCode, receipt } = input;
    for (const bytes of [candidate, suite, securityLog, replayLog]) {
      requireValid(Buffer.isBuffer(bytes) && bytes.length > 0);
    }
    requireValid(typeof exitCode === 'string' && exitCode.trim() === '0');
    requireValid(object(receipt));
    const hashes = {
      candidateSha256: sha256(candidate),
      suiteSha256: sha256(suite),
      securityLogSha256: sha256(securityLog),
      replayLogSha256: sha256(replayLog),
    };
    requireValid(hashes.candidateSha256 === EXPECTED_CANDIDATE_SHA256);
    for (const [key, expected] of Object.entries({
      formatVersion: 1, check: 'security', project: PROJECT,
      exitCode: 0, passed: EXPECTED_CASES, total: EXPECTED_CASES, ...hashes,
    })) {
      requireValid(own(receipt, key) && receipt[key] === expected);
    }
    validateSecurityLog(securityLog);
    validateReplayLog(replayLog);
    return Object.freeze({
      formatVersion: 1, check: 'security', project: PROJECT, exitCode: 0,
      passed: EXPECTED_CASES, total: EXPECTED_CASES, ...hashes,
    });
  } catch (_) { reject(); }
}

function readVerifiedCandidate(root = path.resolve(__dirname, '../..')) {
  try {
    requireValid(typeof root === 'string' && root.length > 0);
    const directory = path.join(path.resolve(root), 'audit', 'cloud-test');
    const read = name => fs.readFileSync(path.join(directory, name));
    const candidate = read('recipe-budget-candidate.rules');
    const verification = validateEvidence({
      candidate,
      suite: read('security_acceptance_candidate.mjs'),
      securityLog: read('candidate-security.txt'),
      replayLog: read('candidate-replay.txt'),
      exitCode: decode(read('candidate-security.exit')),
      receipt: parseUniqueJson(decode(read('candidate-security-receipt.json'))),
    });
    return Object.freeze({
      source: decode(candidate), sha256: verification.candidateSha256, verification,
    });
  } catch (_) { reject(); }
}

function validateDeployment(input) {
  try {
    requireValid(object(input));
    const { verified, report, source } = input;
    requireValid(object(verified) && typeof verified.source === 'string' &&
      verified.sha256 === EXPECTED_CANDIDATE_SHA256 &&
      sha256(Buffer.from(verified.source, 'utf8')) === verified.sha256);
    requireValid(object(verified.verification) &&
      verified.verification.candidateSha256 === verified.sha256 &&
      verified.verification.passed === EXPECTED_CASES &&
      verified.verification.total === EXPECTED_CASES);
    requireValid(Buffer.isBuffer(source) && source.length > 0 && object(report));
    const expected = {
      project: 'whatmeal-gemini-test-20261019',
      activeSourceMatchesReviewedRules: true,
      candidateSha256: verified.sha256,
      securityPassed: EXPECTED_CASES,
      securityTotal: EXPECTED_CASES,
      sourceSha256: sha256(source).toLowerCase(),
      comparedAgainst: 'audit/cloud-test/recipe-budget-candidate.rules',
    };
    for (const [key, value] of Object.entries(expected)) {
      requireValid(own(report, key) && report[key] === value);
    }
    const normalize = text => text.replace(/\r\n/g, '\n').trim();
    requireValid(normalize(decode(source)) === normalize(verified.source));
    return verified;
  } catch (_) { reject(); }
}

function readVerifiedDeployment(root = path.resolve(__dirname, '../..')) {
  try {
    const verified = readVerifiedCandidate(root);
    return validateDeployment({
      verified,
      report: parseUniqueJson(decode(fs.readFileSync(path.join(
        root, 'audit', 'cloud-test', 'deployed-rules-check.json')))),
      source: fs.readFileSync(path.join(root, 'build', 'cloud-test', 'explicit-deployed.rules')),
    });
  } catch (_) { reject(); }
}

module.exports = {
  EXPECTED_CANDIDATE_SHA256, EXPECTED_CASES, sha256,
  validateEvidence, readVerifiedCandidate, validateDeployment, readVerifiedDeployment,
};

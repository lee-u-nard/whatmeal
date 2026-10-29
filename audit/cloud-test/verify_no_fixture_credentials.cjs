const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const zlib = require('node:zlib');

// Exact literal inspection only. Required public Firebase client configuration
// is unrelated to these disposable account credentials and is left intact.
function scanZip(read, size, values) {
  if (!Number.isSafeInteger(size) || size < 22 || values.length === 0) throw Error('invalid-input');
  const tailSize = Math.min(size, 65557);
  const tail = read(size - tailSize, tailSize);
  let end = -1;
  for (let i = tail.length - 22; i >= 0; i--) {
    if (tail.readUInt32LE(i) === 0x06054b50 && i + 22 + tail.readUInt16LE(i + 20) === tail.length) {
      end = i;
      break;
    }
  }
  if (end < 0) throw Error('invalid-zip-end');
  const entries = tail.readUInt16LE(end + 10);
  const centralSize = tail.readUInt32LE(end + 12);
  let cursor = tail.readUInt32LE(end + 16);
  if (tail.readUInt16LE(end + 4) !== 0 || tail.readUInt16LE(end + 6) !== 0 ||
      tail.readUInt16LE(end + 8) !== entries || entries === 0 || entries === 65535 ||
      centralSize === 0xffffffff || cursor === 0xffffffff || cursor + centralSize > size - tailSize + end) {
    throw Error('unsupported-zip-layout');
  }
  const centralStart = cursor;
  const centralEnd = cursor + centralSize;
  const needles = values.map((value) => {
    const little = Buffer.from(value, 'utf16le');
    const big = Buffer.from(little);
    big.swap16();
    return [Buffer.from(value, 'utf8'), little, big];
  });
  const matchedValues = new Set();
  let matchingEntries = 0;
  let matches = 0;
  let uncompressedBytes = 0;
  for (let entry = 0; entry < entries; entry++) {
    const header = read(cursor, 46);
    if (header.readUInt32LE(0) !== 0x02014b50 || (header.readUInt16LE(8) & 1) !== 0) throw Error('invalid-or-encrypted-entry');
    const method = header.readUInt16LE(10);
    const compressedSize = header.readUInt32LE(20);
    const expectedSize = header.readUInt32LE(24);
    const localOffset = header.readUInt32LE(42);
    const next = cursor + 46 + header.readUInt16LE(28) + header.readUInt16LE(30) + header.readUInt16LE(32);
    if (next > centralEnd || compressedSize === 0xffffffff || expectedSize === 0xffffffff ||
        localOffset === 0xffffffff || expectedSize > 512 * 1024 * 1024) throw Error('unsupported-entry-size');
    const local = read(localOffset, 30);
    if (local.readUInt32LE(0) !== 0x04034b50 || local.readUInt16LE(8) !== method ||
        (local.readUInt16LE(6) & 1) !== 0) throw Error('invalid-local-header');
    const dataOffset = localOffset + 30 + local.readUInt16LE(26) + local.readUInt16LE(28);
    if (dataOffset + compressedSize > centralStart) throw Error('invalid-entry-range');
    const compressed = read(dataOffset, compressedSize);
    const content = method === 0 ? compressed : method === 8
      ? zlib.inflateRawSync(compressed, { maxOutputLength: 512 * 1024 * 1024 })
      : (() => { throw Error('unsupported-compression'); })();
    if (content.length !== expectedSize) throw Error('uncompressed-size-mismatch');
    uncompressedBytes += content.length;
    let entryMatched = false;
    for (let valueIndex = 0; valueIndex < needles.length; valueIndex++) {
      for (const needle of needles[valueIndex]) {
        let offset = 0;
        while ((offset = content.indexOf(needle, offset)) !== -1) {
          matches++;
          entryMatched = true;
          matchedValues.add(valueIndex);
          offset += needle.length;
        }
      }
    }
    if (entryMatched) matchingEntries++;
    cursor = next;
  }
  if (cursor !== centralEnd) throw Error('central-directory-size-mismatch');
  return { scanComplete: true, zipEntriesScanned: entries, uncompressedBytesScanned: uncompressedBytes,
    distinctCredentialValuesChecked: values.length, encodingsChecked: 3,
    distinctCredentialValuesMatched: matchedValues.size, matchingEntries, matches,
    fixtureCredentialsAbsent: matches === 0, passed: matches === 0 };
}

function main() {
  let report = { scanComplete: false, fixtureCredentialsAbsent: false, passed: false };
  let stage = 'arguments';
  let descriptor;
  try {
    const [apkArg, reportArg] = process.argv.slice(2);
    if (!apkArg || !reportArg) throw Error('missing-arguments');
    const root = path.resolve(__dirname, '../..');
    const apk = path.resolve(apkArg);
    const output = path.resolve(reportArg);
    if (!apk.startsWith(path.join(root, 'build') + path.sep) ||
        !output.startsWith(path.join(root, 'audit', 'cloud-test') + path.sep)) throw Error('outside-deliverable-scope');
    stage = 'private-fixture';
    const fixture = JSON.parse(fs.readFileSync(path.join(root, 'build/cloudtest-private/accounts.json'), 'utf8'));
    if (fixture.project !== 'whatmeal-gemini-test-20261019') throw Error('unexpected-private-fixture-project');
    const accounts = Object.values(fixture.accounts ?? {});
    if (accounts.length !== 2) throw Error('unexpected-fixture-count');
    const values = [...new Set(accounts.flatMap((account) => {
      if (typeof account.email !== 'string' || !account.email.endsWith('@example.test') ||
          typeof account.password !== 'string' || account.password.length === 0) throw Error('invalid-disposable-fixture');
      return [account.email, account.password];
    }))];
    stage = 'zip-entry-scan';
    descriptor = fs.openSync(apk, 'r');
    const size = fs.fstatSync(descriptor).size;
    const read = (offset, length) => {
      if (!Number.isSafeInteger(offset) || !Number.isSafeInteger(length) || offset < 0 || length < 0 || offset + length > size) throw Error('invalid-read-range');
      const bytes = Buffer.alloc(length);
      if (fs.readSync(descriptor, bytes, 0, length, offset) !== length) throw Error('incomplete-read');
      return bytes;
    };
    report = { ...scanZip(read, size, values), fixtureAccountsChecked: accounts.length, apkBytes: size };
    stage = 'artifact-hash';
    const hash = crypto.createHash('sha256');
    const chunkSize = 1024 * 1024;
    for (let offset = 0; offset < size; offset += chunkSize) hash.update(read(offset, Math.min(chunkSize, size - offset)));
    report.apkSha256 = hash.digest('hex').toUpperCase();
    stage = 'public-report';
    fs.writeFileSync(output, JSON.stringify(report, null, 2));
    process.stdout.write(JSON.stringify(report) + '\n');
    process.exitCode = report.passed ? 0 : 1;
  } catch (_) {
    // Parsing errors can contain source snippets; never print the exception.
    report = { scanComplete: false, fixtureCredentialsAbsent: false, passed: false, failureStage: stage };
    const output = process.argv[3] && path.resolve(process.argv[3]);
    const allowed = path.resolve(__dirname) + path.sep;
    if (output && output.startsWith(allowed)) {
      try { fs.writeFileSync(output, JSON.stringify(report, null, 2)); } catch (_) { /* fixed stdout failure remains */ }
    }
    process.stdout.write(JSON.stringify(report) + '\n');
    process.exitCode = 1;
  } finally {
    if (descriptor !== undefined) fs.closeSync(descriptor);
  }
}

module.exports = { scanZip };
if (require.main === module) main();

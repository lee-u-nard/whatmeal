const { test } = require('node:test');
const assert = require('node:assert/strict');
const zlib = require('node:zlib');
const { scanZip } = require('./verify_no_fixture_credentials.cjs');

// Entirely synthetic buffers: never open the real credential file or an APK.
const values = ['owner.synthetic@example.test', 'Synthetic-Only-Password!'];
function zip(entries) {
  const locals = [];
  const central = [];
  let localSize = 0;
  for (let i = 0; i < entries.length; i++) {
    const entry = entries[i];
    const name = Buffer.from(`assets/synthetic-${i}.bin`);
    const method = entry.method ?? 0;
    const content = Buffer.from(entry.content);
    const compressed = method === 8 ? zlib.deflateRawSync(content) : content;
    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(20, 4);
    local.writeUInt16LE(entry.flags ?? 0, 6);
    local.writeUInt16LE(method, 8);
    local.writeUInt32LE(compressed.length, 18);
    local.writeUInt32LE(content.length, 22);
    local.writeUInt16LE(name.length, 26);
    const header = Buffer.alloc(46);
    header.writeUInt32LE(0x02014b50, 0);
    header.writeUInt16LE(20, 4);
    header.writeUInt16LE(20, 6);
    header.writeUInt16LE(entry.flags ?? 0, 8);
    header.writeUInt16LE(method, 10);
    header.writeUInt32LE(compressed.length, 20);
    header.writeUInt32LE(content.length + (entry.sizeDelta ?? 0), 24);
    header.writeUInt16LE(name.length, 28);
    header.writeUInt32LE(localSize, 42);
    locals.push(local, name, compressed);
    central.push(header, name);
    localSize += local.length + name.length + compressed.length;
  }
  const directory = Buffer.concat(central);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(entries.length, 8);
  end.writeUInt16LE(entries.length, 10);
  end.writeUInt32LE(directory.length, 12);
  end.writeUInt32LE(localSize, 16);
  return Buffer.concat([...locals, directory, end]);
}
function scan(buffer) {
  return scanZip((offset, length) => {
    if (offset < 0 || length < 0 || offset + length > buffer.length) throw Error('synthetic-read-range');
    return buffer.subarray(offset, offset + length);
  }, buffer.length, values);
}

test('clean stored and deflated entries retain public Firebase config and pass', () => {
  const report = scan(zip([
    { content: 'Public Firebase client API config: AIza-placeholder-not-provider-secret' },
    { method: 8, content: 'Synthetic normal app code without credential defines' },
  ]));
  assert.equal(report.passed, true);
  assert.equal(report.scanComplete, true);
  assert.equal(report.zipEntriesScanned, 2);
  assert.equal(report.matches, 0);
});
for (const method of [0, 8]) {
  for (const encoding of ['utf8', 'utf16le', 'utf16be']) {
    test(`detects exact synthetic literals in method ${method}, ${encoding}`, () => {
      const bytes = Buffer.from(`prefix:${values[0]}:${values[1]}:suffix`,
          encoding === 'utf16be' ? 'utf16le' : encoding);
      if (encoding === 'utf16be') bytes.swap16();
      const report = scan(zip([{ method, content: bytes }]));
      assert.equal(report.scanComplete, true);
      assert.equal(report.passed, false);
      assert.equal(report.fixtureCredentialsAbsent, false);
      assert.equal(report.distinctCredentialValuesMatched, 2);
      assert.equal(report.matchingEntries, 1);
      for (const value of values) assert.equal(JSON.stringify(report).includes(value), false);
    });
  }
}
test('unsupported, encrypted, truncated and incorrect-size ZIPs fail closed', () => {
  assert.throws(() => scan(zip([{ method: 99, content: 'synthetic' }])));
  assert.throws(() => scan(zip([{ flags: 1, content: 'synthetic' }])));
  const valid = zip([{ method: 8, content: 'synthetic' }]);
  assert.throws(() => scan(valid.subarray(0, valid.length - 1)));
  assert.throws(() => scan(zip([{ method: 8, content: 'synthetic', sizeDelta: 1 }])));
});

import net from 'node:net';
import assert from 'node:assert/strict';
import test from 'node:test';
import { startRelay } from './firestore_relay.mjs';

test('local relay forwards, disconnects existing/new connections, then recovers', async () => {
  const target = net.createServer(socket => socket.pipe(socket));
  await new Promise(resolve => target.listen(0, '127.0.0.1', resolve));
  const relay = await startRelay({ port: 0, controlPort: 0,
    targetPort: target.address().port });
  const clients = [];
  const connect = () => {
    const socket = net.connect(relay.port, '127.0.0.1');
    clients.push(socket);
    return socket;
  };
  const echo = socket => new Promise((resolve, reject) => {
    socket.once('error', reject);
    socket.once('data', data => { assert.equal(data.toString(), 'probe'); resolve(); });
    socket.write('probe');
  });
  const control = async path => (await fetch(
    `http://127.0.0.1:${relay.controlPort}/${path}`,
    { method: path === 'status' ? 'GET' : 'POST' })).json();
  try {
    const first = connect();
    await echo(first);
    const closed = new Promise(resolve => first.once('close', resolve));
    assert.equal((await control('offline')).online, false);
    await closed;
    const blocked = connect();
    await new Promise(resolve => { blocked.on('error', () => {}); blocked.once('close', resolve); });
    assert.ok((await control('status')).dropped >= 2);
    assert.equal((await control('online')).online, true);
    await echo(connect());
  } finally {
    for (const socket of clients) socket.destroy();
    await relay.close();
    await new Promise(resolve => target.close(resolve));
  }
});

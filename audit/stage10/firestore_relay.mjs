import net from 'node:net';
import http from 'node:http';
import { pathToFileURL } from 'node:url';

// Fixed loopback-only target; never inspects or logs authentication/data payloads.
export async function startRelay({ port = 8181, controlPort = 8182,
  targetPort = 8180 } = {}) {
  let online = true;
  let dropped = 0;
  const sockets = new Set();
  const relay = net.createServer(client => {
    if (!online) { dropped++; client.destroy(); return; }
    const upstream = net.connect(targetPort, '127.0.0.1');
    for (const socket of [client, upstream]) {
      sockets.add(socket);
      socket.on('error', () => { client.destroy(); upstream.destroy(); });
      socket.on('close', () => sockets.delete(socket));
    }
    client.on('close', () => upstream.destroy());
    upstream.on('close', () => client.destroy());
    client.pipe(upstream).pipe(client);
  });
  const control = http.createServer((req, res) => {
    if (req.method === 'POST' && req.url === '/offline') {
      online = false;
      dropped += sockets.size;
      for (const socket of sockets) socket.destroy();
    } else if (req.method === 'POST' && req.url === '/online') {
      online = true;
    } else if (req.method !== 'GET' || req.url !== '/status') {
      res.writeHead(404).end(); return;
    }
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ online, dropped }));
  });
  const listen = (server, number) => new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(number, '127.0.0.1', resolve);
  });
  await listen(relay, port);
  try { await listen(control, controlPort); }
  catch (e) { relay.close(); throw e; }
  return { port: relay.address().port, controlPort: control.address().port,
    async close() {
      for (const socket of sockets) socket.destroy();
      await Promise.all([relay, control].map(server =>
        new Promise(resolve => server.close(resolve))));
    } };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const instance = await startRelay();
  console.log('Demo Firestore relay ready on loopback 8181; control 8182.');
  for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, async () => {
    await instance.close(); process.exit(0);
  });
}

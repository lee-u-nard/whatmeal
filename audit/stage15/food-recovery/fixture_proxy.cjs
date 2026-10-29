// Test infrastructure only. Never logs/decrypts payloads or changes the backend.
const net = require('node:net');
const http = require('node:http');
let paused = false;
const peers = new Set();
const proxy = net.createServer(client => {
  if (paused) { client.destroy(); return; }
  const upstream = net.connect({host: '127.0.0.1', port: 9180});
  peers.add(client); peers.add(upstream);
  const close = () => { peers.delete(client); peers.delete(upstream); client.destroy(); upstream.destroy(); };
  client.on('error', close); upstream.on('error', close);
  client.on('close', close); upstream.on('close', close);
  client.pipe(upstream); upstream.pipe(client);
});
const control = http.createServer((req, res) => {
  if (req.method === 'POST' && ['/pause','/resume'].includes(req.url)) {
    paused = req.url === '/pause';
    if (paused) for (const socket of [...peers]) socket.destroy();
  } else if (!(req.method === 'GET' && req.url === '/state')) {
    res.writeHead(404); res.end(); return;
  }
  res.writeHead(200, {'Content-Type': 'application/json'});
  res.end(JSON.stringify({paused}));
});
for (const server of [proxy, control]) server.on('error', () => { process.stderr.write('Local fixture proxy startup failed\n'); process.exit(1); });
proxy.listen(8183, '127.0.0.1', () => control.listen(8184, '127.0.0.1', () => process.stdout.write('Local fixture proxy ready on 8183; control 8184; disposable backend 9180; normal 8180 untouched\n')));
function stop() { for (const socket of peers) socket.destroy(); proxy.close(); control.close(); setTimeout(() => process.exit(0), 100).unref(); }
process.on('SIGINT', stop); process.on('SIGTERM', stop);

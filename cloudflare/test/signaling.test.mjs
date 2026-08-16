// Test end-to-end signaling melawan wrangler dev (Workers + Durable Object).
// Jalankan: npm run dev  (di terminal lain), lalu: npm test
import { WebSocket } from 'ws';
import { createHmac } from 'node:crypto';

// Secret dibaca dari env (di CI dipasok lewat secrets.XYDESK_SECRET, selaras
// dengan `wrangler dev --var`). Default 'test-secret' cocok dengan .dev.vars lokal.
const SECRET = process.env.XYDESK_SECRET || 'test-secret';
const BASE = process.env.XYDESK_BASE || 'ws://127.0.0.1:8787';

// Replika penerbit token (identik dengan /issue di worker).
function issue(purpose, secret = SECRET, nowSec = Math.floor(Date.now() / 1000)) {
  const ts = String(nowSec);
  const sig = createHmac('sha256', secret).update(purpose + '\x00' + ts).digest('hex');
  return `${ts}.${purpose}.${sig}`;
}

function connect(id, role, name) {
  const token = issue(id);
  return new WebSocket(`${BASE}/ws?id=${id}&role=${role}&name=${name}&token=${token}`);
}

// Kolektor pesan per-koneksi agar kita bisa menunggu tipe tertentu sambil
// melewatkan siaran `devices` yang wajar datang.
function collector(ws) {
  const queue = [];
  const waiters = [];
  ws.on('message', (raw) => {
    const m = JSON.parse(raw.toString());
    const i = waiters.findIndex((w) => w.type === m.type);
    if (i >= 0) waiters.splice(i, 1)[0].resolve(m);
    else queue.push(m);
  });
  return {
    waitFor(type, timeoutMs = 3000) {
      const i = queue.findIndex((m) => m.type === type);
      if (i >= 0) return Promise.resolve(queue.splice(i, 1)[0]);
      return new Promise((resolve, reject) => {
        const t = setTimeout(() => reject(new Error(`timeout menunggu ${type}`)), timeoutMs);
        waiters.push({ type, resolve: (m) => { clearTimeout(t); resolve(m); } });
      });
    },
  };
}

let passed = 0;
let failed = 0;
async function test(name, fn) {
  try {
    await fn();
    passed++;
    console.log(`  ✓ ${name}`);
  } catch (e) {
    failed++;
    console.error(`  ✗ ${name}\n    ${e.message}`);
  }
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  console.log('XyDesk signaling — uji end-to-end\n');

  await test('token salah ditolak (401)', async () => {
    const ws = new WebSocket(`${BASE}/ws?id=dev1&role=host&token=bogus.token.here`);
    const err = await new Promise((resolve) => {
      ws.on('error', () => resolve(true));
      ws.on('open', () => resolve(false));
    });
    if (!err) throw new Error('koneksi dengan token salah malah terbuka');
    ws.close();
  });

  await test('hello -> welcome', async () => {
    const ws = connect('dev1', 'host', 'Gaming PC');
    const col = collector(ws);
    await new Promise((r) => ws.on('open', r));
    ws.send(JSON.stringify({ type: 'hello', to: 'dev1', from: 'Gaming PC', reason: 'host' }));
    const m = await col.waitFor('welcome');
    if (m.from !== 'dev1') throw new Error(`welcome.from=${m.from}`);
    ws.close();
  });

  await test('list -> devices berisi host', async () => {
    const ws = connect('dev1', 'host', 'Gaming PC');
    const col = collector(ws);
    await new Promise((r) => ws.on('open', r));
    ws.send(JSON.stringify({ type: 'hello', to: 'dev1', from: 'Gaming PC', reason: 'host' }));
    await col.waitFor('welcome');
    ws.send(JSON.stringify({ type: 'list' }));
    const m = await col.waitFor('devices');
    const dev = m.devices.find((d) => d.id === 'dev1');
    if (!dev) throw new Error('dev1 tidak ada di daftar');
    if (dev.role !== 'host' || dev.name !== 'Gaming PC') throw new Error('info perangkat salah');
    ws.close();
  });

  await test('pair diteruskan ke host + from ditimpa server', async () => {
    const host = connect('host-1', 'host', 'PC');
    const client = connect('client-1', 'client', 'HP');
    const hc = collector(host), cc = collector(client);
    await new Promise((r) => host.on('open', r));
    await new Promise((r) => client.on('open', r));
    host.send(JSON.stringify({ type: 'hello', to: 'host-1', from: 'PC', reason: 'host' }));
    client.send(JSON.stringify({ type: 'hello', to: 'client-1', from: 'HP', reason: 'client' }));
    await hc.waitFor('welcome'); await cc.waitFor('welcome');

    client.send(JSON.stringify({ type: 'pair', to: 'host-1', pin: '123456' }));
    const m = await hc.waitFor('pair');
    if (m.pin !== '123456' || m.from !== 'client-1') throw new Error(`pair salah: ${JSON.stringify(m)}`);
    host.close(); client.close();
  });

  await test('offer direlay antar peer', async () => {
    const host = connect('host-1', 'host', 'PC');
    const client = connect('client-1', 'client', 'HP');
    const hc = collector(host), cc = collector(client);
    await new Promise((r) => host.on('open', r));
    await new Promise((r) => client.on('open', r));
    host.send(JSON.stringify({ type: 'hello', to: 'host-1', from: 'PC', reason: 'host' }));
    client.send(JSON.stringify({ type: 'hello', to: 'client-1', from: 'HP', reason: 'client' }));
    await hc.waitFor('welcome'); await cc.waitFor('welcome');

    client.send(JSON.stringify({ type: 'offer', to: 'host-1', sdp: { type: 'offer', sdp: 'fake' } }));
    const m = await hc.waitFor('offer');
    if (m.from !== 'client-1' || m.sdp.sdp !== 'fake') throw new Error('offer tidak direlay benar');
    host.close(); client.close();
  });

  await test('relay ke peer offline -> error peer-offline', async () => {
    const client = connect('client-1', 'client', 'HP');
    const cc = collector(client);
    await new Promise((r) => client.on('open', r));
    client.send(JSON.stringify({ type: 'hello', to: 'client-1', from: 'HP', reason: 'client' }));
    await cc.waitFor('welcome');
    client.send(JSON.stringify({ type: 'offer', to: 'ghost', sdp: {} }));
    const m = await cc.waitFor('error');
    if (m.error !== 'peer-offline') throw new Error(`ingin peer-offline, dapat ${m.error}`);
    client.close();
  });

  await test('id duplikat ditolak', async () => {
    const a = connect('dev1', 'host', 'PC A');
    const b = connect('dev1', 'host', 'PC B');
    const ac = collector(a), bc = collector(b);
    await new Promise((r) => a.on('open', r));
    await new Promise((r) => b.on('open', r));
    a.send(JSON.stringify({ type: 'hello', to: 'dev1', from: 'PC A', reason: 'host' }));
    await ac.waitFor('welcome');
    b.send(JSON.stringify({ type: 'hello', to: 'dev1', from: 'PC B', reason: 'host' }));
    const m = await bc.waitFor('error');
    if (m.error !== 'id sudah online') throw new Error(`ingin duplikat, dapat ${m.error}`);
    a.close(); b.close();
  });

  await sleep(200);
  console.log(`\nHasil: ${passed} lulus, ${failed} gagal`);
  process.exit(failed ? 1 : 0);
}

main().catch((e) => { console.error(e); process.exit(1); });

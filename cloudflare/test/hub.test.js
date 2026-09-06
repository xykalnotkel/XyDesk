import test from 'node:test';
import assert from 'node:assert/strict';

import { Hub, PAIR_BRAKE, brakeNew, brakeRecordFailure, brakeState } from '../src/hub.js';

test('arah relay hanya mengizinkan alur client-host yang sah', () => {
  const hub = new Hub({ getWebSockets: () => [] }, {});

  assert.equal(hub.relayAllowed('pair', 'client', 'host'), true);
  assert.equal(hub.relayAllowed('pair', 'client', 'client'), false);
  assert.equal(hub.relayAllowed('pair-response', 'host', 'client'), true);
  assert.equal(hub.relayAllowed('pair-response', 'client', 'host'), false);
  assert.equal(hub.relayAllowed('offer', 'client', 'host'), true);
  assert.equal(hub.relayAllowed('answer', 'host', 'client'), true);
  assert.equal(hub.relayAllowed('ice', 'host', 'client'), true);
  assert.equal(hub.relayAllowed('ice', 'client', 'client'), false);
});

test('bye dan ice sah dua arah, tetapi tidak pernah sesama role', () => {
  const hub = new Hub({ getWebSockets: () => [] }, {});

  assert.equal(hub.relayAllowed('bye', 'host', 'client'), true);
  assert.equal(hub.relayAllowed('bye', 'client', 'host'), true);
  assert.equal(hub.relayAllowed('bye', 'host', 'host'), false);
  assert.equal(hub.relayAllowed('bye', 'client', 'client'), false);

  assert.equal(hub.relayAllowed('ice', 'client', 'host'), true);
  assert.equal(hub.relayAllowed('ice', 'host', 'client'), true);
  assert.equal(hub.relayAllowed('ice', 'host', 'host'), false);
  assert.equal(hub.relayAllowed('ice', 'client', 'client'), false);
});

// ── Rem pairing sisi server ──────────────────────────────────────────────
//
// Yang dijaga di sini bukan hanya "tebakan bisa dicegah", tetapi juga
// "pemilik PC tidak ikut dihukum". Rem di host dulu mengunci SEMUA peer
// (GLOBAL_LOCKOUT di pairguard.rs), sehingga orang yang tahu ID 9 digit bisa
// mengunci pemiliknya keluar dari mesin sendiri dengan sepuluh tebakan salah.

function fakeStorage() {
  const map = new Map();
  return {
    map,
    get: async (k) => map.get(k),
    put: async (k, v) => { map.set(k, v); },
    delete: async (k) => { map.delete(k); },
  };
}

function fakeSocket(meta, outbox) {
  return {
    deserializeAttachment: () => meta,
    serializeAttachment: (m) => Object.assign(meta, m),
    send: (data) => outbox.push(JSON.parse(data)),
  };
}

/// Hub + satu host terdaftar + client terdaftar (harus lewat registri: relay
/// mencari peer di `getWebSockets`, jadi client palsu di luar daftar akan
/// membuat `pair-response` mental sebagai peer-offline).
function harness(clients = []) {
  const storage = fakeStorage();
  const hostOut = [];
  const host = fakeSocket(
    { id: '111222333', role: 'host', name: 'PC', registered: true, ip: '9.9.9.9' },
    hostOut,
  );
  const socks = clients.map((c) =>
    fakeSocket({ id: c.id, role: 'client', name: c.id, registered: true, ip: c.ip }, c.out),
  );
  const hub = new Hub({ getWebSockets: () => [host, ...socks], storage }, {});
  return { hub, host, hostOut, socks, storage };
}

const pairMsg = (to) => ({ type: 'pair', to, pin: 'salah-terus', name: 'hp', platform: 'android' });
const rejectMsg = (to) => ({ type: 'pair-response', to, accepted: false, reason: 'password salah' });

/// Satu ronde percobaan salah: client kirim pair, host jawab ditolak.
async function gagalSekali(hub, sock, host, clientId) {
  await hub.relay(sock, pairMsg('111222333'));
  await hub.relay(host, rejectMsg(clientId));
}

test('brakeRecordFailure mengunci setelah batas dan memulai ulang jendela lama', () => {
  const policy = { maxFailures: 3, lockoutSeconds: 300 };
  const now = 1_000_000;
  let entry = null;
  let res;
  for (let i = 0; i < 2; i += 1) {
    res = brakeRecordFailure(entry, now + i, policy);
    assert.equal(res.locked, false);
    entry = res.entry;
  }
  assert.equal(entry.count, 2);

  res = brakeRecordFailure(entry, now + 2, policy);
  assert.equal(res.locked, true, 'kegagalan ketiga harus mengunci');
  assert.equal(res.retryIn, 300);

  // locked_until = (now+2) + 300; satu detik kemudian sisanya 299.
  assert.equal(brakeState(res.entry, now + 3).locked, true);
  assert.equal(brakeState(res.entry, now + 3).retryIn, 299);

  // Kunci yang sudah lewat tidak boleh diperpanjang kegagalan baru: hitungan
  // mulai dari nol, bukan menyambung.
  const sesudah = now + 2 + 301;
  assert.equal(brakeState(res.entry, sesudah).locked, false);
  const lagi = brakeRecordFailure(res.entry, sesudah, policy);
  assert.equal(lagi.entry.count, 1);
  assert.equal(lagi.locked, false);
});

test('jendela kegagalan yang lewat dibersihkan, bukan diwarisi', () => {
  const policy = { maxFailures: 2, lockoutSeconds: 60 };
  const now = 5_000_000;
  const lama = brakeRecordFailure(brakeNew(now), now, policy).entry;
  assert.equal(lama.count, 1);
  // Jendela (PAIR_BRAKE.windowSeconds) lewat tanpa kegagalan baru.
  const jauh = now + PAIR_BRAKE.windowSeconds + 1;
  assert.equal(brakeState(lama, jauh).expired, true);
  assert.equal(brakeRecordFailure(lama, jauh, policy).entry.count, 1);
});

test('pairing dikunci server setelah lima kegagalan, host tidak diganggu lagi', async () => {
  const out = [];
  const { hub, host, hostOut } = harness([{ id: 'hp-a', ip: '1.2.3.4', out }]);

  for (let i = 0; i < 5; i += 1) {
    await gagalSekali(hub, hub.sockets()[1], host, 'hp-a');
    assert.equal(hostOut.length, i + 1, 'sebelum terkunci, percobaan harus sampai ke host');
  }

  out.length = 0;
  hostOut.length = 0;
  await hub.relay(hub.sockets()[1], pairMsg('111222333'));
  assert.equal(hostOut.length, 0, 'percobaan terkunci tidak boleh menyentuh PC orang lain');
  assert.equal(out.length, 1);
  assert.equal(out[0].type, 'error');
  assert.equal(out[0].error, 'pair-terkunci');
  assert.equal(out[0].reason, 'client');
  assert.equal(out[0].retry_in, PAIR_BRAKE.client.lockoutSeconds);
});

test('client lain tidak ikut terkunci — pemilik PC tidak dihukum', async () => {
  const outA = [];
  const outB = [];
  const { hub, host, socks } = harness([
    { id: 'hp-a', ip: '1.2.3.4', out: outA },
    { id: 'pc-pemilik', ip: '5.6.7.8', out: outB },
  ]);

  for (let i = 0; i < 6; i += 1) await gagalSekali(hub, socks[0], host, 'hp-a');

  outB.length = 0;
  await hub.relay(socks[1], pairMsg('111222333'));
  assert.equal(outB.length, 0, 'client dengan id+IP lain tidak boleh menerima error kunci');
});

test('satu IP yang menyapu banyak client id tetap terkunci', async () => {
  const clients = [];
  for (let i = 0; i < 11; i += 1) clients.push({ id: `penyerang-${i}`, ip: '8.8.8.8', out: [] });
  const { hub, host, socks, storage } = harness(clients);

  // Tiap client id hanya gagal sekali (lingkup per-client tidak pernah penuh),
  // tetapi semuanya dari satu IP.
  for (let i = 0; i < PAIR_BRAKE.ip.maxFailures; i += 1) {
    await gagalSekali(hub, socks[i], host, `penyerang-${i}`);
  }
  const kunciIp = [...storage.map.keys()].filter((k) => k.startsWith('pairbrake:i:'));
  assert.equal(kunciIp.length, 1, 'harus ada tepat satu catatan lingkup IP');
  assert.ok(storage.map.get(kunciIp[0]).locked_until > 0, 'catatan IP harus terkunci');

  // Client id baru dari IP yang sama: langsung ditolak tanpa menyentuh host.
  await hub.relay(socks[10], pairMsg('111222333'));
  assert.equal(clients[10].out[0].error, 'pair-terkunci');
  assert.equal(clients[10].out[0].reason, 'ip');
});

test('IP tidak disimpan mentah di storage', async () => {
  const out = [];
  const { hub, host, storage } = harness([{ id: 'hp-a', ip: '203.0.113.7', out }]);
  await gagalSekali(hub, hub.sockets()[1], host, 'hp-a');
  const semua = [...storage.map.keys()].join(' ');
  assert.ok(!semua.includes('203.0.113.7'), 'IP mentah tidak boleh masuk storage');
  assert.ok(semua.includes('pairbrake:i:'), 'catatan lingkup IP tetap ada (ter-hash)');
});

test('pairing sukses membersihkan hitungan client itu', async () => {
  const out = [];
  const { hub, host, socks } = harness([{ id: 'hp-a', ip: '1.2.3.4', out }]);

  for (let i = 0; i < 4; i += 1) await gagalSekali(hub, socks[0], host, 'hp-a');
  // Sekali berhasil: salah ketik yang diikuti keberhasilan bukan pembobolan.
  await hub.relay(socks[0], pairMsg('111222333'));
  await hub.relay(host, { type: 'pair-response', to: 'hp-a', accepted: true });

  for (let i = 0; i < 4; i += 1) {
    out.length = 0;
    await hub.relay(socks[0], pairMsg('111222333'));
    assert.equal(out.length, 0, 'empat kegagalan baru tidak boleh mengunci client yang barusan sukses');
    await hub.relay(host, rejectMsg('hp-a'));
  }
});

test('alasan dari host diteruskan apa adanya ke client', async () => {
  const out = [];
  const { hub, host } = harness([{ id: 'hp-a', ip: '1.2.3.4', out }]);
  await hub.relay(host, {
    type: 'pair-response', to: 'hp-a', accepted: false, reason: 'password salah', retry_in: 4,
  });
  assert.equal(out.length, 1);
  assert.equal(out[0].from, '111222333', 'server menimpa from dengan id pengirim');
  assert.equal(out[0].reason, 'password salah');
  assert.equal(out[0].retry_in, 4);
});

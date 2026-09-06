import test from 'node:test';
import assert from 'node:assert/strict';

import worker, {
  HOST_REFRESH_TTL,
  signHostRefresh,
  verifyHostRefresh,
  verifyToken,
} from '../src/worker.js';
import { AuthStore } from '../src/authstore.js';

class MemoryStorage {
  values = new Map();

  async get(key) {
    return this.values.get(key);
  }

  async put(key, value) {
    this.values.set(key, structuredClone(value));
  }

  async delete(key) {
    this.values.delete(key);
  }
}

const SECRET = 'refresh-test-secret';
const DEVICE = '123456789';
const CLAIM = 'Kopi Pagi 2026';

function envWith(storage) {
  const store = new AuthStore({ storage }, { XYDESK_SECRET: SECRET, AUTH_SECRET: SECRET });
  return {
    XYDESK_SECRET: SECRET,
    CORS_ORIGINS: 'https://app.xydesk.my.id',
    AUTH_STORE: {
      idFromName: () => 'auth',
      get: () => store,
    },
  };
}

function hostTokenRequest(body) {
  return new Request('https://signal.example/host-token', {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'CF-Connecting-IP': '203.0.113.7' },
    body: JSON.stringify(body),
  });
}

async function callHostToken(env, body) {
  const res = await worker.fetch(hostTokenRequest(body), env, {});
  const text = await res.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {
    json = null;
  }
  return { status: res.status, type: res.headers.get('content-type'), text, json };
}

test('klaim klasik tanpa v2 tetap menjawab token teks polos (kompatibel aplikasi lama)', async () => {
  const res = await callHostToken(envWith(new MemoryStorage()), { id: DEVICE, claim: CLAIM });
  assert.equal(res.status, 200);
  assert.match(res.type, /text\/plain/);
  assert.equal(await verifyToken(res.text, DEVICE, 'host', SECRET), true);
});

test('klaim v2 mengembalikan token sesi sekaligus kredensial penyegaran', async () => {
  const res = await callHostToken(envWith(new MemoryStorage()), {
    id: DEVICE,
    claim: CLAIM,
    v: 2,
  });
  assert.equal(res.status, 200);
  assert.match(res.type, /application\/json/);
  assert.equal(await verifyToken(res.json.token, DEVICE, 'host', SECRET), true);
  assert.equal(await verifyHostRefresh(res.json.refresh, DEVICE, SECRET), true);
});

test('kredensial penyegaran ditukar jadi token sesi tanpa password pairing', async () => {
  const env = envWith(new MemoryStorage());
  const first = await callHostToken(env, { id: DEVICE, claim: CLAIM, v: 2 });
  const next = await callHostToken(env, { id: DEVICE, refresh: first.json.refresh });
  assert.equal(next.status, 200);
  assert.equal(await verifyToken(next.json.token, DEVICE, 'host', SECRET), true);
  // Penyegaran tidak pernah menerbitkan kredensial baru: yang lama tetap
  // berlaku sampai kedaluwarsa atau diganti lewat ikat ulang.
  assert.equal(next.json.refresh, undefined);
});

test('token hasil penyegaran diterima gerbang WebSocket', async () => {
  const env = envWith(new MemoryStorage());
  const first = await callHostToken(env, { id: DEVICE, claim: CLAIM, v: 2 });
  const next = await callHostToken(env, { id: DEVICE, refresh: first.json.refresh });
  assert.equal(await verifyToken(next.json.token, DEVICE, 'host', SECRET), true);
  // Token host tidak boleh dipakai sebagai klien.
  assert.equal(await verifyToken(next.json.token, DEVICE, 'client', SECRET), false);
});

test('kredensial penyegaran yang kedaluwarsa ditolak', async () => {
  const env = envWith(new MemoryStorage());
  const now = Math.floor(Date.now() / 1000);
  const expired = await signHostRefresh(DEVICE, SECRET, now - HOST_REFRESH_TTL * 2);
  assert.equal(await verifyHostRefresh(expired, DEVICE, SECRET), false);
  const res = await callHostToken(env, { id: DEVICE, refresh: expired });
  assert.equal(res.status, 401);
});

test('kredensial penyegaran milik perangkat lain ditolak', async () => {
  const env = envWith(new MemoryStorage());
  const first = await callHostToken(env, { id: DEVICE, claim: CLAIM, v: 2 });
  const res = await callHostToken(env, { id: '987654321', refresh: first.json.refresh });
  assert.equal(res.status, 401);
});

test('kredensial penyegaran yang diutak-atik ditolak', async () => {
  const env = envWith(new MemoryStorage());
  const first = await callHostToken(env, { id: DEVICE, claim: CLAIM, v: 2 });
  const parts = first.json.refresh.split('.');
  const res = await callHostToken(env, {
    id: DEVICE,
    refresh: `${parts[0]}.${parts[1]}.${'0'.repeat(parts[2].length)}`,
  });
  assert.equal(res.status, 401);
});

test('ganti password lewat ikat ulang tidak lagi mengunci perangkat', async () => {
  const env = envWith(new MemoryStorage());
  const first = await callHostToken(env, { id: DEVICE, claim: CLAIM, v: 2 });

  const rebind = await callHostToken(env, {
    id: DEVICE,
    refresh: first.json.refresh,
    claim: 'Password Baru 2026',
  });
  assert.equal(rebind.status, 200);
  assert.equal(await verifyToken(rebind.json.token, DEVICE, 'host', SECRET), true);

  // Password lama tidak berlaku lagi, password baru diterima — dan tidak
  // ada satu pun permintaan yang terkena rem klaim, jadi perangkat tidak
  // pernah masuk kunci 15 menit.
  const oldClaim = await callHostToken(env, { id: DEVICE, claim: CLAIM, v: 2 });
  assert.equal(oldClaim.status, 403);
  const newClaim = await callHostToken(env, { id: DEVICE, claim: 'Password Baru 2026', v: 2 });
  assert.equal(newClaim.status, 200);
});

test('ikat ulang tanpa kredensial penyegaran ditolak — tebakan password tidak bisa mengambil alih', async () => {
  const env = envWith(new MemoryStorage());
  await callHostToken(env, { id: DEVICE, claim: CLAIM, v: 2 });
  // Penyerang yang berhasil menebak password tidak punya kredensial
  // penyegaran, jadi ia tidak bisa memindahkan ikatan ke passwordnya
  // sendiri — jalur ini jatuh ke klaim biasa dan ditolak karena beda hash.
  const res = await callHostToken(env, { id: DEVICE, claim: 'Tebakan Penyerang' });
  assert.equal(res.status, 403);
});

test('ikat ulang dengan kredensial penyegaran palsu ditolak', async () => {
  const env = envWith(new MemoryStorage());
  await callHostToken(env, { id: DEVICE, claim: CLAIM, v: 2 });
  const forged = await signHostRefresh(DEVICE, 'secret-yang-salah');
  const res = await callHostToken(env, { id: DEVICE, refresh: forged, claim: 'Password Baru 2026' });
  assert.equal(res.status, 401);
});

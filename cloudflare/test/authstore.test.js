import test from 'node:test';
import assert from 'node:assert/strict';

import { hashOtp } from '../src/auth.js';
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

test('rate limit OTP membatasi per IP tanpa menyimpan alamat mentah', async () => {
  const storage = new MemoryStorage();
  const store = new AuthStore({ storage }, { AUTH_SECRET: 'rate-limit-test-secret' });
  const request = new Request('https://signal.example/auth/request-otp', {
    headers: { 'CF-Connecting-IP': '203.0.113.10' },
  });
  const now = 1_800_000_000;

  for (let i = 0; i < 8; i++) {
    assert.equal((await store.consumeOtpRateLimit(request, now)).ok, true);
  }
  const blocked = await store.consumeOtpRateLimit(request, now);
  assert.equal(blocked.ok, false);
  assert.equal(blocked.retryIn, 600);
  assert.equal([...storage.values.keys()].some((key) => key.includes('203.0.113.10')), false);
});

test('nama profil baru hanya disimpan setelah OTP benar', async () => {
  const secret = 'verify-name-test-secret';
  const storage = new MemoryStorage();
  const email = 'kall@example.com';
  const otp = '123456';
  await storage.put(`otp:${email}`, {
    hash: await hashOtp(secret, email, otp),
    expires_at: Math.floor(Date.now() / 1000) + 600,
    attempts: 0,
    created_at: Math.floor(Date.now() / 1000),
    pending_name: 'Kall XySpace',
  });
  const store = new AuthStore({ storage }, { AUTH_SECRET: secret });
  const request = new Request('https://signal.example/auth/verify-otp', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email, otp }),
  });

  const response = await store.verifyOtp(request);
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.equal(body.user.name, 'Kall XySpace');
  assert.equal([...storage.values.values()].some((row) => row?.name === 'Kall XySpace'), true);
});

test('sesi tamu berumur pendek dan tidak menyimpan identitas', async () => {
  const storage = new MemoryStorage();
  const store = new AuthStore({ storage }, { AUTH_SECRET: 'guest-test-secret' });
  const response = await store.guest(
    new Request('https://signal.example/auth/guest', { method: 'POST' }),
  );
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.guest, true);
  assert.equal(typeof body.token, 'string');
  assert.equal(storage.values.size, 0);
});

test('penerbitan sesi tamu dibatasi per alamat jaringan', async () => {
  const storage = new MemoryStorage();
  const store = new AuthStore({ storage }, { AUTH_SECRET: 'guest-rate-secret' });
  const request = new Request('https://signal.example/auth/guest', {
    method: 'POST',
    headers: { 'CF-Connecting-IP': '192.0.2.44' },
  });

  for (let index = 0; index < 20; index++) {
    assert.equal((await store.guest(request)).status, 200);
  }
  assert.equal((await store.guest(request)).status, 429);
});

test('klaim host mengikat ID, pemilik, dan password perangkat', async () => {
  const storage = new MemoryStorage();
  const env = {
    AUTH_SECRET: 'host-claim-auth-secret',
    XYDESK_SECRET: 'host-claim-internal-secret',
  };
  const store = new AuthStore({ storage }, env);
  const claim = (owner, password) =>
    store.authorizeHost(
      new Request('https://internal/auth/authorize-host', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'X-XyDesk-Internal': env.XYDESK_SECRET,
        },
        body: JSON.stringify({
          owner,
          device_id: '123456789',
          claim: password,
        }),
      }),
    );

  assert.equal((await claim('user-a', 'PAIRPASS99')).status, 200);
  assert.equal((await claim('user-a', 'PAIRPASS99')).status, 200);
  assert.equal((await claim('user-b', 'PAIRPASS99')).status, 403);
  // Pemilik yang sama boleh merotasi password Host dari UI terpadu.
  assert.equal((await claim('user-a', 'NEWPASS999')).status, 200);
});

test('bucket rate limit OTP dibuka kembali setelah jendela selesai', async () => {
  const storage = new MemoryStorage();
  const store = new AuthStore({ storage }, { AUTH_SECRET: 'rate-limit-test-secret' });
  const request = new Request('https://signal.example/auth/request-otp', {
    headers: { 'CF-Connecting-IP': '198.51.100.2' },
  });

  for (let i = 0; i < 8; i++) await store.consumeOtpRateLimit(request, 1000);
  assert.equal((await store.consumeOtpRateLimit(request, 1000)).ok, false);
  assert.equal((await store.consumeOtpRateLimit(request, 1600)).ok, true);
});

// ── Rem klaim device ──────────────────────────────────────────────────────
// Jalur /host-token tidak melewati pairguard.rs sama sekali: penyerang
// menukar {device_id, claim} di edge tanpa pernah menyentuh PC korban. Kalau
// test-test di bawah merah, host orang lain bisa direbut lewat tebakan massal.

function claimRequest(secret, deviceId, claim, ip = '203.0.113.77') {
  return new Request('https://internal/auth/claim-device', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'X-XyDesk-Internal': secret,
      'CF-Connecting-IP': ip,
    },
    body: JSON.stringify({ device_id: deviceId, claim }),
  });
}

test('klaim device salah berulang mengunci device, bukan cuma menolak', async () => {
  const secret = 'claim-lock-test-secret';
  const storage = new MemoryStorage();
  const store = new AuthStore({ storage }, { XYDESK_SECRET: secret, AUTH_SECRET: secret });

  // Device sudah diklaim pemilik sah.
  const first = await store.claimDevice(claimRequest(secret, '123456789', 'sandi-asli'));
  assert.equal(first.status, 200);
  assert.equal((await first.json()).claimed, true);

  // Empat tebakan salah masih dijawab 403 biasa.
  for (let i = 0; i < 4; i++) {
    const res = await store.claimDevice(
      claimRequest(secret, '123456789', `tebakan-${i}`, `198.51.100.${i}`),
    );
    assert.equal(res.status, 403, `tebakan ke-${i} seharusnya 403`);
  }

  // Yang kelima mengunci device — dan penyerang berganti IP tiap kali,
  // jadi yang menahan di sini murni rem per-device.
  const locked = await store.claimDevice(
    claimRequest(secret, '123456789', 'tebakan-5', '198.51.100.200'),
  );
  assert.equal(locked.status, 429);
  const body = await locked.json();
  assert.equal(body.error, 'device-locked');
  assert.ok(body.retry_in > 0);

  // Selama terkunci, password yang BENAR pun ditahan — penyerang tidak boleh
  // memakai oracle "mana yang masih dijawab 403" untuk memisahkan tebakan.
  const evenCorrect = await store.claimDevice(
    claimRequest(secret, '123456789', 'sandi-asli', '198.51.100.201'),
  );
  assert.equal(evenCorrect.status, 429);
});

test('klaim benar menghapus catatan kegagalan device', async () => {
  const secret = 'claim-reset-test-secret';
  const storage = new MemoryStorage();
  const store = new AuthStore({ storage }, { XYDESK_SECRET: secret, AUTH_SECRET: secret });

  await store.claimDevice(claimRequest(secret, '987654321', 'sandi-asli'));
  for (let i = 0; i < 3; i++) {
    await store.claimDevice(claimRequest(secret, '987654321', `salah-${i}`));
  }
  assert.ok(await storage.get('claimfail:987654321'));

  // Pemilik sah salah ketik beberapa kali lalu benar: jatahnya pulih penuh.
  const ok = await store.claimDevice(claimRequest(secret, '987654321', 'sandi-asli'));
  assert.equal(ok.status, 200);
  assert.equal(await storage.get('claimfail:987654321'), undefined);
});

test('kunci device kedaluwarsa sendiri setelah lockout lewat', async () => {
  const secret = 'claim-expiry-test-secret';
  const storage = new MemoryStorage();
  const store = new AuthStore({ storage }, { XYDESK_SECRET: secret, AUTH_SECRET: secret });
  const now = Math.floor(Date.now() / 1000);

  await storage.put('claimfail:111222333', { count: 0, locked_until: now - 1 });
  const state = await store.claimLockState('111222333', now);
  assert.equal(state.locked, false);
  assert.equal(await storage.get('claimfail:111222333'), undefined);
});

test('rem per IP menahan sapuan lintas banyak device', async () => {
  const secret = 'claim-ip-test-secret';
  const storage = new MemoryStorage();
  const store = new AuthStore({ storage }, { XYDESK_SECRET: secret, AUTH_SECRET: secret });

  // Penyerang menyapu device berbeda-beda dari satu IP, jadi rem per-device
  // tidak pernah kena. Yang harus menahan adalah rem per-IP (30/10 menit).
  let blocked = 0;
  for (let i = 0; i < 40; i++) {
    const deviceId = String(100000000 + i);
    const res = await store.claimDevice(claimRequest(secret, deviceId, 'tebakan-sapu'));
    if (res.status === 429) blocked += 1;
  }
  assert.ok(blocked >= 10, `harusnya sebagian besar ditahan, ditahan: ${blocked}`);
});

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

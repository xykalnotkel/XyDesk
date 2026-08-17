import test from 'node:test';
import assert from 'node:assert/strict';

import { AuthStore } from '../src/authstore.js';

class MemoryStorage {
  values = new Map();

  async get(key) {
    return this.values.get(key);
  }

  async put(key, value) {
    this.values.set(key, structuredClone(value));
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

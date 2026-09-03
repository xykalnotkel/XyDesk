import test from 'node:test';
import assert from 'node:assert/strict';

import {
  authConstants,
  generateOtp,
  signJwt,
  timingSafeEqual,
  validateEmail,
  verifyJwt,
} from '../src/auth.js';

const SECRET = 'test-secret-with-enough-entropy-for-hmac';

function encodeJson(value) {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

async function signRaw(header, payload) {
  const h = encodeJson(header);
  const p = encodeJson(payload);
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(SECRET),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'HMAC',
    key,
    new TextEncoder().encode(`${h}.${p}`),
  );
  return `${h}.${p}.${Buffer.from(signature).toString('base64url')}`;
}

test('JWT valid dapat diverifikasi', async () => {
  const token = await signJwt({ sub: 'user-1', email: 'kall@example.com' }, SECRET, 60);
  const payload = await verifyJwt(token, SECRET);

  assert.equal(payload?.sub, 'user-1');
  assert.equal(payload?.email, 'kall@example.com');
});

test('JWT menolak signature yang dimodifikasi', async () => {
  const token = await signJwt({ sub: 'user-1' }, SECRET, 60);
  const parts = token.split('.');
  // Ubah byte awal. Karakter base64url terakhir bisa punya padding bit yang
  // tidak signifikan dan tetap mendecode ke byte yang sama.
  parts[2] = `${parts[2].startsWith('A') ? 'B' : 'A'}${parts[2].slice(1)}`;

  assert.equal(await verifyJwt(parts.join('.'), SECRET), null);
});

test('JWT menolak algoritma selain HS256 walau HMAC cocok', async () => {
  const now = Math.floor(Date.now() / 1000);
  const forged = await signRaw(
    { alg: 'none', typ: 'JWT' },
    { sub: 'user-1', iat: now, exp: now + 60 },
  );

  assert.equal(await verifyJwt(forged, SECRET), null);
});

test('JWT kedaluwarsa dan token tanpa exp ditolak', async () => {
  const expired = await signJwt({ sub: 'user-1' }, SECRET, -1);
  assert.equal(await verifyJwt(expired, SECRET), null);

  const now = Math.floor(Date.now() / 1000);
  const missingExp = await signRaw(
    { alg: 'HS256', typ: 'JWT' },
    { sub: 'user-1', iat: now },
  );
  assert.equal(await verifyJwt(missingExp, SECRET), null);
});

test('OTP selalu enam digit dan email divalidasi', () => {
  for (let i = 0; i < 250; i++) assert.match(generateOtp(), /^\d{6}$/);
  assert.equal(validateEmail('kall@example.com'), true);
  assert.equal(validateEmail('bukan-email'), false);
  assert.equal(authConstants.OTP_MAX_ATTEMPTS, 5);
});

test('perbandingan aman menangani panjang berbeda tanpa salah positif', () => {
  assert.equal(timingSafeEqual('abc', 'abc'), true);
  assert.equal(timingSafeEqual('abc', 'abcd'), false);
  assert.equal(timingSafeEqual('abc', 'abd'), false);
});

// ── Kasus tepi verifyJwt — setiap baris kode di verifyJwt adalah kontrak. ──

async function signRawStr(h, p) {
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(SECRET), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`${h}.${p}`));
  return `${h}.${p}.${Buffer.from(sig).toString('base64url')}`;
}

test('JWT menolak typ selain JWT walau tanda tangan sah', async () => {
  const now = Math.floor(Date.now() / 1000);
  const token = await signRaw(
    { alg: 'HS256', typ: 'JWE' },
    { sub: 'user-1', iat: now, exp: now + 60 },
  );
  assert.equal(await verifyJwt(token, SECRET), null);
});

test('JWT menolak nbf di masa depan', async () => {
  const now = Math.floor(Date.now() / 1000);
  const token = await signRaw(
    { alg: 'HS256', typ: 'JWT' },
    { sub: 'user-1', iat: now, exp: now + 3600, nbf: now + 120 },
  );
  assert.equal(await verifyJwt(token, SECRET), null);
});

test('JWT menolak iat lebih dari satu menit di masa depan', async () => {
  const now = Math.floor(Date.now() / 1000);
  const token = await signRaw(
    { alg: 'HS256', typ: 'JWT' },
    { sub: 'user-1', iat: now + 120, exp: now + 3600 },
  );
  assert.equal(await verifyJwt(token, SECRET), null);
});

test('JWT dengan payload korup (tanda tangan sah) ditolak', async () => {
  const now = Math.floor(Date.now() / 1000);
  const h = encodeJson({ alg: 'HS256', typ: 'JWT' });
  const p = Buffer.from('{ini bukan json').toString('base64url');
  const token = await signRawStr(h, p);
  assert.equal(await verifyJwt(token, SECRET), null);
});

test('verifyJwt menolak token kosong, bagian kurang, dan secret kosong', async () => {
  const token = await signJwt({ sub: 'user-1' }, SECRET, 60);
  assert.equal(await verifyJwt('', SECRET), null);
  assert.equal(await verifyJwt('satu.bagian', SECRET), null);
  assert.equal(await verifyJwt(token, ''), null);
});

test('verifyJwt menolak tanda tangan dari secret yang berbeda', async () => {
  const token = await signJwt({ sub: 'user-1' }, SECRET, 60);
  assert.equal(await verifyJwt(token, 'secret-yang-lain'), null);
});

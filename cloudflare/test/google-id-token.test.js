// Verifikasi ID token Google (RS256 via JWKS) — jalur OAuth "masuk dengan
// Google" untuk worker signaling.
//
// `verifyGoogleIdToken` adalah gerbang kepercayaan untuk identitas Google:
// kalau ia lolos memeriksa token yang seharusnya ditolak, penyerang bisa
// memakai identitas orang lain. Fungsi ini selama ini belum punya satu pun
// test — satu-satunya fungsi kripto auth yang begitu.
//
// Yang diuji di sini: tiap cabang penolakan (audience, issuer, masa berlaku,
// verifikasi email, sub), plus jalur bahagia memakai kunci RSA sungguhan
// yang ditandatangani di tempat (bukan mock yang selalu `ok: true`).

import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, sign as rsaSign } from 'node:crypto';

import { verifyGoogleIdToken } from '../src/auth.js';

const KID = 'google-test-kid';
const JWKS_URL = 'https://www.googleapis.com/oauth2/v3/certs';

const { publicKey, privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const jwk = { ...publicKey.export({ format: 'jwk' }), kid: KID, alg: 'RS256', use: 'sig' };

function b64u(value) {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

function signToken(header, payload) {
  const h = b64u(header);
  const p = b64u(payload);
  const sig = rsaSign('RSA-SHA256', Buffer.from(`${h}.${p}`), privateKey);
  return `${h}.${p}.${Buffer.from(sig).toString('base64url')}`;
}

function mockJwks(keys) {
  globalThis.fetch = async () => new Response(JSON.stringify({ keys }), { status: 200 });
}

function mockJwksDown() {
  globalThis.fetch = async () => new Response('boom', { status: 500 });
}

const NOW = () => Math.floor(Date.now() / 1000);

function basePayload(overrides = {}) {
  return {
    aud: '495336144977-dp1k3678cocjrfhftb9blnqo5qnvhsr6.apps.googleusercontent.com',
    iss: 'https://accounts.google.com',
    exp: NOW() + 3600,
    email: 'founder@example.com',
    email_verified: true,
    sub: 'google-sub-123',
    name: 'Haekal Saputra',
    picture: 'https://example.com/p.jpg',
    ...overrides,
  };
}

const ENV = { GOOGLE_CLIENT_ID: '495336144977-dp1k3678cocjrfhftb9blnqo5qnvhsr6.apps.googleusercontent.com' };

test('tanpa GOOGLE_CLIENT_ID terkonfigurasi, verifikasi menolak 503', async () => {
  const res = await verifyGoogleIdToken({}, 'apa pun');
  assert.equal(res.ok, false);
  assert.equal(res.status, 503);
  assert.equal(res.error, 'google-not-configured');
});

test('tanpa id token, verifikasi menolak 400', async () => {
  const res = await verifyGoogleIdToken(ENV, undefined);
  assert.equal(res.ok, false);
  assert.equal(res.error, 'missing-id-token');
});

test('token bukan tiga bagian ditolak', async () => {
  const res = await verifyGoogleIdToken(ENV, 'dua.bagian');
  assert.equal(res.ok, false);
  assert.equal(res.error, 'invalid-token');
});

test('header yang bukan JSON ditolak', async () => {
  const h = Buffer.from('bukan json').toString('base64url');
  const res = await verifyGoogleIdToken(ENV, `${h}.a.b`);
  assert.equal(res.ok, false);
  assert.equal(res.error, 'invalid-token');
});

test('algoritma selain RS256 atau tanpa kid ditolak sebelum fetch', async () => {
  let fetched = false;
  globalThis.fetch = async () => {
    fetched = true;
    return new Response('{}', { status: 200 });
  };

  const hs = signToken({ alg: 'HS256', kid: KID, typ: 'JWT' }, basePayload());
  const noKid = signToken({ alg: 'RS256', typ: 'JWT' }, basePayload());

  const r1 = await verifyGoogleIdToken(ENV, hs);
  assert.equal(r1.error, 'unsupported-alg');

  const r2 = await verifyGoogleIdToken(ENV, noKid);
  assert.equal(r2.error, 'unsupported-alg');

  assert.equal(fetched, false, 'JWKS tidak boleh diambil untuk header yang jelas salah');
});

test('JWKS yang tidak bisa diambil ditolak 502', async () => {
  mockJwksDown();
  const token = signToken({ alg: 'RS256', kid: KID, typ: 'JWT' }, basePayload());
  const res = await verifyGoogleIdToken(ENV, token);
  assert.equal(res.ok, false);
  assert.equal(res.status, 502);
  assert.equal(res.error, 'jwks-unavailable');
});

test('kid yang tidak dikenal ditolak', async () => {
  mockJwks([jwk]);
  const token = signToken({ alg: 'RS256', kid: 'kid-lain', typ: 'JWT' }, basePayload());
  const res = await verifyGoogleIdToken(ENV, token);
  assert.equal(res.ok, false);
  assert.equal(res.error, 'unknown-kid');
});

test('signature yang tidak cocok dengan kunci di JWKS ditolak', async () => {
  // JWKS memuat kunci LAIN, bukan kunci yang menandatangani token.
  const { publicKey: otherPub } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const otherJwk = { ...otherPub.export({ format: 'jwk' }), kid: KID, alg: 'RS256', use: 'sig' };
  mockJwks([otherJwk]);

  const token = signToken({ alg: 'RS256', kid: KID, typ: 'JWT' }, basePayload());
  const res = await verifyGoogleIdToken(ENV, token);
  assert.equal(res.ok, false);
  assert.equal(res.error, 'bad-signature');
});

test('token Google yang sah lolos dan menormalkan email', async () => {
  mockJwks([jwk]);
  const token = signToken(
    { alg: 'RS256', kid: KID, typ: 'JWT' },
    basePayload({ email: 'FOUNDER@Example.COM' }),
  );
  const res = await verifyGoogleIdToken(ENV, token);
  assert.equal(res.ok, true);
  assert.equal(res.email, 'founder@example.com');
  assert.equal(res.sub, 'google-sub-123');
  assert.equal(res.name, 'Haekal Saputra');
  assert.equal(res.picture, 'https://example.com/p.jpg');
});

test('audience di luar daftar ditolak; daftar dipisah koma diterima', async () => {
  mockJwks([jwk]);
  const multi = { GOOGLE_CLIENT_ID: 'android-client.apps.googleusercontent.com, 495336144977-dp1k3678cocjrfhftb9blnqo5qnvhsr6.apps.googleusercontent.com' };

  const salah = await verifyGoogleIdToken(ENV, signToken({ alg: 'RS256', kid: KID, typ: 'JWT' }, basePayload({ aud: 'klien-asing' })));
  assert.equal(salah.ok, false);
  assert.equal(salah.error, 'bad-audience');

  const benar = await verifyGoogleIdToken(multi, signToken({ alg: 'RS256', kid: KID, typ: 'JWT' }, basePayload({ aud: 'android-client.apps.googleusercontent.com' })));
  assert.equal(benar.ok, true);
});

test('issuer selain accounts.google.com ditolak', async () => {
  mockJwks([jwk]);
  const res = await verifyGoogleIdToken(ENV, signToken({ alg: 'RS256', kid: KID, typ: 'JWT' }, basePayload({ iss: 'https://evil.example' })));
  assert.equal(res.ok, false);
  assert.equal(res.error, 'bad-issuer');
});

test('token kedaluwarsa atau tanpa exp ditolak', async () => {
  mockJwks([jwk]);
  const expired = await verifyGoogleIdToken(ENV, signToken({ alg: 'RS256', kid: KID, typ: 'JWT' }, basePayload({ exp: NOW() - 60 })));
  assert.equal(expired.error, 'expired');

  const noExp = await verifyGoogleIdToken(ENV, signToken({ alg: 'RS256', kid: KID, typ: 'JWT' }, basePayload({ exp: undefined })));
  assert.equal(noExp.error, 'expired');
});

test('email kosong, belum terverifikasi, atau tanpa sub ditolak', async () => {
  mockJwks([jwk]);
  const hdr = () => ({ alg: 'RS256', kid: KID, typ: 'JWT' });

  const noEmail = await verifyGoogleIdToken(ENV, signToken(hdr(), basePayload({ email: undefined })));
  assert.equal(noEmail.error, 'no-email');

  const unverified = await verifyGoogleIdToken(ENV, signToken(hdr(), basePayload({ email_verified: false })));
  assert.equal(unverified.error, 'email-not-verified');

  const noSub = await verifyGoogleIdToken(ENV, signToken(hdr(), basePayload({ sub: undefined })));
  assert.equal(noSub.error, 'missing-sub');
});

test('issuer tanpa skema (accounts.google.com) juga diterima', async () => {
  mockJwks([jwk]);
  const res = await verifyGoogleIdToken(ENV, signToken({ alg: 'RS256', kid: KID, typ: 'JWT' }, basePayload({ iss: 'accounts.google.com' })));
  assert.equal(res.ok, true);
});

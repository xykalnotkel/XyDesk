// Admin berita via Google ID token — jalur kedua selain ADMIN_TOKEN.
//
// Mengunci janji keamanan yang sama seperti worker signaling: verifikasi
// signature + audience sungguhan (RS256 via JWKS), email harus ==
// FOUNDER_EMAIL, dan gagal-tertutup bila konfigurasi tidak lengkap. Kalau
// test ini merah, badge resmi bisa dipalsukan lewat curl.

import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, sign as rsaSign } from 'node:crypto';

import { verifyGoogleIdToken, verifyFounderAdmin } from '../src/auth.js';
import { addComment } from '../src/worker.js';
import worker from '../src/worker.js';

const KID = 'google-test-kid';
const { publicKey, privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const jwk = { ...publicKey.export({ format: 'jwk' }), kid: KID, alg: 'RS256', use: 'sig' };

const WEB_CLIENT_ID = '495336144977-dp1k3678cocjrfhftb9blnqo5qnvhsr6.apps.googleusercontent.com';
const FOUNDER = 'xycdigital@gmail.com';

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
const NOW = () => Math.floor(Date.now() / 1000);
function basePayload(overrides = {}) {
  return {
    aud: WEB_CLIENT_ID,
    iss: 'https://accounts.google.com',
    exp: NOW() + 3600,
    email: FOUNDER,
    email_verified: true,
    sub: 'google-sub-123',
    ...overrides,
  };
}
const ENV = { GOOGLE_CLIENT_ID: WEB_CLIENT_ID, FOUNDER_EMAIL: FOUNDER };
const goodToken = () => signToken({ alg: 'RS256', kid: KID, typ: 'JWT' }, basePayload());

// ── Stub D1 ─────────────────────────────────────────────────────────────
function fakeDb() {
  const inserted = [];
  const calls = [];
  return {
    inserted,
    calls,
    prepare(sql) {
      const stmt = {
        sql,
        args: [],
        bind(...a) {
          stmt.args = a;
          return stmt;
        },
        async first() {
          // Cek duplikat slug dulu — pola `FROM posts` yang lebih umum di
          // bawah juga cocok dengan query ini.
          if (/SELECT id FROM posts WHERE slug/i.test(sql)) return null;
          if (/FROM posts/i.test(sql)) return { id: 1, slug: 'artikel', published: 1 };
          if (/COUNT\(\*\)/i.test(sql)) return { c: 0 };
          return null;
        },
        async run() {
          if (/INSERT INTO comments/i.test(sql)) inserted.push({ sql, args: stmt.args });
          if (/INSERT INTO posts/i.test(sql)) calls.push({ sql, args: stmt.args });
          return { meta: { last_row_id: inserted.length + calls.length } };
        },
        async all() {
          return { results: [] };
        },
      };
      return stmt;
    },
  };
}

// ── verifyGoogleIdToken (port, supaya salinan di worker berita tetap terkunci) ──
test('tanpa GOOGLE_CLIENT_ID, verifikasi menolak 503', async () => {
  const res = await verifyGoogleIdToken({}, 'apa pun');
  assert.equal(res.ok, false);
  assert.equal(res.status, 503);
});

test('token Google sah lolos, email dinormalkan huruf kecil', async () => {
  mockJwks([jwk]);
  const res = await verifyGoogleIdToken(ENV, signToken(
    { alg: 'RS256', kid: KID, typ: 'JWT' },
    basePayload({ email: 'XYCDIGITAL@GMAIL.COM' }),
  ));
  assert.equal(res.ok, true);
  assert.equal(res.email, FOUNDER);
});

test('signature salah ditolak', async () => {
  const { publicKey: otherPub } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const otherJwk = { ...otherPub.export({ format: 'jwk' }), kid: KID, alg: 'RS256', use: 'sig' };
  mockJwks([otherJwk]);
  const res = await verifyGoogleIdToken(ENV, goodToken());
  assert.equal(res.ok, false);
  assert.equal(res.error, 'bad-signature');
});

test('audience salah / kedaluwarsa / email belum diverifikasi ditolak', async () => {
  mockJwks([jwk]);
  const hdr = { alg: 'RS256', kid: KID, typ: 'JWT' };
  assert.equal((await verifyGoogleIdToken(ENV, signToken(hdr, basePayload({ aud: 'asing' })))).error, 'bad-audience');
  assert.equal((await verifyGoogleIdToken(ENV, signToken(hdr, basePayload({ exp: NOW() - 60 })))).error, 'expired');
  assert.equal((await verifyGoogleIdToken(ENV, signToken(hdr, basePayload({ email_verified: false })))).error, 'email-not-verified');
});

// ── verifyFounderAdmin ──────────────────────────────────────────────────
test('tanpa token apa pun → bukan admin', async () => {
  const req = new Request('https://news.example/api/x', { method: 'POST' });
  assert.equal(await verifyFounderAdmin(ENV, req), false);
});

test('ADMIN_TOKEN yang cocok tetap sah (jalur lama tidak berubah)', async () => {
  const env = { ADMIN_TOKEN: 'rahasia' };
  const req = new Request('https://news.example/api/x', { method: 'POST', headers: { 'x-admin-token': 'rahasia' } });
  assert.equal(await verifyFounderAdmin(env, req), true);
});

test('Google token founder → admin; email non-founder → bukan admin', async () => {
  mockJwks([jwk]);
  const env = { ...ENV, ADMIN_TOKEN: 'rahasia' };
  const founderReq = new Request('https://news.example/api/x', {
    method: 'POST',
    headers: { 'x-admin-google-token': goodToken() },
  });
  assert.equal(await verifyFounderAdmin(env, founderReq), true);

  const asing = signToken({ alg: 'RS256', kid: KID, typ: 'JWT' }, basePayload({ email: 'orang@lain.com' }));
  const asingReq = new Request('https://news.example/api/x', {
    method: 'POST',
    headers: { 'x-admin-google-token': asing },
  });
  assert.equal(await verifyFounderAdmin(env, asingReq), false);
});

test('tanpa FOUNDER_EMAIL, jalur Google nonaktif (gagal-tertutup)', async () => {
  mockJwks([jwk]);
  const req = new Request('https://news.example/api/x', {
    method: 'POST',
    headers: { 'x-admin-google-token': goodToken() },
  });
  assert.equal(await verifyFounderAdmin({ GOOGLE_CLIENT_ID: WEB_CLIENT_ID }, req), false);
});

// ── Integrasi: komentar & publish ───────────────────────────────────────
test('komentar founder lewat Google token: badge resmi + nama tim diizinkan', async () => {
  mockJwks([jwk]);
  const db = fakeDb();
  const env = { DB: db, ADMIN_TOKEN: 'rahasia', ...ENV };
  const req = new Request('https://news.example/api/news/artikel/comments', {
    method: 'POST',
    headers: { 'x-admin-google-token': goodToken() },
  });
  const res = await addComment(env, 'artikel', {
    author: 'Haekal Saputra',
    content: 'jawaban resmi',
    fp: 'fp-found',
  }, req);
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.comment.official, true);
  const ins = db.inserted.find((i) => /INSERT INTO comments/i.test(i.sql));
  assert.ok(ins, 'harus ada INSERT komentar');
  // flag official = 1 (kolom terakhir pada INSERT tanpa parent)
  assert.equal(ins.args[ins.args.length - 1], 1);
});

test('komentar publik tetap tidak bisa memakai nama tim', async () => {
  const db = fakeDb();
  const env = { DB: db, ADMIN_TOKEN: 'rahasia' };
  const req = new Request('https://news.example/api/news/artikel/comments', { method: 'POST' });
  const res = await addComment(env, 'artikel', {
    author: 'Haekal Saputra',
    content: 'pura-pura resmi',
    fp: 'fp-1',
  }, req);
  assert.equal(res.status, 403);
  assert.equal(db.inserted.length, 0);
});

test('publish dengan Google token founder berhasil; non-founder 401', async () => {
  mockJwks([jwk]);
  const body = { title: 'Judul rilis', content: 'Isi rilis lengkap', slug: 'changelog-v6-4-2' };

  const founderDb = fakeDb();
  const founderReq = new Request('https://news.example/api/admin/publish', {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-admin-google-token': goodToken() },
    body: JSON.stringify(body),
  });
  const okRes = await worker.fetch(founderReq, { DB: founderDb, ...ENV });
  assert.equal(okRes.status, 200);
  assert.ok(founderDb.calls.some((c) => /INSERT INTO posts/i.test(c.sql)), 'harus ada INSERT artikel');

  const asingToken = signToken({ alg: 'RS256', kid: KID, typ: 'JWT' }, basePayload({ email: 'orang@lain.com' }));
  const asingDb = fakeDb();
  const asingReq = new Request('https://news.example/api/admin/publish', {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-admin-google-token': asingToken },
    body: JSON.stringify(body),
  });
  const asingRes = await worker.fetch(asingReq, { DB: asingDb, ...ENV });
  assert.equal(asingRes.status, 401);
  assert.equal(asingDb.calls.length, 0, 'tanpa izin tidak boleh ada INSERT');
});

test('publish tanpa token apa pun tetap 401', async () => {
  const db = fakeDb();
  const req = new Request('https://news.example/api/admin/publish', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ title: 'Judul', content: 'Isi isi isi isi' }),
  });
  const res = await worker.fetch(req, { DB: db, ...ENV });
  assert.equal(res.status, 401);
  assert.equal(db.calls.length, 0);
});

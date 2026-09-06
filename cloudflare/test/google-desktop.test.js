// Login Google untuk aplikasi desktop (Electron) — penukaran authorization
// code + PKCE di Worker, dan penerimaan audience client Desktop.
//
// Kenapa jalur ini perlu uji sendiri: ia menambah SATU sumber audience baru
// (`GOOGLE_DESKTOP_CLIENT_ID`) ke gerbang kepercayaan identitas. Melonggarkan
// pemeriksaan audience adalah perubahan yang kalau salah tidak menghasilkan
// error — ia menghasilkan akun yang bisa diklaim orang lain. Jadi yang diuji
// di sini bukan hanya "bisa login", tapi juga "tetap menolak yang harus
// ditolak".
//
// Client secret sengaja tidak pernah diuji dengan nilai sungguhan: fungsinya
// hanya meneruskan apa yang ada di env ke endpoint token Google.

import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, sign as rsaSign } from 'node:crypto';

import { exchangeGoogleCode, verifyGoogleIdToken } from '../src/auth.js';

const DESKTOP_CLIENT_ID = '111111111111-desktopdesktop.apps.googleusercontent.com';
const WEB_CLIENT_ID = '222222222222-webwebweb.apps.googleusercontent.com';
const KID = 'google-desktop-kid';
const JWKS_URL = 'https://www.googleapis.com/oauth2/v3/certs';
const TOKEN_URL = 'https://oauth2.googleapis.com/token';

const envSiap = {
  GOOGLE_CLIENT_ID: WEB_CLIENT_ID,
  GOOGLE_DESKTOP_CLIENT_ID: DESKTOP_CLIENT_ID,
  GOOGLE_DESKTOP_CLIENT_SECRET: 'rahasia-uji-bukan-nyata',
};

// ── Konfigurasi & validasi masukan ──────────────────────────────────────────

test('desktop: 503 bila client id/secret belum dikonfigurasi', async () => {
  const r = await exchangeGoogleCode({}, { code: 'c', codeVerifier: 'v' });
  assert.equal(r.ok, false);
  assert.equal(r.status, 503);
  assert.equal(r.error, 'google-desktop-not-configured');
});

test('desktop: 503 bila hanya secret yang hilang', async () => {
  const r = await exchangeGoogleCode(
    { GOOGLE_DESKTOP_CLIENT_ID: DESKTOP_CLIENT_ID },
    { code: 'c', codeVerifier: 'v' },
  );
  assert.equal(r.status, 503);
});

test('desktop: code dan code_verifier wajib ada', async () => {
  const tanpaCode = await exchangeGoogleCode(envSiap, { codeVerifier: 'v' });
  assert.equal(tanpaCode.status, 400);
  assert.equal(tanpaCode.error, 'missing-code');

  const tanpaVerifier = await exchangeGoogleCode(envSiap, { code: 'c' });
  assert.equal(tanpaVerifier.status, 400);
  assert.equal(tanpaVerifier.error, 'missing-code-verifier');
});

test('desktop: redirect_uri harus loopback', async () => {
  const sah = ['http://localhost', 'http://localhost:51234', 'http://127.0.0.1:8080/cb'];
  for (const uri of sah) {
    let dipanggil = false;
    globalThis.fetch = async () => {
      dipanggil = true;
      return new Response(JSON.stringify({ id_token: 'x.y.z' }), { status: 200 });
    };
    const r = await exchangeGoogleCode(envSiap, { code: 'c', codeVerifier: 'v', redirectUri: uri });
    assert.equal(r.ok, true, `loopback harus diterima: ${uri}`);
    assert.equal(dipanggil, true);
  }

  // Menerima redirect non-loopback berarti menerima `code` yang bisa dicuri
  // dari domain lain — pintu terbuka untuk code injection.
  const ditolak = [
    'https://evil.example.com/cb',
    'http://evil.example.com/cb',
    'http://localhost.evil.example.com/cb',
    'https://localhost/cb',
  ];
  for (const uri of ditolak) {
    globalThis.fetch = async () => {
      throw new Error('tidak boleh sampai memanggil Google');
    };
    const r = await exchangeGoogleCode(envSiap, { code: 'c', codeVerifier: 'v', redirectUri: uri });
    assert.equal(r.ok, false, `harus ditolak: ${uri}`);
    assert.equal(r.status, 400);
    assert.equal(r.error, 'bad-redirect-uri');
  }
});

// ── Perilaku terhadap endpoint token Google ─────────────────────────────────

test('desktop: meneruskan code + PKCE + client ke endpoint token', async () => {
  let terkirim = null;
  globalThis.fetch = async (url, init) => {
    terkirim = { url, init };
    return new Response(JSON.stringify({ id_token: 'header.payload.sig', access_token: 'a' }), {
      status: 200,
    });
  };
  const r = await exchangeGoogleCode(envSiap, {
    code: '4/0AXcode',
    codeVerifier: 'verifier-panjang',
    redirectUri: 'http://localhost:43210',
  });
  assert.equal(r.ok, true);
  assert.equal(r.idToken, 'header.payload.sig');
  assert.equal(terkirim.url, TOKEN_URL);
  assert.equal(terkirim.init.method, 'POST');
  const body = new URLSearchParams(terkirim.init.body);
  assert.equal(body.get('grant_type'), 'authorization_code');
  assert.equal(body.get('code'), '4/0AXcode');
  assert.equal(body.get('code_verifier'), 'verifier-panjang');
  assert.equal(body.get('client_id'), DESKTOP_CLIENT_ID);
  assert.equal(body.get('client_secret'), envSiap.GOOGLE_DESKTOP_CLIENT_SECRET);
  assert.equal(body.get('redirect_uri'), 'http://localhost:43210');
});

test('desktop: kesalahan Google diteruskan apa adanya', async () => {
  // `invalid_grant` terjadi bila code dipakai dua kali atau kedaluwarsa —
  // desktop harus bisa menjelaskannya, bukan menampilkan "gagal" generik.
  globalThis.fetch = async () =>
    new Response(JSON.stringify({ error: 'invalid_grant', error_description: 'reuse' }), {
      status: 400,
    });
  const r = await exchangeGoogleCode(envSiap, { code: 'c', codeVerifier: 'v' });
  assert.equal(r.ok, false);
  assert.equal(r.status, 401);
  assert.equal(r.error, 'invalid_grant');
});

test('desktop: 502 bila endpoint token tidak terjangkau atau menjawab sampah', async () => {
  globalThis.fetch = async () => {
    throw new Error('network down');
  };
  const down = await exchangeGoogleCode(envSiap, { code: 'c', codeVerifier: 'v' });
  assert.equal(down.status, 502);
  assert.equal(down.error, 'token-endpoint-unreachable');

  globalThis.fetch = async () => new Response('bukan-json', { status: 200 });
  const sampah = await exchangeGoogleCode(envSiap, { code: 'c', codeVerifier: 'v' });
  assert.equal(sampah.status, 502);
  assert.equal(sampah.error, 'token-endpoint-bad-response');
});

// ── Audience: longgar untuk desktop, tetap ketat untuk yang lain ────────────

const { publicKey, privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const jwk = { ...publicKey.export({ format: 'jwk' }), kid: KID, alg: 'RS256', use: 'sig' };

function b64u(value) {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

function signToken(payload) {
  const h = b64u({ alg: 'RS256', kid: KID, typ: 'JWT' });
  const p = b64u(payload);
  const sig = rsaSign('RSA-SHA256', Buffer.from(`${h}.${p}`), privateKey);
  return `${h}.${p}.${Buffer.from(sig).toString('base64url')}`;
}

function klaim(aud) {
  const now = Math.floor(Date.now() / 1000);
  return {
    iss: 'https://accounts.google.com',
    aud,
    sub: '107892345678901234567',
    email: 'desktop@xydesk.my.id',
    email_verified: true,
    name: 'Desktop',
    exp: now + 600,
    iat: now,
  };
}

function mockJwks() {
  globalThis.fetch = async (url) =>
    url === JWKS_URL
      ? new Response(JSON.stringify({ keys: [jwk] }), { status: 200 })
      : new Response('tidak seharusnya dipanggil', { status: 500 });
}

test('desktop: id_token ber-audience client desktop diterima', async () => {
  mockJwks();
  const r = await verifyGoogleIdToken(envSiap, signToken(klaim(DESKTOP_CLIENT_ID)));
  assert.equal(r.ok, true, JSON.stringify(r));
  assert.equal(r.email, 'desktop@xydesk.my.id');
});

test('desktop: audience web tetap diterima (tidak saling menimpa)', async () => {
  mockJwks();
  const r = await verifyGoogleIdToken(envSiap, signToken(klaim(WEB_CLIENT_ID)));
  assert.equal(r.ok, true, JSON.stringify(r));
});

test('desktop: audience asing tetap ditolak', async () => {
  // Penjaga utama: penambahan satu sumber audience tidak boleh membuat
  // sembarang client id diterima.
  mockJwks();
  const r = await verifyGoogleIdToken(envSiap, signToken(klaim('333333333333-asing.apps.googleusercontent.com')));
  assert.equal(r.ok, false);
  assert.equal(r.status, 401);
  assert.equal(r.error, 'bad-audience');
});

test('desktop: tanpa GOOGLE_DESKTOP_CLIENT_ID, audience desktop ditolak', async () => {
  // Memastikan var-nya benar-benar dipakai, bukan kebetulan lolos karena
  // GOOGLE_CLIENT_ID berisi banyak nilai.
  mockJwks();
  const r = await verifyGoogleIdToken({ GOOGLE_CLIENT_ID: WEB_CLIENT_ID }, signToken(klaim(DESKTOP_CLIENT_ID)));
  assert.equal(r.ok, false);
  assert.equal(r.error, 'bad-audience');
});

test('desktop: daftar koma di kedua var tetap dihormati', async () => {
  mockJwks();
  const android = '444444444444-android.apps.googleusercontent.com';
  const env = {
    GOOGLE_CLIENT_ID: `${WEB_CLIENT_ID}, ${android}`,
    GOOGLE_DESKTOP_CLIENT_ID: DESKTOP_CLIENT_ID,
  };
  for (const aud of [WEB_CLIENT_ID, android, DESKTOP_CLIENT_ID]) {
    const r = await verifyGoogleIdToken(env, signToken(klaim(aud)));
    assert.equal(r.ok, true, `audience seharusnya diterima: ${aud}`);
  }
});

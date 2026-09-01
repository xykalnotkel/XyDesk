// Kebijakan CORS Worker signaling.
//
// Pernah menjadi temuan audit: nilai bawaan `CORS_ORIGINS` adalah `*` —
// jadi kalau variabelnya lupa terisi (deploy dari mesin lain, environment
// pratinjau, salah eja nama), Worker tiba-tiba mengizinkan semua origin.
// Sekarang bawaan itu KOSONG: konfigurasi yang hilang berbunyi "tidak ada
// yang boleh masuk", bukan "semua orang boleh masuk".

import test from 'node:test';
import assert from 'node:assert/strict';

import { corsResponse } from '../src/worker.js';

const APP = 'https://app.xystudio.my.id';

function cors(origin, env) {
  const headers = origin ? { Origin: origin } : {};
  const request = new Request('https://signal.xystudio.my.id/auth/me', { headers });
  return corsResponse(new Response('{}', { status: 200 }), request, env);
}

test('tanpa CORS_ORIGINS: tidak ada origin yang diizinkan', () => {
  for (const env of [{}, { CORS_ORIGINS: '' }, { CORS_ORIGINS: '   ' }]) {
    const res = cors(APP, env);
    assert.equal(
      res.headers.get('Access-Control-Allow-Origin'),
      null,
      `env ${JSON.stringify(env)} tidak boleh membuka akses`
    );
  }
});

test('variabel env bernama mirip tidak dianggap konfigurasi', () => {
  const res = cors(APP, { CORS_ORIGIN: APP, cors_origins: APP });
  assert.equal(res.headers.get('Access-Control-Allow-Origin'), null);
});

test('origin yang terdaftar dipantulkan persis', () => {
  const res = cors(APP, { CORS_ORIGINS: APP });
  assert.equal(res.headers.get('Access-Control-Allow-Origin'), APP);
});

test('origin asing ditolak meski daftar berisi origin lain', () => {
  const res = cors('https://jahat.example', { CORS_ORIGINS: APP });
  assert.equal(res.headers.get('Access-Control-Allow-Origin'), null);
});

test('permintaan tanpa header Origin tidak pernah diberi akses', () => {
  const res = cors(null, { CORS_ORIGINS: APP });
  assert.equal(res.headers.get('Access-Control-Allow-Origin'), null);
});

test('beberapa origin dipisah koma, spasi diabaikan', () => {
  const env = { CORS_ORIGINS: ` ${APP} , https://news.xystudio.my.id ` };
  assert.equal(cors(APP, env).headers.get('Access-Control-Allow-Origin'), APP);
  assert.equal(
    cors('https://news.xystudio.my.id', env).headers.get('Access-Control-Allow-Origin'),
    'https://news.xystudio.my.id'
  );
});

test('bintang hanya berlaku bila ditulis secara eksplisit', () => {
  const res = cors(APP, { CORS_ORIGINS: '*' });
  assert.equal(
    res.headers.get('Access-Control-Allow-Origin'),
    '*',
    'membuka API untuk semua origin harus keputusan sadar, bukan kebetulan'
  );
});

test('header Vary: Origin selalu dikirim agar cache tidak tercampur', () => {
  for (const env of [{}, { CORS_ORIGINS: APP }]) {
    assert.match(cors(APP, env).headers.get('Vary') || '', /Origin/);
  }
});

test('header CORS lain tidak bergantung pada konfigurasi', () => {
  const res = cors(APP, {});
  assert.equal(res.headers.get('Access-Control-Allow-Methods'), 'GET, POST, OPTIONS');
  assert.equal(res.headers.get('Access-Control-Allow-Headers'), 'Authorization, Content-Type');
  assert.equal(res.headers.get('Access-Control-Max-Age'), '86400');
});

test('badan dan status respons tetap utuh setelah dibungkus CORS', async () => {
  const res = corsResponse(
    new Response('{"ok":true}', { status: 201 }),
    new Request('https://signal.xystudio.my.id/auth/me', { headers: { Origin: APP } }),
    { CORS_ORIGINS: APP }
  );
  assert.equal(res.status, 201);
  assert.equal(await res.text(), '{"ok":true}');
});

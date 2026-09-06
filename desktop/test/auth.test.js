// Test auth desktop (Electron) — dijalankan dengan `node --test test/`.
//
// `electron` di-stub lewat Module._load sehingga berkas proses utama bisa
// diuji di luar Electron. Yang diuji bukan mock yang selalu benar: server
// loopback-nya sungguhan (bind 127.0.0.1, port acak, handler HTTP nyata) dan
// callback Google-nya disimulasikan dengan fetch sungguhan ke port itu.
//
// Properti yang paling penting dijaga di sini: redirect_uri yang dipakai saat
// membuka browser HARUS identik dengan yang dikirim saat penukaran code. Kalau
// keduanya beda, Google menolak dengan invalid_grant dan login gagal dengan
// sebab yang tidak jelas bagi pengguna.

import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import os from 'node:os';
import Module from 'node:module';

const fetchAsli = globalThis.fetch;

// ── Stub electron ───────────────────────────────────────────────────────────
let enkripsiTersedia = false;
let urlBrowser = [];
let handlerIpc = {};

const loadAsli = Module._load;
Module._load = function (request, ...rest) {
  if (request === 'electron') {
    return {
      app: { getPath: () => os.tmpdir() },
      ipcMain: { handle: (nama, fn) => (handlerIpc[nama] = fn) },
      safeStorage: {
        isEncryptionAvailable: () => enkripsiTersedia,
        encryptString: (s) => Buffer.from(`enc:${s}`),
        decryptString: (b) => b.toString().slice(4),
      },
      shell: {
        openExternal: async (u) => {
          urlBrowser.push(u);
        },
      },
    };
  }
  return loadAsli.call(this, request, ...rest);
};

const {
  PESAN_GALAT,
  GOOGLE_DESKTOP_CLIENT_ID,
  expDariToken,
  loginWithGoogle,
  pkce,
  pesanUntuk,
  registerAuthIpc,
  requestEmailOtp,
  sesiPublik,
  siapkanLoopback,
  urlAuthorize,
  verifyEmailOtp,
  keluar,
} = (await import('../electron/auth.cjs')).default || (await import('../electron/auth.cjs'));

function tokenJwt(expDetik) {
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  return `${b64({ alg: 'none' })}.${b64({ sub: 'u1', exp: expDetik })}.sig`;
}

/// fetch stub: menjawab sebagai Worker untuk URL signaling, dan meneruskan ke
/// fetch sungguhan untuk loopback (callback Google yang disimulasikan test).
function pasangFetch(jawabanWorker) {
  const tercatat = [];
  globalThis.fetch = async (url, init) => {
    const u = String(url);
    if (u.startsWith('http://localhost') || u.startsWith('http://127.0.0.1')) {
      return fetchAsli(u, init);
    }
    tercatat.push({ url: u, init });
    const j = typeof jawabanWorker === 'function' ? jawabanWorker(u, init) : jawabanWorker;
    return new Response(JSON.stringify(j.body), { status: j.status });
  };
  return tercatat;
}

/// Pasang handler rejection lebih dulu, lalu kembalikan galatnya. Callback
/// loopback menolak promise di tengah permintaan HTTP, jadi tanpa ini Node
/// melihat unhandled rejection dan test gagal meskipun kodenya benar.
function tangkap(promise) {
  return promise.then(
    () => null,
    (err) => err,
  );
}

function callbackGoogle(urlAuth, code, stateGanti) {
  const q = new URL(urlAuth).searchParams;
  const redirect = q.get('redirect_uri');
  const state = stateGanti === undefined ? q.get('state') : stateGanti;
  const params = new URLSearchParams();
  if (code !== null) params.set('code', code);
  if (state !== null) params.set('state', state);
  return `${redirect}/?${params.toString()}`;
}

// ── PKCE & URL authorize ────────────────────────────────────────────────────

test('pkce: challenge adalah base64url(sha256(verifier))', () => {
  const { verifier, challenge } = pkce();
  assert.ok(verifier.length >= 43, 'verifier terlalu pendek untuk PKCE');
  const harapan = crypto.createHash('sha256').update(verifier).digest('base64url');
  assert.equal(challenge, harapan);
});

test('urlAuthorize: memuat PKCE, state, dan redirect loopback', () => {
  const url = urlAuthorize({
    challenge: 'chal',
    state: 'st',
    redirectUri: 'http://localhost:41234',
  });
  const q = new URL(url).searchParams;
  assert.equal(q.get('client_id'), GOOGLE_DESKTOP_CLIENT_ID);
  assert.equal(q.get('response_type'), 'code');
  assert.equal(q.get('code_challenge'), 'chal');
  assert.equal(q.get('code_challenge_method'), 'S256');
  assert.equal(q.get('state'), 'st');
  assert.equal(q.get('redirect_uri'), 'http://localhost:41234');
  assert.equal(q.get('prompt'), 'select_account');
  assert.ok(q.get('scope').includes('email'));
});

// ── Server loopback sungguhan ───────────────────────────────────────────────

test('loopback: hanya diikat ke 127.0.0.1 pada port bebas', async () => {
  const loop = siapkanLoopback('st', 2000);
  const port = await loop.portSiap;
  assert.ok(port > 0);
  assert.equal(loop.server.address().address, '127.0.0.1');
  const res = await fetchAsli(`http://127.0.0.1:${port}/?code=c&state=st`);
  assert.equal(res.status, 200);
  assert.match(await res.text(), /Berhasil masuk/);
  const kode = await loop.janjiKode;
  assert.equal(kode.code, 'c');
  assert.equal(kode.redirectUri, `http://localhost:${port}`);
});

test('loopback: state yang tidak cocok ditolak', async () => {
  const loop = siapkanLoopback('st-benar', 2000);
  const port = await loop.portSiap;
  const ditolak = tangkap(loop.janjiKode);
  const res = await fetchAsli(`http://127.0.0.1:${port}/?code=c&state=st-salah`);
  assert.equal(res.status, 400);
  const err = await ditolak;
  assert.equal(err.code, 'state-mismatch');
});

test('loopback: tanpa code ditolak', async () => {
  const loop = siapkanLoopback('st', 2000);
  const port = await loop.portSiap;
  const ditolak = tangkap(loop.janjiKode);
  await fetchAsli(`http://127.0.0.1:${port}/?state=st`);
  const err = await ditolak;
  assert.equal(err.code, 'missing-code');
});

test('loopback: Google membalas error (pengguna membatalkan)', async () => {
  const loop = siapkanLoopback('st', 2000);
  const port = await loop.portSiap;
  const ditolak = tangkap(loop.janjiKode);
  const res = await fetchAsli(`http://127.0.0.1:${port}/?error=access_denied&state=st`);
  assert.match(await res.text(), /dibatalkan/i);
  const err = await ditolak;
  assert.equal(err.code, 'access_denied');
});

test('loopback: path selain / tidak menyelesaikan login', async () => {
  const loop = siapkanLoopback('st', 2000);
  const port = await loop.portSiap;
  const res = await fetchAsli(`http://127.0.0.1:${port}/favicon.ico?code=c&state=st`);
  assert.equal(res.status, 404);
  // Promise masih menggantung — itulah maksudnya: permintaan bukan callback
  // tidak boleh dianggap login. Dibiarkan selesai oleh timeout.
  await assert.rejects(loop.janjiKode, (err) => err.code === 'timeout');
});

test('loopback: timeout bila pengguna tidak kembali', async () => {
  const loop = siapkanLoopback('st', 60);
  await loop.portSiap;
  await assert.rejects(loop.janjiKode, (err) => err.code === 'timeout');
});

// ── Alur login Google utuh ──────────────────────────────────────────────────

test('login google: redirect_uri browser identik dengan yang ditukar', async () => {
  urlBrowser = [];
  const tercatat = pasangFetch(() => ({
    status: 200,
    body: { token: tokenJwt(Math.floor(Date.now() / 1000) + 3600), user: { email: 'a@b.id', name: 'A' } },
  }));

  const janji = loginWithGoogle();
  // Tunggu browser "dibuka", lalu simulasikan Google memanggil balik loopback.
  await new Promise((r) => setTimeout(r, 60));
  assert.equal(urlBrowser.length, 1, 'browser harus dibuka tepat sekali');
  const tukar = await fetchAsli(callbackGoogle(urlBrowser[0], '4/0AXcode'));
  assert.equal(tukar.status, 200);

  const hasil = await janji;
  assert.equal(hasil.ok, true, JSON.stringify(hasil));
  assert.equal(hasil.sesi.masuk, true);
  assert.equal(hasil.sesi.user.email, 'a@b.id');

  const kirim = tercatat.find((c) => c.url.endsWith('/auth/google/desktop'));
  assert.ok(kirim, 'harus menukar code ke Worker');
  const body = JSON.parse(kirim.init.body);
  const redirectAuth = new URL(urlBrowser[0]).searchParams.get('redirect_uri');
  assert.equal(body.redirect_uri, redirectAuth, 'redirect_uri harus identik');
  assert.equal(body.code, '4/0AXcode');
  const { verifier } = pkce();
  assert.ok(body.code_verifier && body.code_verifier !== verifier);
  // Secret tidak boleh ikut terkirim dari desktop: penukaran memakai
  // client_id + code_verifier saja, secret-nya milik Worker.
  assert.equal(body.client_secret, undefined);
});

test('login google: renderer tidak pernah menerima token', async () => {
  const publik = sesiPublik();
  assert.equal(publik.masuk, true);
  assert.equal(publik.token, undefined, 'token tidak boleh bocor ke renderer');
  assert.deepEqual(Object.keys(publik).sort(), ['exp', 'masuk', 'metode', 'tersimpan', 'user']);
  await keluar();
  assert.equal(sesiPublik().masuk, false);
});

test('login google: kegagalan Worker dilaporkan sebagai kode + pesan', async () => {
  urlBrowser = [];
  pasangFetch(() => ({ status: 404, body: { error: 'not-found' } }));
  const janji = loginWithGoogle();
  await new Promise((r) => setTimeout(r, 60));
  await fetchAsli(callbackGoogle(urlBrowser[0], 'kode'));
  const hasil = await janji;
  assert.equal(hasil.ok, false);
  assert.equal(hasil.error, 'not-found');
  assert.match(hasil.message, /deploy Worker/i);
});

test('login google: invalid_grant dari Google diterjemahkan', async () => {
  urlBrowser = [];
  pasangFetch(() => ({ status: 401, body: { error: 'invalid_grant' } }));
  const janji = loginWithGoogle();
  await new Promise((r) => setTimeout(r, 60));
  await fetchAsli(callbackGoogle(urlBrowser[0], 'kode-basi'));
  const hasil = await janji;
  assert.equal(hasil.ok, false);
  assert.equal(hasil.error, 'invalid_grant');
  assert.match(hasil.message, /kedaluwarsa|terpakai/i);
});

// ── Email OTP ───────────────────────────────────────────────────────────────

test('email otp: verifikasi berhasil menerbitkan sesi', async () => {
  pasangFetch(() => ({
    status: 200,
    body: { token: tokenJwt(Math.floor(Date.now() / 1000) + 3600), user: { email: 'otp@x.id' } },
  }));
  const hasil = await verifyEmailOtp('otp@x.id', '123456');
  assert.equal(hasil.ok, true);
  assert.equal(hasil.sesi.masuk, true);
  assert.equal(hasil.sesi.metode, 'email');
  await keluar();
});

test('email otp: cooldown menyertakan sisa tunggu dalam pesannya', async () => {
  pasangFetch(() => ({ status: 429, body: { error: 'cooldown', resend_in: 41 } }));
  const hasil = await requestEmailOtp('otp@x.id');
  assert.equal(hasil.ok, false);
  assert.equal(hasil.error, 'cooldown');
  assert.match(hasil.message, /41 detik/);
});

test('email otp: kode salah tidak menjatuhkan proses', async () => {
  pasangFetch(() => ({ status: 401, body: { error: 'wrong-otp' } }));
  const hasil = await verifyEmailOtp('otp@x.id', '000000');
  assert.equal(hasil.ok, false);
  assert.equal(hasil.error, 'wrong-otp');
  assert.equal(hasil.message, PESAN_GALAT['wrong-otp']);
});

test('email otp: jaringan mati dilaporkan, bukan melempar', async () => {
  globalThis.fetch = async () => {
    throw new Error('ECONNREFUSED');
  };
  const hasil = await requestEmailOtp('otp@x.id');
  assert.equal(hasil.ok, false);
  assert.equal(hasil.error, 'jaringan-gagal');
  assert.match(hasil.message, /koneksi/i);
});

// ── Sesi & pesan ────────────────────────────────────────────────────────────

test('sesi: token kedaluwarsa dianggap belum masuk', async () => {
  pasangFetch(() => ({
    status: 200,
    body: { token: tokenJwt(Math.floor(Date.now() / 1000) - 10), user: { email: 'lama@x.id' } },
  }));
  const hasil = await verifyEmailOtp('lama@x.id', '123456');
  assert.equal(hasil.ok, true);
  // UI tidak boleh menampilkan "masuk" untuk token yang sudah mati: kalau ya,
  // setiap aksi berikutnya gagal tanpa sebab yang terlihat.
  assert.equal(sesiPublik().masuk, false);
  assert.equal(expDariToken(tokenJwt(123)), 123);
});

test('sesi: tanpa enkripsi OS, token tidak dipaksa ke disk', () => {
  enkripsiTersedia = false;
  // sesiPublik sudah false dari test sebelumnya; yang dijaga di sini adalah
  // flag `tersimpan` supaya UI bisa jujur bahwa sesi tidak akan bertahan.
  assert.equal(sesiPublik().tersimpan, false);
});

test('pesan: kode tak dikenal tetap menghasilkan teks, bukan undefined', () => {
  assert.equal(pesanUntuk('kode-asing', 500, null), 'kode-asing');
  assert.equal(pesanUntuk(null, 502, null), 'HTTP 502');
  assert.equal(pesanUntuk('retry', 429, { retry_in: 7 }), 'retry (tunggu 7 detik)');
});

test('ipc: handler terdaftar tanpa membocorkan token', async () => {
  registerAuthIpc(() => {});
  assert.deepEqual(
    Object.keys(handlerIpc).sort(),
    ['auth:email:request', 'auth:email:verify', 'auth:google', 'auth:logout', 'auth:session'],
  );
  const sesi = await handlerIpc['auth:session']();
  assert.equal(sesi.token, undefined);
  const hasil = await handlerIpc['auth:logout']();
  assert.equal(hasil.ok, true);
});

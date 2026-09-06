// Login untuk shell Electron: Google (authorization code + PKCE) dan email OTP.
//
// Dua aturan yang menentukan bentuk berkas ini:
//
// 1. CLIENT SECRET TIDAK ADA DI SINI. Client OAuth tipe "Desktop app" tidak
//    mengizinkan aliran implicit id_token seperti web, jadi yang tersedia hanya
//    code + PKCE. Code itu dikirim ke Worker dan ditukar DI SANA
//    (cloudflare/src/auth.js:exchangeGoogleCode), karena apa pun yang masuk
//    berkas ini ikut terdistribusi ke installer pengguna dan repo ini publik.
//    Client ID tetap di sini — ia bukan rahasia, memang ikut terkirim di URL
//    browser pengguna.
//
// 2. TOKEN SESI TIDAK PERNAH KE RENDERER. Preload sudah menyatakan semua
//    rahasia tinggal di proses utama; sesi auth diperlakukan sama. Renderer
//    hanya menerima identitas pengguna dan status masuk.
//
// Redirect loopback memakai http://localhost:<port acak>. Port acak aman untuk
// client Desktop (Google mengabaikan port pada redirect loopback), dan server
// diikat ke 127.0.0.1 saja supaya tidak terlihat dari jaringan.

const { app, ipcMain, safeStorage, shell } = require('electron');
const crypto = require('node:crypto');
const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');

const SIGNALING_HTTP = process.env.XYDESK_SIGNALING_HTTP || 'https://signal.xydesk.my.id';

// Project xystudio-504611, client OAuth tipe "Desktop app".
const GOOGLE_DESKTOP_CLIENT_ID =
  process.env.XYDESK_GOOGLE_CLIENT_ID ||
  '335906355717-r2em6iirn8uv39qo6ol9iti8ijcv0et8.apps.googleusercontent.com';
const GOOGLE_SCOPES = 'openid email profile';
const AUTHORIZE_URL = 'https://accounts.google.com/o/oauth2/v2/auth';
const LOGIN_TIMEOUT_MS = 180_000;

// Kode galat Worker → kalimat yang bisa dipahami pengguna. Worker sengaja
// membalas kode mesin; menerjemahkannya di sisi klien membuat pesan yang sama
// muncul di desktop, web, dan Android tanpa mengubah kontrak API.
const PESAN_GALAT = {
  'invalid-email': 'Alamat email belum benar.',
  'invalid-name': 'Nama belum benar.',
  'invalid-input': 'Email atau kode belum benar.',
  cooldown: 'Kode baru bisa diminta lagi sebentar lagi.',
  'rate-limited': 'Terlalu banyak permintaan. Coba lagi beberapa saat.',
  'otp-expired': 'Kode sudah kedaluwarsa. Minta kode baru.',
  'wrong-otp': 'Kode belum cocok.',
  'too-many-attempts': 'Terlalu banyak percobaan salah. Minta kode baru.',
  'bad-audience': 'Aplikasi ini belum dikenali server auth.',
  'google-desktop-not-configured': 'Login Google belum diaktifkan di server.',
  'google-not-configured': 'Login Google belum diaktifkan di server.',
  'auth-not-configured': 'Server auth belum dikonfigurasi.',
  'identity-conflict': 'Email ini sudah dipakai akun Google lain.',
  invalid_grant: 'Izin Google sudah terpakai atau kedaluwarsa. Masuk lagi.',
  access_denied: 'Login dibatalkan di browser.',
  timeout: 'Browser tidak menjawab dalam 3 menit. Coba lagi.',
  'state-mismatch': 'Jawaban browser tidak cocok dengan permintaan masuk. Coba lagi.',
  'missing-code': 'Browser tidak mengirim kode masuk. Coba lagi.',
  'not-found': 'Server belum punya jalur login desktop. Perlu deploy Worker terbaru.',
  'jwks-unavailable': 'Server gagal memverifikasi token Google. Coba lagi.',
  'token-endpoint-unreachable': 'Server gagal menghubungi Google. Coba lagi.',
  'jaringan-gagal': 'Tidak bisa menghubungi server auth. Periksa koneksi.',
  'loopback-gagal': 'Tidak bisa membuka port lokal untuk login.',
  'tanpa-token': 'Server tidak menerbitkan token sesi.',
};

function pesanUntuk(code, status, detail) {
  const dasar = PESAN_GALAT[code] || code || `HTTP ${status || 0}`;
  // Worker mengirim sisa waktu tunggu untuk rate limit; ditampilkan supaya
  // pengguna tahu kapan boleh mencoba lagi, bukan menebak.
  if (detail && typeof detail.resend_in === 'number') return `${dasar} (tunggu ${detail.resend_in} detik)`;
  if (detail && typeof detail.retry_in === 'number') return `${dasar} (tunggu ${detail.retry_in} detik)`;
  return dasar;
}

class GalatAuth extends Error {
  constructor(code, status, detail) {
    super(pesanUntuk(code, status, detail));
    this.name = 'GalatAuth';
    this.code = code || 'unknown';
    this.status = status || 0;
    this.detail = detail || null;
  }
}

function jadiHasilGagal(err) {
  const galat = err instanceof GalatAuth ? err : new GalatAuth(err && err.message, 0, null);
  return { ok: false, error: galat.code, message: galat.message, detail: galat.detail };
}

// ── HTTP ke Worker ──────────────────────────────────────────────────────────

async function apiPost(pathName, body) {
  let res;
  try {
    res = await fetch(SIGNALING_HTTP + pathName, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body || {}),
    });
  } catch {
    throw new GalatAuth('jaringan-gagal', 0, null);
  }
  const text = await res.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {
    /* body bukan JSON */
  }
  if (!res.ok) throw new GalatAuth(json && json.error, res.status, json);
  return json;
}

// ── Penyimpanan sesi ────────────────────────────────────────────────────────
//
// Dipakai safeStorage (DPAPI di Windows, Keychain di macOS) supaya token tidak
// tersimpan sebagai teks polos di folder userData. Bila OS tidak menyediakan
// enkripsi, sesi hanya hidup di memori: lebih baik pengguna masuk ulang
// daripada tokennya tergeletak di disk.

let sesiMemori = null;
let gagalSimpan = false;

function berkasSesi() {
  return path.join(app.getPath('userData'), 'sesi-masuk.bin');
}

function simpanSesi(sesi) {
  sesiMemori = sesi;
  if (!sesi) {
    try {
      fs.rmSync(berkasSesi(), { force: true });
    } catch {
      /* berkas memang tidak ada */
    }
    gagalSimpan = false;
    return true;
  }
  try {
    if (safeStorage.isEncryptionAvailable()) {
      fs.writeFileSync(berkasSesi(), safeStorage.encryptString(JSON.stringify(sesi)));
      gagalSimpan = false;
      return true;
    }
  } catch {
    /* jatuh ke gagalSimpan di bawah */
  }
  gagalSimpan = true;
  return false;
}

function expDariToken(token) {
  try {
    const payload = JSON.parse(Buffer.from(String(token).split('.')[1], 'base64url').toString());
    return typeof payload.exp === 'number' ? payload.exp : null;
  } catch {
    return null;
  }
}

function bacaSesi() {
  const expLewat = (token) => {
    const exp = expDariToken(token);
    return exp !== null && exp * 1000 <= Date.now();
  };

  if (sesiMemori) {
    // Sesi kedaluwarsa dibuang di sini, bukan menunggu server menolak: kalau
    // tidak, UI menampilkan "sudah masuk" yang langsung gagal begitu dipakai.
    if (expLewat(sesiMemori.token)) {
      simpanSesi(null);
      return null;
    }
    return sesiMemori;
  }
  try {
    if (!safeStorage.isEncryptionAvailable()) return null;
    const buf = fs.readFileSync(berkasSesi());
    const parsed = JSON.parse(safeStorage.decryptString(buf));
    if (parsed && parsed.token && !expLewat(parsed.token)) {
      sesiMemori = parsed;
      return sesiMemori;
    }
  } catch {
    /* belum pernah masuk, atau berkas rusak */
  }
  return null;
}

function sesiPublik() {
  const sesi = bacaSesi();
  if (!sesi) return { masuk: false, user: null, exp: null, tersimpan: false };
  return {
    masuk: true,
    user: sesi.user || null,
    metode: sesi.metode || null,
    exp: expDariToken(sesi.token),
    tersimpan: !gagalSimpan,
  };
}

function terimaSesi(hasil, metode) {
  if (!hasil || !hasil.token) throw new GalatAuth('tanpa-token', 0, hasil);
  simpanSesi({ token: hasil.token, user: hasil.user || null, metode });
  return sesiPublik();
}

// ── Google: PKCE + server loopback ──────────────────────────────────────────

function pkce() {
  const verifier = crypto.randomBytes(48).toString('base64url');
  const challenge = crypto.createHash('sha256').update(verifier).digest('base64url');
  return { verifier, challenge };
}

function halamanBrowser(judul, isi) {
  // Tanpa aset eksternal: halaman ini dibuka di browser sistem pengguna dan
  // harus tetap terbaca tanpa jaringan.
  return `<!doctype html><html lang="id"><head><meta charset="utf-8">
<title>${judul} — XyDesk</title>
<style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#fafaf9;color:#18181b;
font:15px/1.6 system-ui,-apple-system,"Segoe UI",sans-serif}.kotak{max-width:34rem;margin:2rem;padding:1.5rem 2rem;
border:1px solid #e7e5e4;border-radius:14px;background:#fff;text-align:center}h1{font-size:1.2rem;margin:0 0 .4rem}
p{margin:0}</style></head>
<body><div class="kotak"><h1>${judul}</h1><p>${isi}</p></div></body></html>`;
}

function urlAuthorize({ challenge, state, redirectUri }) {
  return (
    `${AUTHORIZE_URL}?` +
    new URLSearchParams({
      client_id: GOOGLE_DESKTOP_CLIENT_ID,
      redirect_uri: redirectUri,
      response_type: 'code',
      scope: GOOGLE_SCOPES,
      code_challenge: challenge,
      code_challenge_method: 'S256',
      state,
      // prompt=select_account: pengguna dengan beberapa akun Google harus
      // memilih, bukan otomatis masuk dengan akun pertama.
      prompt: 'select_account',
    }).toString()
  );
}

/// Menyiapkan server loopback di 127.0.0.1 pada port bebas dan menunggu satu
/// callback dari Google.
///
/// Mengembalikan dua promise terpisah, dan itu disengaja: `portSiap` harus
/// sudah selesai SEBELUM browser diarahkan (kalau tidak, callback bisa tiba
/// sebelum ada yang mendengarkan), sementara `janjiKode` baru selesai setelah
/// pengguna benar-benar kembali dari browser.
function siapkanLoopback(state, timeoutMs = LOGIN_TIMEOUT_MS) {
  const server = http.createServer();
  let selesai = false;
  let timer = null;
  let resolveKode;
  let rejectKode;
  const janjiKode = new Promise((resolve, reject) => {
    resolveKode = resolve;
    rejectKode = reject;
  });

  const akhiri = (err, nilai) => {
    if (selesai) return;
    selesai = true;
    if (timer) clearTimeout(timer);
    try {
      server.close();
    } catch {
      /* sudah tertutup */
    }
    if (err) rejectKode(err);
    else resolveKode({ code: nilai.code, redirectUri: `http://localhost:${nilai.port}` });
  };

  server.on('request', (req, res) => {
    const balas = (judul, isi, kodeHttp = 200) => {
      res.writeHead(kodeHttp, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(halamanBrowser(judul, isi));
    };
    let url;
    try {
      url = new URL(req.url, 'http://localhost');
    } catch {
      balas('Permintaan aneh', 'Tutup halaman ini dan coba masuk lagi dari aplikasi XyDesk.', 400);
      return;
    }
    if (url.pathname !== '/') {
      balas('Bukan di sini', 'Tutup halaman ini dan coba masuk lagi dari aplikasi XyDesk.', 404);
      return;
    }
    const galat = url.searchParams.get('error');
    const code = url.searchParams.get('code');
    const gotState = url.searchParams.get('state');
    const port = server.address().port;

    if (galat) {
      const batal = galat === 'access_denied';
      balas(
        batal ? 'Login dibatalkan' : 'Login gagal',
        batal
          ? 'Tidak ada akun yang dipilih. Halaman ini boleh ditutup.'
          : `Google menolak permintaan masuk (${galat}). Halaman ini boleh ditutup.`,
      );
      akhiri(new GalatAuth(galat, 0, null), null);
      return;
    }
    if (!code) {
      balas('Kode tidak diterima', 'Browser tidak mengirim kode masuk. Coba lagi dari aplikasi.', 400);
      akhiri(new GalatAuth('missing-code', 0, null), null);
      return;
    }
    // state memastikan jawaban browser benar-benar milik permintaan masuk yang
    // kita buat, bukan tab lain atau callback yang disuntikkan ke port ini.
    if (gotState !== state) {
      balas('Tidak cocok', 'Jawaban browser tidak sesuai permintaan masuk. Coba lagi dari aplikasi.', 400);
      akhiri(new GalatAuth('state-mismatch', 0, null), null);
      return;
    }
    balas('Berhasil masuk', 'Silakan kembali ke aplikasi XyDesk. Halaman ini boleh ditutup.');
    akhiri(null, { code, port });
  });

  server.on('error', (err) =>
    akhiri(new GalatAuth('loopback-gagal', 0, { message: err.message }), null),
  );

  // 127.0.0.1, bukan 0.0.0.0: port ini tidak boleh terlihat dari jaringan.
  server.listen(0, '127.0.0.1');
  const portSiap = new Promise((resolve, reject) => {
    server.once('listening', () => {
      timer = setTimeout(() => akhiri(new GalatAuth('timeout', 0, null), null), timeoutMs);
      resolve(server.address().port);
    });
    server.once('error', reject);
  });

  return { janjiKode, portSiap, server };
}

let sedangMasuk = null;

async function jalankanLoginGoogle(catat) {
  const { verifier, challenge } = pkce();
  const state = crypto.randomBytes(16).toString('base64url');
  const loop = siapkanLoopback(state);
  const port = await loop.portSiap;
  const redirectUri = `http://localhost:${port}`;

  // Browser dibuka SETELAH server loopback siap; kalau dibalik, callback bisa
  // datang sebelum ada yang mendengarkan dan login gagal tanpa sebab jelas.
  await shell.openExternal(urlAuthorize({ challenge, state, redirectUri }));
  catat(`[auth] browser dibuka untuk login Google (loopback :${port})`);

  const kode = await loop.janjiKode;
  catat('[auth] code diterima dari loopback, ditukar ke Worker');
  const hasil = await apiPost('/auth/google/desktop', {
    code: kode.code,
    code_verifier: verifier,
    redirect_uri: kode.redirectUri,
  });
  catat('[auth] sesi Google diterbitkan Worker');
  return terimaSesi(hasil, 'google');
}

/// Masuk dengan Google. Mengembalikan { ok, sesi } atau { ok:false, error,
/// message } — tidak pernah melempar ke renderer.
function loginWithGoogle(log) {
  if (sedangMasuk) return sedangMasuk;
  const catat = typeof log === 'function' ? log : () => {};
  sedangMasuk = jalankanLoginGoogle(catat)
    .then((sesi) => ({ ok: true, sesi }))
    .catch((err) => {
      const gagal = jadiHasilGagal(err);
      catat(`[auth] login Google gagal: ${gagal.error}`);
      return gagal;
    })
    .finally(() => {
      sedangMasuk = null;
    });
  return sedangMasuk;
}

// ── Email OTP ───────────────────────────────────────────────────────────────
// Memakai endpoint Worker yang sudah hidup di produksi; tidak ada jalur baru.

async function requestEmailOtp(email, name) {
  try {
    const detail = await apiPost('/auth/request-otp', { email, name });
    return { ok: true, detail };
  } catch (err) {
    return jadiHasilGagal(err);
  }
}

async function verifyEmailOtp(email, otp, name) {
  try {
    const hasil = await apiPost('/auth/verify-otp', { email, otp, name });
    return { ok: true, sesi: terimaSesi(hasil, 'email') };
  } catch (err) {
    return jadiHasilGagal(err);
  }
}

async function keluar() {
  simpanSesi(null);
  if (sedangMasuk) {
    // Login yang masih menggantung dibiarkan selesai sendiri; sesinya akan
    // ditimpa oleh logout berikutnya bila pengguna memang keluar lagi.
    sedangMasuk = null;
  }
  return { ok: true, sesi: sesiPublik() };
}

// ── IPC ─────────────────────────────────────────────────────────────────────
// Yang dikembalikan ke renderer selalu { masuk, user } — tanpa token.

function registerAuthIpc(log) {
  ipcMain.handle('auth:session', () => sesiPublik());
  ipcMain.handle('auth:google', () => loginWithGoogle(log));
  ipcMain.handle('auth:email:request', (_e, email, name) => requestEmailOtp(email, name));
  ipcMain.handle('auth:email:verify', (_e, email, otp, name) => verifyEmailOtp(email, otp, name));
  ipcMain.handle('auth:logout', () => keluar());
}

module.exports = {
  PESAN_GALAT,
  GOOGLE_DESKTOP_CLIENT_ID,
  GalatAuth,
  bacaSesi,
  expDariToken,
  keluar,
  loginWithGoogle,
  pkce,
  pesanUntuk,
  registerAuthIpc,
  requestEmailOtp,
  sesiPublik,
  siapkanLoopback,
  urlAuthorize,
  verifyEmailOtp,
};

// Penjaga konsistensi CSP ↔ origin yang benar-benar dipanggil aplikasi web.
//
// KENAPA UJI INI ADA. Rilis 6.5.4 memindahkan seluruh layanan dari
// `xystudio.my.id` ke `xydesk.my.id` (49 berkas, 127 kemunculan). Satu berkas
// terlewat: `web_deploy/static/_headers`, yang memegang Content-Security-Policy
// produksi. Bundle live sudah memanggil domain baru, tapi `connect-src` masih
// mengizinkan domain lama yang DNS-nya sudah mati. Browser memblokir kedua
// panggilan itu — client tamu tidak bisa pairing dan tab Berita tidak bisa
// dimuat. Build hijau, deploy hijau, `curl` halaman 200; yang rusak hanya
// terlihat di dalam browser.
//
// Jadi uji ini tidak memeriksa "apakah CSP ada", melainkan "apakah CSP
// mengizinkan origin yang dipanggil kode". Kalau seseorang menambah layanan
// baru atau memindahkan domain lagi, uji ini yang berbunyi — bukan pengguna.
//
// Dijalankan dari direktori `web/` (sama seperti `npm run build` di CI).

import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import assert from 'node:assert/strict';

const WEB = dirname(dirname(fileURLToPath(import.meta.url)));
const ROOT = dirname(WEB);
const HEADERS = join(ROOT, 'web_deploy', 'static', '_headers');
const DOMAIN_LAMA = 'xystudio.my.id';

function baca(path) {
  return readFileSync(path, 'utf8');
}

/// Ambil daftar sumber dari satu direktif CSP.
function sumberCsp(csp, directive) {
  const bagian = csp
    .split(';')
    .map((s) => s.trim())
    .find((s) => s.startsWith(`${directive} `));
  assert.ok(bagian, `direktif ${directive} tidak ditemukan di CSP`);
  return bagian.slice(directive.length + 1).split(/\s+/).filter(Boolean);
}

function cspProduksi() {
  const isi = baca(HEADERS);
  const baris = isi
    .split('\n')
    .map((l) => l.trim())
    .find((l) => l.toLowerCase().startsWith('content-security-policy:'));
  assert.ok(baris, `Content-Security-Policy tidak ada di ${HEADERS}`);
  return baris.slice('content-security-policy:'.length).trim();
}

/// Semua berkas teks di bawah [dir], tanpa node_modules/dist/.wrangler.
function berkas(dir) {
  const skip = new Set(['node_modules', 'dist', '.wrangler', '.git', '.next', 'test']);
  const out = [];
  for (const nama of readdirSync(dir)) {
    if (skip.has(nama)) continue;
    const p = join(dir, nama);
    const st = statSync(p);
    if (st.isDirectory()) out.push(...berkas(p));
    else if (/\.(ts|tsx|js|json|html|css|txt|xml|toml|md)$/.test(nama)) out.push(p);
  }
  return out;
}

test('_headers produksi ada dan bisa dibaca', () => {
  assert.ok(baca(HEADERS).length > 0);
});

test('connect-src mengizinkan API signaling yang dipakai kode', () => {
  const api = baca(join(WEB, 'src', 'api.ts'));
  const m = /PROD_BASE\s*=[\s\S]*?\?\?\s*'(https:\/\/[^']+)'/.exec(api);
  assert.ok(m, 'PROD_BASE bawaan tidak ditemukan di web/src/api.ts');
  const base = m[1];
  const host = new URL(base).host;

  const connect = sumberCsp(cspProduksi(), 'connect-src');
  assert.ok(
    connect.includes(base),
    `CSP connect-src tidak mengizinkan ${base}. Bundle memanggilnya untuk ` +
      `auth, signal-token, dan TURN — tanpa ini semua permintaan diblokir browser.`,
  );
  assert.ok(
    connect.includes(`wss://${host}`),
    `CSP connect-src tidak mengizinkan wss://${host}. WebSocket signaling ` +
      `diblokir = layar sesi menggantung di "Menghubungi host…" selamanya.`,
  );
});

test('connect-src mengizinkan API berita yang dipakai kode', () => {
  const news = baca(join(WEB, 'src', 'news.ts'));
  const m = /NEWS_BASE\s*=\s*'(https:\/\/[^']+)'/.exec(news);
  assert.ok(m, 'NEWS_BASE tidak ditemukan di web/src/news.ts');

  const connect = sumberCsp(cspProduksi(), 'connect-src');
  assert.ok(
    connect.includes(m[1]),
    `CSP connect-src tidak mengizinkan ${m[1]} — tab Berita akan menampilkan ` +
      `"Beritanya belum bisa dimuat" padahal servernya hidup.`,
  );
});

test('tidak ada sisa domain lama di konfigurasi live web', () => {
  const offenders = [];
  for (const dir of [WEB, join(ROOT, 'web_deploy')]) {
    for (const p of berkas(dir)) {
      // Lockfile dan artefak build bukan konfigurasi live.
      if (p.endsWith('package-lock.json')) continue;
      const isi = baca(p);
      if (isi.includes(DOMAIN_LAMA)) {
        offenders.push(p.replace(`${ROOT}/`, ''));
      }
    }
  }
  assert.deepEqual(
    offenders,
    [],
    `Domain lama ${DOMAIN_LAMA} masih ada di konfigurasi live. DNS-nya sudah ` +
      `mati, jadi setiap rujukan ke sana adalah fitur yang rusak diam-diam:\n  ` +
      offenders.join('\n  '),
  );
});

test('form-action tetap mengizinkan login Google', () => {
  // Login web memakai redirect `window.location.href` ke accounts.google.com
  // (web/src/google.ts). `form-action` tidak mengatur navigasi itu, tapi
  // sengaja dijaga supaya tidak dihapus tanpa berpikir.
  const form = sumberCsp(cspProduksi(), 'form-action');
  assert.ok(form.includes("'self'"));
  assert.ok(form.includes('https://accounts.google.com'));
});

test("script-src 'self' tidak menghalangi alur OAuth", () => {
  // OAuth web sengaja memakai redirect, BUKAN popup Google Identity Services —
  // jadi tidak ada skrip pihak ketiga yang perlu dimuat. Uji ini mengunci
  // keputusan itu: kalau suatu hari GIS dipakai lagi, script-src harus ikut
  // dibuka dan keputusan itu harus disadari, bukan terjadi diam-diam.
  const script = sumberCsp(cspProduksi(), 'script-src');
  assert.deepEqual(script, ["'self'"]);

  const google = baca(join(WEB, 'src', 'google.ts'));
  assert.ok(
    google.includes('window.location.href'),
    'google.ts tidak lagi memakai redirect — periksa apakah script-src perlu dibuka',
  );
  assert.ok(
    !/apis\.google\.com|createElement\(['"]script['"]\)/.test(google),
    'google.ts memuat skrip pihak ketiga padahal script-src hanya \'self\'',
  );
});

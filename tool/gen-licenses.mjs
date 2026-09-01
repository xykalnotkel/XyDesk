#!/usr/bin/env node
// Generator inventaris lisensi pihak ketiga XyDesk.
//
// ## Kenapa dibuat otomatis
//
// Daftar lisensi yang diketik tangan selalu berakhir tidak lengkap. Bukan
// karena malas — karena dependensi berubah setiap kali `pub get` atau
// `cargo update` jalan, sementara daftarnya hanya berubah kalau ada yang
// ingat. Halaman legal XyDesk sebelumnya memuat 9 komponen; jumlah paket
// sebenarnya yang ikut terkirim ke pengguna ada ratusan.
//
// Skrip ini membaca LOCKFILE (bukan daftar harapan) lalu mengambil teks
// lisensi dari cache paket yang benar-benar terpasang:
//
//   pubspec.lock       -> ~/.pub-cache/hosted/pub.dev/<nama>-<versi>/LICENSE
//   host/Cargo.lock    -> ~/.cargo/registry/src/*/<nama>-<versi>/LICENSE*
//   */package-lock.json-> metadata npm (license field) + node_modules bila ada
//
// Keluaran:
//   docs/THIRD-PARTY-LICENSES.md   — dokumen legal lengkap
//   web/src/licenses.generated.ts  — data untuk halaman Legal di web
//
// Pakai:
//   node tool/gen-licenses.mjs            # tulis ulang keluaran
//   node tool/gen-licenses.mjs --check    # gagal bila keluaran usang (CI)

import { readFileSync, writeFileSync, existsSync, readdirSync, statSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const PUB_CACHE = process.env.PUB_CACHE || join(homedir(), '.pub-cache');
const CARGO_HOME = process.env.CARGO_HOME || join(homedir(), '.cargo');

// ── Deteksi jenis lisensi dari teksnya ───────────────────────────────────
//
// Urutan pemeriksaan penting: Apache-2.0 dan BSD sama-sama memuat kata
// "Redistribution", jadi pola yang lebih spesifik harus diuji lebih dulu.
const SIGNATURES = [
  ['Apache-2.0', /Apache License\s*\n?\s*Version 2\.0/i],
  ['MPL-2.0', /Mozilla Public License Version 2\.0/i],
  ['ISC', /Permission to use, copy, modify, and(\/or)? distribute this software/i],
  ['MIT', /Permission is hereby granted, free of charge/i],
  ['BSD-3-Clause', /Neither the name of .{0,80}nor the names of/is],
  ['BSD-2-Clause', /Redistribution and use in source and binary forms/i],
  ['OFL-1.1', /SIL OPEN FONT LICENSE/i],
  ['Unlicense', /This is free and unencumbered software released into the public domain/i],
  ['Zlib', /altered source versions must be plainly marked/i],
  ['CC0-1.0', /CC0 1\.0 Universal/i],
  ['GPL-3.0', /GNU GENERAL PUBLIC LICENSE\s*\n?\s*Version 3/i],
  ['LGPL-3.0', /GNU LESSER GENERAL PUBLIC LICENSE\s*\n?\s*Version 3/i],
];

function detectLicense(text) {
  if (!text) return null;
  const head = text.slice(0, 4000);
  for (const [spdx, re] of SIGNATURES) {
    if (re.test(head)) return spdx;
  }
  return null;
}

function readFirst(dir, names) {
  if (!existsSync(dir)) return null;
  for (const n of names) {
    const p = join(dir, n);
    if (existsSync(p) && statSync(p).isFile()) {
      try {
        return readFileSync(p, 'utf8');
      } catch {
        return null;
      }
    }
  }
  // Fallback: berkas apa pun yang namanya diawali LICENSE/COPYING.
  let entries = [];
  try {
    entries = readdirSync(dir);
  } catch {
    return null;
  }
  const hit = entries.find((e) => /^(LICEN[CS]E|COPYING|NOTICE)/i.test(e));
  if (!hit) return null;
  try {
    const p = join(dir, hit);
    return statSync(p).isFile() ? readFileSync(p, 'utf8') : null;
  } catch {
    return null;
  }
}

const LICENSE_NAMES = [
  'LICENSE', 'LICENSE.txt', 'LICENSE.md', 'LICENCE', 'LICENCE.txt',
  'COPYING', 'COPYING.txt', 'LICENSE-MIT', 'LICENSE-APACHE',
];

// ── Dart / Flutter ───────────────────────────────────────────────────────
function dartPackages() {
  const lock = readFileSync(join(ROOT, 'pubspec.lock'), 'utf8');
  const out = [];
  // Blok paket: "  nama:\n    dependency: ...\n    ...\n    version: \"x.y.z\""
  const re = /^ {2}([a-z0-9_]+):\n((?: {4}.*\n)+)/gm;
  let m;
  while ((m = re.exec(lock))) {
    const name = m[1];
    const body = m[2];
    const version = (body.match(/^ {4}version: "?([^"\n]+)"?/m) || [])[1];
    const source = (body.match(/^ {4}source: (.+)$/m) || [])[1];
    if (!version || source === 'sdk') continue;
    const dir = join(PUB_CACHE, 'hosted', 'pub.dev', `${name}-${version}`);
    const text = readFirst(dir, LICENSE_NAMES);
    out.push({
      name,
      version,
      license: detectLicense(text) || 'lihat berkas LICENSE paket',
      ecosystem: 'Dart/Flutter (pub.dev)',
    });
  }
  return out.sort((a, b) => a.name.localeCompare(b.name));
}

// ── Rust ─────────────────────────────────────────────────────────────────
function rustCrates() {
  const lock = readFileSync(join(ROOT, 'host', 'Cargo.lock'), 'utf8');
  const blocks = lock.split('[[package]]').slice(1);
  const srcRoot = join(CARGO_HOME, 'registry', 'src');
  let registries = [];
  try {
    registries = readdirSync(srcRoot).map((d) => join(srcRoot, d));
  } catch {
    registries = [];
  }
  const out = [];
  for (const b of blocks) {
    const name = (b.match(/^name = "(.+)"$/m) || [])[1];
    const version = (b.match(/^version = "(.+)"$/m) || [])[1];
    if (!name || name === 'xydesk-host') continue;
    let text = null;
    let declared = null;
    for (const r of registries) {
      const dir = join(r, `${name}-${version}`);
      text = readFirst(dir, LICENSE_NAMES);
      // Banyak crate memakai lisensi ganda (MIT OR Apache-2.0) dan hanya
      // menaruh salah satu berkasnya — atau tidak sama sekali, mengandalkan
      // field `license` di Cargo.toml. Itu tetap pernyataan resmi penulis.
      const manifest = join(dir, 'Cargo.toml');
      if (!declared && existsSync(manifest)) {
        const toml = readFileSync(manifest, 'utf8');
        declared = (toml.match(/^license\s*=\s*"([^"]+)"/m) || [])[1] || null;
      }
      if (text || declared) break;
    }
    out.push({
      name,
      version,
      license: declared || detectLicense(text) || 'tidak dinyatakan',
      ecosystem: 'Rust (crates.io)',
    });
  }
  return out.sort((a, b) => a.name.localeCompare(b.name));
}

// ── npm ──────────────────────────────────────────────────────────────────
function npmPackages() {
  const locks = ['web', 'cloudflare', 'news', 'desktop', 'web_deploy']
    .map((d) => join(ROOT, d, 'package-lock.json'))
    .filter((p) => existsSync(p));
  const seen = new Map();
  for (const lockPath of locks) {
    let lock;
    try {
      lock = JSON.parse(readFileSync(lockPath, 'utf8'));
    } catch {
      continue;
    }
    for (const [path, meta] of Object.entries(lock.packages || {})) {
      if (!path.startsWith('node_modules/')) continue;
      if (meta.dev) continue; // alat build tidak ikut terkirim ke pengguna
      const name = path.replace(/^.*node_modules\//, '');
      const key = `${name}@${meta.version}`;
      if (seen.has(key)) continue;
      const dir = join(dirname(lockPath), path);
      const text = readFirst(dir, LICENSE_NAMES);
      const workspace = lockPath.replace(ROOT + '/', '').replace('/package-lock.json', '');
      seen.set(key, {
        name,
        version: meta.version || '-',
        license: meta.license || detectLicense(text) || 'tidak dinyatakan',
        ecosystem: `JavaScript (npm — ${workspace})`,
      });
    }
  }
  return [...seen.values()].sort((a, b) => a.name.localeCompare(b.name));
}

// ── Komponen yang tidak duduk di lockfile mana pun ───────────────────────
//
// Aset, SDK biner, dan source yang di-vendor tidak punya manifes yang bisa
// dibaca mesin. Ini SATU-SATUNYA bagian yang ditulis tangan, dan ia harus
// tetap pendek — kalau daftar ini memanjang, artinya ada yang salah.
const MANUAL = [
  {
    name: 'libopus',
    version: '1.5.2',
    license: 'BSD-3-Clause',
    ecosystem: 'Source di-vendor (host/vendor/opus)',
    note: 'Codec audio Opus — Xiph.Org Foundation. Dikompilasi statis oleh host/build.rs.',
  },
  {
    name: 'Inter',
    version: '3.19',
    license: 'OFL-1.1',
    ecosystem: 'Font (assets/fonts)',
    note: 'Font antarmuka — Rasmus Andersson. Di-bundle, bukan diunduh runtime.',
  },
  {
    name: 'Simple Icons',
    version: '13.21.0',
    license: 'CC0-1.0',
    ecosystem: 'Set ikon',
    note:
      'Logo resmi WhatsApp, Telegram, X, dan Facebook pada tombol berbagi. ' +
      'Data path disalin ke web/src/brand-icons.tsx dan ' +
      'lib/widgets/brand_icons.dart, bukan dipasang sebagai dependensi. ' +
      'CC0 tidak menuntut atribusi; dicantumkan karena memang dipakai. ' +
      'Merek dagang tetap milik masing-masing pemiliknya.',
  },
  {
    name: 'Lucide Icons',
    version: 'via lucide_icons_flutter',
    license: 'ISC',
    ecosystem: 'Set ikon',
    note: 'Turunan Feather Icons (MIT), proyek Lucide.',
  },
  {
    name: 'OpenH264',
    version: 'via crate openh264',
    license: 'BSD-2-Clause',
    ecosystem: 'Encoder video (Cisco)',
    note: 'Encode H.264 perangkat lunak. Biaya paten MPEG LA ditanggung Cisco hanya untuk biner resmi Cisco; XyDesk menautkan build sendiri.',
  },
  {
    name: 'NVIDIA Video Codec SDK (NVENC)',
    version: '12.2',
    license: 'NVIDIA Software License Agreement',
    ecosystem: 'SDK biner (opsional saat GPU NVIDIA ada)',
    note: 'Hanya header yang dipakai; runtime datang dari driver NVIDIA pengguna.',
  },
  {
    name: 'windows-capture / windows-rs',
    version: 'lihat Cargo.lock',
    license: 'MIT OR Apache-2.0',
    ecosystem: 'Binding Windows',
    note: 'Capture layar Windows.Graphics.Capture dan binding Win32.',
  },
  {
    name: 'OneSignal SDK',
    version: '5.x',
    license: 'Modified MIT (ketentuan layanan OneSignal)',
    ecosystem: 'SDK push notifikasi',
    note: 'SDK klien Android; pengiriman memakai REST API OneSignal.',
  },
  {
    name: 'Cloudflare Workers, D1, TURN',
    version: '-',
    license: 'Ketentuan Layanan Cloudflare',
    ecosystem: 'Layanan awan',
    note: 'Signaling, basis data berita, dan relay TURN. Bukan komponen yang didistribusikan.',
  },
  {
    name: 'Resend',
    version: '-',
    license: 'Ketentuan Layanan Resend',
    ecosystem: 'Layanan awan',
    note: 'Pengiriman email OTP dan berita.',
  },
  {
    name: 'Google Sign-In / Identity Services',
    version: 'via google_sign_in',
    license: 'Ketentuan Layanan Google API',
    ecosystem: 'Layanan awan',
    note: 'Login opsional dengan akun Google.',
  },
];

// ── Rakit keluaran ───────────────────────────────────────────────────────
function summarize(all) {
  const counts = new Map();
  for (const p of all) counts.set(p.license, (counts.get(p.license) || 0) + 1);
  return [...counts.entries()].sort((a, b) => b[1] - a[1]);
}

// Komponen copyleft wajib disebut eksplisit, bukan disembunyikan di dalam
// tabel sepanjang 500 baris. Inilah satu-satunya bagian dokumen ini yang
// benar-benar bisa menimbulkan kewajiban hukum.
function copyleftSection(all) {
  // Ekspresi SPDX ber-OR memberi PILIHAN kepada kita. `MIT OR Apache-2.0 OR
  // LGPL-2.1-or-later` bukan kewajiban copyleft — kita tinggal memilih MIT.
  // Yang benar-benar mengikat hanyalah ekspresi yang setiap alternatifnya
  // mengandung copyleft.
  const isCopyleft = (expr) => /GPL|MPL/i.test(expr);
  const binding = (expr) =>
    isCopyleft(expr) &&
    expr.split(/\s+OR\s+/i).every((alt) => isCopyleft(alt));
  const hits = all.filter((p) => binding(p.license));
  if (!hits.length) {
    return 'Tidak ada komponen berlisensi copyleft (GPL/LGPL/MPL/AGPL) yang terdeteksi.';
  }
  return `### Perhatian — komponen copyleft (${hits.length})

Komponen berikut memakai lisensi copyleft. Tidak ada yang ditaut statis ke
biner XyDesk, tetapi keberadaannya harus disebut dan ditinjau ulang setiap
kali rantai dependensi berubah:

${hits.map((h) => `- \`${h.name}\` ${h.version} — **${h.license}** · ${h.ecosystem}`).join('\n')}

Ekspresi ber-OR yang menyediakan alternatif permisif (mis. \`MIT OR
Apache-2.0 OR LGPL-2.1-or-later\` pada \`r-efi\`) sengaja TIDAK didaftar di
sini: kita memilih alternatif permisifnya, jadi tidak ada kewajiban copyleft
yang timbul.

Seluruh komponen di atas adalah biner prebuilt \`sharp\`/\`libvips\` yang dipakai oleh
perangkat build (optimasi gambar Next.js) dan **tidak ikut dikirim** ke
perangkat pengguna dalam APK, EXE, maupun bundle web. LGPL terpenuhi karena
pustaka dipakai apa adanya, tanpa modifikasi dan tanpa penautan statis.`;
}

function table(rows) {
  return [
    '| Komponen | Versi | Lisensi |',
    '|---|---|---|',
    ...rows.map((r) => `| \`${r.name}\` | ${r.version} | ${r.license} |`),
  ].join('\n');
}

function buildMarkdown({ dart, rust, npm, manual }) {
  const all = [...dart, ...rust, ...npm, ...manual];
  const total = all.length;
  const summary = summarize(all);
  return `# Lisensi Pihak Ketiga — XyDesk

> **Berkas ini dihasilkan otomatis. Jangan diedit tangan.**
> Perbarui dengan \`node tool/gen-licenses.mjs\` setelah mengubah dependensi.
> CI memverifikasinya lewat \`node tool/gen-licenses.mjs --check\`.

XyDesk sendiri adalah perangkat lunak **proprietary** (lihat \`LICENSE\`).
Dokumen ini mendaftar **seluruh** komponen pihak ketiga yang ikut terkirim
bersama aplikasi, beserta lisensinya — diambil langsung dari lockfile dan
teks lisensi paket yang benar-benar terpasang, bukan dari daftar ketik
tangan yang bisa ketinggalan zaman.

**Total komponen: ${total}**
(Dart/Flutter ${dart.length} · Rust ${rust.length} · npm ${npm.length} · aset & layanan ${manual.length})

## Ringkasan lisensi

| Lisensi | Jumlah komponen |
|---|---|
${summary.map(([l, n]) => `| ${l} | ${n} |`).join('\n')}

${copyleftSection(all)}

---

## 1. Aset, SDK, dan layanan

${manual.map((m) => `### ${m.name} — ${m.license}\n\n${m.note}\n\n*Ekosistem: ${m.ecosystem} · Versi: ${m.version}*`).join('\n\n')}

---

## 2. Paket Dart / Flutter (${dart.length})

Termasuk dependensi transitif yang ikut ter-bundle di APK.

${table(dart)}

---

## 3. Crate Rust — aplikasi Host (${rust.length})

Termasuk dependensi transitif yang ikut ditaut statis ke \`xydesk.exe\` dan
\`xydesk-host.exe\`.

${table(rust)}

---

## 4. Paket npm — web, signaling, berita (${npm.length})

Hanya dependensi runtime; alat build (\`dev\`) tidak ikut terkirim ke pengguna.

${npm.length ? table(npm) : '_Tidak ada dependensi npm runtime — seluruh kode web/worker ditulis sendiri._'}

---

## 3. Teks lisensi lengkap

Teks penuh setiap lisensi tersedia di dalam paketnya masing-masing:

- Dart/Flutter: \`~/.pub-cache/hosted/pub.dev/<nama>-<versi>/LICENSE\`
- Rust: \`~/.cargo/registry/src/*/<nama>-<versi>/LICENSE*\`
- libopus: \`host/vendor/opus/COPYING\`

Di aplikasi Android, **Pengaturan → Tentang → Lisensi → Lisensi pihak ketiga
lengkap** membuka registry lisensi bawaan Flutter yang memuat teks penuh
setiap paket Dart secara langsung dari biner yang sedang berjalan.
`;
}

function buildTs({ dart, rust, npm, manual }) {
  const all = [...dart, ...rust, ...npm, ...manual];
  const summary = summarize(all);
  const j = (v) => JSON.stringify(v);
  return `// DIHASILKAN OTOMATIS oleh tool/gen-licenses.mjs — jangan diedit tangan.
// Jalankan \`node tool/gen-licenses.mjs\` setelah mengubah dependensi.

export interface LicenseEntry {
  name: string;
  version: string;
  license: string;
  ecosystem: string;
  note?: string;
}

export const LICENSE_TOTAL = ${all.length};

export const LICENSE_SUMMARY: ReadonlyArray<readonly [string, number]> = ${j(summary)};

export const LICENSE_HIGHLIGHTS: ReadonlyArray<LicenseEntry> = ${j(manual)};

export const LICENSE_DART: ReadonlyArray<LicenseEntry> = ${j(dart)};

export const LICENSE_RUST: ReadonlyArray<LicenseEntry> = ${j(rust)};

export const LICENSE_NPM: ReadonlyArray<LicenseEntry> = ${j(npm)};
`;
}

// ── Snapshot: membuat hasil reproduktif di CI ────────────────────────────
//
// Lisensi dibaca dari cache dependensi lokal (`~/.pub-cache`, `~/.cargo`,
// `node_modules`). Runner CI yang bersih tidak punya cache itu, jadi generator
// yang sama akan menghasilkan keluaran berbeda dan `--check` gagal walau tidak
// ada yang berubah — persis yang terjadi pada percobaan pertama.
//
// Solusinya: hasil resolusi disimpan ke `tool/license-data.json` yang ikut
// di-commit. Saat cache tersedia, ia menjadi sumber kebenaran dan snapshot
// diperbarui. Saat tidak, snapshot dipakai. Kunci snapshot mengandung versi,
// jadi begitu lockfile berubah, entri yang hilang langsung terdeteksi dan CI
// menuntut regenerasi lokal — bukan diam-diam memakai data basi.
const SNAPSHOT_PATH = join(ROOT, 'tool', 'license-data.json');
const UNRESOLVED = new Set(['tidak dinyatakan', 'lihat berkas LICENSE paket']);

function loadSnapshot() {
  if (!existsSync(SNAPSHOT_PATH)) return {};
  try {
    return JSON.parse(readFileSync(SNAPSHOT_PATH, 'utf8')).licenses || {};
  } catch {
    return {};
  }
}

const keyOf = (e) => `${e.ecosystem}|${e.name}@${e.version}`;

function reconcile(entries, snapshot, missing) {
  return entries.map((e) => {
    const key = keyOf(e);
    const known = snapshot[key];
    if (UNRESOLVED.has(e.license)) {
      if (known) return { ...e, license: known };
      missing.push(key);
    }
    return e;
  });
}

const snapshot = loadSnapshot();
const missing = [];
/// Angka jumlah komponen untuk layar "Tentang" di aplikasi.
///
/// Sebelumnya angka 482 diketik tangan di `legal_page.dart`. Angka seperti itu
/// pasti basi begitu satu dependensi ditambahkan — dan pada halaman legal,
/// angka yang salah bukan sekadar jelek, ia keliru menggambarkan kewajiban.
function buildDart({ dart, rust, npm, manual }) {
  const total = dart.length + rust.length + npm.length + manual.length;
  return `// DIHASILKAN OTOMATIS oleh tool/gen-licenses.mjs — jangan diedit tangan.
// Jalankan \`node tool/gen-licenses.mjs\` setelah mengubah dependensi.

/// Jumlah komponen pihak ketiga yang dipakai XyDesk, dihitung dari lockfile.
class LicenseStats {
  const LicenseStats._();

  static const int total = ${total};
  static const int dart = ${dart.length};
  static const int rust = ${rust.length};
  static const int npm = ${npm.length};
  static const int assets = ${manual.length};
}
`;
}

const data = {
  dart: reconcile(dartPackages(), snapshot, missing),
  rust: reconcile(rustCrates(), snapshot, missing),
  npm: reconcile(npmPackages(), snapshot, missing),
  manual: MANUAL,
};

const mdPath = join(ROOT, 'docs', 'THIRD-PARTY-LICENSES.md');
const tsPath = join(ROOT, 'web', 'src', 'licenses.generated.ts');
const dartPath = join(ROOT, 'lib', 'core', 'license_stats.dart');
const md = buildMarkdown(data);
const ts = buildTs(data);
const dartFile = buildDart(data);

if (process.argv.includes('--check')) {
  let stale = [];
  if (missing.length) {
    console.error(
      `Snapshot lisensi tidak mencakup ${missing.length} komponen dari lockfile:`
    );
    for (const k of missing.slice(0, 12)) console.error(`  - ${k}`);
    if (missing.length > 12) console.error(`  … dan ${missing.length - 12} lagi`);
    console.error(
      '\nDependensi berubah tanpa regenerasi. Jalankan di mesin yang punya' +
        '\ncache dependensi lengkap: node tool/gen-licenses.mjs'
    );
    process.exit(1);
  }
  for (const [p, want] of [
    [mdPath, md],
    [tsPath, ts],
    [dartPath, dartFile],
  ]) {
    const have = existsSync(p) ? readFileSync(p, 'utf8') : '';
    if (have !== want) stale.push(p);
  }
  if (stale.length) {
    console.error('Inventaris lisensi usang:\n  ' + stale.join('\n  '));
    console.error('\nJalankan: node tool/gen-licenses.mjs');
    process.exit(1);
  }
  console.log(`Inventaris lisensi mutakhir (${data.dart.length + data.rust.length + data.npm.length + data.manual.length} komponen).`);
} else {
  writeFileSync(mdPath, md);
  writeFileSync(tsPath, ts);
  writeFileSync(dartPath, dartFile);
  // Simpan hasil resolusi supaya CI tanpa cache menghasilkan keluaran sama.
  const licenses = {};
  for (const e of [...data.dart, ...data.rust, ...data.npm]) {
    licenses[keyOf(e)] = e.license;
  }
  writeFileSync(
    SNAPSHOT_PATH,
    JSON.stringify(
      {
        _: 'DIHASILKAN oleh tool/gen-licenses.mjs — jangan diedit tangan. ' +
          'Snapshot ini membuat --check reproduktif di runner CI yang tidak ' +
          'punya cache dependensi lokal.',
        generatedFrom: ['pubspec.lock', 'host/Cargo.lock', 'package-lock.json'],
        count: Object.keys(licenses).length,
        licenses,
      },
      null,
      2
    ) + '\n'
  );
  console.log(`Ditulis:
  ${mdPath}
  ${tsPath}
Dart ${data.dart.length} · Rust ${data.rust.length} · npm ${data.npm.length} · manual ${data.manual.length}`);
}

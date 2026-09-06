// Migrasi idempoten untuk D1 live.
//
// `schema.sql` memakai CREATE TABLE IF NOT EXISTS, jadi database yang SUDAH
// ada tidak pernah menerima kolom baru darinya. Setiap kolom baru wajib
// ditambahkan di berkas ini, dan berkas ini wajib dijalankan CI sebelum
// Worker versi baru menyala.
//
// Pelajaran mahal: kolom `official` sempat dipakai Worker sebelum ada di
// database produksi. Akibatnya SELECT gagal dan SELURUH endpoint detail
// berita membalas 500 — bukan fitur badge yang mati, tapi seluruh halaman
// berita. Urutannya harus: migrasi dulu, deploy Worker kemudian.
//
// Pemakaian: npx wrangler d1 execute xydesk-news --remote --file schema.sql
// lalu:     node migrate.mjs  (setelah wrangler login / token env)
//
// ⚠️ SETIAP SQL DI BERKAS INI WAJIB SATU BARIS.
// `--command` dilewatkan lewat shell dalam tanda kutip ganda, dan bash tidak
// menerjemahkan `\n` di dalamnya — newline tiba di SQLite sebagai backslash
// harfiah dan parser menolak: "unrecognized token: \" ... SQLITE_ERROR 7500".
// Terbukti live 6 Sep 2026 pada langkah pertama yang memakai SQL multi-baris
// (CREATE TABLE post_aliases); deploy gagal sebelum menyentuh apa pun.
// Pernyataan lama selamat hanya karena semuanya satu baris. Untuk SQL yang
// memang perlu panjang dan multi-baris, pakai `schema.sql` lewat `--file`
// (jalur db:init), bukan `--command` di sini.

import { execSync } from 'node:child_process';

function run(sql) {
  const out = execSync(
    `npx wrangler d1 execute xydesk-news --remote --json --command ${JSON.stringify(sql)}`,
    { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] },
  );
  return JSON.parse(out);
}

// 1) parent_id di comments
const cols = run(`PRAGMA table_info(comments)`);
const hasParent = cols[0].results.some((c) => c.name === 'parent_id');
if (!hasParent) {
  run(`ALTER TABLE comments ADD COLUMN parent_id INTEGER`);
  console.log('migrasi: parent_id ditambahkan');
} else {
  console.log('migrasi: parent_id sudah ada');
}

// 2) kolom official di comments — sumber badge "Resmi".
if (!cols[0].results.some((c) => c.name === 'official')) {
  run(`ALTER TABLE comments ADD COLUMN official INTEGER NOT NULL DEFAULT 0`);
  console.log('migrasi: official ditambahkan');
} else {
  console.log('migrasi: official sudah ada');
}

// 3) tabel subscribers
const tables = run(`SELECT name FROM sqlite_master WHERE type='table' AND name='subscribers'`);
if (tables[0].results.length === 0) {
  run(`CREATE TABLE subscribers (id INTEGER PRIMARY KEY AUTOINCREMENT, email TEXT UNIQUE NOT NULL, source TEXT NOT NULL DEFAULT 'berita', created_at TEXT NOT NULL DEFAULT (datetime('now')))`);
  console.log('migrasi: tabel subscribers dibuat');
} else {
  console.log('migrasi: subscribers sudah ada');
}

// 4) asal langganan di subscribers.
//
// Tanpa kolom ini, "Ingatkan saya" di halaman unduh tidak bisa dibedakan
// dari pelanggan berita — padahal yang satu menunggu artikel dan yang lain
// menunggu tombol unduh dibuka. Baris lama otomatis bernilai 'berita'
// (default), jadi tidak ada data yang perlu diisi ulang.
//
// Ingat urutannya: Worker yang menyisipkan kolom ini HARUS menyala sesudah
// migrasi ini berhasil — persis pelajaran `official` di atas.
const subCols = run(`PRAGMA table_info(subscribers)`);
if (!subCols[0].results.some((c) => c.name === 'source')) {
  run(`ALTER TABLE subscribers ADD COLUMN source TEXT NOT NULL DEFAULT 'berita'`);
  run(`CREATE INDEX IF NOT EXISTS idx_subscribers_source ON subscribers(source)`);
  console.log('migrasi: source ditambahkan');
} else {
  console.log('migrasi: source sudah ada');
}

// 5) alias slug changelog rilis.
//
// Footer web dan layar "Tentang" menautkan versi berjalan ke slug kanonik
// `changelog-vX-Y-Z` (CHANGELOG_SLUG di web/src/version.ts). Enam rilis
// tautannya 404 — terverifikasi live 6 Sep 2026 — karena artikelnya terbit
// dengan slug lain, atau tidak terbit sama sekali.
//
// Sengaja TIDAK memakai `UPDATE posts SET slug = …`: slug lama sudah terlanjur
// tersebar lewat notifikasi push dan email, jadi menggantinya memutus tautan
// yang sudah dikirim ke pelanggan. Alias membuat dua-duanya hidup.
//
// `rilis-65x` tidak mungkin lahir dari POST /api/admin/publish — adminPublish
// hanya menerima slug berpola changelog-v\d+-\d+-\d+ dan mengacak sisanya jadi
// p-<hash>. Artinya keduanya disisipkan langsung ke D1, dan notifySubscribers
// tidak pernah berjalan untuk dua rilis itu. Dicatat di HANDOFF, bukan
// diperbaiki diam-diam di sini.
run(`CREATE TABLE IF NOT EXISTS post_aliases (alias TEXT PRIMARY KEY, slug TEXT NOT NULL REFERENCES posts(slug), created_at TEXT NOT NULL DEFAULT (datetime('now')))`);

const ALIASES = [
  ['changelog-v6-5-4', 'rilis-654'],
  ['changelog-v6-5-3', 'rilis-653'],
  ['changelog-v6-4-0', 'p-8f5aa26aa3bc'],
  ['changelog-v6-1-0', 'p-66a4edde0222'],
  ['changelog-v6-0-0', 'p-d5b4512f7d17'],
  // changelog-v6-5-2 SENGAJA tidak dipetakan: rilis 6.5.2 tidak punya artikel
  // sama sekali, jadi tidak ada yang bisa dituju. Memetakannya ke artikel 6.5.3
  // akan menyajikan isi yang salah untuk versi yang benar. Dibiarkan 404 dan
  // dicatat jujur di HANDOFF area News.
];

for (const [alias, target] of ALIASES) {
  const ada = run(`SELECT 1 AS ok FROM posts WHERE slug = '${target}'`);
  if (!ada[0].results.length) {
    console.log(`migrasi: alias ${alias} DILEWATI — artikel '${target}' tidak ada`);
    continue;
  }
  run(`INSERT OR IGNORE INTO post_aliases (alias, slug) VALUES ('${alias}', '${target}')`);
  console.log(`migrasi: alias ${alias} -> ${target}`);
}

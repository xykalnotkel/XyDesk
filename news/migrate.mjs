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
  run(`CREATE TABLE subscribers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT UNIQUE NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  )`);
  console.log('migrasi: tabel subscribers dibuat');
} else {
  console.log('migrasi: subscribers sudah ada');
}

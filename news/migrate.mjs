// Migrasi idempoten untuk D1 live: menambah kolom parent_id di comments
// dan tabel subscribers bila belum ada (DB lama tidak otomatis dapat
// kolom baru dari schema.sql karena CREATE TABLE IF NOT EXISTS).
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

// 2) tabel subscribers
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

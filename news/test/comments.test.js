// Badge resmi & perlindungan nama tim.
//
// Yang diuji di sini bukan tampilan badge, melainkan satu-satunya hal yang
// membuat badge berarti: bahwa ia TIDAK BISA diminta oleh klien. Kalau test
// ini merah, siapa pun bisa berkomentar sebagai tim XyDesk.

import test from 'node:test';
import assert from 'node:assert/strict';

import { addComment, isProtectedName } from '../src/worker.js';

// ── Stub D1 seperlunya ───────────────────────────────────────────────────
function fakeDb() {
  const inserted = [];
  return {
    inserted,
    prepare(sql) {
      const stmt = {
        sql,
        args: [],
        bind(...a) {
          stmt.args = a;
          return stmt;
        },
        async first() {
          if (/FROM posts/i.test(sql)) return { id: 1, slug: 'artikel' };
          if (/COUNT\(\*\)/i.test(sql)) return { c: 0 };
          return null;
        },
        async run() {
          if (/INSERT INTO comments/i.test(sql)) {
            inserted.push({ sql, args: stmt.args });
          }
          return { meta: { last_row_id: inserted.length } };
        },
        async all() {
          return { results: [] };
        },
      };
      return stmt;
    },
  };
}

const ADMIN = 'rahasia-admin';
const envWith = (db) => ({ DB: db, ADMIN_TOKEN: ADMIN });
const req = (token) =>
  new Request('https://news.example/api/news/artikel/comments', {
    method: 'POST',
    headers: token ? { 'x-admin-token': token } : {},
  });

test('nama tim dikenali dalam berbagai penyamaran', () => {
  for (const n of [
    'Haekal Saputra',
    'haekal saputra',
    'H a e k a l S a p u t r a',
    'haekal.saputra',
    'XyDesk',
    'Tim XyDesk',
    'admin',
    'XySpace Tech',
    'Haekal Saputra (XySpace)',
  ]) {
    assert.equal(isProtectedName(n), true, `harus terlindungi: ${n}`);
  }
  for (const n of ['Budi', 'Rina Wijaya', 'gamer_2026', 'Hakim']) {
    assert.equal(isProtectedName(n), false, `tidak boleh diblokir: ${n}`);
  }
});

test('komentar publik tidak bisa memakai nama tim', async () => {
  const db = fakeDb();
  const res = await addComment(
    envWith(db),
    'artikel',
    { author: 'Haekal Saputra', content: 'halo semua', fp: 'fp-1' },
    req(null),
  );
  assert.equal(res.status, 403);
  assert.equal(db.inserted.length, 0, 'tidak boleh tersimpan');
});

test('komentar publik tidak pernah dapat badge — walau memintanya', async () => {
  const db = fakeDb();
  // Penyerang mengirim official: true langsung di body.
  const res = await addComment(
    envWith(db),
    'artikel',
    { author: 'Budi', content: 'mantap', fp: 'fp-2', official: true },
    req(null),
  );
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.comment.official, false);
  const row = db.inserted[0];
  assert.equal(row.args[row.args.length - 1], 0, 'kolom official harus 0');
});

test('token admin salah tetap tidak memberi badge', async () => {
  const db = fakeDb();
  const res = await addComment(
    envWith(db),
    'artikel',
    { author: 'Budi', content: 'coba tembus', fp: 'fp-3' },
    req('token-palsu'),
  );
  const body = await res.json();
  assert.equal(body.comment.official, false);
});

test('token admin yang benar memberi badge dan boleh memakai nama tim', async () => {
  const db = fakeDb();
  const res = await addComment(
    envWith(db),
    'artikel',
    { author: 'Haekal Saputra', content: 'terima kasih!', fp: 'fp-tim' },
    req(ADMIN),
  );
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.comment.official, true);
  const row = db.inserted[0];
  assert.equal(row.args[row.args.length - 1], 1, 'kolom official harus 1');
});

test('tanpa ADMIN_TOKEN terkonfigurasi, badge mustahil didapat', async () => {
  const db = fakeDb();
  // env tanpa ADMIN_TOKEN: header apa pun tidak boleh cocok dengan undefined.
  const res = await addComment(
    { DB: db },
    'artikel',
    { author: 'Budi', content: 'halo', fp: 'fp-4' },
    req(''),
  );
  const body = await res.json();
  assert.equal(body.comment.official, false);
});

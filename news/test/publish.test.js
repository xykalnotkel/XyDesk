// Terbitkan artikel (admin) — logika slug & validasi.
//
// Ini mengunci satu aturan yang pernah terlewat di rilis 6.4.0: artikel
// changelog HARUS mengirim field `slug` (pola `changelog-vX-Y-Z`), kalau
// tidak slug-nya jadi hash acak `p-…` dan tautan versi di footer web
// menunjuk ke artikel yang tidak ada. Test di bawah memastikan aturan itu
// tetap persis seperti yang diharapkan klien.

import test from 'node:test';
import assert from 'node:assert/strict';

import worker from '../src/worker.js';

const ADMIN = 'token-admin-uji';

function fakeDb(duplicate = false) {
  const calls = [];
  return {
    calls,
    prepare(sql) {
      const stmt = {
        sql,
        args: [],
        bind(...a) {
          stmt.args = a;
          return stmt;
        },
        async first() {
          if (/SELECT id FROM posts WHERE slug/i.test(sql)) return duplicate ? { id: 7 } : null;
          return null;
        },
        async run() {
          calls.push({ sql, args: stmt.args });
          return { meta: { last_row_id: calls.length } };
        },
      };
      return stmt;
    },
  };
}

const envWith = (db) => ({ DB: db, ADMIN_TOKEN: ADMIN });

function publishRequest(body, token = ADMIN) {
  const headers = { 'content-type': 'application/json' };
  if (token) headers['x-admin-token'] = token;
  return new Request('https://news.example/api/admin/publish', {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
  });
}

function insertArg(db, index) {
  const insert = db.calls.find((c) => /INSERT INTO posts/i.test(c.sql));
  assert.ok(insert, 'harus ada INSERT');
  return insert.args[index];
}

test('tanpa token admin, publish ditolak 401 dan tidak menulis apa pun', async () => {
  const db = fakeDb();
  const res = await worker.fetch(publishRequest({ title: 'Judul rilis', content: 'Isi cukup panjang.' }, null), envWith(db));
  assert.equal(res.status, 401);
  assert.equal(db.calls.length, 0);
});

test('judul atau isi terlalu pendek ditolak 400', async () => {
  const db = fakeDb();
  const res = await worker.fetch(publishRequest({ title: 'ab', content: 'Isi cukup panjang.' }, ADMIN), envWith(db));
  assert.equal(res.status, 400);
  assert.equal(db.calls.length, 0);
});

test('slug dikosongkan = jatuh ke hash acak p-… (bukan changelog)', async () => {
  const db = fakeDb();
  const res = await worker.fetch(publishRequest({ title: 'Judul rilis', content: 'Isi cukup panjang.' }, ADMIN), envWith(db));
  assert.equal(res.status, 200);
  const slug = insertArg(db, 0);
  assert.match(slug, /^p-[a-f0-9]{12}$/);
});

test('slug sembarang tidak dihormati — selalu hash acak', async () => {
  const db = fakeDb();
  const res = await worker.fetch(
    publishRequest({ title: 'Judul rilis', content: 'Isi cukup panjang.', slug: 'artikel-bebas' }, ADMIN),
    envWith(db),
  );
  assert.equal(res.status, 200);
  const slug = insertArg(db, 0);
  assert.notEqual(slug, 'artikel-bebas');
  assert.match(slug, /^p-[a-f0-9]{12}$/);
});

test('slug pola changelog-vX-Y-Z boleh dipilih sendiri', async () => {
  const db = fakeDb();
  const res = await worker.fetch(
    publishRequest({ title: 'Judul rilis', content: 'Isi cukup panjang.', slug: 'changelog-v6-4-0' }, ADMIN),
    envWith(db),
  );
  assert.equal(res.status, 200);
  assert.equal(insertArg(db, 0), 'changelog-v6-4-0');
});

test('slug changelog ditulis huruf besar tetap dinormalkan jadi huruf kecil', async () => {
  const db = fakeDb();
  const res = await worker.fetch(
    publishRequest({ title: 'Judul rilis', content: 'Isi cukup panjang.', slug: 'CHANGELOG-V6-4-0' }, ADMIN),
    envWith(db),
  );
  assert.equal(res.status, 200);
  assert.equal(insertArg(db, 0), 'changelog-v6-4-0');
});

test('slug yang sudah dipakai ditolak 409', async () => {
  const db = fakeDb(true);
  const res = await worker.fetch(
    publishRequest({ title: 'Judul rilis', content: 'Isi cukup panjang.', slug: 'changelog-v6-4-0' }, ADMIN),
    envWith(db),
  );
  assert.equal(res.status, 409);
  assert.equal(db.calls.length, 0);
});

test('penulis bawaan tetap Haekal Saputra saat body tidak menyertakan author', async () => {
  const db = fakeDb();
  const res = await worker.fetch(publishRequest({ title: 'Judul rilis', content: 'Isi cukup panjang.' }, ADMIN), envWith(db));
  assert.equal(res.status, 200);
  // bind(slug, title, excerpt, content, cover, category, author) — author di indeks 6.
  assert.equal(insertArg(db, 6), 'Haekal Saputra');
});

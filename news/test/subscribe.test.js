// Asal langganan: "berita" vs "unduhan".
//
// Yang diuji bukan formulirnya, melainkan satu hal yang membuat formulir
// "Ingatkan saya" berguna: bahwa niat orang tersimpan dengan label yang
// benar, dan bahwa label itu tidak bisa diisi sembarangan dari klien.
// Kalau test ini merah, kelak tidak ada cara memilah siapa yang menunggu
// artikel dan siapa yang menunggu tombol unduh.

import test from 'node:test';
import assert from 'node:assert/strict';

import { subscribe } from '../src/worker.js';

// ── Stub D1 seperlunya ───────────────────────────────────────────────────
function fakeDb(existing = null) {
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
          if (/SELECT id, source FROM subscribers/i.test(sql)) return existing;
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

const envWith = (db) => ({ DB: db });

test('pendaftar baru tersimpan dengan asal "berita" secara bawaan', async () => {
  const db = fakeDb();
  const res = await subscribe(envWith(db), { email: 'budi@contoh.id' });
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.subscribed, true);
  assert.equal(body.source, 'berita');

  const insert = db.calls.find((c) => /INSERT INTO subscribers/i.test(c.sql));
  assert.ok(insert, 'harus ada INSERT');
  assert.deepEqual(insert.args, ['budi@contoh.id', 'berita']);
});

test('formulir "Ingatkan saya" tersimpan sebagai asal "unduhan"', async () => {
  const db = fakeDb();
  const res = await subscribe(envWith(db), {
    email: 'sari@contoh.id',
    source: 'unduhan',
  });
  const body = await res.json();
  assert.equal(body.source, 'unduhan');

  const insert = db.calls.find((c) => /INSERT INTO subscribers/i.test(c.sql));
  assert.deepEqual(insert.args, ['sari@contoh.id', 'unduhan']);
});

test('asal yang tidak dikenal dibuang ke "berita", bukan disimpan mentah', async () => {
  const db = fakeDb();
  await subscribe(envWith(db), {
    email: 'aneh@contoh.id',
    source: '<script>alert(1)</script>',
  });
  const insert = db.calls.find((c) => /INSERT INTO subscribers/i.test(c.sql));
  assert.deepEqual(insert.args, ['aneh@contoh.id', 'berita']);
});

test('pelanggan berita yang minta diingatkan unduhan ikut ditandai', async () => {
  const db = fakeDb({ id: 7, source: 'berita' });
  await subscribe(envWith(db), { email: 'lama@contoh.id', source: 'unduhan' });
  const update = db.calls.find((c) => /UPDATE subscribers/i.test(c.sql));
  assert.ok(update, 'pelanggan lama harus diperbarui, bukan dilewati');
  assert.deepEqual(update.args, ['unduhan', 'lama@contoh.id']);
});

test('pelanggan unduhan tidak diturunkan kembali jadi berita', async () => {
  const db = fakeDb({ id: 8, source: 'unduhan' });
  await subscribe(envWith(db), { email: 'sudah@contoh.id' });
  const update = db.calls.find((c) => /UPDATE subscribers/i.test(c.sql));
  assert.equal(update, undefined, 'jangan hapus niat yang sudah tercatat');
});

test('email tidak valid ditolak, tidak ada satu pun tulisan ke basis', async () => {
  const db = fakeDb();
  const res = await subscribe(envWith(db), { email: 'bukan-email' });
  assert.equal(res.status, 400);
  assert.equal(db.calls.length, 0);
});

// Alias slug artikel changelog — pemetaan dan gagal-tertutup.
//
// Konteksnya nyata dan terverifikasi live 6 Sep 2026: enam tautan versi
// (`changelog-v6-5-4`, `-v6-5-3`, `-v6-5-2`, `-v6-4-0`, `-v6-1-0`, `-v6-0-0`)
// menjawab 404, padahal footer web dan layar "Tentang" menautkannya lewat
// `CHANGELOG_SLUG` di web/src/version.ts. Artikelnya ada, tapi terbit dengan
// slug lain — jadi yang rusak bukan isinya, melainkan alamat kanoniknya.
//
// Test ini mengunci tiga keputusan:
//  1. Alias berlaku di SEMUA rute yang memakai slug, bukan cuma detail artikel.
//     Kalau tidak, tautan versi hidup tetapi tombol suka dan kolom komentar di
//     artikel yang sama tetap 404 — perbaikan setengah jadi yang justru lebih
//     membingungkan daripada tidak diperbaiki.
//  2. Jalur normal tidak membayar kueri tambahan: slug yang sudah ada tidak
//     pernah menyentuh tabel alias.
//  3. Kueri alias yang gagal dibaca sebagai "tidak ada alias", BUKAN galat.
//     migrate.mjs mencatat kejadian nyata di mana kolom `official` dipakai
//     Worker sebelum ada di database produksi dan akibatnya SELURUH endpoint
//     detail berita membalas 500. Tabel `post_aliases` baru ada setelah
//     migrasi jalan, jadi urutan deploy yang salah tidak boleh mengubah satu
//     tautan 404 menjadi seluruh situs 500.

import test from 'node:test';
import assert from 'node:assert/strict';

import worker from '../src/worker.js';

const ARTIKEL = {
  id: 15,
  slug: 'rilis-654',
  title: 'XyDesk 6.5.4 — Domain Baru',
  excerpt: 'Seluruh layanan pindah.',
  content: 'Isi artikel.',
  cover: 'https://app.xydesk.my.id/news/covers/changelog-654.jpg',
  category: 'rilis',
  author: 'Haekal Saputra',
  published: 1,
  created_at: '2026-09-06 11:00:00',
};

/// Basis data tiruan.
///
/// `aliasAda` mengisi tabel alias; `aliasMelempar` menirukan tabel yang belum
/// ada di produksi ("no such table: post_aliases") — persis skenario yang
/// membuat seluruh halaman berita 500 pada kejadian `official`.
function fakeDb({ aliasAda = null, aliasMelempar = false } = {}) {
  const kueri = [];
  return {
    kueri,
    prepare(sql) {
      const stmt = {
        sql,
        args: [],
        bind(...a) {
          stmt.args = a;
          return stmt;
        },
        async first() {
          kueri.push(sql.replace(/\s+/g, ' ').trim());
          if (/^SELECT 1 AS ok FROM posts WHERE slug = \?$/i.test(sql)) {
            return stmt.args[0] === ARTIKEL.slug ? { ok: 1 } : null;
          }
          if (/FROM post_aliases WHERE alias = \?/i.test(sql)) {
            if (aliasMelempar) throw new Error('no such table: post_aliases');
            return stmt.args[0] === aliasAda?.alias ? { slug: aliasAda.slug } : null;
          }
          if (/WHERE p\.slug = \? AND p\.published = 1/i.test(sql)) {
            return stmt.args[0] === ARTIKEL.slug ? ARTIKEL : null;
          }
          if (/SELECT COUNT\(\*\) AS c FROM likes/i.test(sql)) return { c: 1 };
          return null;
        },
        async all() {
          kueri.push(sql.replace(/\s+/g, ' ').trim());
          return { results: [] };
        },
        async run() {
          kueri.push(sql.replace(/\s+/g, ' ').trim());
          return { meta: { changes: 1 } };
        },
      };
      return stmt;
    },
  };
}

const envWith = (db) => ({ DB: db });
const get = (path) => new Request(`https://news.example${path}`, { method: 'GET' });
const post = (path, body = {}) =>
  new Request(`https://news.example${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });

test('slug yang sudah ada tidak menyentuh tabel alias', async () => {
  const db = fakeDb();
  const res = await worker.fetch(get('/api/news/rilis-654'), envWith(db), {});
  assert.equal(res.status, 200);
  assert.ok(
    !db.kueri.some((k) => /post_aliases/i.test(k)),
    `jalur normal seharusnya tidak membayar kueri alias, tapi ada: ${db.kueri.join(' | ')}`,
  );
});

test('slug kanonik dipetakan ke artikel yang terbit dengan slug lain', async () => {
  const db = fakeDb({ aliasAda: { alias: 'changelog-v6-5-4', slug: 'rilis-654' } });
  const res = await worker.fetch(get('/api/news/changelog-v6-5-4'), envWith(db), {});
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.post.slug, 'rilis-654', 'isi harus artikel aslinya, bukan salinan');
});

test('slug yang tidak ada dan tidak punya alias tetap 404', async () => {
  const db = fakeDb();
  const res = await worker.fetch(get('/api/news/changelog-v6-5-2'), envWith(db), {});
  assert.equal(res.status, 404);
});

test('tabel alias yang belum ada di produksi TIDAK membuat 500', async () => {
  // Skenario `official` terulang: Worker menyala sebelum migrasi jalan.
  const db = fakeDb({ aliasMelempar: true });
  const res = await worker.fetch(get('/api/news/changelog-v6-5-4'), envWith(db), {});
  assert.equal(res.status, 404, 'harus gagal-tertutup jadi 404, bukan 500');
  const body = await res.json();
  assert.equal(body.error, 'post-not-found');
});

test('slug asli tetap hidup setelah alias dipasang', async () => {
  // Tautan lama sudah terlanjur tersebar lewat push dan email; alias tidak
  // boleh memutusnya.
  const db = fakeDb({ aliasAda: { alias: 'changelog-v6-5-4', slug: 'rilis-654' } });
  const res = await worker.fetch(get('/api/news/rilis-654'), envWith(db), {});
  assert.equal(res.status, 200);
});

test('alias berlaku di rute komentar, bukan hanya detail artikel', async () => {
  const db = fakeDb({ aliasAda: { alias: 'changelog-v6-5-4', slug: 'rilis-654' } });
  const res = await worker.fetch(get('/api/news/changelog-v6-5-4/comments'), envWith(db), {});
  assert.equal(res.status, 200, 'komentar di artikel beralias tidak boleh 404');
  const body = await res.json();
  assert.deepEqual(body.comments, []);
});

test('alias berlaku di halaman berbagi OpenGraph', async () => {
  const db = fakeDb({ aliasAda: { alias: 'changelog-v6-5-4', slug: 'rilis-654' } });
  const res = await worker.fetch(get('/n/changelog-v6-5-4'), envWith(db), {});
  assert.equal(res.status, 200, 'crawler yang membuka tautan versi tidak boleh dapat 404');
  const html = await res.text();
  assert.ok(html.includes('rilis-654'), 'halaman berbagi harus menunjuk slug asli artikel');
});

test('alias berlaku di rute like', async () => {
  const db = fakeDb({ aliasAda: { alias: 'changelog-v6-5-4', slug: 'rilis-654' } });
  const res = await worker.fetch(
    post('/api/news/changelog-v6-5-4/like', { fp: 'sidikjari-uji' }),
    envWith(db),
    {},
  );
  assert.equal(res.status, 200, 'suka pada artikel beralias tidak boleh 404');
  const body = await res.json();
  assert.equal(body.liked, true);
  assert.equal(body.likeCount, 1);
  // Like-nya harus tercatat pada artikel ASLI, bukan pada slug alias yang
  // tidak punya baris di posts — kalau tidak, dua slug punya hitungan berbeda.
  assert.ok(
    db.kueri.some((k) => /^INSERT INTO likes/i.test(k)),
    'like seharusnya tersimpan',
  );
});

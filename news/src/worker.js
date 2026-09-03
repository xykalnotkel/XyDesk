// XyDesk News — Worker publik (D1): feed berita + halaman berbagi OpenGraph.
//
// TERPISAH dari Worker signaling. Endpoint publik berita tidak butuh akun.
// Batas kecil dipasang biar murah dan tidak disalahgunakan:
//   - like: idempoten per sidik jari (fingerprint) buatan client
//   - komentar: maks 5 per 10 menit per fingerprint, panjang terbatas
//   - balasan komentar: satu tingkat (parent_id), divalidasi
//   - seluruh input disanitasi (tag HTML dibuang)
//
// Fitur rilis 6.0:
//   - POST /api/admin/publish  → terbitkan artikel baru dengan slug HASH acak
//     (token ADMIN_TOKEN), lalu kirim notifikasi push (OneSignal) dan email
//     (Resend) ke pelanggan — semuanya asinkron lewat waitUntil.
//   - POST /api/subscribe      → daftar email langganan berita (unix email).

import { verifyFounderAdmin } from './auth.js';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, X-Admin-Token, X-Admin-Google-Token',
  'Access-Control-Max-Age': '86400',
};

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS });
    }

    try {
      if (path === '/api/news' && request.method === 'GET') {
        return listPosts(env, url);
      }
      if (path === '/api/subscribe' && request.method === 'POST') {
        return subscribe(env, await readJson(request));
      }
      if (path === '/api/admin/publish' && request.method === 'POST') {
        return adminPublish(env, request, await readJson(request));
      }
      let m = path.match(/^\/api\/news\/([a-z0-9-]+)$/);
      if (m && request.method === 'GET') return postDetail(env, m[1], url);
      m = path.match(/^\/api\/news\/([a-z0-9-]+)\/like$/);
      if (m && request.method === 'POST') {
        return likePost(env, m[1], await readJson(request));
      }
      m = path.match(/^\/api\/news\/([a-z0-9-]+)\/comments$/);
      if (m && request.method === 'GET') return listComments(env, m[1]);
      if (m && request.method === 'POST') {
        return addComment(env, m[1], await readJson(request), request);
      }
      m = path.match(/^\/n\/([a-z0-9-]+)$/);
      if (m) return sharePage(env, m[1], url);
      return json({ error: 'not-found' }, 404);
    } catch (e) {
      return json({ error: String((e && e.message) || e) }, 500);
    }
  },
};

// ── Util ────────────────────────────────────────────────────────────────
function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8', ...CORS },
  });
}

async function readJson(request) {
  try {
    return await request.json();
  } catch {
    return {};
  }
}

function clean(v) {
  return String(v ?? '').replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();
}

/// Pembersih untuk isi artikel — sama dengan `clean()`, tetapi MEMPERTAHANKAN
/// pemisah paragraf.
///
/// `clean()` meratakan `\s+` menjadi satu spasi. Itu benar untuk judul, tetapi
/// pada isi artikel ia menggabungkan seluruh tulisan menjadi satu blok tanpa
/// jeda — persis yang terjadi pada artikel yang diterbitkan lewat endpoint
/// admin, sementara artikel dari `seed.sql` tetap punya paragraf. Selisih itu
/// yang membuat berita hasil publish terlihat berantakan di aplikasi.
function cleanBody(v) {
  return String(v ?? '')
    .replace(/<[^>]*>/g, '')
    .replace(/\r\n?/g, '\n')
    .split('\n')
    .map((line) => line.replace(/[^\S\n]+/g, ' ').trim())
    .join('\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function rowToPost(r) {
  return {
    slug: r.slug,
    title: r.title,
    excerpt: r.excerpt,
    content: r.content,
    cover: r.cover,
    category: r.category,
    author: r.author,
    createdAt: r.created_at,
    likeCount: r.like_count,
    commentCount: r.comment_count,
  };
}

function rowToComment(c) {
  return {
    id: c.id,
    author: c.author,
    content: c.content,
    parentId: c.parent_id ?? null,
    createdAt: c.created_at,
    // Selalu boolean, tidak pernah undefined — klien memakainya untuk
    // memutuskan menampilkan badge, dan `undefined` di sana berarti badge
    // hilang diam-diam pada baris lama.
    official: c.official === 1,
  };
}

// ── Nama yang dilindungi ─────────────────────────────────────────────────
//
// Badge resmi tidak ada gunanya bila nama di sebelahnya bisa ditiru. Orang
// tidak membaca "badge + nama" sebagai dua hal terpisah; mereka membaca
// keseluruhannya sebagai "ini dia". Jadi nama tim ikut dikunci: komentar
// publik yang memakainya ditolak, bukan sekadar tidak diberi badge.
//
// Perbandingan mengabaikan huruf besar/kecil, spasi berlebih, dan karakter
// non-alfanumerik supaya "haekal.saputra" dan "H A E K A L SAPUTRA" ikut
// tertangkap.
const PROTECTED_NAMES = [
  'haekalsaputra',
  'haekal',
  'xydesk',
  'timxydesk',
  'xyspace',
  'xyspacetech',
  'admin',
  'administrator',
  'official',
  'resmi',
  'moderator',
];

function nameKey(v) {
  return String(v || '').toLowerCase().replace(/[^a-z0-9]/g, '');
}

export function isProtectedName(author) {
  const key = nameKey(author);
  if (!key) return false;
  return PROTECTED_NAMES.some((p) => key === p || key.startsWith(p));
}

const POST_SELECT = `
  SELECT p.*,
    (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id) AS like_count,
    (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id) AS comment_count
  FROM posts p
`;

// ── API ─────────────────────────────────────────────────────────────────
async function listPosts(env, url) {
  const category = clean(url.searchParams.get('category') || '');
  const limit = Math.min(Number(url.searchParams.get('limit') || 30) || 30, 50);
  let rows;
  if (category) {
    rows = await env.DB.prepare(
      `${POST_SELECT} WHERE p.published = 1 AND p.category = ? ORDER BY p.created_at DESC, p.id DESC LIMIT ?`
    ).bind(category, limit).all();
  } else {
    rows = await env.DB.prepare(
      `${POST_SELECT} WHERE p.published = 1 ORDER BY p.created_at DESC, p.id DESC LIMIT ?`
    ).bind(limit).all();
  }
  return json({ posts: rows.results.map(rowToPost) });
}

async function getPost(env, slug) {
  const r = await env.DB.prepare(`${POST_SELECT} WHERE p.slug = ? AND p.published = 1`)
    .bind(slug).first();
  return r || null;
}

async function postDetail(env, slug, url) {
  const p = await getPost(env, slug);
  if (!p) return json({ error: 'post-not-found' }, 404);
  const comments = await env.DB.prepare(
    `SELECT id, author, content, parent_id, official, created_at FROM comments WHERE post_id = ? ORDER BY created_at ASC, id ASC LIMIT 200`
  ).bind(p.id).all();
  // `liked` ikut dikembalikan supaya tombol suka tampil terisi saat artikel
  // dibuka lagi. Tanpa ini, klien tidak punya cara tahu perangkat ini sudah
  // menyukai artikel dan hatinya selalu terlihat kosong.
  const fp = clean((url && url.searchParams.get('fp')) || '').slice(0, 64);
  let liked = false;
  if (fp) {
    const row = await env.DB.prepare(
      'SELECT 1 AS ok FROM likes WHERE post_id = ? AND fp = ?'
    ).bind(p.id, fp).first();
    liked = Boolean(row);
  }
  return json({
    post: rowToPost(p),
    liked,
    comments: comments.results.map(rowToComment),
  });
}

async function likePost(env, slug, body) {
  const p = await getPost(env, slug);
  if (!p) return json({ error: 'post-not-found' }, 404);
  const fp = clean(body.fp).slice(0, 64);
  if (!fp) return json({ error: 'fingerprint diperlukan' }, 400);
  // Toggle: like kedua dengan fp yang sama = batal suka.
  const existing = await env.DB.prepare(
    'SELECT 1 FROM likes WHERE post_id = ? AND fp = ?'
  ).bind(p.id, fp).first();
  if (existing) {
    await env.DB.prepare('DELETE FROM likes WHERE post_id = ? AND fp = ?').bind(p.id, fp).run();
  } else {
    await env.DB.prepare('INSERT INTO likes (post_id, fp) VALUES (?, ?)').bind(p.id, fp).run();
  }
  const counts = await env.DB.prepare(
    'SELECT COUNT(*) AS c FROM likes WHERE post_id = ?'
  ).bind(p.id).first();
  return json({ liked: !existing, likeCount: counts.c });
}

async function listComments(env, slug) {
  const p = await getPost(env, slug);
  if (!p) return json({ error: 'post-not-found' }, 404);
  const rows = await env.DB.prepare(
    `SELECT id, author, content, parent_id, official, created_at FROM comments WHERE post_id = ? ORDER BY created_at ASC, id ASC LIMIT 200`
  ).bind(p.id).all();
  return json({ comments: rows.results.map(rowToComment) });
}

export async function addComment(env, slug, body, request) {
  const p = await getPost(env, slug);
  if (!p) return json({ error: 'post-not-found' }, 404);
  const author = clean(body.author).slice(0, 40);
  const content = clean(body.content).slice(0, 1000);
  const fp = clean(body.fp).slice(0, 64);
  if (!author) return json({ error: 'nama tidak boleh kosong' }, 400);
  if (content.length < 2) return json({ error: 'komentar terlalu pendek' }, 400);
  if (!fp) return json({ error: 'fingerprint diperlukan' }, 400);

  // Badge resmi ditentukan SERVER (ADMIN_TOKEN atau Google ID token founder),
  // tidak pernah dari body. Kalau klien boleh mengirim `official: true`,
  // badge itu cuma dekorasi yang bisa dipasang siapa saja lewat curl.
  const official = await verifyFounderAdmin(env, request);

  if (!official && isProtectedName(author)) {
    return json(
      {
        error:
          'Nama itu dipakai tim XyDesk. Pilih nama lain supaya tidak ada ' +
          'yang salah mengira komentarmu berasal dari kami.',
      },
      403,
    );
  }

  // Balasan: satu tingkat, induk harus ada di artikel yang sama.
  let parentId = null;
  if (body.parentId != null && body.parentId !== '') {
    parentId = Number(body.parentId);
    if (!Number.isInteger(parentId) || parentId <= 0) {
      return json({ error: 'parentId tidak valid' }, 400);
    }
    const parent = await env.DB.prepare(
      'SELECT id FROM comments WHERE id = ? AND post_id = ?'
    ).bind(parentId, p.id).first();
    if (!parent) return json({ error: 'komentar induk tidak ditemukan' }, 404);
  }

  // Batas laju: 5 komentar per 10 menit per fp. Tim dikecualikan — membalas
  // sepuluh komentar berturut-turut saat rilis adalah pekerjaan normal,
  // bukan spam.
  if (!official) {
    const recent = await env.DB.prepare(
      `SELECT COUNT(*) AS c FROM comments WHERE post_id = ? AND fp = ? AND created_at > datetime('now', '-10 minutes')`
    ).bind(p.id, fp).first();
    if (recent.c >= 5) {
      return json({ error: 'terlalu banyak komentar. Coba lagi nanti.' }, 429);
    }
  }

  const now = new Date().toISOString();
  const flag = official ? 1 : 0;
  const r = parentId != null
    ? await env.DB.prepare(
        'INSERT INTO comments (post_id, author, content, fp, parent_id, official) VALUES (?, ?, ?, ?, ?, ?)'
      ).bind(p.id, author, content, fp, parentId, flag).run()
    : await env.DB.prepare(
        'INSERT INTO comments (post_id, author, content, fp, official) VALUES (?, ?, ?, ?, ?)'
      ).bind(p.id, author, content, fp, flag).run();
  return json({
    comment: {
      id: Number(r.meta.last_row_id),
      author,
      content,
      parentId,
      createdAt: now,
      official,
    },
  });
}

// ── Langganan email ─────────────────────────────────────────────────────
export async function subscribe(env, body) {
  const email = clean(body.email).slice(0, 120).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
    return json({ error: 'alamat email tidak valid' }, 400);
  }
  // Asal langganan menentukan siapa dikabari saat apa. Klien hanya boleh
  // memilih di antara dua nilai yang dikenal; nilai lain dibuang, bukan
  // disimpan — kolom ini dipakai untuk memilih kelompok penerima, jadi
  // nilai bebas membuatnya tidak bisa dipakai.
  const source = clean(body.source).toLowerCase() === 'unduhan' ? 'unduhan' : 'berita';

  const existing = await env.DB.prepare(
    'SELECT id, source FROM subscribers WHERE email = ?'
  ).bind(email).first();
  if (existing) {
    // Yang sudah terdaftar sebagai pelanggan berita lalu meminta diingatkan
    // soal unduhan: tandai juga, supaya ia ikut dikabari saat unduhan dibuka.
    if (source === 'unduhan' && existing.source !== 'unduhan') {
      await env.DB.prepare('UPDATE subscribers SET source = ? WHERE email = ?')
        .bind('unduhan', email)
        .run();
    }
    return json({ ok: true, subscribed: false, reason: 'sudah terdaftar' });
  }
  await env.DB.prepare('INSERT INTO subscribers (email, source) VALUES (?, ?)')
    .bind(email, source)
    .run();
  return json({ ok: true, subscribed: true, source });
}

// ── Terbitkan artikel (admin) + notifikasi push & email ─────────────────
async function adminPublish(env, request, body) {
  const admin = await verifyFounderAdmin(env, request);
  if (!admin) {
    return json({ error: 'unauthorized' }, 401);
  }
  const title = clean(body.title).slice(0, 160);
  const excerpt = clean(body.excerpt).slice(0, 300);
  const content = cleanBody(body.content).slice(0, 20000);
  const cover = clean(body.cover).slice(0, 300);
  const category = (clean(body.category) || 'umum').slice(0, 24);
  // Penulis bawaan: nama manusia (Haekal Saputra), label resminya
  // ditangani badge XySpace di klien — bukan ditumpuk ke nama penulis.
  const author = (clean(body.author) || 'Haekal Saputra').slice(0, 60);
  if (title.length < 4 || content.length < 10) {
    return json({ error: 'judul dan isi wajib diisi' }, 400);
  }
  // Slug: acak secara bawaan — tidak menebak urutan, tidak membocorkan judul
  // di URL. Pengecualiannya artikel changelog: footer web dan layar "Tentang"
  // menautkan versi ke `changelog-v<major>-<minor>-<patch>`, jadi slug-nya
  // harus bisa ditentukan. Hanya pola itu yang boleh dipilih sendiri, supaya
  // slug tebakan tidak bisa dipakai untuk artikel sembarangan.
  const requested = clean(body.slug).toLowerCase();
  const slug = /^changelog-v\d+-\d+-\d+$/.test(requested)
    ? requested
    : 'p-' + crypto.randomUUID().replaceAll('-', '').slice(0, 12);
  const dup = await env.DB.prepare('SELECT id FROM posts WHERE slug = ?')
    .bind(slug)
    .first();
  if (dup) return json({ error: 'slug sudah dipakai', slug }, 409);
  const r = await env.DB.prepare(
    `INSERT INTO posts (slug, title, excerpt, content, cover, category, author, published)
     VALUES (?, ?, ?, ?, ?, ?, ?, 1)`
  ).bind(slug, title, excerpt, content, cover, category, author).run();
  const postId = Number(r.meta.last_row_id);

  // Notifikasi berjalan asinkron — balasan API tidak menunggu kiriman push/email.
  request.ctx?.waitUntil?.(notifySubscribers(env, {
    slug,
    title,
    excerpt: excerpt || title,
    cover,
  }));

  return json({ ok: true, slug, id: postId });
}

async function notifySubscribers(env, post) {
  const results = await Promise.allSettled([
    sendPush(env, post),
    sendEmails(env, post),
  ]);
  // Kegagalan dicatat di log worker; tidak menggagalkan publikasi.
  for (const r of results) {
    if (r.status === 'rejected') console.error('notify gagal:', r.reason);
  }
}

/// Push OneSignal: semua pengguna yang sudah opt-in notifikasi.
async function sendPush(env, post) {
  if (!env.ONESIGNAL_APP_ID || !env.ONESIGNAL_API_KEY) return;
  const res = await fetch('https://onesignal.com/api/v1/notifications', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Basic ${env.ONESIGNAL_API_KEY}`,
    },
    body: JSON.stringify({
      app_id: env.ONESIGNAL_APP_ID,
      included_segments: ['Subscribed Users'],
      headings: { id: 'XyDesk News', en: 'XyDesk News' },
      contents: {
        id: post.title,
        en: post.excerpt || post.title,
      },
      url: `https://news.xystudio.my.id/n/${post.slug}`,
      chrome_web_image: post.cover || undefined,
      big_picture: post.cover || undefined,
      name: 'news',
    }),
  });
  if (!res.ok) throw new Error(`onesignal ${res.status}: ${await res.text()}`);
}

/// Email Resend ke seluruh pelanggan berita.
async function sendEmails(env, post) {
  if (!env.RESEND_API_KEY || !env.EMAIL_FROM) return;
  const subs = await env.DB.prepare('SELECT email FROM subscribers').all();
  for (const s of subs.results) {
    try {
      const res = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${env.RESEND_API_KEY}`,
        },
        body: JSON.stringify({
          from: `XyDesk News <${env.EMAIL_FROM}>`,
          to: [s.email],
          subject: `XyDesk: ${post.title}`,
          html: `<div style="font-family:sans-serif;max-width:560px;margin:auto">
  <div style="display:flex;align-items:center;gap:12px;padding:14px 18px;background:#0d0716;border-radius:14px 14px 0 0">
    <img src="https://app.xystudio.my.id/logo.png" alt="XyDesk" width="34" height="34" style="border-radius:8px;display:block;border:0" />
    <span style="color:#a78bfa;font-size:13px;font-weight:600">XyDesk News</span>
  </div>
  <div style="padding:22px;border:1px solid #e9e5f2;border-top:0;border-radius:0 0 14px 14px">
    <h2 style="margin:0 0 10px;color:#160f2b">${post.title}</h2>
    <p style="color:#5b5570">${post.excerpt || ''}</p>
    <a href="https://news.xystudio.my.id/n/${post.slug}" style="display:inline-block;background:#7c3aed;color:#fff;padding:11px 20px;border-radius:10px;text-decoration:none;font-weight:600">Baca di XyDesk</a>
    <p style="color:#9a94ad;font-size:12px;margin:20px 0 0">Kamu menerima email ini karena berlangganan berita XyDesk.</p>
    <div style="display:flex;align-items:center;gap:12px;margin-top:20px;padding-top:18px;border-top:1px solid #e9e5f2">
      <img src="https://app.xystudio.my.id/team/founder.jpg" alt="Haekal Saputra" width="34" height="34" style="border-radius:50%;object-fit:cover;display:block" />
      <div style="font-size:13px;color:#160f2b"><strong>Haekal Saputra</strong><br /><span style="color:#9a94ad">Founder, XySpace — via XyDesk News</span></div>
    </div>
  </div>
</div>`,
        }),
      });
      if (!res.ok) throw new Error(`resend ${res.status}`);
    } catch (e) {
      console.error('email gagal ke', s.email, e);
    }
  }
}

// ── Halaman berbagi (OpenGraph untuk crawler sosial) ────────────────────
function esc(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

async function sharePage(env, slug, url) {
  const p = await getPost(env, slug);
  if (!p) {
    return new Response('Tidak ditemukan.', { status: 404, headers: { 'content-type': 'text/plain; charset=utf-8' } });
  }
  const web = env.WEB_APP || 'https://app.xystudio.my.id';
  const target = `${web}/news/${p.slug}`;
  const shareUrl = `https://news.xystudio.my.id/n/${p.slug}`;
  const html = `<!doctype html>
<html lang="id">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(p.title)} — XyDesk</title>
<meta name="description" content="${esc(p.excerpt)}">
<link rel="canonical" href="${esc(shareUrl)}">
<meta property="og:type" content="article">
<meta property="og:site_name" content="XyDesk">
<meta property="og:title" content="${esc(p.title)}">
<meta property="og:description" content="${esc(p.excerpt)}">
<meta property="og:url" content="${esc(shareUrl)}">
<meta property="og:image" content="${esc(p.cover)}">
<meta property="og:locale" content="id_ID">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${esc(p.title)}">
<meta name="twitter:description" content="${esc(p.excerpt)}">
<meta name="twitter:image" content="${esc(p.cover)}">
<meta http-equiv="refresh" content="0; url=${esc(target)}">
<style>body{font-family:system-ui,sans-serif;background:#0a0a0a;color:#fff;display:flex;align-items:center;justify-content:center;height:100vh;margin:0}</style>
</head>
<body>Membuka <a href="${esc(target)}" style="color:#a78bfa">${esc(p.title)}</a>…</body>
</html>`;
  return new Response(html, {
    headers: { 'content-type': 'text/html; charset=utf-8', ...CORS },
  });
}

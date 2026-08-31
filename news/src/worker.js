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

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
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
      if (m && request.method === 'GET') return postDetail(env, m[1]);
      m = path.match(/^\/api\/news\/([a-z0-9-]+)\/like$/);
      if (m && request.method === 'POST') {
        return likePost(env, m[1], await readJson(request));
      }
      m = path.match(/^\/api\/news\/([a-z0-9-]+)\/comments$/);
      if (m && request.method === 'GET') return listComments(env, m[1]);
      if (m && request.method === 'POST') {
        return addComment(env, m[1], await readJson(request));
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
  };
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

async function postDetail(env, slug) {
  const p = await getPost(env, slug);
  if (!p) return json({ error: 'post-not-found' }, 404);
  const comments = await env.DB.prepare(
    `SELECT id, author, content, parent_id, created_at FROM comments WHERE post_id = ? ORDER BY created_at ASC, id ASC LIMIT 200`
  ).bind(p.id).all();
  return json({
    post: rowToPost(p),
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
    `SELECT id, author, content, parent_id, created_at FROM comments WHERE post_id = ? ORDER BY created_at ASC, id ASC LIMIT 200`
  ).bind(p.id).all();
  return json({ comments: rows.results.map(rowToComment) });
}

async function addComment(env, slug, body) {
  const p = await getPost(env, slug);
  if (!p) return json({ error: 'post-not-found' }, 404);
  const author = clean(body.author).slice(0, 40);
  const content = clean(body.content).slice(0, 1000);
  const fp = clean(body.fp).slice(0, 64);
  if (!author) return json({ error: 'nama tidak boleh kosong' }, 400);
  if (content.length < 2) return json({ error: 'komentar terlalu pendek' }, 400);
  if (!fp) return json({ error: 'fingerprint diperlukan' }, 400);

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

  // Batas laju: 5 komentar per 10 menit per fp.
  const recent = await env.DB.prepare(
    `SELECT COUNT(*) AS c FROM comments WHERE post_id = ? AND fp = ? AND created_at > datetime('now', '-10 minutes')`
  ).bind(p.id, fp).first();
  if (recent.c >= 5) {
    return json({ error: 'terlalu banyak komentar. Coba lagi nanti.' }, 429);
  }

  const now = new Date().toISOString();
  const r = parentId != null
    ? await env.DB.prepare(
        'INSERT INTO comments (post_id, author, content, fp, parent_id) VALUES (?, ?, ?, ?, ?)'
      ).bind(p.id, author, content, fp, parentId).run()
    : await env.DB.prepare(
        'INSERT INTO comments (post_id, author, content, fp) VALUES (?, ?, ?, ?)'
      ).bind(p.id, author, content, fp).run();
  return json({
    comment: {
      id: Number(r.meta.last_row_id),
      author,
      content,
      parentId,
      createdAt: now,
    },
  });
}

// ── Langganan email ─────────────────────────────────────────────────────
async function subscribe(env, body) {
  const email = clean(body.email).slice(0, 120).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
    return json({ error: 'alamat email tidak valid' }, 400);
  }
  const existing = await env.DB.prepare(
    'SELECT id FROM subscribers WHERE email = ?'
  ).bind(email).first();
  if (existing) {
    return json({ ok: true, subscribed: false, reason: 'sudah terdaftar' });
  }
  await env.DB.prepare('INSERT INTO subscribers (email) VALUES (?)').bind(email).run();
  return json({ ok: true, subscribed: true });
}

// ── Terbitkan artikel (admin) + notifikasi push & email ─────────────────
async function adminPublish(env, request, body) {
  const token = request.headers.get('x-admin-token') || '';
  if (!env.ADMIN_TOKEN || token !== env.ADMIN_TOKEN) {
    return json({ error: 'unauthorized' }, 401);
  }
  const title = clean(body.title).slice(0, 160);
  const excerpt = clean(body.excerpt).slice(0, 300);
  const content = clean(body.content).slice(0, 20000);
  const cover = clean(body.cover).slice(0, 300);
  const category = (clean(body.category) || 'umum').slice(0, 24);
  const author = (clean(body.author) || 'Tim XyDesk').slice(0, 60);
  if (title.length < 4 || content.length < 10) {
    return json({ error: 'judul dan isi wajib diisi' }, 400);
  }
  // Slug HASH acak — tidak menebak urutan, tidak membocorkan judul di URL.
  const slug = 'p-' + crypto.randomUUID().replaceAll('-', '').slice(0, 12);
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
  <h2 style="margin:0 0 8px">${post.title}</h2>
  <p style="color:#52525b">${post.excerpt || ''}</p>
  <a href="https://news.xystudio.my.id/n/${post.slug}" style="display:inline-block;background:#6d28d9;color:#fff;padding:10px 18px;border-radius:8px;text-decoration:none">Baca di XyDesk</a>
  <p style="color:#a1a1aa;font-size:12px;margin-top:16px">Kamu menerima email ini karena berlangganan berita XyDesk.</p>
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

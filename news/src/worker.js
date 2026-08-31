// XyDesk News — Worker publik (D1): feed berita + halaman berbagi OpenGraph.
//
// TERPISAH dari Worker signaling. Semua endpoint publik — berita tidak butuh
// akun. Batas-batas kecil dipasang biar murah dan tidak bisa disalahgunakan:
//   - like: idempoten per sidik jari (fingerprint) yang dibuat client
//   - komentar: maks 5 per 10 menit per fingerprint, panjang terbatas
//   - seluruh input disanitasi (tag HTML dibuang)

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
    `SELECT id, author, content, created_at FROM comments WHERE post_id = ? ORDER BY created_at ASC, id ASC LIMIT 200`
  ).bind(p.id).all();
  return json({
    post: rowToPost(p),
    comments: comments.results.map((c) => ({
      id: c.id,
      author: c.author,
      content: c.content,
      createdAt: c.created_at,
    })),
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
    `SELECT id, author, content, created_at FROM comments WHERE post_id = ? ORDER BY created_at ASC, id ASC LIMIT 200`
  ).bind(p.id).all();
  return json({
    comments: rows.results.map((c) => ({
      id: c.id,
      author: c.author,
      content: c.content,
      createdAt: c.created_at,
    })),
  });
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
  // Batas laju: 5 komentar per 10 menit per fp.
  const recent = await env.DB.prepare(
    `SELECT COUNT(*) AS c FROM comments WHERE post_id = ? AND fp = ? AND created_at > datetime('now', '-10 minutes')`
  ).bind(p.id, fp).first();
  if (recent.c >= 5) {
    return json({ error: 'terlalu banyak komentar. Coba lagi nanti.' }, 429);
  }
  const r = await env.DB.prepare(
    'INSERT INTO comments (post_id, author, content, fp) VALUES (?, ?, ?, ?)'
  ).bind(p.id, author, content, fp).run();
  return json({
    comment: {
      id: Number(r.meta.last_row_id),
      author,
      content,
      createdAt: new Date().toISOString(),
    },
  });
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
<style>body{font-family:system-ui,sans-serif;background:#131315;color:#ededef;display:flex;align-items:center;justify-content:center;height:100vh;margin:0}</style>
</head>
<body>Membuka <a href="${esc(target)}" style="color:#7654f6">${esc(p.title)}</a>…</body>
</html>`;
  return new Response(html, {
    headers: { 'content-type': 'text/html; charset=utf-8', ...CORS },
  });
}

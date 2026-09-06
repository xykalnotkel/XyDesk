// XyDesk Web — Worker renderer OpenGraph.
//
// Tugasnya satu: saat crawler sosial (WhatsApp/Telegram/FB/X) meminta
// halaman, berikan HTML berisi tag OpenGraph sesuai KONTEN halaman —
// terutama /news/<slug> (judul, ringkasan, sampul dari basis berita).
// Browser manusia tetap mendapat aplikasi Vite statis lewat env.ASSETS.
//
// Data berita dibaca langsung dari D1 (binding DB) — tanpa fetch
// edge-to-edge yang lambat dan rapuh. Kalau binding tidak tersedia
// (lingkungan dev), fallback ke API publik berita.

const NEWS_API = 'https://news.xydesk.my.id';
const SITE = 'https://app.xydesk.my.id';

const BOT_PATTERNS = [
  /facebookexternalhit/i,
  /Facebot/i,
  /Twitterbot/i,
  /Slackbot/i,
  /LinkedInBot/i,
  /TelegramBot/i,
  /WhatsApp/i,
  /Discordbot/i,
  /Googlebot/i,
  /Bingbot/i,
  /DuckDuckBot/i,
  /YandexBot/i,
  /baiduspider/i,
  /Applebot/i,
  /vkShare/i,
  /redditbot/i,
  /Mastodon/i,
  /pinterest/i,
  /embed\.ly/i,
  /iframely/i,
  /Scrapy/i,
];

const DEFAULT_OG = {
  title: 'XyDesk — Remote Desktop Android, Windows & Web',
  description:
    'Akses layar PC dari HP atau browser dengan target glass-to-glass di bawah 40 ms di LAN. Untuk kerja, untuk game — media sesi peer-to-peer.',
  image: `${SITE}/og-image.jpg`,
  type: 'website',
};

function isBot(ua) {
  return BOT_PATTERNS.some((re) => re.test(ua));
}

function esc(s) {
  return String(s ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function ogPage({ title, description, image, type, url }) {
  const img = image && image.startsWith('http') ? image : DEFAULT_OG.image;
  return `<!doctype html>
<html lang="id">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)}</title>
<meta name="description" content="${esc(description)}">
<meta property="og:type" content="${esc(type)}">
<meta property="og:site_name" content="XyDesk">
<meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="${esc(description)}">
<meta property="og:url" content="${esc(url)}">
<meta property="og:image" content="${esc(img)}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:locale" content="id_ID">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${esc(title)}">
<meta name="twitter:description" content="${esc(description)}">
<meta name="twitter:image" content="${esc(img)}">
<link rel="canonical" href="${esc(url)}">
</head>
<body style="font-family:sans-serif;background:#0a0a0a;color:#fff;margin:0;padding:40px">
<h1 style="margin:0 0 8px">${esc(title)}</h1>
<p style="margin:0 0 16px;color:#a1a1aa">${esc(description)}</p>
<a href="${esc(url)}" style="color:#8b5cf6">Buka di XyDesk Web →</a>
</body>
</html>`;
}

async function newsOg(slug, env) {
  const url = `${SITE}/news/${encodeURIComponent(slug)}`;
  // Jalur utama: baca langsung dari D1 (tanpa lompatan jaringan).
  if (env && env.DB) {
    try {
      const row = await env.DB.prepare(
        'SELECT slug, title, excerpt, cover FROM posts WHERE slug = ? AND published = 1 LIMIT 1',
      )
        .bind(slug)
        .first();
      if (row && row.title) {
        return ogPage({
          title: row.title,
          description: row.excerpt || '',
          image: row.cover,
          type: 'article',
          url,
        });
      }
    } catch {
      // Lanjut ke fallback HTTP di bawah.
    }
  }
  // Fallback: API publik (dipakai di lingkungan tanpa binding D1).
  try {
    const res = await fetch(`${NEWS_API}/api/news/${encodeURIComponent(slug)}`, {
      headers: { accept: 'application/json' },
    });
    if (!res.ok) throw new Error(`news ${res.status}`);
    const data = await res.json();
    const post = data.post;
    if (!post) throw new Error('post kosong');
    return ogPage({
      title: post.title,
      description: post.excerpt,
      image: post.cover,
      type: 'article',
      url,
    });
  } catch {
    // Gagal ambil berita — jangan hancurkan share; pakai fallback umum.
    return ogPage({ ...DEFAULT_OG, type: 'article', url });
  }
}

export default {
  async fetch(request, env) {
    const ua = request.headers.get('user-agent') || '';
    const url = new URL(request.url);

    if (isBot(ua)) {
      if (url.pathname.startsWith('/news/')) {
        const slug = decodeURIComponent(url.pathname.slice('/news/'.length)).trim();
        if (slug) {
          return new Response(await newsOg(slug, env), {
            headers: {
              'content-type': 'text/html; charset=utf-8',
              'cache-control': 'public, max-age=300',
            },
          });
        }
      }
      return new Response(ogPage({ ...DEFAULT_OG, url: SITE + url.pathname }), {
        headers: {
          'content-type': 'text/html; charset=utf-8',
          'cache-control': 'public, max-age=600',
        },
      });
    }

    // Browser manusia: aset statis Vite, dengan fallback SPA.
    let res = await env.ASSETS.fetch(request);
    if (res.status === 404) {
      res = await env.ASSETS.fetch(new Request(`${SITE}/index.html`, request));
    }
    return res;
  },
};

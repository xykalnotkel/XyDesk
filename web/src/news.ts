// Klien News XyDesk — API publik di Worker terpisah (D1).
// https://news.xystudio.my.id — berita publik tanpa akun.
//
// Halaman berbagi (untuk crawler sosial + WhatsApp/Telegram/X):
//   https://news.xystudio.my.id/n/:slug  → OpenGraph + redirect ke halaman ini.
// Aplikasi web sendiri membaca: https://news.xystudio.my.id/api/news/...

export const NEWS_BASE = 'https://news.xystudio.my.id';
export const NEWS_SHARE_BASE = 'https://news.xystudio.my.id/n';

export interface NewsPost {
  slug: string;
  title: string;
  excerpt: string;
  content: string;
  cover: string;
  category: string;
  author: string;
  createdAt: string;
  likeCount: number;
  commentCount: number;
}

export interface NewsComment {
  id: number;
  author: string;
  content: string;
  createdAt: string;
}

export const NEWS_CATEGORIES = ['semua', 'rilis', 'teknik', 'umum'] as const;

/// Sidik jari perangkat untuk like/komentar (tanpa akun). Disimpan lokal;
/// cukup untuk idempotensi like dan batas laju komentar.
export function newsFingerprint(): string {
  const KEY = 'xydesk.news.fp';
  let fp = localStorage.getItem(KEY);
  if (!fp) {
    const buf = new Uint8Array(16);
    crypto.getRandomValues(buf);
    fp = Array.from(buf, (b) => b.toString(16).padStart(2, '0')).join('');
    localStorage.setItem(KEY, fp);
  }
  return fp;
}

async function getJson<T>(url: string, init?: RequestInit): Promise<T> {
  const res = await fetch(url, init);
  const data = (await res.json().catch(() => ({}))) as T & { error?: string };
  if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
  return data;
}

export function fetchNewsList(
  category?: string,
  limit = 30,
): Promise<{ posts: NewsPost[] }> {
  const q = new URLSearchParams({ limit: String(limit) });
  if (category && category !== 'semua') q.set('category', category);
  return getJson(`${NEWS_BASE}/api/news?${q}`);
}

export function fetchNewsPost(slug: string): Promise<{
  post: NewsPost;
  comments: NewsComment[];
}> {
  return getJson(`${NEWS_BASE}/api/news/${encodeURIComponent(slug)}`);
}

export function toggleLike(slug: string): Promise<{ liked: boolean; likeCount: number }> {
  return getJson(`${NEWS_BASE}/api/news/${encodeURIComponent(slug)}/like`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ fp: newsFingerprint() }),
  });
}

export function postComment(
  slug: string,
  author: string,
  content: string,
): Promise<{ comment: NewsComment }> {
  return getJson(`${NEWS_BASE}/api/news/${encodeURIComponent(slug)}/comments`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ fp: newsFingerprint(), author, content }),
  });
}

/// Format tanggal "2026-08-31 05:00:00" → "31 Agu 2026".
export function formatNewsDate(iso: string): string {
  const d = new Date(iso.includes('T') ? iso : iso.replace(' ', 'T') + 'Z');
  if (Number.isNaN(d.getTime())) return iso.slice(0, 10);
  return d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' });
}

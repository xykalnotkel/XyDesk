// Klien News untuk shell desktop — API publik yang sama dengan web/Android:
// https://news.xystudio.my.id (Worker + D1). Renderer boleh memanggil
// langsung karena CORS terbuka dan data publik.

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
  parentId?: number | null;
  createdAt: string;
}

export const NEWS_CATEGORIES = ['semua', 'rilis', 'teknik', 'umum'] as const;

export function newsFingerprint(): string {
  const KEY = 'xydesk.desktop.news.fp';
  let fp = localStorage.getItem(KEY);
  if (!fp) {
    const buf = new Uint8Array(16);
    crypto.getRandomValues(buf);
    fp = Array.from(buf, (b) => b.toString(16).padStart(2, '0')).join('');
    localStorage.setItem(KEY, fp);
  }
  return fp;
}

/// Nama tampilan acak per instalasi — tanpa kolom nama manual.
export function newsDisplayName(): string {
  const KEY = 'xydesk.desktop.news.name';
  let name = localStorage.getItem(KEY);
  if (!name) {
    const fp = newsFingerprint();
    let h = 0;
    for (let i = 0; i < fp.length; i++) h = (h * 31 + fp.charCodeAt(i)) >>> 0;
    name = `tamu-${h.toString(16).padStart(4, '0')}`;
    localStorage.setItem(KEY, name);
  }
  return name;
}

async function getJson<T>(url: string, init?: RequestInit): Promise<T> {
  const res = await fetch(url, init);
  const data = (await res.json().catch(() => ({}))) as T & { error?: string };
  if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
  return data;
}

export function fetchNewsList(category?: string): Promise<{ posts: NewsPost[] }> {
  const q = new URLSearchParams({ limit: '30' });
  if (category && category !== 'semua') q.set('category', category);
  return getJson(`${NEWS_BASE}/api/news?${q}`);
}

export function fetchNewsPost(slug: string): Promise<{ post: NewsPost; comments: NewsComment[] }> {
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
  content: string,
  parentId?: number | null,
): Promise<{ comment: NewsComment }> {
  return getJson(`${NEWS_BASE}/api/news/${encodeURIComponent(slug)}/comments`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      fp: newsFingerprint(),
      author: newsDisplayName(),
      content,
      ...(parentId != null ? { parentId } : {}),
    }),
  });
}

/// Daftarkan email untuk langganan berita.
export function subscribeNews(email: string): Promise<{ ok: boolean }> {
  return getJson(`${NEWS_BASE}/api/subscribe`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email }),
  });
}

export function formatNewsDate(iso: string): string {
  const d = new Date(iso.includes('T') ? iso : iso.replace(' ', 'T') + 'Z');
  if (Number.isNaN(d.getTime())) return iso.slice(0, 10);
  return d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' });
}

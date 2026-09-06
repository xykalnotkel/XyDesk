// Klien News XyDesk — API publik di Worker terpisah (D1).
// https://news.xydesk.my.id — berita publik tanpa akun.
//
// Halaman berbagi (untuk crawler sosial + WhatsApp/Telegram/X):
//   https://news.xydesk.my.id/n/:slug  → OpenGraph + redirect ke halaman ini.
// Aplikasi web sendiri membaca: https://news.xydesk.my.id/api/news/...
//
// Rilis 6.0: balasan komentar (parentId), username acak per perangkat
// (tanpa kolom nama), langganan email berita.

import { ApiError } from './api';

export const NEWS_BASE = 'https://news.xydesk.my.id';
export const NEWS_SHARE_BASE = 'https://news.xydesk.my.id/n';

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
  /// Ditetapkan SERVER dari ADMIN_TOKEN — klien tidak bisa memintanya.
  /// Lihat `news/src/worker.js` dan `news/test/comments.test.js`.
  official?: boolean;
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

/// Nama tampilan acak per perangkat — stabil antar kunjungan.
/// Tidak ada kolom nama manual: pengguna cukup berkomentar.
///
/// Nama dibentuk dari daftar nama manusia (bukan "tamu-xxxx") supaya kolom
/// komentar terasa hidup. Turunan deterministik dari sidik jari perangkat:
/// orang yang sama selalu muncul dengan nama yang sama.
const NAME_FIRST = [
  'Raka', 'Sinta', 'Bima', 'Dewi', 'Aldi', 'Nadia', 'Fajar', 'Laras',
  'Galih', 'Ayu', 'Reza', 'Putri', 'Dimas', 'Ratna', 'Yoga', 'Salsa',
  'Ilham', 'Maya', 'Rio', 'Tania', 'Bagus', 'Intan', 'Eka', 'Wulan',
  'Arif', 'Citra', 'Damar', 'Nirmala', 'Panji', 'Kirana', 'Satria', 'Anggi',
];
const NAME_LAST = [
  'Saputra', 'Pratama', 'Lestari', 'Wijaya', 'Ramadhan', 'Maharani',
  'Nugroho', 'Anggraini', 'Santoso', 'Utami', 'Firmansyah', 'Puspita',
  'Hidayat', 'Safitri', 'Kurniawan', 'Melati', 'Gunawan', 'Andini',
  'Prasetyo', 'Rahayu', 'Mahendra', 'Paramita', 'Wibowo', 'Larasati',
];

export function newsDisplayName(): string {
  const KEY = 'xydesk.news.name';
  let name = localStorage.getItem(KEY);
  // Regenerasi juga untuk pengguna lama yang masih tersimpan "tamu-xxxx".
  if (!name || /^tamu-/i.test(name)) {
    const fp = newsFingerprint();
    let h = 0;
    for (let i = 0; i < fp.length; i++) h = (h * 31 + fp.charCodeAt(i)) >>> 0;
    const first = NAME_FIRST[h % NAME_FIRST.length];
    const last = NAME_LAST[Math.floor(h / NAME_FIRST.length) % NAME_LAST.length];
    name = `${first} ${last}`;
    localStorage.setItem(KEY, name);
  }
  return name;
}

/// Foto profil komentator — dihasilkan DiceBear (gratis, tanpa kunci API)
/// dari nama penulis: nama sama = wajah sama, di perangkat mana pun.
/// Komentar resmi (official) tidak lewat sini — mereka memakai logo XyDesk.
export function newsAvatarUrl(author: string): string {
  return `https://api.dicebear.com/9.x/adventurer/svg?seed=${encodeURIComponent(author)}&backgroundColor=ede9fe,fde68a,bbf7d0,bae6fd`;
}

async function getJson<T>(url: string, init?: RequestInit): Promise<T> {
  const res = await fetch(url, init);
  const data = (await res.json().catch(() => ({}))) as T & { error?: string };
  // ApiError (bukan Error polos) supaya `explainError` bisa membedakan 404
  // dari gangguan jaringan dan menampilkan pesan manusiawi — bukan kode galat
  // mentah seperti "post-not-found".
  if (!res.ok) {
    throw new ApiError(res.status, data.error ?? 'unknown', data.error ?? `HTTP ${res.status}`);
  }
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
  liked: boolean;
}> {
  // Sidik jari ikut dikirim supaya server yang memutuskan tombol suka
  // tampil terisi atau tidak. localStorage saja tidak cukup: begitu cache
  // browser dibersihkan, suka yang tercatat di server jadi tidak kelihatan.
  const fp = encodeURIComponent(newsFingerprint());
  return getJson(`${NEWS_BASE}/api/news/${encodeURIComponent(slug)}?fp=${fp}`);
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
  admin?: { token?: string; googleToken?: string },
): Promise<{ comment: NewsComment }> {
  return getJson(`${NEWS_BASE}/api/news/${encodeURIComponent(slug)}/comments`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      // Badge resmi tetap keputusan SERVER: header ini cuma bukti, worker
      // yang memvalidasi. Dua bukti yang diterima: token ADMIN_TOKEN lama,
      // atau Google ID token (diprioritaskan bila tersedia — founder tidak
      // perlu lagi menempel token manual).
      ...(admin?.googleToken
        ? { 'x-admin-google-token': admin.googleToken }
        : admin?.token
          ? { 'x-admin-token': admin.token }
          : {}),
    },
    body: JSON.stringify({
      fp: newsFingerprint(),
      author: admin ? ADMIN_DISPLAY_NAME : newsDisplayName(),
      content,
      ...(parentId != null ? { parentId } : {}),
    }),
  });
}

// ── Mode admin (founder) ───────────────────────────────────────
// Email Google founder → balasan tampil sebagai Haekal Saputra dengan foto
// profil resmi + badge XySpace. Email hanya MEMBUKA UI-nya; otoritas
// sesungguhnya tetap ADMIN_TOKEN yang divalidasi worker — email saja tidak
// bisa memalsukan badge.
export const ADMIN_EMAIL = 'xycdigital@gmail.com';
export const ADMIN_DISPLAY_NAME = 'Haekal Saputra';
const ADMIN_TOKEN_KEY = 'xydesk.news.adminToken';

export function getAdminToken(): string {
  return localStorage.getItem(ADMIN_TOKEN_KEY) ?? '';
}

export function setAdminToken(token: string): void {
  if (token.trim()) localStorage.setItem(ADMIN_TOKEN_KEY, token.trim());
  else localStorage.removeItem(ADMIN_TOKEN_KEY);
}

/// Daftarkan email untuk dikabari nanti.
///
/// `source` menentukan ia dikabari saat apa: 'berita' saat artikel baru
/// terbit, 'unduhan' saat tombol unduh dibuka. Keduanya tersimpan di tabel
/// yang sama (lihat news/migrations/0003).
export function subscribeNews(
  email: string,
  source: 'berita' | 'unduhan' = 'berita',
): Promise<{ ok: boolean; subscribed?: boolean; reason?: string }> {
  return getJson(`${NEWS_BASE}/api/subscribe`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email, source }),
  });
}

/// Format tanggal "2026-08-31 05:00:00" → "31 Agu 2026".
export function formatNewsDate(iso: string): string {
  const d = new Date(iso.includes('T') ? iso : iso.replace(' ', 'T') + 'Z');
  if (Number.isNaN(d.getTime())) return iso.slice(0, 10);
  return d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' });
}

/// Waktu relatif untuk komentar: "1 detik lalu", "5 menit lalu", dst.
/// Lewat 4 minggu kembali ke tanggal biasa — "37 minggu lalu" menyulitkan.
export function formatRelativeTime(iso: string): string {
  const d = new Date(iso.includes('T') ? iso : iso.replace(' ', 'T') + 'Z');
  if (Number.isNaN(d.getTime())) return formatNewsDate(iso);
  const s = Math.max(1, Math.floor((Date.now() - d.getTime()) / 1000));
  if (s < 60) return `${s} detik lalu`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m} menit lalu`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h} jam lalu`;
  const hari = Math.floor(h / 24);
  if (hari < 7) return `${hari} hari lalu`;
  const minggu = Math.floor(hari / 7);
  if (minggu < 5) return `${minggu} minggu lalu`;
  return formatNewsDate(iso);
}

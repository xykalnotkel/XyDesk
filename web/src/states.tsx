// Keadaan kosong, gagal, dan offline untuk seluruh halaman web.
//
// Mengapa berkas ini ada: sebelumnya tiap halaman menulis pesannya sendiri.
// Akibatnya tiga halaman memakai tiga gaya berbeda, tidak satu pun yang
// membedakan "datanya memang kosong" dari "koneksinya putus" — padahal dua
// keadaan itu minta tindakan yang sama sekali berbeda dari pembaca. Yang
// paling parah: tombol "coba lagi" di daftar berita memanggil
// setCategory(nilaiYangSama), sehingga efeknya tidak pernah jalan lagi dan
// tombolnya tidak melakukan apa-apa.

import { useCallback, useEffect, useState } from 'react';

import { ApiError } from './api';

export type StateTone = 'empty' | 'error' | 'offline';

/** Apakah perangkat sedang terhubung. Diperbarui saat status jaringan berubah. */
export function useOnline(): boolean {
  const [online, setOnline] = useState(
    () => typeof navigator === 'undefined' || navigator.onLine,
  );

  useEffect(() => {
    const up = () => setOnline(true);
    const down = () => setOnline(false);
    window.addEventListener('online', up);
    window.addEventListener('offline', down);
    return () => {
      window.removeEventListener('online', up);
      window.removeEventListener('offline', down);
    };
  }, []);

  return online;
}

/**
 * Penanda untuk memicu ulang pengambilan data.
 *
 * Mengembalikan [nonce, reload]. Masukkan `nonce` keDependensi useEffect dan
 * panggil `reload()` dari tombol ulang. Jangan memakai ulang variabel keadaan
 * yang nilainya bisa sama dengan sebelumnya — efeknya tidak akan berjalan.
 */
export function useReload(): [number, () => void] {
  const [nonce, setNonce] = useState(0);
  const reload = useCallback(() => setNonce((n) => n + 1), []);
  return [nonce, reload];
}

/** Pesan yang bisa dipahami orang, bukan pesan mentah dari mesin. */
export function explainError(e: unknown, fallback: string, online: boolean): string {
  if (!online) {
    return 'Perangkat kamu sedang tidak terhubung ke internet. Begitu sambungannya kembali, halaman ini akan kami isi ulang.';
  }
  if (e instanceof ApiError) {
    if (e.status === 404) return 'Yang kamu cari tidak ada di sini. Mungkin tautannya sudah lama.';
    if (e.status === 429) return 'Terlalu banyak permintaan. Tunggu sebentar, lalu coba lagi.';
    if (e.status >= 500) return 'Server kami sedang bermasalah. Bukan salah kamu — coba lagi sebentar lagi.';
    return e.message || fallback;
  }
  if (e instanceof TypeError) {
    // fetch gagal sebelum sempat mendapat balasan: DNS, CORS, atau putus di
    // tengah jalan. Untuk pembaca, semua itu bunyinya sama.
    return 'Sambungan ke server terputus sebelum selesai. Cek jaringan kamu, lalu coba lagi.';
  }
  return e instanceof Error ? e.message : fallback;
}

function Glyph({ kind }: { kind: 'news' | 'comment' | 'cloud' | 'alert' }) {
  const common = {
    width: 26,
    height: 26,
    viewBox: '0 0 24 24',
    fill: 'none',
    stroke: 'currentColor',
    strokeWidth: 1.6,
    strokeLinecap: 'round' as const,
    strokeLinejoin: 'round' as const,
    'aria-hidden': true,
  };
  if (kind === 'news') {
    return (
      <svg {...common}>
        <path d="M4 6h11a1 1 0 0 1 1 1v11" />
        <path d="M4 6v12a2 2 0 0 0 2 2h11" />
        <path d="M7 10h7M7 14h5" />
      </svg>
    );
  }
  if (kind === 'comment') {
    return (
      <svg {...common}>
        <path d="M20 15a3 3 0 0 1-3 3H9l-4 3v-3H6a3 3 0 0 1-3-3V8a3 3 0 0 1 3-3h11a3 3 0 0 1 3 3z" />
      </svg>
    );
  }
  if (kind === 'cloud') {
    return (
      <svg {...common}>
        <path d="M17 18H7a4 4 0 0 1-.4-8A6 6 0 0 1 18 9.5a4 4 0 0 1-1 8.5z" />
        <path d="M3 4l18 18" />
      </svg>
    );
  }
  return (
    <svg {...common}>
      <path d="M12 9v5M12 17.5v.5" />
      <path d="M10.3 4.3 2.6 18a2 2 0 0 0 1.7 3h15.4a2 2 0 0 0 1.7-3L13.7 4.3a2 2 0 0 0-3.4 0z" />
    </svg>
  );
}

const DEFAULT_TITLE: Record<StateTone, string> = {
  empty: 'Belum ada isinya',
  error: 'Gagal memuat',
  offline: 'Kamu sedang offline',
};

const DEFAULT_GLYPH: Record<StateTone, 'news' | 'comment' | 'cloud' | 'alert'> = {
  empty: 'news',
  error: 'alert',
  offline: 'cloud',
};

export interface StateNoticeProps {
  tone: StateTone;
  /** Kalimat utama. Tulis dampaknya, bukan nama galatnya. */
  title?: string;
  /** Satu kalimat yang menjelaskan apa yang bisa dilakukan pembaca. */
  message?: string;
  actionLabel?: string;
  onAction?: () => void;
  glyph?: 'news' | 'comment' | 'cloud' | 'alert';
  compact?: boolean;
}

export function StateNotice({
  tone,
  title,
  message,
  actionLabel,
  onAction,
  glyph,
  compact = false,
}: StateNoticeProps) {
  return (
    <div
      className={`state-notice ${tone}${compact ? ' compact' : ''}`}
      role={tone === 'empty' ? 'status' : 'alert'}
    >
      <span className="state-glyph">
        <Glyph kind={glyph ?? DEFAULT_GLYPH[tone]} />
      </span>
      <div className="state-body">
        <p className="state-title">{title ?? DEFAULT_TITLE[tone]}</p>
        {message && <p className="state-message">{message}</p>}
      </div>
      {actionLabel && onAction && (
        <button type="button" className="state-action" onClick={onAction}>
          {actionLabel}
        </button>
      )}
    </div>
  );
}

/** Kerangka daftar berita selagi data diambil. */
export function NewsGridSkeleton({ count = 3 }: { count?: number }) {
  return (
    <div className="news-grid">
      {Array.from({ length: count }, (_, i) => (
        <div className="news-card skeleton" key={i}>
          <div className="news-card-cover sk" />
          <div className="news-card-body">
            <div className="sk-line w80" />
            <div className="sk-line w100" />
            <div className="sk-line w60" />
          </div>
        </div>
      ))}
    </div>
  );
}

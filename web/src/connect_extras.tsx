// Pelengkap halaman Connect: pemindai QR, panduan main, dan tautan
// sosmed — cermin fitur yang sama di aplikasi Android
// (lib/features/connect/connect_page.dart + guide_page.dart).
import { useEffect, useRef, useState } from 'react';
import { TelegramIcon, WhatsAppIcon, TikTokIcon } from './brand-icons';

/// Ekstrak ID 9 digit dari payload QR; null bila bukan QR XyDesk.
/// Sama persis dengan parseHostId di aplikasi Android: menerima
/// "123456789" polos maupun URI xydesk://connect?id=123456789.
export function parseHostId(raw: string): string | null {
  let candidate = raw;
  try {
    const uri = new URL(raw);
    if (uri.protocol === 'xydesk:') candidate = uri.searchParams.get('id') ?? '';
  } catch {
    // Bukan URI — pakai teks mentah.
  }
  const digits = candidate.replace(/\D/g, '');
  return digits.length === 9 ? digits : null;
}

// ── Pemindai QR ────────────────────────────────────────────────
// Kamera belakang + BarcodeDetector bawaan browser bila ada; jsQR
// (dimuat lambat, tidak membebani bundle utama) sebagai cadangan untuk
// browser tanpa API itu (Safari/Firefox).
export function QrScanModal({
  onResult,
  onClose,
}: {
  onResult: (id: string) => void;
  onClose: () => void;
}) {
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const [error, setError] = useState('');

  useEffect(() => {
    let alive = true;
    let stream: MediaStream | null = null;
    let timer = 0;
    const stop = () => stream?.getTracks().forEach((t) => t.stop());

    (async () => {
      try {
        stream = await navigator.mediaDevices.getUserMedia({
          video: { facingMode: 'environment' },
        });
      } catch {
        if (alive) {
          setError(
            'Kamera tidak bisa diakses. Izinkan akses kamera di browser, atau masukkan ID secara manual.',
          );
        }
        return;
      }
      if (!alive || !videoRef.current) {
        stop();
        return;
      }
      const video = videoRef.current;
      video.srcObject = stream;
      await video.play().catch(() => undefined);

      // Pilih detektor sekali di awal, bukan tiap frame.
      type Detect = (v: HTMLVideoElement) => Promise<string | null>;
      let detect: Detect;
      const BD = (
        window as unknown as {
          BarcodeDetector?: {
            new (opts: { formats: string[] }): {
              detect(v: HTMLVideoElement): Promise<{ rawValue: string }[]>;
            };
            getSupportedFormats(): Promise<string[]>;
          };
        }
      ).BarcodeDetector;
      let native = false;
      if (BD) {
        try {
          native = (await BD.getSupportedFormats()).includes('qr_code');
        } catch {
          native = false;
        }
      }
      if (native && BD) {
        const det = new BD({ formats: ['qr_code'] });
        detect = async (v) => {
          try {
            const codes = await det.detect(v);
            return codes[0]?.rawValue ?? null;
          } catch {
            return null;
          }
        };
      } else {
        const jsQR = (await import('jsqr')).default;
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d', { willReadFrequently: true });
        detect = async (v) => {
          if (!ctx || !v.videoWidth) return null;
          const w = Math.min(640, v.videoWidth);
          const h = Math.round(v.videoHeight * (w / v.videoWidth));
          canvas.width = w;
          canvas.height = h;
          ctx.drawImage(v, 0, 0, w, h);
          const img = ctx.getImageData(0, 0, w, h);
          return jsQR(img.data, w, h)?.data ?? null;
        };
      }

      const loop = async () => {
        if (!alive) return;
        const raw = await detect(video);
        const id = raw ? parseHostId(raw) : null;
        if (id) {
          stop();
          if (navigator.vibrate) navigator.vibrate(60);
          onResult(id);
          return;
        }
        timer = window.setTimeout(() => void loop(), 180);
      };
      void loop();
    })();

    return () => {
      alive = false;
      clearTimeout(timer);
      stop();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div className="qr-modal" role="dialog" aria-modal="true" aria-label="Pindai QR">
      <div className="qr-box">
        <header className="qr-head">
          <strong>Pindai QR</strong>
          <button type="button" className="qr-close" onClick={onClose} title="Tutup">
            ✕
          </button>
        </header>
        {error ? (
          <p className="qr-error">{error}</p>
        ) : (
          <>
            <div className="qr-view">
              <video ref={videoRef} playsInline muted />
              <i className="qr-frame" aria-hidden="true" />
            </div>
            <p className="qr-hint">Arahkan kamera ke QR pada aplikasi XyDesk Host di PC.</p>
          </>
        )}
      </div>
    </div>
  );
}

// ── Panduan main ───────────────────────────────────────────────
// Teks langkah dari GuidePage aplikasi Android; langkah client
// disesuaikan karena client-nya di sini adalah browser, bukan APK.
const CLIENT_STEPS: [string, string][] = [
  [
    'Buka halaman ini',
    'Halaman Connect ini adalah client-nya — tidak perlu memasang aplikasi apa pun di perangkat ini.',
  ],
  ['Dapatkan ID dari host', 'Minta ID perangkat dan kata sandi dari aplikasi XyDesk Host.'],
  [
    'Masukkan ID atau pindai QR',
    'Ketik data host pada formulir di atas, atau gunakan tombol Pindai QR.',
  ],
  [
    'Mulai sesi',
    'Tekan Konek sekarang, tunggu pairing selesai, dan layar PC muncul di browser.',
  ],
];
const HOST_STEPS: [string, string][] = [
  ['Pasang aplikasi host', 'Jalankan XyDesk Host di PC yang ingin kamu akses.'],
  ['Aktifkan akses remote', 'Pastikan aplikasi host aktif dan PC tidak masuk sleep.'],
  ['Bagikan ID atau QR', 'Tampilkan ID dan QR pairing dari halaman host untuk client.'],
  ['Terima koneksi', 'Saat client masuk, periksa permintaan lalu izinkan sesi remote.'],
];

export function ConnectGuide() {
  const [side, setSide] = useState<'client' | 'host'>('client');
  const steps = side === 'client' ? CLIENT_STEPS : HOST_STEPS;
  return (
    <section className="connect-guide surface-card">
      <h2>Cara main</h2>
      <p className="muted">Ikuti langkah sesuai sisi yang sedang kamu siapkan.</p>
      <div className="guide-toggle" role="tablist">
        <button
          type="button"
          role="tab"
          aria-selected={side === 'client'}
          className={side === 'client' ? 'active' : ''}
          onClick={() => setSide('client')}
        >
          Sisi client
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={side === 'host'}
          className={side === 'host' ? 'active' : ''}
          onClick={() => setSide('host')}
        >
          Sisi host (PC)
        </button>
      </div>
      <ol className="guide-steps">
        {steps.map(([title, desc], i) => (
          <li key={title}>
            <span className="guide-num">{i + 1}</span>
            <div>
              <strong>{title}</strong>
              <p>{desc}</p>
            </div>
          </li>
        ))}
      </ol>
    </section>
  );
}

// ── Sosmed ─────────────────────────────────────────────────────
// Tautan yang sama dengan blok "Dukung kami di" di aplikasi Android.
const SOCIALS = [
  { label: 'Telegram', url: 'https://t.me/xydesk', Icon: TelegramIcon },
  {
    label: 'WhatsApp',
    url: 'https://whatsapp.com/channel/0029VbB7nwuJZg3ym6UQ4Z1L',
    Icon: WhatsAppIcon,
  },
  { label: 'TikTok', url: 'https://tiktok.com/@xydesk', Icon: TikTokIcon },
];

export function SupportLinks() {
  return (
    <div className="support-block">
      <span className="support-title">Dukung kami di</span>
      <div className="support-row">
        {SOCIALS.map(({ label, url, Icon }) => (
          <a key={label} href={url} target="_blank" rel="noopener noreferrer" title={label}>
            <Icon />
            <span>{label}</span>
          </a>
        ))}
      </div>
    </div>
  );
}

import { lazy, Suspense, useCallback, useEffect, useId, useRef, useState } from 'react';
import type { FormEvent, ReactElement } from 'react';
import {
  ApiError,
  createGuestSession,
  deleteAccount,
  me,
  requestOtp,
  signInWithGoogle,
  updateProfileName,
  UserProfile,
  verifyOtp,
} from './api';
import { detectDevicePackage, initialDevicePackage } from './device';
import {
  explainError,
  NewsGridSkeleton,
  StateNotice,
  useOnline,
  useReload,
} from './states';
import {
  beginGoogleLogin,
  consumeGoogleRedirect,
  consumeGoogleReturn,
  storeGoogleIdToken,
  getStoredGoogleIdToken,
  clearStoredGoogleIdToken,
  GOOGLE_CLIENT_ID,
} from './google';
import {
  ADMIN_EMAIL,
  fetchNewsList,
  fetchNewsPost,
  formatNewsDate,
  formatRelativeTime,
  getAdminToken,
  NEWS_CATEGORIES,
  NEWS_SHARE_BASE,
  NewsComment,
  NewsPost,
  newsAvatarUrl,
  postComment,
  setAdminToken,
  subscribeNews,
  toggleLike,
} from './news';
import { LICENSE_TOTAL } from './license-total';

// Inventaris lisensi berisi 490 entri dan besarnya puluhan kilobyte. Halaman
// depan tidak butuh itu, jadi berkasnya baru diunduh saat halaman Legal
// dibuka.
const LicenseInventory = lazy(() => import('./LicenseInventory'));
import { HostMeta, InputCodec, RtcPhase, RtcSession } from './rtc';
import type { SessionStats } from './rtc';
import {
  APP_VERSION,
  CHANGELOG_SLUG,
  DOWNLOAD_DISABLED_REASON,
  DOWNLOAD_ENABLED,
  RELEASE_STAGE,
  STAGE_LABEL,
} from './version';
import { vkFromCode } from './vk';
import BillingPage from './Billing';
import { VirtualKeyboard, GamingPad, SessionPanel, SessionRail, DEFAULT_PREFS, fmtDurasi, useElapsedSec } from './session_ui';
import type { SessionPrefs } from './session_ui';
import { QrScanModal, ConnectGuide, SupportLinks } from './connect_extras';
import { WhatsAppIcon, TelegramIcon, XIcon, FacebookIcon } from './brand-icons';

type StaticRoute = '/' | '/connect' | '/download' | '/legal' | '/news' | '/billing';
type Route = StaticRoute | NewsDetailRoute;
interface NewsDetailRoute {
  page: 'news-detail';
  slug: string;
}
type AuthStep = 'closed' | 'login' | 'otp';

// Blok gambar di badan berita: baris sendiri berbentuk
// ![keterangan](https://app.xystudio.my.id/news/shots/....jpg).
// Hanya gambar dari domain sendiri yang dirender — sesuai docs/NEWS_STYLE.md;
// baris lain tetap tampil sebagai paragraf biasa.
const NEWS_IMAGE_BLOCK = /^!\[([^\]]*)\]\((https:\/\/app\.xystudio\.my\.id\/[^\s)]+)\)$/;

const TOKEN_KEY = 'xydesk.web.jwt';const GUEST_TOKEN_KEY = 'xydesk.web.guestJwt';
/// Batas sesi tamu: token signaling tamu terbit 2 jam (authstore.js) —
/// dipakai untuk menampilkan sisa waktu di layar sesi.
const GUEST_SESI_DETIK = 2 * 60 * 60;
const LAST_HOST_KEY = 'xydesk.web.lastHost';
const RELEASE_BASE =
  'https://github.com/xykalnotkel/XyDesk/releases/latest/download';
const WHATSAPP_CHANNEL =
  'https://whatsapp.com/channel/0029VbB7nwuJZg3ym6UQ4Z1L';

const downloads = [
  {
    platform: 'Android',
    architecture: 'ARM64',
    file: 'XyDesk-Android-arm64-v8a.apk',
    note: 'Rekomendasi untuk hampir semua HP modern',
  },
  {
    platform: 'Android',
    architecture: 'ARMv7 32-bit',
    file: 'XyDesk-Android-armeabi-v7a.apk',
    note: 'Untuk perangkat Android lama',
  },
  {
    platform: 'Windows',
    architecture: 'x64',
    file: 'XyDesk-x64.exe',
    note: 'Aplikasi terpadu Connect + Host untuk Intel atau AMD',
  },
  {
    platform: 'Windows',
    architecture: 'Arm64',
    file: 'XyDesk-arm64.exe',
    note: 'Aplikasi terpadu Connect + Host untuk Windows on Arm',
  },
] as const;

function routePath(r: Route): string {
  if (typeof r === 'string') return r;
  return `/news/${r.slug}`;
}

function currentRoute(): Route {
  const path = window.location.pathname.replace(/\/$/, '') || '/';
  if (path.startsWith('/news/')) {
    const slug = decodeURIComponent(path.slice('/news/'.length));
    if (slug) return { page: 'news-detail', slug };
    return '/news';
  }
  switch (path) {
    case '/connect':
      return '/connect';
    case '/download':
      return '/download';
    case '/legal':
      return '/legal';
    case '/news':
      return '/news';
    case '/billing':
      return '/billing';
    default:
      return '/';
  }
}

function useRoute(): [Route, (r: Route) => void] {
  const [route, setRoute] = useState<Route>(currentRoute);
  useEffect(() => {
    const onChange = () => {
      setRoute(currentRoute());
      window.scrollTo(0, 0);
    };
    window.addEventListener('popstate', onChange);
    return () => window.removeEventListener('popstate', onChange);
  }, []);
  const navigate = useCallback((r: Route) => {
    window.history.pushState({}, '', routePath(r));
    setRoute(r);
    window.scrollTo(0, 0);
  }, []);
  return [route, navigate];
}

export default function App() {
  const [route, navigate] = useRoute();
  const isConnect = route === '/connect';

  if (isConnect) {
    return (
      <>
        <SiteHeader route={route} navigate={navigate} bare />
        <RemoteApp />
      </>
    );
  }

  let page: React.ReactNode;
  if (route === '/download') page = <DownloadPage />;
  else if (route === '/legal') page = <LegalPage />;
  else if (route === '/billing') page = <BillingPage />;
  else if (route === '/news') page = <NewsPage navigate={navigate} />;
  else if (typeof route === 'object' && route.page === 'news-detail')
    page = <NewsDetailPage slug={route.slug} navigate={navigate} />;
  else page = <LandingPage navigate={navigate} />;

  return (
    <div className="site">
      <SiteHeader route={route} navigate={navigate} />
      {page}
      <SiteFooter navigate={navigate} />
    </div>
  );
}

function Logo({ size = 30 }: { size?: number }) {
  return (
    <img src="/logo.png" alt="XyDesk" width={size} height={size} aria-hidden="true" />
  );
}

function SiteHeader({
  route,
  navigate,
  bare = false,
}: {
  route: Route;
  navigate: (r: Route) => void;
  bare?: boolean;
}) {
  const current = typeof route === 'string' ? route : '/news';
  // Di layar sempit menu atas disembunyikan (lihat style.css). Dulu tidak ada
  // penggantinya, jadi pengunjung HP tidak bisa mencapai Berita dan Unduh
  // sama sekali. Panel ini menggantikannya.
  const [menuOpen, setMenuOpen] = useState(false);

  // Tutup menu setiap halaman berganti, atau pengguna menekan Escape.
  useEffect(() => {
    setMenuOpen(false);
  }, [route]);

  useEffect(() => {
    if (!menuOpen) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setMenuOpen(false);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [menuOpen]);

  const go = (r: Route) => {
    setMenuOpen(false);
    navigate(r);
  };

  return (
    <header className={bare ? 'site-header bare' : 'site-header'}>
      <button className="brand" onClick={() => navigate('/')} aria-label="Beranda XyDesk">
        <Logo />
        <strong>XyDesk</strong>
      </button>
      {!bare && (
        <nav className="top-nav">
          <button className={current === '/' ? 'active' : ''} onClick={() => navigate('/')}>
            Beranda
          </button>
          <button className={current === '/news' ? 'active' : ''} onClick={() => navigate('/news')}>
            Berita
          </button>
          <button className={current === '/billing' ? 'active' : ''} onClick={() => navigate('/billing')}>
            Sewa PC
          </button>
          <button className={current === '/download' ? 'active' : ''} onClick={() => navigate('/download')}>
            Unduh
          </button>
        </nav>
      )}
      <div className="header-actions">
        {!bare && (
          <button className="btn ghost desktop-only" onClick={() => navigate('/connect')}>
            Connect Web
          </button>
        )}
        {DOWNLOAD_ENABLED ? (
          <a className="btn primary" href={`${RELEASE_BASE}/XyDesk-x64.exe`}>
            Unduh Windows
          </a>
        ) : (
          <button
            className="btn primary"
            disabled
            title={DOWNLOAD_DISABLED_REASON}
          >
            {STAGE_LABEL[RELEASE_STAGE]}
          </button>
        )}
        {!bare && (
          <button
            className="nav-toggle"
            aria-label={menuOpen ? 'Tutup menu' : 'Buka menu'}
            aria-expanded={menuOpen}
            aria-controls="mobile-nav"
            onClick={() => setMenuOpen((o) => !o)}
          >
            {menuOpen ? (
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden="true">
                <path d="M6 6l12 12M18 6L6 18" />
              </svg>
            ) : (
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden="true">
                <path d="M4 7h16M4 12h16M4 17h16" />
              </svg>
            )}
          </button>
        )}
      </div>

      {menuOpen && !bare && (
        <>
          <div className="nav-backdrop" onClick={() => setMenuOpen(false)} aria-hidden="true" />
          <nav id="mobile-nav" className="mobile-nav">
            <button className={current === '/' ? 'active' : ''} onClick={() => go('/')}>
              Beranda
            </button>
            <button className={current === '/news' ? 'active' : ''} onClick={() => go('/news')}>
              Berita
            </button>
            <button className={current === '/billing' ? 'active' : ''} onClick={() => go('/billing')}>
              Sewa PC
            </button>
            <button className={current === '/download' ? 'active' : ''} onClick={() => go('/download')}>
              Unduh
            </button>
            <button onClick={() => go('/connect')}>Connect Web</button>
          </nav>
        </>
      )}
    </header>
  );
}

function LandingPage({ navigate }: { navigate: (r: Route) => void }) {
  // Tombol hero saat unduhan ditutup membuka popup "Ingatkan saya"
  // (email / saluran resmi), bukan sekadar membawa ke halaman unduhan.
  const [remindOpen, setRemindOpen] = useState(false);
  const [latest, setLatest] = useState<NewsPost[]>([]);

  useEffect(() => {
    fetchNewsList('semua', 3)
      .then((r) => setLatest(r.posts))
      .catch(() => {});
  }, []);

  return (
    <main className="landing">
      {/* ── Hero ── */}
      <section className="hero">
        <div className="hero-copy">
          <span className="hero-eyebrow">
            <span className="dot" /> Remote desktop low-latency
          </span>
          <h1>
            PC kamu, di
            <span className="grad"> genggaman</span>.
          </h1>
          <p>
            Akses layar PC dari HP atau browser, nyaris tanpa jeda di jaringan
            lokal. Buat kerja atau main game — koneksinya langsung antar
            perangkatmu, tanpa server perantara yang ikut melihat sesimu.
          </p>
          <div className="hero-cta">
            <button
              className="btn primary big"
              onClick={() => (DOWNLOAD_ENABLED ? navigate('/download') : setRemindOpen(true))}
            >
              {DOWNLOAD_ENABLED ? 'Unduh sekarang' : 'Ingatkan saya'}
            </button>
            <button className="btn ghost big" onClick={() => navigate('/connect')}>
              Coba dari browser
            </button>
          </div>
          <p className="hero-note">
            {DOWNLOAD_ENABLED
              ? 'Gratis. Media sesi peer-to-peer, tidak lewat server kami.'
              : `v${APP_VERSION} · ${STAGE_LABEL[RELEASE_STAGE]} — belum bisa diunduh.`}
          </p>
        </div>
        <div className="hero-art" aria-hidden="true">
          <div className="hero-glow" />
          <img className="hero-logo" src="/logo.png" alt="" />
        </div>
      </section>

      {/* ── Stats ── */}
      <section className="stats-strip">
        <div className="stat">
          <strong>&lt; 40 ms</strong>
          <span>target latency LAN</span>
        </div>
        <div className="stat">
          <strong>P2P</strong>
          <span>media tidak lewat server</span>
        </div>
        <div className="stat">
          <strong>NVENC</strong>
          <span>encode hardware GPU</span>
        </div>
        <div className="stat">
          <strong>Rp 0</strong>
          <span>tanpa langganan</span>
        </div>
      </section>

      {/* ── Fitur ── */}
      <section className="features">
        <h2>Dibangun untuk terasa lokal</h2>
        <div className="feature-grid">
          <FeatureCard index="01" title="Main game langsung dari HP">
            WASD, tombol yang bisa ditahan, keyboard lengkap, dan trackpad —
            semua kontrol PC ada di layar HP tanpa menutupi jalannya game.
          </FeatureCard>
          <FeatureCard index="02" title="Koneksi pribadi dan aman">
            Masuk pakai ID dan password dari PC-mu sendiri. Gambar dan suara
            mengalir langsung antar perangkat, tidak mampir ke server kami.
          </FeatureCard>
          <FeatureCard index="03" title="Gambar mulus, jaringan hemat">
            Encoding pakai hardware GPU bila ada, dan bitrate menyesuaikan
            supaya Wi-Fi rumah tetap lega untuk perangkat lain.
          </FeatureCard>
          <FeatureCard index="04" title="Langsung dari browser">
            Tidak sempat pasang aplikasi? Buka halaman Connect, masukkan ID,
            dan PC-mu tampil di tab browser — HP maupun laptop.
          </FeatureCard>
        </div>
      </section>

      {/* ── Berita ── */}
      {latest.length > 0 && (
        <section className="home-news">
          <div className="section-head">
            <h2>Berita terbaru</h2>
            <button className="text-link" onClick={() => navigate('/news')}>
              Lihat semua →
            </button>
          </div>
          <div className="news-grid">
            {latest.map((p) => (
              <NewsCard
                key={p.slug}
                post={p}
                onOpen={() => navigate({ page: 'news-detail', slug: p.slug })}
              />
            ))}
          </div>
        </section>
      )}

      {/* ── Unduh ── */}
      <section className="download-cta">
        <h2>{DOWNLOAD_ENABLED ? 'Mulai dari perangkatmu' : 'Segera di perangkatmu'}</h2>
        <PlatformTables compact />
        {DOWNLOAD_ENABLED ? (
          <a className="btn primary big" href={`${RELEASE_BASE}/XyDesk-Android-arm64-v8a.apk`}>
            Unduh untuk Android
          </a>
        ) : (
          <NotifyMeForm />
        )}
      </section>
      {remindOpen && <RemindMeModal onClose={() => setRemindOpen(false)} />}
    </main>
  );
}

function FeatureCard({
  index,
  title,
  children,
}: {
  index: string;
  title: string;
  children: string;
}) {
  return (
    <div className="feature-card">
      <span className="feature-index">{index}</span>
      <h3>{title}</h3>
      <p>{children}</p>
    </div>
  );
}

function PlatformIcon({ platform }: { platform: 'android' | 'windows' }) {
  return (
    <img
      src={platform === 'android' ? '/platform-android.svg' : '/platform-windows.svg'}
      alt=""
      width="20"
      height="20"
    />
  );
}

function useRecommendedDownload() {
  const [recommended, setRecommended] = useState(initialDevicePackage);
  useEffect(() => {
    void detectDevicePackage().then(setRecommended);
  }, []);
  return recommended;
}

function PlatformTables({ compact = false }: { compact?: boolean }) {
  const android = downloads.filter((item) => item.platform === 'Android');
  const windows = downloads.filter((item) => item.platform !== 'Android');
  const table = (
    title: string,
    icon: 'android' | 'windows',
    items: readonly (typeof downloads)[number][],
  ) => (
    <section className="platform-table">
      <div className="platform-table-head">
        <PlatformIcon platform={icon} />
        <h2>{title}</h2>
      </div>
      <div className="platform-table-body">
        {items.map((item) => (
          <div className="platform-table-row" key={item.file}>
            <div>
              <strong>{item.architecture}</strong>
              {!compact && <span>{item.note}</span>}
            </div>
            {DOWNLOAD_ENABLED ? (
              <a href={`${RELEASE_BASE}/${item.file}`}>Download</a>
            ) : (
              <span className="soon-chip" title={DOWNLOAD_DISABLED_REASON}>
                Segera
              </span>
            )}
          </div>
        ))}
      </div>
    </section>
  );
  return (
    <div className={compact ? 'platform-tables compact' : 'platform-tables'}>
      {table('Android', 'android', android)}
      {table('Windows', 'windows', windows)}
    </div>
  );
}

/**
 * "Ingatkan saya" — pengganti tombol unduh selama unduhan ditahan.
 *
 * Kenapa bukan tombol unduh yang dinonaktifkan saja: tombol mati hanya
 * menghentikan orang, dan orang yang berhenti tidak pernah kembali. Form ini
 * menangkap niatnya — alamat email disimpan berlabel 'unduhan', sehingga
 * kelak ia bisa dikabari satu kali saat unduhan benar-benar dibuka.
 *
 * Email tidak dikirim ke mana pun hari ini. Ia disimpan, dan hanya dipakai
 * untuk satu kabar itu (lihat news/migrations/0003).
 */
function NotifyMeForm() {
  const inputId = useId();
  const [email, setEmail] = useState('');
  const [status, setStatus] = useState<'idle' | 'sending' | 'done' | 'error'>('idle');
  const [note, setNote] = useState('');

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (status === 'sending') return;
    const value = email.trim();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(value)) {
      setStatus('error');
      setNote('Alamat emailnya belum benar. Periksa lagi ya.');
      return;
    }
    setStatus('sending');
    setNote('');
    try {
      const r = await subscribeNews(value, 'unduhan');
      if (!r.ok) throw new Error('ditolak server');
      setStatus('done');
      if (r.subscribed === false) setNote('Email kamu sudah pernah terdaftar — kami tetap ingat.');
    } catch {
      setStatus('error');
      setNote('Gagal menyimpan email kamu. Coba lagi sebentar.');
    }
  };

  if (status === 'done') {
    return (
      <div className="notify-me done">
        <p className="notify-title">
          <strong>Siap.</strong> Kami kabari {email} begitu unduhan dibuka.
        </p>
        {note && <p className="notify-note">{note}</p>}
        <a className="notify-alt" href={WHATSAPP_CHANNEL} target="_blank" rel="noreferrer">
          Mau lebih cepat? Ikuti saluran WhatsApp kami
        </a>
      </div>
    );
  }

  return (
    <form className={`notify-me${status === 'error' ? ' invalid' : ''}`} onSubmit={submit} noValidate>
      <label htmlFor={inputId}>Ingatkan saya saat unduhan dibuka</label>
      <div className="notify-row">
        <input
          id={inputId}
          type="email"
          inputMode="email"
          autoComplete="email"
          placeholder="nama@email.com"
          value={email}
          onChange={(e) => {
            setEmail(e.target.value);
            if (status === 'error') {
              setStatus('idle');
              setNote('');
            }
          }}
          aria-invalid={status === 'error'}
          aria-describedby={note ? `${inputId}-note` : undefined}
        />
        <button className="btn primary" type="submit" disabled={status === 'sending'}>
          {status === 'sending' ? 'Menyimpan…' : 'Ingatkan saya'}
        </button>
      </div>
      {note && (
        <p className="notify-note error" id={`${inputId}-note`} role="alert">
          {note}
        </p>
      )}
      <a className="notify-alt" href={WHATSAPP_CHANNEL} target="_blank" rel="noreferrer">
        Atau pantau lewat saluran WhatsApp kami
      </a>
    </form>
  );
}

/// Popup "Ingatkan saya" dari tombol hero beranda — menangkap niat
/// pengunjung sebelum mereka pergi: kabar rilis ke email (disimpan
/// berlabel 'unduhan', sama dengan form di halaman unduhan) atau ikut
/// saluran resmi. Status rilis dijelaskan terbuka, bukan disembunyikan.
function RemindMeModal({ onClose }: { onClose: () => void }) {
  const inputId = useId();
  const [email, setEmail] = useState('');
  const [status, setStatus] = useState<'idle' | 'sending' | 'done' | 'error'>('idle');
  const [note, setNote] = useState('');

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (status === 'sending') return;
    const value = email.trim();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(value)) {
      setStatus('error');
      setNote('Alamat emailnya belum benar. Periksa lagi ya.');
      return;
    }
    setStatus('sending');
    setNote('');
    try {
      const r = await subscribeNews(value, 'unduhan');
      if (!r.ok) throw new Error('ditolak server');
      setStatus('done');
      if (r.subscribed === false) setNote('Email kamu sudah pernah terdaftar — kami tetap ingat.');
    } catch {
      setStatus('error');
      setNote('Gagal menyimpan email kamu. Coba lagi sebentar.');
    }
  };

  return (
    <div
      className="remind-modal"
      role="dialog"
      aria-modal="true"
      aria-label="Ingatkan saya saat rilis"
      onClick={onClose}
    >
      <div className="remind-box" onClick={(e) => e.stopPropagation()}>
        <header className="remind-head">
          <strong>Ingatkan saya saat rilis</strong>
          <button type="button" className="remind-close" onClick={onClose} aria-label="Tutup">
            ✕
          </button>
        </header>
        <p className="remind-sub">
          Unduhan belum dibuka — {STAGE_LABEL[RELEASE_STAGE]}. Mau kabar rilisnya dikirim ke mana?
        </p>
        {status === 'done' ? (
          <div className="remind-done">
            <p>
              <strong>Siap.</strong> Kami kabari {email} begitu unduhan dibuka.
            </p>
            {note && <p className="remind-note">{note}</p>}
          </div>
        ) : (
          <form className={`remind-form${status === 'error' ? ' invalid' : ''}`} onSubmit={submit} noValidate>
            <input
              id={inputId}
              type="email"
              inputMode="email"
              autoComplete="email"
              placeholder="nama@email.com"
              value={email}
              onChange={(e) => {
                setEmail(e.target.value);
                if (status === 'error') {
                  setStatus('idle');
                  setNote('');
                }
              }}
              aria-invalid={status === 'error'}
              aria-describedby={note ? `${inputId}-note` : undefined}
            />
            <button className="btn primary" type="submit" disabled={status === 'sending'}>
              {status === 'sending' ? 'Menyimpan…' : 'Kirim ke email'}
            </button>
            {note && (
              <p className="remind-note error" id={`${inputId}-note`} role="alert">
                {note}
              </p>
            )}
          </form>
        )}
        <div className="remind-sep"><span>atau ikuti saluran resmi</span></div>
        <div className="remind-channels">
          <a href={WHATSAPP_CHANNEL} target="_blank" rel="noreferrer">
            <WhatsAppIcon size={18} /> Saluran WhatsApp
          </a>
          <a href="https://t.me/xydesk" target="_blank" rel="noreferrer">
            <TelegramIcon size={18} /> Telegram
          </a>
        </div>
        <p className="remind-foot">Email hanya dipakai untuk kabar rilis — tidak untuk yang lain.</p>
      </div>
    </div>
  );
}

function DownloadPage() {
  const recommended = useRecommendedDownload();

  // Pra-beta: halaman ini berhenti menjual dan mulai menjelaskan. Tidak ada
  // tombol yang menjanjikan file yang belum layak dipasang siapa pun.
  if (!DOWNLOAD_ENABLED) {
    return (
      <main className="content-page download-page">
        <p className="eyebrow">STATUS RILIS</p>
        <h1>Belum bisa diunduh dulu.</h1>
        <p className="page-lead">{DOWNLOAD_DISABLED_REASON}</p>
        <div className="stage-card">
          <div className="stage-row">
            <span>Versi saat ini</span>
            <strong>v{APP_VERSION}</strong>
          </div>
          <div className="stage-row">
            <span>Tahap</span>
            <strong>{STAGE_LABEL[RELEASE_STAGE]}</strong>
          </div>
          <div className="stage-row">
            <span>File unduhan</span>
            <strong>Belum dibuka</strong>
          </div>
        </div>
        <h2 className="stage-heading">Yang harus beres dulu</h2>
        <ul className="stage-list">
          <li>Suara PC benar-benar terdengar di HP, dan mikrofon HP terdengar di PC.</li>
          <li>Ganti monitor saat sesi berjalan, diuji di komputer sungguhan.</li>
          <li>Tombol kontrol, mouse, dan keyboard dari HP terbukti menggerakkan PC.</li>
          <li>Jeda gambar diukur di internet biasa, bukan cuma di jaringan lokal.</li>
          <li>Pemberitahuan benar-benar sampai dan bisa dibuka di HP.</li>
        </ul>
        <p className="page-lead">
          Setiap poin di atas kami tulis kemajuannya di halaman berita. Kamu bisa
          ikuti tanpa perlu memasang apa pun.
        </p>
        <button
          className="btn primary big centered"
          onClick={() => (window.location.href = '/news')}
        >
          Lihat kabar terbaru
        </button>
        <NotifyMeForm />
        <a className="channel-link" href={WHATSAPP_CHANNEL} target="_blank" rel="noreferrer">
          Mau dikabari saat sudah bisa diunduh? Ikuti saluran WhatsApp kami
        </a>
      </main>
    );
  }

  return (
    <main className="content-page download-page">
      <p className="eyebrow">DOWNLOAD CENTER</p>
      <h1>Pilih paket yang tepat.</h1>
      <p className="page-lead">
        Deteksi otomatis merekomendasikan {recommended.label}. Semua file di bawah
        terhubung langsung ke GitHub Release terbaru dan dilindungi SHA-256.
      </p>
      {recommended.file ? (
        <a className="btn primary big centered" href={`${RELEASE_BASE}/${recommended.file}`}>
          <PlatformIcon platform={recommended.platform === 'windows' ? 'windows' : 'android'} />
          Download For {recommended.platform === 'windows' ? 'Windows' : 'Android'}
        </a>
      ) : (
        <a className="btn primary big centered" href="/connect">
          Buka XyDesk Web
        </a>
      )}
      <div className="abi-switcher" aria-label="Pilih arsitektur Android manual">
        <span>Android ABI:</span>
        <button onClick={() => {
          localStorage.setItem('xydesk.download.arch', 'android-arm64');
          window.location.reload();
        }}>ARM64</button>
        <button onClick={() => {
          localStorage.setItem('xydesk.download.arch', 'android-armv7');
          window.location.reload();
        }}>ARMv7 32-bit</button>
        <button onClick={() => {
          localStorage.removeItem('xydesk.download.arch');
          window.location.reload();
        }}>Deteksi ulang</button>
      </div>
      <PlatformTables />
      <a className="channel-link" href={WHATSAPP_CHANNEL} target="_blank" rel="noreferrer">
        Ikuti info rilis di saluran WhatsApp
      </a>
    </main>
  );
}

function LegalPage() {
  return (
    <main className="content-page prose-page">
      <p className="eyebrow">LEGAL & PRIVASI</p>
      <h1>Kendali tetap milik kamu.</h1>
      <p className="lede">
        Berlaku sejak 1 September 2026. XyDesk dibuat oleh XySpace Tech, Indonesia.
        Versi lengkap Syarat &amp; Ketentuan dan Kebijakan Privasi juga ada di dalam
        aplikasi, lewat Akun → Tentang → Legal.
      </p>

      <section>
        <h2>Status layanan</h2>
        <p>
          XyDesk masih pra-beta. Unduhan publik ditutup, sebagian fitur belum jalan,
          dan sesi bisa berubah perilakunya tanpa pemberitahuan. Jangan jadikan XyDesk
          satu-satunya jalan masuk ke komputer yang kamu butuhkan untuk kerja penting.
        </p>
      </section>

      <section>
        <h2>Privasi sesi</h2>
        <p>
          Signaling hanya mempertemukan perangkat. Media WebRTC memakai DTLS-SRTP dan
          tidak disimpan oleh layanan XyDesk. Password pairing diverifikasi di sisi Host
          dan tidak pernah dikirim ke server kami.
        </p>
      </section>

      <section>
        <h2>Data yang kami simpan</h2>
        <ul>
          <li>Email, dan nama serta foto profil kalau kamu masuk lewat Google.</li>
          <li>ID perangkat, nama perangkat, dan sistem operasinya.</li>
          <li>Metadata sesi: waktu, durasi, jalur langsung atau relay, bitrate, ping.</li>
          <li>Token notifikasi, kalau kamu mengizinkan notifikasi.</li>
          <li>Sidik jari acak browser untuk suka dan komentar berita.</li>
          <li>Log server standar: alamat IP, waktu akses, jenis permintaan.</li>
        </ul>
        <p>
          Yang tidak pernah kami simpan: isi layar, ketikan, gerakan mouse, audio,
          berkas yang kamu transfer, dan isi papan klip.
        </p>
      </section>

      <section>
        <h2>Data akun</h2>
        <p>
          Login email memakai kode sekali pakai. Kodenya disimpan sebagai hash dan punya
          batas waktu serta batas percobaan. Sesi tamu berumur pendek dan tidak menyimpan
          identitas pengguna.
        </p>
      </section>

      <section>
        <h2>Layanan pihak ketiga</h2>
        <p>
          Supabase untuk akun dan basis data, Cloudflare untuk jaringan dan situs,
          OneSignal untuk notifikasi, Google Sign-In untuk pilihan masuk, dan GitHub
          sebagai tempat berkas pemasangan diunduh. Karena penyedia ini beroperasi lintas
          negara, datamu bisa diproses di luar Indonesia. Kami tidak menjual data dan
          tidak memasang pelacak iklan.
        </p>
      </section>

      <section>
        <h2>Berapa lama disimpan</h2>
        <ul>
          <li>Metadata sesi: 90 hari.</li>
          <li>Log server: 30 hari.</li>
          <li>Catatan audit keamanan: 1 tahun.</li>
          <li>Data akun: selama akunmu aktif, lalu hilang 30 hari setelah dihapus.</li>
        </ul>
      </section>

      <section>
        <h2>Hak kamu</h2>
        <p>
          Sesuai UU Nomor 27 Tahun 2022 tentang Pelindungan Data Pribadi, kamu berhak
          melihat, memperbaiki, mengunduh, membatasi, dan menghapus datamu, serta menarik
          persetujuan. Kirim ke <strong>privacy@xydesk.app</strong>, dijawab paling lama
          14 hari kerja.
        </p>
      </section>

      <section>
        <h2>Tanggung jawab penggunaan</h2>
        <p>
          Gunakan XyDesk hanya pada perangkat yang kamu miliki atau yang jelas memberi
          izin. Jangan memakai layanan untuk mengambil alih, mengganggu, atau mengakses
          data pihak lain tanpa hak. Layanan resmi tidak pernah meminta kamu memasang
          aplikasi remote desktop lalu menyebutkan ID dan password — kalau ada yang
          meminta begitu, itu penipuan.
        </p>
      </section>

      <section>
        <h2>Hukum dan sengketa</h2>
        <p>
          Ketentuan ini tunduk pada hukum Republik Indonesia. Perselisihan diselesaikan
          lebih dulu secara musyawarah lewat <strong>legal@xydesk.app</strong>. Bila tidak
          selesai dalam 30 hari, perkara dibawa ke pengadilan yang berwenang di Indonesia.
        </p>
      </section>

      <section>
        <h2>Lisensi proyek</h2>
        <p>
          XyDesk adalah perangkat lunak <strong>proprietary (bukan sumber terbuka)</strong>.
          Kamu bebas memakai aplikasinya, tetapi dilarang meng-clone, menyalin,
          merekayasa balik, atau mendistribusikan ulang kode sumbernya tanpa izin
          tertulis dari XySpace Tech. Teks lengkap Perjanjian Lisensi ada di dokumen
          lisensi proyek dan di Pengaturan → Legal di aplikasi Android/Desktop.
        </p>
      </section>

      <section>
        <h2>Lisensi pihak ketiga</h2>
        <p>
          Seluruh UI/UX XyDesk dirancang sendiri oleh tim. Di bawah ini adalah
          inventaris <strong>lengkap</strong> komponen pihak ketiga yang ikut
          terkirim bersama aplikasi — {LICENSE_TOTAL} komponen, dihasilkan
          otomatis dari lockfile dan teks lisensi paket yang benar-benar
          terpasang, bukan daftar yang diketik tangan.
        </p>
        <Suspense fallback={<p className="muted">Memuat daftar lisensi…</p>}>
          <LicenseInventory />
        </Suspense>
      </section>
    </main>
  );
}

/// Nama penulis dengan badge resmi XyDesk.
///
/// Badge ini melekat pada identitas, jadi ia harus punya arti tunggal:
/// "tulisan ini datang dari tim". Karena itu ia HANYA dirender saat server
/// menandai `official` — nilai yang berasal dari ADMIN_TOKEN, bukan dari
/// nama yang diketik. Nama tim juga dikunci di sisi worker, sehingga tidak
/// ada komentar publik yang bisa tampil sebagai "Haekal Saputra" tanpa badge
/// dan menipu pembaca yang sekilas.
function AuthorName({
  name,
  official,
  size = 'sm',
  avatar = true,
}: {
  name: string;
  official?: boolean;
  size?: 'sm' | 'md';
  /// Foto founder menempel di byline artikel, tapi JANGAN di komentar —
  /// kepala komentar sudah punya avatar sendiri; kalau keduanya jalan,
  /// komentar resmi tampil dengan foto yang sama dua kali.
  avatar?: boolean;
}) {
  if (!official) return <span className="author-name">{name}</span>;
  return (
    <span className={`author-name official ${size}`}>
      {avatar && <img className="author-badge" src="/team/founder.jpg" alt="" aria-hidden="true" />}
      <strong>{name}</strong>
      <span className="official-tag" title="Akun resmi XySpace — Haekal Saputra">
        XySpace
      </span>
    </span>
  );
}

function NewsCard({
  post,
  onOpen,
}: {
  post: NewsPost;
  onOpen: () => void;
}) {
  return (
    <article className="news-card" onClick={onOpen}>
      <div className="news-card-cover">
        <img src={post.cover} alt="" loading="lazy" />
        <span className="news-cat">{post.category}</span>
      </div>
      <div className="news-card-body">
        <h3>{post.title}</h3>
        <p>{post.excerpt}</p>
        <div className="news-card-meta">
          <span>{formatNewsDate(post.createdAt)}</span>
          <span>
            ♥ {post.likeCount} · 💬 {post.commentCount}
          </span>
        </div>
      </div>
    </article>
  );
}

function NewsPage({ navigate }: { navigate: (r: Route) => void }) {
  const [category, setCategory] = useState<string>('semua');
  const [posts, setPosts] = useState<NewsPost[] | null>(null);
  const [error, setError] = useState<unknown>(null);
  // `nonce` sengaja: tombol ulang yang memanggil setCategory(nilaiYangSama)
  // tidak pernah menjalankan ulang efeknya, jadi tombolnya percuma.
  const [nonce, reload] = useReload();
  const online = useOnline();

  useEffect(() => {
    let alive = true;
    setPosts(null);
    setError(null);
    fetchNewsList(category)
      .then((r) => {
        if (alive) setPosts(r.posts);
      })
      .catch((e) => {
        if (alive) setError(e);
      });
    return () => {
      alive = false;
    };
  }, [category, nonce]);

  return (
    <main className="content-page news-page">
      <p className="eyebrow">XYDESK NEWS</p>
      <h1>Berita & catatan rilis.</h1>
      <p className="page-lead">
        Pembaruan produk, keputusan teknik, dan angka yang kami ukur sendiri —
        tanpa jargon kosong.
      </p>

      <div className="news-cats">
        {NEWS_CATEGORIES.map((c) => (
          <button
            key={c}
            className={category === c ? 'active' : ''}
            onClick={() => setCategory(c)}
          >
            {c === 'semua' ? 'Semua' : c}
          </button>
        ))}
      </div>

      {error !== null && (
        <StateNotice
          tone={online ? 'error' : 'offline'}
          glyph={online ? 'alert' : 'cloud'}
          title={online ? 'Beritanya belum bisa dimuat' : 'Kamu sedang offline'}
          message={explainError(error, 'Gagal memuat berita.', online)}
          actionLabel="Coba lagi"
          onAction={reload}
        />
      )}

      {!posts && !error && <NewsGridSkeleton />}

      {posts && posts.length === 0 && (
        <StateNotice
          tone="empty"
          glyph="news"
          title={
            category === 'semua'
              ? 'Belum ada berita'
              : `Belum ada berita di kategori ${category}`
          }
          message="Begitu ada kabar baru, ia muncul di sini lebih dulu."
          {...(category === 'semua'
            ? {}
            : { actionLabel: 'Lihat semua berita', onAction: () => setCategory('semua') })}
        />
      )}

      {posts && posts.length > 0 && (
        <div className="news-grid">
          {posts.map((p) => (
            <NewsCard
              key={p.slug}
              post={p}
              onOpen={() => navigate({ page: 'news-detail', slug: p.slug })}
            />
          ))}
        </div>
      )}
    </main>
  );
}

function NewsDetailPage({
  slug,
  navigate,
}: {
  slug: string;
  navigate: (r: Route) => void;
}) {
  const [data, setData] = useState<{ post: NewsPost; comments: NewsComment[] } | null>(null);
  const [error, setError] = useState<unknown>(null);
  const [nonce, reload] = useReload();
  const online = useOnline();
  const [likeCount, setLikeCount] = useState(0);
  const [liked, setLiked] = useState(false);
  const [commentText, setCommentText] = useState('');
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState('');
  const [replyTo, setReplyTo] = useState<NewsComment | null>(null);
  // Mode founder: login Google xycdigital@gmail.com membuka UI-nya;
  // keabsahan badge tetap diputuskan worker dari ADMIN_TOKEN.
  const [adminEligible, setAdminEligible] = useState(false);
  const [adminToken, setAdminTokenState] = useState(getAdminToken);
  const [googleToken, setGoogleToken] = useState<string | null>(getStoredGoogleIdToken);
  // Tombol lompat: panah bawah menuju komentar di dasar artikel; setelah
  // sampai, berubah jadi panah atas untuk kembali ke judul. Artikel
  // changelog bisa panjang — tanpa ini pembaca HP harus menggulir jauh.
  const [diDasar, setDiDasar] = useState(false);
  useEffect(() => {
    const cek = () => {
      const d = document.documentElement;
      setDiDasar(window.innerHeight + window.scrollY >= d.scrollHeight - 90);
    };
    cek();
    window.addEventListener('scroll', cek, { passive: true });
    return () => window.removeEventListener('scroll', cek);
  }, []);
  const [adminDraft, setAdminDraft] = useState('');
  useEffect(() => {
    const jwt = localStorage.getItem('xydesk.web.jwt');
    if (!jwt) return;
    me(jwt)
      .then((r) => setAdminEligible(r.user?.email?.toLowerCase() === ADMIN_EMAIL))
      .catch(() => {});
  }, []);
  // Admin aktif bila founder dan (Google id_token masih berlaku ATAU sudah
  // menempel ADMIN_TOKEN). Google id_token diutamakan saat kirim komentar.
  const adminActive = adminEligible && (googleToken !== null || adminToken !== '');
  // Form komentar ada di BAWAH daftar; saat "Balas" ditekan dari komentar
  // paling atas, gulirkan ke form supaya pengguna tidak mencarinya.
  const commentFormRef = useRef<HTMLDivElement | null>(null);
  const focusCommentForm = (target: NewsComment | null) => {
    setReplyTo(target);
    setNotice('');
    requestAnimationFrame(() => {
      commentFormRef.current?.scrollIntoView({ behavior: 'smooth', block: 'center' });
      commentFormRef.current?.querySelector('textarea')?.focus({ preventScroll: true });
    });
  };
  const [email, setEmail] = useState('');
  const [subBusy, setSubBusy] = useState(false);

  useEffect(() => {
    let alive = true;
    setData(null);
    setError(null);
    fetchNewsPost(slug)
      .then((r) => {
        if (!alive) return;
        setData(r);
        setLikeCount(r.post.likeCount);
        setLiked(r.liked || localStorage.getItem(`xydesk.news.liked.${slug}`) === '1');
      })
      .catch((e) => {
        if (alive) setError(e);
      });
    return () => {
      alive = false;
    };
  }, [slug, nonce]);

  const post = data?.post;

  // Tautan versi di footer menuju `CHANGELOG_SLUG` (mis. changelog-v6-4-0).
  // Kalau rilis lupa menerbitkan artikel dengan slug itu, artikelnya jatuh ke
  // hash acak `p-…` dan halaman ini kena 404. Alih-alih menampilkan pesan
  // galat mentah, tampilkan penjelasan + jalan keluar ke daftar berita.
  const isChangelogMissing =
    slug === CHANGELOG_SLUG && online && error instanceof ApiError && error.status === 404;

  // Like OPTIMISTIK: UI berubah seketika, server menyusul — kalau gagal,
  // kembalikan ke keadaan sebelumnya. Ini membuat like terasa instan.
  const like = () => {
    if (!post || busy) return;
    const target = !liked;
    setLiked(target);
    setLikeCount((n) => n + (target ? 1 : -1));
    toggleLike(post.slug)
      .then((r) => {
        setLiked(r.liked);
        setLikeCount(r.likeCount);
        localStorage.setItem(`xydesk.news.liked.${post.slug}`, r.liked ? '1' : '0');
      })
      .catch((e) => {
        setLiked(!target);
        setLikeCount((n) => n + (target ? -1 : 1));
        setNotice(e instanceof Error ? e.message : 'Gagal memproses like.');
      });
  };

  const submitComment = async () => {
    if (!post || commentText.trim().length < 2 || busy) return;
    setBusy(true);
    setNotice('');
    try {
      // Username acak per perangkat — kecuali mode founder yang terverifikasi
      // server: tampil sebagai Haekal Saputra + badge XySpace.
      // Cek ulang id_token saat kirim (bisa saja kedaluwarsa sejak halaman
      // dibuka); bila masih ada, pakai jalur Google — bila tidak, fallback
      // ke ADMIN_TOKEN yang ditempel. Kalau keduanya kosong, komentar jatuh
      // ke mode publik biasa (nama acak), bukan kredensial kosong.
      const gt = getStoredGoogleIdToken();
      if (gt !== googleToken) setGoogleToken(gt);
      const adminCredential = gt
        ? { googleToken: gt }
        : adminToken
          ? { token: adminToken }
          : undefined;
      const r = await postComment(
        post.slug,
        commentText.trim(),
        replyTo?.id ?? null,
        adminCredential,
      );
      setData((d) =>
        d
          ? { post: { ...d.post, commentCount: d.post.commentCount + 1 }, comments: [...d.comments, r.comment] }
          : d,
      );
      setCommentText('');
      setReplyTo(null);
      setNotice('Komentar terkirim.');
    } catch (e) {
      setNotice(e instanceof Error ? e.message : 'Gagal mengirim komentar.');
    } finally {
      setBusy(false);
    }
  };

  const subscribe = async () => {
    if (!email.includes('@') || subBusy) return;    setSubBusy(true);
    setNotice('');
    try {
      await subscribeNews(email.trim());
      setEmail('');
      setNotice('Berhasil! Email kamu terdaftar untuk berita XyDesk.');
    } catch (e) {
      setNotice(e instanceof Error ? e.message : 'Gagal mendaftar email.');
    } finally {
      setSubBusy(false);
    }
  };

  const shareUrl = post ? `${NEWS_SHARE_BASE}/${post.slug}` : '';

  const share = async () => {
    if (!post) return;
    const dataToShare = { title: post.title, text: post.excerpt, url: shareUrl };
    if (navigator.share) {
      try {
        await navigator.share(dataToShare);
        return;
      } catch {
        /* batal / tidak didukung → tombol manual tetap tersedia */
      }
    }
    try {
      await navigator.clipboard.writeText(shareUrl);
      setNotice('Tautan disalin — tempel ke media sosial.');
    } catch {
      setNotice(shareUrl);
    }
  };

  const socials: { label: string; href: string; Icon: (p: { size?: number }) => ReactElement }[] =
    post
      ? [
          {
            label: 'WhatsApp',
            Icon: WhatsAppIcon,
            href: `https://wa.me/?text=${encodeURIComponent(`${post.title} ${shareUrl}`)}`,
          },
          {
            label: 'Telegram',
            Icon: TelegramIcon,
            href: `https://t.me/share/url?url=${encodeURIComponent(shareUrl)}&text=${encodeURIComponent(post.title)}`,
          },
          {
            label: 'X',
            Icon: XIcon,
            href: `https://twitter.com/intent/tweet?text=${encodeURIComponent(post.title)}&url=${encodeURIComponent(shareUrl)}`,
          },
          {
            label: 'Facebook',
            Icon: FacebookIcon,
            href: `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(shareUrl)}`,
          },
        ]
      : [];

  const comments = data?.comments ?? [];
  const topLevel = comments.filter((c) => c.parentId == null);

  return (
    <main className="content-page news-detail">
      <button className="back-action" onClick={() => navigate('/news')}>
        ← Semua berita
      </button>

      {error !== null && (
        isChangelogMissing ? (
          <StateNotice
            tone="empty"
            glyph="news"
            title="Catatan rilis versi ini belum tersedia"
            message="Artikel changelog untuk versi ini belum diterbitkan di XyDesk News. Kamu tetap bisa membaca berita terbaru dari daftar semua berita."
            actionLabel="Semua berita"
            onAction={() => navigate('/news')}
          />
        ) : (
          <StateNotice
            tone={online ? 'error' : 'offline'}
            glyph={online ? 'alert' : 'cloud'}
            title={online ? 'Berita ini belum bisa dibuka' : 'Kamu sedang offline'}
            message={explainError(error, 'Berita tidak ditemukan.', online)}
            actionLabel="Coba lagi"
            onAction={reload}
          />
        )
      )}

      {!post && !error && (
        <div className="news-detail-skeleton">
          <div className="sk sk-block cover" />
          <div className="sk-line w80 big" />
          <div className="sk-line w100" />
          <div className="sk-line w100" />
          <div className="sk-line w40" />
        </div>
      )}

      {post && (
        <article className="post">
          <div className="post-cover">
            <img src={post.cover} alt="" />
          </div>
          <span className="news-cat">{post.category}</span>
          <h1>{post.title}</h1>
          <div className="post-meta">
            {/* Artikel hanya bisa diterbitkan lewat endpoint admin, jadi
                penulisnya resmi menurut konstruksi. */}
            <AuthorName name={post.author} official size="md" />
            <span>·</span>
            <span>{formatNewsDate(post.createdAt)}</span>
          </div>

          <div className="post-actions">
            <button
              className={`like-btn ${liked ? 'liked' : ''}`}
              onClick={like}
              title={liked ? 'Batal suka' : 'Suka'}
            >
              <svg viewBox="0 0 24 24" width="16" height="16" fill={liked ? 'currentColor' : 'none'} stroke="currentColor" strokeWidth="2">
                <path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7z" />
              </svg>
              {likeCount}
            </button>
            <button className="share-btn" onClick={share}>
              Bagikan
            </button>
            {socials.map(({ label, href, Icon }) => (
              <a
                key={label}
                className="social-chip"
                href={href}
                target="_blank"
                rel="noreferrer"
                title={`Bagikan ke ${label}`}
              >
                <Icon size={15} />
                <span>{label}</span>
              </a>
            ))}
          </div>

          <div className="post-body">
            {post.content.split(/\n\n+/).map((p, i) => {
              const img = NEWS_IMAGE_BLOCK.exec(p.trim());
              if (img) {
                return (
                  <figure key={i}>
                    <img src={img[2]} alt={img[1]} loading="lazy" />
                    {img[1] && <figcaption>{img[1]}</figcaption>}
                  </figure>
                );
              }
              return <p key={i}>{p}</p>;
            })}
          </div>

          <section className="comments">
            <h2>Komentar ({comments.length})</h2>
            <div className="comment-list">
              {comments.length === 0 && (
                <StateNotice
                  tone="empty"
                  glyph="comment"
                  compact
                  title="Belum ada komentar"
                  message="Jadilah yang pertama menanggapi berita ini."
                />
              )}
              {topLevel.map((c) => {
                const replies = comments.filter((r) => r.parentId === c.id);
                return (
                  <div className="comment" key={c.id}>
                    <div className="comment-head">
                      <img
                        className="comment-avatar"
                        src={c.official ? '/team/founder.jpg' : newsAvatarUrl(c.author)}
                        alt=""
                        loading="lazy"
                      />
                      <AuthorName name={c.author} official={c.official} avatar={false} />
                      <span>{formatRelativeTime(c.createdAt)}</span>
                    </div>
                    <p>{c.content}</p>
                    <button className="reply-link" onClick={() => focusCommentForm(c)}>
                      Balas
                    </button>
                    {replies.length > 0 && (
                      <div className="replies">
                        {replies.map((r) => (
                          <div className="reply" key={r.id}>
                            <div className="comment-head">
                              <img
                                className="comment-avatar sm"
                                src={r.official ? '/team/founder.jpg' : newsAvatarUrl(r.author)}
                                alt=""
                                loading="lazy"
                              />
                              <AuthorName name={r.author} official={r.official} avatar={false} />
                              <span>{formatRelativeTime(r.createdAt)}</span>
                            </div>
                            <p>{r.content}</p>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
            <div className="comment-form" ref={commentFormRef}>
              {adminActive && (
                <div className="admin-banner">
                  <img src="/team/founder.jpg" alt="" />
                  <span>
                    Membalas sebagai <strong>Haekal Saputra</strong>
                    <em className="official-tag">XySpace</em>
                  </span>
                  <button
                    type="button"
                    title="Matikan mode tim di perangkat ini"
                    onClick={() => {
                      setAdminToken('');
                      setAdminTokenState('');
                      clearStoredGoogleIdToken();
                      setGoogleToken(null);
                    }}
                  >
                    ×
                  </button>
                </div>
              )}
              {adminEligible && !adminActive && (
                <div className="admin-setup">
                  <p>
                    Login founder terdeteksi. Masuk dengan Google untuk membalas
                    sebagai tim — tanpa token manual:
                  </p>
                  <button
                    type="button"
                    className="btn primary"
                    onClick={() => beginGoogleLogin(window.location.pathname)}
                  >
                    Lanjutkan dengan Google
                  </button>
                  <details className="admin-token-fallback">
                    <summary>Cara lama: tempel ADMIN_TOKEN</summary>
                    <p>Token tersimpan hanya di perangkat ini.</p>
                    <div className="admin-setup-row">
                      <input
                        type="password"
                        placeholder="ADMIN_TOKEN"
                        value={adminDraft}
                        onChange={(e) => setAdminDraft(e.target.value)}
                      />
                      <button
                        type="button"
                        className="btn primary"
                        disabled={!adminDraft.trim()}
                        onClick={() => {
                          setAdminToken(adminDraft);
                          setAdminTokenState(adminDraft.trim());
                          setAdminDraft('');
                        }}
                      >
                        Aktifkan
                      </button>
                    </div>
                  </details>
                </div>
              )}
              {replyTo && (
                <div className="reply-banner">
                  <span>
                    Membalas <AuthorName name={replyTo.author} official={replyTo.official} />
                  </span>
                  <button onClick={() => setReplyTo(null)}>×</button>
                </div>
              )}
              <textarea
                placeholder="Tulis komentar…"
                maxLength={1000}
                rows={3}
                value={commentText}
                onChange={(e) => setCommentText(e.target.value)}
              />
              {notice && <p className="muted">{notice}</p>}
              <button
                className="btn primary"
                disabled={busy || commentText.trim().length < 2}
                onClick={submitComment}
              >
                {busy ? 'Mengirim…' : 'Kirim komentar'}
              </button>
            </div>
          </section>

          <section className="subscribe-box">
            <h2>Berita lewat email</h2>
            <p className="muted">Artikel baru dikirim langsung ke email kamu.</p>
            <div className="subscribe-row">
              <input
                type="email"
                placeholder="alamat@email.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
              <button className="btn primary" onClick={subscribe} disabled={subBusy}>
                {subBusy ? 'Mendaftar…' : 'Langganan'}
              </button>
            </div>
          </section>
        </article>
      )}
      {data && (
        <button
          type="button"
          className="lompat-btn"
          onClick={() =>
            window.scrollTo({
              top: diDasar ? 0 : document.documentElement.scrollHeight,
              behavior: 'smooth',
            })
          }
          title={diDasar ? 'Kembali ke atas' : 'Lompat ke paling bawah'}
          aria-label={diDasar ? 'Kembali ke atas' : 'Lompat ke paling bawah'}
        >
          {diDasar ? (
            <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
              <path d="M12 19V5" />
              <path d="M5 12l7-7 7 7" />
            </svg>
          ) : (
            <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
              <path d="M12 5v14" />
              <path d="M19 12l-7 7-7-7" />
            </svg>
          )}
        </button>
      )}
    </main>
  );
}
function RemoteApp() {
  const [jwt, setJwt] = useState<string | null>(() =>
    localStorage.getItem(TOKEN_KEY) || sessionStorage.getItem(GUEST_TOKEN_KEY),
  );
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [authStep, setAuthStep] = useState<AuthStep>('closed');
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [otp, setOtp] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [editingName, setEditingName] = useState<string | null>(null);

  useEffect(() => {
    if (!jwt || sessionStorage.getItem(GUEST_TOKEN_KEY) === jwt) return;
    me(jwt)
      .then((r) => setProfile(r.user))
      .catch(() => {
        localStorage.removeItem(TOKEN_KEY);
        setJwt(null);
      });
  }, [jwt]);

  // Kembali dari halaman login Google (redirect flow): tukar id_token
  // menjadi sesi XyDesk lalu bersihkan URL. id_token ikut disimpan agar
  // mode founder berita bisa dipakai tanpa menempel ADMIN_TOKEN. Bila login
  // ini dipicu dari halaman berita (returnPath), kembalikan ke sana.
  useEffect(() => {
    const idToken = consumeGoogleRedirect();
    if (idToken) {
      storeGoogleIdToken(idToken);
      void doGoogle(idToken).then(() => {
        const kembali = consumeGoogleReturn();
        if (kembali && kembali !== window.location.pathname) {
          window.history.pushState({}, '', kembali);
          window.dispatchEvent(new PopStateEvent('popstate'));
        }
      });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const finishAuth = (token: string, user?: UserProfile) => {
    sessionStorage.removeItem(GUEST_TOKEN_KEY);
    localStorage.setItem(TOKEN_KEY, token);
    setJwt(token);
    if (user) setProfile(user);
    setAuthStep('closed');
  };

  const ensureToken = useCallback(async () => {
    if (jwt) return jwt;
    const guest = await createGuestSession();
    sessionStorage.setItem(GUEST_TOKEN_KEY, guest.token);
    setJwt(guest.token);
    return guest.token;
  }, [jwt]);

  const doRequestOtp = async () => {
    setBusy(true);
    setError('');
    try {
      await requestOtp(email.trim().toLowerCase(), name.trim());
      setAuthStep('otp');
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Gagal mengirim OTP.');
    } finally {
      setBusy(false);
    }
  };

  const doVerify = async () => {
    setBusy(true);
    setError('');
    try {
      const session = await verifyOtp(email.trim().toLowerCase(), otp.trim());
      finishAuth(session.token, session.user);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'OTP salah.');
    } finally {
      setBusy(false);
    }
  };

  const doGoogle = async (idToken: string) => {
    setBusy(true);
    setError('');
    try {
      const session = await signInWithGoogle(idToken);
      finishAuth(session.token, session.user);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Login Google gagal.');
    } finally {
      setBusy(false);
    }
  };

  const signOut = () => {
    localStorage.removeItem(TOKEN_KEY);
    sessionStorage.removeItem(GUEST_TOKEN_KEY);
    setJwt(null);
    setProfile(null);
  };

  if (authStep !== 'closed') {
    return (
      <AuthPanel
        step={authStep}
        setStep={setAuthStep}
        name={name}
        setName={setName}
        email={email}
        setEmail={setEmail}
        otp={otp}
        setOtp={setOtp}
        busy={busy}
        error={error}
        requestOtp={doRequestOtp}
        verify={doVerify}
      />
    );
  }

  return (
    <main className="connect-page">
      <div className="connect-account-bar">
        {profile ? (
          <div className="account-chip">
            {profile.picture ? (
              <img src={profile.picture} alt="" referrerPolicy="no-referrer" />
            ) : (
              <span className="avatar-fallback">
                {(profile.name || profile.email)[0]?.toUpperCase()}
              </span>
            )}
            <button
              type="button"
              className="account-name"
              title="Klik untuk ganti nama"
              onClick={() => setEditingName(profile.name ?? '')}
            >
              {profile.name || profile.email.split('@')[0]}
            </button>
          </div>
        ) : (
          <span>Mode tamu siap digunakan</span>
        )}
        {profile ? (
          <span className="account-actions">
            <button
              className="text-action danger-text"
              onClick={async () => {
                if (!jwt) return;
                const ok = window.confirm(
                  'Hapus akun XyDesk secara permanen? Tindakan ini tidak bisa dibatalkan.',
                );
                if (!ok) return;
                try {
                  await deleteAccount(jwt);
                  signOut();
                } catch {
                  window.alert('Gagal menghapus akun.');
                }
              }}
            >
              Hapus akun
            </button>
            <button className="text-action" onClick={signOut}>Keluar</button>
          </span>
        ) : (
          <button className="text-action" onClick={() => setAuthStep('login')}>Masuk akun</button>
        )}
      </div>
      <ConnectScreen ensureToken={ensureToken} />
      {editingName !== null && (
        <div className="modal-backdrop" onClick={() => setEditingName(null)}>
          <div className="modal-card" onClick={(e) => e.stopPropagation()}>
            <h2>Ganti nama tampilan</h2>
            <input
              autoFocus
              maxLength={60}
              placeholder="Nama baru"
              value={editingName}
              onChange={(e) => setEditingName(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Escape') setEditingName(null);
                if (e.key === 'Enter' && editingName.trim().length >= 2) {
                  void saveName();
                }
              }}
            />
            <div className="modal-actions">
              <button className="ghost-btn" onClick={() => setEditingName(null)}>
                Batal
              </button>
              <button
                disabled={busy || editingName.trim().length < 2}
                onClick={() => void saveName()}
              >
                {busy ? 'Menyimpan…' : 'Simpan'}
              </button>
            </div>
          </div>
        </div>
      )}
    </main>
  );

  async function saveName() {
    if (!jwt || editingName === null) return;
    setBusy(true);
    try {
      const r = await updateProfileName(jwt, editingName.trim());
      setProfile(r.user);
      setEditingName(null);
    } catch {
      // Biarkan modal terbuka; pengguna bisa coba lagi.
    } finally {
      setBusy(false);
    }
  }
}

interface AuthPanelProps {
  step: AuthStep;
  setStep: (step: AuthStep) => void;
  name: string;
  setName: (value: string) => void;
  email: string;
  setEmail: (value: string) => void;
  otp: string;
  setOtp: (value: string) => void;
  busy: boolean;
  error: string;
  requestOtp: () => void;
  verify: () => void;
}

function AuthPanel(props: AuthPanelProps) {
  return (
    <main className="auth-panel surface-card">
      <button className="back-action" onClick={() => props.setStep('closed')}>Kembali ke mode tamu</button>
      <img src="/logo.png" alt="XyDesk" className="auth-logo" />
      <h1>{props.step === 'otp' ? 'Kode verifikasi' : 'Masuk ke XyDesk'}</h1>
      {props.step === 'login' ? (
        <>
          <GoogleButton />
          <p className="or-label">atau dengan email</p>
          <input placeholder="Nama lengkap" value={props.name} onChange={(e) => props.setName(e.target.value)} />
          <input type="email" placeholder="email@contoh.com" value={props.email} onChange={(e) => props.setEmail(e.target.value)} />
          {props.error && <p className="error">{props.error}</p>}
          <button disabled={props.busy || props.name.trim().length < 2 || !props.email.includes('@')} onClick={props.requestOtp}>
            {props.busy ? 'Mengirim…' : 'Kirim kode OTP'}
          </button>
        </>
      ) : (
        <>
          <p className="muted">Enam digit dikirim ke {props.email}.</p>
          <input inputMode="numeric" maxLength={6} placeholder="000000" value={props.otp} autoFocus onChange={(e) => props.setOtp(e.target.value.replace(/\D/g, ''))} />
          {props.error && <p className="error">{props.error}</p>}
          <button disabled={props.busy || props.otp.length !== 6} onClick={props.verify}>
            {props.busy ? 'Memeriksa…' : 'Masuk'}
          </button>
          <button className="text-action" onClick={() => props.setStep('login')}>Ganti email</button>
        </>
      )}
    </main>
  );
}

function GoogleButton() {
  if (!GOOGLE_CLIENT_ID) return null;
  // Redirect flow: tanpa popup/iframe — aman untuk Safari iOS dan in-app
  // browser yang memblokir popup GIS (gejala "mentok di about:blank").
  return (
    <button type="button" className="google-btn" onClick={() => beginGoogleLogin()}>
      <svg viewBox="0 0 48 48" width="18" height="18" aria-hidden>
        <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z" />
        <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z" />
        <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z" />
        <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z" />
      </svg>
      Lanjutkan dengan Google
    </button>
  );
}

function formatHostId(raw: string): string {
  return raw.replace(/\D/g, '').slice(0, 9).replace(/(\d{3})(?=\d)/g, '$1 ');
}

// ── Riwayat koneksi (maks 5, terbaru di atas) ──
// Hanya ID host yang disimpan, TANPA password. Password pairing adalah
// kunci masuk ke PC seseorang; menyimpannya di localStorage — meski
// di-encode — berarti satu XSS atau satu peramban bersama (urusan nyata
// untuk PC sewaan) cukup untuk membukanya. Klik riwayat mengisi ID dan
// langsung memfokus kolom password.
interface RecentEntry {
  id: string;
  at: number;
}

const RECENTS_KEY = 'xydesk.web.recents';

function loadRecents(): RecentEntry[] {
  try {
    const raw = JSON.parse(localStorage.getItem(RECENTS_KEY) ?? '[]') as Array<
      RecentEntry & { pw?: string }
    >;
    const cleaned = raw
      .map(({ id, at }) => ({ id: String(id ?? '').replace(/\s/g, ''), at: Number(at) || Date.now() }))
      .filter((r) => r.id.length > 0)
      .slice(0, 5);
    // Migrasi satu arah: entri lama yang masih membawa password ditulis
    // ulang tanpanya, jadi sisa masa lalu ikut hilang saat dibaca.
    if (raw.some((r) => typeof r.pw === 'string')) {
      localStorage.setItem(RECENTS_KEY, JSON.stringify(cleaned));
    }
    return cleaned;
  } catch {
    return [];
  }
}

function saveRecent(id: string) {
  const cleaned = id.replace(/\s/g, '');
  if (!cleaned) return;
  const next: RecentEntry[] = [
    { id: cleaned, at: Date.now() },
    ...loadRecents().filter((r) => r.id !== cleaned),
  ].slice(0, 5);
  localStorage.setItem(RECENTS_KEY, JSON.stringify(next));
}

function clearRecents() {
  localStorage.removeItem(RECENTS_KEY);
}

function HistoryIcon() {
  return (
    <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" />
      <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" />
    </svg>
  );
}

function QrIcon() {
  return (
    <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <rect x="3" y="3" width="7" height="7" rx="1" />
      <rect x="14" y="3" width="7" height="7" rx="1" />
      <rect x="3" y="14" width="7" height="7" rx="1" />
      <path d="M14 14h3v3h-3zM21 14v.01M14 21v.01M21 21v.01M17.5 17.5H21" />
    </svg>
  );
}

function EyeIcon() {
  return (
    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7z" />
      <circle cx="12" cy="12" r="3" />
    </svg>
  );
}

function EyeOffIcon() {
  return (
    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M17.94 17.94A10.5 10.5 0 0 1 12 19c-6.5 0-10-7-10-7a19.8 19.8 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c6.5 0 10 7 10 7a19.8 19.8 0 0 1-3.22 4.31" />
      <path d="M14.12 14.12a3 3 0 1 1-4.24-4.24" />
      <path d="M2 2l20 20" />
    </svg>
  );
}

function ConnectScreen({ ensureToken }: { ensureToken: () => Promise<string> }) {
  const [hostId, setHostId] = useState(() => localStorage.getItem(LAST_HOST_KEY) ?? '');
  const [pin, setPin] = useState('');
  const [phase, setPhase] = useState<RtcPhase | ''>('');
  const [recents, setRecents] = useState<RecentEntry[]>(loadRecents);
  const [recentsOpen, setRecentsOpen] = useState(false);
  const [qrOpen, setQrOpen] = useState(false);
  // Pindai QR butuh getUserMedia — sembunyikan tombolnya di browser tanpa
  // API kamera (konteks non-HTTPS / browser tua) daripada memamerkan
  // tombol yang pasti gagal.
  const canScanQr =
    typeof navigator !== 'undefined' && !!navigator.mediaDevices?.getUserMedia;
  const [kbOpen, setKbOpen] = useState(false);
  const [padOpen, setPadOpen] = useState(false);
  const [trackpad, setTrackpad] = useState(false);
  const [panelOpen, setPanelOpen] = useState(false);
  // Password pairing bisa diperlihatkan — sengaja huruf besar semua di sisi
  // host (tanpa I/O/0/1 yang mudah tertukar), jadi lihat-langsung adalah
  // cara tercepat memastikan ketikan sama dengan layar PC.
  const [showPw, setShowPw] = useState(false);
  // Rail kontrol bisa disembunyikan agar tidak menutupi game — pilihan
  // pengguna disimpan supaya konsisten antar sesi (ala aplikasi).
  const [railHidden, setRailHidden] = useState(() => localStorage.getItem('xydesk.session.railHidden') === '1');
  useEffect(() => {
    localStorage.setItem('xydesk.session.railHidden', railHidden ? '1' : '0');
  }, [railHidden]);
  const [stats, setStats] = useState<SessionStats | null>(null);
  const [connectedAt, setConnectedAt] = useState<number | null>(null);
  const [hudToast, setHudToast] = useState('');
  // Sesi tamu berbatas 2 jam (token signaling); pengguna login tidak.
  // Dihitung per render: token tamu baru tersimpan saat connect dimulai.
  const tamu = !localStorage.getItem(TOKEN_KEY) && !!sessionStorage.getItem(GUEST_TOKEN_KEY);
  const totalSesiDetik = tamu ? GUEST_SESI_DETIK : null;
  const durasiDetik = useElapsedSec(phase === 'connected' ? connectedAt : null);
  const sisaDetik =
    totalSesiDetik !== null && durasiDetik !== null
      ? Math.max(0, totalSesiDetik - durasiDetik)
      : null;
  // Preferensi sesi — bertahan antar sesi di perangkat ini.
  const [prefs, setPrefs] = useState<SessionPrefs>(() => {
    try {
      return { ...DEFAULT_PREFS, ...JSON.parse(localStorage.getItem('xydesk.session.prefs') ?? '{}') };
    } catch {
      return DEFAULT_PREFS;
    }
  });
  useEffect(() => {
    prefsRef.current = prefs;
    localStorage.setItem('xydesk.session.prefs', JSON.stringify(prefs));
    if (audioRef.current) audioRef.current.volume = prefs.volume;
  }, [prefs]);
  const [retryInfo, setRetryInfo] = useState('');
  // Jejak jari untuk mode trackpad: posisi terakhir per pointer, penanda
  // "sudah bergerak" (pembeda tap vs geser), dan stempel waktu turun.
  const touchRef = useRef({
    points: new Map<number, { x: number; y: number }>(),
    moved: false,
    downAt: 0,
  });
  // Ref cermin prefs agar handler yang dibuat di closure lama (mis.
  // onAudioTrack) selalu membaca nilai terbaru.
  const prefsRef = useRef(DEFAULT_PREFS as SessionPrefs);
  const sessionRef = useRef<RtcSession | null>(null);
  const retryRef = useRef({ tries: 0, timer: 0 as ReturnType<typeof setTimeout> | 0, wasConnected: false });
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const [audioOn, setAudioOn] = useState(true);
  const [micOn, setMicOn] = useState(false);
  const [hostMeta, setHostMeta] = useState<HostMeta | null>(null);
  const surfaceRef = useRef<HTMLDivElement | null>(null);
  const pinRef = useRef<HTMLInputElement | null>(null);

  const connected = phase === 'connected';
  const canConnect = hostId.replace(/[\s-]/g, '').length === 9 && pin.length >= 6 && !['pairing', 'negotiating'].includes(phase);

  const enterImmersive = useCallback(async () => {
    try {
      if (!document.fullscreenElement) await document.documentElement.requestFullscreen();
    } catch {
      // iOS Safari tidak mendukung Fullscreen API pada elemen biasa.
    }
    try {
      const orientation = screen.orientation as ScreenOrientation & { lock?: (value: string) => Promise<void> };
      await orientation.lock?.('landscape');
    } catch {
      // Orientation lock bersifat best-effort dan tergantung browser.
    }
  }, []);

  const connect = async (isRetry = false) => {
    localStorage.setItem(LAST_HOST_KEY, hostId);
    setPhase('pairing');
    if (!isRetry) {
      retryRef.current.tries = 0;
      retryRef.current.wasConnected = false;
      setRetryInfo('');
    }
    // PENTING: fullscreen + rotasi landscape TIDAK dipanggil di sini.
    // Selama pairing/negosiasi pengguna tetap di layar form; layar baru
    // berputar setelah transport benar-benar connected.
    try {
      const jwt = await ensureToken();
      const session = new RtcSession();
      sessionRef.current = session;
      session.onPhase = (next) => {
        setPhase(next);
        if (next === 'connected') {
          retryRef.current.tries = 0;
          retryRef.current.wasConnected = true;
          setRetryInfo('');
          setConnectedAt(Date.now());
          saveRecent(hostId);
          setRecents(loadRecents());
          window.history.replaceState({}, '', '/connect#session');
          void enterImmersive();
        }
        // Reconnect otomatis HANYA bila sesi pernah live lalu putus
        // (jaringan goyah) — bukan untuk pairing gagal/password salah.
        if (
          next === 'ended' &&
          retryRef.current.wasConnected &&
          retryRef.current.tries < 3 &&
          sessionRef.current === session
        ) {
          retryRef.current.tries += 1;
          const wait = retryRef.current.tries * 2000;
          setRetryInfo(
            `Koneksi terputus — mencoba ulang (${retryRef.current.tries}/3)…`,
          );
          retryRef.current.timer = setTimeout(() => void connect(true), wait);
        } else if (next === 'ended' && retryRef.current.tries >= 3) {
          setRetryInfo('Gagal menyambung ulang. Coba konek manual.');
        }
      };
      session.onTrack = (stream) => {
        if (videoRef.current) videoRef.current.srcObject = stream;
      };
      // Audio sistem host — diputar lewat elemen audio terpisah.
      session.onAudioTrack = (stream) => {
        if (audioRef.current) {
          audioRef.current.srcObject = stream;
          audioRef.current.volume = prefsRef.current.volume;
        }
      };
      // Meta host (daftar layar + status audio) untuk pemilih monitor.
      session.onMeta = (meta) => setHostMeta(meta);
      // Balasan "ambil dari papan klip PC": salin ke papan klip perangkat
      // ini; kalau izin ditolak, tampilkan isinya biar tetap bisa disalin.
      session.onClipboard = async (text) => {
        try {
          await navigator.clipboard.writeText(text);
          setHudToast(`Papan klip PC tersalin ke perangkat ini (${text.length} karakter)`);
        } catch {
          setHudToast(`Papan klip PC: ${text.slice(0, 80)}${text.length > 80 ? '…' : ''}`);
        }
      };
      await session.start(jwt, hostId, pin);
    } catch {
      setPhase('ended');
    }
  };

  const disconnect = useCallback(() => {
    if (retryRef.current.timer) clearTimeout(retryRef.current.timer);
    retryRef.current.tries = 3; // blok retry setelah putus manual
    sessionRef.current?.stop();
    sessionRef.current = null;
    setKbOpen(false);
    setPadOpen(false);
    setPanelOpen(false);
    setStats(null);
    setConnectedAt(null);
    setHudToast('');
    setPhase('');
    if (window.location.hash === '#session') {
      window.history.replaceState({}, '', '/connect');
    }
    if (document.fullscreenElement) void document.exitFullscreen();
  }, []);
  useEffect(() => disconnect, [disconnect]);

  const send = (bytes: Uint8Array) => sessionRef.current?.sendInput(bytes);

  // Statistik live (tab Gambar di panel): baca getStats tiap detik hanya
  // saat panel terbuka supaya tidak bikin rame saat main.
  useEffect(() => {
    if (!connected || !panelOpen) return;
    let alive = true;
    const poll = async () => {
      const s = await sessionRef.current?.readStats();
      if (alive && s) setStats(s);
    };
    void poll();
    const t = setInterval(() => void poll(), 1000);
    return () => {
      alive = false;
      clearInterval(t);
    };
  }, [connected, panelOpen]);

  // Toast HUD hilang sendiri setelah 4 detik.
  useEffect(() => {
    if (!hudToast) return;
    const t = setTimeout(() => setHudToast(''), 4000);
    return () => clearTimeout(t);
  }, [hudToast]);

  const toggleTrackpad = useCallback(() => {
    touchRef.current.points.clear();
    setTrackpad((v) => !v);
  }, []);

  // Kirim papan klip perangkat ini ke PC (0x08 CLIPBOARD_SET, bukan
  // diketik per karakter — sama seperti aplikasi).
  const clipboardPush = async () => {
    try {
      const text = await navigator.clipboard.readText();
      if (!text) {
        setHudToast('Papan klip perangkat ini kosong.');
        return;
      }
      sessionRef.current?.sendClipboard(text.slice(0, 32768));
      setHudToast(`Terkirim ke papan klip PC (${text.length} karakter)`);
    } catch {
      setHudToast('Izin baca papan klip ditolak browser — buka keyboard virtual lalu tempel di sana.');
    }
  };

  // Minta isi papan klip PC (0x09 CLIPBOARD_REQ); balasannya lewat
  // onClipboard di atas.
  const clipboardPull = () => {
    sessionRef.current?.requestClipboard();
    setHudToast('Meminta isi papan klip PC…');
  };

  // Keyboard fisik -> host. Aktif hanya saat sesi live; preventDefault agar
  // shortcut browser (Ctrl+W dsb.) tidak membajak sesi.
  useEffect(() => {
    if (!connected) return;
    const down = (e: KeyboardEvent) => {
      const vk = vkFromCode(e.code);
      if (vk === null) return;
      e.preventDefault();
      send(InputCodec.key(vk, true));
    };
    const up = (e: KeyboardEvent) => {
      const vk = vkFromCode(e.code);
      if (vk === null) return;
      e.preventDefault();
      send(InputCodec.key(vk, false));
    };
    window.addEventListener('keydown', down);
    window.addEventListener('keyup', up);
    return () => {
      window.removeEventListener('keydown', down);
      window.removeEventListener('keyup', up);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [connected]);

  const onPointerMove = (event: React.PointerEvent) => {
    const element = surfaceRef.current;
    if (!element) return;
    const rect = element.getBoundingClientRect();
    send(InputCodec.mouseMoveAbs((event.clientX - rect.left) / rect.width, (event.clientY - rect.top) / rect.height));
  };

  // ── Mode trackpad: layar jadi touchpad, bukan layar sentuh ──────
  // Satu jari geser = gerak kursor relatif; ketuk singkat tanpa geser =
  // klik kiri; dua jari geser = scroll. Cocok untuk HP karena kursor
  // tidak "meloncat" ke posisi jari. Sensitivitas & perilaku diatur
  // lewat panel pengaturan sesi.
  const tpDown = (e: React.PointerEvent) => {
    const t = touchRef.current;
    t.points.set(e.pointerId, { x: e.clientX, y: e.clientY });
    if (t.points.size === 1) {
      t.moved = false;
      t.downAt = performance.now();
    }
  };
  const tpMove = (e: React.PointerEvent) => {
    const t = touchRef.current;
    const prev = t.points.get(e.pointerId);
    if (!prev) return; // hover mouse tanpa tekan — abaikan di mode trackpad
    const dx = e.clientX - prev.x;
    const dy = e.clientY - prev.y;
    t.points.set(e.pointerId, { x: e.clientX, y: e.clientY });
    if (Math.abs(dx) + Math.abs(dy) > 2) t.moved = true;
    if (t.points.size >= 2) {
      // Dua jari: scroll. Arah alami — konten mengikuti jari — kecuali
      // dibalik lewat pengaturan.
      const dir = prefs.reverseScroll ? -1 : 1;
      send(InputCodec.scroll(0, Math.round(dy * 2 * dir)));
    } else {
      send(InputCodec.mouseMoveRel(Math.round(dx * prefs.sens), Math.round(dy * prefs.sens)));
    }
  };
  const tpUp = (e: React.PointerEvent) => {
    const t = touchRef.current;
    const known = t.points.delete(e.pointerId);
    if (!known) return;
    if (t.points.size === 0 && !t.moved && prefs.tapClick && performance.now() - t.downAt < 300) {
      send(InputCodec.mouseButton(0, true));
      send(InputCodec.mouseButton(0, false));
    }
  };

  const labels: Record<string, string> = {
    pairing: 'Menghubungi host…',
    negotiating: 'Menyiapkan koneksi langsung…',
    connected: 'Tersambung',
    rejected:
      'ID atau password salah. Periksa keduanya lalu coba lagi — huruf besar dan kecil ikut dihitung.',
    'peer-offline':
      'ID tidak ditemukan. Pastikan ID benar dan XyDesk Host sedang berjalan di PC.',
    'host-busy':
      'Perangkat sedang dipakai sesi lain. Koneksi ini ditolak — tunggu sesi selesai lalu coba lagi.',
    ended: 'Sesi berakhir',
  };

  return (
    <>
    <section className={connected ? 'remote-session' : 'connect-card surface-card'}>
      {!connected && (
        <div className="connect-form">
          <h1>Kendalikan PC dari browser.</h1>
          <p className="muted">Tidak perlu akun. Ambil ID dan password dari XyDesk Host di PC.</p>
          <div className="field-head">
            <span className="field-label">ID perangkat</span>
            <span className="field-tools">
            {canScanQr && (
            <button
              type="button"
              className="recents-toggle"
              onClick={() => setQrOpen(true)}
              title="Pindai QR dari XyDesk Host"
            >
              <QrIcon />
              Pindai QR
            </button>
            )}
            {recents.length > 0 && (
              <button
                type="button"
                className={recentsOpen ? 'recents-toggle open' : 'recents-toggle'}
                onClick={() => setRecentsOpen((v) => !v)}
                aria-expanded={recentsOpen}
              >
                <HistoryIcon />
                Riwayat
              </button>
            )}
            </span>
          </div>
          {recentsOpen && (
            <div className="recents-list">
              {recents.map((r) => (
                <button
                  key={r.id}
                  type="button"
                  className="recent-item"
                  onClick={() => {
                    setHostId(formatHostId(r.id));
                    setPin('');
                    setRecentsOpen(false);
                    pinRef.current?.focus();
                  }}
                >
                  <span className="recent-id">{formatHostId(r.id)}</span>
                  <span className="recent-pw">ketik password</span>
                </button>
              ))}
              <button
                type="button"
                className="recent-clear"
                onClick={() => {
                  clearRecents();
                  setRecents([]);
                  setRecentsOpen(false);
                }}
              >
                Hapus riwayat
              </button>
            </div>
          )}
          <input className="host-id" inputMode="numeric" placeholder="123 456 789" value={hostId} autoFocus={!hostId} onChange={(e) => {
            const value = formatHostId(e.target.value);
            setHostId(value);
            if (value.replace(/\s/g, '').length === 9) pinRef.current?.focus();
          }} />
          <span className="field-label">Password pairing</span>
          <div className="pw-field">
            {/* autoCapitalize "none", bukan "characters" seperti dulu: host
                membandingkan password secara peka-kasus, jadi peramban mobile
                yang mengkapital huruf pertama akan MENGUBAH password yang
                diketik dan mengunci penggunanya sendiri. */}
            <input
              ref={pinRef}
              type={showPw ? 'text' : 'password'}
              placeholder="Password pairing"
              value={pin}
              autoCapitalize="none"
              autoCorrect="off"
              spellCheck={false}
              autoComplete="off"
              onChange={(e) => setPin(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && canConnect && connect()}
            />
            <button
              type="button"
              className="pw-toggle"
              onClick={() => setShowPw((v) => !v)}
              title={showPw ? 'Sembunyikan password' : 'Tampilkan password'}
              aria-label={showPw ? 'Sembunyikan password' : 'Tampilkan password'}
              aria-pressed={showPw}
            >
              {showPw ? <EyeOffIcon /> : <EyeIcon />}
            </button>
          </div>
          {phase && <p className="status-text">{labels[phase] ?? phase}</p>}
          {retryInfo && <p className="status-text">{retryInfo}</p>}
          <button className="connect-cta" disabled={!canConnect} onClick={() => void connect()}>{['pairing', 'negotiating'].includes(phase) ? labels[phase] : 'Konek sekarang'}</button>
          <p className="microcopy">Sesi tamu berlaku dua jam dan tidak menyimpan identitas.</p>
        </div>
      )}
      <div
        ref={surfaceRef}
        className="video-surface"
        hidden={!connected}
        onPointerMove={trackpad ? tpMove : onPointerMove}
        onPointerDown={trackpad ? tpDown : (e) => send(InputCodec.mouseButton(e.button === 2 ? 1 : 0, true))}
        onPointerUp={trackpad ? tpUp : (e) => send(InputCodec.mouseButton(e.button === 2 ? 1 : 0, false))}
        onPointerCancel={trackpad ? tpUp : undefined}
        onWheel={(e) => send(InputCodec.scroll(-e.deltaX, -e.deltaY))}
        onContextMenu={(e) => e.preventDefault()}
      >
        <video ref={videoRef} autoPlay playsInline muted />
        {/* Audio sistem host (track Opus) — elemen terpisah, tidak di-mute. */}
        <audio ref={audioRef} autoPlay />
        {connected && (
          <div
            className={`sesi-waktu${sisaDetik !== null && sisaDetik <= 300 ? ' kritis' : ''}`}
            title={
              tamu
                ? 'Sesi tamu berlaku dua jam — putuskan lalu konek ulang bila habis'
                : 'Durasi sesi berjalan'
            }
          >
            <span>{fmtDurasi(durasiDetik ?? 0)}</span>
            {sisaDetik !== null && (
              <em>{sisaDetik > 0 ? `tersisa ${fmtDurasi(sisaDetik)}` : 'batas tercapai'}</em>
            )}
          </div>
        )}
        <SessionRail
          collapsed={railHidden}
          onToggleCollapsed={() => setRailHidden((v) => !v)}
          audioOn={audioOn}
          onAudio={() => {
            const next = !audioOn;
            setAudioOn(next);
            void sessionRef.current?.setAudioEnabled(next);
          }}
          micOn={micOn}
          onMic={async () => {
            if (micOn) {
              await sessionRef.current?.disableMic();
              setMicOn(false);
              return;
            }
            const err = await sessionRef.current?.enableMic();
            if (err) {
              setHudToast(err);
              return;
            }
            setMicOn(true);
          }}
          kbOpen={kbOpen}
          onKeyboard={() => setKbOpen((v) => !v)}
          padOpen={padOpen}
          onPad={() => setPadOpen((v) => !v)}
          trackpad={trackpad}
          onTrackpad={toggleTrackpad}
          onClipboardPush={() => void clipboardPush()}
          onClipboardPull={clipboardPull}
          onFullscreen={() => void enterImmersive()}
          panelOpen={panelOpen}
          onPanel={() => setPanelOpen((v) => !v)}
          onDisconnect={disconnect}
        />
        <div className="hud-mouse" aria-hidden="false">
          <button
            className="hud-icon-btn"
            title="Klik kiri (tahan untuk drag)"
            onPointerDown={() => send(InputCodec.mouseButton(0, true))}
            onPointerUp={() => send(InputCodec.mouseButton(0, false))}
            onPointerCancel={() => send(InputCodec.mouseButton(0, false))}
          >
            <img src="/hud-mouse-left.png" alt="Klik kiri" />
          </button>
          <button
            className="hud-icon-btn"
            title="Klik kanan"
            onPointerDown={() => send(InputCodec.mouseButton(1, true))}
            onPointerUp={() => send(InputCodec.mouseButton(1, false))}
            onPointerCancel={() => send(InputCodec.mouseButton(1, false))}
          >
            <img src="/hud-mouse-right.png" alt="Klik kanan" />
          </button>
        </div>
        {retryInfo && <p className="session-retry">{retryInfo}</p>}
        {hudToast && <p className="hud-toast" role="status">{hudToast}</p>}
        {panelOpen && (
          <SessionPanel
            prefs={prefs}
            onChange={setPrefs}
            onClose={() => setPanelOpen(false)}
            hostId={hostId}
            onDisconnect={disconnect}
            stats={stats}
            displays={hostMeta?.displays ?? []}
            wantedDisplay={hostMeta?.wanted ?? 0}
            onSelectDisplay={(i) => sessionRef.current?.selectDisplay(i)}
            connectedAt={connectedAt}
            railCollapsed={railHidden}
            totalSesiDetik={totalSesiDetik}
            trackpad={trackpad}
            onTrackpadMode={(on) => {
              if (on !== trackpad) toggleTrackpad();
            }}
          />
        )}
        {padOpen && <GamingPad send={send} />}
        {kbOpen && <VirtualKeyboard send={send} />}
      </div>
    </section>
    {qrOpen && (
      <QrScanModal
        onClose={() => setQrOpen(false)}
        onResult={(id) => {
          setHostId(formatHostId(id));
          setQrOpen(false);
          pinRef.current?.focus();
        }}
      />
    )}
    {!connected && (
      <>
        <SupportLinks />
        <ConnectGuide />
      </>
    )}
    </>
  );
}

function SiteFooter({ navigate }: { navigate: (r: Route) => void }) {
  return (
    <footer className="site-footer">
      <div className="footer-inner">
        <div className="footer-brand">
          <img src="/logo-white.png" alt="XyDesk" />
          <strong>XyDesk</strong>
          <p>Remote desktop ringan untuk kerja, bermain, dan mengakses PC dari mana saja.</p>
        </div>
        <div className="footer-columns">
          <div className="footer-column">
            <strong>Produk</strong>
            <button onClick={() => navigate('/connect')}>Connect Web</button>
            <button onClick={() => navigate('/download')}>Download</button>
            <button onClick={() => navigate('/news')}>Berita</button>
          </div>
          <div className="footer-column">
            <strong>Platform</strong>
            {DOWNLOAD_ENABLED ? (
              <>
                <a href={`${RELEASE_BASE}/XyDesk-Android-arm64-v8a.apk`}>Android</a>
                <a href={`${RELEASE_BASE}/XyDesk-x64.exe`}>Windows</a>
              </>
            ) : (
              <>
                <button onClick={() => navigate('/download')}>Android — segera</button>
                <button onClick={() => navigate('/download')}>Windows — segera</button>
              </>
            )}
            <button onClick={() => navigate('/connect')}>iPhone & iPad</button>
          </div>
          <div className="footer-column">
            <strong>Dukungan</strong>
            <button onClick={() => navigate('/legal')}>Legal & Privasi</button>
            <button onClick={() => navigate('/legal')}>Lisensi pihak ketiga</button>
            <a href={WHATSAPP_CHANNEL} target="_blank" rel="noreferrer">Saluran WhatsApp</a>
          </div>
        </div>
        <div className="footer-bottom">
          {/* Versi dibaca dari pubspec saat build; tautannya ke changelog,
              bukan ke GitHub Releases — pengguna butuh penjelasan, bukan
              artefak build. */}
          <span>
            © 2026 XySpace Tech ·{' '}
            <button
              className="footer-version"
              onClick={() => navigate({ page: 'news-detail', slug: CHANGELOG_SLUG })}
            >
              XyDesk v{APP_VERSION} · {STAGE_LABEL[RELEASE_STAGE]}
            </button>
          </span>
          <span>Media sesi tidak disimpan oleh server.</span>
        </div>
      </div>
    </footer>
  );
}

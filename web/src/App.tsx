import { useCallback, useEffect, useRef, useState } from 'react';
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
  beginGoogleLogin,
  consumeGoogleRedirect,
  GOOGLE_CLIENT_ID,
} from './google';
import { InputCodec, RtcPhase, RtcSession } from './rtc';
import { TOUCH_ROWS, vkFromCode } from './vk';

type Route = '/' | '/connect' | '/download' | '/legal' | '/blog';
type AuthStep = 'closed' | 'login' | 'otp';

const TOKEN_KEY = 'xydesk.web.jwt';
const GUEST_TOKEN_KEY = 'xydesk.web.guestJwt';
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
    file: 'XyDesk-Windows-x64-Setup.exe',
    note: 'Aplikasi terpadu Connect + Host untuk Intel atau AMD',
  },
  {
    platform: 'Windows',
    architecture: 'Arm64',
    file: 'XyDesk-Windows-arm64-Setup.exe',
    note: 'Aplikasi terpadu Connect + Host untuk Windows on Arm',
  },
] as const;

function currentRoute(): Route {
  const path = window.location.pathname.replace(/\/$/, '') || '/';
  return ['/connect', '/download', '/legal', '/blog'].includes(path)
    ? (path as Route)
    : '/';
}

function useRoute() {
  const [route, setRoute] = useState<Route>(currentRoute);
  useEffect(() => {
    const onPop = () => setRoute(currentRoute());
    window.addEventListener('popstate', onPop);
    return () => window.removeEventListener('popstate', onPop);
  }, []);
  const navigate = useCallback((next: Route) => {
    window.history.pushState({}, '', next);
    setRoute(next);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }, []);
  return { route, navigate };
}

export default function App() {
  const { route, navigate } = useRoute();
  useEffect(() => {
    const titles: Record<Route, string> = {
      '/': 'XyDesk — Remote Desktop untuk Semua Perangkat',
      '/connect': 'Connect Web — XyDesk',
      '/download': 'Download XyDesk untuk Android dan Windows',
      '/blog': 'XyDesk Notes',
      '/legal': 'Legal dan Privasi — XyDesk',
    };
    document.title = titles[route];
  }, [route]);
  return (
    <div className="site-shell">
      <SiteHeader route={route} navigate={navigate} />
      {route === '/' && <LandingPage navigate={navigate} />}
      {route === '/connect' && <RemoteApp />}
      {route === '/download' && <DownloadPage />}
      {route === '/legal' && <LegalPage />}
      {route === '/blog' && <BlogPage />}
      {route !== '/connect' && <SiteFooter navigate={navigate} />}
    </div>
  );
}

function SiteHeader({ route, navigate }: { route: Route; navigate: (r: Route) => void }) {
  const [menuOpen, setMenuOpen] = useState(false);
  const go = (next: Route) => {
    setMenuOpen(false);
    navigate(next);
  };
  return (
    <header className="site-header">
      <button className="brand-button" onClick={() => go('/')}>
        <img src="/logo.png" alt="" className="brand-logo" />
        <span>XyDesk</span>
      </button>
      <button
        className={menuOpen ? 'menu-toggle open' : 'menu-toggle'}
        aria-label={menuOpen ? 'Tutup menu' : 'Buka menu'}
        aria-expanded={menuOpen}
        onClick={() => setMenuOpen((value) => !value)}
      >
        <span />
        <span />
        <span />
      </button>
      {menuOpen && <button className="menu-backdrop" aria-label="Tutup menu" onClick={() => setMenuOpen(false)} />}
      <nav className={menuOpen ? 'open' : ''} aria-label="Navigasi utama">
        {([
          ['/', 'Beranda'],
          ['/connect', 'Connect'],
          ['/download', 'Download'],
          ['/blog', 'Blog'],
          ['/legal', 'Legal'],
        ] as const).map(([path, label]) => (
          <button
            key={path}
            className={route === path ? 'nav-link active' : 'nav-link'}
            onClick={() => go(path)}
          >
            {label}
          </button>
        ))}
      </nav>
      <button className="header-cta" onClick={() => go('/connect')}>
        Buka Web
      </button>
    </header>
  );
}

function PlatformIcon({ platform }: { platform: 'android' | 'windows' }) {
  return (
    <img
      className="platform-image-icon"
      src={platform === 'android' ? '/platform-android.svg' : '/platform-windows.svg'}
      alt=""
      aria-hidden="true"
    />
  );
}

function LandingPage({ navigate }: { navigate: (r: Route) => void }) {
  const recommended = useRecommendedDownload();
  return (
    <main>
      <section className="hero">
        <div className="float-stage" aria-hidden="true">
          <img className="float-item float-monitor" src="/float-monitor.webp" alt="" />
          <img className="float-item float-controller" src="/float-controller.webp" alt="" />
          <img className="float-item float-keyboard" src="/float-keyboard.webp" alt="" />
          <img className="float-item float-mouse" src="/float-mouse.webp" alt="" />
          <img className="float-item float-cursor" src="/float-cursor.webp" alt="" />
          <img className="float-item float-rocket" src="/float-rocket.webp" alt="" />
          <img className="float-item float-cloud" src="/float-cloud.webp" alt="" />
          <img className="float-item float-wifi" src="/float-wifi.webp" alt="" />
          <i className="orbit-dot orbit-dot-a" />
          <i className="orbit-dot orbit-dot-b" />
          <i className="orbit-dot orbit-dot-c" />
        </div>
        <div className="hero-copy">
          <h1>XyDesk</h1>
          <p className="hero-description">
            Akses PC untuk kerja dan bermain dari Android, Windows, atau browser.
            Ringan, aman, dan langsung tersambung lewat ID serta password host.
          </p>
          <div className="hero-actions">
            {recommended.file ? (
              <a className="hero-btn primary-cta platform-cta" href={`${RELEASE_BASE}/${recommended.file}`}>
                <PlatformIcon platform={recommended.platform === 'windows' ? 'windows' : 'android'} />
                Download {recommended.platform === 'windows' ? 'Windows' : 'Android'}
              </a>
            ) : (
              <button className="hero-btn primary-cta" onClick={() => navigate('/connect')}>
                Buka XyDesk Web
              </button>
            )}
            <button className="hero-btn secondary-cta" onClick={() => navigate('/connect')}>
              Connect dari Browser
            </button>
          </div>
          <a className="channel-link" href={WHATSAPP_CHANNEL} target="_blank" rel="noreferrer">
            Join saluran WhatsApp
          </a>
          {recommended.file && (
            <p className="detect-chip">
              Terdeteksi: <strong>{recommended.label}</strong>
              {recommended.confidence === 'fallback' && ' (perkiraan)'}
              {recommended.platform === 'android' && (
                <button
                  className="abi-correction"
                  onClick={() => {
                    localStorage.setItem(
                      'xydesk.download.arch',
                      recommended.architecture === 'arm64'
                        ? 'android-armv7'
                        : 'android-arm64',
                    );
                    window.location.reload();
                  }}
                >
                  {recommended.architecture === 'arm64'
                    ? 'HP 32-bit? Pakai ARMv7'
                    : 'HP 64-bit? Pakai ARM64'}
                </button>
              )}
            </p>
          )}
        </div>
      </section>

      <PlatformTables compact />

      <section className="feature-grid" aria-label="Keunggulan XyDesk">
        <FeatureCard index="01" title="Satu ID, langsung konek">
          Tidak perlu menghafal alamat jaringan. Ambil ID dan password dari Host,
          lalu masukkan dari perangkat pengendali.
        </FeatureCard>
        <FeatureCard index="02" title="Paket sesuai perangkat">
          Android dan Windows dipisah per arsitektur agar unduhan lebih kecil dan
          tidak membawa library yang tidak dipakai.
        </FeatureCard>
        <FeatureCard index="03" title="Verifikasi berlapis">
          Update memeriksa checksum, ukuran, ABI, package ID, build, dan sertifikat
          signing sebelum installer dibuka.
        </FeatureCard>
      </section>

      <section className="release-strip">
        <div>
          <p className="eyebrow">RILIS STABIL</p>
          <h2>Unduh hanya yang kamu butuhkan.</h2>
        </div>
        <button className="secondary-cta" onClick={() => navigate('/download')}>
          Lihat semua paket
        </button>
      </section>
    </main>
  );
}

function FeatureCard({ index, title, children }: { index: string; title: string; children: string }) {
  return (
    <article className="feature-card">
      <span>{index}</span>
      <h2>{title}</h2>
      <p>{children}</p>
    </article>
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
  const table = (title: string, icon: 'android' | 'windows', items: readonly (typeof downloads)[number][]) => (
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
            <a href={`${RELEASE_BASE}/${item.file}`}>Download</a>
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

function DownloadPage() {
  const recommended = useRecommendedDownload();
  return (
    <main className="content-page download-page">
      <p className="eyebrow">DOWNLOAD CENTER</p>
      <h1>Pilih paket yang tepat.</h1>
      <p className="page-lead">
        Deteksi otomatis merekomendasikan {recommended.label}. Semua file di bawah
        terhubung langsung ke GitHub Release terbaru dan dilindungi SHA-256.
      </p>
      {recommended.file ? (
        <a className="primary-cta centered-cta platform-cta" href={`${RELEASE_BASE}/${recommended.file}`}>
          <PlatformIcon platform={recommended.platform === 'windows' ? 'windows' : 'android'} />
          Download For {recommended.platform === 'windows' ? 'Windows' : 'Android'}
        </a>
      ) : (
        <a className="primary-cta centered-cta" href="/connect">
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
      <p className="eyebrow">LEGAL & PRIVACY</p>
      <h1>Kendali tetap milik kamu.</h1>
      <section>
        <h2>Privasi sesi</h2>
        <p>
          Signaling hanya mempertemukan perangkat. Media WebRTC memakai DTLS-SRTP
          dan tidak disimpan oleh layanan XyDesk. Password pairing diverifikasi di
          sisi Host.
        </p>
      </section>
      <section>
        <h2>Data akun</h2>
        <p>
          Login email memakai OTP satu kali. OTP disimpan sebagai hash dan memiliki
          batas waktu serta batas percobaan. Sesi tamu berumur pendek dan tidak
          menyimpan identitas pengguna.
        </p>
      </section>
      <section>
        <h2>Tanggung jawab penggunaan</h2>
        <p>
          Gunakan XyDesk hanya pada perangkat yang kamu miliki atau yang secara jelas
          memberi izin. Jangan memakai layanan untuk mengambil alih, mengganggu, atau
          mengakses data pihak lain tanpa hak.
        </p>
      </section>
    </main>
  );
}

function BlogPage() {
  const posts = [
    ['Rilis 1.3.0', 'Paket Android dan Windows kini dipisah per arsitektur agar lebih kecil dan presisi.'],
    ['Cara memilih APK', 'ARM64 cocok untuk hampir semua HP modern. ARMv7 disediakan untuk perangkat lama.'],
    ['Mengapa update diverifikasi', 'Checksum saja belum cukup; XyDesk turut memeriksa ABI, build, package, dan signing.'],
  ];
  return (
    <main className="content-page blog-page">
      <p className="eyebrow">XYDESK NOTES</p>
      <h1>Catatan produk tanpa jargon kosong.</h1>
      <div className="blog-grid">
        {posts.map(([title, summary], index) => (
          <article key={title}>
            <span>0{index + 1}</span>
            <h2>{title}</h2>
            <p>{summary}</p>
          </article>
        ))}
      </div>
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
  // menjadi sesi XyDesk lalu bersihkan URL.
  useEffect(() => {
    const idToken = consumeGoogleRedirect();
    if (idToken) void doGoogle(idToken);
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
              onClick={async () => {
                const name = window.prompt(
                  'Nama tampilan baru:',
                  profile.name ?? '',
                );
                if (!name || !jwt) return;
                try {
                  const r = await updateProfileName(jwt, name.trim());
                  setProfile(r.user);
                } catch {
                  window.alert('Gagal menyimpan nama.');
                }
              }}
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
    </main>
  );
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
    <button type="button" className="google-btn" onClick={beginGoogleLogin}>
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
// Password disimpan ter-encode ringan di localStorage perangkat ini —
// murni kenyamanan; browser profile pribadi adalah asumsinya.
interface RecentEntry {
  id: string;
  pw: string;
  at: number;
}

const RECENTS_KEY = 'xydesk.web.recents';

function loadRecents(): RecentEntry[] {
  try {
    const raw = JSON.parse(localStorage.getItem(RECENTS_KEY) ?? '[]') as RecentEntry[];
    return raw.map((r) => ({ ...r, pw: atob(r.pw) })).slice(0, 5);
  } catch {
    return [];
  }
}

function saveRecent(id: string, pw: string) {
  const cleaned = id.replace(/\s/g, '');
  const next: RecentEntry[] = [
    { id: cleaned, pw, at: Date.now() },
    ...loadRecents().filter((r) => r.id !== cleaned),
  ].slice(0, 5);
  localStorage.setItem(
    RECENTS_KEY,
    JSON.stringify(next.map((r) => ({ ...r, pw: btoa(r.pw) }))),
  );
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

function ConnectScreen({ ensureToken }: { ensureToken: () => Promise<string> }) {
  const [hostId, setHostId] = useState(() => localStorage.getItem(LAST_HOST_KEY) ?? '');
  const [pin, setPin] = useState('');
  const [phase, setPhase] = useState<RtcPhase | ''>('');
  const [recents, setRecents] = useState<RecentEntry[]>(loadRecents);
  const [recentsOpen, setRecentsOpen] = useState(false);
  const [kbOpen, setKbOpen] = useState(false);
  const [retryInfo, setRetryInfo] = useState('');
  const sessionRef = useRef<RtcSession | null>(null);
  const retryRef = useRef({ tries: 0, timer: 0 as ReturnType<typeof setTimeout> | 0, wasConnected: false });
  const videoRef = useRef<HTMLVideoElement | null>(null);
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
          saveRecent(hostId, pin);
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
    setPhase('');
    if (window.location.hash === '#session') {
      window.history.replaceState({}, '', '/connect');
    }
    if (document.fullscreenElement) void document.exitFullscreen();
  }, []);
  useEffect(() => disconnect, [disconnect]);

  const send = (bytes: Uint8Array) => sessionRef.current?.sendInput(bytes);

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

  const tapKey = (vk: number) => {
    send(InputCodec.key(vk, true));
    send(InputCodec.key(vk, false));
  };
  const onPointerMove = (event: React.PointerEvent) => {
    const element = surfaceRef.current;
    if (!element) return;
    const rect = element.getBoundingClientRect();
    send(InputCodec.mouseMoveAbs((event.clientX - rect.left) / rect.width, (event.clientY - rect.top) / rect.height));
  };

  const labels: Record<string, string> = {
    pairing: 'Menghubungi host…',
    negotiating: 'Menyiapkan koneksi langsung…',
    connected: 'Tersambung',
    rejected: 'ID atau password salah. Periksa keduanya lalu coba lagi.',
    'peer-offline':
      'ID tidak ditemukan. Pastikan ID benar dan XyDesk Host sedang berjalan di PC.',
    ended: 'Sesi berakhir',
  };

  return (
    <section className={connected ? 'remote-session' : 'connect-card surface-card'}>
      {!connected && (
        <div className="connect-form">
          <h1>Kendalikan PC dari browser.</h1>
          <p className="muted">Tidak perlu akun. Ambil ID dan password dari XyDesk Host di PC.</p>
          <div className="field-head">
            <span className="field-label">ID perangkat</span>
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
                    setPin(r.pw);
                    setRecentsOpen(false);
                  }}
                >
                  <span className="recent-id">{formatHostId(r.id)}</span>
                  <span className="recent-pw">password tersimpan</span>
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
          <input ref={pinRef} type="password" placeholder="Password pairing" value={pin} onChange={(e) => setPin(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && canConnect && connect()} />
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
        onPointerMove={onPointerMove}
        onPointerDown={(e) => send(InputCodec.mouseButton(e.button === 2 ? 1 : 0, true))}
        onPointerUp={(e) => send(InputCodec.mouseButton(e.button === 2 ? 1 : 0, false))}
        onWheel={(e) => send(InputCodec.scroll(-e.deltaX, -e.deltaY))}
        onContextMenu={(e) => e.preventDefault()}
      >
        <video ref={videoRef} autoPlay playsInline muted />
        <div className="session-actions">
          <button
            onClick={async () => {
              try {
                const text = await navigator.clipboard.readText();
                if (text) send(InputCodec.text(text.slice(0, 32768)));
              } catch {
                // Izin clipboard ditolak — abaikan diam-diam.
              }
            }}
          >
            Kirim clipboard
          </button>
          <button onClick={() => setKbOpen((v) => !v)}>Keyboard</button>
          <button onClick={() => void enterImmersive()}>Layar penuh</button>
          <button className="danger-action" onClick={disconnect}>Putuskan</button>
        </div>
        {retryInfo && <p className="session-retry">{retryInfo}</p>}
        {kbOpen && (
          <div className="touch-kb" onPointerDown={(e) => e.stopPropagation()}>
            {TOUCH_ROWS.map((row, i) => (
              <div className="touch-kb-row" key={i}>
                {row.map(([label, vk]) => (
                  <button key={label} onClick={() => tapKey(vk)}>
                    {label}
                  </button>
                ))}
              </div>
            ))}
          </div>
        )}
      </div>
    </section>
  );
}

function SiteFooter({ navigate }: { navigate: (r: Route) => void }) {
  return (
    <footer className="site-footer">
      <div className="footer-brand">
        <div className="brand">
          <img src="/logo.png" alt="" className="brand-logo" />
          <strong>XyDesk</strong>
        </div>
        <p>Remote desktop ringan untuk kerja, bermain, dan mengakses PC dari mana saja.</p>
      </div>
      <div className="footer-column">
        <strong>Produk</strong>
        <button onClick={() => navigate('/connect')}>Connect Web</button>
        <button onClick={() => navigate('/download')}>Download</button>
        <button onClick={() => navigate('/blog')}>Blog</button>
      </div>
      <div className="footer-column">
        <strong>Platform</strong>
        <a href={`${RELEASE_BASE}/XyDesk-Android-arm64-v8a.apk`}>Android</a>
        <a href={`${RELEASE_BASE}/XyDesk-Windows-x64-Setup.exe`}>Windows</a>
        <button onClick={() => navigate('/connect')}>iPhone & iPad</button>
      </div>
      <div className="footer-column">
        <strong>Dukungan</strong>
        <button onClick={() => navigate('/legal')}>Legal & Privasi</button>
        <a href={WHATSAPP_CHANNEL} target="_blank" rel="noreferrer">Saluran WhatsApp</a>
        <a href="https://github.com/xykalnotkel/XyDesk/releases" target="_blank" rel="noreferrer">GitHub Releases</a>
      </div>
      <div className="footer-bottom">
        <span>© 2026 XySpace Tch. XyDesk.</span>
        <span>Media sesi tidak disimpan oleh server.</span>
      </div>
    </footer>
  );
}

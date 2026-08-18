import { useCallback, useEffect, useRef, useState } from 'react';
import {
  ApiError,
  createGuestSession,
  me,
  requestOtp,
  signInWithGoogle,
  UserProfile,
  verifyOtp,
} from './api';
import { detectDevicePackage, initialDevicePackage } from './device';
import { GOOGLE_CLIENT_ID, renderGoogleButton } from './google';
import { InputCodec, RtcPhase, RtcSession } from './rtc';

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
  return platform === 'android' ? (
    <svg className="android-head-icon" viewBox="0 0 24 24" aria-hidden="true">
      <defs>
        <linearGradient id="androidMetal" x1="4" y1="3" x2="19" y2="19">
          <stop offset="0" stopColor="#d8dde0" />
          <stop offset="0.36" stopColor="#75c776" />
          <stop offset="0.72" stopColor="#3f8f55" />
          <stop offset="1" stopColor="#b8bec2" />
        </linearGradient>
      </defs>
      <path fill="url(#androidMetal)" d="M7.1 10.2c.2-2.15 1.42-4 3.2-4.95L8.95 3.3a.55.55 0 0 1 .9-.63l1.45 2.08A7.2 7.2 0 0 1 12 4.7c.24 0 .48.02.71.05l1.45-2.08a.55.55 0 1 1 .9.63l-1.36 1.95a5.95 5.95 0 0 1 3.2 4.95H7.1Zm2.9-2.1a.72.72 0 1 0 0-1.44.72.72 0 0 0 0 1.44Zm4 0a.72.72 0 1 0 0-1.44.72.72 0 0 0 0 1.44ZM7.05 11.3h9.9v6.25c0 1.04-.84 1.89-1.89 1.89H8.94a1.89 1.89 0 0 1-1.89-1.89V11.3Z" />
      <path fill="none" stroke="rgba(255,255,255,.55)" strokeWidth=".65" d="M7.8 11.95h8.4" />
    </svg>
  ) : (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path fill="currentColor" d="M3 5.2 10.7 4v7.35H3V5.2Zm8.7-1.35L21 2.5v8.85h-9.3v-7.5ZM3 12.35h7.7V19.7L3 18.5v-6.15Zm8.7 0H21v8.9l-9.3-1.4v-7.5Z" />
    </svg>
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
          <p className="eyebrow">REMOTE DESKTOP, TANPA RIBET</p>
          <h1>XyDesk</h1>
          <p className="hero-description">
            Akses PC untuk kerja dan bermain dari Android, Windows, atau browser.
            Ringan, aman, dan langsung tersambung lewat ID serta password host.
          </p>
          <div className="hero-actions">
            {recommended.file ? (
              <a className="primary-cta platform-cta" href={`${RELEASE_BASE}/${recommended.file}`}>
                <PlatformIcon platform={recommended.platform === 'windows' ? 'windows' : 'android'} />
                Download For {recommended.platform === 'windows' ? 'Windows' : 'Android'}
              </a>
            ) : (
              <button className="primary-cta" onClick={() => navigate('/connect')}>
                Buka XyDesk Web
              </button>
            )}
            <button className="secondary-cta" onClick={() => navigate('/connect')}>
              Connect dari Browser
            </button>
          </div>
          <a className="channel-link" href={WHATSAPP_CHANNEL} target="_blank" rel="noreferrer">
            Join saluran WhatsApp
          </a>
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
        google={doGoogle}
      />
    );
  }

  return (
    <main className="connect-page">
      <div className="connect-account-bar">
        <span>{profile ? `Masuk sebagai ${profile.name || profile.email}` : 'Mode tamu siap digunakan'}</span>
        {profile ? (
          <button className="text-action" onClick={signOut}>Keluar</button>
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
  google: (token: string) => void;
}

function AuthPanel(props: AuthPanelProps) {
  return (
    <main className="auth-panel surface-card">
      <button className="back-action" onClick={() => props.setStep('closed')}>Kembali ke mode tamu</button>
      <img src="/logo.png" alt="XyDesk" className="auth-logo" />
      <h1>{props.step === 'otp' ? 'Kode verifikasi' : 'Masuk ke XyDesk'}</h1>
      {props.step === 'login' ? (
        <>
          <GoogleButton onCredential={props.google} />
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

function GoogleButton({ onCredential }: { onCredential: (idToken: string) => void }) {
  const ref = useRef<HTMLDivElement | null>(null);
  const [failed, setFailed] = useState(!GOOGLE_CLIENT_ID);
  useEffect(() => {
    if (!ref.current || !GOOGLE_CLIENT_ID) return;
    renderGoogleButton(ref.current, onCredential).catch(() => setFailed(true));
  }, [onCredential]);
  return failed ? null : <div ref={ref} className="google-btn" />;
}

function formatHostId(raw: string): string {
  return raw.replace(/\D/g, '').slice(0, 9).replace(/(\d{3})(?=\d)/g, '$1 ');
}

function ConnectScreen({ ensureToken }: { ensureToken: () => Promise<string> }) {
  const [hostId, setHostId] = useState(() => localStorage.getItem(LAST_HOST_KEY) ?? '');
  const [pin, setPin] = useState('');
  const [phase, setPhase] = useState<RtcPhase | ''>('');
  const sessionRef = useRef<RtcSession | null>(null);
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

  const connect = async () => {
    localStorage.setItem(LAST_HOST_KEY, hostId);
    setPhase('pairing');
    void enterImmersive();
    try {
      const jwt = await ensureToken();
      const session = new RtcSession();
      sessionRef.current = session;
      session.onPhase = (next) => {
        setPhase(next);
        if (next === 'connected') void enterImmersive();
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
    sessionRef.current?.stop();
    sessionRef.current = null;
    setPhase('');
    if (document.fullscreenElement) void document.exitFullscreen();
  }, []);
  useEffect(() => disconnect, [disconnect]);

  const send = (bytes: Uint8Array) => sessionRef.current?.sendInput(bytes);
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
    rejected: 'Password pairing ditolak',
    'peer-offline': 'Host tidak online',
    ended: 'Sesi berakhir',
  };

  return (
    <section className={connected ? 'remote-session' : 'connect-card surface-card'}>
      {!connected && (
        <div className="connect-form">
          <p className="eyebrow">GUEST CONNECT</p>
          <h1>Kendalikan PC dari browser.</h1>
          <p className="muted">Tidak perlu akun. Ambil ID dan password dari XyDesk Host di PC.</p>
          <input className="host-id" inputMode="numeric" placeholder="123 456 789" value={hostId} autoFocus={!hostId} onChange={(e) => {
            const value = formatHostId(e.target.value);
            setHostId(value);
            if (value.replace(/\s/g, '').length === 9) pinRef.current?.focus();
          }} />
          <input ref={pinRef} type="password" placeholder="Password pairing" value={pin} onChange={(e) => setPin(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && canConnect && connect()} />
          {phase && <p className="status-text">{labels[phase] ?? phase}</p>}
          <button disabled={!canConnect} onClick={connect}>{['pairing', 'negotiating'].includes(phase) ? labels[phase] : 'Konek sekarang'}</button>
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
          <button onClick={() => void enterImmersive()}>Layar penuh</button>
          <button className="danger-action" onClick={disconnect}>Putuskan</button>
        </div>
      </div>
    </section>
  );
}

function SiteFooter({ navigate }: { navigate: (r: Route) => void }) {
  return (
    <footer>
      <span>XyDesk · XySpace Tch</span>
      <div>
        <button onClick={() => navigate('/legal')}>Legal</button>
        <button onClick={() => navigate('/blog')}>Blog</button>
        <a href={WHATSAPP_CHANNEL} target="_blank" rel="noreferrer">WhatsApp</a>
      </div>
    </footer>
  );
}

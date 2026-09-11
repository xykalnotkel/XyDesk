'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import {
  Cable,
  ClipboardCopy,
  Eye,
  EyeOff,
  Heart,
  Home,
  Laptop,
  Monitor,
  Newspaper,
  Power,
  RefreshCw,
  Settings,
  Share2,
  Smartphone,
  User,
  ExternalLink,
  LogOut,
  Shield,
} from 'lucide-react';
import {
  fetchNewsList,
  fetchNewsPost,
  formatNewsDate,
  NEWS_CATEGORIES,
  NEWS_SHARE_BASE,
  NewsComment,
  NewsPost,
  postComment,
  subscribeNews,
  toggleLike,
} from './news';

// Mode demo: dibuka sebagai halaman biasa (bukan lewat Electron) → data contoh.
const DEMO = typeof window !== 'undefined' && !window.xydesk;

// Blok gambar di badan berita: baris sendiri berbentuk
// ![keterangan](https://app.xydesk.my.id/news/shots/....jpg).
// Hanya gambar dari domain sendiri yang dirender — sesuai docs/NEWS_STYLE.md;
// baris lain tetap tampil sebagai paragraf biasa. Pola sama dengan web client.
const NEWS_IMAGE_BLOCK = /^!\[([^\]]*)\]\((https:\/\/(app\.)?xydesk\.my\.id\/[^)\s]+)\)$/;

const DEMO_STATUS: StatusPayload = {
  state: 'streaming',
  engine: true,
  deviceId: '123456789',
  password: 'KopiPagi2026',
  signalingUrl: 'wss://signal.xydesk.my.id/ws',
  uptimeMs: 1800000,
  session: {
    clientId: 'klien-demo',
    clientName: 'Redmi Note 12',
    clientPlatform: 'android',
    startedAtMs: Date.now() - 60000,
    durationMs: 60000,
  },
  video: { framesSent: 214400, fps: 60, nvenc: true, encoder: 'nvenc', latencyMs: 21.4, latencyMaxMs: 46 },
  audio: {
    captureAvailable: true,
    pipeline: 'wasapi-loopback → opus 48kHz stereo',
    micAvailable: true,
    micPipeline: 'opus 48kHz mono → default render endpoint',
    outputs: 2,
    volume: 0.65,
  },
  displays: {
    list: [
      { index: 0, name: '\\\\.\\DISPLAY1', width: 2560, height: 1440 },
      { index: 1, name: '\\\\.\\DISPLAY2', width: 1920, height: 1080 },
    ],
    wanted: 0,
  },
  targetBitrateBps: 8000000,
  framesCaptured: 214400,
  isRdpSession: false,
  captureBackend: 'dxgi-duplication',
  virtualDisplay: { needed: false, installed: true, isAdmin: true },
  virtualMic: { needed: false, installed: true, hasVirtualInput: true, hasVirtualOutput: true, renderTarget: 'CABLE Input (VB-Audio Virtual Cable)' },
  lastError: null,
};

const DEMO_LOGS: LogEntry[] = [
  { t: Date.now() - 5000, line: '[shell] identitas host 123456789' },
  { t: Date.now() - 4500, line: '[shell] mulai engine (port control 43210)' },
  { t: Date.now() - 4200, line: '[engine] [control] http://127.0.0.1:43210 token=…' },
  { t: Date.now() - 3800, line: '[engine] terhubung ke wss://signal.xydesk.my.id/ws' },
  { t: Date.now() - 2000, line: '[engine] NVENC aktif: H264 hardware 1920x1080 @ 8000 kbps CBR' },
  { t: Date.now() - 1500, line: '[engine] pairing DITERIMA dari klien-demo' },
  { t: Date.now() - 1000, line: '[engine] track video siap — streaming' },
];

type Page = 'home' | 'connect' | 'news' | 'profile' | 'settings';

/// Lisensi pihak ketiga — data statis, ditampilkan di Pengaturan.
const LICENSES: [string, string, string][] = [
  ['Flutter SDK', 'BSD-3-Clause', 'Google'],
  ['Dart SDK', 'BSD-3-Clause', 'Google'],
  ['Next.js', 'MIT', 'Vercel'],
  ['React', 'MIT', 'Meta'],
  ['Electron', 'MIT', 'OpenJS Foundation'],
  ['Lucide Icons', 'ISC', 'Lucide Contributors'],
  ['Inter', 'SIL OFL 1.1', 'Rasmus Andersson'],
  ['flutter_riverpod', 'MIT', 'Remi Rousselet'],
  ['flutter_webrtc & libwebrtc', 'MIT / BSD-3', 'Flutter WebRTC / Google'],
  ['OneSignal SDK', 'Ketentuan OneSignal', 'OneSignal'],
  ['NVENC SDK', 'Lisensi SDK NVIDIA', 'NVIDIA'],
  ['Cloudflare Workers & D1', 'Layanan', 'Cloudflare'],
];

// Label navigasi seragam bahasa Indonesia (konsisten dengan seluruh produk:
// web & Android juga berbahasa Indonesia). Sebelumnya campur Inggris
// ("Home/Connect/News/Profile/Settings") di tengah konten Indonesia.
const NAV: { id: Page; label: string; icon: typeof Home }[] = [
  { id: 'home', label: 'Beranda', icon: Home },
  { id: 'connect', label: 'Hubungkan', icon: Cable },
  { id: 'news', label: 'Berita', icon: Newspaper },
];

const NAV_BOTTOM: { id: Page; label: string; icon: typeof Home }[] = [
  { id: 'profile', label: 'Profil', icon: User },
  { id: 'settings', label: 'Pengaturan', icon: Settings },
];

const PAGE_TITLE: Record<Page, string> = {
  home: 'Beranda',
  connect: 'Hubungkan',
  news: 'Berita',
  profile: 'Profil',
  settings: 'Pengaturan',
};

const STATE_LABEL: Record<string, { label: string; cls: string }> = {
  starting: { label: 'Memulai…', cls: 'connecting' },
  connecting: { label: 'Menghubungkan…', cls: 'connecting' },
  ready: { label: 'Siap menerima', cls: 'ready' },
  streaming: { label: 'Streaming aktif', cls: 'streaming' },
  error: { label: 'Galat', cls: 'error' },
};

function formatId(id: string): string {
  const digits = id.replace(/\D/g, '');
  return digits.length === 9 ? `${digits.slice(0, 3)} ${digits.slice(3, 6)} ${digits.slice(6, 9)}` : id;
}

/// Nama platform yang siap dibaca manusia. Client mengirim nilai mentah
/// ("android", "windows", "web"); kalau tidak dikenal, tampilkan apa adanya.
const PLATFORM_LABEL: Record<string, string> = {
  android: 'HP · Android',
  ios: 'HP · iOS',
  windows: 'PC · Windows',
  linux: 'PC · Linux',
  macos: 'Mac',
  web: 'Peramban web',
};

/// Sama seperti `identity::is_legacy_shape` di host: tanpa satu pun huruf
/// kecil, host melonggarkan verifikasinya jadi tidak peka-kasus. UI memperingatkan
/// ini supaya pengguna tahu apa yang ia korbankan.
function isLegacyShape(pw: string): boolean {
  const t = pw.trim();
  return t.length > 0 && !/[a-z]/.test(t);
}

function platformLabel(platform?: string | null): string | null {
  if (!platform) return null;
  const key = platform.trim().toLowerCase();
  return PLATFORM_LABEL[key] ?? platform.trim();
}

/// "Siapa yang sedang menonton" untuk topbar/kartu: nama perangkat + platform,
/// jatuh ke ID pairing bila client lama tidak mengirim label (ask: tampilkan
/// device hp atau pc di host).
function peerLabel(session?: { clientId: string; clientName?: string | null; clientPlatform?: string | null } | null): string {
  if (!session) return '—';
  const who = session.clientName?.trim() || session.clientId;
  const plat = platformLabel(session.clientPlatform);
  // Dipagu kurung, bukan "·": label platform sendiri sudah memuat "·"
  // ("HP · Android"), dan "Redmi Note 12 · HP · Android" terbaca seperti tiga
  // perangkat berbeda.
  return plat ? `${who} (${plat})` : `${who} (tanpa label)`;
}

/// Ikon kecil untuk membedakan HP vs PC di baris status.
function peerIcon(platform?: string | null) {
  const p = (platform || '').trim().toLowerCase();
  if (p === 'android' || p === 'ios') return Smartphone;
  if (p === 'windows' || p === 'macos' || p === 'linux') return Monitor;
  return Laptop;
}

function formatDuration(ms: number): string {
  const s = Math.floor(ms / 1000);
  const m = Math.floor(s / 60);
  const h = Math.floor(m / 60);
  const mm = String(m % 60).padStart(2, '0');
  const ss = String(s % 60).padStart(2, '0');
  return h > 0 ? `${h}:${mm}:${ss}` : `${mm}:${ss}`;
}

export default function Page() {
  const [page, setPage] = useState<Page>('home');
  const [status, setStatus] = useState<StatusPayload | null>(null);
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [flash, setFlash] = useState<string | null>(null);
  const [info, setInfo] = useState<InfoPayload | null>(null);
  const [demoReady, setDemoReady] = useState(false);
  // Identitas pemilik PC. Shell tidak pernah melihat token: yang dikirim
  // proses utama hanya { masuk, user, metode, exp, tersimpan }. Selama belum
  // masuk, seluruh aplikasi diganti layar login — host tanpa identitas adalah
  // host yang bisa dipasangi siapa saja.
  const [sesi, setSesi] = useState<AuthSessionPayload | null>(null);
  const [sesiDicek, setSesiDicek] = useState(false);

  const flashMsg = useCallback((msg: string) => {
    setFlash(msg);
    setTimeout(() => setFlash(null), 2600);
  }, []);

  // Data contoh (dan banner pratinjau) baru dipasang SETELAH mount, bukan dari
  // nilai awal `useState`. `window.xydesk` memang tidak ada saat SSR, jadi
  // kalau render pertama client langsung berbeda dari HTML server, React
  // mengamuk dengan #418 (hydration mismatch) dan seluruh subtree dibangun
  // ulang. Di dalam aplikasi Electron `DEMO` false di kedua sisi: tidak ada
  // yang berubah, hanya jeda satu frame lebih bersih.
  useEffect(() => {
    if (!DEMO) return;
    setStatus(DEMO_STATUS);
    setLogs(DEMO_LOGS);
    setDemoReady(true);
    setSesi({
      masuk: true,
      user: { id: 'demo', email: 'pratinjau@xydesk.my.id', name: 'Mode Pratinjau', picture: null },
      metode: 'email',
      exp: null,
      tersimpan: false,
    });
    setSesiDicek(true);
  }, []);

  useEffect(() => {
    if (DEMO) return;
    window.xydesk
      ?.authSession()
      .then((s) => {
        setSesi(s);
        setSesiDicek(true);
      })
      .catch(() => setSesiDicek(true));
  }, []);

  useEffect(() => {
    if (DEMO) return;
    const tick = async () => {
      try {
        const [s, l, i] = await Promise.all([
          window.xydesk!.getStatus(),
          window.xydesk!.getLogs(),
          window.xydesk!.getInfo(),
        ]);
        setStatus(s);
        setLogs(l);
        setInfo(i);
      } catch {
        /* IPC mati (app ditutup) — abaikan */
      }
    };
    tick();
    const timer = setInterval(tick, 1500);
    return () => clearInterval(timer);
  }, []);

  // Baris judul jendela + tooltip tray ikut melaporkan siapa yang menonton:
  // saat jendela ditutup ke tray, itulah satu-satunya tempat pemilik PC bisa
  // melihat bahwa layarnya sedang dilihat orang lain.
  useEffect(() => {
    if (DEMO) return;
    const sesi = status?.session;
    const hint = sesi
      ? `Dikendalikan ${peerLabel(sesi)}`
      : status?.state === 'ready'
        ? 'Menunggu pairing'
        : '';
    window.xydesk?.setHint?.(hint).catch(() => {});
  }, [status]);

  // Baris judul kita lebur jadi milik aplikasi (titleBarOverlay Electron),
  // jadi tombol caption Windows butuh tempat kosong di ujung kanan topbar.
  useEffect(() => {
    const root = document.documentElement;
    const cls = 'electron';
    if (info && info.packaged !== undefined && info.platform === 'win32') root.classList.add(cls);
    else if (info && info.platform !== 'win32') root.classList.remove(cls);
  }, [info]);

  // `extra` sengaja longgar: control API menerima bidang berbeda per aksi
  // (`password`, `index`, `volume`, `bitrateMbps`) dan proses utama meneruskan
  // JSON-nya apa adanya, jadi shell tidak perlu tahu bentuk tiap aksi.
  const runAction = async (action: string, extra: Record<string, unknown> = {}) => {
    if (DEMO) {
      flashMsg('Mode pratinjau — aksi hanya jalan di aplikasi desktop.');
      return;
    }
    try {
      const res = await window.xydesk!.runAction({ action, ...extra });
      if (res.ok) {
        if (action === 'new-password') flashMsg('Password baru dibuat.');
        if (action === 'set-password') flashMsg('Password disimpan.');
        if (action === 'stop-session')
          flashMsg(res.stopped ? 'Sesi diakhiri. Peer wajib pairing ulang.' : 'Tidak ada sesi aktif.');
        if (action === 'display-select')
          flashMsg(`Monitor sumber diganti ke indeks ${extra.index}.`);
        if (action === 'video-bitrate')
          flashMsg(`Bitrate ${extra.bitrateMbps === 0 ? 'Auto' : extra.bitrateMbps + ' Mbps'} — berlaku sesi berikutnya.`);
        if (action === 'video-quality')
          flashMsg(`Quality ${extra.quality} — Auto/Medium/High/Ultra, berlaku sesi berikutnya.`);
        if (action === 'audio-volume') flashMsg('Volume PC diubah.');
        setStatus(await window.xydesk!.getStatus());
      } else {
        flashMsg(res.error || 'Aksi gagal.');
      }
    } catch (e) {
      flashMsg(String(e));
    }
  };

  const copy = async (text: string, label: string) => {
    try {
      await navigator.clipboard.writeText(text);
      flashMsg(`${label} disalin.`);
    } catch {
      flashMsg('Gagal menyalin (izin clipboard).');
    }
  };

  const st = status;
  const pill = st && STATE_LABEL[st.state] ? STATE_LABEL[st.state] : STATE_LABEL.starting;
  const engineUp = !!st?.engine;

  // Gerbang identitas: tanpa sesi, tidak ada yang lain yang boleh tampil —
  // termasuk ID + password pairing, sebab keduanya adalah kunci ke layar ini.
  if (!sesiDicek) {
    return (
      <div className="login-shell">
        <p className="dim">Menyiapkan…</p>
      </div>
    );
  }
  if (!sesi?.masuk) {
    return (
      <LoginScreen
        onDone={(s) => {
          setSesi(s);
          flashMsg(`Selamat datang, ${s.user?.name || s.user?.email || 'pengguna'}.`);
        }}
      />
    );
  }

  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">
          {/* Logo resmi, bukan gambar tangan. `desktop/public/logo.png`
              dihasilkan `tool/gen_logo.py` dari `design/logo-asli.png` seperti
              semua aset identitas lain (lihat docs/BRAND_ASSETS.md) — dulu di
              sini ada SVG "X" bikinan sendiri sehingga shell memajang logo yang
              berbeda dari web/APK. Berkasnya ikut dibundel ke `out/`. */}
          <img className="mark" src="/logo.png" width={32} height={32} alt="Logo XyDesk" />
          <div>
            <h1>XyDesk</h1>
            <span className="sub">Host Desktop</span>
          </div>
        </div>

        <nav className="nav">
          {NAV.map(({ id, label, icon: Icon }) => (
            <button key={id} className={page === id ? 'active' : ''} onClick={() => setPage(id)}>
              <Icon size={17} />
              {label}
            </button>
          ))}
        </nav>

        <nav className="nav bottom">
          {NAV_BOTTOM.map(({ id, label, icon: Icon }) => (
            <button key={id} className={page === id ? 'active' : ''} onClick={() => setPage(id)}>
              <Icon size={17} />
              {label}
            </button>
          ))}
        </nav>

      </aside>

      <main className="main">
        {DEMO && demoReady && (
          <div className="demo-banner">
            <b>Mode pratinjau.</b> Data di bawah contoh — jalankan lewat aplikasi desktop XyDesk
            untuk melihat status engine sesungguhnya.
          </div>
        )}

        <header className="topbar">
          <h2>{PAGE_TITLE[page]}</h2>
          <div className="quick">
            {flash && <span className="flash">{flash}</span>}
            {/* Indikator sesi SENGAJA tidak ada di topbar: siapa yang sedang
                terhubung ditampilkan sebagai daftar perangkat di bawah blok
                ID + password (keputusan UI), bukan chip yang bersaing dengan
                judul halaman. Pemilik PC tetap punya sinyal itu lewat tooltip
                tray dan judul jendela (setHint di atas). */}
            <span className={`pill ${pill.cls}`}>
              <span className="dot" />
              {engineUp ? pill.label : 'Engine belum siap'}
            </span>
          </div>
        </header>

        <div className="page-body">
          {page === 'home' && (
            <HomePage status={st} onStop={() => runAction('stop-session')} />
          )}
          {page === 'connect' && (
            <ConnectPage status={st} onCopy={copy} onAction={runAction} />
          )}
          {page === 'news' && <NewsPage />}
          {page === 'profile' && (
            <ProfilePage
              status={st}
              info={info}
              sesi={sesi}
              onLogout={() => {
                window.xydesk
                  ?.authLogout()
                  .then((r) => setSesi(r.sesi ?? null))
                  .catch(() => setSesi({ masuk: false, user: null, exp: null, tersimpan: false }));
              }}
            />
          )}
          {page === 'settings' && (
            <SettingsPage
              status={st}
              info={info}
              logs={logs}
              flashMsg={flashMsg}
              onAction={runAction}
            />
          )}
        </div>
      </main>
    </div>
  );
}

/* ── Login ────────────────────────────────────────────────────────── */

/// Gerbang identitas shell: Google (browser sistem + loopback di proses utama)
/// atau email OTP. Keduanya endpoint Worker yang sama dengan web/Android, jadi
/// satu akun tetap satu identitas di semua platform.
function LoginScreen({ onDone }: { onDone: (s: AuthSessionPayload) => void }) {
  const [mode, setMode] = useState<'google' | 'email'>('google');
  const [email, setEmail] = useState('');
  const [otp, setOtp] = useState('');
  const [tahap, setTahap] = useState<'email' | 'otp'>('email');
  const [busy, setBusy] = useState(false);
  const [galat, setGalat] = useState<string | null>(null);

  const jalankan = async (fn: () => Promise<AuthResultPayload>) => {
    setBusy(true);
    setGalat(null);
    const r = await fn();
    setBusy(false);
    if (r.ok && r.sesi) onDone(r.sesi);
    else if (!r.ok) setGalat(r.message || r.error || 'Gagal masuk. Coba lagi.');
  };

  return (
    <div className="login-shell">
      <div className="login-hero">
        <div className="login-hero-top">
          <img src="/logo.png" width={36} height={36} alt="Logo" />
          <div>
            <h1>XyDesk</h1>
            <span>Remote Desktop • Low Latency</span>
          </div>
        </div>
        <div className="login-hero-main">
          <h2>Remote <span>secepat</span><br />di depan PC</h2>
          <p>Host desktop untuk gaming & kerja. Enkripsi end-to-end, NVENC hardware, dan audio loopback — semua di mesin ini.</p>
          <div className="login-hero-illust">
            <div className="row">
              <div className="dot">🖥️</div>
              <div className="txt"><strong>DXGI + GDI Fallback</strong><span>Anti hitam di VM/RDP — GetDC(0) aktif v6.7.1+</span></div>
            </div>
            <div className="row">
              <div className="dot">🔊</div>
              <div className="txt"><strong>WASAPI Loopback</strong><span>Suara PC → HP, mic HP → PC</span></div>
            </div>
            <div className="row">
              <div className="dot">⚡</div>
              <div className="txt"><strong>NVENC H264</strong><span>Hardware encode 1080p60 &lt;10ms</span></div>
            </div>
          </div>
        </div>
        <div className="login-hero-foot">
          <span>© 2026 XyDesk • Proprietary</span>
          <span>Void #0d0716 + Accent #7c3aed</span>
        </div>
      </div>

      <div className="login-form-wrap">
        <form
          className="login-card"
          onSubmit={(e) => {
            e.preventDefault();
            if (mode !== 'email') return;
            if (tahap === 'email') {
              void jalankan(() =>
                window.xydesk!.authEmailRequest(email).then((r) => {
                  if (r.ok) setTahap('otp');
                  return r;
                }),
              );
            } else {
              void jalankan(() => window.xydesk!.authEmailVerify(email, otp));
            }
          }}
        >
          <div className="logo-row">
            <img src="/logo.png" width={40} height={40} alt="Logo XyDesk" />
            <div>
              <h2>Masuk ke Host</h2>
              <p>Identitas pemilik PC</p>
            </div>
          </div>
          <p className="dim">
            Sesi disimpan terenkripsi di mesin ini (safeStorage). Token tidak pernah meninggalkan proses utama.
          </p>

          <div className="login-tabs">
            <button
              type="button"
              className={mode === 'google' ? 'active' : ''}
              onClick={() => {
                setMode('google');
                setGalat(null);
              }}
            >
              Google
            </button>
            <button
              type="button"
              className={mode === 'email' ? 'active' : ''}
              onClick={() => {
                setMode('email');
                setGalat(null);
              }}
            >
              Email
            </button>
          </div>

          {mode === 'google' ? (
            <button
              type="button"
              className="primary wide"
              disabled={busy}
              onClick={() => void jalankan(() => window.xydesk!.authGoogle())}
            >
              {busy ? 'Menunggu browser…' : 'Masuk dengan Google'}
            </button>
          ) : tahap === 'email' ? (
            <>
              <input
                type="email"
                placeholder="alamat@email.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                autoComplete="email"
                required
              />
              <button
                type="submit"
                className="primary wide"
                disabled={busy || !/^\S+@\S+\.\S+$/.test(email)}
              >
                {busy ? 'Mengirim…' : 'Kirim kode'}
              </button>
            </>
          ) : (
            <>
              <p className="dim">Kode dikirim ke {email}.</p>
              <input
                inputMode="numeric"
                placeholder="6 digit kode"
                value={otp}
                onChange={(e) => setOtp(e.target.value.replace(/\D/g, '').slice(0, 6))}
                autoComplete="one-time-code"
                required
              />
              <button type="submit" className="primary wide" disabled={busy || otp.length !== 6}>
                {busy ? 'Memverifikasi…' : 'Verifikasi'}
              </button>
              <button
                type="button"
                className="ghost wide"
                onClick={() => {
                  setTahap('email');
                  setOtp('');
                }}
              >
                Ganti email
              </button>
            </>
          )}

          {galat && <p className="danger-text">{galat}</p>}
          <p className="hint" style={{ textAlign: 'center', marginTop: 8 }}>
            Host tanpa identitas bisa dipasangi siapa saja — login wajib sebelum ID pairing terlihat.
          </p>
        </form>
      </div>
    </div>
  );
}

/* ── Home ────────────────────────────────────────────────────────── */

function HomePage({ status, onStop }: { status: StatusPayload | null; onStop: () => void }) {
  const s = status?.session;
  const v = status?.video;
  const [installingVdd, setInstallingVdd] = useState(false);
  const [vddMsg, setVddMsg] = useState<string | null>(null);

  const handleInstallVdd = async () => {
    if (DEMO || !window.xydesk?.installDriver) return;
    setInstallingVdd(true);
    setVddMsg(null);
    try {
      const res = await window.xydesk.installDriver('all');
      setVddMsg(res || 'Instalasi driver selesai.');
    } catch (e: any) {
      setVddMsg(`Gagal: ${e?.message || e}`);
    } finally {
      setInstallingVdd(false);
    }
  };
  return (
    <div className="pg">
      <section className="card">
        <h3>Status engine</h3>
        {status?.engine === false ? (
          <div>
            <p className="dim">Engine belum siap. Shell sedang menyiapkan proses host…</p>
            {status?.lastError && <p className="danger-text">Penyebab: {status.lastError}</p>}
          </div>
        ) : (
          <>
            <div className="kv-grid">
              <div className="kv">
                <span>Signaling</span>
                <strong>{status?.signalingUrl || '—'}</strong>
              </div>
              <div className="kv">
                <span>Uptime engine</span>
                <strong>{status?.uptimeMs != null ? formatDuration(status.uptimeMs) : '—'}</strong>
              </div>
              <div className="kv">
                <span>Backend capture</span>
                <strong title="Hasil pengukuran watchdog, bukan preferensi">
                  {status?.captureBackend || '—'}
                </strong>
              </div>
              <div className="kv">
                <span>Frame tertangkap</span>
                <strong>
                  {status?.framesCaptured != null ? status.framesCaptured.toLocaleString('id-ID') : '—'}
                </strong>
              </div>
            </div>
            {/* RDP session warning — penyebab #1 hitam di lab Actions */}
            {status?.isRdpSession && (
              <div className="vm-warning" style={{ marginTop: 14, background: 'linear-gradient(135deg, rgba(124,58,237,0.12), rgba(167,139,250,0.12))' }}>
                <span className="icon">🖥️</span>
                <div className="text">
                  <strong>RDP session terdeteksi (SM_REMOTESESSION=1) — ini lab Actions?</strong><br />
                  DXGI tidak jalan di RDP, tutup RDP = lock = hitam total (BitBlt 0).<br />
                  Cara tes benar XyDesk di lab:<br />
                  • Setup ID + password di RDP, lalu <code>tscon %SESSIONNAME% /dest:console</code> atau klik <code>Disconnect-tanpa-lock.bat</code> di Desktop<br />
                  • Baru konek via XyDesk (bukan RDP) — capture akan jalan via GDI fallback <code>GetDC(0)</code><br />
                  • Jangan login sebagai <code>runneradmin</code> — itu bunuh job Actions
                </div>
              </div>
            )}
            {/* Virtual Display Driver — seperti AnyDesk/RustDesk */}
            {status?.virtualDisplay && (
              <div className="vm-warning" style={{ marginTop: 14, background: status.virtualDisplay.installed ? 'linear-gradient(135deg, rgba(22,115,71,0.10), rgba(22,115,71,0.06))' : 'linear-gradient(135deg, rgba(124,58,237,0.14), rgba(91,33,182,0.10))' }}>
                <span className="icon">{status.virtualDisplay.installed ? '✅' : '🖥️'}</span>
                <div className="text">
                  <strong>Virtual Display Driver: {status.virtualDisplay.installed ? 'Terpasang (seperti AnyDesk)' : 'Belum terpasang'}</strong><br />
                  {status.virtualDisplay.needed ? (
                    <>
                      Headless/RDP terdeteksi — butuh driver biar tidak hitam seperti AnyDesk.<br />
                      Status: {status.virtualDisplay.installed ? 'Driver ada, DISPLAY virtual seharusnya muncul' : 'Driver belum ada'} • Admin: {status.virtualDisplay.isAdmin ? 'Ya' : 'Bukan (butuh admin untuk install)'}<br />
                      {!status.virtualDisplay.installed && (
                        <>
                          Install: <code>host/driver/install.ps1</code> (PowerShell admin) atau download dari <code>github.com/itsmikethetech/Virtual-Display-Driver</code><br />
                          Atau Scoop: <code>scoop install idd-sample-driver</code> • Setelah install, restart XyDesk
                          <div style={{ marginTop: 8 }}>
                            <button
                              type="button"
                              className="btn primary mini"
                              disabled={installingVdd}
                              onClick={handleInstallVdd}
                            >
                              {installingVdd ? '⏳ Memasang Driver…' : '⚙️ Pasang Driver Virtual (1-Klik Admin)'}
                            </button>
                            {vddMsg && <p style={{ marginTop: 4, fontSize: 12, color: '#8b5cf6' }}>{vddMsg}</p>}
                          </div>
                        </>
                      )}
                    </>
                  ) : (
                    <>Tidak butuh driver — {status?.displays?.list?.length ?? 0} monitor terdeteksi, capture jalan normal</>
                  )}
                </div>
              </div>
            )}
            {/* VM headless warning — hitam tapi tersambung */}
            {status?.framesCaptured === 0 && (status?.uptimeMs ?? 0) > 8000 && (
              <div className="vm-warning" style={{ marginTop: 14 }}>
                <span className="icon">⚠️</span>
                <div className="text">
                  <strong>Belum ada frame — kemungkinan VM tanpa display aktif.</strong><br />
                  Host mendeteksi {status?.displays?.list?.length ?? 0} monitor. Di GPU VM (Paperspace, RunPod, Vast) atau sesi RDP terkunci,
                  Windows tidak punya desktop yang bisa di-capture. Solusi:<br />
                  • Pasang <code>virtual display driver</code> (iddSampleDriver) atau colok HDMI dummy<br />
                  • Pastikan sesi tidak terkunci (Win+L = hitam) dan tidak lewat RDP headless<br />
                  • Backend sekarang: <code>{status?.captureBackend || 'mencoba...'}</code> — fallback GDI <code>GetDC(0)</code> sudah aktif di v6.7.1+
                  {status?.isRdpSession && ' — RDP terdeteksi, ini yang bikin hitam di lab!'}
                </div>
              </div>
            )}
            {status?.lastError && <p className="danger-text">Kendala terakhir: {status.lastError}</p>}
          </>
        )}
      </section>

      <section className="card">
        <h3>Sesi aktif</h3>
        {s ? (
          <>
            <div className="kv-grid">
              <div className="kv wide">
                <span>Perangkat pengendali</span>
                <strong title={peerLabel(s)}>{peerLabel(s)}</strong>
              </div>
              <div className="kv">
                <span>ID pairing</span>
                <strong>{s.clientId}</strong>
              </div>
              <div className="kv">
                <span>Durasi</span>
                <strong>{formatDuration(s.durationMs)}</strong>
              </div>
            </div>
            <p className="hint">
              Nama dan jenis perangkat dilaporkan sendiri oleh HP/PC yang terhubung — host hanya
              menampilkannya, tidak memakainya untuk memutuskan akses. Kalau kosong, client-nya
              versi lama yang belum mengirim label.
            </p>
            <div className="stat-row four">
              <div className="stat">
                <span className="k">FPS kirim</span>
                <span className="v">{v ? Math.round(v.fps) : '—'}</span>
              </div>
              <div className="stat">
                <span className="k">Frame</span>
                <span className="v">{v ? v.framesSent.toLocaleString('id-ID') : '—'}</span>
              </div>
              <div className="stat">
                <span className="k">Encoder</span>
                <span className="v">{v?.encoder ? v.encoder.toUpperCase() : v?.nvenc ? 'NVENC' : 'Software'}</span>
              </div>
              {/* Latensi pipeline host (capture -> tulis RTP). Angka KECIL di
                  sini bukan berarti nyaman: bolak-balik jala belum termasuk. */}
              <div className="stat">
                <span className="k">Latensi host</span>
                <span className="v">{v?.latencyMs != null ? `${v.latencyMs.toFixed(1)} ms` : '—'}</span>
              </div>
              <div className="stat">
                <span className="k">Monitor</span>
                <span className="v">
                  {status?.displays?.list?.length ? `#${(status.displays.wanted ?? 0) + 1}` : '—'}
                </span>
              </div>
            </div>
            <button className="danger" onClick={onStop}>
              <Power size={15} /> Akhiri sesi
            </button>
          </>
        ) : (
          <p className="dim">
            Menunggu koneksi. Buka aplikasi XyDesk di HP, lalu ketik ID + password dari halaman
            Connect. Hanya satu sesi yang bisa berjalan — koneksi kedua akan ditolak otomatis.
          </p>
        )}
      </section>
    </div>
  );
}

/* ── Connect ──────────────────────────────────────────────────────── */

function ConnectPage({
  status,
  onCopy,
  onAction,
}: {
  status: StatusPayload | null;
  onCopy: (text: string, label: string) => void;
  onAction: (action: string, extra?: Record<string, unknown>) => void;
}) {
  const [showPw, setShowPw] = useState(false);
  const [customPw, setCustomPw] = useState('');
  const [popover, setPopover] = useState(false);
  const popoverRef = useRef<HTMLDivElement | null>(null);

  // Popover menutup saat klik jatuh di luar panel atau Esc ditekan — perilaku
  // yang orang harapkan dari popover, tanpa library tambahan.
  useEffect(() => {
    if (!popover) return;
    const klik = (e: MouseEvent) => {
      if (popoverRef.current && !popoverRef.current.contains(e.target as Node)) setPopover(false);
    };
    const esc = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setPopover(false);
    };
    document.addEventListener('mousedown', klik);
    document.addEventListener('keydown', esc);
    return () => {
      document.removeEventListener('mousedown', klik);
      document.removeEventListener('keydown', esc);
    };
  }, [popover]);

  // Engine melaporkan satu sesi berjalan; dibungkus array supaya daftar ini
  // siap bila host suatu saat menerima lebih dari satu peer.
  const sesiList = status?.session ? [status.session] : [];

  return (
    <div className="pg">
      <section className="card">
        <h3>Perangkat ini</h3>
        <div className="id-row">
          <span className="id">{status?.deviceId ? formatId(status.deviceId) : '— — — — — — —'}</span>
          <button
            className="ghost"
            disabled={!status?.deviceId}
            onClick={() => status?.deviceId && onCopy(status.deviceId, 'ID')}
          >
            <ClipboardCopy size={14} /> Salin
          </button>
        </div>
        <div className="pw-row">
          <span className="pw">
            {status?.password ? (showPw ? status.password : '•'.repeat(status.password.length)) : '••••••••'}
          </span>
          <button className="ghost" disabled={!status?.password} onClick={() => setShowPw((v) => !v)}>
            {showPw ? <EyeOff size={14} /> : <Eye size={14} />} {showPw ? 'Sembunyikan' : 'Lihat'}
          </button>
          {/* Semua pengaturan password hidup DI baris ini sebagai popover —
              bukan seksi terpisah di bawah, supaya konteksnya tidak lepas
              dari password yang sedang dilihat. */}
          <div className="pw-anchor" ref={popoverRef}>
            <button
              className="ghost"
              disabled={!status?.password}
              onClick={() => setPopover((v) => !v)}
              title="Atur password pairing"
            >
              <Settings size={14} /> Atur
            </button>
            {popover && (
              <div className="popover">
                <div className="pop-row">
                  <button
                    disabled={!status?.engine}
                    onClick={() => {
                      onAction('new-password');
                      setPopover(false);
                    }}
                  >
                    <RefreshCw size={14} /> Password acak baru
                  </button>
                  <button
                    disabled={!status?.password}
                    onClick={() => status?.password && onCopy(status.password, 'Password')}
                  >
                    <ClipboardCopy size={14} /> Salin password
                  </button>
                </div>
                <div className="set-row">
                  <input
                    type="text"
                    placeholder="Password kustom (min. 6 karakter)"
                    value={customPw}
                    onChange={(e) => setCustomPw(e.target.value)}
                    autoCapitalize="none"
                    autoCorrect="off"
                    spellCheck={false}
                    autoComplete="off"
                  />
                  <button
                    className="primary"
                    disabled={customPw.trim().length < 6}
                    onClick={() => {
                      onAction('set-password', { password: customPw });
                      setCustomPw('');
                      setPopover(false);
                    }}
                  >
                    Simpan
                  </button>
                </div>
                {customPw.trim().length >= 6 && isLegacyShape(customPw) && (
                  <p className="danger-text">
                    Tanpa huruf kecil, host memperlakukannya sebagai password lama: besar-kecil
                    TIDAK dihitung dan ruang tebakannya turun. Tambahkan huruf kecil.
                  </p>
                )}
                <p className="hint">
                  Min. 6 karakter, bebas huruf besar/kecil/angka/spasi. Besar-kecil dihitung:{' '}
                  <code>KopiPagi2026</code> dan <code>kopipagi2026</code> adalah dua password
                  berbeda. Mengganti password tidak memutus sesi yang sedang berjalan.
                </p>
              </div>
            )}
          </div>
        </div>
        <p className="hint">
          Ketik ID dan password ini di aplikasi XyDesk di HP untuk menghubungkan ke layar ini.
          Bila sesi sedang berjalan, percobaan koneksi lain akan ditolak meski passwordnya benar.
        </p>
      </section>

      <section className="card">
        <h3>Perangkat terhubung</h3>
        {sesiList.length === 0 ? (
          <p className="dim">Belum ada perangkat yang mengendalikan PC ini.</p>
        ) : (
          <ul className="device-list">
            {sesiList.map((ss) => {
              const Icon = peerIcon(ss.clientPlatform);
              return (
                <li className="device-row" key={ss.clientId}>
                  <Icon size={16} aria-hidden="true" />
                  <div className="who">
                    <strong>Device {ss.clientName || ss.clientId}</strong>
                    <span>
                      {platformLabel(ss.clientPlatform) || 'Platform tidak dikenal'} ·{' '}
                      {formatDuration(ss.durationMs)}
                    </span>
                  </div>
                  <span className="live-dot" title="Sesi aktif" />
                </li>
              );
            })}
          </ul>
        )}
        <p className="hint">
          Nama dan jenis perangkat dilaporkan sendiri oleh HP/PC yang terhubung — host hanya
          menampilkannya. Hanya satu sesi yang bisa berjalan; koneksi kedua ditolak otomatis.
        </p>
      </section>
    </div>
  );
}

/* ── News ─────────────────────────────────────────────────────────── */

function NewsPage() {
  const [category, setCategory] = useState<string>('semua');
  const [posts, setPosts] = useState<NewsPost[] | null>(null);
  const [error, setError] = useState('');
  const [open, setOpen] = useState<NewsPost | null>(null);
  const [retry, setRetry] = useState(0);

  useEffect(() => {
    let alive = true;
    setPosts(null);
    setError('');
    fetchNewsList(category)
      .then((r) => {
        if (alive) setPosts(r.posts);
      })
      .catch((e) => {
        if (alive)
          setError(
            e instanceof Error && e.message !== 'Failed to fetch'
              ? e.message
              : 'Gagal memuat berita — periksa koneksi internet.',
          );
      });
    return () => {
      alive = false;
    };
  }, [category, retry]);

  if (open) return <NewsDetail post={open} onBack={() => setOpen(null)} />;

  return (
    <div className="pg">
      <div className="news-cats">
        {NEWS_CATEGORIES.map((c) => (
          <button key={c} className={category === c ? 'active' : ''} onClick={() => setCategory(c)}>
            {c === 'semua' ? 'Semua' : c}
          </button>
        ))}
      </div>
      {error && (
        <div className="news-error">
          <p className="danger-text">{error}</p>
          <div className="set-row">
            <button className="ghost" onClick={() => setRetry((n) => n + 1)}>
              <RefreshCw size={14} /> Coba lagi
            </button>
            <a
              className="btn-ghost-link"
              href="https://app.xydesk.my.id/news"
              target="_blank"
              rel="noreferrer"
            >
              <ExternalLink size={14} /> Buka di web
            </a>
          </div>
        </div>
      )}
      {!posts && !error && (
        <div className="news-list">
          {[0, 1, 2].map((i) => (
            <div className="news-card sk" key={i}>
              <div className="sk-cover" />
              <div className="sk-line" style={{ width: '70%' }} />
              <div className="sk-line" style={{ width: '100%' }} />
            </div>
          ))}
        </div>
      )}
      {posts && posts.length === 0 && <p className="dim">Belum ada berita di kategori ini.</p>}
      {posts && posts.length > 0 && (
        <div className="news-list">
          {posts.map((p) => (
            <article className="news-card" key={p.slug} onClick={() => setOpen(p)}>
              <img className="news-cover" src={p.cover} alt="" loading="lazy" />
              <div className="news-info">
                <span className="news-cat">{p.category}</span>
                <h4>{p.title}</h4>
                <p>{p.excerpt}</p>
                <span className="news-meta">
                  {formatNewsDate(p.createdAt)} · ♥ {p.likeCount} · 💬 {p.commentCount}
                </span>
              </div>
            </article>
          ))}
        </div>
      )}
    </div>
  );
}

function NewsDetail({ post, onBack }: { post: NewsPost; onBack: () => void }) {
  const [data, setData] = useState<{ post: NewsPost; comments: NewsComment[] } | null>(null);
  const [likeCount, setLikeCount] = useState(post.likeCount);
  const [liked, setLiked] = useState(localStorage.getItem(`xydesk.desktop.liked.${post.slug}`) === '1');
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState('');
  const [replyTo, setReplyTo] = useState<NewsComment | null>(null);
  const [email, setEmail] = useState('');
  const [subBusy, setSubBusy] = useState(false);

  useEffect(() => {
    let alive = true;
    fetchNewsPost(post.slug)
      .then((r) => {
        if (alive) setData(r);
      })
      .catch(() => {});
    return () => {
      alive = false;
    };
  }, [post.slug]);

  // Like OPTIMISTIK: UI berubah seketika, server menyusul.
  const like = () => {
    if (busy) return;
    const target = !liked;
    setLiked(target);
    setLikeCount((n) => n + (target ? 1 : -1));
    toggleLike(post.slug)
      .then((r) => {
        setLiked(r.liked);
        setLikeCount(r.likeCount);
        localStorage.setItem(`xydesk.desktop.liked.${post.slug}`, r.liked ? '1' : '0');
      })
      .catch((e) => {
        setLiked(!target);
        setLikeCount((n) => n + (target ? -1 : 1));
        setNotice(e instanceof Error ? e.message : 'Gagal memproses like.');
      });
  };

  const submit = async () => {
    if (text.trim().length < 2) return;
    setBusy(true);
    setNotice('');
    try {
      // Username acak per instalasi — tanpa kolom nama manual.
      const r = await postComment(post.slug, text.trim(), replyTo?.id ?? null);
      setData((d) => (d ? { post: d.post, comments: [...d.comments, r.comment] } : d));
      setText('');
      setReplyTo(null);
      setNotice('Komentar terkirim.');
    } catch (e) {
      setNotice(e instanceof Error ? e.message : 'Gagal mengirim komentar.');
    } finally {
      setBusy(false);
    }
  };

  const subscribe = async () => {
    if (!email.includes('@') || subBusy) return;
    setSubBusy(true);
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

  const share = async () => {
    const url = `${NEWS_SHARE_BASE}/${post.slug}`;
    try {
      await navigator.clipboard.writeText(url);
      setNotice('Tautan berbagi disalin — tempel ke media sosial.');
    } catch {
      setNotice(url);
    }
  };

  const p = data?.post ?? post;
  const comments = data?.comments ?? [];
  const topLevel = comments.filter((c) => c.parentId == null);

  return (
    <div className="pg news-detail">
      <button className="back" onClick={onBack}>
        ← Semua berita
      </button>
      <article className="card post-card">
        <img className="post-cover" src={p.cover} alt="" />
        <span className="news-cat">{p.category}</span>
        <h3 className="post-title">{p.title}</h3>
        <p className="post-meta">
          {p.author} · {formatNewsDate(p.createdAt)}
        </p>
        <div className="post-actions">
          <button className={`like ${liked ? 'liked' : ''}`} disabled={busy} onClick={like}>
            <Heart size={15} fill={liked ? 'currentColor' : 'none'} /> {likeCount}
          </button>
          <button className="share" onClick={share}>
            <Share2 size={15} /> Bagikan
          </button>
        </div>
        <div className="post-body">
          {p.content.split(/\n\n+/).map((para, i) => {
            const img = NEWS_IMAGE_BLOCK.exec(para.trim());
            if (img) {
              return (
                <figure key={i}>
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={img[2]} alt={img[1]} loading="lazy" />
                  {img[1] && <figcaption>{img[1]}</figcaption>}
                </figure>
              );
            }
            return <p key={i}>{para}</p>;
          })}
        </div>

        <div className="comments">
          <h4>Komentar ({comments.length})</h4>
          <div className="comment-form">
            {replyTo && (
              <div className="reply-banner">
                <span>
                  Membalas <strong>{replyTo.author}</strong>
                </span>
                <button onClick={() => setReplyTo(null)}>×</button>
              </div>
            )}
            <textarea
              placeholder="Tulis komentar…"
              maxLength={1000}
              rows={3}
              value={text}
              onChange={(e) => setText(e.target.value)}
            />
            {notice && <p className="hint">{notice}</p>}
            <button className="primary" disabled={busy || text.trim().length < 2} onClick={submit}>
              {busy ? 'Mengirim…' : 'Kirim komentar'}
            </button>
          </div>
          <div className="comment-list">
            {comments.length === 0 && <p className="hint">Belum ada komentar.</p>}
            {topLevel.map((c) => {
              const replies = comments.filter((r) => r.parentId === c.id);
              return (
                <div className="comment" key={c.id}>
                  <div className="comment-head">
                    <strong>{c.author}</strong>
                    <span>{formatNewsDate(c.createdAt)}</span>
                  </div>
                  <p>{c.content}</p>
                  <button className="reply-link" onClick={() => { setReplyTo(c); setNotice(''); }}>
                    Balas
                  </button>
                  {replies.length > 0 && (
                    <div className="replies">
                      {replies.map((r) => (
                        <div className="reply" key={r.id}>
                          <div className="comment-head">
                            <strong>{r.author}</strong>
                            <span>{formatNewsDate(r.createdAt)}</span>
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
        </div>

        <div className="subscribe-box">
          <h4>Berita lewat email</h4>
          <p className="hint">Artikel baru dikirim langsung ke email kamu.</p>
          <div className="subscribe-row">
            <input
              type="email"
              placeholder="alamat@email.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
            <button className="primary" onClick={subscribe} disabled={subBusy}>
              {subBusy ? 'Mendaftar…' : 'Langganan'}
            </button>
          </div>
        </div>
      </article>
    </div>
  );
}

/* ── Profile ──────────────────────────────────────────────────────── */

function ProfilePage({
  status,
  info,
  sesi,
  onLogout,
}: {
  status: StatusPayload | null;
  info: InfoPayload | null;
  sesi: AuthSessionPayload | null;
  onLogout: () => void;
}) {
  return (
    <div className="pg">
      <section className="card">
        <h3>Akun</h3>
        <div className="kv-grid">
          <div className="kv wide">
            <span>Masuk sebagai</span>
            <strong>{sesi?.user?.email || '—'}</strong>
          </div>
          <div className="kv">
            <span>Metode</span>
            <strong>
              {sesi?.metode === 'google' ? 'Google' : sesi?.metode === 'email' ? 'Email OTP' : '—'}
            </strong>
          </div>
        </div>
        <div className="set-row">
          <button className="danger" onClick={onLogout}>
            <LogOut size={14} /> Keluar dari akun ini
          </button>
        </div>
        <p className="hint">
          Keluar tidak mematikan engine maupun sesi yang sedang berjalan — hanya identitas di
          shell ini yang dilepas.
        </p>
      </section>

      <section className="card">
        <h3>Perangkat host</h3>
        <div className="kv-grid">
          <div className="kv">
            <span>ID perangkat</span>
            <strong>{status?.deviceId ? formatId(status.deviceId) : '—'}</strong>
          </div>
          <div className="kv">
            <span>Nama host</span>
            <strong>XyDesk Host</strong>
          </div>
          <div className="kv">
            <span>Encoder video</span>
            <strong>{status?.video?.nvenc ? 'NVENC (hardware)' : 'Software (cadangan)'}</strong>
          </div>
          <div className="kv">
            <span>Sumber video</span>
            <strong>DXGI Desktop Duplication</strong>
          </div>
        </div>
      </section>

      <section className="card">
        <h3>Aplikasi</h3>
        <div className="kv-grid">
          <div className="kv">
            <span>Versi shell</span>
            <strong>v{info?.appVersion || '—'}</strong>
          </div>
          <div className="kv">
            <span>Mode</span>
            <strong>{info?.packaged ? 'Terpasang' : 'Pengembangan'}</strong>
          </div>
          <div className="kv">
            <span>Signaling</span>
            <strong>{info?.signalingHttp || '—'}</strong>
          </div>
          <div className="kv">
            <span>Media</span>
            <strong>Peer-to-peer (WebRTC)</strong>
          </div>
        </div>
        <div className="set-row">
          <a className="btn-ghost-link" href="https://github.com/xykalnotkel/XyDesk" target="_blank" rel="noreferrer">
            <ExternalLink size={14} /> GitHub
          </a>
          <a className="btn-ghost-link" href="https://app.xydesk.my.id/news" target="_blank" rel="noreferrer">
            <ExternalLink size={14} /> Berita di Web
          </a>
        </div>
      </section>
    </div>
  );
}

/* ── Settings ─────────────────────────────────────────────────────── */

function fmtBytes(n: number | null | undefined): string {
  if (n == null || n <= 0) return '—';
  const mb = n / 1_000_000;
  return mb >= 100 ? `${Math.round(mb)} MB` : `${mb.toFixed(1)} MB`;
}

function UpdateCard({
  info,
  flashMsg,
}: {
  info: InfoPayload | null;
  flashMsg: (m: string) => void;
}) {
  const [st, setSt] = useState<UpdateStatusPayload | null>(null);
  const [phase, setPhase] = useState<'idle' | 'checking' | 'downloading' | 'opening' | 'error'>(
    'idle',
  );
  const [error, setError] = useState('');

  const check = useCallback(async () => {
    if (DEMO) {
      flashMsg('Mode pratinjau — pembaruan hanya di aplikasi desktop.');
      return;
    }
    setPhase('checking');
    setError('');
    try {
      const r = await window.xydesk!.checkUpdate();
      setSt(r);
      setPhase('idle');
      if (!r.updateAvailable) flashMsg(`Sudah versi terbaru (v${r.currentVersion}).`);
    } catch (e) {
      setPhase('error');
      setError(e instanceof Error ? e.message : String(e));
    }
  }, [flashMsg]);

  useEffect(() => {
    if (!DEMO) void check();
  }, [check]);

  const install = async () => {
    setPhase('downloading');
    setError('');
    try {
      // Unduh + verifikasi SHA-256 di proses utama, lalu…
      const path = await window.xydesk!.downloadUpdate();
      setPhase('opening');
      flashMsg('Installer terverifikasi — membukanya sekarang.');
      // …installer dibuka dan aplikasi keluar sendiri. Janji ini tidak
      // pernah resolve; kalau resolve berarti gagal membuka.
      await window.xydesk!.installUpdate(path);
      setPhase('error');
      setError('Installer tidak terbuka. Coba unduh manual dari GitHub Releases.');
    } catch (e) {
      setPhase('error');
      setError(e instanceof Error ? e.message : String(e));
    }
  };

  const busy = phase === 'checking' || phase === 'downloading' || phase === 'opening';
  const current = st?.currentVersion ?? info?.appVersion ?? '—';

  return (
    <section className="card">
      <h3>Pembaruan aplikasi</h3>
      <div className="kv">
        <span>Versi terpasang</span>
        <strong>v{current}</strong>
      </div>
      {st && (
        <div className="kv">
          <span>Versi terbaru</span>
          <strong>v{st.latestVersion}</strong>
        </div>
      )}
      {st?.updateAvailable && (
        <>
          <ul className="update-notes">
            {st.notes.map((n, i) => (
              <li key={i}>{n}</li>
            ))}
          </ul>
          <p className="hint">
            {st.assetName} ({fmtBytes(st.assetBytes)}) — terverifikasi SHA-256 sebelum
            dipasang. Installer meminta izin admin (UAC), lalu aplikasi dimulai ulang.
          </p>
        </>
      )}
      {phase === 'error' && error && <p className="form-error">{error}</p>}
      {phase === 'downloading' && <p className="hint">Mengunduh installer terverifikasi…</p>}
      {phase === 'opening' && <p className="hint">Membuka installer…</p>}
      <div className="row-actions">
        <button className="ghost" onClick={() => void check()} disabled={busy}>
          {phase === 'checking' ? 'Memeriksa…' : 'Periksa pembaruan'}
        </button>
        {st?.updateAvailable && (
          <button className="primary" onClick={() => void install()} disabled={busy}>
            {phase === 'downloading'
              ? 'Mengunduh…'
              : phase === 'opening'
                ? 'Membuka installer…'
                : `Unduh & pasang v${st.latestVersion}`}
          </button>
        )}
      </div>
    </section>
  );
}

function SettingsPage({
  status,
  info,
  logs,
  flashMsg,
  onAction,
}: {
  status: StatusPayload | null;
  info: InfoPayload | null;
  logs: LogEntry[];
  flashMsg: (m: string) => void;
  onAction: (action: string, extra?: Record<string, unknown>) => void;
}) {
  const [autostart, setAutostart] = useState(false);
  const [busy, setBusy] = useState(false);
  const displays = status?.displays;
  const daftarMonitor = displays?.list ?? [];
  const bitrateMbps = status?.targetBitrateBps ? Math.round(status.targetBitrateBps / 1_000_000) : null;
  const [bps, setBps] = useState<string>(bitrateMbps ? String(bitrateMbps) : '0');
  const [quality, setQuality] = useState<string>('auto');
  const volume = status?.audio?.volume ?? null;
  const [vol, setVol] = useState<number>(volume == null ? 60 : Math.round(volume * 100));
  const [installingDriver, setInstallingDriver] = useState(false);
  const [driverInstallMsg, setDriverInstallMsg] = useState<string | null>(null);

  const handleInstallDriver = async (driverType: string = 'all') => {
    if (DEMO || !window.xydesk?.installDriver) {
      flashMsg('Pemasangan driver hanya dapat dijalankan di aplikasi desktop Windows.');
      return;
    }
    setInstallingDriver(true);
    setDriverInstallMsg(null);
    try {
      const res = await window.xydesk.installDriver(driverType);
      setDriverInstallMsg(res || 'Proses instalasi driver selesai.');
      flashMsg('Instalasi driver diproses.');
    } catch (err: any) {
      const msg = err?.message || String(err);
      setDriverInstallMsg(`Gagal: ${msg}`);
      flashMsg(`Gagal: ${msg}`);
    } finally {
      setInstallingDriver(false);
    }
  };
  useEffect(() => {
    // Jangan timpa angka yang sedang digeser pengguna dengan nilai hasil polling.
    if (volume != null && Math.round(volume * 100) !== volRef.current) setVol(Math.round(volume * 100));
  }, [volume]);
  const volRef = useRef(vol);
  volRef.current = vol;
  const logScroll = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (DEMO) return;
    window.xydesk!.getAutostart().then(setAutostart).catch(() => {});
  }, []);

  useEffect(() => {
    const el = logScroll.current;
    if (el) el.scrollTop = el.scrollHeight;
  }, [logs]);

  const toggleAutostart = async () => {
    if (DEMO) {
      flashMsg('Mode pratinjau — setelan hanya jalan di aplikasi desktop.');
      return;
    }
    setBusy(true);
    try {
      const r = await window.xydesk!.setAutostart(!autostart);
      if (r.ok) {
        setAutostart(r.enabled ?? !autostart);
        flashMsg(r.enabled ? 'XyDesk akan berjalan saat Windows mulai.' : 'Autostart dimatikan.');
      } else {
        flashMsg(r.error || 'Gagal mengubah autostart.');
      }
    } finally {
      setBusy(false);
    }
  };

  const restart = async () => {
    if (DEMO) {
      flashMsg('Mode pratinjau — restart engine hanya di aplikasi desktop.');
      return;
    }
    setBusy(true);
    try {
      const r = await window.xydesk!.restartEngine();
      flashMsg(r.restarted ? 'Engine dimulai ulang.' : 'Engine tidak sedang berjalan.');
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="pg">
      <UpdateCard info={info} flashMsg={flashMsg} />
      <section className="card">
        <h3>Umum</h3>
        <label className="switch-row">
          <div>
            <strong>Mulai dengan Windows</strong>
            <span className="hint">Shell dan engine host menyala otomatis saat login.</span>
          </div>
          <button
            role="switch"
            aria-checked={autostart}
            className={`switch ${autostart ? 'on' : ''}`}
            onClick={toggleAutostart}
            disabled={busy}
          >
            <span className="knob" />
          </button>
        </label>
      </section>

      <section className="card">
        <h3>Engine</h3>
        <div className="kv-grid">
          <div className="kv">
            <span>Status</span>
            <strong>{status?.engine === false ? 'Belum siap' : 'Berjalan'}</strong>
          </div>
          <div className="kv">
            <span>Koneksi</span>
            <strong>{status?.signalingUrl || '—'}</strong>
          </div>
        </div>
        <div className="set-row">
          <button onClick={restart} disabled={busy}>
            <RefreshCw size={14} /> Mulai ulang engine
          </button>
        </div>
        <p className="hint">
          Engine dimulai ulang dengan token signaling baru. Sesi yang sedang berjalan akan putus.
        </p>
      </section>

      {/* Dua kartu berikut menutup lubang yang cukup aneh: engine SUDAH
          mendukung `display-select`, `video-bitrate`, dan `audio-volume` lewat
          control API (dan `/status` bahkan melaporkan nilainya), tetapi shell
          tidak pernah punya kendalinya — pemilik PC harus pindah monitor atau
          menurunkan bitrate dari HP-nya. */}
      <section className="card">
        <h3>Tampilan &amp; kualitas</h3>
        {daftarMonitor.length > 1 ? (
          <>
            <span className="field-label">Monitor sumber</span>
            <div className="chip-row">
              {daftarMonitor.map((d) => (
                <button
                  key={d.index}
                  className={`chip select${displays?.wanted === d.index ? ' on' : ''}`}
                  onClick={() => onAction('display-select', { index: d.index })}
                  title={d.name}
                >
                  {d.index === 0 ? 'Utama' : `#${d.index + 1}`} · {d.width}×{d.height}
                </button>
              ))}
            </div>
            <p className="hint">
              Dipakai untuk sesi berikutnya. Client juga bisa memindah monitor lewat daftar
              display di layarnya — nilai di atas hanya mengikuti yang terakhir dipilih.
            </p>
          </>
        ) : (
          <p className="dim">
            {daftarMonitor.length === 1
              ? 'Satu monitor terdeteksi — tidak ada yang perlu dipilih.'
              : 'Daftar monitor belum tersedia (engine belum siap, atau platform ini tidak mendukung enumerasi monitor).'}
          </p>
        )}

        <span className="field-label">Quality preset — Auto, Medium, High, Ultra (Founder request)</span>
        <div className="chip-row">
          {[
            { id: 'auto', label: 'Auto', bps: 0, desc: 'Adaptive' },
            { id: 'medium', label: 'Medium', bps: 8, desc: '720p' },
            { id: 'high', label: 'High', bps: 15, desc: '1080p' },
            { id: 'ultra', label: 'Ultra', bps: 25, desc: '1440p' },
          ].map((q) => (
            <button
              key={q.id}
              className={`chip select${quality === q.id ? ' on' : ''}`}
              onClick={() => {
                setQuality(q.id);
                setBps(String(q.bps));
                onAction('video-quality', { quality: q.id });
              }}
              title={q.desc}
            >
              {q.label}
            </button>
          ))}
        </div>
        <p className="hint">Auto = adaptive to network, Medium = 720p ~8 Mbps, High = 1080p ~15 Mbps, Ultra = 1440p ~25-50 Mbps — controlled from host & session screen.</p>

        <span className="field-label">Bitrate — Auto / Manual (0=Auto)</span>
        <div className="chip-row">
          {[0, 8, 15, 25, 50].map((m) => (
            <button
              key={m}
              className={`chip select${bitrateMbps === m ? ' on' : ''}`}
              onClick={() => {
                setBps(String(m));
                onAction('video-bitrate', { bitrateMbps: m });
              }}
            >
              {m === 0 ? 'Auto' : `${m} Mbps`}
            </button>
          ))}
          <span className="chip">
            <input
              className="mini"
              type="number"
              min={0}
              max={60}
              value={bps}
              onChange={(e) => setBps(e.target.value)}
              aria-label="Bitrate custom Mbps, 0=Auto"
            />
            <button
              className="ghost tiny"
              disabled={!/^(0|[1-9][0-9]?)$/.test(bps.trim())}
              onClick={() => onAction('video-bitrate', { bitrateMbps: Number(bps.trim()) })}
            >
              Pakai
            </button>
          </span>
        </div>
        <p className="hint">
          Sekarang {bitrateMbps != null ? (bitrateMbps === 0 ? 'Auto' : `${bitrateMbps} Mbps`) : '—'} ≈{' '}
          {bitrateMbps != null ? (bitrateMbps === 0 ? 'adaptive' : `${((bitrateMbps * 450) / 1000).toFixed(1)} MB/jam`) : '—'}.
          Auto = host decides. Turunkan kalau tethering, naikkan kalau patah. Berlaku sesi berikutnya & di session screen.
        </p>
      </section>

      <section className="card">
        <h3>Audio</h3>
        {status?.audio ? (
          <>
            <div className="kv-grid">
              <div className="kv">
                <span>Suara PC ke HP</span>
                <strong>{status.audio.captureAvailable ? status.audio.pipeline : 'Tidak tersedia'}</strong>
              </div>
              <div className="kv">
                <span>Mic HP ke PC</span>
                <strong>{status.audio.micAvailable ? status.audio.micPipeline : 'Tidak ada mic'}</strong>
              </div>
            </div>
            {status.audio.outputs === 0 && (
              <div className="vm-warning" style={{ marginTop: 14 }}>
                <span className="icon">🔇</span>
                <div className="text">
                  <strong>Tidak ada perangkat audio terdeteksi — ini VM/GPU VM?</strong><br />
                  WASAPI butuh output device aktif. Di VM tanpa sound card, loopback & mic akan mati.<br />
                  Solusi: install <code>VB-Audio Virtual Cable</code> atau enable <code>Windows Audio Service</code>, lalu restart engine.
                  Deteksi baru di v6.7.1+: <code>captureAvailable</code> sekarang cek device beneran, bukan cuma OS.
                </div>
              </div>
            )}
            {/* Virtual Mic Driver — biar mic client denyut di Control Panel seperti AnyDesk */}
            {status?.virtualMic && (
              <div className="vm-warning" style={{ marginTop: 14, background: status.virtualMic.installed ? 'linear-gradient(135deg, rgba(22,115,71,0.10), rgba(22,115,71,0.06))' : 'linear-gradient(135deg, rgba(124,58,237,0.14), rgba(91,33,182,0.10))' }}>
                <span className="icon">{status.virtualMic.installed ? '🎙️' : '🔈'}</span>
                <div className="text">
                  <strong>Virtual Mic: {status.virtualMic.installed ? 'Terpasang — mic client akan denyut di Recording' : 'Belum terpasang — mic client cuma ke speaker'}</strong><br />
                  Render target sekarang: <code>{status.virtualMic.renderTarget}</code><br />
                  {status.virtualMic.installed ? (
                    <>
                      ✅ Driver virtual audio ada — CABLE Input/Output terdeteksi.<br />
                      Di Control Panel → Sound → Recording → <code>CABLE Output</code> akan denyut kalau HP ngomong.<br />
                      Di Discord/Zoom/Game, pilih mic = <code>CABLE Output</code> biar suara HP masuk sebagai mic.
                    </>
                  ) : (
                    <>
                      Saat ini mic HP → speaker PC (default), jadi <strong>tidak denyut di Recording</strong> — itu kenapa control panel diam.<br />
                      Install VB-CABLE dari <code>vb-audio.com/Cable</code> (VBCABLE_Setup_x64.exe admin) atau VoiceMeeter Banana.<br />
                      Setelah install, restart XyDesk — render akan otomatis ke CABLE Input dan denyut di CABLE Output.
                    </>
                  )}
                </div>
              </div>
            )}
            <span className="field-label">Volume master PC ({vol}%)</span>
            <input
              className="slider"
              type="range"
              min={0}
              max={100}
              step={5}
              value={vol}
              onChange={(e) => setVol(Number(e.target.value))}
              onPointerUp={() => onAction('audio-volume', { volume: vol / 100 })}
              onKeyUp={() => onAction('audio-volume', { volume: vol / 100 })}
              disabled={status.audio.outputs === 0}
            />
            <p className="hint">
              Slider ini mengatur volume MASTER perangkat output default PC — jadi yang didengar
              pengguna di HP ikut berubah. {status.audio.outputs} perangkat output terdeteksi.
              {status.audio.outputs === 0 && ' (VM tanpa audio)'}
            </p>
          </>
        ) : (
          <p className="dim">Status audio belum terbaca dari engine.</p>
        )}
      </section>

      <section className="card">
        <h3>Driver &amp; Integrasi Perangkat Virtual (Windows)</h3>
        <p className="hint">
          Driver bawaan memungkinkan display virtual headless (mencegah layar hitam saat RDP/VM) dan mikrofon virtual terintegrasi (suara mic HP terbaca di Discord/Zoom PC).
        </p>
        <div className="kv-grid" style={{ marginBottom: 12 }}>
          <div className="kv">
            <span>Virtual Display Driver (IddSampleDriver)</span>
            <strong>{status?.virtualDisplay?.installed ? '✅ Terpasang' : '⚠️ Belum Terpasang'}</strong>
          </div>
          <div className="kv">
            <span>Virtual Audio &amp; Mic (VB-CABLE)</span>
            <strong>{status?.virtualMic?.installed ? '✅ Terpasang' : '⚠️ Belum Terpasang'}</strong>
          </div>
        </div>
        <div className="set-row" style={{ gap: 8, flexWrap: 'wrap' }}>
          <button
            onClick={() => handleInstallDriver('all')}
            disabled={installingDriver || busy}
            style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}
          >
            <Shield size={14} /> {installingDriver ? 'Memasang Driver (Admin)…' : 'Pasang Semua Driver (1-Klik Admin)'}
          </button>
          {!status?.virtualDisplay?.installed && (
            <button
              onClick={() => handleInstallDriver('vdd')}
              disabled={installingDriver || busy}
            >
              Pasang Display Saja
            </button>
          )}
          {!status?.virtualMic?.installed && (
            <button
              onClick={() => handleInstallDriver('audio')}
              disabled={installingDriver || busy}
            >
              Pasang Audio Saja
            </button>
          )}
        </div>
        {driverInstallMsg && (
          <p style={{ marginTop: 8, fontSize: 12.5, color: 'var(--accent, #8b5cf6)', fontWeight: 500 }}>
            {driverInstallMsg}
          </p>
        )}
      </section>

      <section className="card">
        <h3>Lisensi &amp; legal</h3>
        <p className="hint">
          XyDesk adalah perangkat lunak <strong>proprietary</strong> — bebas dipakai,
          dilarang di-clone / direkayasa balik tanpa izin tertulis. Seluruh UI/UX
          dirancang sendiri oleh tim; berikut perangkat lunak pihak ketiga yang dipakai:
        </p>
        <div className="kv-grid">
          {LICENSES.map((l) => (
            <div className="kv" key={l[0]}>
              <span>{l[0]}</span>
              <strong>
                {l[1]} · {l[2]}
              </strong>
            </div>
          ))}
        </div>
      </section>

      <section className="card logs-card">
        <h3>Log engine</h3>
        <div className="logs" ref={logScroll}>
          {logs.length === 0 ? (
            <p className="hint">— belum ada log —</p>
          ) : (
            logs.map((l, i) => (
              <div key={i}>
                <span className="t">{new Date(l.t).toLocaleTimeString('id-ID', { hour12: false })}</span>
                {l.line}
              </div>
            ))
          )}
        </div>
      </section>
    </div>
  );
}

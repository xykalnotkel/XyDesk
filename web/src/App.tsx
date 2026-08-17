import { useCallback, useEffect, useRef, useState } from 'react';
import {
  ApiError,
  me,
  requestOtp,
  signInWithGoogle,
  UserProfile,
  verifyOtp,
} from './api';
import { GOOGLE_CLIENT_ID, renderGoogleButton } from './google';
import { InputCodec, RtcPhase, RtcSession } from './rtc';

type Screen = 'login' | 'otp' | 'connect' | 'session';

const TOKEN_KEY = 'xydesk.web.jwt';

export default function App() {
  const [screen, setScreen] = useState<Screen>('login');
  const [email, setEmail] = useState('');
  const [otp, setOtp] = useState('');
  const [jwt, setJwt] = useState<string | null>(() =>
    localStorage.getItem(TOKEN_KEY),
  );
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  // Pulihkan sesi tersimpan.
  useEffect(() => {
    if (!jwt) return;
    me(jwt)
      .then((r) => {
        setProfile(r.user);
        setScreen('connect');
      })
      .catch(() => {
        localStorage.removeItem(TOKEN_KEY);
        setJwt(null);
      });
  }, [jwt]);

  const finishAuth = (token: string, user?: UserProfile) => {
    localStorage.setItem(TOKEN_KEY, token);
    setJwt(token);
    if (user) setProfile(user);
    setScreen('connect');
  };

  const doRequestOtp = async () => {
    setBusy(true);
    setError('');
    try {
      await requestOtp(email.trim().toLowerCase());
      setScreen('otp');
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
      setError(
        e instanceof ApiError ? e.message : 'Login Google gagal. Coba lagi.',
      );
    } finally {
      setBusy(false);
    }
  };

  const signOut = () => {
    localStorage.removeItem(TOKEN_KEY);
    setJwt(null);
    setProfile(null);
    setScreen('login');
  };

  return (
    <div className="shell">
      <header>
        <div className="brand">
          <img src="/logo.png" alt="" className="brand-logo" />
          <span className="brand-name">
            XyDesk <span className="web-tag">WEB</span>
          </span>
        </div>
        {profile && <ProfileChip profile={profile} onSignOut={signOut} />}
      </header>

      {screen === 'login' && (
        <main className="card auth-card">
          <img src="/logo.png" alt="XyDesk" className="auth-logo" />
          <h1>Masuk ke XyDesk</h1>
          <p className="hint">
            Satu akun untuk semua perangkat. Sudah punya akun di aplikasi
            Android? Masuk dengan email atau Google yang sama — semuanya
            tersambung.
          </p>

          <GoogleButton onCredential={doGoogle} />
          <AppleButton />

          <div className="divider">
            <span>atau lewat email</span>
          </div>

          <input
            type="email"
            placeholder="email@contoh.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && email && doRequestOtp()}
          />
          {error && <p className="error">{error}</p>}
          <button
            disabled={busy || !email.includes('@')}
            onClick={doRequestOtp}
          >
            {busy ? 'Mengirim…' : 'Kirim kode OTP'}
          </button>

          <p className="footnote">
            Pengguna iPhone/iPad: XyDesk Web adalah cara resmi memakai XyDesk
            di iOS. Tambahkan ke Home Screen (Bagikan &rarr; Tambah ke Layar
            Utama) agar terasa seperti aplikasi.
          </p>
        </main>
      )}

      {screen === 'otp' && (
        <main className="card auth-card">
          <h1>Kode OTP</h1>
          <p className="hint">6 digit dikirim ke {email}.</p>
          <input
            inputMode="numeric"
            maxLength={6}
            placeholder="000000"
            value={otp}
            autoFocus
            onChange={(e) => setOtp(e.target.value.replace(/\D/g, ''))}
            onKeyDown={(e) =>
              e.key === 'Enter' && otp.length === 6 && doVerify()
            }
          />
          {error && <p className="error">{error}</p>}
          <button disabled={busy || otp.length !== 6} onClick={doVerify}>
            {busy ? 'Memeriksa…' : 'Masuk'}
          </button>
          <button className="ghost" onClick={() => setScreen('login')}>
            Ganti email
          </button>
        </main>
      )}

      {screen === 'connect' && jwt && (
        <ConnectScreen jwt={jwt} onSession={() => setScreen('session')} />
      )}
    </div>
  );
}

function ProfileChip({
  profile,
  onSignOut,
}: {
  profile: UserProfile;
  onSignOut: () => void;
}) {
  const initial = (profile.name || profile.email)[0]?.toUpperCase() ?? '?';
  return (
    <div className="profile-chip">
      {profile.picture ? (
        <img src={profile.picture} alt="" referrerPolicy="no-referrer" />
      ) : (
        <span className="avatar-fallback">{initial}</span>
      )}
      <span className="profile-meta">
        <strong>{profile.name || profile.email}</strong>
        {profile.name && <small>{profile.email}</small>}
      </span>
      <button className="ghost" onClick={onSignOut}>
        Keluar
      </button>
    </div>
  );
}

function GoogleButton({
  onCredential,
}: {
  onCredential: (idToken: string) => void;
}) {
  const ref = useRef<HTMLDivElement | null>(null);
  const [failed, setFailed] = useState(!GOOGLE_CLIENT_ID);

  useEffect(() => {
    if (!ref.current || !GOOGLE_CLIENT_ID) return;
    renderGoogleButton(ref.current, onCredential).catch(() => setFailed(true));
  }, [onCredential]);

  if (failed) return null;
  return <div ref={ref} className="google-btn" />;
}

function AppleButton() {
  // Sign in with Apple butuh keanggotaan Apple Developer Program (berbayar)
  // untuk membuat Services ID. Tombol disiapkan tetapi nonaktif sampai
  // kredensial tersedia — jujur ke pengguna, bukan tombol yang diam-diam
  // gagal.
  return (
    <button className="apple-btn" disabled title="Segera hadir">
      <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden>
        <path
          fill="currentColor"
          d="M16.36 12.79c-.02-2.07 1.69-3.06 1.77-3.11-.96-1.41-2.46-1.6-3-1.62-1.28-.13-2.5.75-3.15.75-.65 0-1.65-.73-2.72-.71-1.4.02-2.69.81-3.41 2.06-1.45 2.52-.37 6.25 1.04 8.29.69 1 1.52 2.12 2.6 2.08 1.04-.04 1.44-.67 2.7-.67 1.26 0 1.62.67 2.72.65 1.12-.02 1.83-1.02 2.52-2.02.79-1.16 1.12-2.28 1.14-2.34-.03-.01-2.19-.84-2.21-3.36zM14.3 6.7c.57-.7.96-1.66.85-2.62-.83.03-1.83.55-2.42 1.24-.53.62-1 1.6-.87 2.55.92.07 1.86-.47 2.44-1.17z"
        />
      </svg>
      Lanjutkan dengan Apple — segera hadir
    </button>
  );
}

const LAST_HOST_KEY = 'xydesk.web.lastHost';

/// Format ID host "123456789" -> "123 456 789" saat mengetik.
function formatHostId(raw: string): string {
  const d = raw.replace(/\D/g, '').slice(0, 9);
  return d.replace(/(\d{3})(?=\d)/g, '$1 ');
}

function ConnectScreen({
  jwt,
  onSession,
}: {
  jwt: string;
  onSession: () => void;
}) {
  const [hostId, setHostId] = useState(
    () => localStorage.getItem(LAST_HOST_KEY) ?? '',
  );
  const [pin, setPin] = useState('');
  const [phase, setPhase] = useState<RtcPhase | ''>('');
  const sessionRef = useRef<RtcSession | null>(null);
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const surfaceRef = useRef<HTMLDivElement | null>(null);
  const pinRef = useRef<HTMLInputElement | null>(null);

  const idOk = hostId.replace(/[\s-]/g, '').length === 9;
  const canConnect =
    idOk && !!pin && phase !== 'pairing' && phase !== 'negotiating';

  const connect = async () => {
    localStorage.setItem(LAST_HOST_KEY, hostId);
    const session = new RtcSession();
    sessionRef.current = session;
    session.onPhase = setPhase;
    session.onTrack = (stream) => {
      if (videoRef.current) videoRef.current.srcObject = stream;
    };
    try {
      await session.start(jwt, hostId, pin);
      onSession();
    } catch {
      setPhase('ended');
    }
  };

  const disconnect = useCallback(() => {
    sessionRef.current?.stop();
    sessionRef.current = null;
    setPhase('');
  }, []);

  useEffect(() => disconnect, [disconnect]);

  const onPointerMove = (e: React.PointerEvent) => {
    const el = surfaceRef.current;
    const s = sessionRef.current;
    if (!el || !s) return;
    const r = el.getBoundingClientRect();
    s.sendInput(
      InputCodec.mouseMoveAbs(
        (e.clientX - r.left) / r.width,
        (e.clientY - r.top) / r.height,
      ),
    );
  };
  const onPointerDown = (e: React.PointerEvent) =>
    sessionRef.current?.sendInput(
      InputCodec.mouseButton(e.button === 2 ? 1 : 0, true),
    );
  const onPointerUp = (e: React.PointerEvent) =>
    sessionRef.current?.sendInput(
      InputCodec.mouseButton(e.button === 2 ? 1 : 0, false),
    );
  const onWheel = (e: React.WheelEvent) =>
    sessionRef.current?.sendInput(InputCodec.scroll(-e.deltaX, -e.deltaY));

  const connected = phase === 'connected';

  const statusLabel: Record<string, string> = {
    pairing: 'Menghubungi host…',
    negotiating: 'Negosiasi koneksi…',
    connected: 'Tersambung',
    rejected: 'Pairing ditolak (password salah?)',
    'peer-offline': 'Host tidak online',
    ended: 'Sesi berakhir',
  };

  return (
    <main className={connected ? 'session' : 'card'}>
      {!connected && (
        <>
          <h1>Sambungkan ke PC</h1>
          <p className="hint">
            Masukkan ID 9 digit dan password dari XyDesk Host di PC kamu —
            langsung konek.
          </p>
          <input
            className="host-id"
            inputMode="numeric"
            placeholder="123 456 789"
            value={hostId}
            autoFocus={!hostId}
            onChange={(e) => {
              const v = formatHostId(e.target.value);
              setHostId(v);
              // ID lengkap -> pindah fokus ke password otomatis.
              if (v.replace(/\s/g, '').length === 9) pinRef.current?.focus();
            }}
          />
          <input
            ref={pinRef}
            type="password"
            placeholder="Password pairing"
            value={pin}
            autoFocus={!!hostId}
            onChange={(e) => setPin(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && canConnect && connect()}
          />
          {phase && (
            <p className="hint status">{statusLabel[phase] ?? phase}</p>
          )}
          <button disabled={!canConnect} onClick={connect}>
            {phase === 'pairing' || phase === 'negotiating'
              ? statusLabel[phase]
              : 'Konek'}
          </button>
        </>
      )}
      <div
        ref={surfaceRef}
        className="video-surface"
        style={{ display: connected ? 'block' : 'none' }}
        onPointerMove={onPointerMove}
        onPointerDown={onPointerDown}
        onPointerUp={onPointerUp}
        onWheel={onWheel}
        onContextMenu={(e) => e.preventDefault()}
      >
        <video ref={videoRef} autoPlay playsInline muted />
        <button className="disconnect" onClick={disconnect}>
          Putuskan
        </button>
      </div>
    </main>
  );
}

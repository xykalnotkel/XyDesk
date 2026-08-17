import { useCallback, useEffect, useRef, useState } from 'react';
import { me, requestOtp, verifyOtp, ApiError } from './api';
import { InputCodec, RtcPhase, RtcSession } from './rtc';

type Screen = 'login' | 'otp' | 'connect' | 'session';

const TOKEN_KEY = 'xydesk.web.jwt';

export default function App() {
  const [screen, setScreen] = useState<Screen>('login');
  const [email, setEmail] = useState('');
  const [otp, setOtp] = useState('');
  const [jwt, setJwt] = useState<string | null>(
    () => localStorage.getItem(TOKEN_KEY),
  );
  const [userEmail, setUserEmail] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  // Pulihkan sesi tersimpan.
  useEffect(() => {
    if (!jwt) return;
    me(jwt)
      .then((r) => {
        setUserEmail(r.user.email);
        setScreen('connect');
      })
      .catch(() => {
        localStorage.removeItem(TOKEN_KEY);
        setJwt(null);
      });
  }, [jwt]);

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
      localStorage.setItem(TOKEN_KEY, session.token);
      setJwt(session.token);
      setUserEmail(email.trim().toLowerCase());
      setScreen('connect');
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'OTP salah.');
    } finally {
      setBusy(false);
    }
  };

  const signOut = () => {
    localStorage.removeItem(TOKEN_KEY);
    setJwt(null);
    setUserEmail('');
    setScreen('login');
  };

  return (
    <div className="shell">
      <header>
        <div className="brand">
          <span className="logo" aria-hidden />
          XyDesk <span className="web-tag">WEB</span>
        </div>
        {userEmail && (
          <button className="ghost" onClick={signOut}>
            {userEmail} — keluar
          </button>
        )}
      </header>

      {screen === 'login' && (
        <main className="card">
          <h1>Masuk</h1>
          <p className="hint">
            Kode OTP dikirim ke email. Akun sama dengan aplikasi Android.
          </p>
          <input
            type="email"
            placeholder="email@contoh.com"
            value={email}
            autoFocus
            onChange={(e) => setEmail(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && email && doRequestOtp()}
          />
          {error && <p className="error">{error}</p>}
          <button disabled={busy || !email.includes('@')} onClick={doRequestOtp}>
            {busy ? 'Mengirim…' : 'Kirim kode OTP'}
          </button>
        </main>
      )}

      {screen === 'otp' && (
        <main className="card">
          <h1>Kode OTP</h1>
          <p className="hint">6 digit dikirim ke {email}.</p>
          <input
            inputMode="numeric"
            maxLength={6}
            placeholder="000000"
            value={otp}
            autoFocus
            onChange={(e) => setOtp(e.target.value.replace(/\D/g, ''))}
            onKeyDown={(e) => e.key === 'Enter' && otp.length === 6 && doVerify()}
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

function ConnectScreen({
  jwt,
  onSession,
}: {
  jwt: string;
  onSession: () => void;
}) {
  const [hostId, setHostId] = useState('');
  const [pin, setPin] = useState('');
  const [phase, setPhase] = useState<RtcPhase | ''>('');
  const sessionRef = useRef<RtcSession | null>(null);
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const surfaceRef = useRef<HTMLDivElement | null>(null);

  const idOk = hostId.replace(/[\s-]/g, '').length === 9;

  const connect = async () => {
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

  // Input pointer -> data channel (absolut, fraksi permukaan video).
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
            ID perangkat 9 digit dari XyDesk Host di PC kamu.
          </p>
          <input
            placeholder="123 456 789"
            value={hostId}
            autoFocus
            onChange={(e) => setHostId(e.target.value)}
          />
          <input
            type="password"
            placeholder="Password pairing"
            value={pin}
            onChange={(e) => setPin(e.target.value)}
          />
          {phase && <p className="hint status">{statusLabel[phase] ?? phase}</p>}
          <button
            disabled={!idOk || !pin || phase === 'pairing' || phase === 'negotiating'}
            onClick={connect}
          >
            {phase === 'pairing' || phase === 'negotiating'
              ? statusLabel[phase]
              : 'Mulai sesi'}
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

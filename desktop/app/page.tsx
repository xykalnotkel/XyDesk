'use client';

import { useCallback, useEffect, useRef, useState } from 'react';

// Demo mode: dibuka sebagai halaman biasa (bukan lewat Electron) → tampilkan
// data contoh agar tampilan bisa dipreview. Aplikasi asli selalu lewat
// window.xydesk (preload).
const DEMO = typeof window !== 'undefined' && !window.xydesk;

const DEMO_STATUS: StatusPayload = {
  state: 'streaming',
  engine: true,
  deviceId: '123456789',
  password: 'AB2CD3EF4G',
  signalingUrl: 'wss://signal.xystudio.my.id/ws',
  uptimeMs: 1800000,
  session: { clientId: 'klien-demo', startedAtMs: Date.now() - 60000, durationMs: 60000 },
  video: { framesSent: 214400, fps: 60, nvenc: true },
  lastError: null,
};

const DEMO_LOGS: LogEntry[] = [
  { t: Date.now() - 5000, line: '[shell] identitas host 123456789' },
  { t: Date.now() - 4500, line: '[shell] mulai engine (port control 43210)' },
  { t: Date.now() - 4200, line: '[engine] [control] http://127.0.0.1:43210 token=…' },
  { t: Date.now() - 4100, line: '[shell] control API siap di 127.0.0.1:43210' },
  { t: Date.now() - 3800, line: '[engine] terhubung ke wss://signal.xystudio.my.id/ws' },
  { t: Date.now() - 2000, line: '[engine] NVENC aktif: H264 hardware 1920x1080 @ 8000 kbps CBR' },
  { t: Date.now() - 1500, line: '[engine] pairing DITERIMA dari klien-demo' },
  { t: Date.now() - 1000, line: '[engine] track video siap — streaming' },
];

const STATE_LABEL: Record<string, { label: string; cls: string }> = {
  starting: { label: 'Memulai…', cls: 'connecting' },
  connecting: { label: 'Menghubungkan…', cls: 'connecting' },
  ready: { label: 'Siap menerima', cls: '' },
  streaming: { label: 'Streaming aktif', cls: 'streaming' },
  error: { label: 'Galat', cls: 'error' },
};

function formatId(id: string): string {
  const digits = id.replace(/\D/g, '');
  return digits.length === 9 ? `${digits.slice(0, 3)} ${digits.slice(3, 6)} ${digits.slice(6, 9)}` : id;
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
  const [status, setStatus] = useState<StatusPayload | null>(DEMO ? DEMO_STATUS : null);
  const [logs, setLogs] = useState<LogEntry[]>(DEMO ? DEMO_LOGS : []);
  const [info, setInfo] = useState<InfoPayload | null>(null);
  const [showPw, setShowPw] = useState(false);
  const [customPw, setCustomPw] = useState('');
  const [busy, setBusy] = useState(false);
  const [flash, setFlash] = useState<string | null>(null);
  const logScroll = useRef<HTMLDivElement>(null);

  const flashMsg = useCallback((msg: string) => {
    setFlash(msg);
    setTimeout(() => setFlash(null), 2500);
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

  useEffect(() => {
    const el = logScroll.current;
    if (el) el.scrollTop = el.scrollHeight;
  }, [logs]);

  const runAction = async (action: string, password?: string) => {
    if (DEMO) {
      flashMsg('Mode pratinjau — aksi hanya jalan di aplikasi desktop.');
      return;
    }
    setBusy(true);
    try {
      const res = await window.xydesk!.runAction({ action, password });
      if (res.ok) {
        if (action === 'new-password') flashMsg('Password baru dibuat.');
        if (action === 'set-password') flashMsg('Password disimpan.');
        if (action === 'stop-session') flashMsg(res.stopped ? 'Sesi diakhiri.' : 'Tidak ada sesi aktif.');
        setCustomPw('');
        // Segarkan status segera setelah aksi.
        setStatus(await window.xydesk!.getStatus());
      } else {
        flashMsg(res.error || 'Aksi gagal.');
      }
    } catch (e) {
      flashMsg(String(e));
    } finally {
      setBusy(false);
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

  return (
    <div className="shell">
      {DEMO && (
        <div className="demo-banner">
          <b>Mode pratinjau.</b> Data di bawah contoh — jalankan lewat aplikasi desktop XyDesk
          (Electron) untuk melihat status engine sesungguhnya.
        </div>
      )}

      <header className="top">
        <div className="brand">
          <svg width="30" height="30" viewBox="0 0 32 32" aria-hidden="true">
            <defs>
              <linearGradient id="xg" x1="0" y1="0" x2="1" y2="1">
                <stop offset="0" stopColor="#7654F6" />
                <stop offset="1" stopColor="#9A7BFF" />
              </linearGradient>
            </defs>
            <rect x="3" y="3" width="26" height="26" rx="7" fill="url(#xg)" opacity="0.16" />
            <path
              d="M9.5 10.5 L16 22.5 L22.5 10.5 M16 22.5 L16 14.5"
              stroke="url(#xg)"
              strokeWidth="2.6"
              strokeLinecap="round"
              strokeLinejoin="round"
              fill="none"
            />
          </svg>
          <div>
            <h1>XyDesk</h1>
            <div className="sub">Host Desktop — Windows</div>
          </div>
        </div>
        {flash && (
          <div className="pill" style={{ background: 'var(--overlay)' }}>
            {flash}
          </div>
        )}
        <div className={`pill ${pill.cls}`}>
          <span className="dot" />
          {engineUp ? pill.label : 'Engine belum siap'}
        </div>
      </header>

      <div className="grid">
        <div className="col">
          <section className="card identity">
            <h2>Perangkat ini</h2>
            <div className="id-row">
              <span className="id">{st?.deviceId ? formatId(st.deviceId) : '— — — — — — —'}</span>
              <button
                className="ghost"
                disabled={!st?.deviceId}
                onClick={() => st?.deviceId && copy(st.deviceId, 'ID')}
                title="Salin ID"
              >
                Salin
              </button>
            </div>
            <div className="pw-row">
              <span className="pw">
                {st?.password ? (showPw ? st.password : '•'.repeat(st.password.length)) : '••••••••'}
              </span>
              <button className="ghost" disabled={!st?.password} onClick={() => setShowPw((v) => !v)}>
                {showPw ? 'Sembunyikan' : 'Lihat'}
              </button>
              <button
                className="ghost"
                disabled={!st?.password}
                onClick={() => st?.password && copy(st.password, 'Password')}
              >
                Salin
              </button>
            </div>
            <p className="hint">
              Ketik ID dan password ini di aplikasi XyDesk di HP untuk menghubungkan ke layar ini.
              Password bisa diubah kapan saja — koneksi lama akan meminta password baru.
            </p>
          </section>

          <section className="card">
            <h2>Keamanan</h2>
            <div className="set-row">
              <button disabled={busy} onClick={() => runAction('new-password')}>
                Password acak baru
              </button>
            </div>
            <div className="set-row">
              <input
                type="text"
                placeholder="Password kustom (min. 6 karakter)"
                value={customPw}
                onChange={(e) => setCustomPw(e.target.value)}
                autoCapitalize="characters"
                spellCheck={false}
              />
              <button
                className="primary"
                disabled={busy || customPw.length < 6}
                onClick={() => runAction('set-password', customPw)}
              >
                Simpan
              </button>
            </div>
            <p className="hint">
              Password pendek hanya aman karena engine membatasi laju percobaan pairing
              (pairguard). Password acak disarankan.
            </p>
          </section>
        </div>

        <div className="col">
          <section className="card">
            <h2>Sesi</h2>
            {st?.session ? (
              <>
                <div>
                  Terhubung dari <b>{st.session.clientId}</b>
                  {st.video?.nvenc && <span className="badge">NVENC</span>}
                </div>
                <div className="session-stats">
                  <div className="stat">
                    <div className="k">Durasi</div>
                    <div className="v">{formatDuration(st.session.durationMs)}</div>
                  </div>
                  <div className="stat">
                    <div className="k">FPS kirim</div>
                    <div className="v">{st.video ? Math.round(st.video.fps) : '—'}</div>
                  </div>
                  <div className="stat">
                    <div className="k">Frame</div>
                    <div className="v">{st.video ? st.video.framesSent.toLocaleString('id-ID') : '—'}</div>
                  </div>
                </div>
                <button className="danger" disabled={busy} onClick={() => runAction('stop-session')}>
                  Akhiri sesi
                </button>
              </>
            ) : (
              <>
                <p className="session-empty">Menunggu koneksi. Buka aplikasi XyDesk di HP, lalu ketik ID + password di atas.</p>
                {st?.lastError && <p className="hint">Kendala terakhir: {st.lastError}</p>}
              </>
            )}
          </section>

          <section className="card logs">
            <h2>Log engine</h2>
            <div className="scroll" ref={logScroll}>
              {logs.length === 0 ? (
                <div>— belum ada log —</div>
              ) : (
                logs.map((l, i) => (
                  <div key={i}>
                    <span className="t">
                      {new Date(l.t).toLocaleTimeString('id-ID', { hour12: false })}
                    </span>
                    {l.line}
                  </div>
                ))
              )}
            </div>
          </section>
        </div>
      </div>

      <footer>
        <span>
          v{info?.appVersion || '0.1.0'} · engine Rust + shell Electron ·{' '}
          {info?.packaged ? 'installed' : 'dev mode'}
        </span>
        <a href="https://app.xystudio.my.id" target="_blank" rel="noreferrer">
          {info?.signalingHttp || 'app.xystudio.my.id'}
        </a>
      </footer>
    </div>
  );
}

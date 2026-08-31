'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import {
  Cable,
  ClipboardCopy,
  Eye,
  EyeOff,
  Heart,
  Home,
  Newspaper,
  Power,
  RefreshCw,
  Settings,
  Share2,
  User,
  ExternalLink,
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
  { t: Date.now() - 3800, line: '[engine] terhubung ke wss://signal.xystudio.my.id/ws' },
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

const NAV: { id: Page; label: string; icon: typeof Home }[] = [
  { id: 'home', label: 'Home', icon: Home },
  { id: 'connect', label: 'Connect', icon: Cable },
  { id: 'news', label: 'News', icon: Newspaper },
];

const NAV_BOTTOM: { id: Page; label: string; icon: typeof Home }[] = [
  { id: 'profile', label: 'Profile', icon: User },
  { id: 'settings', label: 'Settings', icon: Settings },
];

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
  const [status, setStatus] = useState<StatusPayload | null>(DEMO ? DEMO_STATUS : null);
  const [logs, setLogs] = useState<LogEntry[]>(DEMO ? DEMO_LOGS : []);
  const [info, setInfo] = useState<InfoPayload | null>(null);
  const [flash, setFlash] = useState<string | null>(null);

  const flashMsg = useCallback((msg: string) => {
    setFlash(msg);
    setTimeout(() => setFlash(null), 2600);
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

  const runAction = async (action: string, password?: string) => {
    if (DEMO) {
      flashMsg('Mode pratinjau — aksi hanya jalan di aplikasi desktop.');
      return;
    }
    try {
      const res = await window.xydesk!.runAction({ action, password });
      if (res.ok) {
        if (action === 'new-password') flashMsg('Password baru dibuat.');
        if (action === 'set-password') flashMsg('Password disimpan.');
        if (action === 'stop-session')
          flashMsg(res.stopped ? 'Sesi diakhiri. Peer wajib pairing ulang.' : 'Tidak ada sesi aktif.');
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

  return (
    <div className="shell">
      {DEMO && (
        <div className="demo-banner">
          <b>Mode pratinjau.</b> Data di bawah contoh — jalankan lewat aplikasi desktop XyDesk
          untuk melihat status engine sesungguhnya.
        </div>
      )}

      <aside className="sidebar">
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

        <div className="side-status">
          <span className={`dot ${pill.cls}`} />
          {engineUp ? pill.label : 'Engine belum siap'}
        </div>
      </aside>

      <main className="main">
        <header className="topbar">
          <h2>{page === 'home' ? 'Home' : page === 'connect' ? 'Connect' : page === 'news' ? 'News' : page === 'profile' ? 'Profile' : 'Settings'}</h2>
          {flash && <span className="flash">{flash}</span>}
          <span className={`pill ${pill.cls}`}>
            <span className="dot" />
            {engineUp ? pill.label : 'Engine belum siap'}
          </span>
        </header>

        <div className="page-body">
          {page === 'home' && (
            <HomePage status={st} onStop={() => runAction('stop-session')} />
          )}
          {page === 'connect' && (
            <ConnectPage status={st} onCopy={copy} onAction={runAction} />
          )}
          {page === 'news' && <NewsPage />}
          {page === 'profile' && <ProfilePage status={st} info={info} />}
          {page === 'settings' && (
            <SettingsPage status={st} info={info} logs={logs} flashMsg={flashMsg} />
          )}
        </div>
      </main>
    </div>
  );
}

/* ── Home ─────────────────────────────────────────────────────────── */

function HomePage({ status, onStop }: { status: StatusPayload | null; onStop: () => void }) {
  const s = status?.session;
  const v = status?.video;
  return (
    <div className="pg">
      <section className="card">
        <h3>Status engine</h3>
        {status?.engine === false ? (
          <p className="dim">Engine belum siap. Shell sedang menyiapkan proses host…</p>
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
            </div>
            {status?.lastError && <p className="danger-text">Kendala terakhir: {status.lastError}</p>}
          </>
        )}
      </section>

      <section className="card">
        <h3>Sesi aktif</h3>
        {s ? (
          <>
            <div className="kv-grid">
              <div className="kv">
                <span>Client</span>
                <strong>{s.clientId}</strong>
              </div>
              <div className="kv">
                <span>Durasi</span>
                <strong>{formatDuration(s.durationMs)}</strong>
              </div>
            </div>
            <div className="stat-row">
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
                <span className="v">{v?.nvenc ? 'NVENC' : 'Software'}</span>
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
  onAction: (action: string, password?: string) => void;
}) {
  const [showPw, setShowPw] = useState(false);
  const [customPw, setCustomPw] = useState('');
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
          <button
            className="ghost"
            disabled={!status?.password}
            onClick={() => status?.password && onCopy(status.password, 'Password')}
          >
            <ClipboardCopy size={14} /> Salin
          </button>
        </div>
        <p className="hint">
          Ketik ID dan password ini di aplikasi XyDesk di HP untuk menghubungkan ke layar ini.
          Bila sesi sedang berjalan, percobaan koneksi lain akan ditolak meski passwordnya benar.
        </p>
      </section>

      <section className="card">
        <h3>Password pairing</h3>
        <div className="set-row">
          <button disabled={!status?.engine} onClick={() => onAction('new-password')}>
            <RefreshCw size={14} /> Password acak baru
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
          <button className="primary" disabled={customPw.length < 6} onClick={() => onAction('set-password', customPw)}>
            Simpan
          </button>
        </div>
        <p className="hint">
          Password pendek hanya aman karena engine membatasi laju percobaan pairing (pairguard).
          Mengganti password tidak memutus sesi yang sedang berjalan.
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

  useEffect(() => {
    let alive = true;
    setPosts(null);
    setError('');
    fetchNewsList(category)
      .then((r) => {
        if (alive) setPosts(r.posts);
      })
      .catch((e) => {
        if (alive) setError(e instanceof Error ? e.message : 'Gagal memuat berita.');
      });
    return () => {
      alive = false;
    };
  }, [category]);

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
      {error && <p className="danger-text">{error}</p>}
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
          {p.content.split(/\n\n+/).map((para, i) => (
            <p key={i}>{para}</p>
          ))}
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

function ProfilePage({ status, info }: { status: StatusPayload | null; info: InfoPayload | null }) {
  return (
    <div className="pg">
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
            <strong>{status?.video?.nvenc ? 'NVENC (hardware)' : 'Software (fallback)'}</strong>
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
            <strong>{info?.packaged ? 'Installed' : 'Dev'}</strong>
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
          <a className="btn-ghost-link" href="https://app.xystudio.my.id/news" target="_blank" rel="noreferrer">
            <ExternalLink size={14} /> Berita di Web
          </a>
        </div>
      </section>
    </div>
  );
}

/* ── Settings ─────────────────────────────────────────────────────── */

function SettingsPage({
  status,
  info,
  logs,
  flashMsg,
}: {
  status: StatusPayload | null;
  info: InfoPayload | null;
  logs: LogEntry[];
  flashMsg: (m: string) => void;
}) {
  const [autostart, setAutostart] = useState(false);
  const [busy, setBusy] = useState(false);
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

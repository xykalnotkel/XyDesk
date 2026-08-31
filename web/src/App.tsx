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
import {
  fetchNewsList,
  fetchNewsPost,
  formatNewsDate,
  NEWS_CATEGORIES,
  NEWS_SHARE_BASE,
  NewsComment,
  NewsPost,
  postComment,
  toggleLike,
} from './news';
import { InputCodec, RtcPhase, RtcSession } from './rtc';
import { TOUCH_ROWS, vkFromCode } from './vk';

type StaticRoute = '/' | '/connect' | '/download' | '/legal' | '/news';
type Route = StaticRoute | NewsDetailRoute;
interface NewsDetailRoute {
  page: 'news-detail';
  slug: string;
}
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
    <svg width={size} height={size} viewBox="0 0 32 32" aria-hidden="true">
      <defs>
        <linearGradient id="logo-g" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#7654F6" />
          <stop offset="1" stopColor="#9A7BFF" />
        </linearGradient>
      </defs>
      <rect x="3" y="3" width="26" height="26" rx="7" fill="url(#logo-g)" opacity="0.16" />
      <path
        d="M9.5 10.5 L16 22.5 L22.5 10.5 M16 22.5 L16 14.5"
        stroke="url(#logo-g)"
        strokeWidth="2.6"
        strokeLinecap="round"
        strokeLinejoin="round"
        fill="none"
      />
    </svg>
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
          <button className={current === '/download' ? 'active' : ''} onClick={() => navigate('/download')}>
            Unduh
          </button>
        </nav>
      )}
      <div className="header-actions">
        {!bare && (
          <button className="btn ghost" onClick={() => navigate('/connect')}>
            Connect Web
          </button>
        )}
        <a className="btn primary" href={`${RELEASE_BASE}/XyDesk-Windows-x64-Setup.exe`}>
          Unduh Windows
        </a>
      </div>
    </header>
  );
}

function LandingPage({ navigate }: { navigate: (r: Route) => void }) {
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
            Akses layar PC dari HP atau browser dengan target glass-to-glass di
            bawah 40 ms di LAN. Untuk kerja, untuk game — tanpa server perantara
            yang menyimpan sesimu.
          </p>
          <div className="hero-cta">
            <button className="btn primary big" onClick={() => navigate('/download')}>
              Unduh sekarang
            </button>
            <button className="btn ghost big" onClick={() => navigate('/connect')}>
              Coba dari browser
            </button>
          </div>
          <p className="hero-note">Gratis. Media sesi peer-to-peer, tidak lewat server kami.</p>
        </div>
        <div className="hero-art" aria-hidden="true">
          <div className="hero-screen">
            <div className="screen-top">
              <span className="screen-logo">
                <Logo size={14} /> XyDesk
              </span>
              <span className="screen-live">LIVE · 9 ms</span>
            </div>
            <div className="screen-body">
              <div className="screen-fps">60 FPS</div>
              <div className="screen-vignette" />
            </div>
          </div>
          <img className="float-el el-phone" src="/float-controller.webp" alt="" />
          <img className="float-el el-kb" src="/float-keyboard.webp" alt="" />
          <img className="float-el el-mouse" src="/float-mouse.webp" alt="" />
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
          <FeatureCard index="01" title="Panel gaming dua sisi">
            Trackpad, keyboard virtual dengan modifier sticky, dan HUD glyph
            border-only yang tidak menutupi piksel game.
          </FeatureCard>
          <FeatureCard index="02" title="Pasangan terenkripsi">
            Pairing password dijaga pembatas laju (anti brute-force), sesi media
            peer-to-peer lewat WebRTC.
          </FeatureCard>
          <FeatureCard index="03" title="Encoder sadar konten">
            NVENC hardware saat GPU ada, fallback software otomatis — dengan
            bitrate terkendali agar Wi-Fi rumah tetap lega.
          </FeatureCard>
          <FeatureCard index="04" title="Jujur soal angka">
            Status transport ditampilkan apa adanya: pairing, negosiasi,
            koneksi — bukan layar dummy yang pura-pura tersambung.
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
        <h2>Mulai dari perangkatmu</h2>
        <PlatformTables compact />
        <a className="btn primary big" href={`${RELEASE_BASE}/XyDesk-Android-arm64-v8a.apk`}>
          Unduh untuk Android
        </a>
      </section>
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
  const [error, setError] = useState('');

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

      {error && (
        <div className="news-state error">
          {error} — <button onClick={() => setCategory(category)}>coba lagi</button>
        </div>
      )}

      {!posts && !error && (
        <div className="news-grid">
          {[0, 1, 2].map((i) => (
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
      )}

      {posts && posts.length === 0 && (
        <div className="news-state">Belum ada berita di kategori ini.</div>
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
  const [error, setError] = useState('');
  const [likeCount, setLikeCount] = useState(0);
  const [liked, setLiked] = useState(false);
  const [author, setAuthor] = useState(() => localStorage.getItem('xydesk.news.author') ?? '');
  const [commentText, setCommentText] = useState('');
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState('');

  useEffect(() => {
    let alive = true;
    setData(null);
    setError('');
    fetchNewsPost(slug)
      .then((r) => {
        if (!alive) return;
        setData(r);
        setLikeCount(r.post.likeCount);
        setLiked(localStorage.getItem(`xydesk.news.liked.${slug}`) === '1');
      })
      .catch((e) => {
        if (alive) setError(e instanceof Error ? e.message : 'Berita tidak ditemukan.');
      });
    return () => {
      alive = false;
    };
  }, [slug]);

  const post = data?.post;

  const like = async () => {
    if (!post) return;
    setBusy(true);
    try {
      const r = await toggleLike(post.slug);
      setLikeCount(r.likeCount);
      setLiked(r.liked);
      localStorage.setItem(`xydesk.news.liked.${post.slug}`, r.liked ? '1' : '0');
    } catch (e) {
      setNotice(e instanceof Error ? e.message : 'Gagal memproses like.');
    } finally {
      setBusy(false);
    }
  };

  const submitComment = async () => {
    if (!post || commentText.trim().length < 2) return;
    const name = author.trim() || 'Anonim';
    setBusy(true);
    setNotice('');
    try {
      localStorage.setItem('xydesk.news.author', name);
      const r = await postComment(post.slug, name, commentText.trim());
      setData((d) =>
        d ? { post: d.post, comments: [...d.comments, r.comment] } : d,
      );
      setCommentText('');
      setNotice('Komentar terkirim.');
    } catch (e) {
      setNotice(e instanceof Error ? e.message : 'Gagal mengirim komentar.');
    } finally {
      setBusy(false);
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

  const socials: { label: string; href: string }[] = post
    ? [
        { label: 'WhatsApp', href: `https://wa.me/?text=${encodeURIComponent(`${post.title} ${shareUrl}`)}` },
        { label: 'Telegram', href: `https://t.me/share/url?url=${encodeURIComponent(shareUrl)}&text=${encodeURIComponent(post.title)}` },
        { label: 'X', href: `https://twitter.com/intent/tweet?text=${encodeURIComponent(post.title)}&url=${encodeURIComponent(shareUrl)}` },
        { label: 'Facebook', href: `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(shareUrl)}` },
      ]
    : [];

  return (
    <main className="content-page news-detail">
      <button className="back-action" onClick={() => navigate('/news')}>
        ← Semua berita
      </button>

      {error && <div className="news-state error">{error}</div>}

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
            <span>{post.author}</span>
            <span>·</span>
            <span>{formatNewsDate(post.createdAt)}</span>
          </div>

          <div className="post-actions">
            <button
              className={`like-btn ${liked ? 'liked' : ''}`}
              onClick={like}
              disabled={busy}
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
            {socials.map((s) => (
              <a key={s.label} className="social-chip" href={s.href} target="_blank" rel="noreferrer">
                {s.label}
              </a>
            ))}
          </div>

          <div className="post-body">
            {post.content.split(/\n\n+/).map((p, i) => (
              <p key={i}>{p}</p>
            ))}
          </div>

          <section className="comments">
            <h2>Komentar ({data?.comments.length ?? 0})</h2>
            <div className="comment-form">
              <input
                placeholder="Nama kamu"
                maxLength={40}
                value={author}
                onChange={(e) => setAuthor(e.target.value)}
              />
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
            <div className="comment-list">
              {(data?.comments ?? []).length === 0 && (
                <p className="muted">Belum ada komentar. Jadilah yang pertama.</p>
              )}
              {(data?.comments ?? []).map((c) => (
                <div className="comment" key={c.id}>
                  <div className="comment-head">
                    <strong>{c.author}</strong>
                    <span>{formatNewsDate(c.createdAt)}</span>
                  </div>
                  <p>{c.content}</p>
                </div>
              ))}
            </div>
          </section>
        </article>
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
    'host-busy':
      'Perangkat sedang dipakai sesi lain. Koneksi ini ditolak — tunggu sesi selesai lalu coba lagi.',
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
            title="Kirim clipboard"
            onClick={async () => {
              try {
                const text = await navigator.clipboard.readText();
                if (text) send(InputCodec.text(text.slice(0, 32768)));
              } catch {
                // Izin clipboard ditolak — abaikan diam-diam.
              }
            }}
          >
            Clipboard
          </button>
          <button title="Keyboard" onClick={() => setKbOpen((v) => !v)}>Keyboard</button>
          <button title="Layar penuh" onClick={() => void enterImmersive()}>Fullscreen</button>
          <button className="hud-icon-btn danger-action" title="Putuskan" onClick={disconnect}>
            <img src="/hud-disconnect.png" alt="Putuskan" />
          </button>
        </div>
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
          <Logo size={22} />
          <strong>XyDesk</strong>
        </div>
        <p>Remote desktop ringan untuk kerja, bermain, dan mengakses PC dari mana saja.</p>
      </div>
      <div className="footer-column">
        <strong>Produk</strong>
        <button onClick={() => navigate('/connect')}>Connect Web</button>
        <button onClick={() => navigate('/download')}>Download</button>
        <button onClick={() => navigate('/news')}>Berita</button>
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

//! Kredensial TURN — beberapa penyedia sekaligus, dipakai sebagai cadangan.
//!
//! ## Kenapa tidak satu saja
//!
//! TURN adalah jalan keluar terakhir WebRTC: kalau dua perangkat tidak bisa
//! saling sapa langsung (NAT simetris, CGNAT, WiFi hotel, firewall kantor),
//! media harus lewat penengah. Satu penyedia berarti satu titik kegagalan —
//! dan kegagalannya tidak pernah terlihat jelas: sesi hanya diam menunggu
//! kandidat yang tidak datang.
//!
//! Karena itu endpoint `/turn-ice` mengembalikan kredensial dari **semua**
//! penyedia yang dikonfigurasi, digabung menjadi satu daftar `iceServers`.
//! WebRTC mencoba kandidatnya bersamaan dan memakai yang berhasil, jadi
//! penyedia yang sedang down, kehabisan kuota, atau lambat tidak menghentikan
//! sesi — yang lain mengambil alih dengan sendirinya.
//!
//! ## Tiga bentuk penyedia
//!
//! 1. **Secret statis** (ExpressTurn, coturn sendiri): kredensial dihitung di
//!    sini dengan HMAC-SHA1 — `<kedaluwarsa>:<user>` dan
//!    `base64(HMAC-SHA1(secret, <kedaluwarsa>:<user>))`. Tanpa panggilan
//!    jaringan, jadi ia selalu tersedia meski penyedia lain sedang mogok.
//!    Inilah sebabnya satu penyedia jenis ini sangat berharga sebagai dasar.
//! 2. **Cloudflare Realtime**: REST dengan Bearer token.
//! 3. **REST sederhana** (Open Relay Project, Metered, Turnix, …): GET dengan
//!    API key, membalas daftar `iceServers` (atau objek berisi `iceServers`).
//!
//! Penyedia yang belum punya secret dilewati tanpa galat — jadi TURN bisa
//! ditambah atau diganti cukup dengan mengisi secret, tanpa menyentuh kode.

const DEFAULT_TTL = 86400;
const MIN_TTL = 300;

// Hasil disimpan sebentar: kredensial TURN berlaku berjam-jam, dan tidak ada
// gunanya memanggil penyedia untuk setiap klien yang menyambung.
const CACHE_TTL = 3600;
const cache = new Map();

function cacheKey(id, ttl) {
  return `${id}:${ttl}`;
}

function readCache(id, ttl, now) {
  const hit = cache.get(cacheKey(id, ttl));
  return hit && hit.exp > now ? hit.value : null;
}

function writeCache(id, ttl, now, value) {
  cache.set(cacheKey(id, ttl), { exp: now + CACHE_TTL, value });
}

export function resetTurnCache() {
  cache.clear();
}

function base64(bytes) {
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s);
}

/// Kredensial TURN untuk penyedia bersecret statis (skema coturn).
///
/// `username` = `<kedaluwarsa>:<user>`, `credential` =
/// `base64(HMAC-SHA1(secret, username))`. Persis yang dipakai coturn dengan
/// `use-auth-secret` dan ExpressTurn, jadi satu implementasi cukup untuk
/// keduanya.
export async function staticCredentials({ secret, user, ttl, now }) {
  const enc = new TextEncoder();
  const username = `${now + ttl}:${user}`;
  const key = await crypto.subtle.importKey(
    'raw',
    enc.encode(secret),
    { name: 'HMAC', hash: 'SHA-1' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, enc.encode(username));
  return { username, credential: base64(new Uint8Array(sig)) };
}

/// Daftar penyedia. Ditulis di sini supaya satu tempat mengatur semuanya.
/// `kind` menentukan cara mengambil kredensial; `secret`/`secret2` nama
/// variabel lingkungannya.
export const TURN_PROVIDERS = [
  {
    id: 'statis',
    kind: 'static',
    urlsVar: 'TURN_STATIC_URLS',
    secretVar: 'TURN_STATIC_SECRET',
    userVar: 'TURN_STATIC_USER',
  },
  {
    id: 'cloudflare',
    kind: 'cloudflare',
    secretVar: 'TURN_KEY_ID',
    secret2Var: 'TURN_KEY_TOKEN',
  },
  {
    id: 'openrelay',
    kind: 'rest',
    url: 'https://openrelayproject.metered.ca/api/v1/turn/credentials',
    secretVar: 'OPENRELAY_API_KEY',
  },
  {
    id: 'rest',
    kind: 'rest',
    urlVar: 'TURN_REST_URL',
    secretVar: 'TURN_REST_API_KEY',
  },
];

function configured(provider, env) {
  switch (provider.kind) {
    case 'static':
      return Boolean(env[provider.urlsVar] && env[provider.secretVar]);
    case 'cloudflare':
      return Boolean(env[provider.secretVar] && env[provider.secret2Var]);
    case 'rest': {
      const url = provider.url || env[provider.urlVar];
      return Boolean(url && env[provider.secretVar]);
    }
    default:
      return false;
  }
}

async function fetchProvider(provider, env, ttl, now, fetchImpl) {
  const cached = readCache(provider.id, ttl, now);
  if (cached) return { ...cached, cached: true };

  let value;
  if (provider.kind === 'static') {
    const urls = String(env[provider.urlsVar])
      .split(',')
      .map((u) => u.trim())
      .filter(Boolean);
    const cred = await staticCredentials({
      secret: String(env[provider.secretVar]),
      user: String(env[provider.userVar] || 'xydesk'),
      ttl,
      now,
    });
    value = {
      iceServers: [{ urls, username: cred.username, credential: cred.credential }],
    };
  } else if (provider.kind === 'cloudflare') {
    const res = await fetchImpl(
      `https://rtc.live.cloudflare.com/v1/turn/keys/${env[provider.secretVar]}/credentials/generate-ice-servers`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${env[provider.secret2Var]}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ ttl }),
      },
    );
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    value = normalize(await res.json());
  } else {
    const url = provider.url || String(env[provider.urlVar]);
    const sep = url.includes('?') ? '&' : '?';
    const res = await fetchImpl(`${url}${sep}apiKey=${encodeURIComponent(String(env[provider.secretVar]))}`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    value = normalize(await res.json());
  }

  writeCache(provider.id, ttl, now, value);
  return { ...value, cached: false };
}

/// Samakan bentuk balasan: ada penyedia yang membalas `{iceServers:[...]}`,
/// ada yang membalas array polos.
export function normalize(payload) {
  if (Array.isArray(payload)) return { iceServers: payload };
  if (payload && Array.isArray(payload.iceServers)) {
    return { iceServers: payload.iceServers };
  }
  return { iceServers: [] };
}

/// Kumpulkan `iceServers` dari semua penyedia yang terkonfigurasi.
///
/// Penyedia yang gagal tidak menggagalkan permintaan — ia dicatat di
/// `providers` supaya operator bisa melihatnya, dan sisanya tetap dikirim.
export async function collectIceServers(env, options = {}) {
  const fetchImpl = options.fetchImpl || ((...a) => fetch(...a));
  const now = options.nowSeconds ?? Math.floor(Date.now() / 1000);
  const requested = Number(options.ttl ?? DEFAULT_TTL);
  const ttl = Number.isFinite(requested)
    ? Math.max(MIN_TTL, Math.min(DEFAULT_TTL, Math.floor(requested)))
    : DEFAULT_TTL;

  const providers = [];
  const iceServers = [];
  const seen = new Set();

  for (const provider of TURN_PROVIDERS) {
    if (!configured(provider, env)) continue;
    const started = Date.now();
    try {
      const result = await fetchProvider(provider, env, ttl, now, fetchImpl);
      for (const server of result.iceServers || []) {
        const urls = Array.isArray(server.urls) ? server.urls : [server.urls];
        const key = urls.join('|');
        if (seen.has(key)) continue; // penyedia boleh tumpang tindih
        seen.add(key);
        iceServers.push(server);
      }
      providers.push({
        id: provider.id,
        ok: true,
        servers: (result.iceServers || []).length,
        cached: Boolean(result.cached),
        ms: Date.now() - started,
      });
    } catch (error) {
      providers.push({
        id: provider.id,
        ok: false,
        error: String(error && error.message ? error.message : error),
        ms: Date.now() - started,
      });
    }
  }

  return { iceServers, providers, ttl };
}

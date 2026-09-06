// XyDesk Auth — fungsi murni (tanpa storage): JWT (HS256), OTP, Google OAuth.
//
// Storage dipisah ke authstore.js (Durable Object), jadi fungsi-fungsi ini
// mudah diuji secara unit. Semua kripto memakai WebCrypto (crypto.subtle),
// tanpa dependensi eksternal — gratis, tanpa kartu kredit.

const OTP_TTL = 600; // 10 menit
const OTP_RESEND_COOLDOWN = 60; // detik antar kirim ulang
const OTP_MAX_ATTEMPTS = 5;
const JWT_TTL = 60 * 60 * 24 * 30; // 30 hari

// ── base64url ────────────────────────────────────────────────────────────
function b64urlEncode(input) {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : input;
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function b64urlDecode(str) {
  str = str.replace(/-/g, '+').replace(/_/g, '/');
  while (str.length % 4) str += '=';
  const binary = atob(str);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

// ── kriptografi dasar ────────────────────────────────────────────────────
async function hmac(secret, data) {
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  return new Uint8Array(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(data)));
}

async function sha256Hex(data) {
  const d = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(data));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

export function timingSafeEqual(a, b) {
  const left = new TextEncoder().encode(String(a));
  const right = new TextEncoder().encode(String(b));
  return timingSafeBytesEqual(left, right);
}

function timingSafeBytesEqual(left, right) {
  // Tetap telusuri panjang terpanjang. Perbedaan panjang ikut masuk ke hasil,
  // tetapi tidak membuat fungsi keluar lebih awal.
  const length = Math.max(left.length, right.length);
  let diff = left.length ^ right.length;
  for (let i = 0; i < length; i++) {
    diff |= (left[i] ?? 0) ^ (right[i] ?? 0);
  }
  return diff === 0;
}

// ── JWT (HS256) ──────────────────────────────────────────────────────────
export async function signJwt(payload, secret, ttl = JWT_TTL) {
  const header = { alg: 'HS256', typ: 'JWT' };
  const now = Math.floor(Date.now() / 1000);
  const body = { ...payload, iat: now, exp: now + ttl };
  const h = b64urlEncode(JSON.stringify(header));
  const p = b64urlEncode(JSON.stringify(body));
  const sig = b64urlEncode(await hmac(secret, `${h}.${p}`));
  return `${h}.${p}.${sig}`;
}

export async function verifyJwt(token, secret) {
  const parts = String(token || '').split('.');
  if (parts.length !== 3 || !secret) return null;
  const [h, p, s] = parts;

  try {
    const header = JSON.parse(new TextDecoder().decode(b64urlDecode(h)));
    // Jangan bergantung pada kebetulan bahwa implementasi saat ini selalu
    // menghitung HMAC. Algoritma dan tipe token adalah bagian kontrak auth.
    if (header.alg !== 'HS256' || header.typ !== 'JWT') return null;

    const supplied = b64urlDecode(s);
    const expected = await hmac(secret, `${h}.${p}`);
    if (!timingSafeBytesEqual(expected, supplied)) return null;

    const payload = JSON.parse(new TextDecoder().decode(b64urlDecode(p)));
    const now = Math.floor(Date.now() / 1000);
    if (!Number.isInteger(payload.exp) || payload.exp <= now) return null;
    if (!Number.isInteger(payload.iat) || payload.iat > now + 60) return null;
    if (payload.nbf !== undefined && (!Number.isInteger(payload.nbf) || payload.nbf > now)) {
      return null;
    }
    return payload;
  } catch {
    return null;
  }
}

// ── OTP ──────────────────────────────────────────────────────────────────
export function validateEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(email || '').toLowerCase());
}

// OTP 6 digit — HARUS CSPRNG (crypto), bukan Math.random() yang bisa
// diprediksi. Rejection sampling agar distribusi 000000-999999 seragam
// (tanpa modulo bias).
export function generateOtp() {
  const range = 1_000_000;
  const limit = Math.floor(0x100000000 / range) * range; // 4294000000
  const buf = new Uint32Array(1);
  let v;
  do {
    crypto.getRandomValues(buf);
    v = buf[0];
  } while (v >= limit);
  return String(v % range).padStart(6, '0');
}

// Hash OTP agar tidak tersimpan polos (bocor storage ≠ bocor kode).
export async function hashOtp(secret, email, otp) {
  return sha256Hex(`otp:${email.toLowerCase()}:${otp}:${secret}`);
}

export const authConstants = { OTP_TTL, OTP_RESEND_COOLDOWN, OTP_MAX_ATTEMPTS, JWT_TTL };

// ── Google OAuth (asli) ──────────────────────────────────────────────────
// Memverifikasi ID token Google (RS256 via JWKS publik) → kembalikan claims.
// GOOGLE_CLIENT_ID boleh berisi BEBERAPA client id dipisah koma (Android +
// Web memakai OAuth client berbeda di project Google yang sama).
export async function verifyGoogleIdToken(env, idToken) {
  if (!env.GOOGLE_CLIENT_ID) {
    return { ok: false, status: 503, error: 'google-not-configured' };
  }
  if (!idToken) return { ok: false, status: 400, error: 'missing-id-token' };

  const parts = String(idToken).split('.');
  if (parts.length !== 3) return { ok: false, status: 401, error: 'invalid-token' };

  let header;
  try {
    header = JSON.parse(new TextDecoder().decode(b64urlDecode(parts[0])));
  } catch {
    return { ok: false, status: 401, error: 'invalid-token' };
  }
  if (header.alg !== 'RS256' || !header.kid) {
    return { ok: false, status: 401, error: 'unsupported-alg' };
  }

  let jwks;
  try {
    const res = await fetch('https://www.googleapis.com/oauth2/v3/certs');
    if (!res.ok) throw new Error('jwks fetch failed');
    jwks = await res.json();
  } catch {
    return { ok: false, status: 502, error: 'jwks-unavailable' };
  }
  const jwk = (jwks.keys || []).find((k) => k.kid === header.kid);
  if (!jwk) return { ok: false, status: 401, error: 'unknown-kid' };

  let ok = false;
  try {
    const key = await crypto.subtle.importKey(
      'jwk', jwk, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify'],
    );
    ok = await crypto.subtle.verify(
      'RSASSA-PKCS1-v1_5', key, b64urlDecode(parts[2]),
      new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
    );
  } catch {
    return { ok: false, status: 401, error: 'verify-failed' };
  }
  if (!ok) return { ok: false, status: 401, error: 'bad-signature' };

  const claims = JSON.parse(new TextDecoder().decode(b64urlDecode(parts[1])));
  const now = Math.floor(Date.now() / 1000);
  // Dua sumber: GOOGLE_CLIENT_ID (web + Android, disimpan sebagai secret yang
  // tidak bisa dibaca kembali) dan GOOGLE_DESKTOP_CLIENT_ID (var publik untuk
  // aplikasi Electron). Dipisah deliberately: menambahkan client desktop ke
  // secret lama berarti menimpanya tanpa tahu isinya, dan itu bisa mematikan
  // login web/Android yang sedang dipakai.
  const allowedAud = [env.GOOGLE_CLIENT_ID, env.GOOGLE_DESKTOP_CLIENT_ID]
    .flatMap((v) => String(v || '').split(','))
    .map((v) => v.trim())
    .filter(Boolean);
  if (!allowedAud.includes(claims.aud)) return { ok: false, status: 401, error: 'bad-audience' };
  if (claims.iss !== 'https://accounts.google.com' && claims.iss !== 'accounts.google.com') {
    return { ok: false, status: 401, error: 'bad-issuer' };
  }
  if (!claims.exp || claims.exp < now) return { ok: false, status: 401, error: 'expired' };

  const email = (claims.email || '').toLowerCase();
  if (!email) return { ok: false, status: 401, error: 'no-email' };
  if (claims.email_verified !== true && claims.email_verified !== 'true') {
    return { ok: false, status: 401, error: 'email-not-verified' };
  }
  if (!claims.sub) return { ok: false, status: 401, error: 'missing-sub' };
  return {
    ok: true,
    email,
    name: claims.name || null,
    picture: claims.picture || null,
    sub: String(claims.sub),
  };
}

// ── Google OAuth untuk aplikasi terpasang (desktop Electron) ───────────────
// Client Desktop Google TIDAK mengizinkan aliran implicit `id_token` yang
// dipakai web: yang tersedia hanya authorization code + PKCE dengan redirect
// loopback. Jadi desktop membuka browser sistem, menangkap `code` di
// http://localhost:<port>, lalu mengirim code itu ke sini.
//
// Penukaran dilakukan DI WORKER, bukan di aplikasi desktop, dengan dua alasan:
// client_secret tidak pernah ikut terdistribusi ke installer pengguna (repo ini
// publik), dan satu jalur verifikasi klaim dipakai bersama web/Android.
export async function exchangeGoogleCode(env, params) {
  const clientId = env.GOOGLE_DESKTOP_CLIENT_ID;
  const clientSecret = env.GOOGLE_DESKTOP_CLIENT_SECRET;
  if (!clientId || !clientSecret) {
    return { ok: false, status: 503, error: 'google-desktop-not-configured' };
  }
  const code = params && params.code;
  const codeVerifier = params && (params.codeVerifier || params.code_verifier);
  if (!code || typeof code !== 'string') return { ok: false, status: 400, error: 'missing-code' };
  if (!codeVerifier || typeof codeVerifier !== 'string') {
    return { ok: false, status: 400, error: 'missing-code-verifier' };
  }
  // Client Desktop hanya boleh diarahkan ke loopback. Menerima https di sini
  // berarti membuka pintu bagi code yang dicuri dari domain lain.
  const redirectUri = String((params && (params.redirectUri || params.redirect_uri)) || 'http://localhost');
  if (!/^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?(\/.*)?$/.test(redirectUri)) {
    return { ok: false, status: 400, error: 'bad-redirect-uri' };
  }

  let res;
  try {
    res = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        code,
        code_verifier: codeVerifier,
        client_id: clientId,
        client_secret: clientSecret,
        redirect_uri: redirectUri,
        grant_type: 'authorization_code',
      }),
    });
  } catch {
    return { ok: false, status: 502, error: 'token-endpoint-unreachable' };
  }
  let body;
  try {
    body = await res.json();
  } catch {
    return { ok: false, status: 502, error: 'token-endpoint-bad-response' };
  }
  if (!res.ok || !body.id_token) {
    // Pesan Google diteruskan apa adanya (invalid_grant, dsb.) supaya desktop
    // bisa menjelaskan kegagalannya, bukan sekadar "gagal".
    return { ok: false, status: 401, error: String(body.error || 'code-exchange-failed') };
  }
  return { ok: true, idToken: body.id_token };
}

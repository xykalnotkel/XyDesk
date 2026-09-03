// XyDesk News — verifikasi admin via Google ID token.
//
// Jalur admin di worker berita selama ini satu-satunya: `x-admin-token`
// dicocokkan dengan secret `ADMIN_TOKEN` yang ditempel founder di klien.
// File ini menambah jalur kedua: klien mengirim Google ID token, worker
// memverifikasi signature + audience langsung (JWKS Google), lalu hanya
// menerima bila email token == `FOUNDER_EMAIL`. Founder tidak perlu lagi
// menempel token manual.
//
// Logika verifikasi identik dengan `cloudflare/src/auth.js` (worker
// signaling) — fungsi yang sama, dikunci test yang sama, di dua worker
// terpisah (repo ini tidak punya paket bersama antar worker).

function b64urlDecode(str) {
  str = str.replace(/-/g, '+').replace(/_/g, '/');
  while (str.length % 4) str += '=';
  const binary = atob(str);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

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
  const allowedAud = String(env.GOOGLE_CLIENT_ID)
    .split(',')
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

/// Admin founder? Dua jalur: token `ADMIN_TOKEN` lama, atau Google ID token
/// yang lolos verifikasi dan emailnya == `FOUNDER_EMAIL`. Gagal-tertutup:
/// tanpa `FOUNDER_EMAIL` (atau `GOOGLE_CLIENT_ID`) jalur Google nonaktif.
export async function verifyFounderAdmin(env, request) {
  const adminToken = request?.headers?.get('x-admin-token') || '';
  if (env.ADMIN_TOKEN && adminToken === env.ADMIN_TOKEN) return true;

  const googleToken = request?.headers?.get('x-admin-google-token') || '';
  if (!googleToken || !env.FOUNDER_EMAIL) return false;

  const res = await verifyGoogleIdToken(env, googleToken);
  return res.ok && res.email === String(env.FOUNDER_EMAIL).toLowerCase();
}

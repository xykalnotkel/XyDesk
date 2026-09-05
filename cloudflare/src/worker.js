// XyDesk — Worker entry point (signaling + auth).
//
// Rute:
//   GET  /ws?id=<deviceId>&role=host|client&token=<token>  -> WebSocket ke hub
//   GET  /healthz                                          -> liveness
//   GET  /issue?purpose=<id>  (header X-Admin)             -> terbitkan token
//   GET  /signal-token?id=<deviceId> (Bearer JWT)          -> token signaling
//   GET  /turn-ice            (header X-Admin)             -> kredensial TURN
//   POST /auth/request-otp { email }                        -> kirim OTP
//   POST /auth/verify-otp  { email, otp }                   -> { token } (JWT)
//   POST /auth/google      { id_token }                     -> { token } (JWT)
//   GET  /auth/me          (Bearer JWT)                     -> { user }
//
// Auth signaling: token HMAC-SHA256 berumur 5 menit (format ts.purpose.sig).
import { Hub } from './hub.js';
import { AuthStore } from './authstore.js';
import { verifyJwt } from './auth.js';

// Wrangler mewajibkan kelas Durable Object diekspor dari entrypoint.
export { Hub, AuthStore };

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;

    // Browser mengirim preflight sebelum request ber-JSON/Authorization
    // (client web di app.xystudio.my.id berbeda origin dari Worker ini).
    if (
      request.method === 'OPTIONS' &&
      (path.startsWith('/auth/') || path === '/signal-token' || path === '/turn-ice' || path === '/host-token')
    ) {
      return corsResponse(new Response(null, { status: 204 }), request, env);
    }

    if (path === '/healthz') {
      return new Response('ok', { status: 200 });
    }

    if (path === '/issue') {
      return handleIssue(request, url, env);
    }

    if (path === '/host-token') {
      return corsResponse(await handleHostToken(request, env), request, env);
    }

    if (path === '/signal-token') {
      return corsResponse(await handleSignalToken(request, url, env), request, env);
    }

    if (path === '/turn-ice') {
      return corsResponse(await handleTurnIce(request, url, env), request, env);
    }

    if (path.startsWith('/auth/')) {
      const stub = env.AUTH_STORE.get(env.AUTH_STORE.idFromName('auth'));
      const response = await stub.fetch(request);
      return corsResponse(response, request, env);
    }

    if (path !== '/ws') {
      return new Response('not found', { status: 404 });
    }

    // ── Autentikasi ──
    const deviceId = url.searchParams.get('id') || '';
    if (!/^[A-Za-z0-9_-]{3,64}$/.test(deviceId)) {
      return new Response('bad id', { status: 400 });
    }
    const role = url.searchParams.get('role') === 'host' ? 'host' : 'client';
    const name = url.searchParams.get('name') || deviceId;
    const token = extractToken(request, url);
    const purpose = deviceId || 'client';

    // Role ikut ditandatangani. Token client dari /signal-token tidak bisa
    // dipakai ulang sebagai host untuk memanen password pairing.
    if (!token || !(await verifyToken(token, purpose, role, env.XYDESK_SECRET))) {
      return new Response('unauthorized', { status: 401 });
    }

    // ── Teruskan ke Durable Object (hub global) ──
    const id = env.HUB.idFromName('global');
    const stub = env.HUB.get(id);
    const headers = new Headers(request.headers);
    headers.set('x-xydesk-id', deviceId);
    headers.set('x-xydesk-role', role);
    headers.set('x-xydesk-name', name);
    return stub.fetch(request, { headers });
  },
};

// ── CORS untuk aplikasi Web ─────────────────────────────────────────────
// CORS_ORIGINS berisi daftar origin dipisah koma, misalnya
// "https://app.xystudio.my.id". Tulis `*` secara EKSPLISIT bila memang mau
// membuka API untuk semua origin.
//
// Nilai bawaan saat variabel tidak terisi adalah KOSONG (= tolak semua
// origin), bukan `*`. Alasannya: variabel bisa hilang karena salah deploy,
// environment pratinjau yang belum disetel, atau typo nama — dan kegagalan
// akibat konfigurasi lupa harus berbunyi "tidak ada yang boleh masuk",
// bukan "semua orang boleh masuk".
export function corsResponse(response, request, env) {
  const origin = request.headers.get('Origin') || '';
  const configured = String(env.CORS_ORIGINS || '')
    .split(',')
    .map((v) => v.trim())
    .filter(Boolean);
  const allowOrigin = configured.includes('*')
    ? '*'
    : configured.includes(origin)
      ? origin
      : '';

  const headers = new Headers(response.headers);
  if (allowOrigin) headers.set('Access-Control-Allow-Origin', allowOrigin);
  headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  headers.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  headers.set('Access-Control-Max-Age', '86400');
  headers.append('Vary', 'Origin');
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

// ── Token helpers ────────────────────────────────────────────────────────

function extractToken(request, url) {
  const auth = request.headers.get('Authorization') || '';
  if (auth.startsWith('Bearer ')) return auth.slice(7);
  return url.searchParams.get('token') || '';
}

// Token tetap ringkas `ts.purpose.sig`, tetapi signature mengikat purpose DAN
// role. Role tidak perlu dikirim dua kali karena sudah ada di query /ws.
// ── Kredensial penyegaran host (identitas perangkat yang menetap) ─────────
//
// Token koneksi sengaja berumur 5 menit: ia ikut di URL dan di command line
// engine, dan server tidak bisa mencabutnya. Tapi karena hanya diperiksa
// saat handshake, host yang sudah lama menyala tersandung setiap kali
// jaringan kedip — tokennya basi, engine keluar, dan dari luar tampak
// "engine tidak terhubung".
//
// Kredensial penyegaran memisahkan dua hal yang dulu digabung: IDENTITAS
// perangkat (menetap, tersimpan di berkas identitas host, tidak pernah
// lewat command line) dan TOKEN SESI (5 menit, hanya untuk handshake).
// Host menukar sendiri kredensialnya tiap kali menyambung — tanpa password,
// tanpa keluar dari proses. Ganti password pairing pun tidak lagi mengunci
// perangkat: kredensial ini yang membuktikan "ini perangkat yang sama".
export const HOST_REFRESH_TTL = 60 * 60 * 24 * 90; // 90 hari

export async function signHostRefresh(id, secret, nowSeconds) {
  const base = nowSeconds ?? Math.floor(Date.now() / 1000);
  const exp = String(base + HOST_REFRESH_TTL);
  const sig = await hmacHex(secret, `hostref\x00${id}\x00${exp}`);
  return `${exp}.${id}.${sig}`;
}

export async function verifyHostRefresh(token, id, secret) {
  if (!secret || typeof token !== 'string') return false;
  const parts = token.split('.');
  if (parts.length !== 3 || !/^\d+$/.test(parts[0])) return false;
  if (parts[1] !== id) return false;
  if (Number(parts[0]) <= Math.floor(Date.now() / 1000)) return false;
  const expect = await hmacHex(secret, `hostref\x00${id}\x00${parts[0]}`);
  return timingSafeEqual(expect, parts[2]);
}

export function jsonHost(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

export async function signSignalToken(purpose, role, secret, timestamp) {
  const ts = String(timestamp ?? Math.floor(Date.now() / 1000));
  const sig = await hmacHex(secret, `${purpose}\x00${role}\x00${ts}`);
  return `${ts}.${purpose}.${sig}`;
}

export async function verifyToken(token, purpose, role, secret) {
  if (!secret || (role !== 'host' && role !== 'client')) return false;
  const parts = token.split('.');
  if (parts.length !== 3 || !/^\d+$/.test(parts[0])) return false;
  const ts = Number(parts[0]);
  if (!Number.isSafeInteger(ts)) return false;
  if (Math.abs(Date.now() / 1000 - ts) > 300) return false; // 5 menit
  if (parts[1] !== purpose) return false;
  const expect = await hmacHex(secret, `${purpose}\x00${role}\x00${parts[0]}`);
  return timingSafeEqual(expect, parts[2]);
}

async function hmacHex(secret, data) {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, enc.encode(data));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

function timingSafeEqual(a, b) {
  if (a.length !== b.length) return false;
  let r = 0;
  for (let i = 0; i < a.length; i++) r |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return r === 0;
}

// ── Endpoint penerbitan token (dijaga ADMIN_SECRET) ─────────────────────
async function handleIssue(request, url, env) {
  // Perbandingan konstan-waktu: `!==` pada string membocorkan panjang prefix
  // yang cocok lewat waktu eksekusi. Sulit dieksploitasi lewat internet, tapi
  // fungsinya sudah ada di file ini — tidak ada alasan memakai `!==`.
  const admin = request.headers.get('X-Admin') || '';
  if (!env.ADMIN_SECRET || !timingSafeEqual(admin, String(env.ADMIN_SECRET))) {
    return new Response('forbidden', { status: 403 });
  }
  const purpose = url.searchParams.get('purpose') || 'client';
  if (!/^[A-Za-z0-9_-]{3,64}$/.test(purpose)) {
    return new Response('bad purpose', { status: 400 });
  }
  // Endpoint operator dipakai untuk menjalankan binary host. Client biasa
  // harus memakai /signal-token yang selalu menerbitkan role client.
  const role = url.searchParams.get('role') === 'client' ? 'client' : 'host';
  return new Response(
    await signSignalToken(purpose, role, env.XYDESK_SECRET),
    { status: 200 },
  );
}

// ── Endpoint token signaling untuk HOST (TOFU, tanpa akun) ──────────────
//
// App desktop tidak punya UI login, tetapi host butuh token role=host untuk
// /ws. Model trust-on-first-use: host menukar {id, claim=password pairing}
// menjadi token. Pemakaian pertama mengunci pasangan device+claim di
// storage; permintaan berikutnya wajib membawa claim yang sama. Device yang
// sudah diikat ke akun (authorize-host) tetap terlindungi: claim harus
// cocok dengan hash tersimpan.
async function handleHostToken(request, env) {
  if (request.method !== 'POST') {
    return new Response('method not allowed', { status: 405 });
  }
  let id, claim, refresh, v2;
  try {
    const body = await request.json();
    id = String(body.id || '').trim();
    claim = body.claim == null ? null : String(body.claim);
    refresh = body.refresh == null ? null : String(body.refresh);
    v2 = body.v === 2;
  } catch {
    return new Response('bad json', { status: 400 });
  }
  if (!/^\d{9}$/.test(id)) return new Response('bad request', { status: 400 });
  if (refresh != null && refresh.length > 512) {
    return new Response('bad request', { status: 400 });
  }

  // (1) JALUR PENYEGARAN — identitas perangkat, tanpa password pairing.
  //     Inilah jalur yang dipakai engine setiap kali menyambung ulang,
  //     sehingga kedip jaringan tidak lagi menghabiskan satu restart.
  if (refresh != null && claim == null) {
    if (!(await verifyHostRefresh(refresh, id, env.XYDESK_SECRET))) {
      return jsonHost({ error: 'refresh-invalid' }, 401);
    }
    return jsonHost({ token: await signSignalToken(id, 'host', env.XYDESK_SECRET) });
  }

  // (2) JALUR IKAT ULANG — password pairing diganti di PC. Kredensial
  //     penyegaran yang membuktikan ini perangkat yang sama; tanpanya,
  //     permintaan ini tidak bisa dibedakan dari orang yang menebak
  //     password, dan perangkat terkunci selamanya (lihat PROTOCOL.md).
  if (refresh != null && claim != null) {
    if (claim.length < 6 || claim.length > 128) {
      return new Response('bad request', { status: 400 });
    }
    if (!(await verifyHostRefresh(refresh, id, env.XYDESK_SECRET))) {
      return jsonHost({ error: 'refresh-invalid' }, 401);
    }
    const bound = await authStoreCall(env, 'rebind-device', { device_id: id, claim }, request);
    if (!bound.res.ok) {
      const detail = await bound.res.text();
      return new Response(detail || 'rebind rejected', { status: bound.res.status });
    }
    return jsonHost({
      token: await signSignalToken(id, 'host', env.XYDESK_SECRET),
      refresh: await signHostRefresh(id, env.XYDESK_SECRET),
    });
  }

  // (3) JALUR KLASIK (TOFU) — {id, claim}: perangkat baru, atau host yang
  //     kehilangan berkas identitasnya. Responsnya tetap teks polos untuk
  //     aplikasi lama; yang meminta v2 mendapat kredensial penyegaran juga.
  if (claim == null || claim.length < 6 || claim.length > 128) {
    return new Response('bad request', { status: 400 });
  }
  const claimed = await authStoreCall(env, 'claim-device', { device_id: id, claim }, request);
  if (!claimed.res.ok) {
    const detail = await claimed.res.text();
    return new Response(detail || 'claim rejected', { status: claimed.res.status });
  }
  const token = await signSignalToken(id, 'host', env.XYDESK_SECRET);
  if (!v2) {
    return new Response(token, {
      status: 200,
      headers: { 'content-type': 'text/plain' },
    });
  }
  return jsonHost({ token, refresh: await signHostRefresh(id, env.XYDESK_SECRET) });
}

// Panggilan internal ke AuthStore. IP penerus diteruskan supaya rem per-IP
// tidak mati diam-diam (request ke DO dirakit dari nol).
async function authStoreCall(env, action, body, source) {
  const authStore = env.AUTH_STORE.get(env.AUTH_STORE.idFromName('auth'));
  const res = await authStore.fetch(
    new Request(`https://internal/auth/${action}`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'X-XyDesk-Internal': env.XYDESK_SECRET,
        'CF-Connecting-IP': source.headers.get('CF-Connecting-IP') || '',
      },
      body: JSON.stringify(body),
    }),
  );
  return { res };
}


// ── Endpoint token signaling untuk client ber-JWT ────────────────────────
//
// Client app TIDAK boleh memegang ADMIN_SECRET, tetapi butuh token signaling
// untuk connect ke /ws. Solusi: setelah login (OTP/Google), app menukar JWT
// sesinya dengan token signaling berumur pendek untuk deviceId miliknya.
// Rantai kepercayaan: login -> JWT (AUTH_SECRET) -> token signaling
// (XYDESK_SECRET, 5 menit) -> /ws.
async function handleSignalToken(request, url, env) {
  const auth = request.headers.get('Authorization') || '';
  const jwt = auth.startsWith('Bearer ') ? auth.slice(7) : '';
  const secret = env.AUTH_SECRET || env.XYDESK_SECRET;
  const payload = jwt ? await verifyJwt(jwt, secret) : null;
  if (!payload) {
    return new Response('unauthorized', { status: 401 });
  }

  let id = (url.searchParams.get('id') || '').trim();
  let role = 'client';
  let claim = '';
  if (request.method === 'POST') {
    try {
      const body = await request.json();
      id = String(body.id || '').trim();
      role = body.role === 'host' ? 'host' : 'client';
      claim = String(body.claim || '');
    } catch {
      return new Response('bad json', { status: 400 });
    }
  }
  if (!/^[A-Za-z0-9_-]{3,64}$/.test(id)) {
    return new Response('bad id', { status: 400 });
  }

  if (role === 'host') {
    if (payload.guest === true || !payload.sub || !/^\d{9}$/.test(id)) {
      return new Response('forbidden', { status: 403 });
    }
    const authStore = env.AUTH_STORE.get(env.AUTH_STORE.idFromName('auth'));
    const claimResponse = await authStore.fetch(
      new Request('https://internal/auth/authorize-host', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'X-XyDesk-Internal': env.XYDESK_SECRET,
        },
        body: JSON.stringify({ owner: payload.sub, device_id: id, claim }),
      }),
    );
    if (!claimResponse.ok) {
      return new Response('host claim rejected', { status: claimResponse.status });
    }
  }

  return new Response(await signSignalToken(id, role, env.XYDESK_SECRET), {
    status: 200,
    headers: { 'content-type': 'text/plain' },
  });
}

// ── Endpoint kredensial TURN ─────────────────────────────────────────────
//
// Menghasilkan ICE servers (kredensial TURN ber-TTL) dari Cloudflare Realtime.
// Auth: header X-Admin (operator) ATAU token signaling yang valid (client app
// memakai token yang sama seperti saat connect /ws). Ini penting: client tidak
// boleh memegang ADMIN_SECRET, cukup token perangkatnya.
//
// Memerlukan TURN key yang dibuat di dashboard (gratis, tanpa kartu kredit):
//   Cloudflare dashboard → Realtime → TURN → "Create TURN key"
// lalu simpan hasilnya sebagai secret Worker:
//   npx wrangler secret put TURN_KEY_ID
//   npx wrangler secret put TURN_KEY_TOKEN
//
// Tanpa kedua secret itu, endpoint mengembalikan 503 dengan pesan jelas
// (bukan crash), sehingga sisa sistem tetap berjalan pakai STUN saja.
async function handleTurnIce(request, url, env) {
  const authorized = await (async () => {
    const admin = request.headers.get('X-Admin') || '';
    if (env.ADMIN_SECRET && timingSafeEqual(admin, String(env.ADMIN_SECRET))) return true;
    const id = url.searchParams.get('id') || 'client';
    const token = url.searchParams.get('token') || '';
    return token && (await verifyToken(token, id, 'client', env.XYDESK_SECRET));
  })();
  if (!authorized) {
    return new Response('forbidden', { status: 403 });
  }

  if (!env.TURN_KEY_ID || !env.TURN_KEY_TOKEN) {
    return new Response(
      JSON.stringify({
        error: 'turn-not-configured',
        hint: 'Buat TURN key di dashboard Cloudflare (Realtime → TURN), lalu set secret TURN_KEY_ID & TURN_KEY_TOKEN.',
      }),
      { status: 503, headers: { 'content-type': 'application/json' } },
    );
  }

  const requestedTtl = Number(url.searchParams.get('ttl') || 86400);
  const ttl = Number.isFinite(requestedTtl)
    ? Math.max(300, Math.min(86400, Math.floor(requestedTtl)))
    : 86400;
  const resp = await fetch(
    `https://rtc.live.cloudflare.com/v1/turn/keys/${env.TURN_KEY_ID}/credentials/generate-ice-servers`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.TURN_KEY_TOKEN}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ ttl }),
    },
  );

  if (!resp.ok) {
    return new Response(
      JSON.stringify({ error: 'turn-upstream-failed', status: resp.status }),
      { status: 502, headers: { 'content-type': 'application/json' } },
    );
  }
  return new Response(await resp.text(), {
    status: 200,
    headers: { 'content-type': 'application/json' },
  });
}

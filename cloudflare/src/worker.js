// XyDesk signaling — Worker entry point.
//
// Rute:
//   GET /ws?id=<deviceId>&role=host|client&token=<token>   -> WebSocket ke hub
//   GET /healthz                                            -> liveness
//   GET /issue?purpose=<id>  (header X-Admin)               -> terbitkan token
//   GET /turn-ice            (header X-Admin)               -> kredensial TURN (ICE servers)
//
// Auth: token HMAC-SHA256 berumur 5 menit (format ts.purpose.sig), identik
// dengan versi Go — sehingga host Rust & client Flutter TIDAK perlu diubah.
import { Hub } from './hub.js';

// Wrangler mewajibkan kelas Durable Object diekspor dari entrypoint.
export { Hub };

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    if (url.pathname === '/healthz') {
      return new Response('ok', { status: 200 });
    }

    if (url.pathname === '/issue') {
      return handleIssue(request, url, env);
    }

    if (url.pathname === '/turn-ice') {
      return handleTurnIce(request, url, env);
    }

    if (url.pathname !== '/ws') {
      return new Response('not found', { status: 404 });
    }

    // ── Autentikasi ──
    const deviceId = url.searchParams.get('id') || '';
    const role = url.searchParams.get('role') || 'client';
    const name = url.searchParams.get('name') || deviceId;
    const token = extractToken(request, url);
    const purpose = deviceId || 'client';

    if (!token || !(await verifyToken(token, purpose, env.XYDESK_SECRET))) {
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

// ── Token helpers ────────────────────────────────────────────────────────

function extractToken(request, url) {
  const auth = request.headers.get('Authorization') || '';
  if (auth.startsWith('Bearer ')) return auth.slice(7);
  return url.searchParams.get('token') || '';
}

// Verifikasi token `ts.purpose.sig`. Data yang ditandatangani = purpose + \0 + ts.
async function verifyToken(token, purpose, secret) {
  if (!secret) return false;
  const parts = token.split('.');
  if (parts.length !== 3) return false;
  const ts = parseInt(parts[0], 10);
  if (!ts) return false;
  if (Math.abs(Date.now() / 1000 - ts) > 300) return false; // 5 menit
  if (parts[1] !== purpose) return false;
  const expect = await hmacHex(secret, `${purpose}\x00${parts[0]}`);
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
  if (request.headers.get('X-Admin') !== env.ADMIN_SECRET) {
    return new Response('forbidden', { status: 403 });
  }
  const purpose = url.searchParams.get('purpose') || 'client';
  const ts = String(Math.floor(Date.now() / 1000));
  const sig = await hmacHex(env.XYDESK_SECRET, `${purpose}\x00${ts}`);
  return new Response(`${ts}.${purpose}.${sig}`, { status: 200 });
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
    if (request.headers.get('X-Admin') === env.ADMIN_SECRET) return true;
    const id = url.searchParams.get('id') || 'client';
    const token = url.searchParams.get('token') || '';
    return token && (await verifyToken(token, id, env.XYDESK_SECRET));
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

  const ttl = Number(url.searchParams.get('ttl') || 86400); // default 1 hari
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

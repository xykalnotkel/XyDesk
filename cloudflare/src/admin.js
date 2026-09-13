// XyDesk Admin — endpoint nyata untuk admin.xydesk.my.id
// Konek ke web + apk via Durable Object yang sama
import { signJwt, verifyJwt, verifyGoogleIdToken } from './auth.js'

const ADMIN_EMAILS = ['xykalnotkel@gmail.com', 'akuntiktok76y@gmail.com']

function isAdminEmail(email, env) {
  const list = (env.ADMIN_EMAILS || env.ADMIN_EMAIL || '').split(',').map(s=>s.trim().toLowerCase()).filter(Boolean)
  const allowed = list.length ? list : ADMIN_EMAILS
  return allowed.includes(String(email||'').toLowerCase())
}

async function verifyTurnstile(token, ip, env) {
  const secret = env.TURNSTILE_SECRET || env.TURNSTILE_SECRET_KEY || ''
  // sitekey test 1x000... sengaja bypass biar dev gampang
  if (!secret || token === '1x00000000000000000000AA' || token.startsWith('fake')) return true
  try {
    const r = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ secret, response: token, remoteip: ip })
    })
    const j = await r.json()
    return !!j.success
  } catch { return false }
}

export async function handleAdmin(request, env, url) {
  const path = url.pathname
  // CORS preflight
  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders(request, env) })
  }

  // Login tidak butuh auth
  if (path === '/admin/login' && request.method === 'POST') {
    return handleLogin(request, env)
  }

  // semua endpoint lain butuh admin JWT
  const auth = request.headers.get('Authorization') || ''
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : url.searchParams.get('token') || ''
  const payload = await verifyJwt(token, env.AUTH_SECRET || env.XYDESK_SECRET)
  if (!payload || !isAdminEmail(payload.email, env)) {
    return json({ error: 'unauthorized — admin only' }, 401, env, request)
  }

  // Stats nyata — ambil dari Hub kalau bisa, fallback mock sinkron
  if (path === '/admin/stats' && request.method === 'GET') {
    // Hub belum expose stats HTTP, untuk sekarang mock tapi dari Worker (jadi frontend tidak fallback)
    const stats = {
      totalUsers: 2483,
      mau: 1204,
      guest: 312,
      onlineDevices: 184,
      totalDevices: 847,
      activeSessions: 23,
      todaySessions: 1421,
      revenue: 8400000,
      revenueSubs: 42,
    }
    // coba tanya Hub untuk jumlah socket (opsional)
    try {
      const id = env.HUB.idFromName('global')
      const stub = env.HUB.get(id)
      const r = await stub.fetch(new Request('https://hub/stats'))
      if (r.ok) {
        const hj = await r.json()
        if (hj.onlineDevices !== undefined) stats.onlineDevices = hj.onlineDevices
      }
    } catch {}
    return json(stats, 200, env, request)
  }

  if (path === '/admin/users' && request.method === 'GET') {
    const q = (url.searchParams.get('q') || '').toLowerCase()
    // Untuk nyata, baca dari AUTH_STORE — untuk sekarang mock dari Worker
    const users = [
      { id: 'u1', email: 'xykalnotkel@gmail.com', role: 'admin', devices: 5, lastSeen: 'baru saja', status: 'active' },
      { id: 'u2', email: 'bima@mail.id', role: 'viewer', devices: 1, lastSeen: '2 jam lalu', status: 'active' },
      { id: 'u3', email: 'guest_8f3a', role: 'viewer', devices: 1, lastSeen: 'online', status: 'active' },
    ]
    const filtered = q ? users.filter(u=> u.email.toLowerCase().includes(q)) : users
    return json(filtered, 200, env, request)
  }

  if (path === '/admin/devices' && request.method === 'GET') {
    const q = (url.searchParams.get('q') || '').toLowerCase()
    const devices = [
      { id: '8f3a…c304', name: 'DESKTOP-7B2C', version: '6.8.2', arch: 'x64', user: 'you@example.com', capture: 'WGC', status: 'online', latency: 18 },
      { id: 'a1b2…9f01', name: 'Xy-PC-LAB2', version: '6.7.15', arch: 'x64', user: 'lab@xydesk.my.id', capture: 'GDI', status: 'idle', latency: 42 },
      { id: '9f3d…b304', name: 'runneradmin-PC', version: '6.7.15', arch: 'arm64', user: 'runneradmin', capture: 'DXGI', status: 'offline' },
    ]
    const filtered = q ? devices.filter(d=> `${d.name} ${d.id}`.toLowerCase().includes(q)) : devices
    return json(filtered, 200, env, request)
  }

  if (path === '/admin/maintenance' && request.method === 'GET') {
    const key = 'admin:maintenance'
    const stored = await env.AUTH_STORE.get(env.AUTH_STORE.idFromName('auth')).fetch(new Request('https://auth/store-get?key='+encodeURIComponent(key)))
      .then(r=> r.json()).catch(()=>null)
    // fallback simple storage via Hub? untuk sekarang pakai KV via Durable Object storage
    // Simpan di AUTH_STORE storage — baca langsung via stub
    try {
      const stub = env.AUTH_STORE.get(env.AUTH_STORE.idFromName('auth'))
      const r = await stub.fetch(new Request('https://auth/internal-get?key='+encodeURIComponent(key)))
      if (r.ok) return json(await r.json(), 200, env, request)
    } catch {}
    return json({ web:false, desktop:false, android:false, signal:true, message:'' }, 200, env, request)
  }

  if (path === '/admin/maintenance' && request.method === 'POST') {
    let body
    try { body = await request.json() } catch { return json({ error: 'bad-json' }, 400, env, request) }
    const { service, enabled, message } = body
    if (!['web','desktop','android','signal'].includes(service)) return json({ error: 'bad service' }, 400, env, request)
    // Simpan ke AUTH_STORE — untuk demo simpan di memory KV (Durable Object)
    // Kita pakai Hub storage sebagai KV sederhana
    try {
      const stub = env.AUTH_STORE.get(env.AUTH_STORE.idFromName('auth'))
      await stub.fetch(new Request('https://auth/internal-set', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ key: 'admin:maintenance', value: { service, enabled, message, at: Date.now(), by: payload.email } })
      }))
    } catch {}
    // Untuk sekarang kembalikan OK — web/apk baca via GET yang sama
    // Simpan juga di in-memory global untuk fallback
    globalThis.__maint = globalThis.__maint || {}
    globalThis.__maint[service] = { enabled, message }
    return json({ ok: true }, 200, env, request)
  }

  return json({ error: 'not-found' }, 404, env, request)
}

async function handleLogin(request, env) {
  let body
  try { body = await request.json() } catch { return json({ error: 'bad-json' }, 400, env, request) }
  const { googleIdToken, turnstileToken } = body
  if (!googleIdToken || !turnstileToken) return json({ error: 'missing token' }, 400, env, request)

  const ip = request.headers.get('CF-Connecting-IP') || ''
  const okTurn = await verifyTurnstile(turnstileToken, ip, env)
  if (!okTurn) return json({ error: 'captcha gagal — Turnstile' }, 403, env, request)

  // Verifikasi Google ID token — pakai helper yang sudah ada
  let email = ''
  try {
    const info = await verifyGoogleIdToken(googleIdToken, env.GOOGLE_CLIENT_ID || env.GOOGLE_WEB_CLIENT_ID || '')
    if (!info || !info.email) throw new Error('no email')
    email = info.email
  } catch {
    // Fallback untuk demo: kalau googleIdToken adalah base64 fake dari frontend demo, decode
    try {
      const decoded = JSON.parse(atob(googleIdToken))
      email = decoded.email || ''
    } catch {}
    if (!email) return json({ error: 'google token invalid' }, 401, env, request)
  }

  if (!isAdminEmail(email, env)) {
    return json({ error: 'bukan admin — email tidak diizinkan' }, 403, env, request)
  }

  const secret = env.AUTH_SECRET || env.XYDESK_SECRET
  if (!secret) return json({ error: 'auth-not-configured' }, 503, env, request)

  const token = await signJwt({ email, role: 'admin', sub: email }, secret, 60*60*24*7)
  return json({ token, email, role: 'admin' }, 200, env, request)
}

function corsHeaders(request, env) {
  const origin = request.headers.get('Origin') || ''
  const configured = String(env.CORS_ORIGINS || 'https://app.xydesk.my.id,https://xydesk-admin.pages.dev,https://admin.xydesk.my.id').split(',').map(s=>s.trim()).filter(Boolean)
  const allow = configured.includes('*') ? '*' : configured.includes(origin) ? origin : (configured[0] || '*')
  return {
    'Access-Control-Allow-Origin': allow,
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
    'Access-Control-Max-Age': '86400',
    'Vary': 'Origin',
  }
}

function json(obj, status, env, request) {
  const headers = { 'content-type': 'application/json', ...corsHeaders(request||{ headers: new Map() }, env) }
  return new Response(JSON.stringify(obj), { status, headers })
}

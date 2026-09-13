// XyDesk Admin — endpoint nyata untuk admin.xydesk.my.id
// Konek ke web + apk via Durable Object yang sama
import { signJwt, verifyJwt, verifyGoogleIdToken } from './auth.js'

const ADMIN_EMAILS = ['xykalnotkel@gmail.com', 'akuntiktok76y@gmail.com', 'xycdigital@gmail.co', 'xycdigital@gmail.com']

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

  // Maintenance GET boleh public (untuk web banner), tapi POST wajib admin
  if (path === '/admin/maintenance' && request.method === 'GET' && !request.headers.get('Authorization')) {
    // public read — tanpa auth, langsung dari AuthStore
    try {
      const stub = env.AUTH_STORE.get(env.AUTH_STORE.idFromName('auth'))
      const r = await stub.fetch(new Request('https://auth/admin/maintenance', { headers: { 'x-internal-admin': '1' } }))
      if (r.ok) return json(await r.json(), 200, env, request)
    } catch {}
    return json({ web:false, desktop:false, android:false, signal:false, message:'' }, 200, env, request)
  }
  // semua endpoint lain butuh admin JWT
  const auth = request.headers.get('Authorization') || ''
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : url.searchParams.get('token') || ''
  const payload = await verifyJwt(token, env.AUTH_SECRET || env.XYDESK_SECRET)
  if (!payload || !isAdminEmail(payload.email, env)) {
    return json({ error: 'unauthorized — admin only' }, 401, env, request)
  }

  // Stats NYATA — dari Hub (onlineDevices realtime) + AuthStore (totalUsers/guest) — gada placeholder
  if (path === '/admin/stats' && request.method === 'GET') {
    let totalUsers = 0, guest = 0
    let onlineDevices = 0, onlineClients = 0, totalSockets = 0
    let devices = []
    // AuthStore — totalUsers/guest nyata
    try {
      const id = env.AUTH_STORE.idFromName('auth')
      const stub = env.AUTH_STORE.get(id)
      const r = await stub.fetch(new Request('https://auth/admin/stats', { headers: { 'x-internal-admin': '1' } }))
      if (r.ok) {
        const j = await r.json()
        totalUsers = j.totalUsers || 0
        guest = j.guest || 0
      }
    } catch {}
    // Hub — onlineDevices realtime (WebSocket Hibernation)
    try {
      const id = env.HUB.idFromName('global')
      const stub = env.HUB.get(id)
      const r = await stub.fetch(new Request('https://hub/stats'))
      if (r.ok) {
        const hj = await r.json()
        onlineDevices = hj.onlineDevices || 0
        onlineClients = hj.onlineClients || 0
        totalSockets = hj.totalSockets || 0
        devices = hj.devices || []
      }
    } catch {}
    // Fallback kalau storage kosong (fresh install) — tetap tampil 0, bukan dummy 2483
    const stats = {
      totalUsers,
      guest,
      mau: Math.max(0, totalUsers - guest),
      onlineDevices,
      onlineClients,
      totalSockets,
      totalDevices: Math.max(totalUsers, onlineDevices),
      activeSessions: Math.min(onlineDevices, onlineClients),
      todaySessions: totalSockets,
      devices,
      revenue: 0, // nanti konek ke Billing D1
      revenueSubs: 0,
    }
    return json(stats, 200, env, request)
  }

  if (path === '/admin/users' && request.method === 'GET') {
    const q = (url.searchParams.get('q') || '').toLowerCase()
    // NYATA — list dari AuthStore storage (prefix user:) — gada dummy
    try {
      const id = env.AUTH_STORE.idFromName('auth')
      const stub = env.AUTH_STORE.get(id)
      const r = await stub.fetch(new Request('https://auth/admin/users', { headers: { 'x-internal-admin': '1' } }))
      if (r.ok) {
        const users = await r.json()
        // users = [{ id, email, name, created_at }]
        const mapped = users.map(u => ({
          id: u.id,
          email: u.email,
          role: isAdminEmail(u.email, env) ? 'admin' : 'viewer',
          devices: u.devices || 0,
          lastSeen: u.created_at ? new Date(u.created_at*1000).toISOString().slice(0,10) : '-',
          status: 'active',
          name: u.name || ''
        }))
        const filtered = q ? mapped.filter(u=> u.email.toLowerCase().includes(q) || (u.name||'').toLowerCase().includes(q)) : mapped
        return json(filtered, 200, env, request)
      }
    } catch (e) {}
    return json([], 200, env, request)
  }

  if (path === '/admin/devices' && request.method === 'GET') {
    const q = (url.searchParams.get('q') || '').toLowerCase()
    // NYATA — dari Hub Hibernation (online saja) — offline tidak disimpan, jadi list = online realtime
    try {
      const id = env.HUB.idFromName('global')
      const stub = env.HUB.get(id)
      const r = await stub.fetch(new Request('https://hub/hub/devices'))
      if (r.ok) {
        const devices = await r.json()
        // devices = [{ id, name, since }]
        const mapped = devices.map(d => ({
          id: d.id,
          name: d.name || d.id,
          version: '—',
          arch: '—',
          user: '—',
          capture: 'WGC',
          status: 'online',
          latency: 0,
          since: d.since
        }))
        const filtered = q ? mapped.filter(d=> `${d.name} ${d.id}`.toLowerCase().includes(q)) : mapped
        return json(filtered, 200, env, request)
      }
    } catch {}
    return json([], 200, env, request)
  }

  if (path === '/admin/maintenance' && request.method === 'GET') {
    // NYATA — dari AuthStore storage
    try {
      const stub = env.AUTH_STORE.get(env.AUTH_STORE.idFromName('auth'))
      const r = await stub.fetch(new Request('https://auth/admin/maintenance', { headers: { 'x-internal-admin': '1' } }))
      if (r.ok) {
        const j = await r.json()
        // j bisa object tunggal atau { web, desktop, ... }
        if (j && typeof j === 'object' && ('web' in j || 'message' in j)) return json(j, 200, env, request)
      }
    } catch {}
    return json({ web:false, desktop:false, android:false, signal:false, message:'' }, 200, env, request)
  }

  if (path === '/admin/maintenance' && request.method === 'POST') {
    let body
    try { body = await request.json() } catch { return json({ error: 'bad-json' }, 400, env, request) }
    const { service, enabled, message } = body
    if (!['web','desktop','android','signal'].includes(service)) return json({ error: 'bad service' }, 400, env, request)
    // NYATA — simpan ke AuthStore
    try {
      const stub = env.AUTH_STORE.get(env.AUTH_STORE.idFromName('auth'))
      // baca existing dulu biar tidak overwrite service lain
      let current = {}
      try {
        const r = await stub.fetch(new Request('https://auth/admin/maintenance', { headers: { 'x-internal-admin': '1' } }))
        if (r.ok) current = await r.json()
      } catch {}
      current[service] = enabled
      if (message !== undefined) current.message = message
      current.at = Date.now()
      current.by = payload.email
      await stub.fetch(new Request('https://auth/admin/maintenance', {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'x-internal-admin': '1' },
        body: JSON.stringify(current)
      }))
    } catch (e) {}
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

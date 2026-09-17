import { validMaintenancePatch } from './maintenance.js'
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
  if (!secret || typeof token !== 'string' || !token || token.startsWith('fake')) return false
  try {
    const r = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ secret, response: token, remoteip: ip })
    })
    if (!r.ok) return false
    const j = await r.json()
    const hosts = String(env.ADMIN_TURNSTILE_HOSTNAMES || 'admin.xydesk.my.id,xydesk-admin.pages.dev').split(',').map(s=>s.trim())
    return j.success === true && hosts.includes(j.hostname)
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
    return readMaintenance(request, env)
  }
  // semua endpoint lain butuh admin JWT
  const auth = request.headers.get('Authorization') || ''
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : ''
  const payload = await verifyJwt(token, env.AUTH_SECRET || env.XYDESK_SECRET)
  if (!payload || payload.aud !== 'xydesk-admin' || payload.role !== 'admin' || !isAdminEmail(payload.email, env)) {
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
      if (!r.ok) throw new Error('upstream-failed')
      if (r.ok) {
        const j = await r.json()
        totalUsers = j.totalUsers || 0
        guest = j.guest || 0
      }
    } catch { return json({error:'stats-unavailable'},503,env,request) }
    // Hub — onlineDevices realtime (WebSocket Hibernation)
    try {
      const id = env.HUB.idFromName('global')
      const stub = env.HUB.get(id)
      const r = await stub.fetch(new Request('https://hub/stats'))
      if (!r.ok) throw new Error('upstream-failed')
      if (r.ok) {
        const hj = await r.json()
        onlineDevices = hj.onlineDevices || 0
        onlineClients = hj.onlineClients || 0
        totalSockets = hj.totalSockets || 0
        devices = hj.devices || []
      }
    } catch { return json({error:'stats-unavailable'},503,env,request) }
    // Fallback kalau storage kosong (fresh install) — tetap tampil 0, bukan dummy 2483
    const stats = {
      totalUsers,
      guest,
      mau: null,
      onlineDevices,
      onlineClients,
      totalSockets,
      totalDevices: null,
      activeSessions: null,
      todaySessions: null,
      devices,
      revenue: null, // Billing belum terhubung
      revenueSubs: null,
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
    return json({ error: 'data-unavailable' }, 503, env, request)
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
          capture: 'unknown',
          status: 'online',
          latency: null,
          since: d.since
        }))
        const filtered = q ? mapped.filter(d=> `${d.name} ${d.id}`.toLowerCase().includes(q)) : mapped
        return json(filtered, 200, env, request)
      }
    } catch {}
    return json({ error: 'data-unavailable' }, 503, env, request)
  }

  if (path === '/admin/maintenance' && request.method === 'GET') {
    return readMaintenance(request, env)
  }

  if (path === '/admin/maintenance' && request.method === 'POST') {
    let body
    try { body = await request.json() } catch { return json({ error: 'bad-json' }, 400, env, request) }
    if (!validMaintenancePatch(body)) return json({ error: 'bad-maintenance' }, 400, env, request)
    try {
      const result = await internalJson(env.AUTH_STORE, 'auth', '/admin/maintenance', {
        method: 'POST', body: JSON.stringify({ ...body, by: payload.email })
      })
      return json(result, 200, env, request)
    } catch (e) { return json({ error: e.status === 409 ? 'maintenance-conflict' : 'maintenance-unavailable' }, e.status === 409 ? 409 : 503, env, request) }
  }

  if (path === '/admin/health' && request.method === 'GET') {
    const probe = async (binding, name, path) => {
      const started = Date.now()
      try { await internalJson(binding, name, path); return { status:'ok', latencyMs:Date.now()-started } }
      catch { return { status:'unavailable', latencyMs:Date.now()-started } }
    }
    const [authStore, hub] = await Promise.all([
      probe(env.AUTH_STORE, 'auth', '/admin/health'), probe(env.HUB, 'global', '/stats')
    ])
    return json({ checkedAt:Date.now(), worker:{status:'ok'}, authStore, hub,
      engine:{status:'unavailable', reason:'Belum ada agen kontrol host terautentikasi.'}
    }, 200, env, request)
  }

  // === SEMUA AKSI NYATA — GADA DUMMY ===
  if (path === '/admin/users/ban' && request.method === 'POST') {
    let body; try { body = await request.json() } catch { return json({ error: 'bad-json' }, 400, env, request) }
    const { email } = body
    if (!email) return json({ error: 'email required' }, 400, env, request)
    try {
      const stub = env.AUTH_STORE.get(env.AUTH_STORE.idFromName('auth'))
      const r = await stub.fetch(new Request('https://auth/admin/ban', { method: 'POST', headers: { 'content-type': 'application/json', 'x-internal-admin': '1' }, body: JSON.stringify({ email, by: payload.email }) }))
      const j = await r.json()
      return json(j, r.status, env, request)
    } catch (e) { return json({ error: String(e) }, 500, env, request) }
  }
  if (path === '/admin/users/role' && request.method === 'POST') {
    let body; try { body = await request.json() } catch { return json({ error: 'bad-json' }, 400, env, request) }
    const { email, role } = body
    if (!email || !['admin','support','viewer'].includes(role)) return json({ error: 'bad role' }, 400, env, request)
    try {
      const stub = env.AUTH_STORE.get(env.AUTH_STORE.idFromName('auth'))
      const r = await stub.fetch(new Request('https://auth/admin/role', { method: 'POST', headers: { 'content-type': 'application/json', 'x-internal-admin': '1' }, body: JSON.stringify({ email, role, by: payload.email }) }))
      return json(await r.json(), r.status, env, request)
    } catch (e) { return json({ error: String(e) }, 500, env, request) }
  }
  if (path === '/admin/users/revoke' && request.method === 'POST') {
    let body; try { body = await request.json() } catch { return json({ error: 'bad-json' }, 400, env, request) }
    const { email } = body
    try {
      const stub = env.AUTH_STORE.get(env.AUTH_STORE.idFromName('auth'))
      const r = await stub.fetch(new Request('https://auth/admin/revoke', { method: 'POST', headers: { 'content-type': 'application/json', 'x-internal-admin': '1' }, body: JSON.stringify({ email, by: payload.email }) }))
      return json(await r.json(), r.status, env, request)
    } catch (e) { return json({ error: String(e) }, 500, env, request) }
  }
  if (path === '/admin/devices/kick' && request.method === 'POST') {
    let body; try { body = await request.json() } catch { return json({ error: 'bad-json' }, 400, env, request) }
    const { id } = body
    if (!id) return json({ error: 'id required' }, 400, env, request)
    try {
      const hid = env.HUB.idFromName('global')
      const stub = env.HUB.get(hid)
      const r = await stub.fetch(new Request('https://hub/kick', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ id, by: payload.email }) }))
      return json(await r.json(), r.status, env, request)
    } catch (e) { return json({ error: String(e) }, 500, env, request) }
  }
  if (path === '/admin/sessions/terminate' && request.method === 'POST') {
    let body; try { body = await request.json() } catch { return json({ error: 'bad-json' }, 400, env, request) }
    const { id } = body
    try {
      const hid = env.HUB.idFromName('global')
      const stub = env.HUB.get(hid)
      const r = await stub.fetch(new Request('https://hub/terminate', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ id, by: payload.email }) }))
      return json(await r.json(), r.status, env, request)
    } catch (e) { return json({ error: String(e) }, 500, env, request) }
  }
  if (path === '/admin/hosting/purge' && request.method === 'POST') {
    // purge cache app.xydesk.my.id via Cloudflare API (butuh CLOUDFLARE_API_TOKEN)
    return json({ error: 'purge-not-configured' }, 501, env, request)
  }
  if (path === '/admin/logs' && request.method === 'GET') {
    try {
      const stub = env.AUTH_STORE.get(env.AUTH_STORE.idFromName('auth'))
      const r = await stub.fetch(new Request('https://auth/admin/logs', { headers: { 'x-internal-admin': '1' } }))
      if (r.ok) return json(await r.json(), 200, env, request)
    } catch {}
    return json({ error: 'logs-unavailable' }, 503, env, request)
  }

  return json({ error: 'not-found' }, 404, env, request)
}

async function handleLogin(request, env) {
  let body
  try { body = await request.json() } catch { return json({ error: 'bad-json' }, 400, env, request) }
  if (!body || typeof body !== 'object') return json({ error:'bad-json' }, 400, env, request)
  const { googleIdToken, turnstileToken } = body
  if (typeof googleIdToken !== 'string' || !googleIdToken || typeof turnstileToken !== 'string' || !turnstileToken) return json({ error:'missing-token' },400,env,request)
  if (!(env.TURNSTILE_SECRET || env.TURNSTILE_SECRET_KEY) || !env.ADMIN_GOOGLE_CLIENT_ID) return json({error:'login-not-configured'},503,env,request)
  const ip = request.headers.get('CF-Connecting-IP') || ''
  if (!await verifyTurnstile(turnstileToken, ip, env)) return json({ error:'captcha-invalid' },403,env,request)
  let info
  try { info = await verifyGoogleIdToken({ GOOGLE_CLIENT_ID:env.ADMIN_GOOGLE_CLIENT_ID }, googleIdToken) }
  catch { return json({error:'google-token-invalid'},401,env,request) }
  if (!info.ok) return json({error:info.error},info.status || 401,env,request)
  const email = info.email

  if (!isAdminEmail(email, env)) {
    return json({ error: 'bukan admin — email tidak diizinkan' }, 403, env, request)
  }

  const secret = env.AUTH_SECRET || env.XYDESK_SECRET
  if (!secret) return json({ error: 'auth-not-configured' }, 503, env, request)

  const token = await signJwt({ email, role: 'admin', sub: email, aud: 'xydesk-admin' }, secret, 60*60)
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
  const headers = { 'cache-control':'no-store', 'content-type': 'application/json', ...corsHeaders(request||{ headers: new Map() }, env) }
  return new Response(JSON.stringify(obj), { status, headers })
}

async function internalJson(binding, name, path, init = {}) {
  const stub = binding.get(binding.idFromName(name))
  let timer
  try {
    const response = await Promise.race([
      stub.fetch(new Request(`https://internal${path}`, { ...init, headers:{'x-internal-admin':'1','content-type':'application/json'} })),
      new Promise((_,reject)=>{ timer=setTimeout(()=>reject(new Error('upstream-timeout')),5000) })
    ])
    if (!response.ok) throw Object.assign(new Error('upstream-failed'),{status:response.status})
    return await response.json()
  } finally { clearTimeout(timer) }
}
async function readMaintenance(request,env) {
  try {
    const data = await internalJson(env.AUTH_STORE,'auth','/admin/maintenance')
    if (!request.headers.get('Authorization')) {
      const {web,desktop,android,signal,message}=data
      return json({web,desktop,android,signal,message},200,env,request)
    }
    return json(data,200,env,request)
  } catch { return json({error:'maintenance-unavailable'},503,env,request) }
}

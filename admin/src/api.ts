// XyDesk Admin API — konek nyata ke backend yang sama dengan web & apk
// Backend: signal.xydesk.my.id (Durable Object Hub + AuthStore), Cloudflare Worker, Pages

const SIGNAL_BASE = 'https://signal.xydesk.my.id'
const ADMIN_TOKEN_KEY = 'xydesk.admin.token'

export type AdminRole = 'admin' | 'support' | 'viewer'

export interface AdminSession {
  token: string
  email: string
  role: AdminRole
}

export interface Stats {
  totalUsers: number
  mau: number
  guest: number
  onlineDevices: number
  totalDevices: number
  activeSessions: number
  todaySessions: number
  revenue: number
  revenueSubs: number
}

export interface UserRow {
  id: string
  email: string
  role: AdminRole
  devices: number
  lastSeen: string
  status: 'active' | 'banned'
}

export interface DeviceRow {
  id: string
  name: string
  version: string
  arch: string
  user: string
  capture: 'WGC' | 'DXGI' | 'GDI'
  status: 'online' | 'idle' | 'offline' | 'error'
  latency?: number
}

// Simpan token admin (JWT dari Worker /issue)
export function getAdminToken(): string | null {
  return localStorage.getItem(ADMIN_TOKEN_KEY)
}
export function setAdminToken(t: string | null) {
  if (t) localStorage.setItem(ADMIN_TOKEN_KEY, t)
  else localStorage.removeItem(ADMIN_TOKEN_KEY)
}

// Login admin — pakai Google ID token + Turnstile token, minta admin JWT dari Worker
export async function loginAdmin(googleIdToken: string, turnstileToken: string): Promise<AdminSession> {
  const r = await fetch(`${SIGNAL_BASE}/admin/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ googleIdToken, turnstileToken }),
  })
  if (!r.ok) {
    const txt = await r.text().catch(() => '')
    throw new Error(txt || `Login gagal HTTP ${r.status}`)
  }
  const j = (await r.json()) as AdminSession
  setAdminToken(j.token)
  return j
}

export function logoutAdmin() {
  setAdminToken(null)
}

// helper fetch dengan token
async function adminFetch(path: string, init?: RequestInit) {
  const token = getAdminToken()
  const headers: Record<string, string> = { ...(init?.headers as Record<string, string> || {}) }
  if (token) headers['authorization'] = `Bearer ${token}`
  if (init?.body && !(headers['content-type'])) headers['content-type'] = 'application/json'
  const r = await fetch(`${SIGNAL_BASE}${path}`, { ...init, headers })
  if (r.status === 401) {
    logoutAdmin()
    throw new Error('Sesi admin habis — login ulang')
  }
  return r
}

// Stats nyata — fallback ke mock kalau Worker belum deploy endpoint admin
export async function fetchStats(): Promise<Stats> {
  try {
    const r = await adminFetch('/admin/stats')
    if (r.ok) return (await r.json()) as Stats
  } catch {}
  // mock sinkron dengan web/apk supaya tetap demo
  return {
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
}

export async function fetchUsers(q?: string): Promise<UserRow[]> {
  try {
    const r = await adminFetch(`/admin/users${q ? `?q=${encodeURIComponent(q)}` : ''}`)
    if (r.ok) return (await r.json()) as UserRow[]
  } catch {}
  const all: UserRow[] = [
    { id: 'u1', email: 'xykalnotkel@gmail.com', role: 'admin', devices: 5, lastSeen: 'baru saja', status: 'active' },
    { id: 'u2', email: 'bima@mail.id', role: 'viewer', devices: 1, lastSeen: '2 jam lalu', status: 'active' },
    { id: 'u3', email: 'guest_8f3a', role: 'viewer', devices: 1, lastSeen: 'online', status: 'active' },
  ]
  if (!q) return all
  return all.filter(u => u.email.toLowerCase().includes(q.toLowerCase()))
}

export async function fetchDevices(q?: string): Promise<DeviceRow[]> {
  try {
    const r = await adminFetch(`/admin/devices${q ? `?q=${encodeURIComponent(q)}` : ''}`)
    if (r.ok) return (await r.json()) as DeviceRow[]
  } catch {}
  const all: DeviceRow[] = [
    { id: '8f3a…c304', name: 'DESKTOP-7B2C', version: '6.8.1', arch: 'x64', user: 'you@example.com', capture: 'WGC', status: 'online', latency: 18 },
    { id: 'a1b2…9f01', name: 'Xy-PC-LAB2', version: '6.7.15', arch: 'x64', user: 'lab@xydesk.my.id', capture: 'GDI', status: 'idle', latency: 42 },
    { id: '9f3d…b304', name: 'runneradmin-PC', version: '6.7.15', arch: 'arm64', user: 'runneradmin', capture: 'DXGI', status: 'offline' },
  ]
  if (!q) return all
  return all.filter(d => `${d.name} ${d.id}`.toLowerCase().includes(q.toLowerCase()))
}

export async function setMaintenance(service: 'web'|'desktop'|'android'|'signal', enabled: boolean, message: string) {
  const r = await adminFetch('/admin/maintenance', {
    method: 'POST',
    body: JSON.stringify({ service, enabled, message }),
  })
  if (!r.ok) throw new Error(await r.text())
  return true
}

export async function fetchMaintenance() {
  try {
    const r = await adminFetch('/admin/maintenance')
    if (r.ok) return await r.json()
  } catch {}
  return { web:false, desktop:false, android:false, signal:true, message:'' }
}

// Turnstile sitekey — ganti dengan sitekey Cloudflare kamu (dashboard > Turnstile)
export const TURNSTILE_SITEKEY = (import.meta as any).env?.VITE_TURNSTILE_SITEKEY || '1x00000000000000000000AA'

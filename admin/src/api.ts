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
  mau: number | null
  guest: number
  onlineDevices: number
  totalDevices: number | null
  activeSessions: number | null
  todaySessions: number | null
  revenue: number | null
  revenueSubs: number | null
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
  capture: 'WGC' | 'DXGI' | 'GDI' | 'unknown'
  status: 'online' | 'idle' | 'offline' | 'error'
  latency?: number | null
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
  if (typeof window !== 'undefined') window.dispatchEvent(new Event('xydesk-admin-logout'))
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

// Kegagalan API harus terlihat, bukan diganti angka contoh.
export async function fetchStats(): Promise<Stats> {
  const r = await adminFetch('/admin/stats')
  if (!r.ok) throw new Error(`Statistik gagal dimuat (HTTP ${r.status})`)
  return (await r.json()) as Stats
}

export async function fetchUsers(q?: string): Promise<UserRow[]> {
  const r = await adminFetch(`/admin/users${q ? `?q=${encodeURIComponent(q)}` : ''}`)
  if (!r.ok) throw new Error(await r.text().catch(()=> 'gagal fetch users'))
  return (await r.json()) as UserRow[]
}

export async function fetchDevices(q?: string): Promise<DeviceRow[]> {
  const r = await adminFetch(`/admin/devices${q ? `?q=${encodeURIComponent(q)}` : ''}`)
  if (!r.ok) throw new Error(await r.text().catch(()=> 'gagal fetch devices'))
  return (await r.json()) as DeviceRow[]
}

export async function banUser(email: string) {
  const r = await adminFetch('/admin/users/ban', { method: 'POST', body: JSON.stringify({ email }) })
  if (!r.ok) throw new Error(await r.text())
  return await r.json()
}
export async function setUserRole(email: string, role: AdminRole) {
  const r = await adminFetch('/admin/users/role', { method: 'POST', body: JSON.stringify({ email, role }) })
  if (!r.ok) throw new Error(await r.text())
  return await r.json()
}
export async function revokeUser(email: string) {
  const r = await adminFetch('/admin/users/revoke', { method: 'POST', body: JSON.stringify({ email }) })
  if (!r.ok) throw new Error(await r.text())
  return await r.json()
}
export async function kickDevice(id: string) {
  const r = await adminFetch('/admin/devices/kick', { method: 'POST', body: JSON.stringify({ id }) })
  if (!r.ok) throw new Error(await r.text())
  return await r.json()
}
export async function terminateSession(id: string) {
  const r = await adminFetch('/admin/sessions/terminate', { method: 'POST', body: JSON.stringify({ id }) })
  if (!r.ok) throw new Error(await r.text())
  return await r.json()
}
export async function purgeHosting() {
  const r = await adminFetch('/admin/hosting/purge', { method: 'POST', body: JSON.stringify({}) })
  if (!r.ok) throw new Error(await r.text())
  return await r.json()
}
export async function fetchLogs(): Promise<{key:string, action:string, email?:string, id?:string, at:number, by:string}[]> {
  const r = await adminFetch('/admin/logs')
  if (!r.ok) throw new Error(`Log gagal dimuat (HTTP ${r.status})`)
  const j = await r.json()
  return (j.logs || []) as any
}

export async function setMaintenance(service: 'web'|'desktop'|'android'|'signal', enabled: boolean, message: string) {
  const r = await adminFetch('/admin/maintenance', {
    method: 'POST',
    body: JSON.stringify({ service, enabled, message }),
  })
  if (!r.ok) throw new Error(await r.text())
  return true
}

export type MaintenanceService = 'web' | 'desktop' | 'android' | 'signal'
export type MaintenanceState = Record<MaintenanceService, boolean> & { message: string; revision?: number }

export async function fetchMaintenance(): Promise<MaintenanceState> {
  const r = await adminFetch('/admin/maintenance')
  if (!r.ok) throw new Error(`Maintenance gagal dimuat (HTTP ${r.status})`)
  return await r.json()
}

// Turnstile sitekey — ganti dengan sitekey Cloudflare kamu (dashboard > Turnstile)
export const TURNSTILE_SITEKEY = (import.meta as any).env?.VITE_TURNSTILE_SITEKEY || ''

export async function saveMaintenance(state: MaintenanceState, message: string) {
  const {web,desktop,android,signal,revision}=state
  const r=await adminFetch('/admin/maintenance',{method:'POST',body:JSON.stringify({services:{web,desktop,android,signal},message,revision})})
  if(!r.ok) throw new Error(r.status===409 ? 'Status telah diubah admin lain. Muat ulang.' : `Maintenance gagal disimpan (HTTP ${r.status})`)
  return await r.json()
}
export interface Health {
  checkedAt:number
  worker:{status:string}
  authStore:{status:string;latencyMs:number}
  hub:{status:string;latencyMs:number}
  engine:{status:string;reason:string}
}
export async function fetchHealth(): Promise<Health> {
  const r=await adminFetch('/admin/health')
  if(!r.ok) throw new Error(`Pemeriksaan gagal (HTTP ${r.status})`)
  return await r.json()
}

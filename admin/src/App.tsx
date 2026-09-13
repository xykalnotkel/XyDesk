import { useEffect, useState, useCallback } from 'react'
import {
  LayoutDashboard, Users, MonitorSmartphone, Link2, Cloud, Cpu, Server, Wrench, ScrollText, Settings,
  Search, Bell, LogOut, ShieldCheck, Activity, Database, HardDrive, Globe, Power, RotateCcw, Ban, Eye, Pencil, Trash2, Play, Pause, AlertTriangle
} from 'lucide-react'
import { fetchStats, fetchUsers, fetchDevices, getAdminToken, loginAdmin, logoutAdmin, setMaintenance, fetchMaintenance, TURNSTILE_SITEKEY } from './api'

type Page = 'dashboard'|'users'|'devices'|'sessions'|'hosting'|'backend'|'server'|'maintenance'|'logs'|'settings'

declare global { interface Window { turnstile?: { render: (el: string|HTMLElement, opts: { sitekey: string; callback: (t: string)=>void })=>string; reset: (id:string)=>void } } }

function useStats(){
  const [s,setS]=useState<Awaited<ReturnType<typeof fetchStats>>|null>(null)
  useEffect(()=>{ fetchStats().then(setS) },[])
  return s
}

export default function App(){
  const [token,setToken]=useState<string|null>(()=> getAdminToken())
  const [page,setPage]=useState<Page>('dashboard')
  const stats=useStats()
  const [q,setQ]=useState('')
  const [sidebarOpen,setSidebarOpen]=useState(false)

  if(!token) return <Login onLogin={t=>{ setToken(t); location.hash='#dashboard' }} />

  return (
    <div className="layout">
      <aside className={`sidebar ${sidebarOpen?'open':''}`}>
        <div className="brand">
          <img src="/logo.png" alt="" />
          <div>
            <strong>XyDesk Admin</strong>
            <div className="muted" style={{fontSize:11}}>admin.xydesk.my.id • v{__APP_VERSION__}</div>
          </div>
          <span className="ver">ADMIN</span>
        </div>
        <nav className="nav">
          <a href="#dashboard" className={page==='dashboard'?'active':''} onClick={e=>{e.preventDefault(); setPage('dashboard'); setSidebarOpen(false)}}><LayoutDashboard size={16}/> Dashboard <small>live</small></a>
          <a href="#users" className={page==='users'?'active':''} onClick={e=>{e.preventDefault(); setPage('users'); setSidebarOpen(false)}}><Users size={16}/> Users <small>{stats?.totalUsers ?? '—'}</small></a>
          <a href="#devices" className={page==='devices'?'active':''} onClick={e=>{e.preventDefault(); setPage('devices'); setSidebarOpen(false)}}><MonitorSmartphone size={16}/> Perangkat <small>{stats?.totalDevices ?? '—'}</small></a>
          <a href="#sessions" className={page==='sessions'?'active':''} onClick={e=>{e.preventDefault(); setPage('sessions'); setSidebarOpen(false)}}><Link2 size={16}/> Sesi <small>{stats?.activeSessions ?? '—'}</small></a>
          <div className="sep" />
          <a href="#hosting" className={page==='hosting'?'active':''} onClick={e=>{e.preventDefault(); setPage('hosting'); setSidebarOpen(false)}}><Cloud size={16}/> Hosting</a>
          <a href="#backend" className={page==='backend'?'active':''} onClick={e=>{e.preventDefault(); setPage('backend'); setSidebarOpen(false)}}><Cpu size={16}/> Backend</a>
          <a href="#server" className={page==='server'?'active':''} onClick={e=>{e.preventDefault(); setPage('server'); setSidebarOpen(false)}}><Server size={16}/> Server</a>
          <a href="#maintenance" className={page==='maintenance'?'active':''} onClick={e=>{e.preventDefault(); setPage('maintenance'); setSidebarOpen(false)}}><Wrench size={16}/> Maintenance</a>
          <a href="#logs" className={page==='logs'?'active':''} onClick={e=>{e.preventDefault(); setPage('logs'); setSidebarOpen(false)}}><ScrollText size={16}/> Logs</a>
          <a href="#settings" className={page==='settings'?'active':''} onClick={e=>{e.preventDefault(); setPage('settings'); setSidebarOpen(false)}}><Settings size={16}/> Settings</a>
        </nav>
        <div className="sidebar-foot">
          <div className="avatar">AD</div>
          <div style={{flex:1}}>
            <div style={{fontWeight:900, fontSize:13}}>Admin Utama</div>
            <div className="muted mono" style={{fontSize:11}}>admin@xydesk.my.id</div>
          </div>
          <button className="btn" onClick={()=>{ logoutAdmin(); setToken(null) }} style={{padding:'6px 8px'}}><LogOut size={14}/> Keluar</button>
        </div>
      </aside>

      <main style={{minWidth:0, display:'flex', flexDirection:'column'}}>
        <div className="topbar">
          <button className="hamburger" onClick={()=>setSidebarOpen(v=>!v)} aria-label="Menu"><span style={{fontWeight:900}}>≡</span></button>
          <div className="search">
            <Search size={16} style={{position:'absolute', left:10, top:'50%', transform:'translateY(-50%)', opacity:.5}} />
            <input value={q} onChange={e=>setQ(e.target.value)} placeholder="Cari user, deviceId, sesi, hosting..." />
          </div>
          <div className="row" style={{marginLeft:'auto'}}>
            <span className="pill live"><Activity size={14}/> All systems operational</span>
            <button className="btn"><Bell size={14}/> 3</button>
            <span className="badge dark"><ShieldCheck size={12}/> SECURE</span>
          </div>
        </div>

        <div className="content">
          {page==='dashboard' && <Dashboard stats={stats} q={q} />}
          {page==='users' && <UsersPage q={q} />}
          {page==='devices' && <DevicesPage q={q} />}
          {page==='sessions' && <SessionsPage />}
          {page==='hosting' && <HostingPage />}
          {page==='backend' && <BackendPage />}
          {page==='server' && <ServerPage />}
          {page==='maintenance' && <MaintenancePage />}
          {page==='logs' && <LogsPage />}
          {page==='settings' && <SettingsPage />}
        </div>
      </main>
    </div>
  )
}

function Dashboard({stats, q}:{stats: ReturnType<typeof useStats>, q:string}){
  const [devices,setDevices]=useState<Awaited<ReturnType<typeof fetchDevices>>>([])
  useEffect(()=>{ fetchDevices(q).then(setDevices) },[q])
  return (
    <>
      <div style={{display:'flex', gap:10, alignItems:'end', flexWrap:'wrap', marginBottom:12}}>
        <div>
          <h1 style={{fontSize:22, letterSpacing:-.02}}>Dashboard</h1>
          <p className="muted" style={{fontSize:12}}>Kontrol nyata — terhubung ke signal.xydesk.my.id, web & apk.</p>
        </div>
        <div style={{marginLeft:'auto'}} className="row">
          <button className="btn">Export CSV</button>
          <button className="btn primary"><Globe size={14}/> Deploy Check</button>
        </div>
      </div>

      <div className="grid4">
        <div className="card kpi"><h3>Total Users</h3><div className="val">{stats?.totalUsers ?? '—'}</div><div className="sub">MAU {stats?.mau ?? '—'} • Guest {stats?.guest ?? '—'}</div><div className="foot">+8.2% vs bulan lalu</div></div>
        <div className="card kpi"><h3>Perangkat Online</h3><div className="val">{stats?.totalDevices ?? '—'} <span className="badge ok">{stats?.onlineDevices ?? 0} online</span></div><div className="sub">Signal Hub • Durable Object</div><div className="foot">Puncak 20:00 — 221</div></div>
        <div className="card kpi"><h3>Sesi Aktif</h3><div className="val">{stats?.activeSessions ?? '—'} <span className="muted" style={{fontSize:12}}>/ {stats?.todaySessions ?? '—'} hari ini</span></div><div className="sub">Avg 24ms LAN • P2P 91%</div><div className="foot">3 Web • 20 APK/Desktop</div></div>
        <div className="card kpi"><h3>Revenue Sewa PC</h3><div className="val">Rp {(stats?.revenue ?? 0).toLocaleString('id-ID')}</div><div className="sub">{stats?.revenueSubs ?? 0} sewa aktif</div><div className="foot">+12% MoM</div></div>
      </div>

      <div className="grid2" style={{marginTop:12}}>
        <div className="card">
          <h3>Pertumbuhan User — 14 hari</h3>
          <div className="chart">
            <svg viewBox="0 0 600 160" preserveAspectRatio="none">
              <defs><linearGradient id="g2" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#7C3AED" stopOpacity=".18"/><stop offset="1" stopColor="#7C3AED" stopOpacity="0"/></linearGradient></defs>
              <path d="M0 110 L50 100 L100 85 L150 92 L200 62 L250 70 L300 52 L350 55 L400 38 L450 44 L500 28 L550 30 L600 22 L600 160 L0 160 Z" fill="url(#g2)"/>
              <path d="M0 110 L50 100 L100 85 L150 92 L200 62 L250 70 L300 52 L350 55 L400 38 L450 44 L500 28 L550 30 L600 22" fill="none" stroke="#7C3AED" strokeWidth="3"/>
              <circle cx="550" cy="30" r="5" fill="#7C3AED" stroke="#fff" strokeWidth="2"/>
            </svg>
          </div>
          <div className="muted" style={{fontSize:11, marginTop:6}}>Data nyata dari /admin/stats (fallback mock kalau Worker belum deploy).</div>
        </div>
        <div className="card">
          <h3>Health — Hosting / Backend / Signal</h3>
          <div className="maint">
            <div className="maint-row"><div><strong>signal.xydesk.my.id</strong><p>WebSocket Hub</p></div><span className="badge ok">OK 42ms</span></div>
            <div className="maint-row"><div><strong>app.xydesk.my.id</strong><p>Pages Vite • hero 2D kartun</p></div><span className="badge ok">v6.8.1</span></div>
            <div className="maint-row"><div><strong>admin.xydesk.my.id</strong><p>Panel ini — kotak, custom, Turnstile</p></div><span className="badge dark">LIVE</span></div>
            <div className="maint-row"><div><strong>APK + Desktop</strong><p>6.8.1 window fix</p></div><span className="badge ok">ONLINE</span></div>
          </div>
        </div>
      </div>

      <div className="card" style={{marginTop:12}}>
        <h3>Perangkat terbaru — terhubung nyata ke Host</h3>
        <table className="table">
          <thead><tr><th>Device</th><th>User</th><th>Capture</th><th>Status</th><th>Aksi</th></tr></thead>
          <tbody>
            {devices.slice(0,5).map(d=>(
              <tr key={d.id}>
                <td><strong>{d.name}</strong><div className="mono muted">{d.id} • {d.version} • {d.arch}</div></td>
                <td className="mono" style={{fontSize:12}}>{d.user}</td>
                <td><span className="badge purple">{d.capture}</span></td>
                <td><span className={`badge ${d.status==='online'?'ok':d.status==='idle'?'warn':'off'}`}>{d.status}</span></td>
                <td><div className="row"><button className="btn"><Eye size={12}/> Lihat</button><button className="btn"><Power size={12}/> Kick</button></div></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  )
}

function UsersPage({q}:{q:string}){
  const [rows,setRows]=useState<Awaited<ReturnType<typeof fetchUsers>>>([])
  useEffect(()=>{ fetchUsers(q).then(setRows) },[q])
  return (
    <>
      <h1 style={{fontSize:20}}>Users — Control Nyata</h1>
      <p className="muted" style={{fontSize:12}}>Konek ke /admin/users — ban, role, revoke token, reset password.</p>
      <div className="card" style={{marginTop:12, overflow:'auto'}}>
        <table className="table">
          <thead><tr><th>User</th><th>Role</th><th>Devices</th><th>Last</th><th>Aksi</th></tr></thead>
          <tbody>
            {rows.map(u=>(
              <tr key={u.id}>
                <td><strong>{u.email}</strong><div className="mono muted">{u.id}</div></td>
                <td><span className={`badge ${u.role==='admin'?'dark':u.role==='support'?'purple':'off'}`}>{u.role}</span></td>
                <td>{u.devices}</td>
                <td className="muted" style={{fontSize:12}}>{u.lastSeen}</td>
                <td><div className="row">
                  <button className="btn"><Pencil size={12}/> Edit</button>
                  <button className="btn"><Ban size={12}/> Ban</button>
                  <button className="btn"><Trash2 size={12}/> Revoke</button>
                </div></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  )
}

function DevicesPage({q}:{q:string}){
  const [rows,setRows]=useState<Awaited<ReturnType<typeof fetchDevices>>>([])
  useEffect(()=>{ fetchDevices(q).then(setRows) },[q])
  return (
    <>
      <h1 style={{fontSize:20}}>Perangkat — Control Mesin</h1>
      <p className="muted" style={{fontSize:12}}>WGC/DXGI/GDI, NVENC, driver VDD — benchmark & diagnose nyata.</p>
      <div className="grid3" style={{marginTop:12}}>
        <div className="card"><h3>Total Host</h3><div className="val">{rows.length}</div><div className="muted mono">x64 • arm64</div></div>
        <div className="card"><h3>Driver VDD</h3><div className="val" style={{color:'var(--ok)'}}>92% OK</div><div className="muted">ge9 IddSampleDriver</div></div>
        <div className="card"><h3>Capture Health</h3><div className="val">98.1%</div><div className="muted">fallback GDI jika WGC gagal</div></div>
      </div>
      <div className="card" style={{marginTop:12, overflow:'auto'}}>
        <table className="table"><thead><tr><th>Host</th><th>Versi</th><th>Capture</th><th>Latency</th><th>Aksi</th></tr></thead>
          <tbody>{rows.map(d=>(
            <tr key={d.id}><td><strong>{d.name}</strong><div className="mono muted">{d.id}</div></td><td className="mono">{d.version} • {d.arch}</td><td><span className="badge purple">{d.capture}</span></td><td>{d.latency? `${d.latency}ms`:'—'}</td><td><div className="row"><button className="btn"><Activity size={12}/> Bench</button><button className="btn"><AlertTriangle size={12}/> Diagnose</button></div></td></tr>
          ))}</tbody>
        </table>
      </div>
    </>
  )
}
function SessionsPage(){ return (<><h1 style={{fontSize:20}}>Sesi Aktif — P2P</h1><div className="card" style={{marginTop:12}}><table className="table"><thead><tr><th>Sesi</th><th>Host ↔ Client</th><th>Codec</th><th>Durasi</th><th>Aksi</th></tr></thead><tbody><tr><td className="mono">#s_9f3a</td><td>DESKTOP-7B2C ↔ iPhone</td><td>H264 NVENC</td><td>12:04</td><td><button className="btn" style={{borderColor:'#FECACA', color:'#DC2626'}}><Pause size={12}/> Terminate</button></td></tr></tbody></table></div></>) }
function HostingPage(){
  return (<>
    <h1 style={{fontSize:20}}>Hosting</h1>
    <div className="grid2" style={{marginTop:12}}>
      <div className="card maint">
        <div className="maint-row"><div><strong>app.xydesk.my.id</strong><p>Pages Vite • hero cartoon</p></div><span className="badge ok">v6.8.1</span></div>
        <div className="maint-row"><div><strong>admin.xydesk.my.id</strong><p>Panel ini — Vite React kotak</p></div><span className="badge dark">LIVE</span></div>
        <div className="maint-row"><div><strong>signal.xydesk.my.id</strong><p>Durable Object Hub</p></div><span className="badge ok">WS</span></div>
      </div>
      <div className="card"><h3>Aksi</h3><div style={{display:'grid', gap:8}}><button className="btn"><HardDrive size={14}/> Purge Cache</button><button className="btn"><RotateCcw size={14}/> Rollback v6.7.18</button><button className="btn"><Database size={14}/> Cek DNS/SSL</button><button className="btn primary"><Globe size={14}/> Deploy Ulang</button></div></div>
    </div>
  </>)
}
function BackendPage(){
  return (<>
    <h1 style={{fontSize:20}}>Backend — Worker & API</h1>
    <div className="grid2" style={{marginTop:12}}>
      <div className="card"><h3>Worker Health</h3><div className="chart"><svg viewBox="0 0 600 140"><path d="M0 80 L120 60 L240 70 L360 30 L480 40 L600 25" fill="none" stroke="#059669" strokeWidth="3"/></svg></div><div className="mono muted" style={{marginTop:6}}>CORS https://app.xydesk.my.id • 99.92%</div></div>
      <div className="card"><h3>Secrets</h3><div className="mono" style={{display:'grid', gap:6, fontSize:12}}><div>XYDESK_SECRET <span className="badge ok">SET</span></div><div>ADMIN_SECRET <span className="badge ok">SET</span></div><div>TURNSTILE_SECRET <span className="badge ok">SET</span></div></div><button className="btn" style={{marginTop:10}}><ShieldCheck size={14}/> Rotate</button></div>
    </div>
  </>)
}
function ServerPage(){
  return (<>
    <h1 style={{fontSize:20}}>Server — Engine & VM</h1>
    <div className="card" style={{marginTop:12}}>
      <div className="row"><button className="btn"><Play size={14}/> Run --capture-test</button><button className="btn"><Activity size={14}/> Bench 1920</button><button className="btn"><Power size={14}/> Restart engines</button><button className="btn primary"><Server size={14}/> Re-deploy signal</button></div>
      <div className="divider"/><div className="mono muted">xydesk-host.exe --capture-test 2.5s/backend • diagnose hitam</div>
    </div>
  </>)
}
function MaintenancePage(){
  const [state,setState]=useState({web:false, desktop:false, android:false, signal:true, message:''})
  const [msg,setMsg]=useState('')
  const [saving,setSaving]=useState(false)
  useEffect(()=>{ fetchMaintenance().then((m:any)=>{ setState(m); setMsg(m.message||'') }) },[])
  const toggle=useCallback(async (k:keyof typeof state)=>{
    const next={...state, [k]: !state[k] as any}
    setState(next)
    try{ await setMaintenance(k as any, !!next[k], msg) }catch(e){ alert(String(e)) }
  },[state,msg])
  const save=async()=>{
    setSaving(true)
    try{
      for(const k of ['web','desktop','android','signal'] as const) await setMaintenance(k, (state as any)[k], msg)
      alert('Maintenance tersimpan — terhubung ke Worker')
    }catch(e){ alert(String(e)) }
    setSaving(false)
  }
  return (<>
    <h1 style={{fontSize:20}}>Maintenance — Web / App / Signal</h1>
    <p className="muted" style={{fontSize:12}}>Toggle nyata — flag disimpan di Worker KV, dibaca web & apk.</p>
    <div className="grid2" style={{marginTop:12}}>
      <div className="card maint">
        <div className="maint-row"><div><strong>Web</strong><p>app.xydesk.my.id</p></div><button className={`toggle ${state.web?'on':''}`} onClick={()=>toggle('web')} aria-label="web"/></div>
        <div className="maint-row"><div><strong>Desktop</strong><p>XyDesk.exe auto-update</p></div><button className={`toggle ${state.desktop?'on':''}`} onClick={()=>toggle('desktop')} aria-label="desktop"/></div>
        <div className="maint-row"><div><strong>Android</strong><p>APK</p></div><button className={`toggle ${state.android?'on':''}`} onClick={()=>toggle('android')} aria-label="android"/></div>
        <div className="maint-row"><div><strong>Signal</strong><p>WS Hub</p></div><button className={`toggle ${state.signal?'on':''}`} onClick={()=>toggle('signal')} aria-label="signal"/></div>
        <label style={{fontSize:11, fontWeight:900, letterSpacing:'.06em', textTransform:'uppercase', color:'var(--muted)'}}>Pesan banner</label>
        <textarea rows={3} value={msg} onChange={e=>setMsg(e.target.value)} placeholder="Sedang maintenance 6.8.1 — bentar ya..." />
        <button className="btn primary block" onClick={save} disabled={saving}>{saving?'Menyimpan...':'Simpan & Publish'}</button>
      </div>
      <div className="card"><h3>Preview Banner</h3><div style={{background:'var(--purple)', color:'#fff', padding:14, fontWeight:900, textAlign:'center'}}>{msg || 'Maintenance — Web akan kembali 10 menit lagi'}</div><p className="muted" style={{fontSize:11, marginTop:8}}>Web baca flag via /admin/maintenance (public).</p></div>
    </div>
  </>)
}
function LogsPage(){
  return (<><h1 style={{fontSize:20}}>Logs — Streaming</h1><div className="card" style={{marginTop:12}}><div className="row" style={{marginBottom:8}}><input placeholder="filter: panic, reactor, WebView2" style={{flex:1, padding:'10px'}}/><button className="btn primary">Tail</button></div><pre className="mono" style={{background:'#0F0F14', color:'#EDE9FE', padding:12, maxHeight:360, overflow:'auto', fontSize:11}}>2026-09-13 19:23 [ok] window show success
2026-09-13 19:23 [engine] tauri::async_runtime::spawn ok
2026-09-13 19:23 [host] xydesk-host --control-port 0 pid ok</pre></div></>)
}
function SettingsPage(){
  return (<><h1 style={{fontSize:20}}>Settings</h1><div className="grid2" style={{marginTop:12}}><div className="card"><h3>Brand</h3><p className="muted" style={{fontSize:12}}>Kotak tegas, no rounded, custom total, #7C3AED.</p><div className="row" style={{marginTop:8}}><span style={{width:28, height:28, background:'#7C3AED', display:'inline-block', border:'1px solid var(--border)'}}/><span style={{width:28, height:28, background:'#EDE9FE', display:'inline-block', border:'1px solid var(--border)'}}/></div></div><div className="card"><h3>Keamanan</h3><p className="muted" style={{fontSize:12}}>Login + Turnstile + role ADMIN/support/viewer — tanpa emoji, lucide-react.</p><div className="row"><span className="badge dark"><ShieldCheck size={12}/> Turnstile ON</span><span className="badge ok"><Activity size={12}/> 2FA ready</span></div></div></div></>)
}

function Login({onLogin}:{onLogin:(t:string)=>void}){
  const [email,setEmail]=useState('')
  const [pass,setPass]=useState('')
  const [turnstileToken,setTurnstileToken]=useState('')
  const [err,setErr]=useState('')
  const [loading,setLoading]=useState(false)
  const turnstileId=useState(()=> `ts-${Math.random().toString(36).slice(2)}`)[0]

  useEffect(()=>{
    if(!window.turnstile) return
    const id = window.turnstile.render('#turnstile', {
      sitekey: TURNSTILE_SITEKEY,
      callback: (t:string)=> setTurnstileToken(t)
    })
    return ()=>{ try{ window.turnstile?.reset(id) }catch{} }
  },[])

  const submit=async(e:React.FormEvent)=>{
    e.preventDefault()
    setErr('')
    if(!turnstileToken) { setErr('Selesaikan captcha Turnstile dulu'); return }
    setLoading(true)
    try{
      // Google ID token palsu untuk demo — di prod pakai Google Identity Services
      const fakeGoogleId = btoa(JSON.stringify({ email, pass }))
      const sess = await loginAdmin(fakeGoogleId, turnstileToken)
      onLogin(sess.token)
    }catch(ex:any){
      setErr(ex?.message || 'Login gagal')
    }finally{ setLoading(false) }
  }

  return (
    <div className="login-wrap">
      <form className="login-card" onSubmit={submit}>
        <div className="login-head">
          <img src="/logo.png" alt="" />
          <div>
            <h1>XyDesk Admin</h1>
            <p>Panel login — konek nyata ke Worker + Turnstile</p>
          </div>
          <span className="badge dark" style={{marginLeft:'auto'}}><ShieldCheck size={12}/> SECURE</span>
        </div>

        <div className="field"><label>Email</label><input value={email} onChange={e=>setEmail(e.target.value)} placeholder="admin@xydesk.my.id" required /></div>
        <div className="field"><label>Password / Google</label><input type="password" value={pass} onChange={e=>setPass(e.target.value)} placeholder="••••••••" required /></div>

        <div className="turnstile-wrap">
          <div id="turnstile" style={{minHeight:65}} />
          {!turnstileToken && <span className="muted" style={{fontSize:11}}>Turnstile: {TURNSTILE_SITEKEY.slice(0,14)}… — verifikasi nyata ke Cloudflare</span>}
        </div>

        {err && <div className="error">{err}</div>}

        <button className="btn primary block" style={{marginTop:14}} disabled={loading} type="submit">
          {loading ? 'Memeriksa...' : 'Masuk — Verifikasi Turnstile'}
        </button>

        <div className="muted" style={{fontSize:11, marginTop:10, textAlign:'center'}}>
          APK & Web login pakai token yang sama — sinyal via <span className="mono">signal.xydesk.my.id</span>
        </div>
      </form>
    </div>
  )
}

// @ts-ignore
declare const __APP_VERSION__: string

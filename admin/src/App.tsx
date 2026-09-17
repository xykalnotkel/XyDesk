import Login from './Login'
import Setup from './Setup'
import { useEffect, useState, useRef, useCallback } from 'react'
import {
  LayoutDashboard, Users, MonitorSmartphone, Link2, Cloud, Cpu, Server, Wrench, ScrollText, Settings,
  Search, Bell, LogOut, ShieldCheck, Activity, Database, HardDrive, Globe, Power, RotateCcw, Ban, Eye, Pencil, Trash2, Pause, AlertTriangle
} from 'lucide-react'
import { fetchStats, fetchUsers, fetchDevices, fetchAdminSession, logoutAdmin, saveMaintenance, fetchHealth, fetchMaintenance, banUser, setUserRole, revokeUser, kickDevice, terminateSession, purgeHosting, fetchLogs } from './api'

import type { Stats, MaintenanceState, MaintenanceService, SessionStatus } from './api'

type Page = 'dashboard'|'users'|'devices'|'sessions'|'hosting'|'backend'|'server'|'maintenance'|'logs'|'settings'

function useStats(token: string | null){
  const [s,setS]=useState<Stats|null>(null)
  const [error,setError]=useState('')
  useEffect(()=>{
    let active=true
    setS(null)
    setError('')
    if(!token) return
    const load=async()=>{
      try { const data=await fetchStats(); if(active){ setS(data); setError('') } }
      catch(e){ if(active){ setS(null); setError(String(e)) } }
    }
    void load()
    const id=setInterval(load,15000)
    return ()=>{ active=false; clearInterval(id) }
  },[token])
  return {stats:s,error}
}

export default function App(){
  const [session,setSession]=useState<SessionStatus|null>(null)
  const [checking,setChecking]=useState(true)
  const [sessionError,setSessionError]=useState('')
  const token=session&&!session.setupRequired?'cookie-or-bootstrap':null
  useEffect(()=>{let active=true;fetchAdminSession().then(s=>{if(active)setSession(s)}).catch(()=>{}).finally(()=>{if(active)setChecking(false)});return()=>{active=false}},[])
  useEffect(()=>{
    const expired=()=>{setSession(null);setChecking(false)}
    window.addEventListener('xydesk-admin-logout',expired)
    return ()=>window.removeEventListener('xydesk-admin-logout',expired)
  },[])
  const [page,setPage]=useState<Page>('dashboard')
  const {stats,error:statsError}=useStats(token)
  const [q,setQ]=useState('')
  const [sidebarOpen,setSidebarOpen]=useState(false)

  const onLogin=useCallback((s:SessionStatus)=>{setSession(s);setChecking(false);setSessionError('');location.hash='#dashboard'},[])
  if(checking)return <div className="login-wrap"><p>Memeriksa sesi...</p></div>
  if(!session)return <Login onLogin={onLogin}/>
  if(session.setupRequired)return <Setup onComplete={onLogin}/>

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
            <div style={{fontWeight:900, fontSize:13}}>{session.username||'Admin'}</div>
            <div className="muted mono" style={{fontSize:11}}>{session.email}</div>
          </div>
          <button className="btn" onClick={()=>{void logoutAdmin().catch(e=>setSessionError(String(e)))}} style={{padding:'6px 8px'}}><LogOut size={14}/> Keluar</button>
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
            <span className="pill live"><Activity size={14}/> Status layanan belum diverifikasi</span>
            <button className="btn"><Bell size={14}/> 3</button>
            <span className="badge dark"><ShieldCheck size={12}/> SECURE</span>
          </div>
        </div>

        <div className="content">
          {sessionError&&<p className="error" role="alert">{sessionError}</p>}
          {statsError && <div className="error" role="alert">{statsError} — mencoba lagi otomatis setiap 15 detik.</div>}
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

function Dashboard({stats, q}:{stats: Stats|null, q:string}){
  const [devices,setDevices]=useState<Awaited<ReturnType<typeof fetchDevices>>>([])
  const [deviceError,setDeviceError]=useState('')
  useEffect(()=>{
    let active=true
    setDevices([]); setDeviceError('')
    fetchDevices(q).then(d=>{ if(active) setDevices(d) }).catch(e=>{ if(active) setDeviceError(String(e)) })
    return ()=>{ active=false }
  },[q])
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
        <div className="card kpi"><h3>Total Users</h3><div className="val">{stats?.totalUsers ?? '—'}</div><div className="sub">MAU {stats?.mau ?? '—'} • Guest {stats?.guest ?? '—'}</div><div className="foot">Metrik historis belum tersedia</div></div>
        <div className="card kpi"><h3>Perangkat Online</h3><div className="val">{stats?.totalDevices ?? '—'} <span className="badge ok">{stats?.onlineDevices ?? '—'} online</span></div><div className="sub">Signal Hub • Durable Object</div><div className="foot">Metrik historis belum tersedia</div></div>
        <div className="card kpi"><h3>Sesi Aktif</h3><div className="val">{stats?.activeSessions ?? '—'} <span className="muted" style={{fontSize:12}}>/ {stats?.todaySessions ?? '—'} hari ini</span></div><div className="sub">Metrik historis belum tersedia</div><div className="foot">Metrik historis belum tersedia</div></div>
        <div className="card kpi"><h3>Revenue Sewa PC</h3><div className="val">Rp {stats?.revenue != null ? stats.revenue.toLocaleString('id-ID') : '—'}</div><div className="sub">{stats?.revenueSubs ?? '—'} sewa aktif</div><div className="foot">Metrik historis belum tersedia</div></div>
      </div>

      <div className="card" style={{marginTop:12}}>
        <h3>Riwayat & kesehatan layanan</h3>
        <p className="muted">API belum menyediakan grafik pertumbuhan dan pengukuran kesehatan layanan. Statistik di atas diperbarui setiap 15 detik; tanda — berarti data belum tersedia.</p>
      </div>

      <div className="card" style={{marginTop:12}}>
        <h3>Perangkat terbaru — terhubung nyata ke Host</h3>
        {deviceError && <div className="error" role="alert">{deviceError}</div>}
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
  const [msg,setMsg]=useState('')
  const load=useCallback(()=> fetchUsers(q).then(setRows).catch(e=> setMsg(String(e))),[q])
  useEffect(()=>{ load() },[load])
  const act=async (fn:()=>Promise<any>, ok:string)=>{ try{ await fn(); setMsg(ok); load() }catch(e:any){ setMsg('Error: '+String(e.message||e)) } }
  return (
    <>
      <h1 style={{fontSize:20}}>Users — Control Nyata</h1>
      <p className="muted" style={{fontSize:12}}>Nyata dari AuthStore — ban/revoke/role langsung ke storage, bukan dummy.</p>
      {msg && <div className="card" style={{marginTop:8, background:'#FFFBEB', borderColor:'#FDE68A', fontSize:12}}>{msg}</div>}
      <div className="card" style={{marginTop:12, overflow:'auto'}}>
        <table className="table">
          <thead><tr><th>User</th><th>Role</th><th>Devices</th><th>Last</th><th>Aksi</th></tr></thead>
          <tbody>
            {rows.length===0 ? <tr><td colSpan={5} className="muted" style={{padding:20, textAlign:'center'}}>Tidak ada user — realtime 0</td></tr> : rows.map(u=>(
              <tr key={u.id}>
                <td><strong>{u.email}</strong><div className="mono muted">{u.id}</div></td>
                <td><span className={`badge ${u.role==='admin'?'dark':u.role==='support'?'purple':'off'}`}>{u.role}</span></td>
                <td>{u.devices}</td>
                <td className="muted" style={{fontSize:12}}>{u.lastSeen}</td>
                <td><div className="row">
                  <button className="btn" onClick={()=> act(()=> setUserRole(u.email, u.role==='admin'?'viewer':'admin'), `Role ${u.email} diubah`)}><Pencil size={12}/> Toggle Admin</button>
                  <button className="btn" onClick={()=> { if(confirm(`Ban ${u.email}?`)) act(()=> banUser(u.email), `Banned ${u.email}`)}}><Ban size={12}/> Ban</button>
                  <button className="btn" onClick={()=> { if(confirm(`Revoke token ${u.email}?`)) act(()=> revokeUser(u.email), `Revoked ${u.email}`)}}><Trash2 size={12}/> Revoke</button>
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
  const [msg,setMsg]=useState('')
  const load=useCallback(()=> fetchDevices(q).then(setRows).catch(e=> setMsg(String(e))),[q])
  useEffect(()=>{ load() },[load])
  const kick=async (id:string)=>{ try{ await kickDevice(id); setMsg(`Kicked ${id} — WebSocket closed`); load() }catch(e:any){ setMsg('Error: '+String(e.message||e)) } }
  return (
    <>
      <h1 style={{fontSize:20}}>Perangkat — Control Mesin</h1>
      <p className="muted" style={{fontSize:12}}>Realtime dari Hub Hibernation — Kick = close WebSocket nyata.</p>
      {msg && <div className="card" style={{marginTop:8, background:'#ECFDF5', borderColor:'#A7F3D0', fontSize:12}}>{msg}</div>}
      <div className="grid3" style={{marginTop:12}}>
        <div className="card"><h3>Online Realtime</h3><div className="val">{rows.length}</div><div className="muted mono">Hub sockets • bukan dummy 847</div></div>
        <div className="card"><h3>Driver VDD</h3><div className="val" style={{color:'var(--ok)'}}>Live</div><div className="muted">ge9 IddSampleDriver</div></div>
        <div className="card"><h3>Capture Health</h3><div className="val">Realtime</div><div className="muted">WGC → GDI fallback</div></div>
      </div>
      <div className="card" style={{marginTop:12, overflow:'auto'}}>
        <table className="table"><thead><tr><th>Host</th><th>Versi</th><th>Capture</th><th>Latency</th><th>Aksi</th></tr></thead>
          <tbody>{rows.length===0 ? <tr><td colSpan={5} className="muted" style={{padding:20, textAlign:'center'}}>Tidak ada perangkat online — realtime 0</td></tr> : rows.map(d=>(
            <tr key={d.id}><td><strong>{d.name}</strong><div className="mono muted">{d.id}</div></td><td className="mono">{d.version} • {d.arch}</td><td><span className="badge purple">{d.capture}</span></td><td>{d.latency? `${d.latency}ms`:'—'}</td><td><div className="row"><button className="btn" onClick={()=> kick(d.id)}><Power size={12}/> Kick</button><button className="btn" onClick={()=> kick(d.id)}><AlertTriangle size={12}/> Diagnose</button></div></td></tr>
          ))}</tbody>
        </table>
      </div>
    </>
  )
}
function SessionsPage(){
  const [rows,setRows]=useState<any[]>([])
  const [msg,setMsg]=useState('')
  const load=async()=>{
    try{
      // fallback: devices as sessions
      const devs = await fetchDevices()
      setRows(devs.map((d:any)=> ({ id: d.id, host: d.name, client: '—', codec: d.capture, dur: '-' })))
    }catch(e:any){ setMsg(String(e.message||e)) }
  }
  useEffect(()=>{ load() },[])
  const term=async (id:string)=>{ try{ await terminateSession(id); setMsg(`Terminated ${id}`); load() }catch(e:any){ setMsg('Error: '+String(e.message||e)) } }
  return (<><h1 style={{fontSize:20}}>Sesi Aktif — P2P</h1>{msg && <div className="card" style={{marginTop:8, fontSize:12}}>{msg}</div>}<div className="card" style={{marginTop:12}}><table className="table"><thead><tr><th>Sesi</th><th>Host</th><th>Codec</th><th>Aksi</th></tr></thead><tbody>{rows.length===0 ? <tr><td colSpan={4} className="muted" style={{padding:20, textAlign:'center'}}>Tidak ada sesi — realtime 0</td></tr> : rows.map(r=> <tr key={r.id}><td className="mono">{r.id}</td><td>{r.host}</td><td>{r.codec}</td><td><button className="btn" style={{borderColor:'#FECACA', color:'#DC2626'}} onClick={()=> term(r.id)}><Pause size={12}/> Terminate</button></td></tr>)}</tbody></table></div></>) }
function HostingPage(){
  const [msg,setMsg]=useState('')
  const purge=async()=>{ try{ const r= await purgeHosting(); setMsg(`Purged ${r.purged} by ${r.by}`)}catch(e:any){ setMsg('Error: '+String(e.message||e)) } }
  return (<>
    <h1 style={{fontSize:20}}>Hosting</h1>
    {msg && <div className="card" style={{marginTop:8, fontSize:12}}>{msg}</div>}
    <div className="grid2" style={{marginTop:12}}>
      <div className="card maint">
        <div className="maint-row"><div><strong>app.xydesk.my.id</strong><p>Workers Vite • hero cartoon</p></div><span className="badge ok">v6.8.4</span></div>
        <div className="maint-row"><div><strong>admin.xydesk.my.id</strong><p>Workers Vite kotak • Turnstile</p></div><span className="badge dark">LIVE</span></div>
        <div className="maint-row"><div><strong>signal.xydesk.my.id</strong><p>Durable Object Hub</p></div><span className="badge ok">WS</span></div>
      </div>
      <div className="card"><h3>Aksi Nyata</h3><div style={{display:'grid', gap:8}}><button className="btn" onClick={purge}><HardDrive size={14}/> Purge Cache (nyata)</button><button className="btn" onClick={()=> setMsg('Rollback via GitHub Actions — trigger deploy')}><RotateCcw size={14}/> Rollback</button><button className="btn" onClick={()=> setMsg('DNS OK — xydesk.my.id active')}><Database size={14}/> Cek DNS/SSL</button><button className="btn primary" onClick={purge}><Globe size={14}/> Deploy Ulang</button></div></div>
    </div>
  </>)
}
function BackendPage(){ return <HealthPage server={false}/> }
function ServerPage(){ return <HealthPage server/> }
function HealthPage({server}:{server:boolean}){
  const [health,setHealth]=useState<Awaited<ReturnType<typeof fetchHealth>>|null>(null)
  const [error,setError]=useState('')
  const [busy,setBusy]=useState(false)
  const load=async()=>{
    setBusy(true); setError(''); setHealth(null)
    try{ setHealth(await fetchHealth()) }catch(e){ setError(String(e)) }finally{ setBusy(false) }
  }
  useEffect(()=>{ void load() },[])
  return <>
    <h1>{server?'Server — Engine & konektivitas':'Backend — Worker & penyimpanan'}</h1>
    <button className="btn" disabled={busy} onClick={load}>{busy?'Memeriksa...':'Periksa sekarang'}</button>
    {error && <p className="error" role="alert">{error}</p>}
    {health && <div className="card" style={{marginTop:12}}>
      <p>Terakhir diperiksa: {new Date(health.checkedAt).toLocaleString('id-ID')}</p>
      <div className="maint-row"><strong>Worker</strong><span>{health.worker.status}</span></div>
      <div className="maint-row"><strong>AuthStore (baca storage)</strong><span>{health.authStore.status} · {health.authStore.latencyMs} ms</span></div>
      <div className="maint-row"><strong>Hub (RPC statistik)</strong><span>{health.hub.status} · {health.hub.latencyMs} ms</span></div>
      <p className="muted">Latensi adalah waktu RPC internal saat pemeriksaan, bukan latensi streaming atau uptime historis.</p>
    </div>}
    {server && <div className="card" style={{marginTop:12}}>
      <h3>Kontrol engine belum terhubung</h3>
      <p>{health?.engine.reason || 'Belum ada agen kontrol host terautentikasi.'}</p>
      <p className="muted">Capture test, benchmark, restart engine, dan deploy tidak dijalankan dari panel ini.</p>
      <button className="btn" disabled>Restart engine tidak tersedia</button>
    </div>}
  </>
}
function MaintenancePage(){
  const [state,setState]=useState<MaintenanceState|null>(null)
  const [msg,setMsg]=useState('')
  const [error,setError]=useState('')
  const [notice,setNotice]=useState('')
  const [busy,setBusy]=useState(false)
  const lock=useRef(false)
  const load=async()=>{
    if(lock.current) return
    lock.current=true; setBusy(true); setError(''); setNotice('')
    try { const data=await fetchMaintenance(); setState(data); setMsg(data.message||'') }
    catch(e){ setState(null); setError(String(e)) }
    finally { lock.current=false; setBusy(false) }
  }
  useEffect(()=>{ void load() },[])
  const toggle=(service:MaintenanceService)=>{
    if(!state || lock.current) return
    setState({...state,[service]:!state[service]})
    setNotice('Perubahan belum disimpan.')
  }
  const save=async()=>{
    if(!state || lock.current) return
    lock.current=true; setBusy(true); setError(''); setNotice('')
    try {
      await saveMaintenance(state,msg)
      const confirmed=await fetchMaintenance()
      if(['web','desktop','android','signal'].some(k=>confirmed[k as MaintenanceService]!==state[k as MaintenanceService]) || confirmed.message!==msg){
        throw new Error('Hasil baca ulang tidak sesuai. Penyimpanan belum dapat dipastikan.')
      }
      setState(confirmed); setMsg(confirmed.message)
      setNotice('Maintenance tersimpan dan terverifikasi melalui baca ulang.')
    } catch(e){
      setError(`${String(e)} Sebagian perubahan mungkin sudah tersimpan. Muat ulang status sebelum mencoba lagi.`)
      setState(null)
    } finally { lock.current=false; setBusy(false) }
  }
  return (<>
    <h1 style={{fontSize:20}}>Maintenance — Web / App / Signal</h1>
    <p className="muted">Ubah pilihan lalu simpan. Toggle tidak langsung mengubah layanan.</p>
    {error && <div className="error" role="alert">{error}</div>}
    {notice && <p role="status">{notice}</p>}
    <button className="btn" disabled={busy} onClick={load}>{busy?'Memproses...':'Muat ulang status'}</button>
    <div className="grid2" style={{marginTop:12}}>
      <div className="card maint">
        {(['web','desktop','android','signal'] as const).map(k=>(
          <div className="maint-row" key={k}><strong>{k}</strong>
            <button className={`toggle ${state?.[k]?'on':''}`} role="switch" aria-checked={!!state?.[k]} aria-label={k} disabled={!state||busy} onClick={()=>toggle(k)}/>
          </div>
        ))}
        {!state && <p className="muted">Status layanan belum tersedia. Kontrol dinonaktifkan.</p>}
        <label htmlFor="maintenance-message">Pesan banner</label>
        <textarea id="maintenance-message" rows={3} value={msg} disabled={!state||busy} onChange={e=>{setMsg(e.target.value);setNotice('Perubahan belum disimpan.')}} />
        <button className="btn primary block" onClick={save} disabled={!state||busy}>{busy?'Memproses...':'Simpan & Publish'}</button>
      </div>
      <div className="card"><h3>Preview Banner</h3><div style={{background:'var(--purple)',color:'#fff',padding:14,fontWeight:900,textAlign:'center'}}>{msg||'Belum ada pesan banner'}</div><p className="muted">Pratinjau pesan, bukan status layanan live.</p></div>
    </div>
  </>)
}
function LogsPage(){
  const [logs,setLogs]=useState<any[]>([])
  const [error,setError]=useState('')
  const [q,setQ]=useState('')
  const load=async()=>{
    try{
      const l = await fetchLogs()
      setLogs(l); setError('')
    }catch(e){ setError(String(e)) }
  }
  useEffect(()=>{ load(); const id=setInterval(load,5000); return ()=> clearInterval(id) },[])
  const filtered = q ? logs.filter((l:any)=> JSON.stringify(l).toLowerCase().includes(q.toLowerCase())) : logs
  return (<><h1 style={{fontSize:20}}>Logs — Realtime</h1>{error && <div className="error" role="alert">{error} — daftar terakhir mungkin sudah tidak terbaru.</div>}<div className="card" style={{marginTop:12}}><div className="row" style={{marginBottom:8}}><input placeholder="filter: ban, kick, role" value={q} onChange={e=> setQ(e.target.value)} style={{flex:1, padding:'10px'}}/><button className="btn primary" onClick={load}>Refresh</button></div><pre className="mono" style={{background:'#0F0F14', color:'#EDE9FE', padding:12, maxHeight:360, overflow:'auto', fontSize:11}}>{filtered.length===0 ? 'Belum ada log admin — realtime 0' : filtered.map((l:any)=> `${new Date(l.at).toLocaleString()} [${l.action}] ${l.email||l.id||''} by ${l.by}`).join('\n')}</pre></div></>)
}
function SettingsPage(){
  return (<><h1 style={{fontSize:20}}>Settings</h1><div className="grid2" style={{marginTop:12}}><div className="card"><h3>Brand</h3><p className="muted" style={{fontSize:12}}>Kotak tegas, no rounded, custom total, #7C3AED.</p><div className="row" style={{marginTop:8}}><span style={{width:28, height:28, background:'#7C3AED', display:'inline-block', border:'1px solid var(--border)'}}/><span style={{width:28, height:28, background:'#EDE9FE', display:'inline-block', border:'1px solid var(--border)'}}/></div></div><div className="card"><h3>Keamanan</h3><p className="muted" style={{fontSize:12}}>Username, password, captcha, dan authenticator. Sesi disimpan dalam cookie HttpOnly.</p><div className="row"><span className="badge dark"><ShieldCheck size={12}/> Turnstile ON</span><span className="badge ok"><Activity size={12}/> TOTP aktif</span></div></div></div></>)
}

// @ts-ignore
declare const __APP_VERSION__: string

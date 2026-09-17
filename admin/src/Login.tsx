import { useEffect, useState } from 'react'
import GoogleBootstrap from './GoogleBootstrap'
import Captcha from './Captcha'
import { fetchAuthConfig, passwordLogin } from './api'
import type { AuthConfig, SessionStatus } from './api'
export default function Login({onLogin}:{onLogin:(session:SessionStatus)=>void}){
  const [config,setConfig]=useState<AuthConfig|null>(null),[error,setError]=useState(''),[retry,setRetry]=useState(0)
  useEffect(()=>{let active=true;setError('');fetchAuthConfig().then(c=>{if(active)setConfig(c)}).catch(e=>{if(active)setError(String(e))});return()=>{active=false}},[retry])
  if(!config)return <div className="login-wrap"><div className="login-card"><h1>XyDesk Admin</h1>{error?<><p className="error" role="alert">{error}</p><button className="btn" onClick={()=>setRetry(v=>v+1)}>Coba lagi</button></>:<p>Memeriksa metode login...</p>}</div></div>
  if(!config.passwordEnabled&&!config.setupAvailable)return <div className="login-wrap"><div className="login-card"><h1>Setup belum tersedia</h1><p>Konfigurasi keamanan server belum siap. Hubungi pemilik server; jangan kirim password ke chat.</p><button className="btn" onClick={()=>setRetry(v=>v+1)}>Periksa lagi</button></div></div>
  if(!config.passwordEnabled)return <GoogleBootstrap onLogin={onLogin}/>
  return <PasswordLogin onLogin={onLogin}/>
}
function PasswordLogin({onLogin}:{onLogin:(session:SessionStatus)=>void}){
  const [username,setUsername]=useState(''),[password,setPassword]=useState(''),[code,setCode]=useState('')
  const [recovery,setRecovery]=useState(false),[captcha,setCaptcha]=useState(''),[nonce,setNonce]=useState(0)
  const [busy,setBusy]=useState(false),[error,setError]=useState('')
  const submit=async(e:React.FormEvent)=>{
    e.preventDefault();if(busy||!captcha)return
    setBusy(true);setError('')
    try{const status=await passwordLogin(username,password,code,recovery,captcha);setPassword('');setCode('');onLogin(status)}
    catch(e){setError(String(e));setCode('')}
    finally{setBusy(false);setCaptcha('');setNonce(v=>v+1)}
  }
  return <div className="login-wrap"><form className="login-card" onSubmit={submit}>
    <div className="login-head"><img src="/logo.png" alt="XyDesk"/><div><h1>XyDesk Admin</h1><p>Username, password, dan verifikasi dua langkah.</p></div></div>
    <div className="field"><label htmlFor="admin-username">Username</label><input id="admin-username" autoComplete="username" autoCapitalize="none" value={username} onChange={e=>setUsername(e.target.value)} minLength={3} maxLength={32} required disabled={busy}/></div>
    <div className="field"><label htmlFor="admin-password">Password</label><input id="admin-password" type="password" autoComplete="current-password" value={password} onChange={e=>setPassword(e.target.value)} maxLength={128} required disabled={busy}/></div>
    <div className="field"><label htmlFor="admin-code">{recovery?'Kode pemulihan':'Kode authenticator'}</label><input id="admin-code" autoComplete="one-time-code" inputMode={recovery?'text':'numeric'} value={code} onChange={e=>setCode(e.target.value)} maxLength={recovery?64:6} required disabled={busy}/></div>
    <label style={{fontSize:12,display:'flex',gap:8}}><input type="checkbox" checked={recovery} onChange={e=>{setRecovery(e.target.checked);setCode('')}} disabled={busy}/> Gunakan kode pemulihan sekali pakai</label>
    <Captcha onToken={setCaptcha} nonce={nonce}/>
    <button type="button" className="btn" onClick={()=>setNonce(v=>v+1)} disabled={busy}>Muat ulang captcha</button>
    {error&&<p className="error" role="alert">{error}</p>}
    <button className="btn primary block" type="submit" disabled={busy||!captcha} style={{marginTop:12}}>{busy?'Memeriksa...':'Masuk'}</button>
    <p className="muted" style={{fontSize:12}}>Sesi disimpan sebagai cookie aman, bukan token yang bisa dibaca JavaScript. Kode authenticator yang sudah dipakai harus menunggu periode berikutnya.</p>
  </form></div>
}

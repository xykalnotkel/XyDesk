import { useState } from 'react'
import { startAdminSetup, confirmAdminSetup, logoutAdmin } from './api'
import type { SessionStatus } from './api'
export default function Setup({onComplete}:{onComplete:(status:SessionStatus)=>void}){
  const [username,setUsername]=useState(''),[password,setPassword]=useState(''),[confirm,setConfirm]=useState(''),[code,setCode]=useState('')
  const [enrollment,setEnrollment]=useState<Awaited<ReturnType<typeof startAdminSetup>>|null>(null)
  const [result,setResult]=useState<Awaited<ReturnType<typeof confirmAdminSetup>>|null>(null)
  const [saved,setSaved]=useState(false),[busy,setBusy]=useState(false),[error,setError]=useState('')
  const begin=async(e:React.FormEvent)=>{
    e.preventDefault();if(busy)return
    if(password!==confirm){setError('Konfirmasi password belum sama.');return}
    setBusy(true);setError('')
    try{setEnrollment(await startAdminSetup(username,password));setPassword('');setConfirm('')}
    catch(e){setError(String(e))}finally{setBusy(false)}
  }
  const activate=async(e:React.FormEvent)=>{
    e.preventDefault();if(busy)return
    setBusy(true);setError('')
    try{setResult(await confirmAdminSetup(code));setEnrollment(null);setCode('')}
    catch(e){setError(String(e))}finally{setBusy(false)}
  }
  const download=()=>{
    if(!result)return
    const url=URL.createObjectURL(new Blob([`XyDesk Admin — kode pemulihan sekali pakai\nUsername: ${result.username}\nSimpan di tempat aman, terpisah dari password.\n\n${result.recoveryCodes.join('\n')}\n`],{type:'text/plain'}))
    const a=document.createElement('a');a.href=url;a.download='xydesk-admin-recovery-codes.txt';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000)
  }
  return <div className="login-wrap"><div className="login-card" style={{maxWidth:560}}>
    <h1>{result?'Akun admin siap':'Siapkan akun admin'}</h1>
    <p className="muted">{result?'Login Google sudah dimatikan. Gunakan username, password, dan authenticator.':'Google hanya untuk membuktikan kepemilikan saat setup. Penggantian login berlaku setelah kode authenticator dikonfirmasi.'}</p>
    {error&&<p className="error" role="alert">{error}</p>}
    {result?<>
      <h3>Simpan kode pemulihan sekarang</h3><p>Kode hanya ditampilkan sekali. Setiap kode dapat menggantikan authenticator satu kali, tetapi password tetap diperlukan.</p>
      <pre className="mono" style={{fontSize:12,whiteSpace:'pre-wrap'}}>{result.recoveryCodes.join('\n')}</pre>
      <button className="btn" onClick={download}>Unduh kode pemulihan</button>
      <label style={{display:'flex',gap:8,margin:'16px 0'}}><input type="checkbox" checked={saved} onChange={e=>setSaved(e.target.checked)}/> Saya sudah menyimpan kode di tempat aman.</label>
      <button className="btn primary block" disabled={!saved} onClick={()=>onComplete(result)}>Buka dashboard</button>
    </>:enrollment?<form onSubmit={activate}>
      <h3>Tambahkan ke authenticator</h3><p>Di aplikasi authenticator, pilih tambah akun → masukkan kunci setup → jenis berbasis waktu (TOTP).</p>
      <label>Kunci setup (jangan dibagikan)</label><pre className="mono" style={{whiteSpace:'pre-wrap',overflowWrap:'anywhere'}}>{enrollment.secret}</pre>
      <a className="btn" href={enrollment.otpauthUri}>Buka aplikasi authenticator</a>
      <p className="muted">Berlaku sampai {new Date(enrollment.expiresAt).toLocaleTimeString('id-ID')}. Pastikan jam perangkat otomatis.</p>
      <div className="field"><label htmlFor="setup-code">Kode 6 digit</label><input id="setup-code" autoComplete="one-time-code" inputMode="numeric" pattern="[0-9]{6}" maxLength={6} value={code} onChange={e=>setCode(e.target.value)} required disabled={busy}/></div>
      <button className="btn primary block" disabled={busy}>{busy?'Memverifikasi...':'Aktifkan & matikan login Google'}</button>
      <button className="btn" type="button" disabled={busy} onClick={()=>{setEnrollment(null);setCode('')}} style={{marginTop:8}}>Mulai ulang setup</button>
    </form>:<form onSubmit={begin}>
      <div className="field"><label htmlFor="setup-user">Username admin</label><input id="setup-user" value={username} onChange={e=>setUsername(e.target.value)} autoComplete="username" autoCapitalize="none" pattern="[a-z0-9][a-z0-9._-]{2,31}" minLength={3} maxLength={32} required disabled={busy}/></div>
      <div className="field"><label htmlFor="setup-password">Password baru (14–128 karakter)</label><input id="setup-password" type="password" autoComplete="new-password" value={password} onChange={e=>setPassword(e.target.value)} minLength={14} maxLength={128} required disabled={busy}/></div>
      <div className="field"><label htmlFor="setup-confirm">Ulangi password</label><input id="setup-confirm" type="password" autoComplete="new-password" value={confirm} onChange={e=>setConfirm(e.target.value)} required disabled={busy}/></div>
      <p className="muted">Gunakan password unik dari pengelola password atau frasa sandi panjang. Password tidak perlu dikirim ke chat.</p>
      <button className="btn primary block" disabled={busy}>{busy?'Menyiapkan...':'Lanjut ke authenticator'}</button>
    </form>}
    {!result&&<button className="btn" style={{marginTop:12}} disabled={busy} onClick={()=>{void logoutAdmin().catch(e=>setError(String(e)))}}>Keluar</button>}
  </div></div>
}

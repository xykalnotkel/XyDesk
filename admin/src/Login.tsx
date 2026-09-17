import { useEffect, useRef, useState } from 'react'
import { loginAdmin, TURNSTILE_SITEKEY } from './api'

declare global {
  interface Window {
    turnstile?: {
      render:(el:HTMLElement, options:{sitekey:string;callback:(t:string)=>void;'expired-callback':()=>void;'error-callback':()=>void})=>string
      reset:(id:string)=>void
      remove:(id:string)=>void
    }
    google?: {accounts:{id:{initialize:(opts:{client_id:string;callback:(r:{credential:string})=>void})=>void;renderButton:(el:HTMLElement,opts:{theme:string;size:string})=>void}}}
  }
}
const CLIENT_ID=(import.meta as any).env?.VITE_GOOGLE_CLIENT_ID || ''
export default function Login({onLogin}:{onLogin:(token:string)=>void}){
  const captcha=useRef<HTMLDivElement>(null)
  const googleButton=useRef<HTMLDivElement>(null)
  const captchaToken=useRef('')
  const working=useRef(false)
  const [error,setError]=useState('')
  const [busy,setBusy]=useState(false)
  useEffect(()=>{
    if(!CLIENT_ID || !TURNSTILE_SITEKEY){ setError('Login belum dikonfigurasi: Google Client ID dan Turnstile sitekey diperlukan.'); return }
    let disposed=false, initialized=false, widget:string|undefined
    const initialize=()=>{
      if(initialized || !window.google || !window.turnstile || !captcha.current || !googleButton.current) return
      initialized=true
      widget=window.turnstile.render(captcha.current,{
        sitekey:TURNSTILE_SITEKEY, callback:t=>{captchaToken.current=t},
        'expired-callback':()=>{captchaToken.current=''},
        'error-callback':()=>{captchaToken.current='';setError('Captcha gagal dimuat. Muat ulang halaman.')}
      })
      window.google.accounts.id.initialize({client_id:CLIENT_ID,callback:async result=>{
        if(disposed || working.current) return
        if(!captchaToken.current){setError('Selesaikan captcha sebelum memilih akun Google.');return}
        working.current=true;setBusy(true);setError('')
        const token=captchaToken.current;captchaToken.current=''
        try{const session=await loginAdmin(result.credential,token);if(!disposed) onLogin(session.token)}
        catch(e){if(!disposed) setError(String(e))}
        finally{
          working.current=false
          if(!disposed){setBusy(false);if(widget) window.turnstile?.reset(widget)}
        }
      }})
      window.google.accounts.id.renderButton(googleButton.current,{theme:'outline',size:'large'})
    }
    initialize()
    const interval=setInterval(initialize,200)
    const timeout=setTimeout(()=>{clearInterval(interval);if(!initialized)setError('Layanan Google atau captcha tidak dapat dimuat. Periksa jaringan lalu muat ulang.')},15000)
    return ()=>{disposed=true;clearInterval(interval);clearTimeout(timeout);captchaToken.current='';if(widget)window.turnstile?.remove(widget);googleButton.current?.replaceChildren()}
  },[onLogin])
  return <div className="login-wrap"><div className="login-card">
    <div className="login-head"><img src="/logo.png" alt="XyDesk"/><div><h1>XyDesk Admin</h1><p>Masuk menggunakan akun Google admin yang diizinkan.</p></div></div>
    <div ref={captcha} style={{minHeight:65}}/>
    <div ref={googleButton}/>
    {busy && <p role="status">Memverifikasi akun...</p>}
    {error && <p className="error" role="alert">{error}</p>}
  </div></div>
}

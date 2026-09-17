import { useEffect, useRef, useState } from 'react'
import { TURNSTILE_SITEKEY } from './api'
export default function Captcha({onToken,nonce}:{onToken:(token:string)=>void;nonce:number}){
  const container=useRef<HTMLDivElement>(null),callback=useRef(onToken)
  const [error,setError]=useState('')
  callback.current=onToken
  useEffect(()=>{
    let widget:string|undefined
    setError('');callback.current('')
    const init=()=>{
      if(widget!==undefined||!window.turnstile||!container.current)return
      widget=window.turnstile.render(container.current,{sitekey:TURNSTILE_SITEKEY,callback:t=>callback.current(t),'expired-callback':()=>callback.current(''),'error-callback':()=>{callback.current('');setError('Captcha gagal. Muat ulang captcha atau periksa jaringan.')}})
    }
    if(!TURNSTILE_SITEKEY){setError('Captcha belum dikonfigurasi.');return}
    init();const interval=setInterval(init,200)
    const timeout=setTimeout(()=>{clearInterval(interval);if(widget===undefined)setError('Captcha tidak dapat dimuat. Periksa jaringan lalu muat ulang.')},15000)
    return ()=>{clearInterval(interval);clearTimeout(timeout);callback.current('');if(widget!==undefined)window.turnstile?.remove(widget)}
  },[nonce])
  return <><div ref={container} style={{minHeight:65,marginTop:12}}/>{error&&<p className="error" role="alert">{error}</p>}</>
}

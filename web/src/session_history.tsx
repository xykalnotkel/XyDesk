import {useEffect, useState} from 'react';
import {API_BASE} from './api';
import {MAX_PREVIEW_URL} from './wallpaper_transfer';
export type HistoryState = 'ended'|'interrupted'|'failed'|'cancelled';
export type HistoryItem = {id:string;deviceId:string;name:string;startedAt:number;endedAt:number;state:HistoryState;specs:Record<string,string>;preview:string|null;previewConsent?:boolean};
const LOCAL_KEY='xydesk.guest.history.v1';
const TOKEN_KEY='xydesk.web.jwt';
export function accountHistoryToken(){return localStorage.getItem(TOKEN_KEY);}
export function loadGuestHistory():HistoryItem[]{
 try{const rows=JSON.parse(localStorage.getItem(LOCAL_KEY)||'[]');return Array.isArray(rows)?rows.filter(x=>x&&typeof x.id==='string'&&/^\d{9}$/.test(x.deviceId)).slice(0,20).map(x=>({...x,preview:typeof x.preview==='string'&&x.preview.length<=MAX_PREVIEW_URL&&/^data:image\/jpeg;base64,[A-Za-z0-9+/]+=*$/.test(x.preview)?x.preview:null})):[];}catch{return [];}
}
async function serverHistory(token:string, body?:object){
 const r=await fetch(`${API_BASE}/auth/session-history`,{method:body?'POST':'GET',headers:{Authorization:`Bearer ${token}`,...(body?{'Content-Type':'application/json'}:{})},body:body?JSON.stringify(body):undefined,keepalive:!!body && JSON.stringify(body).length<48000,cache:'no-store'});
 if(!r.ok)throw Error(r.status===401?'Sesi akun berakhir. Masuk lagi untuk membuka riwayat.':'Riwayat server belum dapat diakses. Coba lagi.');
 return r.json();
}
export function deviceCards(rows:HistoryItem[]):HistoryItem[]{
 const cards=new Map<string,HistoryItem>();
 for(const row of [...rows].sort((a,b)=>b.endedAt-a.endedAt)){
  const old=cards.get(row.deviceId);
  if(!old)cards.set(row.deviceId,{...row});else if(!old.preview&&row.preview)old.preview=row.preview;
 }
 return [...cards.values()];
}
export async function saveSessionHistory(item:HistoryItem, accountToken:string|null){
 if(accountToken){await serverHistory(accountToken,{action:'save',record:item});return;}
 const previous=loadGuestHistory();
 const preview=item.preview || deviceCards(previous).find(x=>x.deviceId===item.deviceId)?.preview || null;
 const rows=[{...item,preview},...previous.filter(x=>x.id!==item.id)].slice(0,20);
 const previews=new Set<string>();for(const row of rows){if(previews.has(row.deviceId))row.preview=null;else if(row.preview)previews.add(row.deviceId);}
 for(let i=rows.length-1;;i--){try{localStorage.setItem(LOCAL_KEY,JSON.stringify(rows));return;}catch{if(i<=0)throw Error('Penyimpanan browser penuh; preview baru belum tersimpan.');rows[i].preview=null;}}
}
const status:Record<HistoryState,string>={ended:'Sesi selesai',interrupted:'Koneksi terputus',failed:'Gagal terhubung',cancelled:'Dibatalkan'};
export function SessionHistoryPage(){
 const [token,setToken]=useState(accountHistoryToken);const [items,setItems]=useState<HistoryItem[]>([]);const [error,setError]=useState('');const [loading,setLoading]=useState(true);const [refresh,setRefresh]=useState(0);
 useEffect(()=>{const changed=()=>setToken(accountHistoryToken());window.addEventListener('storage',changed);return()=>window.removeEventListener('storage',changed);},[]);
 useEffect(()=>{let active=true;setItems([]);setLoading(true);setError('');const task=token?serverHistory(token).then(x=>x.items):Promise.resolve(loadGuestHistory());task.then(rows=>{if(active)setItems(deviceCards(rows));}).catch(e=>{if(active)setError(e.message);}).finally(()=>{if(active)setLoading(false);});return()=>{active=false;};},[token,refresh]);
 const remove=async(id?:string)=>{if(!window.confirm(id?'Hapus riwayat perangkat ini beserta preview?':'Hapus semua riwayat dan preview?'))return;try{if(token)await serverHistory(token,id?{action:'delete-device',deviceId:id}:{action:'clear'});else localStorage.setItem(LOCAL_KEY,JSON.stringify(id?loadGuestHistory().filter(x=>x.deviceId!==id):[]));setRefresh(x=>x+1);}catch(e){setError(e instanceof Error?e.message:'Gagal menghapus riwayat.');}};
 return <main className="history-page"><header className="history-heading"><div><p className="eyebrow">PERANGKAT & SESI</p><h1>Riwayat koneksi</h1><p>{token?'Disimpan pada akun di server.':'Mode tamu — disimpan hanya di browser ini.'} Satu kartu per ID dari 20 sesi terbaru.</p></div><a className="btn primary" href="/connect">Hubungkan PC</a></header>
 <div className="history-actions"><button className="btn ghost" onClick={()=>setRefresh(x=>x+1)}>Muat ulang</button><button className="btn ghost" disabled={!items.length} onClick={()=>void remove()}>Hapus semua</button></div>
 {error&&<p role="alert">{error}</p>}{loading?<p role="status">Memuat riwayat…</p>:!items.length&&!error?<div className="history-empty"><h2>Belum ada sesi tersimpan</h2><p>Setelah sesi selesai atau terputus, detail PC muncul di sini. Wallpaper HD diambil manual tanpa menangkap aplikasi terbuka dan dipakai ulang untuk ID yang sama.</p></div>:null}
 <div className="history-grid">{items.map(item=><article className="history-card" key={item.id}><div className="history-banner">{item.preview?<img src={item.preview} alt={`Preview tersimpan ${item.name}`} loading="lazy"/>:<div><span>▣</span><small>Preview tidak disimpan</small></div>}<span className="history-status">{status[item.state]||'Sesi terakhir'}</span></div><div className="history-content"><h2>{item.name}</h2><p>ID {item.deviceId} · {new Date(item.endedAt).toLocaleString('id-ID')}</p><p>Durasi {Math.max(0,Math.round((item.endedAt-item.startedAt)/1000))} detik</p><details><summary>Spesifikasi & detail</summary><dl>{Object.entries(item.specs||{}).map(([key,value])=><div key={key}><dt>{key.toUpperCase()}</dt><dd>{String(value)}</dd></div>)}</dl>{!Object.keys(item.specs||{}).length&&<p>Host belum mengirim spesifikasi.</p>}<p>Status PC saat ini belum diperiksa. Banner adalah preview tersimpan, bukan layar langsung.</p></details><footer><a className="btn ghost" href="/connect" onClick={()=>localStorage.setItem('xydesk.web.lastHost',item.deviceId)}>Hubungkan lagi</a><button className="text-action" onClick={()=>void remove(item.deviceId)}>Hapus</button></footer></div></article>)}</div></main>;
}

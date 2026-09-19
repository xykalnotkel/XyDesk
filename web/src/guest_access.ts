// Remembered host grants are secrets, separate from wallpaper/history and URLs.
const REFRESH_KEY='xydesk.guest.browser.v1';
const ACCESS_KEY='xydesk.web.guestJwt';
const GRANT_PREFIX='xydesk.guest.hostAccess.v1.';
function hostKey(id:string){return /^\d{9}$/.test(id)?GRANT_PREFIX+id:null;}
export function loadHostAccess(id:string):string|null {
 try{const key=hostKey(id),token=key?localStorage.getItem(key):null;return token&&/^[0-9a-f]{64}$/.test(token)?token:null;}catch{return null;}
}
export function saveHostAccess(id:string,token:string):boolean {
 const key=hostKey(id);if(!key||!/^[0-9a-f]{64}$/.test(token))return false;
 try{localStorage.setItem(key,token);return true;}catch{return false;}
}
export function forgetHostAccess(id:string){try{const key=hostKey(id);if(key)localStorage.removeItem(key);}catch{}}
function fresh(token:string|null){
 try {const p=JSON.parse(atob(token!.split('.')[1].replace(/-/g,'+').replace(/_/g,'/')));return p.guest===true&&typeof p.exp==='number'&&p.exp>Date.now()/1000+60;}catch{return false;}
}
let inflight:Promise<string>|null=null;
export function ensureGuestAccess(issue:(refresh?:string)=>Promise<{token:string;refresh?:string}>):Promise<string>{
 if(inflight)return inflight;
 inflight=(async()=>{
  let cached:string|null=null,refresh:string|null=null;
  try{cached=sessionStorage.getItem(ACCESS_KEY);refresh=localStorage.getItem(REFRESH_KEY);}catch{}
  if(fresh(cached))return cached!;
  let response;
  try{response=await issue(refresh||undefined);}
  catch(error){
   if(!refresh||(error as {status?:number})?.status!==401)throw error;
   // A rotated server key can invalidate a browser identity, not its host-side grant.
   response=await issue();
  }
  if(typeof response.token!=='string'||!response.token)throw Error('Respons sesi tamu tidak valid.');
  try{if(response.refresh)localStorage.setItem(REFRESH_KEY,response.refresh);sessionStorage.setItem(ACCESS_KEY,response.token);}catch{}
  return response.token;
 })().finally(()=>{inflight=null;});
 return inflight;
}
export function mayRetrySession(phase:string,allowed:boolean,wasConnected:boolean,tries:number){return allowed&&wasConnected&&tries<10&&['error','ended','peer-offline'].includes(phase);}
export function retryDelay(tries:number){return Math.min(30000,2000*2**Math.max(0,tries-1));}

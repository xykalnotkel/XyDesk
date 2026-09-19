// Browser identity only. This credential cannot authenticate a host, admin,
// member account, or WebSocket; host pairing is always checked separately.
const pattern=/^g1\.([0-9a-f]{64})\.([0-9a-f]{64})$/;
async function key(secret,usage){return crypto.subtle.importKey('raw',new TextEncoder().encode(secret),{name:'HMAC',hash:'SHA-256'},false,[usage]);}
function bytes(hex){return Uint8Array.from(hex.match(/../g).map(x=>parseInt(x,16)));}
function hex(bytes){return [...new Uint8Array(bytes)].map(x=>x.toString(16).padStart(2,'0')).join('');}
function message(id){return new TextEncoder().encode(`xydesk-guest-browser-refresh-v1\0${id}`);}
export async function createGuestRefresh(secret){
 if(!secret)throw Error('missing-secret');
 const id=hex(crypto.getRandomValues(new Uint8Array(32)));
 const mac=hex(await crypto.subtle.sign('HMAC',await key(secret,'sign'),message(id)));
 return {refresh:`g1.${id}.${mac}`,sub:`guest:${id}`};
}
export async function verifyGuestRefresh(refresh,secret){
 if(!secret||typeof refresh!=='string')return null;
 const match=pattern.exec(refresh);if(!match)return null;
 return await crypto.subtle.verify('HMAC',await key(secret,'verify'),bytes(match[2]),message(match[1]))?`guest:${match[1]}`:null;
}

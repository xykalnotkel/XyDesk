import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {readFileSync} from 'node:fs';
import {signJwt} from '../src/auth.js';
import {signSignalToken} from '../src/worker.js';
const require=createRequire(import.meta.url),wr=createRequire(require.resolve('wrangler/package.json'));
const {Miniflare,convertV4MiniflareOptions}=wr('miniflare');
const bundle=readFileSync(new URL('../.wrangler/runtime-test/entry.js',import.meta.url),'utf8');
// Only the in-memory test bundle has fixture hooks; deployment entry is untouched.
const script=bundle+`\nconst fetchAuth=AuthStore.prototype.fetch;AuthStore.prototype.fetch=async function(r){if(new URL(r.url).pathname==='/fixture'){const u=await r.json();await this.ctx.storage.put('user:'+u.email,u);return Response.json({ok:true});}return fetchAuth.call(this,r);};`;
const secret='bound-runtime-only';
const options={workers:[{name:'bound-runtime',modules:true,script,compatibilityDate:'2026-08-17',bindings:{AUTH_SECRET:secret,XYDESK_SECRET:secret},durableObjects:{AUTH_STORE:{className:'AuthStore',useSQLite:true},HUB:{className:'Hub',useSQLite:true}}}]};
const mf=new Miniflare(convertV4MiniflareOptions?convertV4MiniflareOptions(options):options);
const sockets=[];
function inbox(ws){
 const messages=[];const listeners=new Set();let closeEvent;
 ws.addEventListener('message',ev=>{messages.push(JSON.parse(ev.data));for(const f of [...listeners])f();});
 ws.addEventListener('close',ev=>{closeEvent=ev;for(const f of [...listeners])f();try{ws.close();}catch{}});
 const wait=(check,ms=6000)=>new Promise((resolve,reject)=>{const timer=setTimeout(()=>{listeners.delete(run);reject(Error('socket timeout'));},ms);function run(){const v=check();if(v){clearTimeout(timer);listeners.delete(run);resolve(v);}}listeners.add(run);run();});
 return {messages,waitType:type=>wait(()=>messages.find(m=>m.type===type)),waitBye:()=>wait(()=>messages.find(m=>m.type==='bye'),24000),waitClose:()=>wait(()=>closeEvent,24000),closed:()=>closeEvent};
}
const call=(path,token,body)=>mf.dispatchFetch('https://signal.example'+path,{method:body?'POST':'GET',headers:token?{Authorization:'Bearer '+token}:{},body:body?JSON.stringify(body):undefined});
async function connect(id,role,token){
 const r=await mf.dispatchFetch(`https://signal.example/ws?id=${id}&role=${role}`,{headers:{Upgrade:'websocket',Authorization:'Bearer '+token}});assert.equal(r.status,101);
 const ws=r.webSocket;const box=inbox(ws);ws.accept();sockets.push(ws);ws.send(JSON.stringify({type:'hello',to:id}));await box.waitType('welcome');return {ws,box};
}
try {
 const ns=await mf.getDurableObjectNamespace('AUTH_STORE','bound-runtime'),stub=ns.get(ns.idFromName('auth'));
 const user={id:'bound-member',email:'bound@example.test'};
 await stub.fetch('https://internal/fixture',{method:'POST',body:JSON.stringify(user)});
 const jwt=await signJwt({sub:user.id,email:user.email},secret);
 const ticket=await(await call('/signal-token?id=bound-client',jwt)).text();assert.ok(ticket.startsWith('v2.'));
 const host=await connect('123456789','host',await signSignalToken('123456789','host',secret));
 const client=await connect('bound-client','client',ticket);
 host.ws.send(JSON.stringify({type:'answer',to:'bound-client',sdp:{type:'answer',sdp:'fixture'}}));await client.box.waitType('answer');
 const guestJwt=await signJwt({sub:'guest:healthy',guest:true},secret);
 const guest=await connect('healthy-guest','client',await(await call('/signal-token?id=healthy-guest',guestJwt)).text());
 const expiredJwt=await signJwt({sub:'guest:short',guest:true},secret,5);
 const expiring=await connect('short-guest','client',await(await call('/signal-token?id=short-guest',expiredJwt)).text());
 const began=Date.now();
 const revoked=await stub.fetch('https://internal/admin/revoke',{method:'POST',headers:{'x-internal-admin':'1'},body:JSON.stringify({email:user.email})});assert.equal(revoked.status,200);
 assert.equal((await call('/ws?id=bound-client',ticket)).status,401);
 assert.equal((await call('/turn-ice?id=bound-client',ticket)).status,403);
 // No client message triggers the check: let the real Durable Object alarm run.
 const [bye,closed,expired]=await Promise.all([host.box.waitBye(),client.box.waitClose(),expiring.box.waitClose()]);
 assert.equal(bye.from,'bound-client');assert.equal(bye.reason,'account-authorization-ended');assert.equal(closed.code,1008);assert.equal(expired.code,1008);
 assert.equal(host.box.closed(),undefined);assert.equal(guest.box.closed(),undefined);
 guest.ws.send(JSON.stringify({type:'ping'}));await guest.box.waitType('pong');
 assert.equal((await call('/signal-token?id=bound-client',jwt)).status,401);
 console.log(JSON.stringify({pass:true,checks:['real Worker + SQLite + WebSockets','bound ticket issued','old ticket WS401/TURN403 after revoke','idle alarm sends host bye and client close1008','idle guest expiry close1008','host and unrelated guest stay connected'],alarmObservedMs:Date.now()-began,limit:'Host is protocol fixture, not Windows/Rust media process; no real P2P termination claim.'},null,2));
}finally {for(const ws of sockets){try{ws.close();}catch{}}await mf.dispose();}

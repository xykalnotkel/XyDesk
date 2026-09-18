import test from 'node:test';
import assert from 'node:assert/strict';
import worker,{signSignalToken} from '../src/worker.js';
import {signBoundTicket,readBoundTicket,validPrincipal} from '../src/bound_ticket.js';
import {signJwt} from '../src/auth.js';
import {Hub} from '../src/hub.js';
const secret='bound-ticket-test-only';
const principal=()=>({sub:'account-uuid',guest:false,ver:1,expiresAt:Math.floor(Date.now()/1000)+3600});
function env(allowed=true){return {XYDESK_SECRET:secret,AUTH_STORE:{idFromName:n=>n,get:()=>({fetch:async()=>new Response('',{status:allowed?200:401})})}};}
function socket(meta){let a=structuredClone(meta);return {sent:[],closed:[],deserializeAttachment:()=>structuredClone(a),serializeAttachment:v=>{a=structuredClone(v);},send(s){this.sent.push(JSON.parse(s));},close(...v){this.closed.push(v);}};}
test('bound ticket binds principal, id, role and audience without email',async()=>{
 const p=principal(),t=await signBoundTicket('client-one',p,secret);
 assert.deepEqual(await readBoundTicket(t,'client-one','client',secret),p);
 assert.equal(await readBoundTicket(t,'other','client',secret),null);
 assert.equal(await readBoundTicket(t,'client-one','host',secret),null);
 assert.equal(await readBoundTicket(t,'client-one','client','wrong-secret'),null);
 const other='v2.'+await signJwt({aud:'xydesk-account',role:'client',deviceId:'client-one',principal:p},secret);
 assert.equal(await readBoundTicket(other,'client-one','client',secret),null);
 assert.equal(JSON.stringify(JSON.parse(Buffer.from(t.split('.')[2],'base64url'))).includes('email'),false);
});
test('invalid/expired principal rejected',()=>{
 assert.equal(validPrincipal({...principal(),expiresAt:0}),false);
 assert.equal(validPrincipal({...principal(),ver:-1}),false);
 assert.equal(validPrincipal({...principal(),guest:true}),false);
});
test('revoked bound ticket blocked for websocket and TURN',async()=>{
 const t=await signBoundTicket('client-one',principal(),secret),e=env(false);
 for(const [path,status] of [['/ws?id=client-one&role=client',401],['/turn-ice?id=client-one',403]]){
  const r=await worker.fetch(new Request('https://signal.example'+path,{headers:{Authorization:'Bearer '+t}}),e);assert.equal(r.status,status);
 }
});
test('auth outage cannot open bound websocket or obtain TURN',async()=>{
 const t=await signBoundTicket('client-one',principal(),secret),e=env();e.AUTH_STORE.get=()=>({fetch:async()=>{throw Error('down')}});
 assert.equal((await worker.fetch(new Request('https://signal.example/ws?id=client-one',{headers:{Authorization:'Bearer '+t}}),e)).status,503);
 assert.equal((await worker.fetch(new Request('https://signal.example/turn-ice?id=client-one',{headers:{Authorization:'Bearer '+t}}),e)).status,403);
});
test('worker overwrites spoofed principal header for bound and legacy tickets',async()=>{
 for(const bound of [true,false]){
  const p=principal(),e=env();let captured;
  e.HUB={idFromName:n=>n,get:()=>({fetch:async(_r,init)=>{captured=init.headers;return new Response('forwarded')}})};
  const t=bound?await signBoundTicket('client-one',p,secret):await signSignalToken('client-one','client',secret);
  const r=await worker.fetch(new Request('https://signal.example/ws?id=client-one',{headers:{Authorization:'Bearer '+t,'x-xydesk-principal':'spoof'}}),e);
  assert.equal(r.status,200);assert.equal(captured.get('x-xydesk-principal'),bound?JSON.stringify(p):null);
 }
});
for(const outage of [false,true])test(`idle revocation sends bye only to bound host; outage=${outage}`,async()=>{
 const client=socket({id:'c1',role:'client',connectionId:'nonce-one',principal:principal(),registered:true});
 const host=socket({id:'h1',role:'host',mediaClient:'nonce-one',registered:true});
 const other=socket({id:'h2',role:'host',mediaClient:'different',registered:true});
 const legacy=socket({id:'legacy',role:'client',registered:true});
 const e=env(false);if(outage)e.AUTH_STORE.get=()=>({fetch:async()=>{throw Error('down')}});
 const hub=new Hub({getWebSockets:()=>[client,host,other,legacy],storage:{setAlarm:async()=>{throw Error('no survivors')}}},e);
 await hub.alarm();assert.equal(client.closed[0][0],1008);assert.equal(host.sent.length,1);assert.equal(host.sent[0].type,'bye');assert.equal(host.sent[0].from,'c1');
 assert.equal(host.deserializeAttachment().mediaClient,null);assert.equal(other.sent.length,0);assert.equal(legacy.closed.length,0);assert.equal(host.closed.length,0);
 await hub.webSocketMessage(client,JSON.stringify({type:'hello'}));assert.equal(client.sent.length,0);
 await hub.webSocketClose(client);assert.equal(host.sent.length,1);
});
test('healthy bound socket rearms alarm, guest expiry closes only guest',async()=>{
 const member=socket({id:'c1',role:'client',principal:principal()});
 const guest=socket({id:'g1',role:'client',principal:{sub:'guest:test',guest:true,expiresAt:1}});
 let scheduled=0;const hub=new Hub({getWebSockets:()=>[member,guest],storage:{setAlarm:async n=>{scheduled=n;}}},env());
 await hub.alarm();assert.equal(member.closed.length,0);assert.equal(guest.closed.length,1);assert.ok(scheduled>Date.now());
});
test('new connection does not postpone existing alarm',async()=>{
 let set=0;const hub=new Hub({storage:{getAlarm:async()=>123,setAlarm:async()=>set++}},env());await hub.scheduleSessionCheck();assert.equal(set,0);
});

import test from 'node:test';import assert from 'node:assert/strict';
import {createGuestRefresh,verifyGuestRefresh} from '../src/guest_refresh.js';
import {verifyJwt} from '../src/auth.js';
import {validPrincipal,checkPrincipal,signBoundTicket,readBoundTicket} from '../src/bound_ticket.js';
import {AuthStore} from '../src/authstore.js';
const secret='fixture-guest-refresh';
function store(){const map=new Map();const storage={get:async k=>structuredClone(map.get(k)),put:async(k,v)=>map.set(k,structuredClone(v)),transaction:async f=>f(storage)};return new AuthStore({storage},{AUTH_SECRET:secret,XYDESK_SECRET:'internal-fixture'});}
const req=body=>new Request('https://fixture/auth/guest',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(body)});
test('browser identity refresh is scoped and tamper-resistant',async()=>{
 const a=await createGuestRefresh(secret),b=await createGuestRefresh(secret);
 assert.notEqual(a.refresh,b.refresh);assert.equal(await verifyGuestRefresh(a.refresh,secret),a.sub);
 assert.equal(await verifyGuestRefresh(a.refresh,'other'),null);
 assert.equal(await verifyGuestRefresh(a.refresh.slice(0,-1)+'Z',secret),null);
 assert.equal(await verifyJwt(a.refresh,secret),null);
 assert.equal(await verifyGuestRefresh('a'.repeat(10000),secret),null);
});
test('refresh preserves browser subject, creates short tickets, never a member',async()=>{
 const s=store();const first=await (await s.guest(req({}))).json();const renewed=await (await s.guest(req({refresh:first.refresh}))).json();
 const a=await verifyJwt(first.token,secret),b=await verifyJwt(renewed.token,secret);
 assert.equal(a.sub,b.sub);assert.equal(a.guest,true);assert.equal(b.aud,'xydesk-guest');assert.equal(a.exp-a.iat,900);assert.equal(renewed.refresh,first.refresh);
 assert.equal((await s.guest(req({refresh:'bad'}))).status,401);
 assert.equal((await s.guest(req(null))).status,400);
});
test('expired admission refused but admitted unlimited guest has no session timer',async()=>{
 const p={sub:'guest:fixture',guest:true,unlimited:true,expiresAt:1};
 assert.equal(validPrincipal(p),false);assert.equal(await checkPrincipal({},p),true);
 assert.equal(await checkPrincipal({},{...p,unlimited:false}),false);
 assert.equal(await checkPrincipal({},{...p,guest:false,sub:'member',ver:0}),false);
 assert.equal(await checkPrincipal({},{...p,sub:'admin'}),false);
 await assert.rejects(signBoundTicket('client',p,secret));
 const current={...p,expiresAt:Math.floor(Date.now()/1000)+900};const t=await signBoundTicket('client',current,secret);
 assert.deepEqual(await readBoundTicket(t,'client','client',secret),current);
 assert.equal(await readBoundTicket(t,'client','host',secret),null);
});
test('only internal principal issuer grants unlimited guest sessions',async()=>{
 const s=store();const {token}=await(await s.guest(req({}))).json();
 const r=await s.authorizeSession(new Request('https://fixture/auth/authorize-session',{method:'POST',headers:{Authorization:'Bearer '+token,'X-XyDesk-Internal':'internal-fixture'}}));
 const p=await r.json();assert.equal(p.unlimited,true);assert.equal(p.guest,true);
 const bad=await s.authorizeSession(new Request('https://fixture/auth/authorize-session',{method:'POST',headers:{Authorization:'Bearer '+token}}));assert.equal(bad.status,403);
});

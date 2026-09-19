import test from 'node:test';import assert from 'node:assert/strict';import vm from 'node:vm';import {readFileSync} from 'node:fs';import {transformWithOxc} from 'vite';
const src=readFileSync(new URL('../src/guest_access.ts',import.meta.url),'utf8').replace(/^export /gm,'')+'\nexports.api={loadHostAccess,saveHostAccess,forgetHostAccess,ensureGuestAccess,mayRetrySession,retryDelay};';
const {code}=await transformWithOxc(src,'guest.ts');
function setup(local=new Map(),session=new Map()) {const storage=m=>({getItem:k=>m.get(k)||null,setItem:(k,v)=>m.set(k,v),removeItem:k=>m.delete(k)});const exports={};vm.runInNewContext(code,{exports,localStorage:storage(local),sessionStorage:storage(session),atob,Date});return {...exports.api,local,session};}
const token=()=> 'e30.'+btoa(JSON.stringify({guest:true,exp:Date.now()/1000+900}))+'.signature';
test('grant survives a new page context; clear site data removes it; history contains no secret',()=>{
 const s=setup(),grant='a'.repeat(64);assert.equal(s.saveHostAccess('123456789',grant),true);
 assert.equal(setup(s.local).loadHostAccess('123456789'),grant);assert.equal(s.loadHostAccess('987654321'),null);
 assert.equal(s.saveHostAccess('../bad',grant),false);assert.equal(s.saveHostAccess('123456789','password'),false);
 assert.ok([...s.local.keys()].every(k=>!k.includes('history')));s.forgetHostAccess('123456789');assert.equal(s.loadHostAccess('123456789'),null);
});
test('browser reopen refreshes same identity without storing pairing password',async()=>{
 const s=setup();let calls=[];const issue=async r=>{calls.push(r);return {token:token(),refresh:r||'g1.fixture'};};
 await s.ensureGuestAccess(issue);await s.ensureGuestAccess(issue);assert.equal(calls.length,1);
 await setup(s.local).ensureGuestAccess(issue);assert.deepEqual(calls,[undefined,'g1.fixture']);
});
test('concurrent connects share renewal; network failures do not discard browser identity',async()=>{
 const s=setup();s.local.set('xydesk.guest.browser.v1','old');let count=0;
 const issue=async()=>{count++;await new Promise(r=>setTimeout(r,2));return{token:token(),refresh:'old'};};
 await Promise.all([s.ensureGuestAccess(issue),s.ensureGuestAccess(issue)]);assert.equal(count,1);
 const n=setup(s.local);await assert.rejects(n.ensureGuestAccess(async()=>{throw {status:503};}));assert.equal(n.local.get('xydesk.guest.browser.v1'),'old');
});
test('401 refresh reset cannot grant host access; new guest still needs pairing',async()=>{
 const s=setup();s.local.set('xydesk.guest.browser.v1','invalid');const seen=[];
 await s.ensureGuestAccess(async r=>{seen.push(r);if(r)throw {status:401};return{token:token(),refresh:'new'};});assert.deepEqual(seen,['invalid',undefined]);assert.equal(s.loadHostAccess('123456789'),null);
});
test('network error retries; owner revocation/rejection/manual stop do not',()=>{
 const s=setup();for(const phase of ['error','ended','peer-offline'])assert.equal(s.mayRetrySession(phase,true,true,0),true);
 for(const phase of ['rejected','host-busy'])assert.equal(s.mayRetrySession(phase,true,true,0),false);
 assert.equal(s.mayRetrySession('error',false,true,0),false);assert.equal(s.mayRetrySession('error',true,false,0),false);assert.equal(s.mayRetrySession('error',true,true,10),false);
 assert.equal(s.retryDelay(1),2000);assert.equal(s.retryDelay(9),30000);
});

import test from 'node:test';import assert from 'node:assert/strict';
import {AuthStore} from '../src/authstore.js';import {signJwt} from '../src/auth.js';
class Store{m=new Map();async get(k){return this.m.get(k)}async put(k,v){this.m.set(k,structuredClone(v))}async delete(k){this.m.delete(k)}async transaction(fn){return fn(this)}}
const secret='history-test-secret';const user={id:'user-a',email:'a@example.test'};const other={id:'user-b',email:'b@example.test'};
async function setup(){const storage=new Store();await storage.put('user:'+user.email,user);await storage.put('user:'+other.email,other);return {storage,auth:new AuthStore({storage},{AUTH_SECRET:secret}),token:await signJwt({sub:user.id,email:user.email},secret),otherToken:await signJwt({sub:other.id,email:other.email},secret)}}
const record=(n=0)=>({id:`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`,deviceId:'123456789',name:'PC',startedAt:Date.now()-1000,endedAt:Date.now(),state:'ended',specs:{cpu:'CPU',token:'must-drop'},password:'must-drop',userId:other.id});
const req=(token,body,path='/auth/session-history')=>new Request('https://example.test'+path,{method:body?'POST':'GET',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined});
test('history butuh akun nyata dan terisolasi berdasarkan JWT bukan body',async()=>{const {auth,token,otherToken,storage}=await setup();assert.equal((await auth.fetch(req('',null))).status,401);const guest=await signJwt({sub:'guest',guest:true},secret);assert.equal((await auth.fetch(req(guest,null))).status,401);assert.equal((await auth.fetch(req(token,{action:'save',record:record()}))).status,200);const a=await(await auth.fetch(req(token))).json(),b=await(await auth.fetch(req(otherToken))).json();assert.equal(a.items.length,1);assert.equal(b.items.length,0);assert.equal(a.items[0].password,undefined);assert.equal(a.items[0].specs.token,undefined);await auth.fetch(req(otherToken,{action:'delete',id:record().id}));assert.equal((await(await auth.fetch(req(token))).json()).items.length,1);});
test('preview memerlukan opt-in dan JPEG terbatas; tidak menerima URL remote/SVG',async()=>{const {auth,token}=await setup();for(const preview of ['https://secret.test/x','data:image/svg+xml;base64,AAAA','data:image/jpeg;base64,AAAA','data:image/jpeg;base64,'+'A'.repeat(33000)]){assert.equal((await auth.fetch(req(token,{action:'save',record:{...record(),preview,previewConsent:true}}))).status,400);}assert.equal((await auth.fetch(req(token,{action:'save',record:{...record(),preview:'data:image/jpeg;base64,/9j/wAARCACQAQADASIAAhEBAxEB/9oADAMBAAIRAxEAPwD/2Q=='}}))).status,400);assert.equal((await auth.fetch(req(token,{action:'save',record:{...record(),preview:'data:image/jpeg;base64,/9j/wAARCACQAQADASIAAhEBAxEB/9oADAMBAAIRAxEAPwD/2Q==',previewConsent:true}}))).status,200);});
test('retensi20, idempotent, delete/clear dan penghapusan akun ikut menghapus gambar',async()=>{const {auth,token,storage}=await setup();for(let n=0;n<21;n++)assert.equal((await auth.fetch(req(token,{action:'save',record:record(n)}))).status,200);let rows=(await(await auth.fetch(req(token))).json()).items;assert.equal(rows.length,20);assert.equal(storage.m.has('history:user-a:'+record(0).id),false);await auth.fetch(req(token,{action:'save',record:record(20)}));assert.equal((await(await auth.fetch(req(token))).json()).items.length,20);await auth.fetch(req(token,{action:'delete',id:record(20).id}));assert.equal((await(await auth.fetch(req(token))).json()).items.length,19);await auth.fetch(req(token,{action:'clear'}));assert.equal((await(await auth.fetch(req(token))).json()).items.length,0);await auth.fetch(req(token,{action:'save',record:record()}));assert.equal((await auth.fetch(req(token,{},'/auth/delete'))).status,200);assert.equal([...storage.m.keys()].some(k=>k.startsWith('history:user-a:')),false);assert.equal((await auth.fetch(req(token))).status,401);});
test('akun diganti/ban dan body berlebih ditolak',async()=>{const {auth,token,storage}=await setup();const r=new Request('https://example.test/auth/session-history',{method:'POST',headers:{Authorization:'Bearer '+token},body:'x'.repeat(384*1024+1)});assert.equal((await auth.fetch(r)).status,413);await storage.put('user:'+user.email,{...user,banned:true});assert.equal((await auth.fetch(req(token))).status,401);await storage.put('user:'+user.email,{...user,id:'new-id'});assert.equal((await auth.fetch(req(token))).status,401);});

test('manual preview is reused per device; delete-device removes only that device',async()=>{
 const {auth,token,otherToken}=await setup(),preview='data:image/jpeg;base64,/9j/wAARCACQAQADASIAAhEBAxEB/9oADAMBAAIRAxEAPwD/2Q==';
 await auth.fetch(req(token,{action:'save',record:{...record(1),preview,previewConsent:true}}));
 await auth.fetch(req(token,{action:'save',record:record(2)}));
 await auth.fetch(req(token,{action:'save',record:{...record(3),deviceId:'987654321'}}));
 let rows=(await(await auth.fetch(req(token))).json()).items;
 assert.equal(rows.find(x=>x.id===record(2).id).preview,preview);assert.equal(rows.find(x=>x.deviceId==='987654321').preview,null);
 await auth.fetch(req(otherToken,{action:'delete-device',deviceId:'123456789'}));assert.equal((await(await auth.fetch(req(token))).json()).items.length,3);
 assert.equal((await auth.fetch(req(token,{action:'delete-device',deviceId:'123456789'}))).status,200);
 rows=(await(await auth.fetch(req(token))).json()).items;assert.equal(rows.length,1);assert.equal(rows[0].deviceId,'987654321');
});
test('late manual preview write cannot revert final session state',async()=>{
 const {auth,token}=await setup();const done={...record(4),state:'ended'};
 await auth.fetch(req(token,{action:'save',record:done}));
 await auth.fetch(req(token,{action:'save',record:{...done,state:'interrupted',endedAt:done.endedAt-100,preview:'data:image/jpeg;base64,/9j/wAARCACQAQADASIAAhEBAxEB/9oADAMBAAIRAxEAPwD/2Q==',previewConsent:true}}));
 const row=(await(await auth.fetch(req(token))).json()).items[0];assert.equal(row.state,'ended');assert.equal(row.endedAt,done.endedAt);assert.ok(row.preview);
});

test('HD JPEG split below DO per-value cap, isolation, reuse and deletion remove chunks',async()=>{
 const {auth,token,otherToken,storage}=await setup();
 const preview='data:image/jpeg;base64,'+btoa(atob('/9j/wAARCACQAQADASIAAhEBAxEB/9oADAMBAAIRAxEAPwD/2Q==').slice(0,-2)+'x'.repeat(200000)+'\xff\xd9');
 assert.equal((await auth.fetch(req(token,{action:'save',record:{...record(30),preview,previewConsent:true}}))).status,200);
 assert.ok([...storage.m.entries()].filter(([k])=>k.includes(':preview:')).length>=2);
 for(const [k,v] of storage.m){if(k.startsWith('history:'))assert.ok(JSON.stringify(v).length<128*1024,k);}
 assert.equal((await(await auth.fetch(req(token))).json()).items[0].preview,preview);
 assert.equal((await(await auth.fetch(req(otherToken))).json()).items.length,0);
 await auth.fetch(req(token,{action:'save',record:record(31)}));
 assert.equal((await(await auth.fetch(req(token))).json()).items[0].preview,preview);
 await auth.fetch(req(token,{action:'delete-device',deviceId:'123456789'}));
 assert.equal([...storage.m.keys()].some(k=>k.includes(':preview:')),false);
});

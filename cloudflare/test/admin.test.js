import test, {afterEach} from 'node:test';
import assert from 'node:assert/strict';
import {handleAdmin} from '../src/admin.js';
import {signJwt,verifyJwt} from '../src/auth.js';
import {AuthStore} from '../src/authstore.js';
const secret='admin-unit-test-secret', email='admin@example.com';
const configBinding={idFromName:n=>n,get:()=>({fetch:async()=>Response.json({passwordEnabled:false,setupAvailable:true})})};
const base={AUTH_STORE:configBinding,AUTH_SECRET:secret,ADMIN_EMAILS:email,ADMIN_GOOGLE_CLIENT_ID:'admin-google-test-client',GOOGLE_CLIENT_ID:'web-google-test-client',TURNSTILE_SECRET:'captcha-test-secret'};
const originalFetch=globalThis.fetch;
afterEach(()=>{globalThis.fetch=originalFetch});
const binding=fn=>({idFromName:n=>n,get:()=>({fetch:req=>new URL(req.url).pathname==='/admin/security/config'?Promise.resolve(Response.json({passwordEnabled:false,setupAvailable:true})):fn(req)})});
async function call(path, {body,env={},claims={email,role:'admin',aud:'xydesk-admin'},anonymous=false}={}) {
  const headers={Origin:'https://admin.xydesk.my.id'};
  if(!anonymous)headers.Authorization=`Bearer ${await signJwt(claims,secret,60)}`;
  const request=new Request(`https://signal.example/admin/${path}`,{method:body!==undefined?'POST':'GET',headers,body:body!==undefined?JSON.stringify(body):undefined});
  return handleAdmin(request,{...base,...env},new URL(request.url));
}
const captcha=()=>Response.json({success:true,hostname:'admin.xydesk.my.id'});
test('login menolak base64 email walaupun captcha lolos',async()=>{
  globalThis.fetch=async()=>captcha();
  assert.equal((await call('login',{anonymous:true,body:{googleIdToken:btoa(JSON.stringify({email})),turnstileToken:'valid'}})).status,401);
});
test('login gagal tertutup tanpa secret captcha',async()=>{
  assert.equal((await call('login',{anonymous:true,env:{TURNSTILE_SECRET:''},body:{googleIdToken:'fake',turnstileToken:'fake'}})).status,503);
});
test('token captcha fake tidak melewati siteverify',async()=>{
  globalThis.fetch=async()=>{throw Error('must not fetch')};
  assert.equal((await call('login',{anonymous:true,body:{googleIdToken:'bad',turnstileToken:'fake123'}})).status,403);
});
for(const result of [{success:false},{success:true,hostname:'evil.example'}])test(`captcha ditolak: ${JSON.stringify(result)}`,async()=>{
  globalThis.fetch=async()=>Response.json(result);
  assert.equal((await call('login',{anonymous:true,body:{googleIdToken:'bad',turnstileToken:'valid'}})).status,403);
});
test('body login null ditolak 400',async()=>assert.equal((await call('login',{anonymous:true,body:null})).status,400));
for(const claims of [{email},{email,role:'admin'},{email:'other@example.com',role:'admin',aud:'xydesk-admin'},{email,role:'viewer',aud:'xydesk-admin'}])test(`JWT tidak berhak: ${JSON.stringify(claims)}`,async()=>{
  assert.equal((await call('stats',{claims})).status,401);
});
test('JWT admin tidak diterima lewat query',async()=>{
  const token=await signJwt({email,role:'admin',aud:'xydesk-admin'},secret,60);
  assert.equal((await call(`stats?token=${token}`,{anonymous:true})).status,401);
});
for (const [audience, expectedStatus] of [[base.ADMIN_GOOGLE_CLIENT_ID,200],[base.GOOGLE_CLIENT_ID,401]]) test(`Google audience ${audience}: HTTP ${expectedStatus}`,async()=>{
  const keys=await crypto.subtle.generateKey({name:'RSASSA-PKCS1-v1_5',modulusLength:2048,publicExponent:new Uint8Array([1,0,1]),hash:'SHA-256'},true,['sign','verify']);
  const jwk=await crypto.subtle.exportKey('jwk',keys.publicKey);jwk.kid='admin-test';
  const enc=v=>Buffer.from(JSON.stringify(v)).toString('base64url');
  const data=`${enc({alg:'RS256',kid:jwk.kid})}.${enc({email,email_verified:true,sub:'google-sub',aud:audience,iss:'https://accounts.google.com',exp:Math.floor(Date.now()/1000)+60})}`;
  const sig=await crypto.subtle.sign('RSASSA-PKCS1-v1_5',keys.privateKey,new TextEncoder().encode(data));
  globalThis.fetch=async url=>String(url).includes('siteverify')?captcha():Response.json({keys:[jwk]});
  const r=await call('login',{anonymous:true,body:{googleIdToken:`${data}.${Buffer.from(sig).toString('base64url')}`,turnstileToken:'valid'}});
  assert.equal(r.status,expectedStatus);
  if(expectedStatus!==200){ assert.equal((await r.json()).error,'bad-audience');return }
  const session=await r.json();const payload=await verifyJwt(session.token,secret);
  assert.equal(payload.aud,'xydesk-admin');assert.equal(payload.email,email);assert.equal(payload.exp-payload.iat,3600);
  assert.equal(r.headers.get('cache-control'),'no-store');
});
for(const anonymous of [true,false])test(`maintenance GET galat upstream, public=${anonymous}`,async()=>{
  assert.equal((await call('maintenance',{anonymous,env:{AUTH_STORE:binding(async()=>new Response('',{status:500}))}})).status,503);
});
for(const status of [500,409])test(`maintenance POST meneruskan kegagalan ${status}`,async()=>{
  assert.equal((await call('maintenance',{body:{service:'web',enabled:true},env:{AUTH_STORE:binding(async()=>Response.json({error:'failed'},{status}))}})).status,status===409?409:503);
});
for(const body of [null,{service:'web',enabled:'false'},{services:{web:true}},{service:'web',enabled:true,message:123}])test(`maintenance invalid ${JSON.stringify(body)}`,async()=>{
  assert.equal((await call('maintenance',{body})).status,400);
});
test('stats tidak mengubah upstream gagal menjadi nol',async()=>{
  assert.equal((await call('stats',{env:{AUTH_STORE:binding(async()=>new Response('',{status:503}))}})).status,503);
});
test('metrik belum diukur null, angka Hub dipertahankan',async()=>{
  const r=await call('stats',{env:{AUTH_STORE:binding(async()=>Response.json({totalUsers:2,guest:1})),HUB:binding(async()=>Response.json({onlineDevices:3,onlineClients:4,totalSockets:7,devices:[]}))}});
  assert.equal(r.status,200);const s=await r.json();assert.equal(s.totalUsers,2);assert.equal(s.onlineDevices,3);assert.equal(s.mau,null);assert.equal(s.activeSessions,null);
});
test('health membedakan Hub gagal dari storage tersedia',async()=>{
  const r=await call('health',{env:{AUTH_STORE:binding(async()=>Response.json({ok:true})),HUB:binding(async()=>{throw Error('offline')})}});
  const s=await r.json();assert.equal(s.authStore.status,'ok');assert.equal(s.hub.status,'unavailable');assert.equal(s.engine.status,'unavailable');
});
test('purge belum terhubung tidak mengaku sukses',async()=>assert.equal((await call('hosting/purge',{body:{}})).status,501));
function memoryStore(){
  const values=new Map();let queue=Promise.resolve();
  return {values,get:async k=>structuredClone(values.get(k)),transaction(fn){
    const run=queue.then(async()=>{
      const snapshot=structuredClone(values);
      const txn={get:async k=>snapshot.get(k),put:async(k,v)=>snapshot.set(k,structuredClone(v))};
      const result=await fn(txn);values.clear();for(const [k,v] of snapshot)values.set(k,v);return result;
    });queue=run.catch(()=>{});return run;
  }};
}
const internalRequest=body=>new Request('https://internal/admin/maintenance',{method:'POST',headers:{'x-internal-admin':'1'},body:JSON.stringify(body)});
test('maintenance batch atomik, revision basi ditolak',async()=>{
  const storage=memoryStore();const store=new AuthStore({storage},base);
  const body={services:{web:true,desktop:false,android:true,signal:false},message:'Perawatan',revision:0,by:email};
  const responses=await Promise.all([store.fetch(internalRequest(body)),store.fetch(internalRequest({...body,message:'stale'}))]);
  assert.deepEqual(responses.map(r=>r.status),[200,409]);
  const state=await storage.get('admin:maintenance');assert.equal(state.message,'Perawatan');assert.equal(state.revision,1);assert.equal(storage.values.size,2);
});
test('patch legacy tidak menimpa flag layanan lain',async()=>{
  const storage=memoryStore();const store=new AuthStore({storage},base);
  await store.fetch(internalRequest({service:'web',enabled:true,by:email}));
  await store.fetch(internalRequest({service:'signal',enabled:true,by:email}));
  const state=await storage.get('admin:maintenance');assert.equal(state.web,true);assert.equal(state.signal,true);assert.equal(state.revision,2);
});

test('storage gagal ditulis tidak menghasilkan sukses endpoint', async()=>{
  const store=new AuthStore({storage:{transaction:async()=>{throw new Error('disk unavailable')}}},base);
  const r=await call('maintenance',{body:{service:'web',enabled:true},env:{AUTH_STORE:binding(req=>store.fetch(req))}});
  assert.equal(r.status,503);
});
test('public maintenance tidak membocorkan identitas pengubah',async()=>{
  const r=await call('maintenance',{anonymous:true,env:{AUTH_STORE:binding(async()=>Response.json({web:true,desktop:false,android:false,signal:false,message:'Perawatan',revision:2,by:email}))}});
  assert.equal((await r.json()).by,undefined);
});

test('client web tidak menjadi fallback jika client admin belum dikonfigurasi',async()=>{
  assert.equal((await call('login',{anonymous:true,env:{ADMIN_GOOGLE_CLIENT_ID:''},body:{googleIdToken:'token',turnstileToken:'captcha'}})).status,503);
});

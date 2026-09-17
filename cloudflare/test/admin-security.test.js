import test from 'node:test';
import assert from 'node:assert/strict';
import { AdminSecurity, base32, totp, passwordHash } from '../src/admin_security.js';
import { handleAdmin } from '../src/admin.js';
import { signJwt } from '../src/auth.js';

const email='owner@example.com', password='A-long-unique-password-2026!';
const key='test-only-admin-encryption-key-32-bytes-long';
function memory(){
  const values=new Map();let queue=Promise.resolve();
  const clone=v=>v===undefined?v:structuredClone(v);
  return {values,get:async k=>clone(values.get(k)),put:async(k,v)=>values.set(k,clone(v)),delete:async k=>values.delete(k),transaction(fn){
    const run=queue.then(async()=>{const next=structuredClone(values);const txn={get:async k=>clone(next.get(k)),put:async(k,v)=>next.set(k,clone(v)),delete:async k=>next.delete(k)};const r=await fn(txn);values.clear();for(const [k,v]of next)values.set(k,v);return r});queue=run.catch(()=>{});return run;
  }};
}
async function setup(){
  const storage=memory(),service=new AdminSecurity(storage,{ADMIN_AUTH_KEY:key});
  const start=await service.fetch('setup/start',{actor:email,username:'owner',password});assert.equal(start.status,200);const enrollment=await start.json();
  const code=await totp(enrollment.secret,Math.floor(Date.now()/30000));
  const confirm=await service.fetch('setup/confirm',{actor:email,code});assert.equal(confirm.status,200);
  return {storage,service,enrollment,result:await confirm.json()};
}
test('TOTP sesuai vektor RFC6238 SHA1',async()=>{
  const secret=base32(new TextEncoder().encode('12345678901234567890'));
  for(const [seconds,expected] of [[59,'94287082'],[1111111109,'07081804'],[1111111111,'14050471'],[1234567890,'89005924'],[2000000000,'69279037'],[20000000000,'65353130']])assert.equal(await totp(secret,Math.floor(seconds/30),8),expected);
});
test('PBKDF2 memakai salt dan password berbeda menghasilkan hash berbeda',async()=>{
  const salt=btoa('1234567890123456');assert.equal(await passwordHash(password,salt),await passwordHash(password,salt));assert.notEqual(await passwordHash(password,salt),await passwordHash(password+'x',salt));assert.notEqual(await passwordHash(password,salt),await passwordHash(password,btoa('6543210987654321')));
});
test('setup belum mengalihkan Google sebelum TOTP valid; storage tanpa password/secret mentah',async()=>{
  const storage=memory(),service=new AdminSecurity(storage,{ADMIN_AUTH_KEY:key});
  const initial=await(await service.fetch('config')).json();assert.equal(initial.passwordEnabled,false);
  const start=await service.fetch('setup/start',{actor:email,username:'owner',password});const enrollment=await start.json();
  assert.equal((await(await service.fetch('config')).json()).passwordEnabled,false);
  const dump=JSON.stringify([...storage.values]);assert.equal(dump.includes(password),false);assert.equal(dump.includes(enrollment.secret),false);
  assert.equal((await service.fetch('setup/confirm',{actor:email,code:'invalid'})).status,400);
  assert.equal((await(await service.fetch('config')).json()).passwordEnabled,false);
});
for(const body of [{actor:email,username:'aa',password},{actor:email,username:'owner',password:'short'},{actor:email,username:'../owner',password}])test('setup menolak kebijakan username/password: '+body.username,async()=>{
  const s=new AdminSecurity(memory(),{ADMIN_AUTH_KEY:key});assert.equal((await s.fetch('setup/start',body)).status,400);
});
test('setup konfirmasi sekali, sesi valid, logout membatalkan sesi',async()=>{
  const {service,result,storage}=await setup();
  assert.equal((await(await service.fetch('config')).json()).passwordEnabled,true);
  assert.equal(result.recoveryCodes.length,10);assert.equal(new Set(result.recoveryCodes).size,10);
  assert.equal(JSON.stringify([...storage.values]).includes(result.token),false);
  assert.equal(JSON.stringify([...storage.values]).includes(result.recoveryCodes[0]),false);
  assert.equal((await service.fetch('session',{token:result.token})).status,200);
  assert.equal((await service.fetch('setup/start',{actor:email,username:'other',password})).status,409);
  assert.equal((await service.fetch('logout',{token:result.token})).status,200);
  assert.equal((await service.fetch('session',{token:result.token})).status,401);
});
test('password salah, username salah, dan TOTP replay ditolak',async()=>{
  const {service,enrollment}=await setup();const code=await totp(enrollment.secret,Math.floor(Date.now()/30000));
  for(const body of [{username:'owner',password:'wrong',code},{username:'stranger',password,code},{username:'owner',password,code}])assert.equal((await service.fetch('login',{...body,ip:'test-ip'})).status,401);
});
test('TOTP baru dapat login tetapi replay bersamaan hanya sekali',async()=>{
  const {service,enrollment}=await setup();const code=await totp(enrollment.secret,Math.floor(Date.now()/30000)+1);
  const body={username:'owner',password,code,ip:'ip'};
  const results=await Promise.all([service.fetch('login',body),service.fetch('login',body)]);assert.deepEqual(results.map(r=>r.status).sort(),[200,401]);
});
test('kode recovery hanya sekali, masih memerlukan password, dan aman pada konkurensi',async()=>{
  const {service,result}=await setup();const body={username:'owner',password,code:result.recoveryCodes[0],recovery:true,ip:'ip'};
  assert.equal((await service.fetch('login',{...body,password:'wrong'})).status,401);
  const results=await Promise.all([service.fetch('login',body),service.fetch('login',body)]);assert.deepEqual(results.map(r=>r.status).sort(),[200,401]);
});
test('rate limit username lintas IP',async()=>{
  const {service}=await setup();
  for(let n=0;n<5;n++)assert.equal((await service.fetch('login',{username:'owner',password:'wrong',code:'123456',ip:'ip-'+n})).status,401);
  assert.equal((await service.fetch('login',{username:'owner',password,code:'123456',ip:'different-ip'})).status,429);
});
test('session kedaluwarsa dihapus',async()=>{
  const {service,storage,result}=await setup();const [k,v]=[...storage.values].find(([k])=>k.startsWith('admin:session:'));await storage.put(k,{...v,expiresAt:0});assert.equal((await service.fetch('session',{token:result.token})).status,401);assert.equal(storage.values.has(k),false);
});
test('setup kadaluwarsa tidak mengaktifkan akun',async()=>{
  const storage=memory(),service=new AdminSecurity(storage,{ADMIN_AUTH_KEY:key});const enrollment=await(await service.fetch('setup/start',{actor:email,username:'owner',password})).json();const pending=await storage.get('admin:pending:'+email);await storage.put('admin:pending:'+email,{...pending,expires:0});assert.equal((await service.fetch('setup/confirm',{actor:email,code:await totp(enrollment.secret,Math.floor(Date.now()/30000))})).status,410);
});
function workerEnv(service){return{AUTH_SECRET:'jwt-test-key',ADMIN_AUTH_KEY:key,ADMIN_EMAILS:email,AUTH_STORE:{idFromName:n=>n,get:()=>({fetch:async req=>service.fetch(new URL(req.url).pathname.slice('/admin/security/'.length),req.method==='GET'?undefined:await req.json())})}}}
async function route(env,path,body,headers={}){
  const req=new Request('https://signal.test/admin/'+path,{method:body===undefined?'GET':'POST',headers:{Origin:'https://admin.xydesk.my.id',...headers},body:body===undefined?undefined:JSON.stringify(body)});return handleAdmin(req,env,new URL(req.url));
}
test('Google dan JWT lama ditolak setelah aktivasi; cookie hanya HttpOnly, Secure, Strict',async()=>{
  const storage=memory(),service=new AdminSecurity(storage,{ADMIN_AUTH_KEY:key}),env=workerEnv(service);
  const jwt=await signJwt({email,role:'admin',aud:'xydesk-admin'},env.AUTH_SECRET,60),auth={Authorization:'Bearer '+jwt};
  const begin=await route(env,'setup/start',{username:'owner',password},auth);assert.equal(begin.status,200);const enrollment=await begin.json();
  const confirm=await route(env,'setup/confirm',{code:await totp(enrollment.secret,Math.floor(Date.now()/30000))},auth);assert.equal(confirm.status,200);
  const body=await confirm.json();assert.equal(body.token,undefined);
  const cookie=confirm.headers.get('set-cookie');assert.match(cookie,/^__Host-xydesk_admin=/);assert.match(cookie,/HttpOnly/);assert.match(cookie,/Secure/);assert.match(cookie,/SameSite=Strict/);assert.match(cookie,/Path=\//);
  assert.equal((await route(env,'login',{})).status,410);
  assert.equal((await route(env,'session',undefined,auth)).status,401);
  assert.equal((await route(env,'session',undefined,{Cookie:cookie.split(';')[0]})).status,200);
  assert.equal(confirm.headers.get('access-control-allow-origin'),'https://admin.xydesk.my.id');assert.equal(confirm.headers.get('access-control-allow-credentials'),'true');
});
for(const origin of ['https://evil.example','https://app.xydesk.my.id','null',''])test('CSRF origin ditolak: '+origin,async()=>{
  assert.equal((await route({},'password-login',{}, {Origin:origin})).status,403);
});
test('gagal baca konfigurasi auth tidak membuka fallback Google',async()=>{
  const r=await route({AUTH_STORE:{idFromName:n=>n,get:()=>({fetch:()=>{throw Error('storage down')}})}},'login',{});assert.equal(r.status,503);
});
test('setup tidak boleh memakai JWT Google yang sudah lama',async()=>{
  const service=new AdminSecurity(memory(),{ADMIN_AUTH_KEY:key}),env=workerEnv(service);const token=await signJwt({email,role:'admin',aud:'xydesk-admin',iat:Math.floor(Date.now()/1000)-700},env.AUTH_SECRET,3600);
  // signJwt menetapkan iat sendiri, gunakan clock maju hanya untuk pengujian gate freshness.
  const original=Date.now;Date.now=()=>original()+700000;
  try{assert.equal((await route(env,'setup/start',{username:'owner',password},{Authorization:'Bearer '+token})).status,403)}finally{Date.now=original}
});

test('login recovery paralel memiliki audit terpisah pada milidetik yang sama',async()=>{
  const {service,storage,result}=await setup();const original=Date.now,now=original();Date.now=()=>now;
  try {
    const results=await Promise.all(result.recoveryCodes.slice(0,2).map(code=>service.fetch('login',{username:'owner',password,code,recovery:true,ip:'audit-ip'})));
    assert.deepEqual(results.map(r=>r.status),[200,200]);
    assert.equal([...storage.values.values()].filter(v=>v.action==='security-recovery-login').length,2);
  }finally{Date.now=original}
});

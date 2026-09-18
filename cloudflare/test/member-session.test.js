import test from 'node:test';
import assert from 'node:assert/strict';
import { AuthStore } from '../src/authstore.js';
import worker from '../src/worker.js';
import { signJwt, verifyJwt, hashOtp } from '../src/auth.js';

class Storage {
  data = new Map();
  async get(k) { return structuredClone(this.data.get(k)); }
  async put(k,v) { this.data.set(k,structuredClone(v)); }
  async delete(k) { return this.data.delete(k); }
  async transaction(fn) { return fn(this); }
}
const secret='member-session-test-only';
const base={id:'member-one',email:'member@example.test',name:'Member'};
async function setup(user=base, claims={sub:base.id,email:base.email}) {
  const storage=new Storage(); if(user) await storage.put('user:'+user.email,user);
  const env={AUTH_SECRET:secret,XYDESK_SECRET:'signal-test-only'};
  const store=new AuthStore({storage},env);
  env.AUTH_STORE={idFromName:n=>n,get:()=>({fetch:r=>store.fetch(r)})};
  const token=await signJwt(claims,secret);
  const req=(path,body)=>new Request('https://signal.example'+path,{method:body?'POST':'GET',headers:{Authorization:'Bearer '+token,'content-type':'application/json'},body:body?JSON.stringify(body):undefined});
  return {storage,store,env,token,req};
}
for(const [label,user,claims] of [
  ['banned',{...base,banned:true},{sub:base.id,email:base.email}],
  ['revoked legacy',{...base,token_version:1},{sub:base.id,email:base.email}],
  ['revoked version',{...base,token_version:2},{sub:base.id,email:base.email,ver:1}],
  ['recreated',{...base,id:'new-member'},{sub:base.id,email:base.email}],
  ['deleted',null,{sub:base.id,email:base.email}],
  ['wrong audience',base,{sub:base.id,email:base.email,aud:'xydesk-admin'}],
  ['malformed version',base,{sub:base.id,email:base.email,ver:null}],
]) test(`${label}: profile, history and new signaling ticket rejected`,async()=>{
  const x=await setup(user,claims);
  for(const path of ['/auth/me','/auth/session-history']) assert.equal((await x.store.fetch(x.req(path))).status,401,path);
  assert.equal((await worker.fetch(x.req('/signal-token?id=client-123'),x.env)).status,401);
});
for(const [label,user,claims] of [
 ['healthy legacy',base,{sub:base.id,email:base.email}],
 ['current version',{...base,token_version:2},{sub:base.id,email:base.email,ver:2,aud:'xydesk-account'}],
]) test(`${label}: no global logout`,async()=>{
 const x=await setup(user,claims);
 assert.equal((await x.store.me(x.req('/auth/me'))).status,200);
 assert.equal((await worker.fetch(x.req('/signal-token?id=client-123'),x.env)).status,200);
});
test('guest may get client ticket, never host ticket or account profile',async()=>{
 const x=await setup(null,{sub:'guest:test-guest',guest:true});
 assert.equal((await worker.fetch(x.req('/signal-token?id=client-123'),x.env)).status,200);
 assert.equal((await worker.fetch(x.req('/signal-token',{id:'123456789',role:'host',claim:'test-claim'}),x.env)).status,403);
 assert.equal((await x.store.me(x.req('/auth/me'))).status,401);
});
test('auth store unavailable fails closed',async()=>{
 const x=await setup();x.env.AUTH_STORE.get=()=>({fetch:async()=>{throw Error('unavailable')}});
 assert.equal((await worker.fetch(x.req('/signal-token?id=client-123'),x.env)).status,503);
});
test('internal authorization cannot be called without internal secret',async()=>{
 const x=await setup();assert.equal((await x.store.fetch(x.req('/auth/authorize-session',{}))).status,403);
});
test('profile write cannot restore access revoked while reading body',async()=>{
 const x=await setup();const r=x.req('/auth/profile',{name:'New name'});
 r.json=async()=>{await x.storage.put('user:'+base.email,{...base,token_version:1,banned:true});return {name:'New name'};};
 assert.equal((await x.store.updateProfile(r)).status,401);
 assert.equal((await x.storage.get('user:'+base.email)).banned,true);
});
test('OTP login issues current generation and disabled account cannot log in',async()=>{
 const x=await setup({...base,token_version:3});
 async function otp(){await x.storage.put('otp:'+base.email,{hash:await hashOtp(secret,base.email,'123456'),expires_at:Math.floor(Date.now()/1000)+600,attempts:0});return x.store.verifyOtp(x.req('/auth/verify-otp',{email:base.email,otp:'123456'}));}
 const r=await otp();assert.equal(r.status,200);const p=await verifyJwt((await r.json()).token,secret);assert.equal(p.ver,3);assert.equal(p.aud,'xydesk-account');
 await x.storage.put('user:'+base.email,{...base,token_version:3,banned:true});assert.equal((await otp()).status,403);
});

test('Google login uses current generation, preserves OAuth audience and rejects banned member',async()=>{
 const {generateKeyPairSync,sign}=await import('node:crypto');
 const {publicKey,privateKey}=generateKeyPairSync('rsa',{modulusLength:2048});
 const jwk={...publicKey.export({format:'jwk'}),kid:'member-test',alg:'RS256',use:'sig'};
 const enc=v=>Buffer.from(JSON.stringify(v)).toString('base64url');
 const h=enc({alg:'RS256',kid:'member-test'}),p=enc({aud:'existing-web-client',iss:'https://accounts.google.com',exp:Math.floor(Date.now()/1000)+300,email:base.email,email_verified:true,sub:'google-member'});
 const idToken=`${h}.${p}.${sign('RSA-SHA256',Buffer.from(h+'.'+p),privateKey).toString('base64url')}`;
 const previous=globalThis.fetch;
 try {
  globalThis.fetch=async()=>Response.json({keys:[jwk]});
  const x=await setup({...base,token_version:4});x.env.GOOGLE_CLIENT_ID='existing-web-client';
  const res=await x.store.googleWithIdToken(idToken);assert.equal(res.status,200);
  const token=(await res.json()).token;assert.equal((await verifyJwt(token,secret)).ver,4);
  await x.storage.put('user:'+base.email,{...base,token_version:4,banned:true});
  assert.equal((await x.store.googleWithIdToken(idToken)).status,403);
  x.env.GOOGLE_CLIENT_ID='different-client';assert.equal((await x.store.googleWithIdToken(idToken)).status,401);
 } finally {globalThis.fetch=previous;}
});
test('history write and delete recheck generation inside transaction',async()=>{
 const {historyEndpoint,deleteUserHistory}=await import('../src/session_history.js');const x=await setup();
 await x.storage.put('user:'+base.email,{...base,token_version:1});
 assert.equal((await historyEndpoint(x.req('/auth/session-history',{action:'clear'}),x.storage,base)).status,401);
 assert.equal(await deleteUserHistory(x.storage,base.id,base.email,0),false);
 assert.equal((await x.storage.get('user:'+base.email)).token_version,1);
});

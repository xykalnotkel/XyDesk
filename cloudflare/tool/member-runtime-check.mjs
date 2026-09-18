import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {readFileSync} from 'node:fs';
import {signJwt,verifyJwt,hashOtp} from '../src/auth.js';
const require=createRequire(import.meta.url),wr=createRequire(require.resolve('wrangler/package.json'));
const {Miniflare,convertV4MiniflareOptions}=wr('miniflare');
const bundle=readFileSync(new URL('../.wrangler/runtime-test/entry.js',import.meta.url),'utf8');
// Fixture exists only in this in-memory test bundle, never in deployed source.
const script=bundle+`\nconst realFetch=AuthStore.prototype.fetch;AuthStore.prototype.fetch=async function(req){if(new URL(req.url).pathname==='/fixture'){const {key,value}=await req.json();if(value===undefined)return Response.json(await this.ctx.storage.get(key));await this.ctx.storage.put(key,value);return Response.json({ok:true});}return realFetch.call(this,req);};`;
const secret='member-runtime-test-only',email='member-runtime@example.test';
const opts={workers:[{name:'member-runtime',modules:true,script,compatibilityDate:'2026-08-17',bindings:{AUTH_SECRET:secret,XYDESK_SECRET:'runtime-signal-secret'},durableObjects:{AUTH_STORE:{className:'AuthStore',useSQLite:true},HUB:{className:'Hub',useSQLite:true}}}]};
const mf=new Miniflare(convertV4MiniflareOptions?convertV4MiniflareOptions(opts):opts);
try {
 const ns=await mf.getDurableObjectNamespace('AUTH_STORE','member-runtime'),stub=ns.get(ns.idFromName('auth'));
 const fixture=(key,value)=>stub.fetch('https://internal/fixture',{method:'POST',body:JSON.stringify({key,value})});
 const user={id:'runtime-member',email,name:'Runtime member'};
 await fixture('user:'+email,user);
 const token=await signJwt({sub:user.id,email},secret);
 const request=path=>mf.dispatchFetch('https://signal.example'+path,{headers:{Authorization:'Bearer '+token}});
 assert.equal((await request('/signal-token?id=runtime-client')).status,200);
 assert.equal((await request('/auth/me')).status,200);
 const revoked=await Promise.all(Array.from({length:5},()=>stub.fetch('https://internal/admin/revoke',{method:'POST',headers:{'x-internal-admin':'1'},body:JSON.stringify({email})})));
 assert.ok(revoked.every(r=>r.status===200));
 assert.equal((await(await fixture('user:'+email)).json()).token_version,5);
 assert.equal((await request('/signal-token?id=runtime-client')).status,401);
 assert.equal((await request('/auth/me')).status,401);
 await fixture('otp:'+email,{hash:await hashOtp(secret,email,'123456'),expires_at:Math.floor(Date.now()/1000)+600,attempts:0});
 const otp=()=>mf.dispatchFetch('https://signal.example/auth/verify-otp',{method:'POST',body:JSON.stringify({email,otp:'123456'})});
 const logins=await Promise.all([otp(),otp()]);assert.deepEqual(logins.map(r=>r.status).sort(),[200,401]);
 const fresh=(await logins.find(r=>r.status===200).json()).token;assert.equal((await verifyJwt(fresh,secret)).ver,5);
 assert.equal((await mf.dispatchFetch('https://signal.example/signal-token?id=runtime-client',{headers:{Authorization:'Bearer '+fresh}})).status,200);
 await stub.fetch('https://internal/admin/ban',{method:'POST',headers:{'x-internal-admin':'1'},body:JSON.stringify({email})});
 assert.equal((await mf.dispatchFetch('https://signal.example/signal-token?id=runtime-client',{headers:{Authorization:'Bearer '+fresh}})).status,401);
 await fixture('otp:'+email,{hash:await hashOtp(secret,email,'123456'),expires_at:Math.floor(Date.now()/1000)+600,attempts:0});assert.equal((await otp()).status,403);
 console.log('PASS: real Worker+SQLite legacy compatibility, 5 concurrent revokes => generation5, old JWT blocked, concurrent OTP single-use, fresh login works, ban blocks fresh JWT and OTP login');
} finally {await mf.dispose();}

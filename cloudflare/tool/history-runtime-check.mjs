import assert from 'node:assert/strict';import {createRequire} from 'node:module';import {readFileSync} from 'node:fs';import {signJwt} from '../src/auth.js';
const require=createRequire(import.meta.url), wr=createRequire(require.resolve('wrangler/package.json'));const {Miniflare,convertV4MiniflareOptions}=wr('miniflare');
const bundle=readFileSync(new URL('../.wrangler/runtime-test/entry.js',import.meta.url),'utf8');
// Test-only seed hook appended to the in-memory runtime bundle, never the deploy source.
const script=bundle+`\nconst realFetch=AuthStore.prototype.fetch;AuthStore.prototype.fetch=async function(req){const path=new URL(req.url).pathname;if(path==='/fixture/seed'){const u=await req.json();await this.ctx.storage.put('user:'+u.email,u);return Response.json({ok:true});}if(path==='/fixture/keys')return Response.json([...await this.ctx.storage.list({prefix:'history:'})].map(x=>x[0]));return realFetch.call(this,req);};`;
const secret='history-runtime-local-only';const options={workers:[{name:'history-runtime',modules:true,script,compatibilityDate:'2026-08-17',bindings:{AUTH_SECRET:secret},durableObjects:{AUTH_STORE:{className:'AuthStore',useSQLite:true},HUB:{className:'Hub',useSQLite:true}}}]};
const mf=new Miniflare(convertV4MiniflareOptions?convertV4MiniflareOptions(options):options);
try{const ns=await mf.getDurableObjectNamespace('AUTH_STORE','history-runtime');const stub=ns.get(ns.idFromName('auth'));
 const user={id:'history-runtime-user',email:'history-runtime@example.test'};await stub.fetch('https://internal/fixture/seed',{method:'POST',body:JSON.stringify(user)});const token=await signJwt({sub:user.id,email:user.email},secret);
 const request=body=>stub.fetch('https://internal/auth/session-history',{method:body?'POST':'GET',headers:{Authorization:'Bearer '+token,'content-type':'application/json'},body:body?JSON.stringify(body):undefined});
 const record=n=>({id:`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`,deviceId:'123456789',name:'Runtime PC',state:'ended',startedAt:Date.now()-1000,endedAt:Date.now(),specs:{cpu:'runtime'}});
 const writes=await Promise.all(Array.from({length:21},(_,n)=>request({action:'save',record:record(n)})));assert.ok(writes.every(r=>r.status===200));const listed=await(await request()).json();assert.equal(listed.items.length,20);assert.equal(new Set(listed.items.map(x=>x.id)).size,20);
 const hd='data:image/jpeg;base64,'+btoa(atob('/9j/wAARCACQAQADASIAAhEBAxEB/9oADAMBAAIRAxEAPwD/2Q==').slice(0,-2)+'x'.repeat(200000)+'\xff\xd9');
 assert.equal((await request({action:'save',record:{...record(300),preview:hd,previewConsent:true}})).status,200);
 const hdRows=await(await request()).json();assert.equal(hdRows.items.find(x=>x.id===record(300).id).preview,hd);
 const chunkKeys=await(await stub.fetch('https://internal/fixture/keys')).json();assert.ok(chunkKeys.filter(x=>x.includes(':preview:')).length>=3);
 const pending=Array.from({length:3},(_,n)=>request({action:'save',record:record(n+100)}));const deleted=await stub.fetch('https://internal/auth/delete',{method:'POST',headers:{Authorization:'Bearer '+token}});assert.equal(deleted.status,200);await Promise.all(pending);assert.equal((await request()).status,401);const keys=await(await stub.fetch('https://internal/fixture/keys')).json();assert.equal(keys.length,0);
 console.log('PASS: real SQLite HD preview chunk roundtrip, concurrency21/retention20, account delete racing pending writes leaves zero history keys');
}finally{await mf.dispose();}

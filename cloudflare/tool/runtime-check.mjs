import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { signJwt } from '../src/auth.js';
import { totp } from '../src/admin_security.js';

// Pakai runtime yang dibawa Wrangler, tanpa dependensi produksi tambahan.
const require = createRequire(import.meta.url);
const wranglerRequire = createRequire(require.resolve('wrangler/package.json'));
const { Miniflare, convertV4MiniflareOptions } = wranglerRequire('miniflare');
const secret = 'local-runtime-test-only';
const email = 'runtime@example.com';
const options = {
  workers: [{
    name: 'runtime', modules: true,
    scriptPath: fileURLToPath(new URL('../.wrangler/runtime-test/entry.js', import.meta.url)),
    compatibilityDate: '2026-08-17',
    bindings: { AUTH_SECRET: secret, ADMIN_EMAILS: email, ADMIN_AUTH_KEY: 'runtime-admin-auth-key-at-least-32-bytes', TURNSTILE_SECRET: 'runtime-captcha' },
    outboundService: async request => new URL(request.url).hostname === 'challenges.cloudflare.com' ? Response.json({success:true,hostname:'admin.xydesk.my.id'}) : new Response('',{status:404}),
    durableObjects: {
      AUTH_STORE: { className: 'AuthStore', useSQLite: true },
      HUB: { className: 'Hub', useSQLite: true },
    },
  }],
};
const mf = new Miniflare(convertV4MiniflareOptions ? convertV4MiniflareOptions(options) : options);
try {
  const namespace = await mf.getDurableObjectNamespace('AUTH_STORE', 'runtime');
  const stub = namespace.get(namespace.idFromName('auth'));
  const read = () => stub.fetch('https://internal/admin/maintenance', { headers: { 'x-internal-admin': '1' } });
  const post = body => stub.fetch('https://internal/admin/maintenance', {
    method: 'POST', headers: { 'x-internal-admin': '1' }, body: JSON.stringify(body),
  });
  const initial = await read();
  assert.equal(initial.status, 200);
  assert.equal((await initial.json()).revision, 0);
  const body = {
    services: { web: true, desktop: false, android: true, signal: false },
    message: 'Local test', revision: 0, by: email,
  };
  const responses = await Promise.all([post(body), post({ ...body, message: 'Stale edit' })]);
  assert.deepEqual(responses.map(r => r.status).sort(), [200, 409]);
  const legacy = await post({ service: 'signal', enabled: true, by: email });
  assert.equal(legacy.status, 200);
  const state = await (await read()).json();
  assert.equal(state.web, true);
  assert.equal(state.signal, true);
  assert.equal(state.revision, 2);
  const logs = await stub.fetch('https://internal/admin/logs', { headers: { 'x-internal-admin': '1' } });
  assert.equal((await logs.json()).logs.length, 2);

  const token = await signJwt({ email, role: 'admin', aud: 'xydesk-admin' }, secret, 60);
  const health = await mf.dispatchFetch('https://local/admin/health', { headers: { Authorization: `Bearer ${token}` } });
  assert.equal(health.status, 200);
  const status = await health.json();
  assert.equal(status.authStore.status, 'ok');
  assert.equal(status.hub.status, 'ok');
  const publicState = await mf.dispatchFetch('https://local/admin/maintenance');
  assert.equal((await publicState.json()).by, undefined);
  const unauthorized = await mf.dispatchFetch('https://local/admin/health');
  assert.equal(unauthorized.status, 401);
  const headers={Authorization:`Bearer ${token}`,Origin:'https://admin.xydesk.my.id','content-type':'application/json'};
  const setup=await mf.dispatchFetch('https://local/admin/setup/start',{method:'POST',headers,body:JSON.stringify({username:'runtime-owner',password:'Runtime-password-long-and-unique!'})});
  assert.equal(setup.status,200);const enrollment=await setup.json();
  const code=await totp(enrollment.secret,Math.floor(Date.now()/30000));
  const activated=await mf.dispatchFetch('https://local/admin/setup/confirm',{method:'POST',headers,body:JSON.stringify({code})});
  assert.equal(activated.status,200);assert.match(activated.headers.get('set-cookie'),/HttpOnly/);
  const setupResult=await activated.json();assert.equal(setupResult.token,undefined);assert.equal(setupResult.recoveryCodes.length,10);
  const authConfig=await mf.dispatchFetch('https://local/admin/auth/config');assert.equal((await authConfig.json()).passwordEnabled,true);
  const legacySession=await mf.dispatchFetch('https://local/admin/session',{headers});assert.equal(legacySession.status,401);
  const passwordLogin=await mf.dispatchFetch('https://local/admin/password-login',{method:'POST',headers:{Origin:'https://admin.xydesk.my.id','content-type':'application/json'},body:JSON.stringify({username:'runtime-owner',password:'Runtime-password-long-and-unique!',code:setupResult.recoveryCodes[0],recovery:true,turnstileToken:'local-test-token'})});
  assert.equal(passwordLogin.status,200);const cookie=passwordLogin.headers.get('set-cookie').split(';')[0];
  const session=await mf.dispatchFetch('https://local/admin/session',{headers:{Cookie:cookie}});assert.equal(session.status,200);
  const logout=await mf.dispatchFetch('https://local/admin/logout',{method:'POST',headers:{Origin:'https://admin.xydesk.my.id',Cookie:cookie}});assert.equal(logout.status,200);
  const afterLogout=await mf.dispatchFetch('https://local/admin/session',{headers:{Cookie:cookie}});assert.equal(afterLogout.status,401);
  console.log('Runtime auth: setup+TOTP, pemutusan Google/JWT lama, password+recovery sekali pakai, cookie session, logout lolos; captcha ditirukan hanya dalam tes lokal.');
  console.log('Runtime SQLite: batch + konflik konkurensi + patch legacy + audit + health + pembatasan akses lolos.');
} finally {
  await mf.dispose();
}

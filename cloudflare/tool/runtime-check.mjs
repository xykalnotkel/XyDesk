import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { signJwt } from '../src/auth.js';

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
    bindings: { AUTH_SECRET: secret, ADMIN_EMAILS: email },
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
  console.log('Runtime SQLite: batch + konflik konkurensi + patch legacy + audit + health + pembatasan akses lolos.');
} finally {
  await mf.dispose();
}

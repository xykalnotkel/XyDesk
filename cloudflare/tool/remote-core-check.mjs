// Uji lintas runtime lokal: Worker + SQLite Hub → binary host Rust → Chromium.
// Tidak memakai kredensial produksi. Video Linux adalah pola uji, bukan DXGI.
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { mkdtemp, mkdir, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';

const require = createRequire(import.meta.url);
const wranglerRequire = createRequire(require.resolve('wrangler/package.json'));
const { Miniflare, convertV4MiniflareOptions } = wranglerRequire('miniflare');
const { build } = wranglerRequire('esbuild');
const { chromium } = createRequire(new URL('../../web/e2e/package.json', import.meta.url))('playwright');
const root = fileURLToPath(new URL('../../', import.meta.url));
const work = await mkdtemp(join(tmpdir(), 'xydesk-remote-test-'));
const artifacts = resolve(process.env.REMOTE_REPORT_DIR || join(work, 'report'));
await mkdir(artifacts, { recursive: true });
const hostId = '100200300';
const password = 'LocalPairFixture73';
const secret = 'local-remote-core-test-not-production';
let mf, browser, host, page, clientBundle = '', hostOutput = '';
const errors = [];
const report = { testedAt: new Date().toISOString(), environment: 'Linux synthetic capture → Rust OpenH264 → WebRTC → Chromium; local Worker + SQLite', checks: [] };
const server = createServer((_req, res) => {
  res.setHeader('content-type', 'text/html; charset=utf-8');
  res.end(`<!doctype html><html lang="id"><meta charset="utf-8"><title>Uji media XyDesk</title>
<style>body{font:16px system-ui;background:#f5f3fa;color:#272237;padding:28px}video{width:640px;max-width:100%;background:#111;border-radius:12px}p{max-width:700px}</style>
<h1>Uji media XyDesk — lokal</h1><p>Host Rust Linux • pola uji OpenH264, bukan tangkapan desktop Windows. Signaling memakai Worker dan Hub SQLite asli.</p>
<video id="video" autoplay muted playsinline></video><pre id="state"></pre><script type="module">${clientBundle}</script></html>`);
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const origin = `http://127.0.0.1:${server.address().port}`;

async function until(check, label, ms = 15000) {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    if (await check()) return;
    await delay(100);
  }
  throw new Error(`Timeout: ${label}`);
}

try {
  const workerPath = join(work, 'worker.mjs');
  await build({ entryPoints: [join(root, 'cloudflare/src/entry.js')], bundle: true, format: 'esm', platform: 'neutral', outfile: workerPath });
  const options = { port: 0, host: '127.0.0.1', workers: [{
    name: 'remote-test', modules: true, modulesRoot: work, scriptPath: workerPath, compatibilityDate: '2026-08-17',
    bindings: { AUTH_SECRET: secret, XYDESK_SECRET: secret, CORS_ORIGINS: origin },
    outboundService: () => new Response('external services disabled in local test', { status: 503 }),
    durableObjects: { AUTH_STORE: { className: 'AuthStore', useSQLite: true }, HUB: { className: 'Hub', useSQLite: true } },
  }] };
  mf = new Miniflare(convertV4MiniflareOptions ? convertV4MiniflareOptions(options) : options);
  const base = String(await mf.ready).replace(/\/$/, '');
  const wsBase = base.replace('http:', 'ws:') + '/ws';
  const hostResponse = await fetch(`${base}/host-token`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ id: hostId, claim: password }) });
  assert.equal(hostResponse.status, 200, 'registrasi host melalui TOFU');
  const hostToken = await hostResponse.text();
  report.checks.push('host-token: registrasi perangkat baru melalui AuthStore');
  await writeFile(join(work, 'password'), password);
  host = spawn(process.env.XYDESK_TEST_HOST || join(root, 'host/target/debug/xydesk-host'), ['--id', hostId, '--url', wsBase, '--token', hostToken, '--stun', ''], {
    env: { ...process.env, XYDESK_HOME: work }, stdio: ['ignore', 'pipe', 'pipe'],
  });
  host.on('error', error => errors.push(error.message));
  host.stdout.on('data', data => { hostOutput += data; });
  host.stderr.on('data', data => { hostOutput += data; });
  await until(() => hostOutput.includes(`terdaftar sebagai ${hostId}`), 'host terdaftar di Hub');
  const control = /\[control\] (http:\/\/127\.0\.0\.1:\d+) token=(\S+)/.exec(hostOutput);
  assert.ok(control, 'control API tersedia');
  const status = async () => {
    const res = await fetch(`${control[1]}/status`, { headers: { 'x-xydesk-token': control[2] } });
    assert.equal(res.status, 200);
    return res.json();
  };
  const built = await build({
    stdin: { contents: `import { RtcSession, InputCodec } from './web/src/rtc.ts';
import { createGuestSession } from './web/src/api.ts';
window.phases = [];
window.connect = async (pin) => {
  window.session?.stop();
  const s = new RtcSession(); window.session = s;
  s.onPhase = p => { window.phases.push(p); document.querySelector('#state').textContent = p; };
  s.onTrack = stream => { document.querySelector('video').srcObject = stream; };
  const {token} = await createGuestSession();
  await s.start(token, '${hostId}', pin);
};
window.snapshot = async () => {
  const s = window.session, v = document.querySelector('video');
  const reports = s?.pc ? [...(await s.pc.getStats()).values()] : [];
  const video = reports.find(x => x.type === 'inbound-rtp' && x.kind === 'video');
  const codec = reports.find(x => x.id === video?.codecId);
  const transport = reports.find(x => x.type === 'transport' && x.selectedCandidatePairId);
  const pair = reports.find(x => x.id === transport?.selectedCandidatePairId);
  const local = reports.find(x => x.id === pair?.localCandidateId);
  const remote = reports.find(x => x.id === pair?.remoteCandidateId);
  const canvas = document.createElement('canvas'); canvas.width = 80; canvas.height = 45;
  const ctx = canvas.getContext('2d');
  if (v.videoWidth) ctx.drawImage(v, 0, 0, 80, 45);
  const colors = new Set(); const pixels = ctx.getImageData(0,0,80,45).data;
  for(let i=0;i<pixels.length;i+=4) colors.add(pixels[i]+','+pixels[i+1]+','+pixels[i+2]);
  return { framesDecoded: video?.framesDecoded ?? 0, width: v.videoWidth, height: v.videoHeight, colors: colors.size,
    codec: codec?.mimeType, candidates: { local: local?.candidateType, remote: remote?.candidateType }, connection: s?.pc?.connectionState, input: s?.input?.readyState, phase: window.phases.at(-1) };
};
window.sendControl = () => { window.session.setBitrate(3); window.session.sendInput(InputCodec.mouseMoveAbs(.4,.6)); window.session.sendInput(InputCodec.key(65,true)); window.session.sendInput(InputCodec.key(65,false)); };
`, resolveDir: root, sourcefile: 'remote-test-entry.ts', loader: 'ts' },
    bundle: true, format: 'esm', platform: 'browser', write: false,
    define: { 'import.meta.env': JSON.stringify({ DEV: false, VITE_SIGNAL_API: base, VITE_SIGNAL_WS: wsBase }) },
  });
  clientBundle = built.outputFiles[0].text;
  browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  page = await browser.newPage({ viewport: { width: 960, height: 650 } });
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(origin);
  await page.evaluate(pin => window.connect(pin), 'WrongFixturePassword');
  await page.waitForFunction(() => window.phases.at(-1) === 'rejected');
  assert.equal((await status()).session, null);
  report.checks.push('password salah ditolak, tanpa sesi media');
  await page.evaluate(pin => window.connect(pin), password);
  await until(async () => (await page.evaluate(() => window.snapshot())).framesDecoded >= 5, 'Chromium mendecode lima frame H264', 25000);
  const snapshot = await page.evaluate(() => window.snapshot());
  report.video = snapshot;
  assert.equal(snapshot.codec?.toLowerCase(), 'video/h264');
  assert.deepEqual(snapshot.candidates, { local: 'host', remote: 'host' }, 'uji ini memakai jalur direct lokal, bukan bukti TURN');
  assert.ok(snapshot.width > 0 && snapshot.height > 0 && snapshot.colors > 10);
  await page.waitForFunction(() => window.session.input?.readyState === 'open');
  await page.evaluate(() => window.sendControl());
  await until(async () => (await status()).targetBitrateBps === 3000000, 'input data channel mengubah bitrate host');
  report.video = snapshot;
  report.checks.push('pairing benar → offer/answer + ICE → H264 ter-decode dan dirender', 'input biner browser → decoder host → bitrate berubah ke 3 Mbps');
  report.limitations = ['mouse/key dikirim tetapi Injector Linux no-op; SendInput Windows belum dibuktikan', 'TURN/internet, DXGI/NVENC, Android, audio, 30 menit dan glass-to-glass belum diuji'];
  await page.screenshot({ path: join(artifacts, 'remote-core-local.png') });
  const hub = await mf.getDurableObjectNamespace('HUB', 'remote-test');
  const stub = hub.get(hub.idFromName('global'));
  const kick = await stub.fetch('https://internal/kick', { method: 'POST', body: JSON.stringify({ id: hostId, by: 'local-test' }) });
  assert.equal(kick.status, 200);
  await until(async () => (await status()).session === null, 'kick host benar-benar menghapus sesi media', 1800);
  await delay(300);
  const stoppedAt = (await page.evaluate(() => window.snapshot())).framesDecoded;
  await delay(500);
  assert.equal((await page.evaluate(() => window.snapshot())).framesDecoded, stoppedAt, 'frame berhenti sesudah kick, bukan hanya status berubah');
  report.checks.push('kick Hub menutup sesi host dan menghentikan frame video');
  await until(() => hostOutput.split(`terdaftar sebagai ${hostId}`).length >= 3, 'host mendaftar ulang setelah kick');
  await page.evaluate(pin => window.connect(pin), password);
  await until(async () => (await page.evaluate(() => window.snapshot())).framesDecoded >= 5, 'pairing ulang sesudah kick');
  report.checks.push('host dapat pairing dan streaming lagi setelah signaling tersambung ulang');
  // Client sengaja mengabaikan onclose: pencabutan tidak boleh bergantung
  // pada kebaikan client untuk menutup koneksi P2P sendiri.
  const clientId = await page.evaluate(() => {
    window.session.ws.onclose = null;
    return window.session.deviceId;
  });
  const kickedClient = await stub.fetch('https://internal/kick', { method: 'POST', body: JSON.stringify({ id: clientId, by: 'local-test' }) });
  assert.equal(kickedClient.status, 200);
  await until(async () => (await status()).session === null, 'kick client mencabut media di host', 1800);
  await delay(300);
  const finalFrames = (await page.evaluate(() => window.snapshot())).framesDecoded;
  await delay(500);
  assert.equal((await page.evaluate(() => window.snapshot())).framesDecoded, finalFrames);
  report.checks.push('kick client yang mengabaikan close tetap menghentikan media di host');
  await page.evaluate(pin => window.connect(pin), password);
  await until(async () => (await page.evaluate(() => window.snapshot())).framesDecoded >= 5, 'sesi berikutnya setelah kick client');
  await page.evaluate(() => window.session.stop());
  await until(async () => (await status()).session === null, 'stop browser mengirim bye dan membebaskan host', 1800);
  report.checks.push('putus manual client membebaskan slot host tanpa menunggu ICE timeout');

  assert.deepEqual(errors, []);
  report.result = 'PASS';
} catch (error) {
  report.result = 'FAIL';
  report.error = error.message;
  report.diagnostic = page ? await page.evaluate(() => window.snapshot?.()).catch(() => null) : null;
  report.host = hostOutput.split('\n').filter(line => /^\[xydesk-host\]|^Error:/.test(line));
  report.browserErrors = errors;
  process.exitCode = 1;
} finally {
  await writeFile(join(artifacts, 'remote-core-local.json'), JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify(report, null, 2));
  await browser?.close();
  if (host && host.exitCode === null) {
    host.kill('SIGTERM');
    await new Promise(resolve => host.once('exit', resolve));
  }
  await mf?.dispose();
  await new Promise(resolve => server.close(resolve));
  // Artefak default berada di work; hanya hapus fixture bila laporan disimpan di luar.
  if (!artifacts.startsWith(work + '/')) await rm(work, { recursive: true, force: true });
}

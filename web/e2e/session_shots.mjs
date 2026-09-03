// Harness uji E2E lokal untuk layar sesi web.
//
// Menyusun tumpukan penuh di mesin lokal TANPA host Windows:
//   1. Shim auth :8787  — /auth/guest + /signal-token dengan skema token
//      yang sama dengan signaling/auth.go (ts.purpose.sig, HMAC-SHA256).
//   2. Host pola uji   — tab Chromium kedua: canvas beranimasi → H264 beneran
//      (encoder Chrome) → WebRTC answer. Cermin perilaku `pola uji` host Rust
//      di Linux (host/src/screen.rs) untuk pengujian tanpa DXGI.
//   3. Client           — build rilis (vite preview) yang dijalankan Playwright.
//
// Hasil: screenshot asli UI sesi web dengan video yang benar-benar ter-decode.
// Jalankan:
//   XYDESK_SECRET=... node session_shots.mjs http://localhost:4173
import { createHmac } from 'node:crypto';
import { createServer } from 'node:http';
import { readFileSync } from 'node:fs';
import { mkdirSync } from 'node:fs';
import { chromium } from 'playwright';

const SECRET =
  process.env.XYDESK_SECRET ??
  (() => {
    try {
      return readFileSync('/tmp/xydesk-secret.txt', 'utf8').trim().replace(/^SECRET=/, '');
    } catch {
      return '';
    }
  })();
if (!SECRET) {
  console.error('XYDESK_SECRET kosong — jalankan signaling dengan secret lalu set env.');
  process.exit(1);
}

const APP_URL = process.argv[2] ?? 'http://localhost:4173/connect';
const SIGNAL_WS = process.env.SIGNAL_WS ?? 'ws://localhost:8080/ws';
const SHIM_PORT = Number(process.env.SHIM_PORT ?? 8787);
const HOST_ID = '873649125';
const PIN = '740913';
const OUT = new URL('./shots/', import.meta.url).pathname;

// ── Token: ts.purpose.sig — format identik auth.go / Worker ──
function issue(purpose, role) {
  const ts = Math.floor(Date.now() / 1000);
  const sig = createHmac('sha256', SECRET)
    .update(`${purpose}\0${role}\0${ts}`)
    .digest('hex');
  return `${ts}.${purpose}.${sig}`;
}

// ── Shim auth (cukup dua endpoint yang dipakai tamu) ──
const shim = createServer((req, res) => {
  const json = (code, body) => {
    res.writeHead(code, {
      'content-type': 'application/json',
      'access-control-allow-origin': '*',
      'access-control-allow-methods': 'GET, POST, OPTIONS',
      'access-control-allow-headers': 'content-type, authorization',
    });
    res.end(body === '' ? '' : JSON.stringify(body));
  };
  if (req.method === 'OPTIONS') return json(204, '');
  if (req.method === 'POST' && req.url === '/auth/guest') {
    return json(200, { token: `e2e-${Date.now()}`, guest: true });
  }
  if (req.method === 'GET' && req.url.startsWith('/signal-token')) {
    const id = new URL(req.url, 'http://x').searchParams.get('id') ?? 'client';
    res.writeHead(200, {
      'content-type': 'text/plain',
      'access-control-allow-origin': '*',
      'access-control-allow-methods': 'GET, POST, OPTIONS',
      'access-control-allow-headers': 'content-type, authorization',
    });
    return res.end(issue(id, 'client'));
  }
  json(404, { error: 'not-found' });
});
await new Promise((r) => shim.listen(SHIM_PORT, '127.0.0.1', r));
console.log(`shim auth siap di :${SHIM_PORT}`);

mkdirSync(OUT, { recursive: true });

// Skrip yang disuntik ke tab "host pola uji".
const FAKE_HOST = `
(async () => {
  const HOST_ID = ${JSON.stringify(HOST_ID)};
  const TOKEN = ${JSON.stringify(issue(HOST_ID, 'host'))};
  const WS_URL = ${JSON.stringify(SIGNAL_WS)};
  const ws = new WebSocket(WS_URL + '?id=' + HOST_ID + '&role=host&token=' + encodeURIComponent(TOKEN));
  const send = (m) => ws.readyState === 1 && ws.send(JSON.stringify(m));
  window.__hostLog = [];
  const log = (s) => window.__hostLog.push(s);

  // Pola uji beranimasi: gradien ungu + bar berjalan + jam.
  const canvas = document.createElement('canvas');
  canvas.width = 1920; canvas.height = 1080;
  const ctx = canvas.getContext('2d');
  const draw = (t) => {
    const g = ctx.createLinearGradient(0, 0, 1920, 1080);
    g.addColorStop(0, '#1c1233'); g.addColorStop(1, '#0d0716');
    ctx.fillStyle = g; ctx.fillRect(0, 0, 1920, 1080);
    for (let i = 0; i < 12; i++) {
      const x = ((t * 0.05) + i * 190) % 2400 - 120;
      ctx.fillStyle = 'rgba(124, 58, 237, 0.22)';
      ctx.fillRect(x, 0, 80, 1080);
    }
    ctx.fillStyle = '#d6c6ff'; ctx.textAlign = 'center';
    ctx.font = '700 96px system-ui';
    ctx.fillText('XyDesk — Pola Uji', 960, 470);
    ctx.font = '500 58px system-ui'; ctx.fillStyle = '#a78bfa';
    ctx.fillText(new Date().toLocaleTimeString('id-ID'), 960, 570);
    ctx.font = '500 38px system-ui'; ctx.fillStyle = 'rgba(214,198,255,0.55)';
    ctx.fillText('host pola uji e2e — bukan layar asli', 960, 650);
    requestAnimationFrame(draw);
  };
  requestAnimationFrame(draw);
  const stream = canvas.captureStream(30);

  // Nada 220 Hz pelan — menguji jalur audio tanpa speaker nyata.
  const actx = new AudioContext();
  const dest = actx.createMediaStreamDestination();
  const osc = actx.createOscillator();
  const gain = actx.createGain();
  osc.frequency.value = 220; gain.gain.value = 0.03;
  osc.connect(gain); gain.connect(dest); osc.start();
  stream.addTrack(dest.stream.getAudioTracks()[0]);

  let pc = null;
  ws.onopen = () => { send({ type: 'hello', to: HOST_ID, reason: 'pola-uji-e2e' }); log('hello'); };
  ws.onmessage = async (ev) => {
    const m = JSON.parse(ev.data);
    if (m.type === 'pair') { send({ type: 'pair-response', to: m.from, accepted: true }); log('pair→' + m.from); }
    if (m.type === 'offer') {
      log('offer');
      pc = new RTCPeerConnection({});
      for (const t of stream.getTracks()) pc.addTrack(t, stream);
      pc.onicecandidate = (e) => { if (e.candidate) send({ type: 'ice', to: m.from, candidate: { candidate: e.candidate.candidate, sdpMid: e.candidate.sdpMid, sdpMLineIndex: e.candidate.sdpMLineIndex } }); };
      pc.ondatachannel = (e) => {
        const ch = e.channel;
        log('datachannel:' + ch.label);
        ch.onopen = () => ch.send(JSON.stringify({
          type: 'meta',
          displays: [
            { index: 0, name: 'Pola Uji', width: 1920, height: 1080 },
            { index: 1, name: 'Uji Kedua', width: 1280, height: 720 },
          ],
          wanted: 0,
          audio: { available: true, pipeline: 'pola-uji-osc' },
        }));
        ch.onmessage = (ev2) => {
          if (ev2.data instanceof ArrayBuffer) {
            const b = new Uint8Array(ev2.data);
            if (b[0] === 0x09) {
              const txt = new TextEncoder().encode('Teks papan klip dari host pola uji XyDesk.');
              const r = new Uint8Array(1 + txt.length);
              r[0] = 0x08; r.set(txt, 1);
              ch.send(r.buffer);
              log('clipboard-req dijawab');
            }
          }
        };
      };
      await pc.setRemoteDescription({ type: 'offer', sdp: m.sdp.sdp });
      const ans = await pc.createAnswer();
      await pc.setLocalDescription(ans);
      send({ type: 'answer', to: m.from, sdp: { type: 'answer', sdp: ans.sdp } });
      log('answer terkirim');
    }
    if (m.type === 'ice' && pc && m.candidate) {
      try { await pc.addIceCandidate({ candidate: m.candidate.candidate, sdpMid: m.candidate.sdpMid, sdpMLineIndex: m.candidate.sdpMLineIndex }); } catch {}
    }
    if (m.type === 'bye') { pc && pc.close(); ws.close(); }
  };
  return new Promise((res) => { ws.onclose = () => res('closed'); });
})();
`;

const browser = await chromium.launch({
  args: [
    '--autoplay-policy=no-user-gesture-required',
    '--use-fake-ui-for-media-stream',
    '--use-fake-device-for-media-stream',
  ],
});
const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });

// Tab 1: host pola uji — halaman origin nyata sebagai pembawa media
// (about:blank tidak boleh membuka WebSocket di Chromium).
const hostPage = await ctx.newPage();
hostPage.on('pageerror', (e) => console.log('[host-err]', e.message));
await hostPage.goto(new URL('/', APP_URL).href, { waitUntil: 'domcontentloaded' });
await hostPage.addScriptTag({ content: FAKE_HOST });
await hostPage.waitForTimeout(700); // hello terdaftar dulu sebelum client pair

// Tab 2: client = build rilis yang mau diuji.
const app = await ctx.newPage();
app.on('console', (m) => { if (m.type() === 'error') console.log('[app-error]', m.text()); });
await app.goto(APP_URL, { waitUntil: 'networkidle' });

const shot = (name) => app.screenshot({ path: `${OUT}/${name}.jpg`, type: 'jpeg', quality: 82 });

// Isi form koneksi.
await app.fill('input.host-id', HOST_ID.replace(/(\d{3})(?=\d)/g, '$1 ').trim());
await app.fill('input[type="password"]', PIN);
await app.click('button.connect-cta');
console.log('menghubungkan…');

// Debug fase: kalau 8 detik belum live, cetak status + log host lalu lanjut menunggu.
void (async () => {
  await app.waitForTimeout(8000);
  if (!(await app.locator('.srail').isVisible().catch(() => false))) {
    const status = await app.locator('.status-text').allTextContents().catch(() => []);
    console.log('[debug] status:', JSON.stringify(status));
    console.log('[debug] hostLog:', JSON.stringify(await hostPage.evaluate(() => window.__hostLog).catch(() => 'eval-gagal')));
  }
})();

// Tunggu sesi live: rail muncul + video benar-benar ter-decode.
await app.waitForSelector('.srail', { timeout: 20000 });
await app.waitForFunction(() => {
  const v = document.querySelector('video');
  return v && v.videoWidth > 0 && v.readyState >= 2;
}, null, { timeout: 20000 });
await app.waitForTimeout(2500); // ICE mantap + beberapa frame
await shot('web-sesi-rail');
console.log('✓ sesi live — screenshot rail');

// Sembunyikan kontrol → pil kecil.
await app.click('.srail-btn[title="Sembunyikan kontrol"]');
await app.waitForTimeout(300);
await shot('web-sesi-rail-disembunyikan');
console.log('✓ rail disembunyikan');
await app.click('.srail-pill');
await app.waitForTimeout(300);

// Panel: tab Gambar (statistik live + pemilih layar).
await app.click('.srail-btn[title="Pengaturan sesi"]');
await app.waitForTimeout(2600); // biar angka stats terisi
await shot('web-sesi-panel-gambar');
console.log('✓ panel Gambar');

// Tab Suara.
await app.click('.spanel-tab:has-text("Suara")');
await app.waitForTimeout(300);
await shot('web-sesi-panel-suara');

// Tab Kontrol.
await app.click('.spanel-tab:has-text("Kontrol")');
await app.waitForTimeout(300);
await shot('web-sesi-panel-kontrol');
console.log('✓ panel Suara + Kontrol');

// Tab Sesi (durasi berdetak).
await app.click('.spanel-tab:has-text("Sesi")');
await app.waitForTimeout(1300);
await shot('web-sesi-panel-sesi');
await app.click('.spanel-close');
await app.waitForTimeout(250);

// Keyboard virtual.
await app.click('.srail-btn[title="Keyboard"]');
await app.waitForTimeout(350);
await shot('web-sesi-keyboard');
await app.click('.srail-btn[title="Keyboard"]');
await app.waitForTimeout(250);

// Panel gaming.
await app.click('.srail-btn[title*="Panel gaming"]');
await app.waitForTimeout(350);
await shot('web-sesi-gaming');
await app.click('.srail-btn[title*="Panel gaming"]');
await app.waitForTimeout(250);

// Mode trackpad.
await app.click('.srail-btn[title*="Mode trackpad"]');
await app.waitForTimeout(300);
await shot('web-sesi-trackpad');
console.log('✓ keyboard, gaming, trackpad');

// Ambil dari papan klip PC → toast.
await app.click('.srail-btn[title="Ambil dari papan klip PC"]');
await app.waitForSelector('.hud-toast', { timeout: 5000 });
await app.waitForTimeout(400);
await shot('web-sesi-clipboard');
console.log('✓ papan klip PC → toast');

// Mik ke PC (perangkat mic palsu Chrome — jalur WebRTC tetap asli).
try {
  await app.click('.srail-btn[title="Mik ke PC"]', { timeout: 3000 });
  await app.waitForTimeout(700);
  await shot('web-sesi-mik');
  console.log('✓ mik ke PC aktif');
} catch {
  console.log('! mik dilewati');
}

const hostLog = await hostPage.evaluate(() => window.__hostLog);
console.log('host log:', JSON.stringify(hostLog));
await browser.close();
shim.close();
console.log('selesai — hasil di', OUT);

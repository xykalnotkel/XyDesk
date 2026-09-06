// XyDesk Desktop — proses utama Electron.
//
// Tanggung jawab (dan yang BUKAN tanggung jawabnya):
//   - Jendela aplikasi + renderer Next.js (static export).
//   - Supervisi engine xydesk-host.exe: identitas, token signaling,
//     watchdog restart dengan backoff.
//   - Jembatan control API engine (HTTP 127.0.0.1 + token) → renderer
//     lewat IPC. Renderer TIDAK boleh bicara langsung ke engine.
//   - BUKAN media: capture/encode/WebRTC sepenuhnya di Rust. Proses ini
//     tidak menyentuh frame video maupun injeksi input.
//
// Keamanan: token control dibaca dari stdout engine (hanya parent process
// yang bisa membacanya), disimpan di memori, dan hanya dipakai untuk
// fetch ke 127.0.0.1. Tidak pernah dikirim ke renderer... kecuali lewat
// hasil /status (bukan masalah: renderer adalah UI kita sendiri dan butuh
// menampilkan password pairing).

const { app, BrowserWindow, ipcMain, shell, Tray, Menu, nativeImage } = require('electron');
const { spawn, execFile } = require('node:child_process');
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const net = require('node:net');
const { registerAuthIpc } = require('./auth.cjs');

// ── Konfigurasi ─────────────────────────────────────────────────────────
const SIGNALING_HTTP = process.env.XYDESK_SIGNALING_HTTP || 'https://signal.xydesk.my.id';
const SIGNALING_WS = process.env.XYDESK_SIGNALING_WS || 'wss://signal.xydesk.my.id/ws';
const WATCHDOG_MS = 2500;
const RESTART_BACKOFF_BASE_MS = 2000;
const RESTART_BACKOFF_MAX_MS = 30000;
const LOG_LIMIT = 400;
const DEV_URL = process.env.XYDESK_DEV_URL || 'http://localhost:3470';

// ── Keadaan proses ──────────────────────────────────────────────────────
let mainWindow = null;
let rendererPort = null; // port server statis (mode produksi)
let engine = null; // ChildProcess
let control = null; // { port, token } — dari baris "[control]" stdout engine
let identity = null; // { deviceId, password }
let lastEngineError = null; // pesan gagal terakhir — dipakai UI "Engine belum siap"
let restartAttempt = 0;
let watchdogTimer = null;
let engineStarting = false; // jaga-jaga: jangan spawn engine dua kali sekaligus
// Kegagalan kredensial yang meminta jeda atau tindakan pengguna. Bentuknya
// { until: number|null, reason: string }; `until` null = permanen (hanya
// perintah pengguna yang boleh mencoba lagi). Lihat CredentialError.
let credentialBlock = null;
let tray = null; // ikon tray — host selalu aktif walau jendela ditutup
let isQuitting = false; // pembeda tutup-jendela (sembunyi) vs keluar beneran
let trayNoticeShown = false;

const logs = [];

function addLog(line) {
  const clean = String(line).replace(/\r?\n$/, '');
  if (!clean) return;
  logs.push({ t: Date.now(), line: clean });
  if (logs.length > LOG_LIMIT) logs.shift();
}

// ── Engine: lokasi, identitas, token, supervise ─────────────────────────
function engineExe() {
  if (process.env.XYDESK_ENGINE && fs.existsSync(process.env.XYDESK_ENGINE)) {
    return process.env.XYDESK_ENGINE;
  }
  if (app.isPackaged) {
    return path.join(process.resourcesPath, 'engine', 'xydesk-host.exe');
  }
  // Dev: cari hasil build Rust di repo.
  const root = path.resolve(__dirname, '..', '..');
  const candidates = [
    path.join(root, 'host', 'target', 'release', 'xydesk-host.exe'),
    path.join(root, 'host', 'target', 'debug', 'xydesk-host.exe'),
  ];
  for (const c of candidates) {
    if (fs.existsSync(c)) return c;
  }
  return null;
}

function loadIdentity() {
  return new Promise((resolve, reject) => {
    const exe = engineExe();
    if (!exe) {
      reject(new Error('xydesk-host.exe tidak ditemukan. Build host/ dulu (cargo build --release).'));
      return;
    }
    execFile(exe, ['--identity-json'], { windowsHide: true, timeout: 15000 }, (err, stdout) => {
      if (err) {
        reject(new Error(`Identitas host tidak terbaca: ${err.message}`));
        return;
      }
      try {
        const v = JSON.parse(stdout);
        if (v && v.deviceId) {
          resolve({ deviceId: v.deviceId, password: v.password || '' });
          return;
        }
        reject(new Error('Identitas host tidak terbaca (JSON kosong).'));
      } catch (e) {
        reject(new Error(`Identitas host tidak terbaca: ${e.message}`));
      }
    });
  });
}

// ── Kredensial penyegaran host ──────────────────────────────────────────
//
// Token sesi berumur 5 menit dan hanya diperiksa saat handshake, jadi setiap
// kedip jaringan setelah engine lama menyala membuat token basi, engine
// keluar, dan dari luar tampak "engine tidak terhubung". Kredensial
// penyegaran memisahkan identitas perangkat (menetap, tersimpan di berkas
// ini) dari token sesi: host menukarnya sendiri tanpa password, tanpa rem
// klaim, tanpa restart yang menunggu jatah percobaan.
function refreshFile() {
  return path.join(app.getPath('userData'), 'host-refresh.json');
}

function loadRefresh() {
  try {
    const parsed = JSON.parse(fs.readFileSync(refreshFile(), 'utf8'));
    return typeof parsed.refresh === 'string' && parsed.refresh ? parsed.refresh : null;
  } catch {
    return null;
  }
}

function saveRefresh(refresh) {
  if (!refresh) return;
  try {
    fs.writeFileSync(refreshFile(), JSON.stringify({ refresh }), { mode: 0o600 });
  } catch (e) {
    addLog(`[shell] kredensial penyegaran gagal disimpan: ${e.message}`);
  }
}

function clearRefresh() {
  try {
    fs.unlinkSync(refreshFile());
  } catch {
    // sudah tidak ada — tidak apa-apa
  }
}

async function postHostToken(body) {
  // Timeout 10 dtk: server signaling yang hang tidak boleh membekukan
  // supervisor (engine tak kunjung lahir dan watchdog ikut diam).
  const res = await fetch(`${SIGNALING_HTTP}/host-token`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(10000),
  });
  const text = (await res.text()).trim();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {
    json = null; // worker lama menjawab token teks polos
  }
  return { status: res.status, text, json };
}

// ── Kegagalan kredensial host ───────────────────────────────────────────
//
// Tidak semua kegagalan token boleh dicoba ulang secepat mungkin. Server
// merem klaim: lima kali salah mengunci satu ID selama 15 menit
// (`device-locked`), dan `claim-mismatch` tidak akan pernah sembuh dengan
// mencoba lagi — password pairing di PC ini berbeda dari yang terkunci di
// server. Backoff 2-30 detik yang benar untuk engine crash justru
// menghabiskan jatah klaim itu dalam beberapa menit, sehingga perangkat
// terkunci berulang tanpa satu pun pesan yang sampai ke pengguna. Gejala di
// lapangan: host hidup, tidak pernah terdaftar, web menjawab "ID tidak
// ditemukan", dan UI hanya berkata "engine belum siap".
//
// Karena itu kegagalan kredensial membawa dua informasi tambahan: apakah
// mencoba ulang masuk akal, dan bila ya, kapan.
class CredentialError extends Error {
  constructor(message, { retryInMs = null, permanent = false } = {}) {
    super(message);
    this.name = 'CredentialError';
    this.retryInMs = retryInMs;
    this.permanent = permanent;
  }
}

// Terjemahkan jawaban /host-token menjadi pesan yang bisa ditindak pengguna.
// `res` = bentuk keluaran postHostToken ({ status, text, json }).
function credentialError(id, res, prefix = '') {
  const error = (res.json && res.json.error) || '';
  const retryIn = Number((res.json && res.json.retry_in) || 0);

  if (error === 'claim-mismatch') {
    return new CredentialError(
      `Password pairing di PC ini tidak cocok dengan yang terkunci di server untuk ID ${id}. ` +
        'Server akan menolaknya terus sampai identitas perangkat diganti: keluar dari XyDesk ' +
        'lewat ikon tray, hapus berkas %USERPROFILE%\\.xydesk\\device_id, lalu buka XyDesk lagi ' +
        '(ID baru dibuat, dan perangkat lain harus memakai ID baru itu).',
      { permanent: true },
    );
  }

  if (error === 'device-locked' || error === 'rate-limited') {
    const tungguMs = Math.max(retryIn * 1000, 60_000);
    return new CredentialError(
      `Server mengunci percobaan klaim ID ${id} selama ${Math.ceil(tungguMs / 60_000)} menit ` +
        '(terlalu banyak klaim gagal). XyDesk menunggu dan tidak mencoba ulang.',
      { retryInMs: tungguMs },
    );
  }

  return new CredentialError(
    `${prefix}Server menolak permintaan token host (HTTP ${res.status}` +
      `${error ? `, ${error}` : ''}).`,
    { retryInMs: 60_000 },
  );
}

// Tukar identitas perangkat → token signaling host berumur pendek. Dari
// proses utama (Node), tanpa CORS — sama seperti GUI native dulu (ureq di
// Rust). Urutan: kredensial penyegaran dulu, klaim dengan password hanya
// kalau kredensial itu tidak ada atau ditolak.
async function fetchHostToken(id, claim) {
  const refresh = loadRefresh();

  // (1) Identitas perangkat: tanpa password, tanpa rem klaim.
  if (refresh) {
    try {
      const res = await postHostToken({ id, refresh });
      if (res.status === 200 && res.json && res.json.token) return res.json.token;
      if (res.status === 401) {
        addLog('[shell] kredensial penyegaran ditolak — minta ulang dengan password pairing');
        clearRefresh();
      } else if (res.status !== 200) {
        addLog(`[shell] penyegaran ditolak (HTTP ${res.status}) — coba klaim dengan password`);
      }
    } catch (e) {
      addLog(`[shell] penyegaran gagal: ${e.message} — coba klaim dengan password`);
    }
  }

  // (2) Klaim klasik (perangkat baru, atau berkas identitas hilang).
  const claimed = await postHostToken({ id, claim, v: 2 });

  // (3) Password pairing berganti di PC ini. Kredensial penyegaran yang
  //     membuktikan ini perangkat yang sama — tanpanya perangkat terkunci
  //     selamanya karena server menyimpan hash password yang lama.
  if (claimed.status === 403 && refresh) {
    addLog('[shell] password pairing berbeda dari yang tersimpan — ikat ulang perangkat');
    const rebound = await postHostToken({ id, refresh, claim });
    if (rebound.status === 200 && rebound.json && rebound.json.token) {
      saveRefresh(rebound.json.refresh);
      addLog('[shell] perangkat terikat ulang ke password pairing yang baru');
      return rebound.json.token;
    }
    throw credentialError(id, rebound, 'Password pairing tidak bisa diperbarui: ikat ulang ditolak. ');
  }

  if (claimed.status !== 200) {
    // Bukan kegagalan sementara yang boleh dipukul ulang tiap 2 detik:
    // bawa alasan server apa adanya + kapan boleh mencoba lagi.
    throw credentialError(id, claimed);
  }
  const token = (claimed.json && claimed.json.token) || claimed.text;
  if (!token) throw new Error('Server mengembalikan token kosong.');
  if (claimed.json && claimed.json.refresh) {
    saveRefresh(claimed.json.refresh);
    addLog('[shell] kredensial penyegaran tersimpan — Engine bisa sambung ulang tanpa password');
  }
  return token;
}

function freePort() {
  return new Promise((resolve, reject) => {
    const srv = net.createServer();
    srv.once('error', reject);
    srv.listen(0, '127.0.0.1', () => {
      const port = srv.address().port;
      srv.close(() => resolve(port));
    });
  });
}

function handleEngineOut(chunk) {
  for (const line of String(chunk).split(/\r?\n/)) {
    if (!line) continue;
    addLog(`[engine] ${line}`);
    // Baris control: "[control] http://127.0.0.1:PORT token=HEX"
    const m = line.match(/\[control\] http:\/\/127\.0\.0\.1:(\d+) token=([0-9a-f]+)/);
    if (m) {
      control = { port: Number(m[1]), token: m[2] };
      restartAttempt = 0; // engine sehat — reset backoff
      lastEngineError = null; // control API siap — engine hidup
      addLog(`[shell] control API siap di 127.0.0.1:${m[1]}`);
    }
  }
}

async function startEngine() {
  if (engineStarting) return; // sudah ada proses start berjalan — jangan tumpuk
  if (engine && engine.exitCode === null) return; // masih hidup
  engineStarting = true;
  clearTimeout(watchdogTimer);
  watchdogTimer = null;
  try {
    if (!identity) identity = await loadIdentity();
    addLog(`[shell] identitas host ${identity.deviceId}`);
    const token = await fetchHostToken(identity.deviceId, identity.password);
    const port = await freePort();
    const exe = engineExe();
    if (!exe) throw new Error('xydesk-host.exe tidak ditemukan.');
    addLog(`[shell] mulai engine (port control ${port})`);
    const child = spawn(
      exe,
      ['--url', SIGNALING_WS, '--token', token, '--control-port', String(port)],
      { windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] }
    );
    engine = child;
    control = null;
    child.stdout.on('data', handleEngineOut);
    child.stderr.on('data', (d) => {
      for (const line of String(d).split(/\r?\n/)) if (line) addLog(`[engine] ${line}`);
    });
    child.on('exit', (code, signal) => {
      addLog(
        `[shell] engine keluar (kode ${code}${signal ? `, sinyal ${signal}` : ''}) — restart terjadwal`
      );
      // Catat penyebab untuk ditampilkan di UI. Kode keluar 0 = engine
      // sengaja berhenti (mis. diminta); selain itu ada yang salah.
      if (code !== 0 && code !== null) {
        lastEngineError = `Engine keluar dengan kode ${code}${signal ? ` (sinyal ${signal})` : ''}.`;
      }
      engine = null;
      control = null;
      scheduleRestart();
    });
    child.on('error', (e) => {
      addLog(`[shell] gagal start engine: ${e.message}`);
      lastEngineError = `Gagal memulai engine: ${e.message}`;
      engine = null;
      scheduleRestart();
    });
  } catch (e) {
    addLog(`[shell] ${e.message}`);
    lastEngineError = String(e && e.message ? e.message : e);
    if (e instanceof CredentialError) {
      // Jangan dipukul ulang dengan backoff engine-crash: server merem klaim,
      // dan tiap percobaan yang gagal memakan jatah ID ini. Permanen = hanya
      // perintah pengguna (engine:restart) yang mencoba lagi.
      credentialBlock = {
        until: e.permanent ? null : Date.now() + (e.retryInMs || 60_000),
        reason: e.message,
      };
      addLog(
        e.permanent
          ? '[shell] berhenti mencoba — butuh tindakan pengguna (lihat pesan di atas)'
          : `[shell] menunggu ${Math.round((e.retryInMs || 60_000) / 1000)} dtk sebelum meminta token lagi`,
      );
      return;
    }
    scheduleRestart();
  } finally {
    engineStarting = false;
  }
}

function scheduleRestart() {
  clearTimeout(watchdogTimer);
  restartAttempt = Math.min(restartAttempt + 1, 10);
  const delay = Math.min(RESTART_BACKOFF_BASE_MS * 2 ** (restartAttempt - 1), RESTART_BACKOFF_MAX_MS);
  addLog(`[shell] restart engine dalam ${Math.round(delay / 1000)} dtk`);
  watchdogTimer = setTimeout(() => {
    watchdogTimer = null;
    startEngine().catch(() => {});
  }, delay);
}

function startWatchdog() {
  setInterval(() => {
    if (engine && engine.exitCode === null) return; // hidup — tidak usah
    if (engineStarting) return; // sedang start — jangan tumpuk
    if (watchdogTimer) return; // restart sudah terjadwal — hormati backoff
    if (credentialBlock) {
      // Kegagalan kredensial: menunggu jeda yang diminta server, atau (bila
      // permanen) tindakan pengguna. Memukul /host-token tiap 2,5 detik
      // justru memperpanjang kunci di sisi server.
      if (credentialBlock.until === null) return;
      if (Date.now() < credentialBlock.until) return;
      addLog('[shell] masa tunggu kredensial berakhir — minta token lagi');
      credentialBlock = null;
    }
    startEngine().catch(() => {});
  }, WATCHDOG_MS);
}

// ── Control API → IPC ───────────────────────────────────────────────────
async function controlFetch(pathname, init = {}) {
  if (!control) throw new Error('engine-belum-siap');
  const headers = { 'x-xydesk-token': control.token, ...(init.headers || {}) };
  const res = await fetch(`http://127.0.0.1:${control.port}${pathname}`, {
    ...init,
    headers,
    signal: AbortSignal.timeout(5000),
  });
  const body = await res.text();
  let json = null;
  try {
    json = JSON.parse(body);
  } catch {
    /* body bukan JSON */
  }
  if (!res.ok) {
    throw new Error(`HTTP ${res.status}: ${json ? (json.error || body) : body}`);
  }
  return json;
}

function registerIpc() {
  ipcMain.handle('status', async () => {
    try {
      const s = await controlFetch('/status');
      return { ...s, engine: true };
    } catch {
      // Engine belum siap / mati. Jangan sembunyikan kenapa: kirim identitas
      // (ID + password pairing tetap terbaca dari mesin ini) + sebab terakhir
      // supaya halaman Home bisa menjelaskan, bukan cuma "belum siap".
      return {
        state: 'starting',
        engine: false,
        deviceId: identity ? identity.deviceId : null,
        password: identity ? identity.password : null,
        lastError: lastEngineError,
        // Kegagalan kredensial punya makna khusus: mencoba ulang tidak akan
        // menolong sampai pengguna bertindak (atau masa tunggu server lewat).
        // UI boleh menampilkannya apa adanya; `until` null = permanen.
        credentialBlock: credentialBlock
          ? { reason: credentialBlock.reason, until: credentialBlock.until }
          : null,
      };
    }
  });

  ipcMain.handle('action', async (_event, req) => {
    if (!req || typeof req.action !== 'string') {
      return { ok: false, error: 'Permintaan aksi tidak valid.' };
    }
    try {
      return await controlFetch('/action', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(req),
      });
    } catch (e) {
      return { ok: false, error: String(e.message || e) };
    }
  });

  ipcMain.handle('logs', () => logs.slice(-LOG_LIMIT));
  // Shell mengirim baris pendek ("Dikendalikan Redmi Note 12 · android") untuk
  // tooltip tray + judul jendela. Jendela sering ditutup ke tray saat sesi
  // berjalan, dan di situlah pemilik PC ingin melihat apakah layarnya sedang
  // ditonton — tanpa harus membuka aplikasi.
  ipcMain.handle('window:hint', (_event, hint) => {
    const text = typeof hint === 'string' ? hint.slice(0, 120) : '';
    if (tray) {
      try {
        tray.setToolTip(text ? `XyDesk — ${text}` : 'XyDesk — host selalu aktif');
      } catch {
        /* tooltip tidak bisa diganti (tray sedang sibuk) */
      }
    }
    if (mainWindow) mainWindow.setTitle(text ? `XyDesk — ${text}` : 'XyDesk');
    return { ok: true };
  });

  ipcMain.handle('info', () => ({
    appVersion: app.getVersion(),
    signalingHttp: SIGNALING_HTTP,
    platform: process.platform,
    packaged: app.isPackaged,
  }));

  // Mulai dengan Windows — pengaturan OS sungguhan (bukan dummy).
  ipcMain.handle('autostart:get', () => app.getLoginItemSettings().openAtLogin);

  ipcMain.handle('autostart:set', (_event, enable) => {
    try {
      app.setLoginItemSettings({ openAtLogin: !!enable });
      return { ok: true, enabled: app.getLoginItemSettings().openAtLogin };
    } catch (e) {
      return { ok: false, error: String(e && e.message ? e.message : e) };
    }
  });

  // Restart engine paksa: bunuh proses; watchdog akan menyalakannya lagi
  // dengan token baru.
  ipcMain.handle('engine:restart', () => {
    const wasAlive = engine && engine.exitCode === null;
    if (wasAlive) engine.kill();
    // Perintah pengguna = coba lagi sekarang, walau server tadi menyuruh
    // menunggu atau menolak permanen. Tanpa ini, satu-satunya jalan keluar
    // dari kegagalan kredensial adalah menutup aplikasi.
    const wasBlocked = credentialBlock !== null;
    credentialBlock = null;
    lastEngineError = null;
    restartAttempt = 0;
    scheduleRestart();
    return { ok: true, restarted: wasAlive, wasBlocked };
  });
}

// ── Renderer: server statis (produksi) / URL dev ────────────────────────
const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
  '.txt': 'text/plain; charset=utf-8',
  '.woff2': 'font/woff2',
  '.map': 'application/json',
};

function startRendererServer() {
  const root = path.join(__dirname, '..', 'out');
  return new Promise((resolve) => {
    const srv = http.createServer((req, res) => {
      let p = decodeURIComponent(new URL(req.url, 'http://x').pathname);
      if (p.endsWith('/')) p += 'index.html';
      if (p === '/') p = '/index.html';
      const file = path.normalize(path.join(root, p));
      if (!file.startsWith(root)) {
        res.writeHead(403);
        res.end('forbidden');
        return;
      }
      fs.stat(file, (err, st) => {
        if (err || !st.isFile()) {
          res.writeHead(404);
          res.end('not found');
          return;
        }
        res.writeHead(200, { 'content-type': MIME[path.extname(file).toLowerCase()] || 'application/octet-stream' });
        fs.createReadStream(file).pipe(res);
      });
    });
    srv.listen(0, '127.0.0.1', () => resolve(srv.address().port));
  });
}

// ── Jendela ─────────────────────────────────────────────────────────────
function createWindow() {
  mainWindow = new BrowserWindow({
    width: 940,
    height: 680,
    minWidth: 760,
    minHeight: 560,
    // Warna latar = warna UI. Kalau beda, satu frame pertama sesudah
    // `show` menampilkan kilatan gelap sebelum Next.js sempat menggambar.
    backgroundColor: '#fafaf9',
    autoHideMenuBar: true,
    title: 'XyDesk',
    show: false,
    // Baris judul Windows dilebur ke dalam UI: topbar aplikasi (lihat
    // `.topbar` di globals.css) menjadi daerah seret, dan tombol minimum /
    // maksimum / tutup digambar Windows di ujung kanan baris itu sendiri.
    // Sengaja TIDAK pakai frameless (`frame:false`) — dengan cara ini snap
    // layouts, tombol caption asli, dan estetika Windows tetap utuh, tanpa
    // harus reimplementasi tombol tutup + drag + resize di HTML.
    titleBarStyle: 'hidden',
    titleBarOverlay: { color: '#fafaf9', symbolColor: '#18181b', height: 46 },
    // Linux/konfigurasi lama: overlay tidak didukung; pakai titelbar biasa.
    ...(process.platform === 'win32' || process.platform === 'darwin'
      ? {}
      : { titleBarStyle: 'default', titleBarOverlay: undefined }),
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });

  mainWindow.once('ready-to-show', () => mainWindow.show());
  // Tautan luar dibuka di browser sistem, bukan di dalam jendela app.
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (/^https?:\/\//.test(url)) shell.openExternal(url);
    return { action: 'deny' };
  });
  // Host selalu aktif: menutup jendela TIDAK mematikan app/engine — jendela
  // disembunyikan ke tray (standar remote desktop). Keluar beneran hanya
  // lewat menu tray "Keluar" (atau app.quit()) yang menyetel isQuitting.
  mainWindow.on('close', (event) => {
    if (!isQuitting) {
      event.preventDefault();
      mainWindow.hide();
      if (!trayNoticeShown && tray) {
        trayNoticeShown = true;
        try {
          tray.displayBalloon({
            title: 'XyDesk tetap aktif',
            content: 'Host berjalan di latar belakang. Buka lagi lewat ikon XyDesk di tray.',
          });
        } catch {
          /* balloon tidak tersedia — abaikan */
        }
      }
    }
  });
  mainWindow.on('closed', () => {
    mainWindow = null;
  });

  if (app.isPackaged) {
    mainWindow.loadURL(`http://127.0.0.1:${rendererPort}/`);
  } else {
    mainWindow.loadURL(DEV_URL);
  }
}

// ── Tray + siklus always-on ──────────────────────────────────────────────
// Ikon tray: file .ico di sebelah main.cjs (ikut dibundel via build.files
// "electron/**"). Ukuran multi (16–256) — Windows memilih yang pas.
function trayIcon() {
  try {
    const icon = nativeImage.createFromPath(path.join(__dirname, 'tray.ico'));
    if (!icon.isEmpty()) return icon;
  } catch {
    /* fallback ke ikon kosong */
  }
  return nativeImage.createEmpty();
}

function showWindow() {
  if (!mainWindow) {
    createWindow();
    return;
  }
  if (mainWindow.isMinimized()) mainWindow.restore();
  mainWindow.show();
  mainWindow.focus();
}

function createTray() {
  tray = new Tray(trayIcon());
  tray.setToolTip('XyDesk — host selalu aktif');
  const menu = Menu.buildFromTemplate([
    { label: 'Buka XyDesk', click: () => showWindow() },
    { type: 'separator' },
    { label: 'Keluar (hentikan host)', click: () => quitApp() },
  ]);
  tray.setContextMenu(menu);
  tray.on('click', () => showWindow());
}

function quitApp() {
  isQuitting = true;
  if (engine && engine.exitCode === null) {
    try {
      engine.kill();
    } catch {
      /* proses sudah mati */
    }
  }
  app.quit();
}

// ── Siklus hidup app ────────────────────────────────────────────────────
const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  app.quit();
} else {
  app.on('second-instance', () => showWindow());

  app.whenReady().then(async () => {
    registerIpc();
    // Login (Google PKCE + email OTP). Sengaja didaftarkan di proses utama:
    // token sesi tidak pernah diserahkan ke renderer, dan client_secret
    // Google tidak pernah ada di aplikasi ini sama sekali (penukaran code
    // dilakukan Worker).
    registerAuthIpc(addLog);
    if (app.isPackaged) {
      rendererPort = await startRendererServer();
    }
    createWindow();
    createTray();
    // Mulai supervisor tanpa memblokir tampilan UI.
    startEngine().catch(() => {});
    startWatchdog();

    app.on('activate', () => {
      if (BrowserWindow.getAllWindows().length === 0) createWindow();
      else showWindow();
    });
  });

  // Keluar beneran (menu tray / app.quit): tandai supaya handler close
  // jendela tidak mencegat, lalu pastikan engine ikut mati.
  app.on('before-quit', () => {
    isQuitting = true;
  });
  app.on('quit', () => {
    if (engine && engine.exitCode === null) {
      try {
        engine.kill();
      } catch {
        /* proses sudah mati */
      }
    }
  });

  // Host harus selalu aktif: jendela tertutup hanya disembunyikan (close
  // dicegat di atas), jadi ini praktis tidak pernah terpicu pada mode tray.
  // Tetap dijaga supaya app tidak menggantung bila jendela benar-benar tutup.
  app.on('window-all-closed', () => {
    if (isQuitting) app.quit();
  });
}

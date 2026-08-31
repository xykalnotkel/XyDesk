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

const { app, BrowserWindow, ipcMain, shell } = require('electron');
const { spawn, execFile } = require('node:child_process');
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const net = require('node:net');

// ── Konfigurasi ─────────────────────────────────────────────────────────
const SIGNALING_HTTP = process.env.XYDESK_SIGNALING_HTTP || 'https://signal.xystudio.my.id';
const SIGNALING_WS = process.env.XYDESK_SIGNALING_WS || 'wss://signal.xystudio.my.id/ws';
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
let restartAttempt = 0;
let watchdogTimer = null;

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
    execFile(exe, ['--identity-json'], { windowsHide: true }, (err, stdout) => {
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

// Tukar id+password → token signaling host berumur pendek. Dari proses utama
// (Node), tanpa CORS — sama seperti GUI native dulu (ureq di Rust).
async function fetchHostToken(id, claim) {
  const res = await fetch(`${SIGNALING_HTTP}/host-token`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ id, claim }),
  });
  if (!res.ok) {
    throw new Error(`Server menolak token (HTTP ${res.status}).`);
  }
  const text = (await res.text()).trim();
  if (!text) throw new Error('Server mengembalikan token kosong.');
  return text;
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
      addLog(`[shell] control API siap di 127.0.0.1:${m[1]}`);
    }
  }
}

async function startEngine() {
  if (engine && engine.exitCode === null) return; // masih hidup
  clearTimeout(watchdogTimer);
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
    child.on('exit', (code) => {
      addLog(`[shell] engine keluar (kode ${code}) — restart terjadwal`);
      engine = null;
      control = null;
      scheduleRestart();
    });
    child.on('error', (e) => {
      addLog(`[shell] gagal start engine: ${e.message}`);
      engine = null;
      scheduleRestart();
    });
  } catch (e) {
    addLog(`[shell] ${e.message}`);
    scheduleRestart();
  }
}

function scheduleRestart() {
  clearTimeout(watchdogTimer);
  restartAttempt = Math.min(restartAttempt + 1, 10);
  const delay = Math.min(RESTART_BACKOFF_BASE_MS * 2 ** (restartAttempt - 1), RESTART_BACKOFF_MAX_MS);
  addLog(`[shell] restart engine dalam ${Math.round(delay / 1000)} dtk`);
  watchdogTimer = setTimeout(() => {
    startEngine().catch(() => {});
  }, delay);
}

function startWatchdog() {
  setInterval(() => {
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
      return { state: 'starting', engine: false, deviceId: null, password: null };
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

  ipcMain.handle('info', () => ({
    appVersion: app.getVersion(),
    signalingHttp: SIGNALING_HTTP,
    platform: process.platform,
    packaged: app.isPackaged,
  }));
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
    backgroundColor: '#131315',
    autoHideMenuBar: true,
    title: 'XyDesk',
    show: false,
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
  mainWindow.on('closed', () => {
    mainWindow = null;
  });

  if (app.isPackaged) {
    mainWindow.loadURL(`http://127.0.0.1:${rendererPort}/`);
  } else {
    mainWindow.loadURL(DEV_URL);
  }
}

// ── Siklus hidup app ────────────────────────────────────────────────────
const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore();
      mainWindow.focus();
    }
  });

  app.whenReady().then(async () => {
    registerIpc();
    if (app.isPackaged) {
      rendererPort = await startRendererServer();
    }
    createWindow();
    // Mulai supervisor tanpa memblokir tampilan UI.
    startEngine().catch(() => {});
    startWatchdog();

    app.on('activate', () => {
      if (BrowserWindow.getAllWindows().length === 0) createWindow();
    });
  });

  app.on('window-all-closed', () => {
    if (engine && engine.exitCode === null) engine.kill();
    app.quit();
  });
}

// UI XyDesk Desktop (Tauri) — mode Host, ALWAYS-ON.
//
// Tidak ada tombol start/stop: begitu app dibuka, engine host dinyalakan
// otomatis dan dijaga tetap hidup (watchdog menyalakan ulang bila mati).
// Alur token: id+password pairing (dari engine) ditukar ke /host-token
// Worker menjadi token signaling role=host, lalu engine dijalankan.

import { invoke } from '@tauri-apps/api/core';
import { open } from '@tauri-apps/plugin-shell';

const API_BASE = 'https://signal.xystudio.my.id';
const SIGNALING_URL = 'wss://signal.xystudio.my.id/ws';

interface Identity {
  deviceId?: string;
  password?: string;
}

interface EngineStatus {
  running: boolean;
  pid: number | null;
}

/// "123456789" -> "123 456 789".
function prettyId(id: string): string {
  const d = id.replace(/\D/g, '');
  return d.length === 9 ? `${d.slice(0, 3)} ${d.slice(3, 6)} ${d.slice(6)}` : id;
}

const app = document.getElementById('app')!;

function esc(s: string): string {
  return s.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
}

let identity: Identity | null = null;
let identityError = '';
let lastEngineError = '';
let status: EngineStatus = { running: false, pid: null };

async function loadIdentity(): Promise<void> {
  if (identity !== null) return;
  try {
    identity = await invoke<Identity>('host_identity');
  } catch (e) {
    identityError = String(e);
  }
}

/// Tukar id+password menjadi token signaling host di Worker.
async function fetchHostToken(): Promise<string> {
  const res = await fetch(`${API_BASE}/host-token`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      id: identity?.deviceId ?? '',
      claim: identity?.password ?? '',
    }),
  });
  if (!res.ok) {
    throw new Error(
      res.status === 403
        ? 'Password pairing tidak cocok dengan klaim device di server.'
        : `Server menolak token host (HTTP ${res.status}).`,
    );
  }
  return (await res.text()).trim();
}

/// Watchdog: pastikan engine hidup; nyalakan (ulang) bila mati.
async function ensureEngine(): Promise<void> {
  try {
    status = await invoke<EngineStatus>('engine_status');
    if (status.running) {
      lastEngineError = '';
      return;
    }
    const token = await fetchHostToken();
    status = await invoke<EngineStatus>('start_engine', {
      url: SIGNALING_URL,
      token,
    });
    lastEngineError = '';
  } catch (e) {
    lastEngineError = String(e);
  }
}

function render(): void {
  const shownId = identity?.deviceId ? prettyId(identity.deviceId) : '—';
  const password = identity?.password ?? '—';

  app.innerHTML = `
    <main class="shell">
      <header>
        <img src="/logo.png" alt="" class="logo" />
        <div>
          <h1>XyDesk</h1>
          <p class="sub">Mode Host — selalu aktif selama aplikasi terbuka</p>
        </div>
        <span class="pill ${status.running ? 'pill-live' : 'pill-off'}">
          ${status.running ? 'AKTIF' : 'MENYAMBUNG…'}
        </span>
      </header>

      ${
        identityError
          ? `<section class="card error-card">
               <p>${esc(identityError)}</p>
               <p class="hint">Pastikan XyDesk terinstal utuh (folder Host ikut terpasang).</p>
             </section>`
          : `<section class="card">
               <label>ID perangkat</label>
               <p class="big-id">${esc(shownId)}</p>
               <label>Password pairing</label>
               <div class="pw-row">
                 <code id="pw" data-hidden="1">••••••••</code>
                 <button id="toggle-pw" class="ghost">Lihat</button>
                 <button id="copy-pw" class="ghost">Salin</button>
               </div>
               <p class="hint">Masukkan ID + password ini di aplikasi XyDesk
               (Android) atau app.xystudio.my.id dari perangkat lain.</p>
             </section>`
      }

      ${
        lastEngineError
          ? `<section class="card error-card">
               <p>${esc(lastEngineError)}</p>
               <p class="hint">Dicoba ulang otomatis…</p>
             </section>`
          : ''
      }

      <footer>
        <button id="open-web" class="ghost">Kendalikan PC lain → XyDesk Web</button>
      </footer>
    </main>
  `;

  document.getElementById('toggle-pw')?.addEventListener('click', () => {
    const el = document.getElementById('pw')!;
    const hidden = el.dataset.hidden === '1';
    el.textContent = hidden ? password : '••••••••';
    el.dataset.hidden = hidden ? '0' : '1';
    document.getElementById('toggle-pw')!.textContent = hidden ? 'Tutup' : 'Lihat';
  });

  document.getElementById('copy-pw')?.addEventListener('click', () => {
    void navigator.clipboard.writeText(password);
  });

  document.getElementById('open-web')?.addEventListener('click', () => {
    void open('https://app.xystudio.my.id/connect');
  });
}

async function tick(): Promise<void> {
  await loadIdentity();
  await ensureEngine();
  render();
}

void tick();
// Watchdog + refresh status tiap 5 detik. Token host berumur 5 menit di
// worker, tetapi hanya dibutuhkan SAAT connect — engine yang sudah
// tersambung tidak butuh token baru; restart otomatis mengambil yang baru.
setInterval(() => void tick(), 5000);

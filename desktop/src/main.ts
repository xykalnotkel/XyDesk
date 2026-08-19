// UI XyDesk Desktop (Tauri) — mode Host.
//
// PC ini menjadi host: tampilkan ID + password pairing, tombol start/stop
// engine. Untuk MENGENDALIKAN PC lain dari sini, buka app.xystudio.my.id
// (tombol tersedia) — viewer WebRTC berjalan lebih baik di browser penuh.

import { invoke } from '@tauri-apps/api/core';
import { open } from '@tauri-apps/plugin-shell';

const SIGNALING_URL = 'wss://signal.xystudio.my.id/ws';

interface Identity {
  id?: string;
  pretty_id?: string;
  password?: string;
  name?: string;
}

interface EngineStatus {
  running: boolean;
  pid: number | null;
}

const app = document.getElementById('app')!;

function h(html: string): void {
  app.innerHTML = html;
}

function esc(s: string): string {
  return s.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
}

async function render(): Promise<void> {
  let identity: Identity = {};
  let identityError = '';
  try {
    identity = await invoke<Identity>('host_identity');
  } catch (e) {
    identityError = String(e);
  }
  let status: EngineStatus = { running: false, pid: null };
  try {
    status = await invoke<EngineStatus>('engine_status');
  } catch {
    /* engine belum pernah jalan */
  }

  const prettyId = identity.pretty_id ?? identity.id ?? '—';
  const password = identity.password ?? '—';

  h(`
    <main class="shell">
      <header>
        <img src="/logo.png" alt="" class="logo" />
        <div>
          <h1>XyDesk</h1>
          <p class="sub">Mode Host — PC ini dikendalikan dari perangkat lain</p>
        </div>
        <span class="pill ${status.running ? 'pill-live' : 'pill-off'}">
          ${status.running ? 'AKTIF' : 'NONAKTIF'}
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
               <p class="big-id">${esc(prettyId)}</p>
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

      <section class="card">
        <button id="engine-btn" class="${status.running ? 'danger' : 'primary'}">
          ${status.running ? 'Hentikan Host' : 'Mulai Host'}
        </button>
        <p class="hint">${
          status.running
            ? `Engine berjalan (PID ${status.pid}). Perangkat lain dapat terhubung.`
            : 'Engine berhenti. Mulai untuk menerima koneksi.'
        }</p>
      </section>

      <footer>
        <button id="open-web" class="ghost">Kendalikan PC lain → XyDesk Web</button>
      </footer>
    </main>
  `);

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

  document.getElementById('engine-btn')?.addEventListener('click', async () => {
    const btn = document.getElementById('engine-btn') as HTMLButtonElement;
    btn.disabled = true;
    try {
      if (status.running) {
        await invoke('stop_engine');
      } else {
        await invoke('start_engine', { url: SIGNALING_URL, token: '' });
      }
    } finally {
      void render();
    }
  });

  document.getElementById('open-web')?.addEventListener('click', () => {
    void open('https://app.xystudio.my.id/connect');
  });
}

void render();
// Segarkan status engine tiap 5 detik (murah: satu invoke).
setInterval(() => void render(), 5000);

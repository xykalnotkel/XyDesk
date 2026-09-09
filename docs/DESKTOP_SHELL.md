# XyDesk Desktop — Shell Tauri v2 + Next.js

## Posisi dalam arsitektur

XyDesk Desktop adalah **launcher + panel host Windows** berbasis **Tauri v2 (Rust + WebView2)**
yang menyajikan antarmuka React / Next.js (static export) dan mensupervisi engine streaming
Rust murni (`xydesk-host.exe`).

Pemisahan peran yang ketat:

| Lapisan | Teknologi | Tanggung jawab |
|---|---|---|
| Shell Desktop | Tauri v2 + Next.js (static export) | Sidebar (Home, Connect, News, Profile, Settings), identitas, tray, supervisor engine |
| Engine Streaming | Rust (`xydesk-host.exe`) | Signaling, pairing, capture DXGI, encode NVENC, WebRTC, WASAPI audio loopback, injeksi input |
| Driver Bawaan | IddSampleDriver + VB-CABLE | Virtual display driver (headless/RDP tanpa layar hitam) + Virtual audio/mic driver |

### Mengapa Tauri v2 Menggantikan Electron:
1. **Ringan & Hemat RAM:** Penggunaan memori turun dari ~150–200 MB (Chromium V8 Electron) menjadi **~25–40 MB** (Tauri + native Windows WebView2).
2. **Ukuran Installer:** Ukuran installer terpangkas drastis menjadi **~15–20 MB**.
3. **Ekosistem Rust Terpadu:** Engine streaming (`host/`) dan shell desktop sama-sama ditulis dalam Rust, membuat IPC, tray handling, lifecycle management, dan integrasi OS jauh lebih andal dan konsisten.

---

## Driver Bawaan Terintegrasi (Zero-Prompt Setup)

Pada rilis ini, seluruh driver pendukung **ditanam langsung (embedded)** di dalam paket installer dan runtime:
- **Virtual Display Driver (`IddSampleDriver`)**:
  Menghasilkan layar virtual berkecepatan tinggi saat PC host dijalankan tanpa monitor (headless), monitor mati, atau saat sesi RDP ditutup agar capture tidak menjadi hitam.
- **Virtual Audio & Mic Driver (`VB-CABLE`)**:
  Menangkap audio PC host dan meneruskan microphone client (HP/Tablet/Laptop) agar langsung terbaca sebagai perangkat microphone fisik Windows (CABLE Input $\rightarrow$ CABLE Output di Recording devices).

### Otomasi Instalasi:
- Saat installer dijalankan (dengan hak Admin), skrip Inno Setup (`packaging/windows/XyDesk.iss`) secara otomatis menginstal driver secara silent di latar belakang tanpa memunculkan dialog tambahan atau meminta pengguna menjalankan PowerShell manual.
- Saat aplikasi di-uninstall, driver dibersihkan secara otomatis.

---

## Control API & Supervisi Engine

Shell Tauri berkomunikasi dengan engine `xydesk-host.exe` melalui Control API lokal di `127.0.0.1`:
- **Auth:** Token acak 128-bit yang dibaca dari stdout saat engine pertama kali di-spawn (`[control] http://127.0.0.1:PORT token=HEX`).
- `GET /status`: Mengambil status realtime (state, session, video fps/encoder/latency, audio, display, dll.).
- `POST /action`: Perintah interaktif (ganti password pairing, stop-session, pilih display, ubah bitrate, atur volume audio).
- **Watchdog:** Supervisor mendeteksi bila engine berhenti tak terduga dan melakukan auto-restart dengan backoff bertahap (2s hingga 30s).

---

## Autentikasi Desktop (Google OAuth PKCE & Email OTP)

- **Google OAuth:** Menggunakan alur Authorization Code + PKCE dengan loopback server lokal pada port acak `127.0.0.1:PORT/callback`. Pertukaran kode token dilakukan dengan Worker Cloudflare (`/auth/google/desktop`). Client secret tidak pernah ditanam di binary desktop.
- **Email OTP:** Mengirimkan permintaan OTP ke Cloudflare Worker dan memverifikasinya langsung dari UI desktop.
- **Penyimpanan Sesi:** Sesi login disimpan secara lokal di `%APPDATA%\XyDesk\auth_session.json` dan dijaga masa berlakunya.

---

## Pengembangan & Build

```bash
cd desktop
npm install
npm run dev        # Pratinjau frontend (mode demo di browser): http://localhost:3470
npm run build      # Static export Next.js ke desktop/out/
```

Kompilasi paket penuh Windows:
```bash
cargo build --release -p xydesk-desktop --manifest-path desktop/src-tauri/Cargo.toml
```

# XyDesk Desktop — Shell Electron + Next.js

## Posisi dalam arsitektur

XyDesk Desktop adalah **launcher + panel** untuk host Windows, menggantikan
GUI native Win32 (`host/src/bin/gui.rs`, tetap dipertahankan sebagai
fallback tanpa WebView).

Pemisahan peran yang ketat:

| Lapisan | Teknologi | Tanggung jawab |
|---|---|---|
| Shell | Electron + Next.js (static export) | UI, identitas, watchdog engine, panel sesi |
| Engine | Rust (`xydesk-host.exe`) | Signaling, pairing, capture DXGI, encode NVENC, WebRTC, injeksi input |

**Kenapa Electron boleh di sini tapi tidak untuk media:** desktopCapturer /
getDisplayMedia di Chromium memutar frame lewat CPU dan encode-nya jauh di
atas target `< 40 ms` glass-to-glass. Engine Rust memakai Desktop Duplication
+ NVENC langsung dari tekstur GPU (zero-copy). Selama shell tidak menyentuh
frame video, Electron hanya menambah biaya RAM (~80–120 MB), bukan latency.

**Kenapa Next.js:** pilihan tim untuk UI React dengan toolchain yang nyaman.
Dipakai sebagai static export (`output: 'export'`) — tidak ada SSR/API routes
di runtime desktop; renderer disajikan proses utama lewat server HTTP lokal
di `127.0.0.1` (bukan `file://`, agar tidak ada masalah path/aset).

## Control API (engine ↔ shell)

Agar panel bisa menampilkan keadaan engine (bukan menebak dari log), engine
punya control API HTTP **hanya di `127.0.0.1`** (`host/src/control.rs`):

- **Auth:** token acak 128 bit per-lahir, dicetak sekali ke stdout sebagai
  `[control] http://127.0.0.1:PORT token=HEX`; hanya parent process yang
  membacanya. Perbandingan token konstan-waktu (hash SHA-256 + XOR).
- `GET /health` — liveness (tanpa token; tidak membocorkan apa pun).
- `GET /status` — status JSON: `state` (`starting|connecting|ready|streaming|
  error`), `deviceId`, `password`, `session` (client + durasi), `video`
  (framesSent, fps, nvenc), `lastError`.
- `POST /action` — `new-password`, `set-password` (min 6 karakter),
  `stop-session` (tutup peer connection + cabut izin pairing — sama seperti
  `bye` dari client).

Yang **sengaja tidak bisa** dilakukan control API: memberi izin pairing /
offer. Jalur kepercayaan itu tetap di loop signaling (`pairguard`,
`pairedpeers`). `stop-session` menutup sesi tapi tidak bisa membuka sesi.

Status dibaca polling tiap ~1,5 detik dari renderer — cukup untuk panel,
dan jauh lebih sederhana daripada push-event.

## Alur hidup shell

1. Proses utama membaca identitas: `xydesk-host --identity-json`
   → `{deviceId, password}`.
2. Tukar `id + password` → token signaling lewat `POST /host-token`
   (dari Node — tidak ada CORS, sama seperti GUI native dulu).
3. Spawn engine: `--url wss://signal.xystudio.my.id/ws --token TOKEN
   --control-port <port-bebas>`; port dipilih proses utama agar tidak bentrok.
4. Parse baris `[control]` dari stdout → token + port control.
5. Renderer meminta status lewat IPC (`window.xydesk.getStatus()`);
   proses utama yang memanggil control API — renderer tidak pernah bicara
   langsung ke engine.
6. Watchdog tiap 2,5 detik: engine mati → start ulang dengan token baru,
   backoff eksponensial 2 detik → maks 30 detik.

## Mode identitas portabel

`XYDESK_HOME` (env) mengarahkan penyimpanan `device_id` + `password`.
Dipasang untuk test otomatis; installer portable dapat memakainya agar
identitas ikut folder aplikasi.

## Pengembangan lokal

```bash
cd desktop
npm install
npm run dev        # renderer Next.js di http://localhost:3470 (mode demo bila
                   # dibuka di browser biasa)
npm run typecheck  # pemeriksaan tipe
npm run build      # static export ke out/

# Terminal lain: jalankan shell dengan Electron
npm run electron   # butuh xydesk-host.exe (cargo build --release di host/)
```

Mode demo: bila `window.xydesk` tidak ada (dibuka di browser), UI menampilkan
data contoh dengan banner "Mode pratinjau".

## Paket & rilis

`npm run package` → `electron-builder` menghasilkan installer NSIS + EXE
portable di `desktop/dist/`. Engine dibundel lewat `extraResources` ke
`resources/engine/xydesk-host.exe`. CI: `.github/workflows/build-desktop.yml`
(job Linux verifikasi shell; job Windows paket x64). Rilis terintegrasi di
`release.yml`.

# XyDesk Desktop — Shell Electron + Next.js

## Posisi dalam arsitektur

XyDesk Desktop adalah **launcher + panel** untuk host Windows, menggantikan
GUI native Win32 (`host/src/bin/gui.rs`, tetap dipertahankan sebagai
fallback tanpa WebView).

Pemisahan peran yang ketat:

| Lapisan | Teknologi | Tanggung jawab |
|---|---|---|
| Shell | Electron + Next.js (static export) | Sidebar (Home, Connect, News, Profile, Settings), identitas, watchdog engine |
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
  error`), `deviceId`, `password`, `signalingUrl`, `startedAtMs`, `uptimeMs`,
  `session` (`clientId`, `clientName`, `clientPlatform`, durasi), `video`
  (framesSent, fps, nvenc, encoder, latencyMs, latencyMaxMs), `audio`
  (captureAvailable/pipeline, micAvailable/micPipeline, outputs, volume),
  `displays` (`list[]` + `wanted`), `targetBitrateBps`, `lastError`.
  Semua nama di sisi ini camelCase — lihat tipe-nya di `desktop/global.d.ts`.
- `POST /action` — `new-password`, `set-password` (min. 6 karakter; aturannya
  ada di `identity::set_password`, bukan di shell), `stop-session` (tutup peer
  connection + cabut izin pairing — sama seperti `bye` dari client),
  `audio-volume` (`{"volume":0..1}`), `display-select` (`{"index":n}`),
  `video-bitrate` (`{"bitrate_mbps":n}`).
  **Awas:** body `ActionRequest` TIDAK di-`rename_all`, jadi nama bidangnya
  snake_case apa adanya; `bitrateMbps` diterima lewat `serde(alias)` supaya
  TypeScript tidak salah tebak, tetapi kanoniknya `bitrate_mbps`.
- `session.clientName` / `clientPlatform` berasal dari pesan `pair` client
  (dilaporkan sendiri, boleh dikarang) — dipakai untuk menampilkan "siapa yang
  menonton" dan TIDAK pernah jadi dasar keputusan akses. UI shell: chip di
  topbar, kartu Sesi aktif, tooltip tray, judul jendela.

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

## Halaman sidebar

- **Home** — status engine, uptime, sesi aktif (perangkat pengendali, ID
  pairing, durasi, FPS/frame/encoder/latensi/monitor) + akhiri sesi.
- **Connect** — ID + password pairing, salin/tampilkan, password acak/kustom.
  Kolom password kustom TIDAK mengkapital otomatis (`autoCapitalize="none"`)
  karena host membandingkan secara peka-kasus; ada peringatan kalau password
  yang dipilih tidak punya huruf kecil sama sekali (lihat `host/README.md`).
- **News** — feed publik `news.xystudio.my.id` (like, komentar, salin tautan berbagi).
- **Profile** — identitas perangkat, versi, tautan eksternal.
- **Settings** (pojok kiri bawah) — mulai dengan Windows (nyata lewat
  `app.setLoginItemSettings`), mulai ulang engine, monitor sumber
  (`display-select`), batas bitrate + perkiraan MB/jam (`video-bitrate`),
  volume master PC (`audio-volume`), pipeline audio, lisensi, log engine.

## Aturan tata letak (yang sudah dibayar mahal)

- **Yang menggulung = `.page-body`, bukan jendela.** `.shell` grid-nya
  `grid-template-rows: minmax(0, 100%)` + `overflow: hidden`, dan `.main`
  serta `.page-body` diberi `min-height: 0`. Baris `auto` (keadaan dulu) membuat
  grid memanjang mengikuti isi sehingga `overflow-y: auto` tidak pernah aktif:
  konten terpotong tanpa scrollbar (`body { overflow: hidden }`). Sidebar
  punya scroll sendiri. Diuji Playwright: 5 halaman × 3 viewport (1280×720,
  900×560, 1100×480) → nol baris terkunci.
- **Topbar = baris judul Windows = quick surface.** `titleBarStyle: 'hidden'` +
  `titleBarOverlay` sewarna `--bg`; `.topbar` `-webkit-app-region: drag` dan
  SETIAP elemen yang bisa diklik di dalamnya `no-drag`. Jangan pakai
  `frame: false` (snap layouts + tombol caption asli ikut hilang). Baris di
  ATAS topbar menutupi tombol caption — jangan dipakai di mode Electron.
  `padding-right: 150px` khusus `<html class="electron">` adalah tempat tombol
  min/maks/tutup; cek ulang kalau Electron di-upgrade.
- **Satu data, satu tempat.** Pill status pernah dobel (topbar + bawah
  sidebar); yang dibuang yang di sidebar.
- **Merek dari generator.** `desktop/public/logo.png` dan
  `desktop/electron/tray.ico` adalah keluaran `tool/gen_logo.py`
  (`docs/BRAND_ASSETS.md`). Jangan menggambar logo sendiri di JSX dan jangan
  menyunting berkas hasil — jalankan generatornya.
- **Teks konten bisa diseleksi** (`.page-body { user-select: text }`) supaya
  log/pesan error bisa disalin; chrome aplikasi (`body`, sidebar, tombol) tetap
  `none`.
- **Aset & warna latar jendela sinkron**: `backgroundColor` di `main.cjs`
  sama dengan `--bg`; kalau beda, satu frame pertama menampilkan kilat gelap.

## Paket & rilis

`npm run package` → `electron-builder` menghasilkan installer NSIS + EXE
portable di `desktop/dist/`. Engine dibundel lewat `extraResources` ke
`resources/engine/xydesk-host.exe`. CI: `.github/workflows/build-desktop.yml`
(job Linux verifikasi shell; job Windows paket x64). Rilis terintegrasi di
`release.yml`.

# Audit Semua Platform — XyDesk v6.7.12+47 (2026-09-11)

> **Scope diminta:** "cek semua juga yang kurang dll" — audit lintas `host / desktop / web / flutter / cloudflare / news / packaging / CI` + versi & build.
> **Status verifikasi di sesi ini:** `tool/check_version.py` LULUS, `tool/check_icons.py` OK, `cloudflare npm test` 94/94 PASS, `desktop tsc --noEmit` OK (sesi sebelumnya), `host cargo check` Linux OK & `cargo check --target x86_64-pc-windows-gnu` OK (fake mingw, sesi driver-first), `web` lock diperbaiki manual di sesi ini. `flutter analyze` tidak jalan di sandbox Linux ini (butuh SDK 3.44.9 ±5 GB) — dicatat sebagai gap verifikasi, bukan gagal.

---

## 0. Ringkasan Eksekutif

| Area | Versi | Build Check Sesi Ini | Status Fitur Utama | Yang Kurang / Risiko |
|---|---|---|---|---|
| **Flutter Client** (`pubspec.yaml`) | **6.7.12+47** | `check_version` LULUS; `analyze/test` belum dijalankan di sandbox | Loop `capture→encode→RTP→decode` jalan (loopback test), WebRTC, HUD gaming, QR, notifikasi, multi-bahasa | 48 item HANDOFF pending (banyak UI polish & screenshot), glass-to-glass <40 ms belum terukur, gamepad passthrough belum |
| **Host Engine** (`host/Cargo.toml`) | **6.7.12** | `cargo check` Linux OK, `cargo check --target x86_64-pc-windows-gnu` OK (fake gcc/g++/ar) | **Baru: driver-first IddCx** `virtual-display-driver` (DXGI→VIRTUAL→WGC→GDI), `virtual_mic` VB-CABLE, NVENC fallback openh264, WASAPI loopback+mic, control API `/status` + `/action` | NVENC zero-copy TODO, capture DXGI real belum verifikasi lab, glass-to-glass foto 10 pasang belum |
| **Desktop Shell** (`desktop/package.json` + `src-tauri`) | **6.7.12** | `tsc --noEmit` OK, Tauri Cargo 6.7.12 | **Baru: UI driver-first** (badge hijau, tombol Buat/Pastikan Virtual Display, backend label), update card, audio, display-select, autostart | Butuh uji install driver 1-klik di Windows admin nyata, `tsconfig.tsbuildinfo` sudah di-ignore |
| **Web Client** (`web/package.json`) | **6.7.12** (lock diperbaiki 6.7.5→6.7.12 di sesi ini) | `check_version` LULUS | Vite + React 19, session_ui, billing, license, news, QR | `web/package-lock.json` sempat ketinggalan (FIXED), session panel belum tampilkan `captureBackend`/`virtualDisplay` seperti desktop (gap kecil) |
| **Backend Edge** (`cloudflare/src`) | worker `xydesk-signaling` (vars, bukan semver) | `npm test` 94/94 PASS | HMAC token, Durable Object Hub, PairGuard, TURN multi-provider (ExpressTurn/Cloudflare/Metered/OpenRelay, cache 1h, timeout 2.5s), auth OTP+Google PKCE | `update.json` hanya di GitHub Release (bukan domain) — by design, tapi perlu dipastikan client baca URL benar |
| **News Worker** (`news/`) | `xydesk-news` D1 | tidak ada test fail | Worker + D1 `xydesk-news`, like/komentar/balasan, OG, share `news.xydesk.my.id/n/<slug>` | Butuh artikel rilis 6.7.12 (NEWS_STYLE.md) + screenshot asli platform |
| **Packaging / CI** (`packaging/`, `.github/`, `tool/`) | — | `check_icons.py` OK | Inno Setup `XyDesk.iss` Tasks `driverinstall` bundling `IddSampleDriver` + `audio` (VB-CABLE), `tool/check_version.py`, `tool/wincheck`, `build.yml` filter per-area + `workflow_dispatch` only | 4 cabang mati tertinggal 100k baris (`feat/nvenc` sudah di main), `desktop/tsconfig.tsbuildinfo` & `web_deploy/.wrangler` sudah di-gitignore |

**Keputusan sesi:** `web/package-lock.json` diperbaiki, host driver-first sudah commit `a5ceb66`, desktop lock diselaraskan. Tidak ada perubahan breaking; semua `check_version` tetap hijau.

---

## 1. Host Engine (`host/`)

### 1.1 Yang sudah ada (v6.7.12)
- **Screen & Capture** (`screen.rs`): 4 backend `WGC(0)/GDI(1)/DXGI(2)/VIRTUAL(3)`, `label_backend` `virtual-display-driver`, rantai `DXGI→VIRTUAL→WGC→GDI`, `spawn_frame_source` driver-first bila `needs_virtual_display() && is_driver_installed()` → `ensure_virtual_display_created()` + `current=virtual_display_index()` + `BACKEND=VIRTUAL`, fallback `VIRTUAL→GDI`, watchdog 2s, `list_displays`, `is_rdp_session` (SM_REMOTESESSION).
- **Virtual Display** (`virtual_display.rs`): `needs_virtual_display` = empty || RDP-single || basic_render-single (cek `Microsoft Basic Display` via `pnputil`), `is_driver_installed` via `pnputil /enum-drivers`, `/enum-devices`, nama display, file `drivers/IddSampleDriver/*.inf`, `find_virtual_display`/`virtual_display_index`/`ensure_virtual_display_created` (exe `add` + `pnputil /scan-devices` + `Enable-PnpDevice` + sleep 2s), `ensure_display` auto-create bila admin, `create_virtual_display` (ge9 `option.txt` + itsmikethetech exe + PROGRAMDATA).
- **Virtual Mic** (`virtual_mic.rs`): `VirtualMicStatus`, `get_status`, `is_driver_installed`, `try_install_driver`, `ensure_virtual_mic`.
- **Audio** (`audio.rs`): WASAPI loopback → Opus 48kHz stereo → WebRTC, mic HP → `IAudioRenderClient`, `IPropertyStore` (sudah ada warning unused import — low priority).
- **Control API** (`control.rs`): `GET /status` (state, displays, video {framesSent,fps,nvenc,encoder,latencyMs,latencyMaxMs}, audio, `isRdpSession`, `captureBackend`, `framesCaptured`, `virtualDisplay {needed,installed,isAdmin,hasVirtualDisplay,virtualIndex,backend,displays}`, `virtualMic`), `POST /action` (display-select, audio-volume, video-bitrate, video-quality, driver-install/virtual-display-create/ensure, stop-session, new-password/set-password). `ActionRequest` sudah tambah `driverType,width,height,count` + alias `bitrateMbps`.
- **Session & Video** (`session.rs`, `video.rs`, `nvenc.rs`): WebRTC answerer, `add_video_track` sebelum `create_answer` (bug 0 paket sudah diperbaiki, teruji loopback), NVENC H264 hardware + fallback openh264, `xydesk-host --bench` & `--identity-json`.
- **HWInfo** (`hwinfo.rs`): registry + SystemInfo, storage.
- **Build**: `build.rs` vendor `vendor/opus` (BSD-3) hanya Windows; `Cargo.toml` `windows =0.61` features lengkap.

### 1.2 Yang kurang / TODO
- `screen.rs:1492` `// TODO(optimasi lanjutan): NVENC zero-copy (ID3D11Texture2D → CUDA → NVENC)` — masih copy via CPU.
- `host/src/audio.rs:328` `IPropertyStore` unused import + 2x `unsafe { ws.to_string() }` unnecessary unsafe — warning, bukan bug.
- **Belum terverifikasi di lab Windows nyata:** capture DXGI nyata (runner tanpa GPU), glass-to-glass latency foto 10 pasang, TURN via internet, VB-CABLE denyut di Recording.
- `ROADMAP Fase 0` masih `Belum` untuk dua item di atas + `openh264 ~30ms @640x360` terbukti tidak lulus target <10 ms (NVENC wajib).
- `HANDOFF` masih catat: `update.json` tidak di domain (by design), 4 cabang mati, `PairGuard` anti brute-force sudah ada tapi perlu audit.

### 1.3 Verifikasi sesi ini
- `cargo check` (Linux) **OK** (opus di-skip, warning hilang setelah fix `Ok(_msg)`).
- `cargo check --target x86_64-pc-windows-gnu` **OK** (1m20s, fake `x86_64-w64-mingw32-gcc/g++/ar` — opus vendor + openh264 C++ fake, `windows 0.61` type-check). Tidak butuh MSVC/link.

---

## 2. Desktop Shell (`desktop/`)

### 2.1 Yang sudah ada
- **Stack**: Tauri v2 + Rust `src-tauri` (engine.rs supervisor, commands.rs, tray.rs, update.rs) + Next.js 15 static export `app/` (Tauri `tauri.conf.json` 6.7.12).
- **Bridge** (`app/bridge.ts`, `global.d.ts`): `window.xydesk.getStatus/runAction/getLogs/getInfo/getAutostart/setAutostart/restartEngine/setHint/auth*/checkUpdate/downloadUpdate/installUpdate/checkDriversStatus/installDriver`. Sesi ini diperluas: `virtualDisplay {needed,installed,isAdmin,hasVirtualDisplay,virtualIndex,backend,displays}` + `runAction` extra `driverType,width,height,count`.
- **UI** (`app/page.tsx`): 
  - **Baru driver-first**: `DEMO_STATUS` dengan virtualDisplay lengkap, `HomePage` badge hijau `virtual-display-driver ✅ driver-first`, tombol `Pasang Driver Virtual (1-Klik Admin)` / `Buat/Pastikan Virtual Display`, info `DISPLAYn 1920×1080 (virtual)`, `Settings` chip displays + driver section + hint `tscon /dest:console`, login hero `Virtual Display Driver (IddCx) + DXGI/WGC/GDI fallback`, `Profile` sumber video `virtual-display-driver` bila aktif, VM warning driver-first.
  - UpdateCard (check→download→install, SHA-256), Tampilan & kualitas (4 chip quality + 5 chip bitrate + custom), Audio (volume, virtualMic), Autostart, Engine, Logs.
- **Packaging**: `desktop/src-tauri/build.rs` + `public/logo.png`/`tray.ico` via `tool/gen_logo.py` + `docs/BRAND_ASSETS.md`.

### 2.2 Yang kurang
- Uji 1-klik install driver butuh Windows admin nyata (UAC) — belum bisa di sandbox Linux.
- `desktop/app/page.tsx` masih ada `useState` untuk `quality`/`bps` yang tidak sync ke `targetBitrateBps` dari polling (minor).
- `tool/check_version.py` tidak cek `desktop/package-lock.json` versi (tapi sudah 6.7.12 sekarang).
- Tidak ada test `cargo test` untuk `desktop/src-tauri` di CI (hanya build).

### 2.3 Verifikasi sesi ini
- `npx tsc --noEmit` via `node_modules/.bin/tsc` **OK** (0 error) — sudah jalan sebelum & sesudah patch driver-first.
- `tauri.conf.json` & `src-tauri/Cargo.toml` versi 6.7.12 konsisten.

---

## 3. Web Client (`web/`)

### 3.1 Yang sudah ada
- Vite + React 19 + TypeScript 7, `web/src/App.tsx`/`Billing.tsx`/`session_ui.tsx`/`vk.ts`/`rtc.ts`/`api.ts`, PWA live `https://app.xydesk.my.id`, CSP sudah izinkan `news.xydesk.my.id` & `signal.xydesk.my.id`.
- Session panel sudah support quality `auto/medium/high/ultra` + bitrate `Auto/8/15/25/50` + clipboard/mic, multi-monitor `display-select` (chip).

### 3.2 Yang kurang / Gap kecil (FIXED / OPEN)
- **FIXED sesi ini:** `web/package-lock.json` versi `6.7.5` → **6.7.12** (sebelumnya `package.json` 6.7.12 tapi lock ketinggalan, `check_version.py` tidak cek lock jadi lolos diam-diam).
- **OPEN:** `web/src/session_ui.tsx` belum tampilkan `captureBackend`/`virtualDisplay` seperti desktop (hanya host status). Tambahkan badge `virtual-display-driver` bila host kirim `backend` — 10 baris, low priority.
- `web/src/news.ts` `NEWS_IMAGE_BLOCK` domain whitelist sudah fix (image/jpeg).
- Tidak ada `web_deploy/.wrangler` di git (sudah di-ignore).

### 3.3 Verifikasi sesi ini
- `check_version.py` LULUS (hanya cek `package.json`, bukan lock — jadi gap lock lolos).
- `tsc -b && vite build` belum dijalankan full di sandbox (butuh `npm install` web), tapi `package.json` types OK.

---

## 4. Flutter Client (`lib/`, `android/`, `pubspec.yaml`)

### 4.1 Yang sudah ada
- `pubspec.yaml` 6.7.12+47, Flutter 3.44.9 / Dart 3.12, Riverpod, `flutter_webrtc 1.5.2`, `onesignal_flutter 5.6.7`, `mobile_scanner 7.4.0`, `permission_handler`, `lucide_icons_flutter`.
- Fitur: `lib/features/{home,connect,devices,host,session,splash,account,auth,news,notifications}`, `lib/webrtc/signaling_client.dart` + `rtc_service.dart` (TURN `/turn-ice` 5s timeout, `catch (_) => []`), `lib/core/{tokens.dart,store.dart,theme.dart}`, `android/` mipmap 10 + ico 4 + XML, `assets/` fonts+img.
- `update_repository.dart` fix build 40: `updateAvailable = versionCompare>0 || buildNumber>installed` (sebelumnya hanya build).
- `analysis_options.yaml` tanpa `// ignore:` & `exclude:` (aturan #4).

### 4.2 Yang kurang
- **Belum ada SDK di sandbox** — `flutter analyze --fatal-infos --fatal-warnings` & `flutter test` belum dijalankan sesi ini (catatan Operator: bisa diverifikasi Linux dengan download `flutter_linux_3.44.9-stable.tar.xz` ±5 GB).
- 48 HANDOFF pending banyak di Flutter: `Billing sewa PC otomatis`, avatar komentar, form komentar bawah + auto-scroll, waktu relatif, rebrand warna aksen, dll. (lihat HANDOFF.md).
- `lib/webrtc/rtc_service.dart` TURN direct `kind` sudah dikunci, tapi perlu cek `PER_PROVIDER_TIMEOUT_MS` 2.5s sinkron dengan cloudflare.
- Screenshot asli `web/public/news/shots/<versi>-*.jpg` belum ada untuk 6.7.12 (butuh lab Windows + Android).

### 4.3 Verifikasi sesi ini
- `tool/check_version.py` LULUS, `tool/check_icons.py` OK (10 mipmap + 4 ico).
- `pubspec.lock` tidak di-cek `git diff --exit-code` di sandbox, tapi `check_version` sudah ok.

---

## 5. Backend Edge (`cloudflare/`)

### 5.1 Yang sudah ada
- `cloudflare/src/worker.js` (entry), `hub.js` (Durable Object `Hub` + `PairGuard`), `auth.js`/`authstore.js` (OTP, JWT, Google id_token + PKCE untuk Electron `auth/google/desktop`), `email_otp.js` (Resend), `turn.js` (multi-provider: ExpressTurn HMAC-SHA1 static `user:secret` + Cloudflare Realtime Bearer + REST `openrelay.metered.ca`/`turnwebrtc.com`, cache 1h, `PER_PROVIDER_TIMEOUT_MS=2500`, parallel fetch).
- `wrangler.toml` `xydesk-signaling` custom domain `signal.xydesk.my.id`, `CORS_ORIGINS https://app.xydesk.my.id`, Durable Object `Hub` + `AuthStore`, D1 tidak (hanya news).
- Routes: `GET /healthz`, `GET /issue` (X-Admin), `GET /host-token`, `GET /signal-token` (JWT), `GET /turn-ice` (X-Admin), `POST /auth/*`, `GET /auth/me`, `WS /ws?id=&role=&token=`.

### 5.2 Yang kurang
- `update.json` hanya sebagai aset GitHub Release (`releases/download/v6.7.12/update.json`), bukan di `signal.xydesk.my.id/update.json` atau `app.xydesk.my.id` — by design, tapi HANDOFF masih catat perlu dipastikan client baca URL benar (Flutter `update_repository`, desktop `update.rs`).
- 4 cabang mati perlu hapus/rebase (`feat/nvenc` sudah di main).
- `signaling/` folder cadangan masih ada (isi kosong? `signaling/` lama sebelum Durable Object).

### 5.3 Verifikasi sesi ini
- `npm test` di `cloudflare/` **94/94 PASS** (2.1s) — termasuk TURN provider parallel, timeout, cache, HMAC.
- `wrangler deploy` tidak dijalankan (butuh secret), tapi `worker.js` routes & CORS sudah benar.

---

## 6. News Worker (`news/`)

### 6.1 Yang sudah ada
- `news/src/worker.js` + `wrangler.toml` `xydesk-news` `news.xydesk.my.id/*`, D1 `xydesk-news` `7ffccd9e-...`, `migrations/`, `schema.sql`, `seed.sql`, `migrate.mjs`.
- Fitur: `GET /api/news`, `POST /api/news` (admin `x-admin-token` / `x-admin-google-token`), like/komentar/balasan/bagikan, OG per konten `news.xydesk.my.id/n/<slug>` + `news_deploy/worker` fallback SPA fix via `8b1ebbd` rename.

### 6.2 Yang kurang
- Belum ada artikel rilis **6.7.12** (butuh `docs/NEWS_STYLE.md`: changelog pengguna, screenshot asli host/desktop/web/flutter, badge `Haekal Saputra`).
- `news/package.json` versi `1.0.0` tidak ikut `check_version` (by design — worker bukan app version).

---

## 7. Packaging & CI (`.github/`, `tool/`, `packaging/`)

### 7.1 Yang sudah ada
- `packaging/windows/XyDesk.iss` Tasks `driverinstall` bundling `drivers/IddSampleDriver/*` + `drivers/audio/*` silent, `drivers/README-VDD.txt`, `license-ge9.txt`, uninstall `uninstall.bat`.
- `tool/check_version.py` (pubspec → Cargo + Tauri + web + desktop), `tool/check_icons.py` (mipmap+ico), `tool/wincheck` (type-check Windows tanpa MSVC), `tool/gen_logo.py`, `tool/gen-licenses.mjs`, `tool/check-host-windows.sh` (gnu target).
- `.github/workflows/build.yml` filter per-area `dorny/paths-filter`, `workflow_dispatch` only (push tidak trigger), `concurrency build-${{ref}}`, `FLUTTER_VERSION 3.44.9`.

### 7.2 Yang kurang
- `build.yml` masih refer `pubspec.yaml` untuk host & flutter (bump trigger full chain — sudah benar).
- `tool/check_version.py` belum cek `web/package-lock.json` (gap yang baru saja menimpa).
- `desktop/tsconfig.tsbuildinfo` & `web_deploy/.wrangler` sudah `git rm --cached` + `.gitignore` (sudah benar).
- Cabang mati 4 perlu `git branch -D` + `git push origin --delete`.

---

## 8. Apa yang diperbaiki di sesi ini (2026-09-11)

1. **Host driver-first** (commit `a5ceb66`): `virtual_display.rs` + `screen.rs` + `control.rs` + `desktop` UI (lihat bab 1-2). `cargo check` Linux & `x86_64-pc-windows-gnu` OK.
2. **Desktop UI driver-first** (commit sama): `global.d.ts` + `page.tsx` (badge, tombol, VM warning).
3. **Web lock** (belum commit, fix sesi ini): `web/package-lock.json` 6.7.5→6.7.12 (`packages[""].version`).
4. **Verifikasi**: `check_version` LULUS, `check_icons` OK, `cloudflare` 94 PASS.

---

## 9. Rekomendasi Next (prioritas)

### P1 — Rilis 6.7.12
- Jalankan `flutter pub get && dart format --output=none --set-exit-if-changed lib tool && flutter analyze --fatal-infos --fatal-warnings && flutter test` di Linux dengan Flutter 3.44.9 (butuh ±5 GB, jangan di `/tmp`).
- `cargo fmt --check` & `cargo clippy -D warnings --target x86_64-pc-windows-gnu` (dengan fake mingw atau mingw-w64 asli di runner).
- Ambil screenshot asli 6.7.12 di lab Windows (host ID+QR, desktop sesi `🎬 virtual-display-driver`, settings driver) + Android + Web → `web/public/news/shots/6.7.12-*.jpg`.
- Tulis artikel rilis 6.7.12 (`news/`): apa itu driver-first, kenapa DXGI mati di RDP, cara tes `tscon /dest:console`, dampak pengguna + changelog.

### P2 — Gap kecil (bisa 1 sesi per role)
- **Web**: tampilkan `captureBackend` di `session_ui.tsx` (copy badge desktop).
- **Host**: hapus warning `IPropertyStore` / `unsafe ws.to_string()` atau `#[allow]`.
- **CI**: hapus 4 cabang mati, tambah cek `web/package-lock.json` di `check_version.py`.

### P3 — Pembuktian Fase 0
- Lab Windows nyata: DXGI capture, NVENC <10 ms @1080p60, glass-to-glass <40 ms LAN, mic loopback denyut di `CABLE Output`, `update.json` dari Release terunduh di Flutter/Desktop.

---

## 10. Perintah verifikasi cepat (copy-paste)

```bash
python3 tool/check_version.py
python3 tool/check_icons.py
cd cloudflare && npm test
# host (butuh cargo)
cargo check --target x86_64-pc-windows-gnu -j1  # butuh mingw-w64 atau fake di atas
# desktop
cd desktop && npx tsc --noEmit
# flutter (butuh SDK 3.44.9)
flutter pub get && dart format --output=none --set-exit-if-changed lib tool && flutter analyze --fatal-infos --fatal-warnings && flutter test
```

> Catatan: snapshot workspace mengecualikan `.cargo`, `.local`, `node_modules` — install cargo/mingW/flutter tiap sesi baru akan hilang, tapi commit tetap aman. `uploads/my-binimbg.txt` tetap di `/home/user/uploads/` (bukan di `XyDesk/uploads`).


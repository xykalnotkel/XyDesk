# Changelog XyDesk

Semua perubahan penting XyDesk dicatat di sini.
Format mengikuti [Keep a Changelog](https://keepachangelog.com/id/1.1.0/),
versi mengikuti [Semantic Versioning](https://semver.org/lang/id/).

> **Kebijakan baru 2026-09-07 (Founder Lock):** Changelog tidak digabung numpuk
> di satu file lagi. Setiap versi punya file sendiri di `changelogs/` — biar ga
> numpuk dan mudah dibaca. File ini hanya ringkasan + index. Detail lengkap ada
> di file per versi. Lihat `changelogs/README.md`.

Kebijakan rilis:
- Setiap update aplikasi **wajib menaikkan versi** (`pubspec.yaml X.Y.Z+NN`,
  `web`/`desktop` package.json, `host` Cargo.toml).
- Setiap rilis **wajib punya artikel Berita** dengan changelog yang jelas dan
  panjang (lihat `news/README.md` untuk alur penerbitan).
- **Berita dan changelog adalah dua hal berbeda.** File ini untuk tim dan
  untuk catatan GitHub Release. Berita di `news.xydesk.my.id` ditulis untuk
  pengguna: tanpa nama berkas, tanpa nomor versi di judul, tanpa daftar
  commit. Panduan lengkap nadanya ada di [`docs/NEWS_STYLE.md`](docs/NEWS_STYLE.md).
- File ini otomatis dilampirkan ke GitHub Release oleh `release.yml`.
- **Banner artikel wajib 3D glossy morphing + floating motion blur** —
  lihat `docs/NEWS_STYLE.md` §11.

## [Belum terbit]

## [6.7.7] - 2026-09-07

> Build 42. Fix CI Build 34170387236 — flutter analyze unused + host bitrate 0 auto.

### Diperbaiki
- **CI Build 34170387236**: 2 job gagal — `Analisis Statis Flutter` (unused _connecting, _ConnectingView, missing tokens import) + `Uji Logika Host` (bitrate 0 auto should be allowed). Fixed, 122 tests pass.
- Lihat detail di [6.7.7](./changelogs/6.7.7.md)

## [6.7.6] - 2026-09-07

> Build 41. Hotfix CI — format Dart + Rust + CHANGELOG + TURN direct kind. Build 6.7.5 gagal 4 jobs, fixed.

### Diperbaiki
- **CI Build 34169492118**: 4 job gagal — `Cek Lintas-Dokumen`, `Analisis Statis Flutter`, `Uji Logika Host Rust`, `Uji Backend`. Fixed.
- Lihat detail di [6.7.6](./changelogs/6.7.6.md)

## [6.7.5] - 2026-09-07

> Build 40. Web Perfection — Founder: "Sempurnakan web, serta jalur jalur dan lain lain okey? Gas"

### Ditambahkan
- **Web quality & bitrate UI** `web/src/session_ui.tsx`: `StreamQuality auto|medium|high|ultra`, `BitrateMbps 0|8|15|25|50`, `QUALITY_META`, `BITRATE_OPTIONS`, `DEFAULT_PREFS` quality auto bitrate 0. Tab Gambar: chips Otomatis/Sedang/Tinggi/Ultra + Otomatis/8/15/25/50 Mbps + live stats. Callback `onQuality`/`onBitrate` ke host via 0x0A/0x0B.
- **Host protocol 0x0A/0x0B** `host/src/input.rs` + `main.rs`: `VideoQuality(u8)` `VideoBitrate(u16)`, mapping quality auto→DEFAULT medium 8M high 15M ultra 25M, bitrate 0 auto else 1-50M.
- **Web rtc codec** `web/src/rtc.ts`: `InputCodec.quality()` `bitrateMbps()` + `RtcSession.setQuality/setBitrate`.
- **Hero 3D glossy morphing + floating motion blur** `web/src/style.css` + `App.tsx`: 3 orb radial glossy blur morph + 3 glass card 1080p60 LIVE 24ms NVENC backdrop blur motion blur, hero-glow-morph 9s, logo translateZ.
- **Routing /n/:slug** `web/src/App.tsx`: `currentRoute()` handle `/n/:slug` share short link `news.xydesk.my.id/n/:slug` + `/n` → `/news`. Static routes /, /connect, /download, /legal, /news, /billing, /news/:slug, /n/:slug verified.
- **Download ABI active** `web/src/App.tsx`: switcher active class dari localStorage `xydesk.download.arch`.

### Diperbaiki
- **NEWS_IMAGE_BLOCK domain** `web/src/App.tsx` + `desktop/app/page.tsx`: `app.xystudio.my.id` salah → `(app.)?xydesk.my.id` allow app.xydesk.my.id & xydesk.my.id, fix image block.
- **device.ts** `web/src/device.ts`: `XyDesk-Windows-x64-Setup.exe` → `XyDesk-x64.exe` / `XyDesk-arm64.exe` match RELEASE_BASE.
- **Panel sempit** `web/src/style.css`: `.spanel` min 460px calc(100%-108px) max 480 min 380 padding 20 gap 14 mobile 440px 92vw.
- **Prefs migration** `web/src/App.tsx`: spread DEFAULT untuk localStorage lama tanpa quality/bitrate.

### Build
- `web` vite 8.2.1 37 modules 295.69kB gzip 93.22kB SUCCESS
- `desktop` Next.js 15.1.6 4 static pages 15.8kB SUCCESS
- `host` Cargo.toml 6.7.5 + protocol 0x0A/0x0B ready
- `pubspec.yaml` 6.7.5+40, `web/package.json` 6.7.5, `desktop/package.json` 6.7.5

## Daftar versi (per file)

- [6.7.7](./changelogs/6.7.7.md) - 2026-09-07 — Fix CI flutter analyze + host bitrate 0 auto
- [6.7.6](./changelogs/6.7.6.md) - 2026-09-07 — Hotfix CI format + TURN direct
- [6.7.5](./changelogs/6.7.5.md) - 2026-09-07 — Web Perfection
- [6.7.4](./changelogs/6.7.4.md) - 2026-09-07 — License EN + Admin Auto + Simple Splash + Quality + Spacious Panel
- [6.7.3](./changelogs/6.7.3.md) - 2026-09-07 — Fix Android update + Session Loading + Banner lock + Changelog split
- [6.7.2](./changelogs/6.7.2.md) - 2026-09-07 — Virtual Display + Virtual Mic + NSIS auto-installer
- [6.7.1](./changelogs/6.7.1.md) - 2026-09-07 — Fix VM/RDP hitam + audio mati + UI desktop v3.0
- [6.7.0](./changelogs/6.7.0.md) - 2026-09-07 — DXGI utama, audio 0x88890008 fix, auth desktop
- [6.6.1](./changelogs/6.6.1.md) - 2026-09-06 — Fix layar hitam saat diam
- [6.6.0](./changelogs/6.6.0.md) - 2026-09-06 — Fix splash stuck + CSP web
- [6.5.4](./changelogs/6.5.4.md) - 2026-09-05
- [6.5.3](./changelogs/6.5.3.md) - 2026-09-04
- [6.5.2](./changelogs/6.5.2.md) - 2026-09-03
- [6.5.1](./changelogs/6.5.1.md) - 2026-09-02
- [6.5.0](./changelogs/6.5.0.md) - 2026-09-01
- [6.4.0](./changelogs/6.4.0.md) - 2026-08-30
- [6.3.0](./changelogs/6.3.0.md) - 2026-08-25
- [6.2.2](./changelogs/6.2.2.md) - 2026-08-20
- [6.2.1](./changelogs/6.2.1.md) - 2026-08-18
- [6.2.0](./changelogs/6.2.0.md) - 2026-08-15
- [6.1.0](./changelogs/6.1.0.md) - 2026-08-10
- [6.0.0](./changelogs/6.0.0.md) - 2026-08-01
- [2.5.0](./changelogs/2.5.0.md) - 2026-07-20
- [2.4.0](./changelogs/2.4.0.md) - 2026-07-15

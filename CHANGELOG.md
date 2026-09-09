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

### Diperbaiki
- **Unifikasi UI/UX tiga platform** (operator: web = acuan): token Paper mengikuti web — `bg #ffffff`,
  `overlay`/`input #f5f3ff`, `accent-soft` 10%; radius satu skala 8/12/16/20 + pil + tuts-3 (kartu = 16
  di semua platform); garis pemisah dihapus di desktop + web (kartu = bayangan, baris daftar = ubin
  overlay + gap, strip/tab = jalur input + tab putih, tabel = zebra/ubin, chip = isi overlay dengan
  aktif isi-lembut + teks dalam); switch desktop = trek `textLow @45%` tanpa outline + flat aksen saat
  on; aturan tersisa yang disengaja tercatat tertutup di `docs/DESIGN.md` ("Garis yang disengaja").
- **Installer Windows di-brand**: gambar wizard `wizard-image.bmp` (164×314) + `wizard-small.bmp` (55×55)
  dari logo asli — bukan lagi default polos Inno Setup.
- **Korupsi CSS web**: blok `@media` rusak di `web/src/style.css` (~L1067) dihapus; ~10 deklarasi yatim
  (`margin`, `padding`, `border`, `grid-*`) ikut terbuang, aturan `.sesi-panel h2` duplikat digabung.

### Ditambahkan
- **Updater desktop (PC)**: kartu "Pembaruan aplikasi" di Pengaturan — cek
  otomatis, unduh installer terverifikasi SHA-256, pasang lalu mulai ulang.
  Manifest `update.json` kini membawa kunci `windows` (x64/arm64).
- **Artikel arsip 6.5.2**: `changelog-v6-5-2` diterbitkan retroaktif —
  tidak ada lagi tautan versi yang 404.

### Diperbaiki
- **Tempel teks panjang dari HP**: dipecah otomatis per 2.000 karakter
  (tidak lagi dipotong host di 4.096).
- **Profil desktop**: versi & server kini tampil (kontrak `get_info`
  diluruskan; versi tidak lagi hardcode basi).
- **Label perangkat**: nama akun tampil di pesan pairing web; hub Go tidak
  lagi membuang `name`/`platform` saat relay.
- **`news/seed.sql`**: 5 alias slug diluruskan + 5 artikel lama ditarik dari
  produksi — repo kembali jadi cermin penuh.
- **`build-apk-only.yml`**: signing rilis + Google client id + hapus step
  license palsu (belum pernah jalan sebelum diperbaiki).
- **Ikon launcher kembali ke logo asli**: tile terang `#F5F3FF` + X ungu
  glossy di Android (legacy, adaptive, splash-safe), favicon web, dan
  semua `.ico` Windows. Akar masalahnya di generator (`tile` gelap
  dipanggang + sumber gelap diputihkan) sudah dicabut, dikunci gerbang CI
  `tool/check_icons.py` supaya tidak hitam ketiga kalinya.

## [6.7.12] - 2026-09-09

> Build 47. In-App Update Modal Portrait 3:4 AI, Background Android Notification Download, Splash Luminous Glow, Desktop Tauri v2 fixes, dan pembaruan README.

### Ditambahkan
- **In-App Update Experience (AI Portrait Modal 3:4)**: Dialog visual pembaruan murni rasio 3:4 portrait AI dengan elemen 3D gaming morphing, motion blur, dan tombol floating close `X`.
- **Background Download Progress Notification (Android)**: Notifikasi progress unduh APK pada drawer sistem Android, memungkinkan download tetap jalan di background.
- **Direct APK Install Flow**: Pemasangan langsung APK terverifikasi setelah unduhan selesai.
- **Splash Screen Luminous Ambient Glow (Flutter)**: Aura ambient bloom violet lembut di belakang logo watermark dengan kurva transisi halus.
- **README.md Komprehensif**: Penambahan badge status CI/CD lengkap, dukungan platform, matriks teknologi, dan panduan kontribusi komunitas.
- **Panduan Update Popup Guide (`docs/APP_UPDATE_POPUP_GUIDE.md`)**: Dokumentasi arsitektur, prompt template, dan alur notifikasi.

### Diperbaiki
- **Desktop Tauri v2 Config**: Konfigurasi bundle targets pada `desktop/src-tauri/tauri.conf.json` untuk stabilitas kompilasi release Windows x64 & arm64.
- **Inventaris Lisensi Pihak Ketiga**: Sinkronisasi seluruh dependensi lockfile ke 509 komponen resmi.

## [6.7.11] - 2026-09-07

> Build 46. Fix CI Build 34249803875 — Windows x64/arm64 3 errors PROPERTYKEY not found.

### Diperbaiki
- **CI Build 34249803875**: 2 job gagal — `Windows x64` + `Windows arm64` 3 errors PROPERTYKEY not found in PropertiesSystem, actually in Foundation. Fixed.
- Lihat detail di [6.7.11](./changelogs/6.7.11.md)

## [6.7.10] - 2026-09-07

> Build 45. Fix CI Build 34245728600 — Windows x64/arm64 cargo build 8 errors (Win32 not found, PROPERTYKEY, PWSTR).

### Diperbaiki
- **CI Build 34245728600**: 2 job gagal — `Windows x64` + `Windows arm64` cargo build 8 errors: `screen.rs` Win32 not found, `audio.rs` PROPERTYKEY not found, `audio.rs` PWSTR mismatched. Fixed with Foundation+Com features, ::windows absolute, PWSTR direct.
- Lihat detail di [6.7.10](./changelogs/6.7.10.md)

## [6.7.9] - 2026-09-07

> Build 44. Fix CI Build 34171262232 — Windows x64/arm64 cargo build errors (format, PropertiesSystem, GetSystemMetrics, Security/Threading).

### Diperbaiki
- **CI Build 34171262232**: 2 job gagal — `Windows x64` + `Windows arm64` cargo build release error 4 distinct: `screen.rs` format `{:.1}` no arg, `audio.rs` PropertiesSystem feature, `gdi.rs` GetSystemMetrics wrong module, `virtual_display.rs` Security/Threading features. Fixed.
- Lihat detail di [6.7.9](./changelogs/6.7.9.md)

## [6.7.8] - 2026-09-07

> Build 43. Fix CI Build 34170927923 — flutter seamless Divider + clippy single_element_loop.

### Diperbaiki
- **CI Build 34170927923**: 2 job gagal — `Verifikasi aturan seamless` (Divider) + `Clippy single_element_loop`. Fixed.
- Lihat detail di [6.7.8](./changelogs/6.7.8.md)

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

- [6.7.11](./changelogs/6.7.11.md) - 2026-09-07 — Fix CI Windows PROPERTYKEY Foundation
- [6.7.10](./changelogs/6.7.10.md) - 2026-09-07 — Fix CI Windows cargo build 8 errors (Win32, PROPERTYKEY, PWSTR)
- [6.7.9](./changelogs/6.7.9.md) - 2026-09-07 — Fix CI Windows cargo build 4 errors
- [6.7.8](./changelogs/6.7.8.md) - 2026-09-07 — Fix CI seamless Divider + clippy
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

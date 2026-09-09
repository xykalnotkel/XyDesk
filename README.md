# XyDesk

<div align="center">

<img src="design/logo-asli.png" width="128" height="128" alt="XyDesk Logo" />

### *PC kamu, di tangan kamu.*
**Aplikasi Remote Desktop Ultra-Low Latency untuk Gaming dan Produktivitas**
*Gaya Visual **Quiet Surface** — Clean, Modern, Elegan, dan Tanpa Garis Pemisah.*

---

[![Build Status](https://img.shields.io/github/actions/workflow/status/xykalnotkel/XyDesk/build.yml?branch=main&label=CI%2FCD%20Build&logo=githubactions&logoColor=white&style=flat-square)](https://github.com/xykalnotkel/XyDesk/actions/workflows/build.yml)
[![Release Version](https://img.shields.io/github/v/release/xykalnotkel/XyDesk?display_name=tag&sort=semver&label=Release&logo=github&logoColor=white&color=7c3aed&style=flat-square)](https://github.com/xykalnotkel/XyDesk/releases)
[![Signaling Status](https://img.shields.io/github/actions/workflow/status/xykalnotkel/XyDesk/deploy-signaling.yml?label=Signaling%20Edge&logo=cloudflare&logoColor=white&style=flat-square)](https://signal.xydesk.my.id)
[![News Status](https://img.shields.io/github/actions/workflow/status/xykalnotkel/XyDesk/deploy-news.yml?label=News%20Worker&logo=cloudflarepages&logoColor=white&style=flat-square)](https://news.xydesk.my.id)
[![Web Client](https://img.shields.io/badge/Web_Client-Live-success?logo=googlechrome&logoColor=white&style=flat-square)](https://app.xydesk.my.id)

[![Flutter](https://img.shields.io/badge/Client-Flutter_3.44+-02569B?logo=flutter&logoColor=white&style=flat-square)](https://flutter.dev)
[![Rust](https://img.shields.io/badge/Host_Engine-Rust_1.80+-000000?logo=rust&logoColor=white&style=flat-square)](host/)
[![Tauri](https://img.shields.io/badge/Desktop_Shell-Tauri_v2-24C8D5?logo=tauri&logoColor=white&style=flat-square)](desktop/)
[![TypeScript](https://img.shields.io/badge/Web_&_Edge-TypeScript_5-3178C6?logo=typescript&logoColor=white&style=flat-square)](web/)
[![Cloudflare](https://img.shields.io/badge/Edge_Infrastructure-Workers_+_D1_+_DO-F38020?logo=cloudflare&logoColor=white&style=flat-square)](cloudflare/)
[![WebRTC](https://img.shields.io/badge/Protocol-WebRTC_DTLS--SRTP-333333?logo=webrtc&logoColor=white&style=flat-square)](https://webrtc.org)
[![OneSignal](https://img.shields.io/badge/Push_Notifications-OneSignal-E53935?logo=onesignal&logoColor=white&style=flat-square)](https://onesignal.com)
[![Resend](https://img.shields.io/badge/Email_Service-Resend-000000?logo=resend&logoColor=white&style=flat-square)](https://resend.com)
[![License](https://img.shields.io/badge/License-Proprietary-blueviolet?style=flat-square)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](https://github.com/xykalnotkel/XyDesk/pulls)

</div>

---

## 🌟 Sorotan Fitur Utama

- **🚀 Ultra-Low Latency Streaming**: Pipeline tangkapan layar DXGI / GDI hardware-accelerated di Windows, enkripsi P2P WebRTC DTLS-SRTP, fallback TURN otomatis (ExpressTurn + Cloudflare ber-TTL), dan latensi end-to-end teroptimasi untuk gaming.
- **🎮 In-Session Gaming HUD & Haptic Virtual Controller**: Kontrol overlay ABXY & D-pad virtual berhaptik mikro, keyboard mekanis virtual dengan modifier sticky, dan gesture switch intuitif.
- **🔄 In-App Update Experience (AI Portrait Modal)**: Dialog visual pembaruan rasio 3:4 portrait AI modern, progress unduh di latar belakang via Android system tray push notification, dan instalasi instan direct-to-package-installer.
- **🖥️ Multi-Platform Native Architecture**:
  - **Android Client**: Flutter native dengan rendering WebRTC hardware decoder, Picture-in-Picture (PiP), dan sensor adaptif.
  - **Windows Host & Desktop Shell**: Rust supervisor engine yang ringan dipadukan dengan cangkang modern Tauri v2 + Next.js.
  - **Web Client**: Aplikasi web PWA modern di `https://app.xydesk.my.id` yang siap diakses dari peramban mana pun tanpa instalasi.
- **📺 Multi-Monitor & Audio Loopback**: Pindah layar live antar monitor tanpa memutus sesi, capture audio loopback WASAPI stereo berdefinisi tinggi, dan mikrofon passthrough dua arah.
- **🔒 Keamanan & Zero-Trust Pairing**: Autentikasi OTP email, Google OAuth terverifikasi, HMAC token gerbang signaling, perlindungan anti brute-force pairing (*PairGuard*), dan sesi tunggal anti-ambil alih.
- **✨ Desain "Quiet Surface"**: Nol garis pemisah Material (zero `Divider`), kontras lembut berbasis elevasi ruang, palet warna Paper terang, dan aksen ungu violet 3D-glossy.

---

## 📊 Matriks Platform & Unduhan Rilis

| Platform | Format Berkas | Deskripsi Target |
|---|---|---|
| **Android 64-bit** | `XyDesk-Android-arm64-v8a.apk` | Smartphone dan tablet Android modern (64-bit) |
| **Android 32-bit** | `XyDesk-Android-armeabi-v7a.apk` | Perangkat Android ARMv7 legasi |
| **Windows x64** | `XyDesk-x64.exe` | Laptop & PC Windows Intel/AMD 64-bit (Setup + Engine) |
| **Windows Arm64** | `XyDesk-arm64.exe` | Windows on Arm (Snapdragon X Elite / SQ3 / Surface Pro) |
| **Web Client** | Web App PWA | Akses instan di [app.xydesk.my.id](https://app.xydesk.my.id) |

Seluruh artefak rilis resmi otomatis diverifikasi dengan checksum `SHA256SUMS.txt` dan manifest terenkripsi `update.json`.

---

## 🏗️ Arsitektur Sistem

```
┌────────────────────────────────────────────────────────┐
│               XyDesk Signaling & Edge API              │
│       (Cloudflare Workers + Durable Objects + D1)      │
│  - signal.xydesk.my.id (WebSocket DO Room & PairGuard) │
│  - news.xydesk.my.id   (Umpan Berita & Komentar D1)    │
└───────────────────────────┬────────────────────────────┘
                            │
               SDP Offer / Answer & ICE Candidate
                            │
       ┌────────────────────┴────────────────────┐
       ▼                                         ▼
┌───────────────────────────┐         ┌───────────────────────────┐
│     XyDesk Client         │         │      XyDesk Host          │
│   (Android / Web / PC)    │◄───────►│  (Windows Rust Engine)    │
│  - Flutter WebRTC Video   │  P2P    │  - DXGI Desktop Dupl.     │
│  - Audio Track Renderer   │  DTLS   │  - WASAPI Audio Capture   │
│  - Gaming HUD / Virtual KB│  SRTP   │  - Virtual Display & Mic  │
└───────────────────────────┘  Media  └───────────────────────────┘
```

---

## 💻 Memulai Pengembangan Lokal

### Prasyarat
- **Flutter SDK**: `3.44.9+` (Channel Stable) & **Dart**: `3.12+`
- **Rust**: `1.80+` (Toolchain stable with `x86_64-pc-windows-msvc` / `aarch64-pc-windows-msvc`)
- **Node.js**: `v20+` atau `v24` & **npm**: `10+`

### 1. Menjalankan Aplikasi Flutter (Android)
```bash
# Pasang dependensi Flutter
flutter pub get

# Jalankan pengujian unit & analisis statis
flutter analyze --fatal-infos --fatal-warnings
flutter test

# Jalankan di emulator / perangkat fisik
flutter run
```

### 2. Membangun Host Engine (Rust)
```bash
cd host
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
cargo build --release
```

### 3. Menjalankan Web Client & Desktop Shell
```bash
# Menjalankan Web Client (Vite + React)
cd web
npm ci
npm test
npm run dev

# Menjalankan Desktop Shell (Tauri v2 + Next.js)
cd ../desktop
npm ci
npm test
npm run tauri dev
```

---

## 🎨 Pedoman Desain & Kualitas Kode

- **Zero Divider Line**: Dilarang menyisipkan `Divider()` atau `VerticalDivider()`. Pemisah visual murni menggunakan jarak token `Gap` (16dp, 24dp, 32dp) dan gradasi permukaan `FadeEdge`.
- **High Transparency Assets**: Seluruh ilustrasi diuji otomatis oleh `tool/audit_assets.py` untuk memastikan kompatibilitas tema dan transparansi tepi yang bersih.
- **Konsistensi Lintas-Dokumen**: Nomor versi di seluruh manifest (`pubspec.yaml`, `host/Cargo.toml`, `desktop/src-tauri/tauri.conf.json`, `web/package.json`, dan `CHANGELOG.md`) divalidasi secara ketat oleh `tool/check_version.py`.
- **Inventaris Lisensi Pihak Ketiga**: Seluruh dependensi tercatat dan terverifikasi secara hukum di [`docs/THIRD-PARTY-LICENSES.md`](docs/THIRD-PARTY-LICENSES.md).

---

## 🤝 Kontribusi & Kolaborasi

Kami menyambut hangat kontribusi, diskusi teknis, pelaporan bug, dan ide fitur dari komunitas pengembang!

### Cara Berkontribusi:
1. **Fork Repositori**: Buat salinan repo di akun GitHub Anda.
2. **Buat Branch Fitur**: `git checkout -b feature/fitur-keren-anda`
3. **Patuhi Standar Mutu**: Pastikan `flutter analyze`, `cargo clippy`, dan seluruh test suite lulus 100%.
4. **Format Kode**: Jalankan `dart format lib tool` dan `cargo fmt`.
5. **Kirim Pull Request**: Buka PR dengan deskripsi yang jelas dan alasan perubahan.

---

## 👥 Tim & Kontributor

<div align="center">

Dibuat dan dipelihara dengan dedikasi tinggi oleh:

**Haekal Saputra** (*Founder & Lead Developer*) — [@xykalnotkel](https://github.com/xykalnotkel)  
*Dan seluruh kontributor komunitas open-source yang luar biasa.*

[![GitHub Contributors](https://img.shields.io/github/contributors/xykalnotkel/XyDesk?color=7c3aed&style=flat-square)](https://github.com/xykalnotkel/XyDesk/graphs/contributors)
[![GitHub Forks](https://img.shields.io/github/forks/xykalnotkel/XyDesk?style=flat-square)](https://github.com/xykalnotkel/XyDesk/network/members)
[![GitHub Stars](https://img.shields.io/github/stars/xykalnotkel/XyDesk?style=flat-square)](https://github.com/xykalnotkel/XyDesk/stargazers)
[![GitHub Issues](https://img.shields.io/github/issues/xykalnotkel/XyDesk?style=flat-square)](https://github.com/xykalnotkel/XyDesk/issues)

</div>

---

## 📄 Lisensi

Kode sumber XyDesk dilindungi hak cipta dan didistribusikan di bawah lisensi resmi **XyDesk Proprietary License** (lihat [`LICENSE`](LICENSE)).  
Rincian atribusi lisensi perangkat lunak pihak ketiga tersedia di [`docs/THIRD-PARTY-LICENSES.md`](docs/THIRD-PARTY-LICENSES.md) serta pada menu **Legal & Lisensi** di seluruh klien aplikasi.

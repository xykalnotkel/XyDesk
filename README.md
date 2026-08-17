# XyDesk

Aplikasi remote desktop low-latency untuk **gaming dan kerja**.
Gaya visual **Quiet Surface** — clean, modern, tanpa satu pun garis pemisah.

[![Build](https://github.com/xykalnotkel/XyDesk/actions/workflows/build.yml/badge.svg)](https://github.com/xykalnotkel/XyDesk/actions/workflows/build.yml)
[![Host](https://github.com/xykalnotkel/XyDesk/actions/workflows/build-host.yml/badge.svg)](https://github.com/xykalnotkel/XyDesk/actions/workflows/build-host.yml)
[![Signaling](https://github.com/xykalnotkel/XyDesk/actions/workflows/deploy-signaling.yml/badge.svg)](https://github.com/xykalnotkel/XyDesk/actions/workflows/deploy-signaling.yml)
[![Release](https://img.shields.io/github/v/release/xykalnotkel/XyDesk?display_name=tag&sort=semver)](https://github.com/xykalnotkel/XyDesk/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.44%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Rust](https://img.shields.io/badge/Host-Rust-000000?logo=rust&logoColor=white)](host/)
[![Cloudflare](https://img.shields.io/badge/Edge-Cloudflare_Workers-F38020?logo=cloudflare&logoColor=white)](cloudflare/)
[![License](https://img.shields.io/github/license/xykalnotkel/XyDesk)](LICENSE)

---

## Status

Lapisan WebRTC client kini tersambung ke layar sesi: setelah login dan pairing
diterima host, `RTCVideoView` menampilkan video host dan input (trackpad +
keyboard virtual) terkirim lewat data channel biner. Tanpa login (mode tamu)
layar sesi berjalan sebagai preview dengan status transport yang jujur.
Yang belum terbukti: capture layar nyata di host (masih pola uji) dan angka
latency end-to-end.

| Bagian | Status |
|---|---|
| Design system & tema | Selesai |
| Home, Connect, Akun, Tentang | Selesai |
| Layar sesi + loading bertahap | Selesai |
| Panel gaming dua sisi (7 kategori) | Selesai |
| Keyboard virtual (modifier sticky) | Selesai |
| Glyph HUD (mouse, gulir, arah, switch) | Selesai |
| CI/CD GitHub Actions | Selesai |
| Web client (Vite + React, Cloudflare) | Deploy otomatis — `app.xystudio.my.id` |
| Signaling server (Cloudflare Workers + DO) | Live — `signal.xystudio.my.id` |
| Autentikasi (OTP email + JWT + Google OAuth) | Live di Worker; JWT dan OTP punya test otomatis |
| Gerbang signaling | Role terikat HMAC, relay client-host divalidasi, daftar host global ditutup |
| TURN (kredensial Cloudflare ber-TTL) | Selesai |
| Host app (Rust: capture DXGI + openh264 + webrtc-rs) | Jalur encode→RTP→decode tersedia; capture nyata belum selesai |
| Wiring `RTCVideoView` di client Flutter | Selesai — `lib/webrtc/` tersambung ke `SessionPage` |
| Benchmark latency end-to-end di jaringan nyata | Belum — prioritas berikutnya |

---

## Menjalankan

```bash
flutter pub get
flutter run
```

Butuh Flutter **3.44+** / Dart 3.5+.

```bash
flutter analyze           # pemeriksaan statis
dart format lib           # rapikan source sebelum push
```

GitHub Actions menjalankan analisis Flutter, test keamanan Worker, test unit
host Rust, pemeriksaan format/lint, serta build target. APK/EXE hasilnya tetap
diuji manual untuk perilaku perangkat nyata.

---

## Struktur

```
lib/
├── main.dart                     # edge-to-edge + ProviderScope
├── app.dart                      # shell + bottom-nav seamless
├── core/
│   ├── tokens.dart               # warna, jarak, radius, durasi
│   └── theme.dart                # ThemeData — semua garis dimatikan di sini
├── widgets/
│   ├── seamless.dart             # SeamlessScaffold, SurfaceCard, FadeEdge
│   └── hud_glyphs.dart           # 20 glyph CustomPainter
└── features/
    ├── home/                     # daftar perangkat
    ├── connect/                  # ID + kata sandi + blok dukungan
    ├── account/                  # akun & halaman Tentang
    └── session/
        ├── session_page.dart     # sesi, loading, overlay auto-hide
        ├── session_panels.dart   # bilah kiri + panel kategori kanan
        └── virtual_keyboard.dart # keyboard penuh, radius 3dp
```

---

## Keputusan Desain yang Perlu Diketahui

Ini bukan preferensi acak — masing-masing ada alasannya.

**Nol garis pemisah.** Semua sumber garis Material dimatikan di `theme.dart`:
`surfaceTintColor` transparan, `scrolledUnderElevation: 0`, dan `DividerTheme`
transparan. Pemisahan visual memakai jarak minimal 24dp dan gradasi `FadeEdge`.
CI memverifikasi ini otomatis — kalau ada yang menambahkan `Divider()`, build
gagal.

**Item nav aktif berwarna putih, bukan aksen.** Kalau ikon aktif ikut biru,
satu layar punya dua titik perhatian. Cukup pil `accentSoft` di belakangnya.

**Tombol keyboard tidak berubah warna saat ditekan** — hanya sedikit lebih
terang. Kilatan biru berulang melelahkan saat mengetik cepat. Hanya modifier
sticky yang memakai aksen, karena statusnya memang perlu terlihat.

**Radius tombol keyboard 3dp.** Radius besar membuatnya terlihat seperti
mainan; 3dp terasa presisi seperti keyboard mekanis.

**HUD border-only.** Isi sepenuhnya transparan, hanya garis 1,5px putih 34%.
Piksel game di dalam tombol tetap terlihat. Saat ditekan hanya diisi 14%.

**Glyph HUD memakai CustomPainter, bukan teks.** Karakter seperti `↑↓` dan `⇄`
dirender berbeda di tiap font dan OS. Dengan painter, ketebalan garis bisa
diubah 1,5px → 3px untuk mode kontras tinggi tanpa mengubah bentuk.

**Rotasi landscape terjadi sebelum layar loading muncul.** Kalau dibalik, ada
kedipan orientasi yang membuat aplikasi terasa murah.

**Loading connect menampilkan waktu tiap tahap.** Kegagalan koneksi remote
desktop punya belasan penyebab. Dengan waktu per tahap, user dan tim dukungan
langsung tahu macetnya di penemuan host, autentikasi, atau NAT.

---

## Build dan Release Otomatis

Push ke `main` menjalankan analisis statis serta build Android, Windows, dan Web.
Artefak build biasa tersedia melalui tab **Actions**.

| Target | Artefak Release | Status |
|---|---|---|
| Android 64-bit | `XyDesk-Android-arm64-v8a.apk` | HP Android modern |
| Android 32-bit | `XyDesk-Android-armeabi-v7a.apk` | Perangkat ARMv7 lama |
| Windows x64 | `XyDesk-Windows-x64.zip` | PC Intel/AMD 64-bit |
| Windows Arm64 | `XyDesk-Windows-arm64.zip` | Windows on Arm |
| Windows host x64 | `XyDesk-Host-x64.exe` | Host Intel/AMD 64-bit |
| Windows host Arm64 | `XyDesk-Host-arm64.exe` | Host Windows on Arm |
| Web | `XyDesk-Web.zip` | Bundle web client (Vite + React) |

Bundle Web dari Build `main` yang sukses juga dideploy otomatis ke Cloudflare
Workers Static Assets di `https://app.xystudio.my.id`; frontend ini tetap
berkomunikasi dengan Worker API/signaling di `https://signal.xystudio.my.id`.

GitHub Release tidak dibuat pada setiap push. Release baru hanya berjalan
setelah workflow Build sukses dan nilai `version` di `pubspec.yaml` berubah.
Workflow menerbitkan checksum serta manifest `update.json`, lalu mengirim push
OneSignal hanya ke Android dengan build lebih lama.

Detail trigger, signing, aset, dan secret CI ada di
[`docs/CI.md`](docs/CI.md).

---

## Langkah Berikutnya

1. Selesaikan capture DXGI nyata dan ukur latency end-to-end pada jaringan target.
2. Ikat registrasi host ke pemilik akun agar daftar perangkat privat dapat
   dikembalikan tanpa membocorkan ID lintas akun.
3. Terapkan PAKE untuk pairing agar password tidak pernah dikirim lewat relay.
4. Tambahkan test codec input Flutter dan test protokol signaling Go.

> **Catatan jujur:** bagian tersulit bukan UI, melainkan **latency dan NAT
> traversal**. Buat PoC `capture → encode → WebRTC → decode` lebih dulu dan
> ukur angkanya. Kalau tidak tembus di bawah 40 ms pada jaringan target,
> posisi "cocok untuk game" harus dievaluasi ulang sebelum UI dipoles.

Dokumen arsitektur, protokol, keamanan, CI, dan keputusan produk ada di folder
[`docs/`](docs/).

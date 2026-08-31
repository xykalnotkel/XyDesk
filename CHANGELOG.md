# Changelog XyDesk

Semua perubahan penting XyDesk dicatat di sini.
Format mengikuti [Keep a Changelog](https://keepachangelog.com/id/1.1.0/),
versi mengikuti [Semantic Versioning](https://semver.org/lang/id/).

Kebijakan rilis:
- Setiap update aplikasi **wajib menaikkan versi** (`pubspec.yaml X.Y.Z+NN`,
  `web`/`desktop` package.json, `host` Cargo.toml).
- Setiap rilis **wajib punya artikel Berita** dengan changelog yang jelas dan
  panjang (lihat `news/README.md` untuk alur penerbitan).
- File ini otomatis dilampirkan ke GitHub Release oleh `release.yml`.

## [6.2.0] - 2026-09-01

> Rilis kejujuran. Tidak ada fitur media baru di sini; yang berubah adalah
> apa yang produk ini **katakan tentang dirinya sendiri** — status rilis,
> nomor versi, daftar lisensi, dan siapa yang berbicara di kolom komentar.
> Tombol unduh sengaja dimatikan sampai gerbang beta di `docs/VERSIONING.md`
> lulus.

### Ditambahkan

- **Gerbang tahap rilis terpusat** (`lib/core/release_stage.dart`,
  `web/src/version.ts`). Satu konstanta menentukan apakah produk berstatus
  pra-beta, beta, atau stabil; UI membaca darinya, bukan menebak.
- **Inventaris lisensi lengkap yang dibangkitkan mesin** (`tool/gen-licenses.mjs`).
  Memindai `pubspec.lock`, `Cargo.lock`, dan `package-lock.json` di empat
  workspace, lalu menulis `docs/THIRD-PARTY-LICENSES.md` dan
  `web/src/licenses.generated.ts`. Hasil: **482 komponen** — sebelumnya
  halaman legal hanya menyebut 9 di web dan 18 di aplikasi.
- **Registry lisensi bawaan Flutter** di layar Tentang → Lisensi. Membaca
  berkas LICENSE dari biner yang sedang berjalan, jadi mustahil basi.
- **Badge penulis resmi** di berita dan komentar (web + Android). Nama tim
  didampingi logo XyDesk dan label "Resmi".
- **`docs/VERSIONING.md`** — kebijakan versi dan rilis yang mengikat.
- **`tool/gen_logo.py`** — logo dibangkitkan dari kode untuk seluruh 20+
  ukuran sekaligus.
- **`news/test/comments.test.js`** — 6 uji yang memastikan badge resmi tidak
  bisa diminta klien.

### Diubah

- **Tombol Download dimatikan** di seluruh permukaan web. Halaman Unduh kini
  menampilkan status rilis sebenarnya dan enam syarat yang harus lulus dulu.
- **Menekan Connect langsung membuka layar sesi** dengan status "Menyambung…".
  Halaman perantara `PairSuccessPage` dihapus.
- **Splash screen** dirombak: durasi 1250 ms, rel progres nyata, dan chip
  tahap rilis + versi.
- **Panel Riwayat** di halaman Connect diberi ruang napas dan hierarki.
- **Nomor versi punya satu sumber**: `pubspec.yaml`. Vite membacanya saat
  build; footer web tidak lagi memajang angka yang diketik tangan.
- **Ikon Android**: lapisan foreground adaptive icon kini berukuran 108dp
  yang benar (432 px di xxxhdpi), bukan 192 px yang di-upscale peluncur.

### Diperbaiki

- **Paragraf artikel tidak lagi hilang.** `adminPublish` memakai `clean()`
  yang meratakan semua whitespace, sehingga artikel yang diterbitkan lewat API
  menjadi satu blok tanpa jeda — hanya artikel dari `seed.sql` yang punya
  paragraf. Kini ada `cleanBody()` yang mempertahankan pemisah paragraf.
- **Nama tim tidak bisa dipakai orang lain.** Komentar publik dengan nama yang
  menyerupai anggota tim (termasuk penyamaran spasi dan tanda baca) ditolak
  403, bukan sekadar tampil tanpa badge.
- Tautan **GitHub Releases dihapus dari footer**, diganti tautan Lisensi
  Pihak Ketiga.

### Keamanan

- Kolom `official` hanya bisa disetel server saat `x-admin-token` cocok
  dengan `ADMIN_TOKEN`. Body request tidak pernah dipercaya; mengirim
  `official: true` tidak berpengaruh apa pun (diuji).
- Slug yang bisa ditentukan sendiri dibatasi pada pola
  `changelog-v<major>-<minor>-<patch>` saja.

### Yang masih belum

Disebut terbuka supaya tidak ada yang mengira sudah selesai:

- Layar sesi, HUD kontrol, mouse dan keyboard virtual **belum terverifikasi**
  mengendalikan host sungguhan. Butuh PC Windows nyata.
- Audio WASAPI dan multi-monitor DXGI belum diuji dengar/lihat di perangkat keras.
- Push notifikasi belum dibuktikan terkirim dan terbuka di perangkat uji.
- Latency ujung-ke-ujung di jaringan nyata belum terukur.

## [6.1.0] - 2026-08-31

> Rilis ini menyentuh jalur media HOST (Rust) — biner host & APK/EXE client
> dibangun oleh CI Windows; verifikasi perilaku audio/multi-monitor di lab
> Windows nyata adalah langkah uji berikutnya yang sudah disiapkan.

### Ditambahkan
- **Audio forward (host → client)**: modul baru `host/src/audio.rs` — WASAPI
  loopback (semua bunyi output PC) → encode Opus 48 kHz stereo 96 kbps →
  track audio WebRTC. Aktif otomatis di Windows; jalur non-Windows
  melaporkan "belum didukung" dengan jujur.
- **Mic passthrough (client → host)**: track audio client (getUserMedia)
  diterima host, didecode Opus, dan diputar ke perangkat output default via
  `IAudioRenderClient` — suara mic terdengar di speaker PC host.
- **Multi-monitor**: enumerasi display via GDI (`EnumDisplayMonitors`) di
  control API; pemilihan layar dari client (event biner 0x07) memindahkan
  capture LANGSUNG — thread capture di-respawn dengan monitor baru
  (`windows_capture::Monitor::from_index`, fallback ke primer).
- **Meta host → client** lewat data channel input: daftar layar (nama +
  resolusi), layar terpilih, dan status pipeline audio — dipakai UI untuk
  pemilih monitor & label jujur.
- **Kontrol volume master** di control API host (aksi `audio-volume`).
- **Sesi web**: elemen audio terpisah untuk suara sistem host, tombol
  Audio/Mic di HUD, dan pemilih layar bila host punya >1 monitor.
- **Sesi Android**: pemutar audio remote (RTCVideoView 1×1), quick-dock
  Audio/Mik kini BENAR-BENAR mengaktifkan jalur RTC (transceiver direction /
  getUserMedia), pemilih layar chip di atas quick dock.
- **CHANGELOG.md** — wajib di-update setiap rilis; dilampirkan ke Release.
- **Tanda tangan email premium**: email berita kini memakai badge XySpace +
  nama pengirim **Haekal Saputra (XySpace)**.

### Diubah
- Splash direvisi ulang: cahaya ungu lembut + tile logo + wordmark gradient
  ungu + letter-spacing mengendur — koreografi 1700 ms satu kurva
  (easeOutQuart), tanpa animasi berlebihan.
- Status media panel sesi: audio/mic tidak lagi "belum tersedia" —
  `SessionMediaCapabilities` mencatat jalur aktif dengan catatan jujur
  (mic diputar di speaker host; endpoint mikrofon virtual Windows menyusul).
- Versi: Android **6.1.0+21**, Web **6.1.0**, Desktop **6.1.0**, Host **6.1.0**.

### Dependensi baru
- **libopus 1.5.2** (host, Windows) — di-vendor di `host/vendor/opus`
  (BSD-3-Clause) dan dikompilasi statis oleh `build.rs` + `cc`. Sengaja
  TIDAK memakai crate `opus`: `audiopus_sys`-nya membangun libopus via
  CMake lawas yang ditolak runner Windows modern. API dibungkus di
  `host/src/opus_ffi.rs` (encoder/decoder 48 kHz stereo).
- Pemanfaatan API WASAPI tambahan (windows crate) — `audio.rs`.

## [6.0.0] - 2026-08-31

### Ditambahkan
- Identitas visual: ungu menonjol sebagai warna khas di semua platform.
- Logo X tile seperti sampul berita (tanpa glow/bayangan) di web, Flutter,
  splash native; og-image & sampul berita digambar ulang.
- Push notifikasi jalur server: artikel baru memicu push OneSignal + email
  Resend (endpoint admin `waitUntil`, slug hash acak UUID).
- Balas komentar (satu tingkat), username acak per perangkat (tanpa kolom
  nama), like optimistik, langganan email berita.
- Navigasi Android: geser kiri-kanan berpindah tab; tekan kembali 2× untuk
  keluar aplikasi (PopScope + snackbar).
- `docs/LEGAL.md` — EULA proprietary, kebijakan privasi, S&K, tabel lisensi
  pihak ketiga per platform.

### Diubah
- Lisensi proyek: **proprietary** (EULA, larangan clone/reverse-engineering).
- Splash ditulis ulang (1800 ms, tile + garis aksen).

### Diperbaiki
- Berita web "Failed to fetch" — CSP belum mengizinkan `news.xystudio.my.id`.
- Renderer OG web baca D1 langsung (hapus fetch edge-to-edge yang hang).
- Resource Android `ic_launcher_background` duplikat.

## [2.5.0] - 2026-08-31

### Ditambahkan
- Berita satu umpan (Worker + D1) untuk Android, Desktop, Web — like,
  komentar, berbagi sosial, OpenGraph per konten.
- Renderer OpenGraph di web (`web_deploy/worker/`).

### Diubah
- Tema monokrom terang dengan aksen ungu.
- Logo X resmi tanpa glow (sumber `design/x-white.png` & `x-black.png`).

### Diperbaiki
- CSP web untuk origin berita; manifest warna ikut tema terang.

## [2.4.0] - 2026-08-31

### Ditambahkan
- Control API lokal host (HTTP 127.0.0.1 + token) — status/sesi/video/log/
  password/stop.
- Shell desktop Electron + Next.js dengan supervisor engine (hybrid:
  engine Rust tetap inti capture/encode/WebRTC).

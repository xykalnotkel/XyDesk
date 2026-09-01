# XyDesk — Roadmap Teknis (Brain Developer)

> Dokumen ini adalah **sumber kebenaran tunggal** untuk arah teknis XyDesk.
> Aturan #1: **bukti dulu, baru poles.** Aturan #2: **semua gratis, tanpa
> kartu kredit** — self-host di tier gratis, tanpa API berbayar.

---

## Kenyataan yang harus diterima sekarang

XyDesk hari ini adalah **UI kerangka yang sangat rapi**, tapi belum punya
loop inti: `capture → encode → kirim → decode`. Semua nilai produk terletak
di loop itu. Sampai loop itu jalan dan **latency-nya terukur di bawah target**,
setiap jam yang dipakai untuk memoles UI adalah taruhan.

Target yang harus dibuktikan (dari README-mu sendiri):

| Metrik | Target | Cara ukur |
|---|---|---|
| Glass-to-glass latency | **< 40 ms** LAN | timestamp frame di host → dibanding di client |
| Encode | < 10 ms @1080p60 | NVENC/AMF/QuickSync, bukan x264 |
| Decode | < 8 ms | hardware decoder di client |
| Jitter | < 5 ms | stats WebRTC (`getStats`) |

Kalau PoC gagal tembus target di jaringan nyata (Wi-Fi rumah, bukan LAN kabel
lab), posisi "cocok untuk gaming" **harus dievaluasi ulang** — jangan diteruskan
demi gengsi.

---

## Fase

### Fase 0 — PoC streaming (PRIORITAS, kerjakan SEKARANG)
**Tujuan:** buktikan loop inti jalan end-to-end dan ukur latency-nya.

1. **Host (Rust + Tauri)**: capture layar via Desktop Duplication API (DXGI),
   encode NVENC, kirim via WebRTC. Lihat `host/`.
2. **Client (Flutter)**: terima via `flutter_webrtc`, render ke `RTCVideoView`,
   kirim input (mouse/keyboard) balik lewat data channel. Lihat `lib/webrtc/`.
3. **Signaling**: sudah DIBANGUN (Cloudflare Workers + Durable Object, gratis);
   ada juga `signaling/` cadangan.
4. **Uji latency** dengan overlay timestamp di layar (paling jujur: foto layar
   host + layar client berjejer, baca selisih jam di frame). Protokol lengkap
   ada di `docs/LATENCY.md`.

**Progres Fase 0 (28 Agu 2026):**

- [x] Loop `capture → encode → RTP → client` terbukti di **test loopback
      otomatis** (`host/tests/loopback.rs`): SDP jawaban memuat video, paket
      RTP sampai ke client, data channel input dua arah (PING/PONG).
- [x] Bug urutan `add_video_track` vs `create_answer` diperbaiki — dulu track
      didaftarkan setelah SDP jawaban dibuat, akibatnya **0 paket video**
      (koneksi sukses, layar kosong). Sekarang dijaga test regresi.
- [x] Instrumen ukur: `xydesk-host --bench` (encode avg/p50/p95/max) + log
      statistik encode di jalur capture.
- [x] Konfigurasi encoder dibeneri: `skip_frames(true)` — sebelumnya
      OpenH264 memperingatkan mode bitrate tidak berfungsi (bitrate bisa
      meledak jauh di atas 8 Mbps).
- [ ] **Belum:** capture DXGI nyata diverifikasi di lab Windows (runner
      tanpa GPU; lihat `.github/workflows/test-lab.yml`).
- [ ] **Belum:** angka glass-to-glass terukur (foto 10 pasang layar).
- [ ] **TERBUKTI TIDAK LULUS:** openh264 CPU ~30 ms @640x360 — JAUH di atas
      target <10 ms @1080p60. **NVENC/AMF/QuickSync wajib** untuk target
      latency, openh264 hanya untuk PoC/fungsional.

**Kriteria lulus (go/no-go):** 1080p60, < 40 ms di LAN, < 80 ms via internet
dengan TURN, stabil 30 menit tanpa re-buffer.

### Fase 1 — Hardening & keamanan
- Auth asli (Firebase Spark / Supabase free / tetap self-host HMAC) menggantikan
  "Google tiruan".
- Pairing PIN diverifikasi host-side (sudah didesain di protokol `pair`).
- TURN self-host (coturn) untuk NAT traversal — hanya ~15-20% koneksi butuh ini.
- Clipboard/mic passthrough: **consent per-sesi eksplisit**, bukan toggle global.

### Fase 2 — Fitur yang membedakan
- Control mapping editor (profil JSON) — kerangka UI-nya sudah ada.
- Multi-monitor, per-monitor streaming.
- Audio forward (host → client) + mic passthrough.
- Gamepad passthrough.

### Fase 3 — Distribusi & scale
- Host app installer (Tauri bundler / WiX) dengan auto-update.
- Android release di Play Store / side-load; Windows signed EXE.
- Signaling multi-node (NATS/Redis pub-sub) kalau user base tumbuh — protokol
  sudah tidak berubah, ganti `Hub.clients` saja.

> **Catatan 1 Sep 2026:** identitas logo dikembalikan ke logo asli
> (`design/logo-asli.png`), dan `tool/gen_logo.py` sekarang menurunkan semua
> ukuran dari berkas itu. Baris di bawah ini adalah catatan sejarah, bukan
> keadaan sekarang.

## Rilis 2.5.0 — Monokrom, berita, lisensi (31 Agu 2026)

- Tampilan semua platform: dominan hitam-putih, ungu hanya aksen. Logo X resmi
  tanpa glow/bayangan (sumber: `design/x-white.png` & `design/x-black.png`).
- Berita satu umpan (Worker `news/` + D1) untuk Android, Desktop, Web —
  like/komentar/bagikan; halaman share `news.xystudio.my.id/n/<slug>` dan
  renderer OpenGraph baru di web (`web_deploy/worker/`) memberi meta per konten.
- Perbaikan bug: berita web gagal dimuat ("Failed to fetch") karena CSP belum
  mengizinkan `news.xystudio.my.id` — sudah ditambahkan di `_headers`.
- Lisensi proyek: **proprietary** (file `LICENSE` — EULA, larangan clone);
  daftar lengkap lisensi pihak ketiga di `docs/LEGAL.md` + Legal di
  semua platform. (Sebelumnya sempat tercatat Apache-2.0 — dicabut.)
- Kebijakan rilis (berlaku mulai sekarang):
  1. Setiap update aplikasi **wajib menaikkan versi** (pubspec `X.Y.Z+NN`,
     web & desktop `package.json`).
  2. Setiap rilis **wajib punya artikel Berita** — terbit lewat endpoint
     admin (slug hash acak), lihat `news/README.md`.

## Rilis 6.0.0 — Ungu menonjol, notifikasi nyata, interaksi hidup (31 Agu 2026)

- Identitas ungu menonjol di semua platform (hero web ungu pekat, tombol
  utama ungu, aksen di Android/Desktop); logo X memakai tile seperti
  sampul berita (tanpa glow/bayangan).
- **Push notifikasi DIPERIKSA & DIHIDUPKAN**: jalur server (REST OneSignal,
  teruji dari Worker berita) kini terpasang — artikel baru memicu push
  OneSignal + email Resend otomatis (endpoint admin `waitUntil`). SDK
  klien masuk lewat onesignal_flutter (Maven, tanpa plugin Gradle);
  izin tetap opt-in dari aplikasi.
- Berita: balas komentar (1 tingkat), username acak per perangkat (tanpa
  kolom nama), like optimistik, langganan email, **slug hash acak** untuk
  artikel baru.
- Navigasi Android: geser kiri-kanan berpindah tab (PageView); keluar
  aplikasi wajib tekan kembali 2× (PopScope + snackbar).
- Splash ditulis ulang: 1800 ms, kurva easeOutQuart, tile logo + garis
  aksen ungu — lebih smooth, tanpa animasi berlebihan.
- Legal super lengkap: `docs/LEGAL.md` (EULA proprietary, privasi,
  ketentuan, tabel lisensi pihak ketiga per platform dengan fungsi).
- Versi: Android 6.0.0 (build 20) · Web 6.0.0 · Desktop 6.0.0 · Host 6.0.0.

## Rilis 6.1.0 — Audio nyata, multi-monitor, kontrol penuh (31 Agu 2026)

- **Audio forward**: `host/src/audio.rs` — WASAPI loopback → Opus 48 kHz
  stereo → track WebRTC; otomatis aktif di Windows (non-Windows jujur
  "belum didukung"). Client (Android/Web) memutar track lewat renderer/elemen
  audio terpisah + tombol Audio di HUD (transceiver direction, tanpa
  negosiasi ulang).
- **Mic passthrough**: mic client (getUserMedia) → track Opus → host decode
  → `IAudioRenderClient` (terdengar di speaker PC). Endpoint mikrofon
  virtual Windows menyusul (tercatat jujur di panel audio).
- **Multi-monitor**: enumerasi GDI + pemilih layar di sesi (chip, pesan
  meta host→client); pindah monitor LANGSUNG — thread capture di-respawn
  (event biner 0x07 DISPLAY_SELECT).
- **Volume master** host via control API (`audio-volume`); status audio &
  layar di `/status`.
- Splash revisi ulang (cahaya ungu lembut + tile + wordmark gradient).
- `CHANGELOG.md` wajib per rilis — dilampirkan otomatis ke GitHub Release;
  isi rilis juga dimuat di Release Notes.
- Email berita kini bertanda tangan premium: badge XySpace + **Haekal
  Saputra (Founder, XySpace)**.
- Versi: Android 6.1.0+21 · Web 6.1.0 · Desktop 6.1.0 · Host 6.1.0.
- **Uji berikutnya (lab Windows)**: bunyi loopback terdengar di Android/Web,
  mic terdengar di speaker PC, pindah monitor saat sesi berjalan, volume
  master berubah. Semua jalur punya fallback & log jujur.

## Audit fitur — status implementasi (31 Agu 2026, rilis 6.1)

| Fitur | Status | Catatan |
|---|---|---|
| Capture → encode → RTP → client | Jalan | loopback test otomatis; DXGI/NVENC menunggu lab Windows |
| Pairing + tendang peer kedua | Jalan | `HostBusy` di gerbang pairing, teruji |
| Control API lokal + shell desktop | Jalan | status/sesi/video/log/password/stop + audio-volume + display-select |
| Berita lintas platform | Jalan | like/komentar/balasan/bagikan/OG per konten/langganan email |
| Push notifikasi (rilis + berita) | Jalan | jalur server REST OneSignal teruji; SDK klien via onesignal_flutter (opt-in) |
| Notifikasi email berita | Jalan | Resend + tabel subscribers; domain terverifikasi; badge pengirim premium |
| Akun (email OTP + Google) | Jalan | signaling worker + web connect |
| QR scan pairing | Jalan | mobile_scanner (CameraX/MLKit) |
| Keyboard virtual (modifier sticky) | Jalan | `virtual_keyboard.dart` tersambung ke sesi |
| Geser antar halaman + keluar 2× | Jalan | PageView + PopScope di AppShell |
| Audio forward (host → client) | Jalan (kode) | WASAPI loopback + Opus + track; uji dengar di lab Windows |
| Mic passthrough (client → host) | Jalan (kode) | diputar di speaker host; endpoint mik virtual menyusul |
| Multi-monitor + pilih layar live | Jalan (kode) | GDI enumerate + respawn capture; uji di lab Windows |
| Changelog wajib per rilis | Jalan | `CHANGELOG.md` + dilampirkan ke Release |
| Gamepad passthrough | **Belum** | Fase 2 |
| Driver display virtual (IddSampleDriver) | **Belum** | Fase 2 — installer ada di CI release, integrasi belum |
| Node signaling cadangan (failover) | **Belum** | Fase 3 — Durable Object multi-region / worker kedua |
| Remap kontrol (profil) | **Belum** | Fase 2 — kerangka UI ada |
| Installer signed + auto-update host | **Belum** | Fase 3 |

## Keputusan stack shell desktop (Agu 2026)

Shell host Windows kini **Electron + Next.js (static export)** menggantikan
GUI native Win32 (`host/src/bin/gui.rs`, tetap ada sebagai fallback).
Alasannya: UI web jauh lebih cepat dikembangkan dan konsisten dengan web
client; engine streaming **tetap Rust** — capture/encode/WebRTC TIDAK boleh
pindah ke Chromium (desktopCapturer + encode Chromium jauh di atas target
`< 40 ms`). Shell hanya launcher + panel; kanal baliknya adalah **control API
lokal** di engine (HTTP `127.0.0.1` + token per-lahir, `host/src/control.rs`):
status mesin, sesi aktif, statistik video, dan aksi password/stop-session.
Detail lengkap: `docs/DESKTOP_SHELL.md`.

---

## Stack gratis — TANPA VM/VPS (verifikasi ulang tiap fase)

| Komponen | Pilihan | Biaya |
|---|---|---|
| Signaling | **Cloudflare Worker + Durable Object** (`cloudflare/`, sudah jadi) | Rp 0 |
| STUN | `stun.cloudflare.com` (publik) | Rp 0 tanpa batas |
| TURN | `turn.cloudflare.com` | 1.000 GB/bln gratis |
| TLS | otomatis (custom domain signal.xystudio.my.id) | Rp 0 |
| Auth | Firebase **Spark** / Supabase free / HMAC self-host | Rp 0 |
| Encode | NVENC/AMF/QuickSync (GPU onboard) | Rp 0 |
| Libraries | flutter_webrtc, webrtc-rs, str0m — MIT/Apache | Rp 0 |

**Tidak ada** VM/VPS, tidak ada API berbayar, tidak ada kartu kredit.
Versi Go (`signaling/`) tetap ada sebagai opsi self-host LAN, tetapi produksi
memakai Cloudflare (serverless).

---

## Definisi selesai per fase (untuk mencegah "sudah 90% selamanya")

Setiap fase punya artefak yang bisa diverifikasi orang lain, bukan perasaan:
- Fase 0 → angka latency terukur di tabel di atas + video demo 30 detik.
- Fase 1 → audit keamanan singkat (pen-test basic: bisakah MITM melihat layar?).
- Fase 2 → user bisa remap kontrol tanpa rebuild.
- Fase 3 → installer jalan di PC fresh tanpa dev environment.

---

## PR berikutnya (urut)

1. `feat(host): DXGI capture + NVENC encode skeleton` — lihat `host/`.
2. `feat(client): sambungkan flutter_webrtc ke SessionPage` — lihat `client/`.
3. `feat(signaling): deploy Worker ke Cloudflare + verifikasi STUN/TURN`.
4. **STOP memoles UI** sampai Fase 0 go.

---

## Catatan ke dirimu (yang nulis README)

README-mu sudah luar biasa jujur. Pertahankan itu. Satu-satunya hal yang
perlu diubah segera: tabel "Build Otomatis" yang bilang Windows/iOS "ditunda"
padahal CI sudah membangunnya, dan referensi folder `remote-desktop-docs/`
yang tidak ada. Perbaiki sebelum orang luar membaca dan kehilangan kepercayaan.

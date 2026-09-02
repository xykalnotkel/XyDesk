# HANDOFF — Catatan Lintas Role

Papan serah-terima antar sesi agent. **Setiap sesi WAJIB**:
1. Di awal: baca bagian role-mu, kerjakan yang bisa kamu kerjakan.
2. Di akhir: tambahkan temuan baru untuk role lain, dan pindahkan item yang
   kamu selesaikan ke bagian "Selesai" (JANGAN dihapus — sejarah itu bukti).

> File ini mencatat **temuan lintas role**. Untuk keadaan *real-time* —
> siapa lagi mengunci area apa, push siapa yang sudah diizinkan — baca
> `AGENT_BOARD.md`, bukan percakapan lama.

Format item: `- [ ] (dari <Identitas>, <tanggal>) — <apa> — <kenapa/konteks>`

---

## Untuk: Client Flutter

- [ ] (dari Danu - XySpace Team, 2026-09-02) — **Rebrand**: logo X baru sudah
  masuk, token ungu `lib/core/tokens.dart` sudah diselaraskan dengan web
  (accent `#7C3AED`, deep `#5B21B6`, lavender `#A78BFA`) oleh Laras. Yang
  tersisa: verifikasi hasil rebrand (ikon launcher, splash, aset, warna)
  di **build Android nyata** — belum ada perangkat di sesi ini.
- [ ] (dari Laras - XySpace Team, 2026-09-03) — **Verifikasi di perangkat
  nyata**: avatar & nama komentator (DiceBear `adventurer` SVG dari URL
  `api.dicebear.com`) dimuat melalui jaringan; pastikan `flutter_svg`
  merender SVG di Android tanpa placeholder permanen saat offline. Belum
  diuji di perangkat.

## Untuk: Desktop Shell

- [ ] (dari Galih - XySpace Team, 2026-09-03) — Host kini mengirim **dua**
  stream audio: `audio` (loopback suara sistem) dan `mic` (mikrofon PC host,
  hanya bila ada perangkat capture). Client yang menyajikan track audio
  dengan `mid`/`stream_id` "mic" akan otomatis menerima suara mic. Bila mau
  mute/volume mic terpisah, butuh aksi control API baru (belum ada —
  `audio-volume` saat ini hanya menyentuh perangkat output default).
- [ ] (dari Galih - XySpace Team, 2026-09-03) — Control API kini punya aksi
  `video-bitrate` (field `bitrate_mbps`, 1–50) dan `/status` melaporkan
  `targetBitrateBps`, `video.latencyMs` (EMA pipeline host),
  `video.latencyMaxMs`, dan `video.encoder` (`nvenc`/`openh264`/
  `test-pattern`). Tambahkan kontrol di panel (input Mbps + tampilkan nilai
  aktif, dan kalau mau, tampilkan latensi + encoder) — endpoint-nya sudah
  jadi & teruji, UI-nya belum.
- [ ] (dari Danu - XySpace Team, 2026-09-02) — **Rebrand**: ikon Windows
  (`packaging/windows/xydesk.ico`) sudah lahir ulang dari logo baru —
  verifikasi installer CI berikutnya memakai ikon itu. Selaraskan juga
  warna aksen shell dan avatar penulis resmi berita (foto founder, lihat
  catatan Client Flutter).
- [ ] (dari Danu - XySpace Team, 2026-09-02) — Waktu komentar berita di web
  kini relatif ("5 menit lalu"); samakan di Flutter dan Desktop
  (`formatRelativeTime` di `web/src/news.ts` sebagai acuan). Avatar
  penulis resmi juga kini bulat penuh.
- [ ] (dari Danu - XySpace Team, 2026-09-02) — Form komentar berita: pindah
  ke BAWAH daftar komentar + auto-scroll saat "Balas" (web sudah; alasan:
  input di atas menyulitkan setelah membaca komentar).
- [ ] (dari Danu - XySpace Team, 2026-09-02) — Avatar + nama manusia
  komentar: ikuti pola web (`web/src/news.ts` — `newsDisplayName`,
  `newsAvatarUrl`). Flutter sudah; shell desktop menyusul.

## Untuk: CI / Release

- [ ] (dari Galih - XySpace Team, 2026-09-03) — Push host-only ke `main`
  (tanpa perubahan area client) saat rilis belum selesai memicu ulang
  `release.yml`: job `Ambil build client yang sudah lulus` MERAH karena
  artefak client tidak ada (job Flutter di-skip oleh filter area), padahal
  `prepare` menilai `should_release=true` selama tag `v6.3.0` belum dibuat.
  Tidak terjadi rilis duplikat (`Terbitkan Release` ikut skip), tapi
  run-nya merah. Pertimbangkan penjagaan: `clients` soft-fail / lewati
  bila artefak client tidak ada, atau `prepare` hanya rilis bila area
  client berubah.

## Untuk: Web

- [ ] (dari Cakra - XySpace Team, 2026-09-03) — Push `0081742` (keyboard
  virtual, panel gaming) membuat run `verify-push-auth.yml` MERAH: commit
  tidak memuat penanda `Izin: <ID-SESI>` di body. Aturan baru (lihat
  `AGENT.md` bagian 5): klaim sesi → minta persetujuan operator di
  `AGENT_BOARD.md` → push dengan `Izin: ...` di body. Commit tetap masuk,
  tapi audit mencatatnya sebagai pelanggaran.

## Untuk: Backend / Edge

_(kosong)_
- [ ] (dari Danu - XySpace Team, 2026-09-03) — **Billing sewa PC otomatis**:
  halaman `/billing` web sudah tayang (paket, durasi, total, pesan via WA;
  operator konfirmasi manual). Otomasi penuh butuh: (1) gateway pembayaran
  QRIS (Midtrans/Xendit — perlu keputusan operator + akun), (2) endpoint
  provisioning yang mengirim ID+password XyDesk + kode billing setelah
  webhook pembayaran, verifikasi penebusan = 4 digit akhir nomor WA pembeli.
  Catatan CyberIndo: TIDAK ada API publik/dokumentasi developer (sistem
  tertutup, terikat GCA) — integrasi langsung tidak mungkin tanpa
  reverse-engineering. Jalur realistis: (a) helper kecil di PC server warnet
  yang menerima perintah dari backend kita lalu membuat member/top-up, atau
  (b) lepas dari billing CyberIndo untuk sesi remote — host XyDesk sendiri
  yang membatasi durasi sesi.
- [ ] (dari Danu - XySpace Team, 2026-09-03) — **Verifikasi admin komentar
  yang lebih mulus**: sekarang founder menempel ADMIN_TOKEN sekali di
  perangkat (UI web sudah ada, worker memvalidasi). Peningkatan: worker
  berita menerima Google ID token dan memverifikasi email founder langsung
  (audience + signature), sehingga tidak perlu menempel token manual.

- [ ] (dari Laras - XySpace Team, 2026-09-03) — **Preset upload Cloudinary
  unsigned** untuk foto profil: kode sisi klien sudah selesai (unggah lewat
  `lib/core/cloudinary_upload.dart`, opsinya ada di menu edit profil). Yang
  kurang **hanya satu langkah operator**: buat **unsigned upload preset** di
  dasbor Cloudinary lalu set `cloudinaryUploadPreset` (dan pastikan
  `cloudinaryCloudName` benar). Tidak ada yang perlu diubah di kode lagi.
  opsional untuk cuplikan "layar terakhir" yang kokoh: kalau tangkapan
  klien (RepaintBoundary) ternyata gelap di perangkat nyata, jalur
  terbaik adalah host mengirimkan satu frame terakhir saat sesi berakhir.
  Protokolnya bisa ditambahkan tanpa mengubah kontrak yang ada.

## Untuk: News & Konten

- [ ] (dari Sena - XySpace Team, 2026-09-02) — Setelah Flutter selesai
  merender gambar inline (terbit 3 Sep 2026 di rilis 6.3.0): artikel
  rilis berikutnya dipastikan memakai format baru `docs/NEWS_STYLE.md`
  (apa+kenapa, changelog pengguna, screenshot di `web/public/news/shots/`).

## Untuk: Host Engine

- [ ] (dari Cakra - XySpace Team, 2026-09-03) — Push `f12dace` (bitrate
  live via control API) membuat run `verify-push-auth.yml` MERAH: commit
  tidak memuat penanda `Izin: <ID-SESI>` di body. Aturan baru: klaim
  sesi → persetujuan operator di `AGENT_BOARD.md` → push dengan penanda
  `Izin: ...` di body commit.

## Untuk: Docs & Audit

_(kosong)_

---

## Selesai

- [x] (dari Galih - XySpace Team, 2026-09-03) — Host: mic input PC → client
  (WASAPI `eCapture` → Opus mono → stream `mic`), otomatis bila ada
  perangkat capture; `/status` + `meta` melaporkan `micAvailable`/
  `micPipeline`. Uji 64 unit + loopback hijau; build Windows diverifikasi
  CI.
- [x] (dari Galih - XySpace Team, 2026-09-03) — Host: metrik latensi
  pipeline (capture→encode→write RTP) kini dilaporkan di `/status` sebagai
  `video.latencyMs` (EMA) + `video.latencyMaxMs` + `video.encoder`
  (nvenc/openh264/test-pattern); durasi sampel video diseragamkan ke fps
  nominal 60 (16,67 ms). Semua otomatis (tanpa toggle); uji 63 unit +
  loopback hijau, build Windows x64/arm64 hijau di CI.
- [x] (dari Tara - XySpace Team, 2026-09-03) — Token signaling Go kini
  mengikat role (format identik Worker Cloudflare), middleware menolak
  role/id palsu, relay menegakkan arah, daftar perangkat hanya membagikan
  host. Dikunci `go test` baru + `go vet`/`go test` di CI (commit
  `signaling/` + `.github/workflows/build.yml`).
- [x] (dari Tara - XySpace Team, 2026-09-03) — Email berita memakai
  `badge-xyspace.png` yang sudah hilang (404); kini `logo.png` baru + foto
  founder, selaras web (`news/src/worker.js`).
- [x] (dari Cakra - XySpace Team, 2026-09-03) — Pin Node ≥ 22 untuk tooling
  wrangler: `engines` ditambahkan di `cloudflare/package.json` dan
  `news/package.json` (CI memang sudah Node 24; ini melindungi lingkungan
  lokal).
- [x] (dari Galih - XySpace Team, 2026-09-03) — `nvenc.rs`: `ok()` hanya
  menulis "NVENC status {n}" tanpa nama error — log fallback ke openh264
  terbaca angka, bukan penyebab. Dipetakan `status_name`/`status_hint` di
  `nvenc_config.rs` (0–26 dari nvEncodeAPI.h) + test. Sekalian perakit
  `build_config`/`build_init` dipindah & dikunci uji; VBV dikecilkan dari
  `bitrate/2` ke 1 frame.
- [x] (dari Danu, 2026-09-02) — 500 semua deep link web produksi —
  binding `ASSETS` hilang di `web_deploy/wrangler.toml`. Diperbaiki Danu,
  commit `899e4d1`, diverifikasi live.
- [x] (dari Danu, 2026-09-02) — Selaraskan token ungu `lib/core/tokens.dart`
  dengan web (accent `#7C3AED`, deep `#5B21B6`, lavender `#A78BFA`) —
  selesai di kode oleh Laras (2026-09-03). Verifikasi di build Android
  nyata tetap terbuka (lihat "Untuk: Client Flutter").
- [x] (dari Danu, 2026-09-02) — Avatar penulis resmi + komentar pakai foto
  founder, dan avatar komentar DiceBear (official → foto founder, selainnya
  `api.dicebear.com/9.x/adventurer/svg?seed=<author>`) — selesai di kode
  oleh Laras (2026-09-03).
- [x] (dari Danu, 2026-09-02) — Render gambar inline `![keterangan](url)`
  (hanya `app.xystudio.my.id`) di `news_detail_page.dart` — selesai di kode
  oleh Laras (2026-09-03).
- [x] (dari Danu, 2026-09-02) — Nama komentator nama manusia deterministik
  (bukan `tamu-xxxx`), selaras `web/src/news.ts` — selesai di kode oleh
  Laras (2026-09-03).

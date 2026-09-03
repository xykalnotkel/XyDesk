# Changelog XyDesk

Semua perubahan penting XyDesk dicatat di sini.
Format mengikuti [Keep a Changelog](https://keepachangelog.com/id/1.1.0/),
versi mengikuti [Semantic Versioning](https://semver.org/lang/id/).

Kebijakan rilis:
- Setiap update aplikasi **wajib menaikkan versi** (`pubspec.yaml X.Y.Z+NN`,
  `web`/`desktop` package.json, `host` Cargo.toml).
- Setiap rilis **wajib punya artikel Berita** dengan changelog yang jelas dan
  panjang (lihat `news/README.md` untuk alur penerbitan).
- **Berita dan changelog adalah dua hal berbeda.** File ini untuk tim dan
  untuk catatan GitHub Release. Berita di `news.xystudio.my.id` ditulis untuk
  pengguna: tanpa nama berkas, tanpa nomor versi di judul, tanpa daftar
  commit. Panduan lengkap nadanya ada di [`docs/NEWS_STYLE.md`](docs/NEWS_STYLE.md).
- File ini otomatis dilampirkan ke GitHub Release oleh `release.yml`.

## [Belum terbit]

### Ditambahkan
- Desktop (host Windows): GUI host kembali ke **shell Electron + Next.js**
  (`desktop/`), menggantikan jendela native Win32 5 MB yang selama ini
  dikemas installer. Installer kini memaketkan `XyDesk.exe` (Electron) +
  `resources/engine/xydesk-host.exe` (engine Rust, dibundel
  electron-builder). Jendela native `host/src/bin/gui.rs` tetap ada di
  sumber sebagai cadangan, tidak lagi dikemas.
- Desktop (host Windows): **host selalu aktif** — menutup jendela kini
  menyembunyikan ke **system tray** (ikon XyDesk), engine tetap hidup di
  latar belakang; notifikasi balloon muncul sekali saat pertama kali
  diminimize ke tray. Keluar beneran hanya lewat menu tray "Keluar
  (hentikan host)". Sebelumnya menutup jendela mematikan engine — host
  mati begitu jendela ditutup, bertentangan dengan standar remote desktop.
- Web: **harness uji E2E lokal** (`web/e2e/`) — signaling Go + shim auth
  (format token `ts.purpose.sig` yang sama dengan `auth.go`) + "host pola
  uji" berupa tab Chromium (canvas beranimasi → H264 Chrome → WebRTC),
  lalu build rilis dijalankan Playwright untuk menguji layar sesi dan
  menghasilkan screenshot asli dengan video yang benar-benar ter-decode.
  URL signaling kini bisa dioverride `VITE_SIGNAL_API`/`VITE_SIGNAL_WS`
  saat build uji; produksi tetap default `signal.xystudio.my.id`.
  Hasilnya: 11 screenshot sesi web di `web/public/news/shots/web-sesi-*`.
- Host: **mic input PC → client** — mikrofon host direkam via WASAPI
  `eCapture` (perangkat komunikasi default, PCM 16-bit 48 kHz mono) →
  Opus 20 ms → track audio kedua (stream `mic`). Aktif otomatis hanya bila
  ada perangkat capture, tanpa toggle apa pun; `AUDCLNT_BUFFERFLAGS_SILENT`
  ditangani agar mic yang dimute tetap menghasilkan hening sah. Sebelumnya
  host hanya meneruskan loopback (suara sistem) dan memutar mic *client* ke
  speaker host — suara mic *PC host* tidak pernah sampai ke client.
  `/status` dan `meta` data channel kini melaporkan `audio.micAvailable`
  + `micPipeline`.
- Host: `/status` kini melaporkan **latensi pipeline video** dan **label
  encoder** — `video.latencyMs` (rata-rata EMA capture → tulis RTP),
  `video.latencyMaxMs` (terburuk yang pernah terukur), dan
  `video.encoder` (`nvenc`/`openh264`/`test-pattern`). Sebelumnya tidak ada
  ukuran latensi host sama sekali: webrtc-rs 0.11 mengabaikan
  `packet_timestamp` (timestamp RTP dibuat otomatis packetizer), jadi
  penanda tidak bisa ditanam lewat bidang itu. Kini setiap frame membawa
  `captured_at` sejak detik ditangkap di thread capture, dan latensi
  dihitung sesaat sebelum `write_sample` — pemantauan target roadmap
  < 40 ms glass-to-glass tanpa alat eksternal.
- Client Flutter: **tombol Billing di topbar** — ikon AI 3D ungu glossy
  (mesin + jam + koin sewa PC) yang membuka layar Langganan langsung dari
  bar atas, tidak perlu lewat menu Akun. Aset di `assets/img/nav/billing.png`
  (+ `_off.png`), latar putih dibuang (transparan); `BillingPage` kini
  terlihat dari `app.dart` lewat `import features/account/billing_page.dart`.
- Client Flutter: **data lokal diisolasi per akun** — daftar perangkat,
  riwayat sesi, dan daftar "perangkat terakhir" di halaman Connect kini
  memakai kunci penyimpanan yang memuat ruang lingkup akun
  (`devices:$scope`, `history:$scope`, `connect_recents:$scope`; tamu
  memakai `guest`). Sebelumnya semua akun memakai kunci global, sehingga
  setelah keluar lalu masuk akun lain, daftar PC milik akun sebelumnya
  masih tampil — kebocoran data antar akun. Dikunci lewat
  `test/devices/account_scope_test.dart`.
- Client Flutter: **changelog lengkap di halaman pembaruan** — selain catatan
  ringkas dari manifest, "Pusat Update" kini mengambil body GitHub Release
  resmi (isi `CHANGELOG.md`) dan menampilkannya sebagai "Catatan rilis".
  Manifest hanya membawa tiga catatan umum, jadi sebelumnya halaman tampil
  tanpa rincian. Parser markdown dikunci lewat
  `test/notifications/changelog_parse_test.dart`.

### Ditambahkan
- Web: **chip durasi & sisa waktu di layar sesi** — pojok kiri atas
  menampilkan durasi berjalan dan, untuk sesi tamu, sisa waktu batas
  2 jam (token tamu terbit persis 2 jam di authstore.js) berubah merah
  saat ≤ 5 menit; tab Sesi kini memuat baris Durasi/Total/Sisa waktu.
### Diubah
- Web: **Sewa PC (`/billing`)** — durasi kini bisa custom (input angka
  1–24 jam di samping chip cepat; di luar rentang ditolak dengan pesan)
  dan tiap paket menampilkan ketersediaan stok ("N unit tersedia" /
  "Stok habis" — kartu & tombol pesan nonaktif). Stok adalah angka
  operator di `web/src/Billing.tsx` (belum ada backend inventori),
  diperbarui manual + tanggal "diperbarui" tampil di halaman.
- Web: tombol hero beranda **"Status rilis" → "Ingatkan saya"** — klik
  membuka popup pilihan kanal kabar rilis: email (tersimpan berlabel
  `unduhan`, jalur sama dengan form halaman unduhan), saluran WhatsApp,
  atau Telegram. Sebelumnya tombol ini hanya membawa ke halaman unduhan
  yang memang belum bisa mengunduh (pra-beta) — niat pengunjung hilang
  begitu saja.
- Proses: **push tidak lagi memicu actions apa pun** (3 Sep 2026, sore) —
  sisa jalur otomatis `web/**` di build.yml dicabut. Satu-satunya jalur
  build/kompilasi/kemasan/deploy/rilis = `workflow_dispatch` oleh role
  CI/Release (Cakra) setelah izin operator; agent lain push kode +
  dokumen saja (gerbang audit izin tetap menyala). Dituangkan di
  `AGENT_BOARD.md`, `docs/CI.md`, `HANDOFF.md`.
- Proses: **atur rilis diperketat (3 Sep 2026)** — versi & berita adalah
  keputusan operator; sebelum build/rilis agent wajib memastikan kerjaan
  sesi lain yang menyentuh area rilis sudah `SELESAI`; push yang
  menyentuh versi/rilis wajib izin operator dulu; tiap agent menulis
  bahan artikel untuk kerjanya sendiri dan role CI/Release menyatukannya
  menjadi satu artikel rilis. Dituangkan di `AGENT_BOARD.md`,
  `docs/CI.md`, `docs/NEWS_STYLE.md`, `news/README.md`.
- Web: **tombol lompat di detail berita** — panah bawah melayang di pojok
  kanan bawah menggulir halus ke komentar paling bawah; sampai di dasar ia
  berubah jadi panah atas untuk kembali ke judul. Artikel changelog
  panjangnya bisa ribuan piksel — sebelumnya pembaca HP harus menggulir
  manual.
### Diperbaiki
- Web: **deep link `/billing` jatuh ke beranda** — `currentRoute()` tidak
  punya case `/billing`, jadi buka/refresh langsung ke URL itu merender
  halaman beranda (navigasi lewat menu tetap benar). Ditemukan saat menguji
  halaman sewa; audit responsivitas WEB5 sebelumnya keliru loloskannya
  karena beranda juga tidak overflow.
- Web: **race deploy-web.yml** — dua Build sukses berdekatan bisa mencampur payload sehingga deploy checkout SHA lama dan menimpa bundle baru (kejadian 6c5ba06/d90e12a, ditebus manual). Kini SHA & run Build diambil dari API, checkout memakai SHA itu, artefak dicocokkan dengan run-nya, deploy berjalan serial (tidak dibatalkan di tengah), dan hanya Build web terbaru yang boleh deploy.
- Web: **overflow horizontal di detail berita (layar ≤ 390 px)** — baris
  langganan email tidak bisa membungkus sehingga tombol "Langganan"
  mendorong halaman melebar 33–63 px. Kini input dan tombol membungkus
  rapi; tombol selebar input di layar sempit. Ditemukan lewat audit
  responsivitas 7 halaman × 5 viewport (1440/1024/768/390/360) — semua
  halaman lain lolos tanpa overflow.
- Web: halaman **Connect** dirapikan — blok "Dukung kami di" naik ke atas
  "Cara main", input ID perangkat kini rata kiri dengan gaya sama seperti
  field password (dulu angka besar terpusat berspasi lebar, tampak berbeda
  sendiri), dan password pairing punya tombol tampil/sembunyi (ikon mata).
  Password host memang huruf besar semua by design (charset tanpa I/O/0/1,
  10 karakter ≈ 50 bit) — tombol mata membuat pencocokan dengan layar PC
  cepat tanpa menebak ketikan.
- Web: **layar sesi didesain ulang ke arah paritas aplikasi** — baris tombol
  teks diganti rail ikon vertikal di tepi kanan (Suara PC, Mik ke PC,
  Keyboard, Gamepad, Trackpad, papan klip kirim/ambil, layar penuh,
  pengaturan, putuskan) yang bisa disembunyikan jadi pil kecil, persis pola
  rail sesi aplikasi Android. Panel pengaturan kini ber-tab
  (Gambar/Suara/Kontrol/Sesi) seperti `SessionControlPanel` aplikasi:
  statistik live dari `getStats()` (resolusi, fps, bitrate, ping, paket
  hilang, codec), pemilih layar pindah ke panel (tidak lagi melayang di
  atas video), segmen gerak kursor Langsung/Trackpad, durasi sesi.
  "Ambil dari papan klip PC" akhirnya tersedia di UI — protokolnya
  (`0x09 CLIPBOARD_REQ`) sudah ada di rtc.ts sejak lama tapi tidak pernah
  dipakai; kini dijawab toast setelah tersalin ke perangkat.
- Berita (lintas area, restu operator): penulis artikel selalu
  `Haekal Saputra`, bukan `Tim XySpace` — nama manusia di byline, label
  resmi `XySpace` tetap tampil sebagai badge. Diterapkan di default
  `POST /api/admin/publish`, `news/README.md`, `docs/NEWS_STYLE.md`, dan
  `AGENT.md`; artikel lama di D1 sudah dinormalisasi sesi sebelumnya.
  Tooltip badge komentar resmi kini "Akun resmi XySpace — Haekal Saputra".
- Host: durasi sampel video (maju timestamp RTP per frame) diseragamkan ke
  FPS nominal 60 (16,67 ms) lewat `NOMINAL_FPS`/`frame_duration()` —
  sebelumnya angka 33 ms terpatri acak di `main.rs`, dan sumber pola uji
  (non-Windows) kini berpacing 60 fps, bukan ~30 fps.
- Web: halaman **Sewa PC** (`/billing`) — pilih paket & spek, durasi mulai
  1 jam / Rp 5.000, ringkasan total, pemesanan via WhatsApp; menjelaskan
  alur ID+password+kode billing dengan verifikasi 4 digit akhir nomor WA.
  Pembayaran otomatis (QRIS) belum aktif dan halaman mengatakannya jujur.
- Web: mode founder di komentar berita — login Google `xycdigital@gmail.com`
  + ADMIN_TOKEN (sekali, tersimpan lokal) membuat balasan tampil sebagai
  Haekal Saputra dengan foto resmi dan badge; keabsahan tetap divalidasi
  worker dari token, bukan dari email.

- Client Flutter: **unggah foto profil dari galeri ke Cloudinary** (unsigned
  upload preset, tanpa menyimpan `api_secret` di klien) — pilih foto lewat
  `image_picker`, diunggah ke folder `profile`, lalu URL-nya dipakai sebagai
  avatar. Yang tersisa: operator membuat unsigned preset di dasbor dan mengisi
  `cloudinaryUploadPreset` (lihat `lib/core/cloudinary_upload.dart`). Kalau
  belum diisi, opsi upload menampilkan pesan yang jelas, bukan gagal senyap.
- Client Flutter: dependensi baru `image_picker` (untuk memilih foto dari
  galeri). Inventaris lisensi pihak ketiga diregenerasi: **499 → 504**
  komponen (Dart/Flutter 105 → 110).
- Client Flutter: kontrak konfigurasi unggah Cloudinary dikunci lewat uji
  (`test/core/cloudinary_upload_test.dart`).

- Client Flutter: **nav bawah & rail memakai ikon AI 3D ungu glossy** (aset
  `assets/img/nav/*.png`) dengan dua mode — aktif memakai versi penuh warna,
  nonaktif versi "off" abu-abu. Ikon dibuat AI lalu latar putihnya dibuang
  (transparan) memakai keying manual, dan baris bawah sedikit diperbesar
  (tinggi + ikon 28 px) supaya lebih mudah dijangkau.
- Client Flutter: **pilihan sumber papan ketik sesi** — "XyDesk" (papan ketik
  penuh, F1–F12, modifier sticky, keycode Windows) atau "Sistem" (IME Android
  via field teks, mengetik sebagai teks bebas melalui 0x06 TEXT). Dipilih di
  panel kontrol; kontraknya dikunci lewat `test/session/`
  `session_settings_test.dart`.
- Client Flutter: **tombol "Kirim" komentar berita kini aktif saat mengetik**.
  Sebelumnya `TextEditingController` tidak diberi listener sehingga tombol
  tidak pernah menyala (terlihat seolah tidak bisa mengirim balasan). Balasan
  juga kini mengikuti input yang baru diketik ("tidak sinkron").
- Client Flutter: identitas komentar mengikuti sesi — pengguna yang *login*
  memakai nama akun (fallback ke bagian depan email), sedangkan *tamu* memakai
  nama manusia deterministik dari sidik jari perangkat; keduanya tetap
  mendapatkan avatar (DiceBear).
- Client Flutter: halaman **Syarat & Ketentuan / Kebijakan Privasi** kini
  menyorot kata penting (warna aksen + tebal) dan membuat alamat email serta
  tautan dapat diketuk — tanpa mengubah isi dokumen.
- Client Flutter: jarak antara chip "Riwayat" dan kolom ID perangkat di
  halaman Connect diperbaiki (sebelumnya menempel sehingga membaur jadi satu
  blok).

### Diubah
- Client Flutter: dokumen legal tidak lagi menampilkan teks polos yang sama
  untuk semua kata; kata penting diberi warna/tebal dan email/URL dapat
  diketuk untuk membuka aplikasi email/browser.

### Diperbaiki
- Host: **host tidak lagi hidup-mati-hidup-mati sendiri.** Akar masalahnya
  di dua lapis: (1) server signaling mengirim ping WebSocket tiap 30 dtk dan
  menutup koneksi yang tidak membalas dalam 90 dtk (`signaling/client.go`),
  sementara engine Rust tidak pernah membalas ping (loop hanya memproses
  `Message::Text`) — jadi host idle dibunuh server tiap ~90 detik, lalu
  `main()` selesai dan proses mati; (2) supervisor merestart proses itu,
  lalu siklus terulang. Kini engine membalas ping dengan pong, dan `main()`
  menyambung ulang DALAM proses dengan backoff (1→30 dtk) saat koneksi
  putus — proses hanya keluar bila token ditolak server (401/403, token
  host ≈5 menit) atau signaling tak terjangkau setelah 10 percobaan, agar
  supervisor meminta token baru. Supervisor Electron juga dijaga agar tidak
  men-spawn dua engine sekaligus (guard `engineStarting`), menghormati
  backoff restart, dan mencatat kode keluar + sinyal engine di log.
- Host: **capture layar berhenti saat sesi berakhir** — sebelumnya setelah
  client menutup sesi, thread capture DXGI + encoder terus berjalan tanpa
  penonton (frame dikirim ke channel yang sudah tertutup, diabaikan
  diam-diam), menyedot GPU/CPU sia-sia dan bisa mengganggu sesi berikut.
  Kini `on_frame_arrived` menghentikan capture begitu konsumen frame hilang
  (`try_send` → `Disconnected`), dan `spawn_frame_source` membawa sinyal
  hidup (`FrameSource`) supaya thread capture tahu kapan harus keluar.
- Host: **capture layar pulih dari penutupan OS** — bila Graphics Capture
  ditutup OS (secure desktop/UAC, monitor lepas, reset driver), thread
  capture kini mencoba ulang dengan jeda singkat alih-alih keluar dan
  membekukan gambar selamanya (sesi tetap "terhubung" tapi layar beku).
  Sesi yang benar-benar berakhir tetap menghentikan capture bersih.
- Host: **mutex ter-poison tidak lagi merobohkan proses** — semua kunci
  `control`/`paired` di jalur produksi memakai `recover_lock`, sehingga
  panic satu task media (video/audio/input) tidak menular jadi panic
  berantai di `main()` yang dulu memicu restart supervisor.
- Desktop (host Windows): **supervisor kebal server hang** — permintaan
  token signaling dan panggilan control API kini punya timeout
  (`AbortSignal.timeout` 10 dtk / 5 dtk, `execFile --identity-json` 15 dtk).
  Sebelumnya server signaling yang hang membekukan `startEngine` selamanya
  (guard `engineStarting` terus menyala), sehingga engine tak pernah lahir
  dan watchdog ikut diam.

## [6.3.0] - 2026-09-03

> **Rilis ulang — build 26 (3 Sep 2026).** Build 25 sempat terbit dalam
> keadaan belum lengkap (tanpa perbaikan layar hitam di bawah) lalu
> ditarik; karena build number tidak boleh dipakai ulang, rilis resmi
> 6.3.0 kini build 26. Aplikasi akan menyajikannya sebagai pembaruan bagi
> semua perangkat yang sempat memasang build 25.

### Ditambahkan
- Web: panel pengaturan sesi (tombol "Panel" di bar sesi) — volume audio
  PC, sensitivitas kursor trackpad, ketuk-untuk-klik, arah scroll, info
  host, dan tombol putus; tersimpan permanen di perangkat.

- Web: keyboard virtual QWERTY penuh di layar sesi — baris F1–F12, angka,
  simbol, panah, dan modifier lengket (Ctrl/Shift/Alt/Win ditahan sampai
  tombol berikutnya) — setara keyboard virtual aplikasi Android.
- Web: panel gaming dua sisi di layar sesi — gugus WASD + Shift/Ctrl di
  kiri, Spasi/E/Q/R/F/Esc/Enter di kanan; tombol tahan (down saat sentuh,
  up saat lepas) dengan glyph border-only yang tidak menutupi game.
- Web: mode trackpad — layar jadi touchpad: geser menggerakkan kursor
  relatif, ketuk singkat = klik kiri, dua jari = scroll. Pelengkap mode
  sentuh langsung yang sudah ada.


- Web dan desktop shell kini merender gambar inline di badan berita: baris
  `![keterangan](url)` menjadi gambar + keterangan. Hanya URL
  `app.xystudio.my.id` yang dirender (screenshot rilis dari
  `web/public/news/shots/`); baris lain tetap paragraf biasa. Ini bagian
  dari dukungan aturan screenshot `docs/NEWS_STYLE.md` — Android kini
  ikut merender gambar yang sama; halaman berbagi hanya memuat metadata.
- Aturan kerja agent AI: `AGENT.md` (satu sesi satu role, identitas
  kontributor `Nama - XySpace Team`, kewajiban jujur soal apa yang sudah
  dan belum diuji, izin push per sesi — wajib disetujui operator di
  `AGENT_BOARD.md` dan ditandai `Izin: <ID>` di body commit) dan
  `CONTRIBUTORS.md` (daftar hanya-tambah).
- `docs/NEWS_STYLE.md` dirombak: berita rilis kini wajib detail lengkap —
  setiap perubahan dijelaskan apa dan kenapa, ada bagian "Semua perubahan
  di versi X.Y.Z" dalam bahasa pengguna, dan setiap perubahan visual wajib
  screenshot asli dari build rilis (banner saja tidak cukup).

- Panduan wajib untuk menulis berita: [`docs/NEWS_STYLE.md`](docs/NEWS_STYLE.md).
  Berita bukan changelog — tanpa nama berkas, tanpa nomor versi di judul,
  ditulis untuk pengguna dengan penulis `Tim XySpace`.
- Kontrol mutu CI untuk Worker signaling: 19 test auth/OTP/rate-limit kini
  jalan di setiap PR (sebelumnya hanya saat deploy ke `main`).
- Pengawasan `gofmt` untuk signaling Go.
- **CI Build difilter per area** (`.github/workflows/build.yml`): job
  `changes` mendeteksi area yang tersentuh (Flutter, host, web, news,
  backend, packaging, meta) dan hanya job area itu yang berjalan —
  push agent Docs tidak lagi membayar build Flutter/Rust penuh, dan agent
  tidak saling menunggu run. `pubspec.yaml` ikut memicu rantai host
  supaya bump versi rilis tetap menghasilkan semua artefak yang
  dibutuhkan `release.yml`.
- **CI: build penuh kini manual** — push dan PR tidak lagi memicu build
  penuh. Yang tersisa otomatis hanya bagian web (push menyentuh `web/**`
  → Build terfilter → deploy Web). Build penuh, kemasan desktop, dan
  deploy berita/signaling hanya lewat `workflow_dispatch` — satu run
  utuh saat rilis benar-benar siap (bump versi → Build → Release →
  deploy → berita), jadi tidak ada lagi "hijau palsu" dari push
  perantara atau run terbuang.
- **`AGENT_BOARD.md`**: papan koordinasi agent — kunci sesi (siapa lagi
  kerja apa), antrean izin push, riwayat sesi. `AGENT.md` diperbarui:
  satu area satu agent, izin push per sesi (bukan izin tetap), dan ritual
  buka/tutup sesi di papan.
- **`verify-push-auth.yml`**: setiap push ke `main` diperiksa — semua
  commit non-merge wajib memuat `Izin: <ID-SESI>` dan ID-nya berstatus
  `DISETUJUI` di `AGENT_BOARD.md`; commit merge dan commit operator
  (`OPERATOR_LOGIN`) dikecualikan. Berfungsi sebagai audit, dan bisa
  dijadikan gerbang keras lewat branch protection. Saat pelanggaran
  terdeteksi, operator dikabari lewat ntfy (`NTFY_WEBHOOK`) atau Telegram
  (`TELEGRAM_BOT_TOKEN` + `TELEGRAM_CHAT_ID`) — keduanya opsional.
- `deploy-web.yml` melewati deploy dengan peringatan (alih-alih gagal)
  bila run Build pemicunya tidak memuat artefak `XyDesk-Web` — misalnya
  karena perubahan tidak menyentuh `web/`.
- Sitemap web kini memuat semua halaman (`/download`, `/news`, `/connect`,
  `/legal`) — sebelumnya hanya beranda, jadi mesin pencari tidak diberi
  tahu halaman lain ada.
- Folder `web/public/news/shots/` disiapkan (plus aturan penamaan) sebagai
  wadah screenshot artikel berita sesuai `docs/NEWS_STYLE.md`.
- Komentar berita di web kini punya wajah: foto profil unik per nama
  (dihasilkan otomatis, gratis, tanpa akun), dan nama komentator baru
  berupa nama manusia (mis. "Raka Saputra") menggantikan label
  "tamu-xxxx" — tetap anonim dan stabil per perangkat.
- `HANDOFF.md`: papan serah-terima antar role agent — temuan lintas area
  kini wajib ditulis di sana, bukan hanya diucapkan.
- Host: konversi RGBA → NV12 dipisah ke modul lintas platform `pixfmt.rs`
  dengan uji regresi (warna referensi BT.601 full-range, rata-rata blok
  2x2, pemakaian ulang buffer). Sebelumnya fungsi ini tersembunyi di dalam
  modul Windows `screen.rs` tanpa satu pun pengujian — padahal ia jalur
  piksel menuju NVENC.
- Host: `nvenc_config.rs` memetakan kode status NVENC (0–26 dari
  `nvEncodeAPI.h`) ke nama resmi + petunjuk manusiawi. Sebelumnya log
  fallback ke openh264 hanya menulis "NVENC status 15" — tidak bisa
  dibedakan versi struct yang salah dari GPU yang tidak didukung. Perakit
  `build_config`/`build_init` ikut dipindah ke sana dan dikunci uji.
- Host: bitrate video kini bisa diatur dari shell — control API dapat aksi
  baru `video-bitrate` (Mbps, 1–50) dan `/status` melaporkan
  `targetBitrateBps`. Sebelumnya target 8 Mbps terpatri konstan.
- Uji unit Go untuk signaling self-host (`signaling/auth_test.go` +
  `router_test.go`): ikatan role pada token, middleware, arah relay, filter
  daftar host. `go vet` + `go test` kini ikut wajib hijau di job
  `check-signaling` — dulu hanya `gofmt` yang diawasi CI.
- `engines: node >= 22` dipin di `cloudflare/package.json` dan
  `news/package.json` — wrangler 4.123 menolak Node 20; dulu tidak ada
  pengaman eksplisit sehingga lingkungan lokal bisa rusak diam-diam.

- Client Flutter: komentar berita kini punya wajah. Komentar dan balasan
  menampilkan avatar bulat — foto pendiri XySpace untuk komentar resmi,
  DiceBear `adventurer` SVG (dari nama penulis, gratis tanpa kunci API)
  untuk lainnya — dengan fallback siluet bila gambar gagal termuat
  (`lib/widgets/official_badge.dart` + helper `lib/features/news/`
  `news_avatar.dart`). Sebelumnya kolom komentar tidak punya avatar.
- Client Flutter: badan artikel berita kini merender gambar inline. Baris
  `![keterangan](url)` dari domain `app.xystudio.my.id` menjadi gambar
  berbingkai + keterangan; baris lain tetap paragraf biasa — meniru web
  (`NEWS_IMAGE_BLOCK` di `web/src/App.tsx`). Sebelumnya seluruh isi berita
  ditampilkan sebagai teks polos, sehingga berita bergambar tidak bisa
  tampil di Android.
- Client Flutter: kontrak identitas komentator dikunci pakai uji otomatis
  (`test/news/news_identity_test.dart`) — nama manusia deterministik dan
  URL avatar DiceBear dicek sesuai aturan `web/src/news.ts`, supaya aturan
  yang sama tidak bergeser tanpa terlihat nanti.

### Diubah
- Web: badge penulis/komentar resmi kini bertuliskan **XySpace** (sebelumnya
  "Resmi").
- Web: teks beranda ditulis ulang membumi — hero tanpa jargon
  "glass-to-glass", empat kartu fitur kini bicara manfaat pengguna, bukan
  istilah teknis internal (HUD glyph, modifier sticky, NVENC).
- Worker berita: CORS mengizinkan header `X-Admin-Token` agar mode founder
  di web bisa mengirim komentar resmi dari browser.

- Web: kata penting (cetak tebal) di badan artikel berita kini berwarna
  ungu brand agar penekanan langsung terlihat.
- AGENT.md: aturan logo dipertegas — `design/logo-asli.png` (X ungu
  glossy) WAJIB dipakai semua platform, turunan hanya lewat
  `tool/gen_logo.py`.


- Client Flutter: nama komentator kini nama manusia deterministik dari
  sidik jari perangkat (daftar `_nameFirst`/`_nameLast`, hash
  `h = h*31 + codeUnit-at >> 0`) menggantikan label `tamu-xxxx`; pengguna
  lama yang masih tersimpan `tamu-*` ikut dibangkitkan ulang — selaras
  dengan web (`web/src/news.ts`), supaya perangkat yang sama selalu
  memunculkan nama yang sama.
- Client Flutter: penanda resmi penulis artikel dan komentar memakai foto
  pendiri XySpace (`app.xystudio.my.id/team/founder.jpg`) menggantikan
  badge logo X, meniru web. Bila gagal dimuat (mis. offline), kembalikan
  ke logo agar identitas resmi tetap terbaca.
- Client Flutter: token ungu brand diselaraskan dengan web
  (`lib/core/tokens.dart`): aksen utama `#7C3AED`, deep `#5B21B6`,
  lavender `#A78BFA` (sebelumnya `#7654F6`/`#6142D6` dari gradasi logo
  lama). Deep & lavender diekspos di `AppPalette` sebagai `accentDeep` dan
  `accentLavender`.

- **Token signaling server Go kini mengikat role** — format disamakan
  dengan Worker Cloudflare: `HMAC(secret, purpose \x00 role \x00 ts)`.
  Sebelumnya role tidak ditandatangani dan diambil dari pesan `hello`
  klien, sehingga token client bisa dipakai menyamar sebagai host di
  jalur self-host. Konsekuensi: token lama (tanpa role) ditolak — token
  berumur 5 menit, cukup terbitkan ulang.
- Relay signaling Go kini menegakkan arah seperti hub.js produksi
  (`pair`/`offer` hanya client→host, `pair-response`/`answer` hanya
  host→client, `ice`/`bye` beda role), dan `hello` wajib membawa id yang
  sudah diverifikasi token. Daftar perangkat Go hanya membagikan host —
  id client tidak disiarkan (sepadan dengan Worker yang sengaja
  mengembalikan daftar kosong).
- Email berita (`news/src/worker.js`) tidak lagi memuat gambar
  `badge-xyspace.png` yang sudah hilang sejak rebrand (404 di email):
  header memakai `logo.png` baru dan blok penulis memakai foto founder,
  selaras dengan web.
- **Logo baru: X ungu kaca.** Diganti lewat jalur resmi —
  `design/logo-asli.png` diperbarui, `tool/gen_logo.py` melahirkan ulang
  semua turunan: ikon launcher Android (5 kepadatan, legacy + adaptive),
  splash, favicon web, ikon PWA, `.ico` Windows, dan aset Flutter.
- Profil pengirim berita di web kini foto founder XySpace — bukan lagi
  badge logo X — di baris penulis artikel dan komentar resmi.
- Design pass "Quiet Surface v2" untuk seluruh UI web: ungu inti
  diselaraskan dengan logo baru, tombol/input/dropdown/kartu/grid/state
  kosong-error/skeleton/scrollbar/focus-ring dirapikan jadi satu bahasa
  visual; menghormati `prefers-reduced-motion`.
- Tema web kini putih bersih (`#ffffff`) sebagai bawaan — halaman, PWA,
  dan bar browser satu warna.
- Hero halaman utama dirombak: terang, logo X asli mengambang di kolam
  cahaya — layar tiruan "LIVE · 9 ms / 60 FPS" dan gambar mengambang
  dihapus (angka pura-pura tidak sejalan dengan nilai kejujuran produk).
- Halaman Connect ditata ulang: kartu terpusat, ID perangkat jadi angka
  besar di tengah, tombol riwayat berbentuk chip, dan tombol
  "Konek sekarang" kini tombol utama sungguhan — sebelumnya class-nya
  tanpa sengaja bergaya kartu (balok putih besar) dan beberapa elemen
  (riwayat, kepala field) tidak punya gaya sama sekali.
- Waktu komentar berita kini relatif ("5 menit lalu", "2 hari lalu");
  lewat sebulan kembali ke tanggal biasa.
- Foto profil pengirim berita kini bulat penuh di semua ukuran (dulu
  kotak membulat di baris penulis artikel).
- Warna tema PWA web disamakan ke Paper `#fafaf9` (mengikuti `tokens.dart`
  dan `style.css`) — manifest sebelumnya `#ffffff`, bar PWA Android bisa
  beda warna dari situs.
- Form komentar berita di web dipindah ke bawah daftar komentar (dulu di
  atas — menyulitkan setelah membaca), dengan gulir otomatis saat menekan
  "Balas".
- **Logo asli dipakai di semua platform.** `design/logo-asli.png` menjadi satu
  sumber; `tool/gen_logo.py` menurunkan darinya: ikon aplikasi Android
  (5 kepadatan, legacy + adaptive), splash Android, logo web, favicon, ikon
  PWA, `.ico` Windows, dan aset Flutter. Mengedit berkas hasil generate tidak
  lagi ada gunanya — generator akan menimpanya.
- `host/README.md`: tabel status tidak lagi menulis sumber video DXGI+NVENC
  "belum diimplementasi". Implementasinya sudah ada (`screen.rs` +
  `nvenc.rs`); yang belum hanya verifikasi di lab Windows nyata dan jalur
  zero-copy. Bagian "Rencana implementasi" diganti uraian cara kerja, dan
  struktur folder ikut disesuaikan.
- Host: konfigurasi NVENC dikecilkan buffer VBV dari `bitrate/2` (boleh
  menahan bit sampai ~0,5 detik) menjadi 1 frame (`bitrate/60`) dan
  `tuningInfo` disetel `LOW_LATENCY`. Keduanya mengejar target roadmap
  (< 40 ms glass-to-glass): buffer lama dan tuning `UNDEFINED` bertentangan
  langsung dengan target itu. Kontraknya dikunci uji di `nvenc_config.rs`.
- Host: `TARGET_BPS` bukan lagi konstanta — jadi setting runtime
  (`screen::target_bitrate_bps`/`set_target_bitrate_bps`, bawaan 8 Mbps).
  Kedua jalur encoder (openh264 & NVENC) membacanya saat encoder dibangun,
  dan perubahan di tengah sesi memicu respawn capture dengan encoder baru.

### Diperbaiki

- Layar sesi web ditata ulang: tombol Audio/Mic/Clipboard/Keyboard/
  Fullscreen kini pil overlay rapi di atas video (dulu teks polos tanpa
  gaya yang mengalir di tengah video), dua tombol HUD mouse tidak lagi
  menumpuk di satu titik, dan keyboard sentuh melayang di atas kontrol.
- Halaman Connect kini responsif di layar sempit: kartu, ID besar,
  tombol riwayat, dan bar akun menyesuaikan; tombol konek selebar layar.
- Halaman Connect web: kotak hitam 16:9 tidak lagi tampil sebelum
  tersambung (CSS `display: flex` mengalahkan atribut `hidden`), dan teks
  status koneksi kini mengalir rapi di dalam form — bukan melayang absolut
  di posisi acak.
- **Web produksi: semua deep link (bukan halaman muka) balas 500.**
  `/legal`, `/download`, `/connect`, `/news`, dan setiap tautan berita yang
  dibagikan berakhir di halaman error Cloudflare 1101 — binding `ASSETS`
  tidak pernah dideklarasikan di `web_deploy/wrangler.toml`, jadi worker
  crash saat menyajikan aplikasi untuk pengunjung biasa (crawler sosial
  tidak kena, karena jalur OG tidak memakai binding itu). Direproduksi di
  `wrangler dev` lokal, diperbaiki satu baris (`binding = "ASSETS"`), dan
  diverifikasi ulang: deep link 200, fallback SPA jalan, halaman OG bot
  tetap utuh.
- CORS Worker gagal-tertutup: tanpa `CORS_ORIGINS` tidak ada origin yang
  diizinkan (sebelumnya `*`). `*` tetap tersedia bila ditulis eksplisit.
  Dikunci 10 test baru.
- Inventaris lisensi tidak lagi menghitung dependensi pengembang
  (`flutter_lints`, `lints`, dan paket test) sebagai komponen yang ikut ke
  perangkat pengguna: 490 menjadi 488.
- `npm test` di `news/` tidak lagi gagal (skrip `test` ditambahkan).
- Host: `rgba_to_nv12` kini menolak dimensi ganjil secara eksplisit
  (`debug_assert!`). Sebelumnya kode memakai `.min()` defensif yang memberi
  kesan aman, padahal dimensi ganjil tetap menulis melewati batas plane Y —
  kontrak "dimensi genap" kini terdokumentasi, bukan tersirat.
- **Host: layar sesi yang tampak "terhubung" tapi tetap hitam ditutup.**
  Frame pembuka yang membawa parameter gambar (SPS/PPS + IDR) ditulis
  sebelum jalur data WebRTC siap, sehingga dibuang jaringan; klien lalu
  menerima banyak paket gambar tanpa pernah bisa mulai mendecode
  (`framesDecoded` 0 selamanya). Kini host menunggu sambungan siap
  (Connected) baru menulis video, dan saat sambungan siap meminta encoder
  mengirim gambar pembuka segar. Diverifikasi end-to-end: pola uji tampil
  di Chrome asli (707 frame ter-decode; sebelumnya 0). Regresi dikunci di
  test loopback: SPS/PPS WAJIB tiba di klien, bukan sekadar paket.

- Inventaris lisensi pihak ketiga (`docs/THIRD-PARTY-LICENSES.md`,
  `lib/core/license_stats.dart`, `web/src/licenses.generated.ts`,
  `web/src/license-total.ts`) kini konsisten dengan perhitungan CI:
  dihitung ulang dengan SDK Flutter yang sama persis dengan CI, sehingga
  gerbang "Inventaris lisensi usang" tidak lagi merah.
- Rilis tidak lagi gagal merah saat Build pemicunya hanya build terfilter
  (tanpa artefak lengkap) — dilewati dengan peringatan sebagai gantinya.

## [6.2.2] - 2026-09-01

> Logo baru, layar sesi tanpa panel melayang, angka kualitas yang benar-benar
> dibaca dari koneksi, dan perbaikan notifikasi rilis.

### Ditambahkan

- Statistik sesi nyata dibaca dari `getStats()` WebRTC tiap detik: ukuran
  gambar, fps, pemakaian data, ping, paket hilang, dan codec. Angka ini
  dipakai panel Gambar dan panel Sesi.
- Pemilih layar host pindah ke dalam panel, lengkap dengan resolusi tiap
  monitor.

### Diubah

- Logo aplikasi kembali ke bentuk tiga dimensi yang lama. Ikon Android, ikon
  web, favicon, dan gambar splash ikut dibuat ulang dari berkas master yang
  sama.
- Layar sesi: bar melayang di tengah atas dan dock di tengah bawah dihapus,
  diganti satu rail tipis di tepi kanan yang bisa dilipat.
- Sidebar sesi: kepala panel menampilkan nama PC dan status sambungan, tab
  berubah jadi empat kolom sama lebar dengan ikon, tidak perlu digeser lagi.
- Syarat & Ketentuan diperluas dari 7 menjadi 16 bagian; Kebijakan Privasi
  dari 7 menjadi 15 bagian, termasuk hak pengguna menurut UU 27/2022, daftar
  penyedia pihak ketiga, dan lama penyimpanan tiap jenis data. Halaman Legal
  di web mengikuti isi yang sama.

### Diperbaiki

- Tombol suka di halaman berita tidak pernah terlihat aktif. Parameter untuk
  hati terisi ada di kode tapi tidak pernah dipakai, dan status suka tidak
  pernah dibaca ulang dari server saat artikel dibuka. Sekarang hatinya
  terisi, jumlahnya berubah seketika, dan status suka bertahan.
- Notifikasi rilis tidak terkirim sejak v1.3.0. Perangkat sudah memberi izin
  di Android tetapi belum opt-in di SDK, jadi tidak masuk segmen tujuan dan
  OneSignal menolak dengan "All included players are not subscribed".
  Aplikasi kini menyalakan langganan otomatis bila izin sudah ada dan
  pengguna tidak sengaja menjedanya, dan alur rilis mencoba ulang ke seluruh
  langganan bila segmen utama kosong.
- Panel Sesi tidak lagi menulis "Belum diimplementasikan", "Tidak terhubung",
  dan "Tidak aktif" secara permanen. Isinya sekarang mengikuti keadaan sesi.

### Dihapus

- Delapan gambar di folder publik web yang sudah tidak dirujuk siapa pun.

### Performa

- Inventaris lisensi dipisah jadi berkas sendiri dan baru diunduh saat
  halaman Legal dibuka. Bundel awal web turun dari 294 kB ke 245 kB
  (gzip 84,2 kB ke 77,6 kB).

## [6.2.1] - 2026-09-01

> Rilis kecil soal cara XyDesk berbicara dan tampil. Tidak ada perubahan pada
> jalur media.

### Diubah

- **Tombol berbagi berita memakai logo asli.** WhatsApp, Telegram, X, dan
  Facebook sebelumnya diwakili ikon generik — gelembung chat, pesawat kertas,
  rantai tautan. Sekarang logo resminya, lengkap dengan warna mereknya.
  Facebook yang sebelumnya tidak ada di aplikasi juga ditambahkan.
- **Bahasa di seluruh aplikasi ditulis ulang.** Teks pengaturan, halaman
  unduh, dan halaman lisensi sebelumnya memakai istilah teknis yang hanya
  jelas bagi yang membuatnya: "codec", "bitrate", "kanal papan klip belum ada
  di protokol", "alokasi bandwidth jaringan". Sekarang ditulis seperti orang
  menjelaskan ke temannya.

  Beberapa contoh:

  | Sebelum | Sesudah |
  |---|---|
  | Pengodean akselerasi perangkat keras | Cara PC memproses gambar sebelum dikirim |
  | Alokasi bandwidth jaringan | Batas pemakaian internet selama sesi |
  | Belum didukung Host — kanal papan klip belum ada di protokol | Belum bisa dipakai. Aplikasi XyDesk di PC belum mendukung fitur ini. |
  | Tinjau fungsi yang membutuhkan izin sistem | Lihat izin yang dipakai XyDesk dan alasannya |
  | Bandingkan build dengan Release resmi | Cek dan pasang versi terbaru |

### Diperbaiki

- **Jumlah komponen di halaman Lisensi tidak bisa basi lagi.** Angkanya
  diketik tangan, dan langsung salah begitu satu paket ditambahkan. Sekarang
  `tool/gen-licenses.mjs` ikut membangkitkan `lib/core/license_stats.dart`,
  dan CI menolak kalau angkanya tidak cocok dengan lockfile.

### Ditambahkan

- Paket `flutter_svg` untuk menggambar logo merek di aplikasi.
- Simple Icons (CC0-1.0) dicatat di inventaris lisensi. Merek dagang tetap
  milik masing-masing pemiliknya.

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
- **Pengaturan "Layar tetap menyala saat sesi"** (bawaan aktif). Selama sesi
  pengguna sering hanya menonton; tanpa ini Android memadamkan layar dan sesi
  terlihat seolah putus.
- **"Reset pengaturan ke bawaan"** di Sistem & privasi. Bahasa antarmuka
  sengaja tidak ikut direset — mengembalikan pengguna ke bahasa yang tidak ia
  mengerti membuat layar ini sendiri sulit dipakai untuk membatalkannya.

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

- **Sakelar "Refresh rate tinggi" sekarang benar-benar bekerja.** Sisi Dart
  memanggil `setHighRefreshRate` pada channel `flutter/platform_views` —
  metode yang tidak pernah ada di Flutter — dan kegagalannya ditelan
  `catchError`. Preferensi tersimpan rapi ke disk dan tidak berefek apa pun.
  Implementasi nyatanya kini ada di `MainActivity.kt`, dan pada perangkat yang
  panelnya hanya mendukung satu refresh rate, sakelarnya dinonaktifkan dengan
  alasan yang ditulis apa adanya.
- **Sakelar "Getaran" berlaku di seluruh aplikasi.** Sebelumnya hanya dibaca
  layar sesi; tombol lain memanggil `HapticFeedback` langsung. Kini semua
  lewat `AppHaptics`.
- **"Sinkronisasi papan klip" berhenti berpura-pura.** Protokol host belum
  punya kanal papan klip sama sekali, tetapi sakelarnya menyala secara bawaan.
  Kini dinonaktifkan dengan alasannya.
- **Subtitel "Tema, bahasa, dan kenyamanan visual" tidak lagi berbohong** —
  mode gelap memang sengaja tidak ada, dan halamannya sekarang mengatakan itu.
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

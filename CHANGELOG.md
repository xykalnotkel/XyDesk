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
- Web: pemindai QR di halaman Connect — arahkan kamera ke QR XyDesk Host
  dan ID terisi otomatis; pakai BarcodeDetector bawaan browser, jsQR
  (dimuat lambat) sebagai cadangan; format payload sama dengan aplikasi
  Android (`xydesk://connect?id=` atau 9 digit polos).
- Web: bagian "Cara main" di halaman Connect — panduan 4 langkah dengan
  toggle sisi client/sisi host, teks dari GuidePage aplikasi Android.
- Web: blok "Dukung kami di" (Telegram, WhatsApp, TikTok) di halaman
  Connect — tautan sama dengan aplikasi Android.

### Diubah
- Host: durasi sampel video (maju timestamp RTP per frame) diseragamkan ke
  FPS nominal 60 (16,67 ms) lewat `NOMINAL_FPS`/`frame_duration()` —
  sebelumnya angka 33 ms terpatri acak di `main.rs`, dan sumber pola uji
  (non-Windows) kini berpacing 60 fps, bukan ~30 fps.

## [6.3.0] - 2026-09-03

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

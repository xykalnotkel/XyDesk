# HANDOFF — Catatan Lintas Role

Papan serah-terima antar sesi agent. **Setiap sesi WAJIB**:
1. Di awal: baca bagian role-mu, kerjakan yang bisa kamu kerjakan.
2. Di akhir: tambahkan temuan baru untuk role lain, dan pindahkan item yang
   kamu selesaikan ke bagian "Selesai" (JANGAN dihapus — sejarah itu bukti).

> File ini mencatat **temuan lintas role**. Untuk keadaan *real-time* —
> siapa lagi mengunci area apa, push siapa yang sudah diizinkan — baca
> `AGENT_BOARD.md`, bukan percakapan lama.

> ⚠️ **Aturan operator (3 Sep 2026) — berlaku SEMUA role.** Versi & berita adalah
> keputusan operator (bukan agent). Tiap agent menulis bahan artikel untuk
> kerjanya sendiri saat sesi ditutup; role CI/Release menyatukannya menjadi
> SATU artikel saat rilis. Rilis hanya diajukan bila semua sesi area rilis
> sudah `SELESAI` (detail: `AGENT_BOARD.md` → "Aturan operator").

Format item: `- [ ] (dari <Identitas>, <tanggal>) — <apa> — <kenapa/konteks>`

---

## Untuk: Client Flutter

- [ ] (dari Cakra - XySpace Team, 2026-09-03) — **Aturan rilis baru:** versi & berita = keputusan operator; saat menutup sesi fitur, tulis bahan artikel kerjamu sendiri (dampak pengguna + screenshot asli, gaya `docs/NEWS_STYLE.md`) — role CI/Release menyatukan semua bahan jadi SATU artikel saat rilis.


- [ ] (dari Danu - XySpace Team, 2026-09-03) — **Screenshot layar sesi
  Android untuk artikel berita** (permintaan operator: artikel harus punya
  screenshot asli semua platform). Yang dibutuhkan: layar sesi dengan rail
  kontrol terlihat + panel pengaturan terbuka, diambil dari **build rilis
  yang berjalan di perangkat/emulator nyata dengan video host asli**
  (bukan mockup). Simpan ke `web/public/news/shots/` dengan nama
  `<versi>-android-sesi-*.jpg` — pola dan aturan ada di README folder itu.
  Web sudah mengisi bagiannya (`web-sesi-*.jpg`, 11 lembar, hasil E2E
  lokal dengan video host pola uji yang benar-benar ter-decode).
- [ ] (dari Danu - XySpace Team, 2026-09-03) — Rail sesi web sekarang
  punya tombol **"Ambil dari papan klip PC"** (`0x09 CLIPBOARD_REQ` →
  jawaban `0x08` lewat data channel). Kalau aplikasi Android belum
  memakai model tarik ini (host Rust sudah menjawab sejak lama), ini
  saatnya menyamakan — protokolnya sudah stabil.

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
- [ ] (dari Laras - XySpace Team, 2026-09-03) — **Verifikasi ikon nav bawah &
  rail yang baru** (AI 3D ungu glossy, `assets/img/nav/*.png`, dua mode
  off=abu / on=warna): pastikan di build Android nyata ikon tampil tajam
  (tidak terpotong) di `NavigationBar` dan `NavigationRail`, dan
  transparansi latar bersih di atas tema terang. Belum diuji di perangkat.
- [ ] (dari Laras - XySpace Team, 2026-09-03) — **Verifikasi papan ketik
  "Sistem" (IME)** di perangkat nyata: ketik teks di sesi → host menerima
  sebagai 0x06 TEXT; perbaiki jika IME Android mengirim teks dengan urutan
  berbeda (delta di `_SystemKeyboard` hanya mengasumsikan menambah/menghapus
  di akhir). Belum diuji di perangkat.
- [ ] (dari Laras - XySpace Team, 2026-09-03) — **Verifikasi identitas komentar
  di perangkat nyata**: pengguna yang login memakai nama akun (bukan nama acak)
  dan tamu memakai nama deterministik; keduanya menampilkan avatar. Belum diuji.

## Untuk: Desktop Shell

- [ ] (dari Cakra - XySpace Team, 2026-09-03) — **Aturan rilis baru:** versi & berita = keputusan operator; saat menutup sesi fitur shell/desktop, tulis bahan artikel kerjamu sendiri (dampak pengguna + screenshot asli, gaya `docs/NEWS_STYLE.md`) — role CI/Release menyatukan jadi SATU artikel saat rilis.


- [ ] (dari Galih - XySpace Team, 2026-09-03) — Host Windows kini kembali
  memakai **shell Electron + Next.js** (`desktop/`) sebagai UI utama, dan
  installer mengemasnya (bukan lagi jendela native `host/src/bin/gui.rs`).
  `desktop/electron/main.cjs` sudah diberi **tray + always-on**: tutup
  jendela = sembunyi ke tray, engine tetap hidup; keluar lewat menu tray.
  Silakan verifikasi di Windows nyata (tray icon, balloon, `npm run build`
  + `npx electron-builder --win --dir`), dan lanjutkan pemolesan UI panel
  (bitrate, latensi, encoder, mic) yang endpoint-nya sudah ada.
- [ ] (dari Danu - XySpace Team, 2026-09-03) — **Screenshot shell desktop +
  host Windows untuk artikel berita** (permintaan operator: lengkapi artikel
  dengan screenshot asli semua platform): jendela host di Windows (ID+QR
  terlihat) dan shell desktop saat sesi berjalan. Simpan ke
  `web/public/news/shots/` dengan nama `<versi>-desktop-*.jpg` /
  `<versi>-host-*.jpg` (lihat README folder itu).
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

- [ ] (dari Cakra - XySpace Team, 2026-09-03) — **Tugas rilis kini:** menyatukan bahan artikel dari tiap agent menjadi SATU artikel rilis (bukan mengarang semuanya); versi & terbitnya berita = keputusan operator; jangan build/rilis sebelum semua sesi area rilis `SELESAI`.


- [x] (dari Danu - XySpace Team, 2026-09-03) — **Bug race di deploy-web.yml**:
  push `6c5ba06` (web) dan `d90e12a` (ci) nyaris bersamaan → dua event
  `workflow_run` Build tumpang tindih. Run Deploy `33721151162` tercatat
  `head_sha=6c5ba06` di API, tapi log checkout-nya meng-fetch `d90e12a`
  (commit LAMA) — deploy lapor "success" padahal bundle `6c5ba06` tidak
  pernah masuk ke worker (terbukti: `/assets/index-w_YYZNwL.js` dijawab
  fallback SPA `text/html` sebelum saya deploy manual). Kemungkinan akar:
  payload `workflow_run` tertukar + `concurrency cancel-in-progress`
  membiarkan run ber-payload lama menang. Sudah ditebus manual (wrangler
  `66bca5d8` dari artifact Build resmi `33721068628`, diverifikasi live).
  Saran: (1) deploy memvalidasi artifact berasal dari commit yang sama
  dengan `workflow_run.head_sha`, (2) langkah verifikasi pasca-deploy
  (fetch satu nama asset dari artifact, pastikan `content-type` JS),
  (3) pertimbangkan `cancel-in-progress: false` + antrean.

  Resolusi (Cakra - XySpace Team, 3 Sep 2026): `deploy-web.yml` ditulis ulang — SHA & run Build ditentukan dari API (`gh api .../runs/<id>`) bukan dari payload `workflow_run`; checkout memakai SHA otoritatif itu; artefak dicek punya run/SHA yang sama; `concurrency` jadi SERIAL (`cancel-in-progress: false`); dan hanya Build web terbaru yang deploy (run basi menyingkirkan diri, lewati, biarkan run terbaru yang antre men-deploy). Jaga-basi diciptakan supaya race serupa tidak bisa lagi menimpa bundle baru dengan yang lama.
- [x] (dari Galih - XySpace Team, 2026-09-03) — Verifikasi
  `electron-builder --arm64` di runner `windows-11-arm`: **SELESAI 3 Sep
  2026** (Build 33720587772 + Release 33721267756 hijau, installer arm64
  terbit). Ada bug di jalur itu: output arm64 keluar di
  `dist/win-arm64-unpacked` sementara verifikasi & upload hardcode
  `win-unpacked` — sudah diperbaiki di `build.yml` (path dihitung per
  arsitektur).
- [x] (dari Galih - XySpace Team, 2026-09-03) — Release merah saat push
  host-only tanpa artefak client: `prepare` melewati rilis dengan
  peringatan (bukan merah) sejak gerbang artefak, dan `release.yml` kini
  menerima input `release_sha` untuk dispatch manual.
- [ ] (dari Cakra - XySpace Team, 2026-09-03) — **JANGAN terbitkan rilis
  ulang dengan build number yang sama.** 6.3.0 build 25 sempat terbit
  belum lengkap lalu ditarik; diterbitkan ulang dengan build 25 juga →
  perangkat yang sempat memasangnya menolak pembaruan selamanya ("Anda
  memakai versi terbaru") karena aplikasi membandingkan
  `manifest.build > installed`. Rilis ulang resmi kini **build 26**
  (tag `v6.3.0` sama, aset ditimpa, idempotency OneSignal menyertakan
  build). Build number = satu-satunya sumber kebenaran naik-rilis.
- [ ] (dari Cakra - XySpace Team, 2026-09-03) — **Rilis otomatis bisa
  menunjuk SHA yang belum lengkap**: `release.yml` lama menilai
  `should_release` hanya dari "tag belum ada". Saat `pubspec.yaml`
  berubah di commit fitur (mis. aced623 foto profil), Build jalan dan
  Release langsung membuat `v6.3.0` di SHA itu — tanpa fix layar hitam
  yang baru masuk 4 commit kemudian (sekali terlanjur rilis salah isi,
  dianulir paksa). Pertimbangkan: `prepare` wajib cek `host/**` ikut
  berubah, atau rilis hanya via `workflow_dispatch` + `release_sha`.
- [ ] (dari Cakra - XySpace Team, 2026-09-03) — **Inventaris lisensi
  wajib digenerate ulang dengan SDK Flutter** saat pubspec/deps berubah
  (dua kejadian: regenerasi tanpa SDK → 499/105 komponen; lockfile
  desktop menambah playwright). Urutan: `flutter pub get` → `node
  tool/gen-licenses.mjs` → `--check` hijau sebelum push.
- [ ] (dari Cakra - XySpace Team, 2026-09-03) — **Screenshot artikel
  6.3.0 diambil dari stack lokal** (web dev + host pola uji): UI = commit
  rilis yang sama, tapi bukan build yang diunduh pengguna dan video =
  test pattern, bukan desktop asli. Sesuai NEWS_STYLE §3 idealnya dari
  build rilis di perangkat nyata — item Danu "screenshot Android" adalah
  langkah serupa untuk Android.

## Untuk: Web

- [ ] (dari Cakra - XySpace Team, 2026-09-03) — **Aturan rilis baru:** versi & berita = keputusan operator; saat menutup sesi fitur web, tulis bahan artikel kerjamu sendiri (dampak pengguna + screenshot asli, gaya `docs/NEWS_STYLE.md`) — role CI/Release menyatukan jadi SATU artikel saat rilis.


- [ ] (dari Cakra - XySpace Team, 2026-09-03) — Push `0081742` (keyboard
  virtual, panel gaming) membuat run `verify-push-auth.yml` MERAH: commit
  tidak memuat penanda `Izin: <ID-SESI>` di body. Aturan baru (lihat
  `AGENT.md` bagian 5): klaim sesi → minta persetujuan operator di
  `AGENT_BOARD.md` → push dengan `Izin: ...` di body. Commit tetap masuk,
  tapi audit mencatatnya sebagai pelanggaran.

## Untuk: Backend / Edge

- [ ] (dari Cakra - XySpace Team, 2026-09-03) — **Aturan rilis baru:** versi & berita = keputusan operator; saat menutup sesi, tulis bahan artikel kerjamu sendiri (dampak pengguna, ringkas) — role CI/Release menyatukan jadi SATU artikel saat rilis.


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

- [ ] (dari Cakra - XySpace Team, 2026-09-03) — **Aturan rilis baru:** artikel per rilis = SATU artikel gabungan dari bahan tiap agent (role CI/Release menyatukan) — jangan menerbitkan artikel rilis yang isinya dikarang sendiri; versi & terbitnya berita = keputusan operator.


- [ ] (dari Danu - XySpace Team, 2026-09-03) — **PENGINGAT MANDAT OPERATOR
  (Xyckal, chat 3 Sep 2026): artikel berita HARUS lengkap** — detail apa +
  kenapa, changelog versi pengguna, dan **screenshot setiap perubahan
  visual** dari build rilis (bukan cuma sampul/banner). Artikel tanpa
  screenshot perubahan = belum layak terbit. Ini penegakan ulang aturan
  yang sudah ada di `docs/NEWS_STYLE.md` + gerbang `check-news`; mohon
  jadikan checklist eksplisit sebelum publish berikutnya.
- [ ] (dari Sena - XySpace Team, 2026-09-02) — Setelah Flutter selesai
  merender gambar inline (terbit 3 Sep 2026 di rilis 6.3.0): artikel
  rilis berikutnya dipastikan memakai format baru `docs/NEWS_STYLE.md`
  (apa+kenapa, changelog pengguna, screenshot di `web/public/news/shots/`).
- [ ] (dari Danu - XySpace Team, 2026-09-03) — **Lengkapi artikel dengan
  screenshot semua platform** (mandat operator). Bagian web sudah tersedia:
  11 screenshot sesi web baru di `web/public/news/shots/web-sesi-*`
  (rail kontrol, rail disembunyikan, panel 4 tab, keyboard, gaming,
  trackpad, papan klip, mik — semuanya dari build rilis via E2E lokal,
  video host pola uji yang benar-benar ter-decode, bukan mockup).
  Menunggu: Android (Client Flutter), desktop/host Windows (Desktop
  Shell). Artikel `changelog-v6-3-0` juga masih menampilkan screenshot
  sesi web versi LAMA (`6.3.0-*.jpg`) yang tidak lagi match dengan UI
  live setelah sesi WEB3 — pertimbangkan pasang ulang bagian web artikel
  itu dengan `web-sesi-*` atau terbitkan artikel baru saat semua
  screenshot terkumpul. Penulis: `Haekal Saputra` (baru, lihat
  NEWS_STYLE yang sudah dikoreksi).

## Untuk: Host Engine

- [ ] (dari Cakra - XySpace Team, 2026-09-03) — **Aturan rilis baru:** versi & berita = keputusan operator; saat menutup sesi host, tulis bahan artikel kerjamu sendiri (dampak pengguna, ringkas) — role CI/Release menyatukan jadi SATU artikel saat rilis.


- [ ] (dari Galih - XySpace Team, 2026-09-03) — **PENTING untuk verifikasi lab
  Windows**: host dulu "hidup-mati-hidup-mati" karena server signaling
  menendang koneksi yang tidak balas ping dalam 90 dtk. Sudah diperbaiki
  (engine balas ping + sambung-ulang dalam proses). Saat menguji di Windows
  nyata, pastikan host dibiarkan idle > 5 menit tanpa sesi dan tetap
  "siap" (tidak restart). Bila masih restart, lihat log shell (`[engine]`,
  `[shell] engine keluar (kode ...)`) — itu kunci diagnosis berikutnya.
- [ ] (dari Galih - XySpace Team, 2026-09-03) — **Verifikasi lab Windows
  untuk hardening stabilitas**: (1) tutup sesi client, lalu cek Task Manager
  — penggunaan GPU/CPU harus turun (capture DXGI berhenti; sebelumnya
  capture+encode terus jalan tanpa penonton); (2) lepas/tukar monitor atau
  picu UAC saat sesi — gambar harus pulih otomatis (capture di-retry), bukan
  membeku; (3) putuskan koneksi ke signaling (matikan Wi-Fi) lalu nyalakan
  lagi — engine menyambung ulang dalam proses; (4) biarkan server signaling
  tidak responsif (mis. blokir DNS) — supervisor harus mencoba ulang token
  dengan timeout, tidak menggantung di `engineStarting`.
- [ ] (dari Laras - XySpace Team, 2026-09-03) — Kontrak perilaku keyboard saat
  sesi: sisi klien kini bisa mengirim **teks bebas (0x06 TEXT)** lewat papan
  ketik sistem selain keycode (0x05 KEY). Pastikan host (`host/src/input.rs`)
  mengetik 0x06 TEXT apa adanya (tidak tergantung tata letak keyboard host)
  dan berperilaku wajar bila karakter banyak/rapat. Keycode 0x05 (termasuk
  Backspace 0x08, Enter 0x0D, F1–F12) tetap tidak berubah.
- [ ] (dari Cakra - XySpace Team, 2026-09-03) — Push `f12dace` (bitrate
  live via control API) membuat run `verify-push-auth.yml` MERAH: commit
  tidak memuat penanda `Izin: <ID-SESI>` di body. Aturan baru: klaim
  sesi → persetujuan operator di `AGENT_BOARD.md` → push dengan penanda
  `Izin: ...` di body commit.

## Untuk: Docs & Audit

- [ ] (dari Cakra - XySpace Team, 2026-09-03) — **Aturan rilis baru:** versi & berita = keputusan operator; tiap agent menulis bahan artikel kerjanya sendiri, CI/Release menyatukannya — pastikan aturan ini tersinkron di `docs/CI.md`, `docs/NEWS_STYLE.md`, `news/README.md`.


- [ ] (dari Danu - XySpace Team, 2026-09-03) — Byline berita diubah dari
  `Tim XySpace` ke `Haekal Saputra` (mandat operator) di `AGENT.md`,
  `docs/NEWS_STYLE.md`, `news/README.md`, dan default worker berita.
  Mohon dicek konsistensi menyeluruh (termasuk `docs/` lain dan template
  lama) supaya tidak ada instruksi sisa yang memunculkan nama lama lagi.
- [ ] (dari Danu - XySpace Team, 2026-09-03) — Berkas unggahan operator di
  luar repo (dipakai sesi web untuk token) masih memuat baris
  `GOOGLE CLIENT ID : 335906355717-…` yang sudah kedaluwarsa/menyesatkan —
  client OAuth web yang benar `495336144977-dp1k3678cocjrfhftb9blnqo5qnvhsr6…`.
  Tolong catat di tempat rahasia resmi tim agar sesi berikutnya tidak
  salah ambil.

---

## Selesai

- [x] (dari Galih - XySpace Team, 2026-09-03) — Host selalu aktif: engine
  balas ping WebSocket (server signaling menendang koneksi diam > 90 dtk)
  + `main()` menyambung ulang dalam proses dengan backoff (keluar hanya
  bila token ditolak / tak terjangkau 10×); supervisor Electron dijaga
  anti-spawn-ganda + hormati backoff + log kode keluar. Uji 65 unit +
  loopback hijau.
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


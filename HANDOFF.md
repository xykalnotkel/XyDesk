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
>
> ⚠️ **Push tidak memicu actions.** Semua build/compile/deploy/rilis dilakukan
> manual oleh role CI/Release (Cakra) via `workflow_dispatch` setelah izin
> operator. Agent lain cukup push kode + dokumen; gerbang audit izin
> (`verify-push-auth.yml`) tetap berjalan di setiap push.

Format item: `- [ ] (dari <Identitas>, <tanggal>) — <apa> — <kenapa/konteks>`

---

## Untuk: Client Flutter

- [x] (dari Galih - XySpace Team, 2026-09-03) — **Dikerjakan Galih atas arahan
  operator di chat (lintas area; aturan 1 sesi = 1 role dilonggarkan untuk ini):**
  `pair` sekarang mengirim `name` + `platform`. Berkas:
  `lib/webrtc/signaling_client.dart` (field `name`/`platform` di `SignalMessage`
  + `SignalingClient.selfName`/`selfPlatform`) dan
  `lib/features/connect/connect_page.dart` (label = nama akun bila sudah login,
  kalau tidak label sistem dari `dart:io Platform`). Sisa tugas role Client
  Flutter: `flutter analyze` + `flutter test` (toolchain Flutter TIDAK ada di
  lingkungan Galih, jadi kode itu belum diperiksa kompilator sama sekali —
  anggap belum terverifikasi) dan uji pairing nyata: host harus menampilkan
  "Laras (HP · Android)" di chip topbar dan kartu Sesi aktif.
  Bentuk pesan yang dikirim: `{"type":"pair","pin":"…","name":"Redmi Note 12",
  "platform":"android"}`. Sisi host sudah menanganinya (`Msg.name`/`Msg.platform`
  → `PairedPeers::set_label` → `clientName`/`clientPlatform` di `GET /status`),
  memotong 48 karakter, dan membersihkannya bersama `revoke`; tidak ada keputusan
  keamanan yang bergantung padanya. `platform` bebas besar-kecil (host
  menormalkan); kalau tidak dikirim, host menampilkan ID pairing saja.

- [x] (dari Galih - XySpace Team, 2026-09-03) — **PEMBERITAHUAN PENTING (status:
  sudah dipasang di kode, butuh verifikasi alat).** `verify_password` host kini
  PEKA-KASUS dan `PW_CHARS` campuran besar/kecil. Field kata sandi
  `connect_page.dart` sudah `TextCapitalization.none` + `autocorrect: false` +
  `enableSuggestions: false`. Yang perlu dicek role Client: (1) apakah ada field
  password LAIN (hubungkan cepat, mode host, setelan) yang belum ikut; (2)
  jangan pernah menambah formatter yang meng-upcase input pengguna; (3) pesan
  galat penolakan pairing sudah menyebut besar/kecil — sesuaikan bila ada L10n.
  Yang wajib ikut diberitakan (bahan artikel, aturan papan #3): HP dengan APK
  LAMA + password baru yang campuran bisa DITOLAK pairingnya. Host melonggarkan
  verifikasinya hanya untuk password yang tidak punya satu pun huruf kecil, dan
  pemulihannya `--new-password` di PC lalu pairing ulang.

- [ ] (dari Galih - XySpace Team, 2026-09-03) — **0x06 TEXT belum dibatasi
  panjangnya di client.** `InputCodec.text()` (lib/webrtc/input_codec.dart)
  mengirim seluruh tempel sebagai SATU pesan, berbeda dari `clipboardSet()`
  yang memotong di 64 KiB. Host sekarang memotong di 4.096 unit UTF-16 per
  pesan — sisanya DIBUANG, tidak dipecah otomatis. Kalau mau menempel teks
  panjang bisa diketik, pecah di sisi client menjadi beberapa pesan TEXT
  (±2.000 karakter sudah aman), atau kirim sebagai CLIPBOARD_SET lalu Ctrl+V.

- [x] (dari Danu - XySpace Team, 2026-09-03) — **Parity APK: total & sisa
  waktu sesi** (permintaan operator, "yang request kemarin"). → **SELESAI 3 Sep 2026 (Laras)**.
  Tab Sesi di panel kontrol kini menampilkan card countdown untuk sesi tamu:
  "TOTAL: 2j 00m 00d" dan "SISA: Xj Xm Xd". 3 state visual: normal (neutral),
  critical ≤5 menit (orange + peringatan "Segera simpan pekerjaanmu"), expired
  (merah + "Sesi tamu telah berakhir"). Countdown hanya muncul untuk tamu
  (`authProvider.isGuest`), user login biasa hanya lihat durasi.
  File: `session_page.dart` (konstanta `_guestSessionTotal = 7200`, getter
  `_isGuestSession`), `session_panels.dart` (countdown card di `_SessionPanel`).
  Catatan: /billing web durasi custom + stok belum diimplementasikan di APK.

- [x] (dari Laras - XySpace Team, 2026-09-03) — **Control Mapping system**:
  Halaman Control Mapping tersimpan per akun (scoped). Profil default: Gaming
  (WASD + mouse, FPS style) dan Desktop (Ctrl+C/V/X/Z, produktivitas). User
  bisa buat, edit, hapus, dan set default profil. File: `control_mapping.dart`,
  `control_mapping_page.dart`. Link dari Account page → "Control Mapping".
- [x] (dari Laras - XySpace Team, 2026-09-03) — **Virtual keyboard responsif**:
  Tombol lebih besar (44px), animasi press lebih smooth (easeOutCubic 60ms,
  scale 0.92), visual feedback lebih jelas (border 1.5px, accent glow, shadow
  hilang saat ditekan). Enak dipencet seperti keyboard HP.
  File: `virtual_keyboard.dart` (_PressableKey).
- [x] (dari Laras - XySpace Team, 2026-09-03) — **Profile foto dari Google**:
  `ProfileAvatar` kini menampilkan foto dari akun Google (pictureUrl) sebagai
  prioritas tertinggi, lalu preset DiceBear, lalu URL custom, lalu fallback
  ke inisial. Dipakai di topbar (`TopbarAvatarButton`) dan account page
  (`_ProfileHero`). File: `profile_avatar.dart`, `account_page.dart`, `app.dart`.
- [x] (dari Laras - XySpace Team, 2026-09-03) — **Guest identity (nama random
  manusia)**: Tamu kini mendapat nama manusia Indonesia yang natural (contoh:
  "Aditya Pratama", "Kirana Wijaya") bukan "tamu-xxxx". 64 nama depan × 31
  nama belakang = 1984 kombinasi. Nama tersimpan selama sesi tamu berlangsung.
  File: `guest_identity.dart`, `store.dart` (signInGuest & restore).

- [x] (dari Laras - XySpace Team, 2026-09-03) — **Ikon Billing di topbar**:
  tombol baru di bar atas membuka layar Langganan; aset
  `assets/img/nav/billing.png` (+ `_off.png`) transparan terpasang, dan
  `BillingPage` kini terlihat dari `app.dart`. Yang tersisa: verifikasi
  tampil & navigasi di build Android nyata (lihat item ikon nav di bawah).
- [x] (dari Laras - XySpace Team, 2026-09-03) — **Isolasi data lokal per
  akun**: daftar perangkat, riwayat sesi, dan daftar perangkat-terakhir kini
  disimpan di bawah ruang lingkup akun (`devices:$scope`, `history:$scope`,
  `connect_recents:$scope`; tamu = `guest`). Dikunci dengan
  `test/devices/account_scope_test.dart` (hijau). Perubahan ini
  **security-relevant** — dari sisi lokal tidak bocor antar akun; belum
  diverifikasi alur logout→login berganti akun di perangkat nyata.
- [x] (dari Laras - XySpace Team, 2026-09-03) — **Changelog lengkap di
  halaman pembaruan**: "Pusat Update" kini menampilkan "Catatan rilis" dari
  body GitHub Release resmi (`CHANGELOG.md`), bukan hanya ringkasan
  manifest. Parser markdown dikunci dengan
  `test/notifications/changelog_parse_test.dart` (hijau). Belum diverifikasi
  terhadap format release repo nyata di perangkat.

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

- [x] (dari Galih - XySpace Team, 2026-09-03) — **Topbar sekarang = baris judul
  Windows; jangan dilucuti lagi.** `desktop/electron/main.cjs` memakai
  `titleBarStyle: 'hidden'` + `titleBarOverlay` sewarna `--bg`, `.topbar`
  ber-`-webkit-app-region: drag` dengan `padding-right: 150px` khusus
  `<html class="electron">` (dideduksi dari `info.platform === 'win32'`).
  Tiga hal yang wajib ikut dijaga kalau topbar disentuh: (1) setiap elemen yang
  bisa diklik di dalam topbar harus `no-drag`, (2) jangan balik ke
  `frame: false` — snap layouts + tombol caption asli ikut hilang, (3) kalau
  menambah baris di ATAS topbar (mis. banner peringatan), tombol caption
  Windows tetap menempel di tepi atas jendela, jadi baris itu akan menutupinya
  — banner semacam itu harus di bawah topbar (lihat `.demo-banner`). Konstanta
  150px = lebar 3 tombol caption; cek ulang kalau Electron di-upgrade.
  **Status: dokumentasi aktif, bukan antrean kerja.** Aturan yang sama sudah
  dipindah ke `docs/DESKTOP_SHELL.md` (§Aturan tata letak) supaya tidak hidup di
  dua tempat.

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

  **Catatan Galih:** di lingkungan agent TIDAK ada Windows, jadi screenshot
  yang bisa dibuat di sini adalah render Chromium (Linux) dari `desktop/out`
  — cocok untuk dokumentasi teknis, BUKAN pengganti "screenshot asli semua
  platform" untuk artikel. Yang perlu diambil di lab Windows nanti: jendela
  host dengan ID+password terlihat, shell saat sesi berjalan (chip perangkat
  "… (HP · Android)" di topbar), dan kartu Pengaturan baru. Simpan sebagai
  `<versi>-desktop-*.jpg` di `web/public/news/shots/`.
- [ ] (dari Galih - XySpace Team, 2026-09-03) — Host kini mengirim **dua**
  stream audio: `audio` (loopback suara sistem) dan `mic` (mikrofon PC host,
  hanya bila ada perangkat capture). Client yang menyajikan track audio
  dengan `mid`/`stream_id` "mic" akan otomatis menerima suara mic. Bila mau
  mute/volume mic terpisah, butuh aksi control API baru (belum ada —
  `audio-volume` saat ini hanya menyentuh perangkat output default).
- [x] (dari Galih - XySpace Team, 2026-09-03) — Control API kini punya aksi
  `video-bitrate` (field `bitrate_mbps`, 1–50) dan `/status` melaporkan
  `targetBitrateBps`, `video.latencyMs` (EMA pipeline host),
  `video.latencyMaxMs`, dan `video.encoder` (`nvenc`/`openh264`/
  `test-pattern`). Tambahkan kontrol di panel (input Mbps + tampilkan nilai
  aktif, dan kalau mau, tampilkan latensi + encoder) — endpoint-nya sudah
  jadi & teruji, UI-nya belum.
  **SELESAI (sesi SESI-20260903-GALIH-HOST-UIUX):** kartu "Tampilan & kualitas" di
  Pengaturan kini punya chip 4/8/16/24 Mbps + input kustom 1–60 + nilai aktif dari
  `targetBitrateBps`, plus perkiraan MB/jam; Home menampilkan `video.encoder`,
  `latencyMs`, `latencyMaxMs`. `ActionRequest` ikut diberi `alias =
  "bitrateMbps"` (body /action snake_case, /status camelCase) + 1 test.
- [ ] (dari Danu - XySpace Team, 2026-09-02) — **Rebrand**: ikon Windows
  (`packaging/windows/xydesk.ico`) sudah lahir ulang dari logo baru —
  verifikasi installer CI berikutnya memakai ikon itu. Selaraskan juga
  warna aksen shell dan avatar penulis resmi berita (foto founder, lihat
  catatan Client Flutter).

  **Catatan Galih (2026-09-03, sesi SESI-20260903-GALIH-HOST-UIUX):** bagian
  shell sudah diselaraskan — `desktop/public/logo.png` (merek sidebar, dulu SVG
  gambar tangan) dan `desktop/electron/tray.ico` (tray + taskbar + `build.win.icon`)
  kini jadi target `tool/gen_logo.py` dan `docs/BRAND_ASSETS.md` mencatat barisnya.
  `packaging/windows/xydesk.ico` memang sudah hasil generator, jadi installer CI
  berikutnya otomatis memakai ikon itu. YANG BELUM disentuh dan bukan
  keputusan teknis sepihak: (a) **warna aksen shell** — `--accent: #6142d6` di
  `desktop/app/globals.css` bukan tebak-tebakan, itu token bersama yang
  identik dengan palet terang `lib/core/tokens.dart` (sumber kebenaran desain),
  sedangkan ungu #7C3AED→#A78BFA di logo adalah warna ASET brand; menyamakan
  keduanya = memutuskan ulang token lintas platform, butuh keputusan desain,
  bukan commit shell; (b) avatar penulis resmi berita di halaman Berita shell.

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

- [x] (dari Cakra - XySpace Team, 2026-09-03) — **Rilis 6.4.0+27 TUNTAS.** Bump 4cbbc22 → Build `33728695280` 12/12 @ 4cbbc22 → Release `33729544852` 5/5 (tag v6.4.0, 8 aset, update.json build 27, OneSignal `e4f5574a`). Follow-up: Build `33730701921` (aset artikel) → deploy terjepit deploy manual Danu WEB8 (bundle tanpa aset) + cache CF menyimpan fallback SPA di path gambar → solusi cache-bust rename aset `8b1ebbd` → Build `33732158168` → deploy `33732896248` @ 8eb3ad5 → gambar 6.4.0 image/jpeg. Artikel **p-8f5aa26aa3bc** (id 73) live, top list, OG OK. Web live 6.4.0 terverifikasi (Sewa PC custom, Ingatkan saya, tombol lompat).
## Untuk: CI / Release

- [ ] (dari Galih - XySpace Team, 2026-09-03) — **Perubahan perilaku yang tidak
  boleh lewat tanpa diberitahu:** password pairing host kini PEKA-KASUS (lihat
  item Client Flutter & Web di file ini). Build APK/web/shell berikutnya berbeda
  di mata pengguna: HP lama + password campuran = pairing ditolak. Tolong
  masukkan ke bahan artikel rilis (aturan papan #3) beserta kalimat pemulihannya:
  buka XyDesk di PC → "Password acak baru" atau `xydesk-host --new-password`,
  lalu pairing ulang. Jangan ditulis sebagai "perbaikan keamanan" tanpa efek
  samping — efeknya ada dan menimpa pengguna yang tidak menyentuh apa pun.

- [x] (dari Danu - XySpace Team, 2026-09-03, sesi WEB-ADMIN) — **INFO deploy
  cepat Web (aturan #5):** mode founder kini kirim Google id_token
  (`x-admin-google-token`) otomatis, tanpa tempel `ADMIN_TOKEN`. Build
  produksi `index-DAHi_-aE.js`, `wrangler deploy` versi
  `a3607022-4ca4-4bd8-828b-07f847857e0f`; verifikasi pasca-deploy: md5 live
  == build `a428669f…`, content-type JS, `x-admin-google-token` + key
  penyimpanan + fallback WEB10 + client ID produksi ada di bundle live.
  Murni deploy cepat, bukan rilis.

- [x] (dari Tara - XySpace Team, 2026-09-03, sesi TARA-NEWS-DEPLOY) — **INFO
  deploy worker berita TUNTAS:** worker berita (`news/`) kini menerima
  `x-admin-google-token` (jalur admin kedua; `x-admin-token` tetap sah).
  **Sudah LIVE** — deploy cepat aturan #5: secret `GOOGLE_CLIENT_ID` +
  `FOUNDER_EMAIL` terpasang, `wrangler deploy` versi
  `11253cf5-cd17-495f-8546-135019a843e1`, verifikasi pasca-deploy tercatat
  (CORS `X-Admin-Google-Token` live, `GET /api/news` OK, publish dgn token
  sampah/tanpa token → 401). Tidak ada rilis/bump versi — murni deploy
  worker.

- [x] (dari Danu - XySpace Team, 2026-09-03, sesi WEB-DEPLOY) — **INFO deploy
  cepat Web (aturan #5):** fix WEB10 (fallback 404 slug changelog) sudah LIVE
  di `app.xystudio.my.id`. Build produksi `index-CCHcbcu7.js` (client ID
  `495336144977-…` produksi), `wrangler deploy` versi
  `eca5ab16-45af-4ea0-835b-c88cfe437782`; verifikasi pasca-deploy tercatat:
  md5 live == build `2de36d14…`, `content-type: text/javascript`, fallback
  "Catatan rilis versi ini belum tersedia" + `ApiError` path ada di bundle.
  Ini deploy cepat, bukan rilis — tidak ada artefak Build/rilis baru.

- [ ] (dari Galih - XySpace Team, 2026-09-03) — **Permintaan dispatch Build**
  atas restu operator di chat (3 Sep 2026, "gas + minta dispatch build"): push
  `SESI-20260903-GALIH-HOST-AUDIT` (host engine: masa tenggang disconnect,
  penutupan peer connection, inject teks per batch) sudah di `main` dan
  `verify-push-auth` hijau. Mohon dijalankan saat sesi rilis lain sudah
  `SELESAI` — **nomor versi tetap keputusan operator**; saya tidak menyentuh
  `pubspec.yaml`/`package.json`/`Cargo.toml` (hanya `host/Cargo.lock` yang
  disinkronkan ke 6.4.0 karena tertinggal dari bump 4cbbc22). Bahan artikel
  untuk peranmu sudah ada di blok "Untuk: Host Engine" (tanpa screenshot —
  tidak ada perubahan visual di host).
- [x] (dari Galih - XySpace Team, 2026-09-03) — **Poin (2) DIKERJAKAN (Bhre,
  3 Sep 2026):** `tool/check-host-windows.sh` kini `100755` di index
  (`git update-index --chmod=+x`), jadi perintah yang didokumentasikan
  `docs/CI.md` tidak lagi gagal `Permission denied` di klon baru. Saya sisir
  juga sisa `tool/`: tidak ada skrip `.sh` lain yang kehilangan bit executable.
  Poin (1) `host/Cargo.lock` sudah kamu sinkronkan sendiri — saya verifikasi
  `xydesk-host = 6.4.0`, cocok dengan `Cargo.toml`. Temuan asli:
  Dua hal kebersihan tooling yang
  muncul saat audit host: (1) **`host/Cargo.lock` tertinggal** — masih mencatat
  `xydesk-host 6.3.0` sejak bump versi 4cbbc22 menaikkan `Cargo.toml` ke 6.4.0;
  kalau ada langkah rilis memakai `cargo build --locked`/`--frozen`, ia akan
  gagal. Sudah kusinkronkan di sesi ini (hanya baris versi itu). (2)
  **`tool/check-host-windows.sh` di-commit tanpa bit executable** (`git
  ls-files -s` → 100644), jadi perintah yang didokumentasikan `docs/CI.md`
  gagal `Permission denied` di mesin baru — perlu
  `git update-index --chmod=+x tool/check-host-windows.sh`.

- [x] (dari Danu - XySpace Team, 2026-09-03) — **Sinkronisasi selesai (Bhre,
  3 Sep 2026):** `docs/CI.md` kini punya bagian "Pengecualian: jalur deploy
  cepat (aturan papan #5)" dengan empat syarat kumulatifnya, dan menegaskan
  build/rilis penuh tetap kewenangan CI/Release. Komentar `build.yml` saya
  biarkan apa adanya: isinya bicara soal **pemicu build**, bukan deploy, jadi
  tidak bertentangan dengan aturan #5. Info asli: **aturan papan #5 —
  jalur deploy cepat** (restu operator di chat, kini tertulis di
  `AGENT_BOARD.md` → "Aturan operator"). Web app (Danu) serta worker
  Backend/Edge & berita boleh deploy langsung tanpa menunggu dispatch
  CI, dengan syarat: push di main + `verify-push-auth` hijau, env
  produksi benar, verifikasi pasca-deploy tercatat di board + item
  HANDOFF ke CI pada sesi yang sama. Contoh tercatat: deploy WEB8
  wrangler `728f6c21` (md5 bundle live == build). Build/rilis penuh
  (APK/Windows/installer/tag) tetap kewenanganmu. Mohon sinkronkan
  `docs/CI.md` + komentar `.github/workflows/build.yml` (masih
  menulis "semua deploy via dispatch") dengan aturan #5 ini.

- [x] (dari Danu - XySpace Team, 2026-09-03) — **TERPENUHI lewat rilis 6.4.0**
  (verifikasi Bhre, 3 Sep 2026): bundle live `app.xystudio.my.id`
  `/assets/index-B2YV4o3A.js` memuat versi `6.4.0` dan string fitur WEB7/WEB8
  ("Sewa PC", "Ingatkan saya", "Sisa"). Tidak perlu dispatch terpisah —
  rantai rilis 6.4.0 sudah memborongnya. Permintaan asli: **dispatch WEB8**:
  push fix avatar ganda komentar berita (lihat CHANGELOG) menunggu
  Build + Deploy Web App via dispatch (kebijakan 2dbd186). D1 sudah
  dinormalisasi langsung (byline 5 artikel lama → Haekal Saputra),
  jadi tidak ada perubahan worker yang perlu deploy-news.

- [x] (dari Danu - XySpace Team, 2026-09-03) — **TERPENUHI lewat rilis 6.4.0**
  (bukti sama seperti item WEB8 di atas — satu bundle live memuat keduanya).
  Permintaan asli: **dispatch WEB7**:
  push `5207989` (sewa PC durasi custom + stok, chip total & sisa waktu
  sesi, fix deep link /billing) sudah di main dengan Verifikasi Izin
  hijau. Sesuai kebijakan baru (semua build/deploy via dispatch CI),
  mohon jalankan Build + Deploy Web App untuk SHA itu. E2E lokal hijau
  (billing: stok/custom/routing; sesi: chip 1:59:58 countdown + panel
  Total/Sisa via host pola uji).

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
- [x] (dari Cakra - XySpace Team, 2026-09-03) — **DIKERJAKAN (Bhre, 3 Sep
  2026):** `release.yml` job `prepare` kini menolak merilis SHA yang sudah
  dilewati `main` — Release otomatis berhenti merah dengan pesan berapa commit
  tertinggal, sementara dispatch manual ber-`release_sha` diteruskan dengan
  peringatan (operator dianggap sengaja). Diuji tiga skenario di shell lokal
  (SHA==HEAD lolos senyap; main maju → tolak exit 1; dispatch eksplisit →
  warning + lanjut); YAML kedelapan workflow tetap valid. **Belum diuji di
  GitHub Actions sungguhan** — belum ada rilis baru sejak perubahan ini.
  Temuan asli: **Rilis otomatis bisa
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

- [x] (dari Tara - XySpace Team, 2026-09-03) — **Lengkapi sisi klien admin
  Google.** Worker berita sudah menerima `x-admin-google-token` (ID token
  OpenID; divalidasi signature + audience, email == `FOUNDER_EMAIL`). Yang
  belum: klien web mengirim id_token ini saat founder (login Google
  `xycdigital@gmail.com`, lihat `ADMIN_EMAIL` di `web/src/news.ts`) sudah
  masuk — alih-alih menyuruh tempel `ADMIN_TOKEN` manual. Header lama
  `x-admin-token` tetap berfungsi, jadi ini peningkatan bertahap, bukan
  wajib segera.
  **Selesai (Danu, 3 Sep 2026, sesi WEB-ADMIN):** klien web kini menyimpan
  id_token saat login Google dan mengirimnya sebagai `x-admin-google-token`
  saat berkomentar — tidak perlu lagi menempel `ADMIN_TOKEN` (fallback tetap
  ada). Build tsc+vite hijau, **live** via deploy cepat (versi `a3607022…`).

- [x] (dari Galih - XySpace Team, 2026-09-03) — **Dikerjakan Galih atas arahan
  operator di chat.** `web/src/App.tsx`: kolom password pairing tidak lagi
  `autoCapitalize="characters"` (itu memaksa password jadi huruf besar semua di
  peramban ponsel; sejak verifikasi peka-kasus itu langsung mengunci pengguna) —
  sekarang `none` + `autoCorrect="off"` + `spellCheck={false}`, dan pesan
  `rejected` menyebut besar/kecil. `web/src/rtc.ts`: `pair` mengirim `name`
  (tebakkan browser + OS dari userAgent, mis. "Chrome di Windows") dan
  `platform: "web"`; `RtcSession.selfName` boleh diisi nama akun.
  Terverifikasi: `npm run build` (= `tsc -b && vite build`) hijau. Sisa untuk
  role Web bila mau: isi `selfName` dari profil saat login, dan putuskan apakah
  nama akun layak dikirim (host melihatnya begitu pairing diterima).

- [ ] (dari Cakra - XySpace Team, 2026-09-03) — **Aturan rilis baru:** versi & berita = keputusan operator; saat menutup sesi fitur web, tulis bahan artikel kerjamu sendiri (dampak pengguna + screenshot asli, gaya `docs/NEWS_STYLE.md`) — role CI/Release menyatukan jadi SATU artikel saat rilis.

- [x] (dari Cakra - XySpace Team, 2026-09-03) — Push `0081742` (keyboard
  virtual, panel gaming) membuat run `verify-push-auth.yml` MERAH: commit
  tidak memuat penanda `Izin: <ID-SESI>` di body. Aturan baru (lihat
  `AGENT.md` bagian 5): klaim sesi → minta persetujuan operator di
  `AGENT_BOARD.md` → push dengan `Izin: ...` di body. Commit tetap masuk,
  tapi audit mencatatnya sebagai pelanggaran.
  **Dibereskan retroaktif (Danu, sesi WEB-AUDIT):** push pra-gerbang ini
  sudah disahkan — tercatat di papan riwayat `SESI-20260903-DANU-WEB-AUDIT`
  bersama `d3522bb`/`4785561`/`bff26bb`. Tidak ada tindakan lanjutan.

- [x] (dari Danu - XySpace Team, 2026-09-03) — **Pengingat deploy**: perubahan
  sesi WEB10 (fallback 404 slug changelog) sudah di `main` tapi **belum live** —
  push agent tidak memicu deploy (kebijakan 3 Sep). Sesuai aturan papan #5,
  Web boleh deploy cepat: `npm run build` dengan `VITE_GOOGLE_CLIENT_ID`
  produksi, deploy `wrangler`, lalu verifikasi (md5 bundle live == build,
  content-type JS, teks "Catatan rilis versi ini belum tersedia" muncul saat
  buka `/news/changelog-v6-4-0`). Atau serahkan ke dispatch CI/Release.
  **Selesai (Danu, 3 Sep 2026, sesi WEB-DEPLOY):** di-deploy langsung lewat
  jalur cepat aturan #5 — build produksi `index-CCHcbcu7.js`, wrangler versi
  `eca5ab16-45af-4ea0-835b-c88cfe437782`, verifikasi pasca-deploy lolos penuh
  (md5 live == build `2de36d14…`, content-type `text/javascript`, fallback
  + client ID produksi ada di bundle live). Catatan untuk CI/Release di
  bawah.

## Untuk: Backend / Edge

- [ ] (dari Galih - XySpace Team, 2026-09-03) — **`signaling/` (hub Go)
  MENGHAPUS field asing saat relay, jadi label perangkat tidak sampai ke host
  lewat hub dev.** `hub.go` `relay(from, toID, msg Message)` men-serialize
  ulang struct bertipe `Message` (`protocol.go`), sehingga `name`/`platform`
  yang ditambahkan client di pesan `pair` hilang. Cloudflare hub
  (`cloudflare/src/hub.js`) aman: `peer.send(JSON.stringify({ ...msg, from:
  meta.id }))` melewatkan field apa pun. Perbaikan yang cukup: tambahkan
  `Name`/`Platform` (`json:"name,omitempty"` / `"platform,omitempty"`) ke
  `Message` — atau relay payload mentah. Dampak sekarang: pengujian UI chip
  "HP · Android" hanya bisa dilakukan terhadap worker, tidak terhadap hub Go;
  host tetap normal (label kosong → tampil ID).

- [x] (dari Danu - XySpace Team, 2026-09-03) — **INFO: kini ada jalur
  deploy cepat untuk worker signaling/edge & worker berita** (aturan
  papan #5, restu operator): boleh deploy langsung tanpa menunggu
  dispatch CI — syarat: push di main + izin hijau, uji area hijau,
  verifikasi pasca-deploy tercatat di board, + info HANDOFF ke
  CI/Release. Catatan kredensial: token deploy milik operator dan
  dibagikan operator ke lingkungan agent (Danu mendapatkannya lewat
  berkas unggahan operator) — mohon koordinasi dengan operator bila
  lingkunganmu belum memegang kredensial.
  **Terserap:** aturan papan #5 kini terdokumentasi permanen di
  `docs/CI.md` (sesi Bhre) dan sudah dipakai pertama kali pada sesi
  WEB-DEPLOY (deploy web). Item info ini ditutup.

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
- [x] (dari Danu - XySpace Team, 2026-09-03) — **Verifikasi admin komentar
  yang lebih mulus**: sekarang founder menempel ADMIN_TOKEN sekali di
  perangkat (UI web sudah ada, worker memvalidasi). Peningkatan: worker
  berita menerima Google ID token dan memverifikasi email founder langsung
  (audience + signature), sehingga tidak perlu menempel token manual.
  **Selesai sisi worker (Tara, 3 Sep 2026, sesi TARA-NEWS-GOOGLE):** worker
  berita kini menerima `x-admin-google-token` (ID token diverifikasi RS256
  via JWKS, audience + email == `FOUNDER_EMAIL`); `x-admin-token` lama tetap
  sah; gagal-tertutup bila secret tidak lengkap. Tes `news/` 32/32 hijau.
  **Belum live** — deploy worker berita belum dijalankan (lihat "Untuk: CI /
  Release"). **UPDATE: sudah LIVE** (Tara, sesi TARA-NEWS-DEPLOY) — versi
  `11253cf5-cd17-495f-8546-135019a843e1`, secret `GOOGLE_CLIENT_ID` +
  `FOUNDER_EMAIL` terpasang, verifikasi pasca-deploy tercatat (CORS
  `X-Admin-Google-Token` live, feed publik OK, jalur Google gagal-tertutup
  401). Sisi klien web juga selesai (sesi WEB-ADMIN) — id_token dikirim saat
  founder masuk Google; dan sesi WEB-ADMINFIX menambah tombol "Lanjutkan
  dengan Google" sekali-klik bila id_token kosong/kedaluwarsa (kembali
  otomatis ke artikel).

- [x] (dari Laras - XySpace Team, 2026-09-03) — **SELESAI 3 Sep 2026 (sesi
  `SESI-20260903-LARAS-CLOUDINARY`, operator menyerahkan kunci Cloudinary di
  chat).** Preset dibuat lewat Admin API — bukan dasbor — dengan nama
  `xydesk_profile_unsigned`: `unsigned=true`, folder `profile/`, format
  dibatasi `jpg,jpeg,png,webp`, transformasi `c_limit,w_512,h_512,q_auto:good`
  (foto kamera HP tidak menghabiskan kuota), `unique_filename=true` +
  `overwrite=false` supaya unggahan antar pengguna tidak saling menimpa.
  **Diuji nyata, bukan diasumsikan:** upload dari luar tanpa
  `api_key`/`api_secret` (persis jalur APK) berhasil, `secure_url` yang
  dikembalikan menjawab `HTTP 200 image/png`, dan upload `.txt` ditolak
  (`Raw file format txt not allowed`). Gambar uji langsung dihapus — folder
  `profile/` kembali kosong. `lib/core/cloudinary_upload.dart` sudah diisi,
  dan ditambah test yang menjaga konstanta itu tidak kosong lagi.
  **Belum diuji dari APK di HP sungguhan** (tidak ada perangkat di lingkungan
  sesi ini) — masuk daftar verifikasi perangkat nyata bersama item lain.
  Permintaan asli: **Preset upload Cloudinary
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

- [ ] (dari Galih - XySpace Team, 2026-09-03) — **Permintaan "siapkan driver
  mic/audio/display/GPU" dijawab: tidak ada driver yang perlu/pantas dikirim.**
  Host sudah lewat jalur tercepat user-mode: DXGI Desktop Duplication (capture),
  NVENC D3D11+NV12 (`nvenc.rs`, fallback openh264), WASAPI loopback (audio PC →
  HP), track WebRTC (mic HP → PC), `SendInput` (keyboard/mouse). Driver kernel
  hanya perlu untuk HAL lain dan semuanya butuh EV code-signing + INF + test
  signing, yang bertentangan dengan aturan ROADMAP "semua gratis, tanpa kartu
  kredit": HidHide/ViGEmBus (menyembunyikan perangkat fisik), IddCx (display
  virtual/headless). Tiga Upgrade nyata yang masih murni user-mode dan belum
  dikerjakan — kerjakan kalau mau "gacor" beneran: (1) zero-copy penuh
  DXGI→NVENC lewat shared NT handle (buang salin BGRA→NV12 di CPU), (2) pilih
  adapter/L0 (`DXGI_SWAP_CHAIN_FLAG`/`CreateDXGIFactory1` + prefer GPU diskrit)
  sebelum encoder dibuat, (3) capture audio PER APLIKASI
  (`AUDIOCLIENT_ACTIVATION_PARAMS` + `PROCESS_LOOPBACK_MODE_TARGET`, Win10 2004+)
  supaya hanya suara app target yang ikut ke HP. Uji semuanya di lab Windows
  (`host/TEST-LAB-WINDOWS.md`) — runner CI tidak punya GPU.
- [ ] (dari Galih - XySpace Team, 2026-09-03) — **Keyboard & mouse FISIK di PC
  host sudah aman dan memang begitu desainnya**: `SendInput` MENAMBAH event ke
  antrean input sistem, tidak mengambil alih perangkat, jadi orang di depan PC
  tetap bisa mengetik/gerakin mouse selama sesi (input campur — bukan bug,
  belum ada permintaan mode eksklusif). Yang BELUM ada dan butuh keputusan
  produk sebelum dikoding: "kunci PC lokal selama sesi". Dua bentuk murah:
  (a) `LockWorkStation()` (user32, satu panggilan, tanpa driver) dipicu
  tombol/aksi `POST /action {action:"lock-now"}` — praktis, tapi local user
  harus login ulang; (b) `WH_KEYBOARD_LL`/`WH_MOUSE_LL` yang menelan event lokal
  dengan opsi "lepas" + watchdog — terasa lebih rapi TAPI tidak bisa diuji dari
  CI Linux dan hook salah tulis = pengguna kehilangan papan ketiknya sendiri.
  Jangan pasang (b) tanpa lab Windows + tombol darurat di UI.

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
- [x] (dari Laras - XySpace Team, 2026-09-03) — Kontrak perilaku keyboard saat
  sesi: sisi klien kini bisa mengirim **teks bebas (0x06 TEXT)** lewat papan
  ketik sistem selain keycode (0x05 KEY). **Diperiksa & dilengkapi di sesi
  SESI-20260903-GALIH-HOST-AUDIT:** host sudah mengetik 0x06 apa adanya lewat
  `KEYEVENTF_UNICODE` (tidak bergantung layout keyboard host) dan keycode 0x05
  tidak disentuh. Yang BELUM wajar adalah bagian "karakter banyak/rapat": satu
  pesan TEXT panjang dulu diubah jadi satu `SendInput` berisi ribuan `INPUT`
  tanpa mengikuti nilai kembali sistem (sebagian bisa hilang tanpa jejak). Kini
  dipecah per 32 karakter, sisanya dikirim ulang, dan di atas 4.096 unit UTF-16
  dipotong di batas karakter (bukan di tengah pasangan surrogate). Dikunci 5 uji
  unit lintas platform. Sisi client belum dibatasi panjangnya — lihat item
  "Untuk: Client Flutter".
- [ ] (dari Cakra - XySpace Team, 2026-09-03) — Push `f12dace` (bitrate
  live via control API) membuat run `verify-push-auth.yml` MERAH: commit
  tidak memuat penanda `Izin: <ID-SESI>` di body. Aturan baru: klaim
  sesi → persetujuan operator di `AGENT_BOARD.md` → push dengan penanda
  `Izin: ...` di body commit.

- [ ] (dari Galih - XySpace Team, 2026-09-03) — **Verifikasi lab Windows untuk
  SESI-20260903-GALIH-HOST-AUDIT** (semuanya lolos di unit test Linux, tapi
  perilaku nyata hanya terbukti di Windows). **Langkah uji siap jalan ditulis di
  `host/TEST-LAB-WINDOWS.md`** (resep token + control API, 5 blok pengujian,
  apa yang harus terlihat di log dan di `/status`): (1) saat sesi aktif, putuskan Wi-Fi
  ±5 detik lalu nyalakan — sesi HARUS lanjut tanpa pairing ulang dan log
  menampilkan "pulih sendiri — sesi lanjut"; (2) putuskan > 15 detik — slot
  dilepas DAN capture berhenti (cek Task Manager: GPU/CPU turun); (3) tempel 3–5
  baris + emoji dari HP ke Notepad — semua karakter masuk, tanpa karakter rusak;
  (4) reload client di tengah sesi (renegosiasi) — sesi lama harus ditutup,
  tidak ada dua engine capture berjalan.
- [ ] (dari Galih - XySpace Team, 2026-09-03) — **Butuh keputusan operator, jadi
  tidak kukerjakan:** kalau WebSocket signaling putus-nyambung, sesi media yang
  sedang berjalan TIDAK ditutup (kode menuliskan "Sesi media mati bersama
  koneksi signaling", padahal Arc-nya masih dipegang task video/input). Sisi
  baiknya: video kebal terhadap deploy signaling. Sisi buruknya: host tidak lagi
  mengenalinya sebagai sesi aktif, jadi `bye` dari client tidak menutupnya —
  hanya control API `stop-session` yang bisa. Pilih: biarkan (dan perbaiki
  komentar) atau tutup setelah masa tenggang.
- [ ] (dari Galih - XySpace Team, 2026-09-03) — Task input (arm "offer" di
  `main.rs`) keluar saat `rx.recv()` berakhir, tapi menutup data channel dari
  lawan TIDAK menutup channel mpsc di sisinya — thread injeksi
  (`std::thread::spawn`) bisa bertahan satu per sesi. Belum diukur (butuh sesi
  Windows nyata). Kandidat perbaikan: `dc.on_close` → drop `inj_tx`.
- [ ] (dari Galih - XySpace Team, 2026-09-03) — **Bahan artikel** (aturan papan
  #3; untuk disatukan CI/Release saat rilis berikutnya): "Sesi XyDesk tidak lagi
  putus karena jaringan sebentar. Dulu koneksi yang terlepas dua detik dianggap
  mati total — perangkat harus memasukkan password ulang, dan proses di PC
  kadang terus merekam layar tanpa penonton. Sekarang host memberi masa
  tenggang 15 detik untuk pulih sendiri, dan kalau memang tidak pulih,
  peralatannya dibebaskan dengan benar. Ketikan panjang dari HP juga tidak lagi
  hilang sebagian di tengah jalan." **Tanpa screenshot** — tidak ada perubahan
  visual di sisi host, dan screenshot sesi Windows masih jadi utang Desktop Shell.

## Untuk: Docs & Audit

- [ ] (dari Galih - XySpace Team, 2026-09-03) — **Catat batas gerbang host di
  `docs/CI.md`.** `host-test` menjalankan `cargo fmt/clippy/test` di ubuntu, jadi
  SEMUA kode di balik `cfg(target_os = "windows")` (DXGI, WASAPI, SendInput,
  papan klip) tidak pernah di-lint sebelum rilis. Buktinya nyata: `main` hari ini
  MERAH pada `tool/check-host-windows.sh --clippy` karena dua lint Windows-only —
  `screen.rs` (doc comment menggantung, `empty_line_after_doc_comments`) dan
  `gui.rs` (manual `Iterator::find`) — keduanya lolos CI. Sudah kuperbaiki, tapi
  strukturnya tetap: usulkan step `clippy --target x86_64-pc-windows-gnu` di
  `host-test` (mingw-w64 tersedia di runner ubuntu) ATAU tulis terang-terangan
  bahwa "CI host hijau" tidak berarti kode Windows bersih.

- [x] (dari Cakra - XySpace Team, 2026-09-03) — **Aturan rilis baru:** versi & berita = keputusan operator; tiap agent menulis bahan artikel kerjanya sendiri, CI/Release menyatukannya — pastikan aturan ini tersinkron di `docs/CI.md`, `docs/NEWS_STYLE.md`, `news/README.md`. **Dikerjakan Sena (audit 3 Sep 2026):** `docs/CI.md` sudah memuatnya (§"Sebelum build/rilis"), `news/README.md` sudah memuatnya; yang kurang hanya `docs/NEWS_STYLE.md` — kini ditambah blok "Siapa yang menulis" di §1.

- [x] (dari Danu - XySpace Team, 2026-09-03) — Berkas unggahan operator di
  luar repo (dipakai sesi web untuk token) masih memuat baris
  `GOOGLE CLIENT ID : 335906355717-…` yang sudah kedaluwarsa/menyesatkan —
  client OAuth web yang benar `495336144977-dp1k3678cocjrfhftb9blnqo5qnvhsr6…`.
  **Selesai sesi DOCS2 (3 Sep 2026):** berkas `uploads/my-binimbg.txt` sudah
  dikoreksi — baris `#GOOGLE` ditandai "KEDALUWARSA/MENYESATKAN", dan baris
  web yang tadinya `495336144977-cadhmro3…` (salah) diganti ke
  `495336144977-dp1k3678…` yang benar, **diverifikasi dari bundle live**
  `app.xystudio.my.id`. Di dalam repo sendiri tidak ada client ID yang
  di-hardcode (sudah dicek: hanya contoh `--dart-define` di
  `lib/features/auth/auth_service.dart`).

### Temuan audit Sena — 3 Sep 2026 (belum dikerjakan, bukan area Docs)

- [x] (dari Sena - XySpace Team, 2026-09-03, **untuk News/CI-Release**) —
  **Tautan versi di footer web menuju 404 — TAPI bukan bug kode, melainkan
  prosedur rilis yang terlewat.** Koreksi diagnosis awal saya (yang sempat
  saya tulis di `docs/VERSIONING.md`): saya kira worker memaksa slug hash,
  ternyata TIDAK. `news/src/worker.js` (`adminPublish`) sudah menyediakan
  pengecualian khusus — slug yang cocok pola `^changelog-v\d+-\d+-\d+$`
  **boleh diminta sendiri**, selain itu baru diacak jadi `p-<hash>`. Jadi
  mekanismenya sudah benar dan sudah dipakai: `changelog-v6-2-0`,
  `changelog-v6-2-1`, `changelog-v6-2-2`, `changelog-v6-3-0` semuanya HTTP 200
  (saya cek langsung ke `news.xystudio.my.id`).

  Yang terjadi di rilis 6.4.0: artikelnya diterbitkan **tanpa mengirim field
  `slug`**, sehingga jatuh ke hash `p-8f5aa26aa3bc`. Akibatnya
  `https://news.xystudio.my.id/api/news/changelog-v6-4-0` → **HTTP 404**
  (terverifikasi), dan tombol versi di footer web (`web/src/App.tsx` baris
  ~2497, memakai `CHANGELOG_SLUG` dari `web/src/version.ts`) menunjuk ke
  artikel yang tidak ada. Rilis 6.1 dan 6.0 (`p-66a4edde0222`,
  `p-d5b4512f7d17`) punya masalah yang sama.

  **Dikerjakan Raka (News, 3 Sep 2026) + Danu (Web, sesi WEB10):** sisi
  prosedur sudah ditutup — `news/README.md` kini **mewajibkan** field `slug`
  untuk artikel rilis dengan peringatan eksplisit + contoh `curl` yang
  menyertakannya, dan footer web tidak lagi dead-end (fallback ramah bila
  slug changelog 404). Yang TETAP butuh keputusan operator: artikel 6.4.0
  sudah terbit + sudah dikirim via push/email, jadi slug-nya tidak boleh
  diganti diam-diam. Dua opsi:
    (a) tambah kolom/alias slug kedua di D1 supaya `changelog-v6-4-0`
        mengarah ke artikel yang sama (tanpa mematikan `p-8f5aa26aa3bc`); atau
    (b) biarkan 6.4.0 apa adanya — rilis berikutnya wajib mengirim
        `"slug": "changelog-v<versi>"` saat publish.

- [x] (dari Sena - XySpace Team, 2026-09-03, **untuk News**) — **Sudah beres
  sebelum saya sempat push** (commit `7e6f860`, sesi `SESI-20260903-SENA-DOCS`):
  contoh `author` kini `Haekal Saputra`, plus `news/schema.sql`, `news/seed.sql`,
  dan fallback `news_service.dart` ikut diselaraskan — lebih menyeluruh dari
  yang saya usulkan. Temuan asli: `news/README.md`
  contoh `curl` publish masih memakai `"author": "Tim XyDesk"`, padahal
  paragraf di atasnya sendiri sudah mewajibkan `Haekal Saputra`. Contoh yang
  salah inilah yang kemungkinan melahirkan 5 artikel byline `Tim …` yang baru
  dinormalisasi Danu di D1. Tolong perbaiki contohnya (area `news/`, bukan
  Docs).
- [x] (dari Sena - XySpace Team, 2026-09-03, **untuk CI/Release**) — **Blok
  `[6.4.0]` di `CHANGELOG.md` banyak kalimat terpotong.** 9 dari 10 butir di
  bagian "Ditambahkan"/"Diubah" berhenti di tengah kalimat tanpa titik (mis.
  "— ikon AI 3D ungu glossy", "— pojok kiri atas", "— klik", "— versi & berita
  adalah"), sementara bagian "Diperbaiki" utuh. File ini dilampirkan ke GitHub
  Release, jadi rilis 6.4.0 yang sudah terbit memajang catatan yang menggantung.
  **Selesai Cakra (3 Sep 2026, sesi CAKRA-CHANGELOG):** 17 butir terpotong
  direstorasi dari git history (parent `4cbbc22^`) dan body GitHub Release
  `v6.4.0` dipatch dengan teks lengkap (18 butir asli rilis; butir pasca-rilis
  tidak ditambahkan). Salinan body lama disimpan untuk rollback.
- [x] (dari Sena - XySpace Team, 2026-09-03, **untuk CI/Release**) — **Papan
  `AGENT_BOARD.md`: tabel "Sesi aktif (LOCK)" isinya semua `SELESAI`.**
  **Dibereskan atas izin operator di chat (3 Sep 2026):** 11 baris `SELESAI`
  dikeluarkan dari tabel LOCK; 10 di antaranya sudah punya salinan di *Riwayat
  sesi*, dan `SESI-20260903-CAKRA-RILIS` yang belum ada disalin dulu ke riwayat
  sebelum dikeluarkan — tidak ada sejarah yang hilang. Tabel LOCK kini kosong +
  diberi catatan agar tidak menumpuk lagi. Keterangan asli: Per
  aturan papan langkah 3, baris `SELESAI` harus dipindahkan ke "Riwayat sesi"
  (dan memang sudah ada duplikatnya di sana). Tabel LOCK yang penuh baris mati
  membuat fungsinya — melihat area mana yang sedang dikunci — hilang. Perlu
  dibersihkan oleh pemilik papan, bukan diam-diam oleh saya.
- [x] (dari Sena - XySpace Team, 2026-09-03, **untuk CI/Release**) — **Sudah
  beres di commit `5dbf923`**: rilis 6.4.0 kini punya baris sendiri
  `SESI-20260903-CAKRA-RILIS64`, terpisah dari `SESI-20260903-CAKRA-RILIS`
  (6.3.0), sehingga jejak `Izin: <ID>` tidak lagi ambigu. Temuan asli: baris
  `SESI-20260903-CAKRA-RILIS` di papan masih berbunyi "Rilis 6.3.0", padahal
  ID sesi yang sama dipakai untuk rilis 6.4.0+27 (commit `ed1eb02`, catatan
  HANDOFF di bawah). Satu ID sesi dipakai dua rilis = jejak audit `Izin: <ID>`
  jadi ambigu. Saran: baris terpisah `SESI-20260903-CAKRA-RILIS640`.

---

## Selesai

- [x] (dari Danu - XySpace Team, 2026-09-03, sesi WEB-ADMINFIX) — **Mode
  founder tidak lagi menyuruh tempel token saat id_token kosong:** founder
  yang sudah login (OTP/sesi lama, atau id_token kedaluwarsa) kini diberi
  tombol "Lanjutkan dengan Google" sekali-klik di halaman berita — ambil
  id_token segar lalu kembali otomatis ke artikel; decode id_token diberi
  padding base64. Build tsc+vite hijau; **live** (deploy cepat versi
  `cd92afb3…`, 6.5.0 + fix). Tempel ADMIN_TOKEN tetap jadi cara lama.

- [x] (dari Danu - XySpace Team, 2026-09-03) — **Mode founder web tanpa
  tempel ADMIN_TOKEN:** klien web menyimpan Google id_token saat login dan
  mengirim `x-admin-google-token` saat berkomentar (fallback `ADMIN_TOKEN`
  tetap ada; bila keduanya kosong jatuh ke komentar publik). `google.ts`
  +`news.ts` + `App.tsx`; build tsc+vite hijau; **live** (deploy cepat versi
  `a3607022…`). Item "Lengkapi sisi klien admin Google" ditutup.

- [x] (dari Tara - XySpace Team, 2026-09-03) — **Deploy cepat worker berita
  (aturan #5):** jalur admin Google (`x-admin-google-token`) LIVE di
  `news.xystudio.my.id` — secret `GOOGLE_CLIENT_ID` + `FOUNDER_EMAIL`
  terpasang, `wrangler deploy` versi `11253cf5-cd17-495f-8546-135019a843e1`,
  verifikasi pasca-deploy: CORS `X-Admin-Google-Token` live, `GET /api/news`
  OK, publish token sampah/tanpa token → 401 (gagal-tertutup).

- [x] (dari Sena - XySpace Team, 2026-09-03) — **Beres-beres item HANDOFF
  basi:** (1) item push `0081742` (pelanggaran izin pra-gerbang) ditandai
  selesai — sudah disahkan retroaktif sesi WEB-AUDIT; (2) item INFO "jalur
  deploy cepat" ditandai selesai — aturan papan #5 sudah permanen di
  `docs/CI.md` dan sudah dipakai (WEB-DEPLOY). Sisanya masih terbuka karena
  butuh perangkat nyata/lab atau keputusan operator.

- [x] (dari Tara - XySpace Team, 2026-09-03) — **Worker berita: jalur admin
  kedua via Google ID token.** `news/` kini menerima `x-admin-google-token`
  (ID token diverifikasi RS256 via JWKS Google — signature + audience, lalu
  email == `FOUNDER_EMAIL`); `x-admin-token` lama tetap sah; gagal-tertutup
  tanpa secret. Kode baru `news/src/auth.js` (port dari signaling) +
  `news/test/google-admin.test.js` (12 kasus). `news/` 32/32 hijau. Belum
  live (deploy berita menunggu); sisi klien web dicatat di "Untuk: Web".

- [x] (dari Danu - XySpace Team, 2026-09-03) — **Deploy cepat Web (aturan #5):**
  fix WEB10 (fallback 404 slug changelog) LIVE di `app.xystudio.my.id`. Build
  produksi `index-CCHcbcu7.js` + `wrangler deploy` versi `eca5ab16…`;
  verifikasi pasca-deploy lolos penuh (md5 live==build, content-type JS,
  fallback + client ID produksi di bundle live). Tercatat di papan + item
  INFO untuk CI/Release.

- [x] (dari Cakra - XySpace Team, 2026-09-03) — Changelog 6.4.0 dirapikan:
  17 butir yang kalimatnya terpotong (efek samping commit bump `4cbbc22`)
  direstorasi teks lengkapnya dari git history — bukan dikarang. Body GitHub
  Release `v6.4.0` ikut dipatch (18 butir asli rilis, tanpa butir pasca-rilis);
  salinan body lama disimpan di `rollback-release-v6.4.0-body.md` (di luar
  repo). Catatan: rilis versi berikutnya tetap lewat alur CI/Release resmi.

- [x] (dari Raka - XySpace Team, 2026-09-03) — `news/README.md` kini
  mewajibkan field `slug` untuk artikel changelog rilis: peringatan eksplisit
  (footer web & layar Tentang menautkan versi ke `changelog-vX-Y-Z`) + contoh
  `curl` publish yang menyertakan `"slug": "changelog-v6-4-1"`. Ini menutup
  akar 404 footer rilis 6.4.0 dari sisi prosedur. Keputusan operator tentang
  alias slug 6.4.0 di D1 tetap terbuka (lihat temuan Sena di atas).

- [x] (dari Danu - XySpace Team, 2026-09-03) — Footer web: tautan versi tidak
  lagi dead-end. Artikel changelog 6.4.0 404 (terbit tanpa `slug`); kini
  `news.ts` melempar `ApiError` sehingga halaman membedakan 404 dari gangguan
  jaringan, dan halaman detail menampilkan "Catatan rilis versi ini belum
  tersedia" + tombol ke daftar berita bila slug changelog 404. Uji:
  `npm run build` (tsc + vite) hijau, teks fallback terkonfirmasi di bundle.
  **Sudah live** (deploy cepat WEB-DEPLOY, 3 Sep 2026) — bundle
  `index-CCHcbcu7.js`. Perbaikan akar tetap di News/CI.

- [x] (dari Tara - XySpace Team, 2026-09-03) — Perkuat tes worker signaling &
  berita (tanpa perubahan kode produksi): `verifyGoogleIdToken` yang sempat
  nol-test kini dikunci 14 kasus (aud/iss/exp/email/sub/kid/tanda tangan
  asing/JWKS mati) memakai kunci RSA sungguhan; `verifyJwt` +6 kasus tepi,
  token signaling +kasus tamper/rusak, `relayAllowed` bye/ice lengkap, dan
  `adminPublish` +8 kasus termasuk aturan slug changelog (akar 404 footer
  rilis 6.4.0). `cloudflare/` 51/51, `news/` 20/20 hijau via `node --test`;
  CI otomatis memungutnya (check-signaling `npm test` + check-news
  `news/test/*.test.js`).

- [x] (dari Sena - XySpace Team, 2026-09-03) — Sinkronisasi aturan rilis baru
  diverifikasi: "versi & berita = keputusan operator" dan "tiap agent menulis
  bahan artikel, CI/Release menyatukannya jadi SATU artikel" sudah terpasang
  di `docs/CI.md` dan `news/README.md`; blok "Siapa yang menulis" di
  `docs/NEWS_STYLE.md` dilengkapi sesi audit paralel (DOCS-AUDIT) — kini
  ketiganya sinkron.

- [x] (dari Sena - XySpace Team, 2026-09-03) — Client OAuth web dipastikan
  lewat bukti: bundle live `app.xystudio.my.id` memuat
  `495336144977-dp1k3678cocjrfhftb9blnqo5qnvhsr6.apps.googleusercontent.com`.
  Berkas kunci operator (di luar repo) sudah dikoreksi — baris
  `335906355717-…` ditandai KEDALUWARSA dan baris web yang sebelumnya
  `…cadhmro3…` (salah) diganti ke `…dp1k3678…` yang benar.

- [x] (dari Sena - XySpace Team, 2026-09-03) — Konsistensi byline berita:
  sisa `Tim XyDesk` sebagai default/seed/fallback dinormalkan ke
  `Haekal Saputra` di `news/schema.sql` (DEFAULT author), `news/seed.sql`
  (4 artikel), `news/README.md` (contoh payload), dan fallback client
  `lib/features/news/news_service.dart`. Catatan: `news/test/comments.test.js`
  tetap memuat `'Tim XyDesk'` karena itu daftar **nama-terlindungi**
  (anti-peniruan via `isProtectedName`), bukan byline — tidak diubah.
  D1 produksi sudah dinormalkan sesi WEB8; sumber-sumber di atas kini selaras
  sehingga nama lama tidak muncul lagi saat seed ulang/fallback.

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


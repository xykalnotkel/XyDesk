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

## [6.5.2] - 2026-09-06

> **Build 30.** Rilis perbaikan: menutup dua kerusakan yang dari luar tampak
> seperti "XyDesk mogok" — aplikasi Android yang berhenti di layar
> peluncuran tanpa pernah masuk, dan engine PC yang tersandung setiap kali
> jaringan kedip setelah lama menyala. Yang kedua diselesaikan dengan
> memisahkan identitas perangkat dari token sesi, model yang dipakai produk
> remote desktop pada umumnya; sekalian menutup lubang lama yang mengunci
> perangkat selamanya begitu password pairing diganti. Tidak ada perubahan
> yang memutus aplikasi lama: worker tetap menjawab token teks polos untuk
> permintaan yang tidak meminta format baru.

### Ditambahkan
- Backend / Edge + Desktop Shell: **kredensial penyegaran host** — identitas
  perangkat yang menetap, terpisah dari token sesi. Host menyimpannya di
  berkas identitasnya (bukan di command line) dan menukarnya sendiri menjadi
  token sesi setiap kali menyambung: tanpa password pairing, tanpa rem klaim,
  tanpa menunggu jatah percobaan. Token sesi tetap berumur 5 menit — yang
  berumur panjang cuma identitasnya, persis seperti produk remote desktop
  pada umumnya. Kredensial berlaku 90 hari dan bisa diperbarui lewat jalur
  ikat ulang.

### Diperbaiki
- Client Flutter: **aplikasi bisa berhenti di layar peluncuran tanpa
  batas.** `main()` menunggu inisialisasi layanan notifikasi selesai sebelum
  menampilkan frame pertama, dan rantai itu — inisialisasi SDK, pembacaan
  status izin, dan opt-in langganan — **tidak punya satu pun batas waktu**.
  Satu panggilan SDK yang tidak pernah menjawab (jaringan tersendat, layanan
  ponsel bermasalah, peluncuran dingin) membuat aplikasi diam di logo: bukan
  crash, bukan galat, hanya berhenti. Kini notifikasi disiapkan **setelah**
  frame pertama tampil dan dibatasi 10 detik; kalau gagal, aplikasi tetap
  terbuka dan statusnya bisa dicoba ulang dari Pengaturan. Pembacaan sesi
  aman juga diberi batas waktu 10 detik dengan jalur fallback yang sudah ada
  (pengguna diminta masuk ulang).
- Backend / Edge: **mengganti password pairing mengunci perangkat
  selamanya.** Server menyimpan hash password pada pemakaian pertama dan
  menolak password yang berbeda, sedangkan `set-password` di host hanya
  mengubah berkas lokal — server tidak pernah diberi tahu. Hasilnya: 403
  terus-menerus, lalu kunci 15 menit setiap lima percobaan. Kini host bisa
  mengikat ulang perangkatnya ke password baru dengan menyertakan kredensial
  penyegaran; tanpa kredensial itu, tebakan password yang benar pun tetap
  ditolak (tidak bisa memindahkan ikatan ke password penyerang).

## [6.5.1] - 2026-09-06

> **Build 29.** Rilis perbaikan: tidak ada fitur baru, tidak ada perubahan
> protokol atau format data tersimpan. Isinya menutup kerusakan yang
> terjadi sejak 3 September 2026 — klien Flutter tidak bisa dikompilasi
> lagi, sehingga tidak ada APK yang terbangun selama enam hari — serta
> satu kelemahan keamanan di klien web dan dua kebohongan dokumentasi.
> Angka PATCH dipilih karena semua perubahan memperbaiki perilaku yang
> salah, bukan menambah kemampuan.

### Ditambahkan
- Dokumentasi tim: **role baru `Operator` (identitas `Operator - XyDesk
  Team`)**, ditetapkan pemilik repo. Role ini mewakili pemilik repo: ia
  boleh mengerjakan semua area sekaligus dalam satu sesi (pengecualian
  dari aturan "1 sesi = 1 role"), tidak perlu mengantre `DISETUJUI` di
  papan, dan boleh masuk area yang sedang dikunci bila operator
  memerintahkan langsung. Hak yang sengaja tidak dilonggarkan: menaikkan
  nomor versi, menerbitkan/mengubah berita, serta dispatch Build, Release,
  dan deploy tetap minta restu operator di chat; perubahan berisiko
  produksi besar tetap wajib konfirmasi khusus. Jejaknya tidak hilang —
  baris sesi di papan dan penanda `Izin: <ID-SESI>` tetap wajib. Rincian
  hak dan batasnya ada di `AGENT.md` bagian 2.1, pengingatnya di
  `AGENT_BOARD.md` aturan #6.

### Diperbaiki
- Client Flutter: **latar ikon "Sewa PC" (billing) belum benar-benar
  dibersihkan.** `assets/img/nav/billing.png` masih menyisakan latar
  buram di empat sudutnya — artefak pembersihan latar yang membuat ikon
  tampak sebagai kotak pucat di tombol bilah atas, berbeda dengan empat
  ikon navigasi lain yang sudutnya benar-benar transparan. Latar yang
  tersambung ke tepi dibuang, dan sisa pinggiran pucat di sekeliling
  objek dirapikan. Diukur: sudut kini `alpha = 0` dan tidak ada piksel
  buram yang menyentuh tepi, sama seperti ikon nav lainnya.
- Client Flutter: **kode klien tidak bisa dikompilasi sejak 3 Sep 2026.**
  `lib/features/session/session_panels.dart` menyambung string dengan garis
  miring terbalik di akhir baris — cara yang tidak dikenal Dart — sehingga
  `dart format` gagal mem-parse berkasnya. Akibatnya job "Analisis Statis
  (Flutter)" selalu merah dan job `APK Android per ABI` dilewati: **tidak
  ada APK yang terbangun sejak 3 Sep**, tanpa satu pun tanda bahaya di
  papan. Dua baris itu kini memakai penulisan string bersebelahan yang
  lazim di Dart.
- Client Flutter: **tiga error analisis lain ikut beres.** (1)
  `AppColors.textLow` tidak pernah ada — warna teks bergantung tema dan
  harus diambil dari palet, jadi `XyDeskError.color` kini menerima
  `AppPalette` dari pemanggilnya; (2) `copyWith` di model perangkat
  memakai `gpu` tanpa mendeklarasikannya, sehingga pembaruan informasi
  hardware tidak bisa dikompilasi; (3) `_pendingNews` dideklarasi dua kali
  di layanan notifikasi.
- Client Flutter: **21 info dan warning dibersihkan**, karena CI
  menjalankan `flutter analyze --fatal-infos --fatal-warnings` — satu info
  saja sudah cukup menggagalkan build. Yang dibuang: impor tak terpakai,
  field dan metode mati (`_editingProfileId` hanya ditulis, tidak pernah
  dibaca), konstruktor yang seharusnya `const`, dan dua interpolasi string
  yang sia-sia.
- Client Flutter: **pelanggaran aturan desain di halaman control mapping**
  — `Divider` dipakai sebagai pemisah, padahal Quiet Surface melarang
  garis pemisah dan CI menggagalkan build bila menemukannya. Pemisahnya
  diganti jarak.
- Client Flutter: **17 berkas dirapikan dengan `dart format`** (Dart
  3.12.2, versi yang sama dengan runner CI). Sebelumnya berkas-berkas itu
  tidak pernah diformat sejak ditulis.
- Dokumentasi: inventaris lisensi diregenerasi setelah `go_router` keluar
  dari `pubspec.lock` — halaman Legal tidak lagi mencantumkan paket yang
  tidak dipakai (503 komponen).
- Client Flutter: **`pubspec.lock` basi membuat job "Analisis Statis (Flutter)"
  merah dan APK tidak pernah terbangun.** `go_router` dihapus dari
  `pubspec.yaml` pada 3 Sep (`7d178d1`, tidak dipakai lagi di `lib/`),
  tetapi entrinya tertinggal di `pubspec.lock`. Setiap `flutter pub get`
  di CI menghapus entri itu sendiri, lalu langkah `git diff --exit-code --
  pubspec.lock` gagal — job analisis berhenti di situ dan `APK Android per
  ABI` dilewati. Entri usang itu dibuang; berkas kini identik dengan hasil
  `pub get` (diverifikasi dari hash blob yang sama dengan yang dihasilkan
  runner CI).
- Keamanan web: **password pairing tidak lagi disimpan di peramban.** Riwayat
  koneksi di `web/src/App.tsx` sebelumnya menyimpan ID + password di
  `localStorage` dengan `btoa()` — enkode bolak-balik, bukan enkripsi. Satu
  XSS, atau satu peramban bersama di PC sewaan, cukup untuk membaca password
  yang membuka layar seseorang. Sekarang yang disimpan hanya ID host dan
  waktu terakhir dipakai; memilih riwayat mengisi ID lalu langsung memfokus
  kolom password, dan entri lama yang masih membawa password dibersihkan
  otomatis saat dibaca. Aplikasi Android dan shell desktop tidak terdampak —
  keduanya memang tidak pernah menyimpan password.
- Dokumentasi: **enam berkas berhenti mengklaim gerbang audit izin push masih
  hidup.** `verify-push-auth.yml` dihapus operator sendiri pada 5 Sep 2026
  (commit `b4ce4a4`) dan `main` tanpa branch protection, tetapi `AGENT.md`,
  `AGENT_BOARD.md`, `HANDOFF.md`, `README.md`, `CHANGELOG.md`, dan
  `docs/CI.md` masih menjelaskannya seolah berjalan — padahal sekarang tidak
  ada satu pun workflow yang berjalan karena push. Penanda `Izin: <ID-SESI>`
  dan baris sesi di papan ditegaskan kembali sebagai kebiasaan tim untuk
  jejak audit, bukan sebagai gerbang mesin; resep menghidupkan kembali
  pengawasannya (audit saja, atau gerbang keras lewat branch protection/PR)
  ditulis di `docs/CI.md`. Pemasangannya tetap keputusan operator.
- Web: **mode founder tidak lagi jatuh ke "tempel ADMIN_TOKEN" saat id_token
  Google sudah lewat.** Founder yang sudah login (OTP atau sesi lama) tetapi
  tidak punya id_token segar sebelumnya disuruh menempel token manual; kini
  halaman berita menawarkan tombol "Lanjutkan dengan Google" sekali-klik —
  mengambil id_token segar lalu kembali otomatis ke artikel. Decode payload
  id_token diberi padding base64 (atob butuh kelipatan 4). Tempel ADMIN_TOKEN
  tetap tersedia sebagai cara lama.
- CI: **Publikasi Release ditolak 403 oleh token bawaan.** `GITHUB_TOKEN`
  menjawab "Resource not accessible by integration" saat membuat GitHub
  Release, walau job sudah menyatakan `contents: write` dan izin default
  workflow di repo sudah dinaikkan ke *read and write* — tiga run rilis 6.5.0
  gagal berturut-turut di langkah yang sama, selalu setelah semua artefak
  selesai dibangun. Membuat Release dengan PAT pemilik repo terbukti berhasil,
  jadi langkah publikasi kini memakai secret `RELEASE_TOKEN` bila tersedia dan
  jatuh kembali ke `GITHUB_TOKEN` supaya fork tanpa secret tidak langsung
  patah.
- CI: **Release tidak pernah jalan otomatis sejak push berhenti memicu Build.**
  Job `prepare` di `release.yml` mensyaratkan `workflow_run.event == 'push'` —
  sisa asumsi dari sebelum kebijakan 3 Sep 2026. Karena semua Build kini
  dijalankan lewat `workflow_dispatch`, syarat itu tidak pernah lagi terpenuhi
  dan Release diam-diam berstatus `skipped` walaupun versi sudah dinaikkan
  (ketahuan saat rilis 6.5.0: Build `33781937189` hijau 12/12, Release
  `33783260164` skipped tanpa satu pun log). Kini yang diperiksa adalah
  Build-nya **sukses**, bukan apa yang memicunya.

## [6.5.0] - 2026-09-03

> **Build 28.** Rilis ini mengumpulkan kerja sepanjang 3 Sep 2026 dari
> seluruh area: host engine, shell desktop Windows, web, worker berita,
> aplikasi Android, dan perkakas rilis. Nomor MINOR dipilih karena ada
> kemampuan baru yang kompatibel ke belakang (unggah foto profil, login
> Google untuk admin, Pengaturan lengkap di shell host) tanpa satu pun
> perubahan yang mematahkan protokol atau format data tersimpan.

### Ditambahkan
- Host + Web + Client Flutter: **client sekarang lapor diri saat pairing**
  (`name` + `platform` di pesan `pair`), jadi panel host menampilkan "siapa yang
  menonton" dengan nama, bukan ID acak: Web mengirim "Chrome di Windows"
  (ditebak dari userAgent, tanpa izin tambahan), APK mengirim nama akun bila
  sudah login dan kalau belum pakai label sistem ("HP Android"). Host menyimpan
  label di `PairedPeers` selama izin peer hidup dan membersihkannya bersama
  `revoke`; nilainya hanya tampilan — tidak pernah dipakai untuk memutuskan
  akses, dan `SignalMessage`/`SignalMessage.toJson` tetap mengirim field kosong
  sebagai tidak-ada supaya client lama tidak berubah bentuk pesannya.
- Shell desktop: **Pengaturan punya kendali yang selama ini cuma bisa diubah dari
  HP** — monitor sumber (`display-select`), batas bitrate + perkiraan
  MB-per-jam (`video-bitrate`), volume master PC (`audio-volume`), dan pembacaan
  pipeline audio/mic. Semuanya sudah lama didukung control API dan sudah lama
  dilaporkan `GET /status`; yang belum cuma kendelinya.
- Web + Client Flutter + shell desktop: **verifikasi password kini peka-kasus**,
  jadi semua kolom password mematikan auto-kapital & koreksi otomatis.
- Host + shell desktop: **panel host menampilkan perangkat mana yang menonton.**
  Client boleh mengirim `name` + `platform` di pesan `pair`; host menyimpannya
  (`PairedPeers::set_label`, ikut terhapus saat `revoke`) dan menampilkannya di
  chip topbar, kartu "Sesi aktif", baris log pairing, tooltip tray, dan judul
  jendela — lewat `clientName`/`clientPlatform` di `GET /status`. Client lama
  yang tidak mengirim field itu tetap bisa pairing: UI jatuh ke ID pairing,
  bukan menampilkan nama kosong. Nilainya dilaporkan sendiri oleh peer, jadi
  tidak pernah dipakai untuk memutuskan akses.
- Host: `host/TEST-LAB-WINDOWS.md` — langkah uji lab Windows siap jalan (resep
  menukar ID+password jadi token signaling, membaca `/status` lewat control
  API, lima blok pengujian: blip jaringan, capture berhenti, ketikan panjang,
  satu-sesi-satu-waktu, papan klip). Sebagian besar `host/` hanya terbukti
  berperilaku benar di mesin Windows nyata, dan sampai sekarang tidak ada satu
  pun dokumen yang menuliskan cara mengujinya.
- Pengujian: **22 test baru untuk jalur auth & publish** (Backend/Edge,
  tanpa perubahan kode produksi). `verifyGoogleIdToken` — verifikasi ID
  token Google (RS256 via JWKS) yang sebelumnya tidak punya satu test pun —
  kini dikunci 14 kasus (audience, issuer, kedaluwarsa, email terverifikasi,
  sub, kid tak dikenal, tanda tangan asing, JWKS mati) memakai kunci RSA
  sungguhan, bukan mock `ok: true`. `verifyJwt` ditambah kasus tepi (typ
  asing, `nbf` masa depan, `iat` terlalu maju, payload korup, secret kosong).
  Token signaling ditambah kasus rusak/tamper/secret kosong; `relayAllowed`
  dilengkapi arah `bye`/`ice` dua arah + tolak sesama role. Di sisi berita,
  `adminPublish` dikunci 8 kasus — termasuk aturan slug yang pernah terlewat
  di rilis 6.4.0: tanpa field `slug`, artikel changelog jatuh ke hash acak
  `p-…` dan tautan versi di footer web menunjuk ke artikel yang tidak ada.
  Hasil: `cloudflare/` 51/51 hijau, `news/` 20/20 hijau (`node --test`).
- Backend/Edge: **admin berita kini punya jalur kedua lewat Google ID token.**
  Sebelumnya founder menempel `ADMIN_TOKEN` sekali di perangkat (UI web sudah
  ada, worker memvalidasi). Kini worker berita juga menerima header
  `x-admin-google-token` (ID token OpenID) — diverifikasi signature +
  audience langsung ke JWKS Google, lalu hanya diterima bila email token ==
  `FOUNDER_EMAIL`. Jalur `x-admin-token` lama tetap sah. Gagal-tertutup:
  tanpa `GOOGLE_CLIENT_ID`/`FOUNDER_EMAIL` jalur Google nonaktif. Verifikasi
  identik dengan worker signaling (`cloudflare/src/auth.js`), dikunci
  `news/test/google-admin.test.js` (12 kasus: RSA sungguhan, audience salah,
  kedaluwarsa, email non-founder, tanpa konfigurasi, komentar + publish lewat
  fetch). `news/` 32/32 hijau. Sisi klien (web mengirim token saat founder
  masuk) ikut dikerjakan sesi Web: id_token disimpan saat login dan dikirim
  sebagai `x-admin-google-token` saat berkomentar (fallback `ADMIN_TOKEN`
  tetap ada) — keduanya sudah live.

### Diubah
- Host: **perbandingan password pairing jadi peka-kasus** (`identity::verify_password`).
  Password hasil generasi kini memakai 54 simbol (huruf besar + kecil + angka,
  tanpa `I`/`l`/`1` dan `O`/`o`/`0`) sehingga besar-kecil benar-benar dihitung:
  ≈ 5,75 bit/karakter → ~57,5 bit untuk 10 karakter (sebelumnya 31 simbol,
  ~49,5 bit). Perubahan yang HARUS dibaca sebelum rilis: HP/APK lama yang
  mengkapital huruf pertama akan gagal pairing kalau password-nya campuran.
  Karena itu ada jaring satu arah — kalau password yang tersimpan tidak punya
  satu pun huruf kecil (`is_legacy_shape`), host tetap membandingkan tanpa
  peduli kasus, dan host mencetak catatan di startup + shell desktop memberi
  peringatan di kolom password kustom. Tidak ada mode "kembali seperti dulu":
  kalau pengguna terkunci, pemulihannya fisik (`--new-password` / tombol
  "Password acak baru") lalu pairing ulang.
- Host: `ActionRequest` menerima `bitrateMbps` sebagai alias dari
  `bitrate_mbps` (body `POST /action` memang snake_case sementara `GET /status`
  camelCase — jebakan yang sudah sekali menjebak); `identity::set_password` kini
  juga menolak password yang seluruhnya karakter kontrol dan menghitung
  minimum per KARAKTER, bukan per byte.
- Shell desktop: **merek di sidebar sekarang logo resmi**, bukan SVG "X"
  gambar tangan. `desktop/public/logo.png` dan `desktop/electron/tray.ico`
  (ikon tray + taskbar + `build.win.icon`) ditambahkan sebagai target
  `tool/gen_logo.py`, jadi keduanya ikut diregenerasi bersama aset platform
  lain; `docs/BRAND_ASSETS.md` mencatat barisnya. `themeColor` layout ikut
  disamakan ke terang (#fafaf9) dan favicon jendela memakai aset yang sama.
- Host: pesan penolakan pairing di APK diperjelas ("periksa huruf besar/kecil
  dan spasi di ujung") tanpa membocorkan apa yang salah ke pihak yang mencoba
  menebak — host tetap hanya menjawab diterima/ditolak.
- Client Flutter: **unggah foto profil kini aktif.** Kodenya sudah selesai
  sejak 2 Sep, tetapi menunggu satu langkah yang hanya bisa dilakukan pemilik
  akun Cloudinary — membuat *unsigned upload preset*. Preset
  `xydesk_profile_unsigned` kini dibuat dan diverifikasi dengan upload
  sungguhan, jadi tombol "ganti foto" di halaman akun tidak lagi menjawab
  "belum aktif". Unggahan dibatasi gambar `jpg/jpeg/png/webp`, diperkecil ke
  maksimum 512×512, dan diberi nama unik supaya foto satu pengguna tidak bisa
  menimpa milik pengguna lain. Kunci rahasia Cloudinary tetap tidak pernah
  masuk ke aplikasi — klien hanya membawa nama cloud dan nama preset.
- Shell desktop: **mode pratinjau tidak lagi memicu galat hidrasi React
  (#418).** `DEMO` dihitung dari `window.xydesk`, yang tentu saja tidak ada saat
  SSR — dulu nilai itu dipakai langsung sebagai initial state (`DEMO ?
  DEMO_STATUS : null`) dan untuk merender banner, jadi render pertama client
  berbeda dari HTML server dan React membangun ulang seluruh subtree. Data contoh
  sekarang masuk lewat effect setelah mount; di dalam aplikasi Electron tidak ada
  yang berubah (di sana `DEMO` false di kedua sisi). Console bersih di kedua
  jalur (pratinjau dan shell sungguhan, diuji dengan `window.xydesk` tiruan).
- Host: **password hasil generasi tidak lagi huruf besar semua.** `PW_CHARS`
  sekarang 23 huruf besar + 23 huruf kecil + 8 angka, tetap tanpa karakter yang
  mudah tertukar (di kedua kasus: `I`/`l`/`1`, `O`/`o`/`0`). Dulu ini hanya
  perbaikan keterbacaan karena `verify_password` sengaja dibuat tidak peka
  besar-kecil; sejak sesi ini verifikasi itu peka-kasus (lihat butir di atas),
  jadi besar/kecil ikut dihitung sebagai ruang tebakan: ≈ 5,75 bit per
  karakter, 10 karakter ≈ 57,5 bit.
- Host: **satu sumber aturan untuk password kustom.** `identity::set_password`
  yang memotong spasi ujung, menghitung minimum 6 KARAKTER (bukan byte), dan
  menolak karakter kontrol (Enter/Tab tidak bisa diketik dari papan ketik HP);
  control API `set-password` memanggilnya alih-alih punya salinan aturannya
  sendiri — dulu keduanya bisa berbeda pendirian soal password yang sama.
- Shell desktop: **topbar menyatu dengan baris judul Windows.** `main.cjs`
  memakai `titleBarStyle: 'hidden'` + `titleBarOverlay` sewarna UI, topbar jadi
  daerah seret berisi info yang selalu dibutuhkan (status engine, perangkat +
  durasi sesi, ID pairing yang bisa diklik untuk menyalin), `backgroundColor`
  jendela disamakan dengan `--bg` (#fafaf9; dulu #131315 sehingga ada kilat
  gelap sebelum Next.js menggambar). Pill status yang dulu dobel di bawah
  sidebar dihapus, banner "mode pratinjau" pindah dari `position: absolute`
  (dia menutupi judul halaman) ke baris sendiri di atas topbar.
- Shell desktop: item navigasi di sidebar tidak lagi tampil sebagai pil putih.
  Aturan global `button { background: var(--overlay) }` menimpa seluruh
  `<button>`; `.sidebar .nav button` dulu hanya menimpa `:hover`-nya, jadi
  keadaan diamnya tetap putih di atas sidebar hitam.
- Shell desktop: teks di daerah isi bisa diseleksi lagi. `body { user-select:
  none }` dipakai agar terasa seperti aplikasi native, tapi ikut membekukan
  log engine, artikel berita, dan kode pairing di halaman Hubungkan; sekarang
  `.page-body` mengembalikan `user-select: text` dan tombolnya tetap none.
- CI: **`release.yml` menolak merilis SHA yang tertinggal dari `main`.**
  Sebelumnya `prepare` hanya memeriksa "tag belum ada", sehingga ketika
  `pubspec.yaml` ikut berubah di sebuah commit fitur, Release bisa menandai
  versi di SHA itu — persis yang membuat `v6.3.0` sempat menunjuk isi tanpa
  perbaikan layar hitam dan harus dianulir paksa. Kini rilis otomatis berhenti
  merah bila `main` sudah maju (menyebut berapa commit tertinggal), sedangkan
  dispatch manual dengan `release_sha` diteruskan dengan peringatan karena SHA
  itu memang disengaja operator.
- CI: **`tool/check-host-windows.sh` dapat bit executable** (`100644` →
  `100755`). Perintah cross-check yang didokumentasikan di `docs/CI.md` gagal
  `Permission denied` di setiap klon baru.
- Dokumentasi: **`docs/CI.md` memuat aturan papan #5 (jalur deploy cepat)** —
  Web app serta worker Backend/Edge dan berita boleh deploy langsung dengan
  empat syarat kumulatif, sementara build/rilis penuh tetap kewenangan
  CI/Release. Aturan ini sebelumnya hanya hidup di `AGENT_BOARD.md`.
- Dokumentasi: **README dan `docs/CI.md` disamakan dengan kebijakan pemicu
  3 Sep 2026.** README masih berjudul "Build dan Release Otomatis" dan
  membuka dengan "Push ke `main` menjalankan analisis statis serta build
  Android, Windows, dan Web" — sudah tidak benar sejak push berhenti memicu
  actions, dan itu menyesatkan kontributor baru untuk menunggu build yang
  tidak akan pernah jalan. Bagian Release di `docs/CI.md` juga masih menyebut
  versi sebagai "satu-satunya pemicu rilis" lewat push; kini dijelaskan
  alur sebenarnya (operator → push berizin → dispatch Build → Release via
  `workflow_run`). Tabel workflow ditambah tiga berkas yang sebelumnya tidak
  terdaftar: `build-desktop.yml`, `deploy-news.yml`, `test-lab.yml`.
- Dokumentasi: **`docs/VERSIONING.md` dimutakhirkan** — contoh versi acuan
  `6.2.0+22` → `6.4.0+27` (sesuai `pubspec.yaml`), tag contoh `v6.2.0` →
  `v6.4.0`, dan kalimat usang "rilis berikutnya adalah 6.2.0" diganti catatan
  status. Ditambah peringatan bahwa pola slug `changelog-v6-2-0` tidak lagi
  cocok dengan slug hash acak yang diterbitkan worker berita (tautan versi di
  footer jatuh ke 404) — diteruskan ke role Web/News lewat `HANDOFF.md`.
- Dokumentasi: **koreksi diagnosis slug changelog** (audit lanjutan, hari yang
  sama). Peringatan yang saya tulis sebelumnya keliru menyimpulkan worker
  memaksa slug hash. Setelah membaca `adminPublish` di `news/src/worker.js`:
  pola `changelog-v<X>-<Y>-<Z>` justru SUDAH didukung sebagai satu-satunya
  slug yang boleh diminta sendiri. Jadi ini bukan bug kode melainkan langkah
  rilis yang terlewat — artikel 6.4.0 diterbitkan tanpa field `slug` sehingga
  jatuh ke `p-8f5aa26aa3bc`. `docs/VERSIONING.md` kini menegaskan field itu
  wajib diisi untuk artikel rilis, dengan bukti HTTP yang diverifikasi.
- Dokumentasi: **`docs/NEWS_STYLE.md` memuat pembagian penulisan berita** —
  versi & berita keputusan operator, tiap agent menulis bahan kerjanya
  sendiri, satu rilis satu artikel yang disatukan role CI/Release. Sebelumnya
  aturan ini hanya hidup di `AGENT_BOARD.md` dan `news/README.md`, sehingga
  penulis yang membuka panduan gaya saja tidak menemukannya.
- Proses: **papan koordinasi dirapikan** — semua baris sesi berstatus
  `SELESAI` yang masih menumpuk di tabel *Sesi aktif* dan *Antrean izin
  push* dipindahkan ke *Riwayat sesi* (sejarah tidak dihapus), dan rilis
  6.4.0 yang sebelumnya tidak tercatat kini tercantum sebagai
  `SESI-20260903-CAKRA-RILIS64`.
- Berita: **byline sisa dinormalkan** — default/seed/fallback yang masih
  memakai `Tim XyDesk` (`news/schema.sql`, `news/seed.sql`, `news/README.md`,
  dan fallback `news_service.dart` di Flutter) diselaraskan ke
  `Haekal Saputra` sesuai mandat operator, supaya nama lama tidak muncul
  lagi saat seed ulang atau saat author kosong.
- Host: **ketikan panjang dari client diinject per batch.** Satu pesan teks
  (0x06) kini dipecah ≤ 32 karakter per panggilan `SendInput`, dan sisa yang
  belum disisipkan dikirim ulang mengikuti nilai kembali sistem (dokumentasi
  Win32 menyatakan batas per panggilan berbeda antar versi Windows — batch
  besar sebelumnya bisa hilang sebagian tanpa jejak). Teks di atas 4.096 unit
  UTF-16 dibuang pada batas karakter, bukan dipotong di tengah pasangan
  surrogate, supaya satu tempel raksasa tidak membebani host yang harus selalu
  aktif.
- Host: keputusan "kapan sebuah sesi dianggap berakhir" pindah ke satu fungsi
  (`session::slot_action`) dan dikunci uji unit, sehingga kebijakannya tidak lagi
  tersebar di `matches!` dalam handler.

### Diperbaiki
- Web: **kolom password pairing tidak lagi memaksa huruf besar.**
  `autoCapitalize="characters"` di form Hubungkan membuat peramban ponsel
  menampilkan (dan di sebagian peramban, mengirim) password dalam huruf besar semua —
  dulu tidak terasa karena host mengabaikan kasus, sekarang langsung mengunci
  pengguna. Diganti `none` + `autoCorrect=off` + `spellCheck=false`; pesan
  "ID atau password salah" ikut menyebut besar-kecil.
- Client Flutter: kolom kata sandi memakai `TextCapitalization.none` +
  `autocorrect: false` + `enableSuggestions: false` (default Flutter adalah
  `sentences`: huruf pertama dikapital diam-diam).
- Pengujian: **flake lama di tes identitas ditutup.** Beberapa tes mengarahkan
  penyimpanan identitas lewat env `XYDESK_HOME` lalu menulis ke direktori
  sementara masing-masing, sementara `cargo test` menjalankan tes paralel dalam
  satu proses — jadi hasil kadang bergantung urutan thread. Sekarang semua tes
  yang menyentuh env itu berebut satu gembok RAII (`identity::lock_home_env`
  untuk tes sinkron, `lock_home_env_async` untuk tes `tokio::test` yang harus
  memegangnya sambil menunggu I/O; guard-nya `Send` karena itu, bukan `Mutex`
  std). Diulang 12× tanpa kegagalan.
- Shell desktop: **konten yang lebih tinggi dari jendela akhirnya bisa
  digulung.** `.shell` adalah grid dengan satu baris `auto`, jadi dia MEMANJANG
  mengikuti isinya dan `body { overflow: hidden }` menutup sisanya: di viewport
  1100×480 halaman Pengaturan terpotong 776px tanpa satu pun scrollbar, dan
  `.page-body { overflow-y: auto }` tidak pernah aktif. Baris grid kini
  `minmax(0, 100%)` + `min-height: 0` di `.main` dan `.page-body`, sidebar
  mendapat scroll sendiri, dan scrollbar daerah isi diberi thumb supaya jelas
  ada yang bisa digulung. Diukur pakai Playwright di 5 halaman × 3 viewport
  (1280×720, 900×560, 1100×480): 0 baris terkunci, topbar tetap di tempatnya
  setelah isi digulung.
- Host: **koneksi yang terlepas sebentar tidak lagi mematikan sesi.** Blip Wi-Fi
  (berpindah kanal, sinyal drop dua detik) membuat ICE agent melaporkan
  `Disconnected`, dan host memperlakukannya sama seperti koneksi mati
  permanen: izin pairing langsung dicabut sehingga kandidat ICE berikutnya dari
  klien yang sama ditolak ("bukan sesi aktif") — sesi yang sebenarnya masih
  bisa hidup menjadi tidak mungkin pulih. Sekarang ada masa tenggang 15 detik;
  kalau sesi belum tersambung lagi, slot dicabut DAN peer connection-nya
  ditutup.
- Host: **capture dan encoder tidak lagi hidup tanpa penonton.** Pelepasan slot
  sesi sebelumnya hanya mencabut catatan izin, tanpa menutup peer connection —
  loop video berhenti hanya pada `Closed`/`Failed`. Sesi yang ditinggalkan bisa
  terus memakan CPU/GPU, dan di Windows duplikasi DXGI yang menggantung turut
  membuat sesi berikutnya mendapat layar hitam.
- Host: **status shell tidak bisa lagi ditimpa teardown sesi lama.** Sesi lama
  yang akhirnya tertutup setelah sesi baru berjalan sebelumnya ikut menghapus
  catatan "sedang streaming" (panel menampilkan "siap" padahal ada orang yang
  sedang melihat layar) dan mencabut izin pairing klien yang benar. Pelepasan
  slot kini memeriksa apakah sesi yang tercatat memang sesi milik teardown itu.
- Host: **satu sesi media pada satu waktu.** `offer` ulang (renegosiasi ICE) dari
  klien yang sama membuat sesi baru sementara sesi lamanya dibiarkan berjalan;
  sesi lama kini ditutup saat sesi baru dicatat.
- Host: **password pairing tidak lagi bisa hilang karena panic task media.**
  `set_streaming` memakai `recover_lock` seperti semua jalur produksi lain — itu
  satu-satunya `.lock().unwrap()` yang tersisa di loop utama, dan mutex
  ter-poison di situ merobohkan proses.
- Host (Windows): **papan klip tidak lagi membocorkan memori bila penulisannya
  ditolak sistem** — blok global yang sudah dialokasi kini dibebaskan saat
  `GlobalLock` atau `SetClipboardData` gagal; sebelumnya bocor permanen di heap
  global pada proses yang ditargetkan hidup berhari-hari.
- Host: **pemeriksaan lint Windows hijau lagi.** Dua lint hanya terlihat di
  target Windows (`doc` comment menggantung di `screen.rs`, implementasi manual
  `Iterator::find` di `gui.rs`) dan lolos dari CI karena job `host-test`
  mengompilasi cfg non-Windows.
- Host: `host/Cargo.lock` kembali cocok dengan `Cargo.toml` — sejak bump 6.4.0
  lock masih mencatat 6.3.0.
- Web: **tautan versi di footer tidak lagi berujung dead-end.** Artikel
  changelog 6.4.0 diterbitkan tanpa field `slug`, jadi `changelog-v6-4-0`
  mengembalikan 404 dan klik "XyDesk v6.4.0" menampilkan galat mentah.
  Kini `news.ts` melempar `ApiError` (bukan `Error` polos) sehingga halaman
  bisa membedakan 404 dari gangguan jaringan, dan halaman detail berita
  menampilkan penjelasan ramah "Catatan rilis versi ini belum tersedia"
  dengan tombol ke daftar semua berita bila slug changelog 404. Perbaikan
  akar (slug wajib saat publish) tetap milik News/CI — dicatat di HANDOFF.
- Changelog: **17 butir rilis 6.4.0 yang kalimatnya terpotong direstorasi.**
  Commit bump versi 6.4.0 (`4cbbc22`) memotong bullet multi-baris menjadi
  baris pertama saja (mis. "— ikon AI 3D ungu glossy" tanpa kelanjutan),
  sehingga catatan rilis yang terbit di GitHub memajang kalimat menggantung.
  Teks lengkap dipulihkan dari git history (parent `4cbbc22^`), bukan
  dikarang; body GitHub Release `v6.4.0` ikut dipatch dengan teks lengkap
  (18 butir asli rilis — butir yang masuk setelah rilis tidak ditambahkan).
  Salinan body lama tersimpan untuk rollback.

## [6.4.0] - 2026-09-03

### Ditambahkan
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
- Web: **foto profil ganda di komentar resmi berita** — kepala komentar
  sudah menggambar avatar (foto founder), tapi komponen nama penulis
  menggambarnya sekali lagi dari dalam, sehingga komentar akun resmi
  tampil dengan dua foto identik bersebelahan. Kini komponen itu punya
  prop `avatar` dan komentar/reply mematikannya; byline artikel tetap
  menampilkan foto founder.
- Berita/D1: byline sisa di tabel posts — 5 artikel lama masih bernama
  `Tim …` (mis. `Tim XyDesk`, luput dari normalisasi sebelumnya yang
  hanya menangkap `Tim XySpace`) kini semua `Haekal Saputra`.
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
- Desktop (host Windows): **"Engine belum siap" kini menjelaskan sebabnya** — supervisor mencatat kesalahan terakhir (token ditolak, exe tak ditemukan, kode keluar engine) dan mengirimnya ke UI, plus ID/password pairing tetap tampil walau engine mati. Sebelumnya kegagalan hanya tersembunyi di tab log dan halaman Home cuma bilang "belum siap".
- Desktop (host Windows): **UI konsisten berbahasa Indonesia** — label navigasi `Home/Connect/News/Profile/Settings` → `Beranda/Hubungkan/Berita/Profil/Pengaturan`, judul halaman dan label `Mode` ikut dibumikan (sebelumnya campur Inggris di tengah konten Indonesia).
- Desktop (host Windows): **tab Berita lebih tahan gangguan** — permintaan API news diberi timeout 10 dtk, pesan gagal dijelaskan dalam bahasa Indonesia ("Gagal memuat berita — periksa koneksi internet."), plus tombol `Coba lagi` dan tautan buka di web bila server tidak terjangkau.


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

### Ikutan rilis ulang (build +26, 2026-09-03)

_Ditambahkan_ — items yang sudah ikut terkirim di rilis ulang 6.3.0+26:

- Desktop (host Windows): GUI host kembali ke **shell Electron + Next.js**
- Desktop (host Windows): **host selalu aktif** — menutup jendela kini
- Web: **harness uji E2E lokal** (`web/e2e/`) — signaling Go + shim auth
- Host: **mic input PC → client** — mikrofon host direkam via WASAPI
- Host: `/status` kini melaporkan **latensi pipeline video** dan **label

_Diperbaiki_ — items yang sudah ikut terkirim di rilis ulang 6.3.0+26:

- Web: **layar sesi didesain ulang ke arah paritas aplikasi** — baris tombol
- Berita (lintas area, restu operator): penulis artikel selalu
- Host: durasi sampel video (maju timestamp RTP per frame) diseragamkan ke
- Web: halaman **Sewa PC** (`/billing`) — pilih paket & spek, durasi mulai
- Web: mode founder di komentar berita — login Google `xycdigital@gmail.com`
- Client Flutter: **unggah foto profil dari galeri ke Cloudinary** (unsigned
- Client Flutter: dependensi baru `image_picker` (untuk memilih foto dari
- Client Flutter: kontrak konfigurasi unggah Cloudinary dikunci lewat uji
- Client Flutter: **nav bawah & rail memakai ikon AI 3D ungu glossy** (aset
- Client Flutter: **pilihan sumber papan ketik sesi** — "XyDesk" (papan ketik
- Client Flutter: **tombol "Kirim" komentar berita kini aktif saat mengetik**.
- Client Flutter: identitas komentar mengikuti sesi — pengguna yang *login*
- Client Flutter: halaman **Syarat & Ketentuan / Kebijakan Privasi** kini
- Client Flutter: jarak antara chip "Riwayat" dan kolom ID perangkat di

_Diubah_ — items yang sudah ikut terkirim di rilis ulang 6.3.0+26:

- Client Flutter: dokumen legal tidak lagi menampilkan teks polos yang sama


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

# CI/CD — XyDesk

Build dan rilis dijalankan melalui GitHub Actions agar perangkat pengguna tidak
perlu menjalankan Flutter, Android SDK, Rust, atau Visual Studio secara lokal.

## Workflow

| Berkas | Pemicu | Hasil |
|---|---|---|
| `.github/workflows/build.yml` | **manual** (`workflow_dispatch`) saja — tidak otomatis oleh push | gerbang mutu per-area, APK Android, `XyDesk.exe` + `XyDesk-Host.exe`, bundle Web |
| `.github/workflows/deploy-signaling.yml` | **manual** (`workflow_dispatch`) | deploy Cloudflare Worker API/signaling |
| `.github/workflows/deploy-web.yml` | Build `main` sukses, manual recovery | deploy bundle Flutter Web terverifikasi ke Cloudflare Static Assets |
| `.github/workflows/release.yml` | Build `main` sukses + nilai `version` berubah (menolak SHA yang tertinggal dari `main`), manual recovery via `release_sha` | GitHub Release multi-platform + push OneSignal |
| `.github/workflows/build-desktop.yml` | **manual** (`workflow_dispatch`) | kemasan shell desktop Electron + Next.js |
| `.github/workflows/deploy-news.yml` | **manual** (`workflow_dispatch`) | deploy Worker berita + migrasi D1 |
| `.github/workflows/test-lab.yml` | **manual** (`workflow_dispatch`) | uji lab perangkat |
| ~~`.github/workflows/verify-push-auth.yml`~~ | **dihapus** operator 5 Sep 2026 (`b4ce4a4`) — resep pemulihan ada di bawah | dulu: audit izin push, commit wajib memuat `Izin: <ID>` berstatus `DISETUJUI` di `AGENT_BOARD.md` |

## Kebijakan pemicu (sejak 3 Sep 2026): push TIDAK memicu actions

Push ke `main` **tidak memicu actions apa pun**. Dulu ada satu
pengecualian — gerbang audit `verify-push-auth.yml` — tetapi workflow itu
dihapus operator pada 5 Sep 2026 (commit `b4ce4a4`), jadi sekarang betul-betul
nihil: tidak ada workflow yang berjalan karena push.
Semua jalur — build terfilter maupun penuh, kemasan desktop, deploy
web/news/signaling, rilis — hanya lewat `workflow_dispatch` dan dijalankan
oleh role CI/Release (Cakra) setelah izin operator: bump versi → Build →
Release → deploy → berita, dalam satu run penuh saat operator menyatakan
siap. Alasan: build otomatis dari push perantara menghasilkan "hijau
palsu" (run terfilter, artefak tak lengkap), run yang terbuang, dan
tumpang tindih dengan jadwal rilis; hasil akhir yang dianggap bukti hanya
run penuh yang disetujui. `release.yml`/`deploy-web.yml` menyala HANYA
setelah Build sukses — pemicu sebenarnya tetap satu (dispatch oleh Cakra).

### Pengecualian: jalur deploy cepat (aturan papan #5, 3 Sep 2026)

Restu operator di chat membuka satu pengecualian dari "semua lewat dispatch":
**Web app** serta **worker Backend/Edge dan worker berita** boleh di-deploy
langsung oleh role pemiliknya, tanpa menunggu dispatch CI/Release. Syaratnya
kumulatif — semuanya, bukan pilih salah satu:

1. push sudah di `main` dan `verify-push-auth` hijau;
2. build memakai env produksi yang benar (mis. `VITE_GOOGLE_CLIENT_ID`);
3. verifikasi pasca-deploy dijalankan **dan dicatat** (contoh Web: md5 bundle
   live == artefak build, `content-type` JS benar);
4. dicatat terbuka di baris sesi papan + item `HANDOFF.md` ke CI/Release pada
   sesi yang sama.

Yang TIDAK ikut pengecualian ini: **build/rilis penuh** — APK, Windows,
installer, tag rilis — tetap kewenangan CI/Release lewat `workflow_dispatch`.
Kredensial deploy milik operator; pembagiannya ke lingkungan agent lain adalah
keputusan operator, bukan agent.

### Sebelum build/rilis: cek papan, lalu izin operator (sejak 3 Sep 2026)

Aturan operator — bukan saran, bukan kebiasaan:

1. **Versi & berita = keputusan operator.** Role build/rilis TIDAK
   menetapkan nomor versi, tidak memilih isi berita, dan tidak menaikkan
   `pubspec.yaml` atas inisiatif sendiri. Semua lewat arahan operator.
2. **Cek kerjaan agent lain dulu.** Sebelum mengajukan build penuh/rilis:
   baca `AGENT_BOARD.md` (sesi aktif) + `HANDOFF.md` dan pastikan sesi
   yang menyentuh area rilis (client, host, desktop, web) sudah `SELESAI`.
   Kalau masih ada yang berjalan: TAHAN, laporkan ke operator — jangan
   memaksakan rilis.
3. **Push wajib izin operator.** Termasuk bump versi dan push yang
   menyentuh `pubspec.yaml`/`release.yml`/`build.yml` — antre di
   `AGENT_BOARD.md`, tunggu `DISETUJUI`, baru push. Push sendiri tidak
   menjalankan build apa pun — hanya gerbang audit izin.
4. **Satu gerakan saat siap.** Rilis penuh dikerjakan SEKALIGUS ketika
   operator menyatakan siap: bump → Build → Release → deploy → berita
   (artikel = bahan yang disatukan dari tiap agent).

Untuk memicu Build penuh:

```bash
gh workflow run build.yml --ref main
```

**Catatan anti-race (3 Sep 2026):** `deploy-web.yml` mempercayai API, bukan payload `workflow_run` — SHA run Build diambil dari catatan run, checkout memakai SHA itu, artefak dicocokkan dengan run-nya, deploy berjalan serial (`cancel-in-progress: false`), dan hanya Build web terbaru yang deploy (run basi menyingkirkan diri). Pelajaran: dua Build sukses berdekatan sempat membuat run deploy menimpa bundle baru dengan yang lama (6c5ba06/d90e12a).

## Filter area di Build (sejak 3 Sep 2026)

`build.yml` tidak lagi menjalankan seluruh rantai untuk setiap push/PR.
Job `changes` (selalu berjalan, murah) mendeteksi area yang tersentuh lewat
`dorny/paths-filter`; job lain hanya hidup bila areanya berubah. Peta
filternya (ubah bersama `docs/CI.md` bila bergeser):

| Perubahan | Job yang jalan |
|---|---|
| `lib/`, `test/`, `assets/`, `android/`, `design/`, `tool/`, `pubspec*`, `analysis_options.yaml` | `check-flutter` → `android` + `windows` |
| `host/**` (dan `pubspec.yaml` — bump rilis) | `host-test` → `windows` |
| `web/**` | `web` |
| `news/**` | `check-news` |
| `cloudflare/**`, `signaling/**` | `check-signaling` |
| `packaging/**` | `installer-lint` |
| `docs/`, `AGENT.md`, `AGENT_BOARD.md`, `HANDOFF.md`, `CHANGELOG.md`, `CONTRIBUTORS.md`, `README.md`, `ROADMAP.md`, `SETUP.md`, `.github/workflows/**`, manifest versi | `check-meta` (konsistensi versi) |
| `workflow_dispatch` | **semua** job (build penuh untuk pemulihan) |

Konsekuensi yang dijaga:

- **Rilis tetap utuh.** `pubspec.yaml` masuk filter `flutter` AND `host`,
  sehingga bump versi (satu-satunya pemicu rilis) membangun ulang rantai
  client + host — `release.yml` selalu menemukan artefak
  `XyDesk-Android-APK` dan `XyDesk-Windows-<arch>`.
- **PR dokumen punya status check.** Job `changes` selalu hijau, plus
  `check-meta` untuk perubahan dokumen — tidak ada lagi PR "tanpa check".
- **Deploy tidak ikut salah jalan.** `deploy-web.yml` memeriksa keberadaan
  artefak `XyDesk-Web` pada run Build yang memicunya; kalau tidak ada
  (perubahan tidak menyentuh `web/`), deploy dilewati dengan peringatan,
  bukan gagal.
- **Job `skipped` = bukan areamu, bukan kegagalan.** Baca tabel *Ringkasan*
  pada run untuk melihat area yang terdeteksi.
- **Release hanya mau Build penuh.** `release.yml` memeriksa artefak
  `XyDesk-Android-APK` + `XyDesk-Windows-x64/arm64` pada run Build yang
  dipilih; kalau tidak ada (run terfilter), rilis dilewati dengan
  peringatan, bukan merah. Build penuh lewat `workflow_dispatch` berjalan
  di jalur `manual` (tidak dibatalkan push biasa).
- **Branch protection**: kalau ada, daftar required check nama-nama job
  berubah (mis. `Analisis Statis (Flutter)` menggantikan `Analisis Statis`).

Check yang lama (`Analisis Statis`, satu job raksasa) dipecah menjadi
`check-flutter`, `check-news`, `check-signaling`, dan `check-meta` supaya
filter per-area mungkin dilakukan tanpa kehilangan satu pun pengawal:
analyze/format/test/lisensi/audit aset tetap jalan pada perubahan client,
test Worker berita pada perubahan `news/`, test JWT/OTP/rate-limit + gofmt +
**`go vet` + `go test`** pada perubahan `cloudflare/` atau `signaling/`
(uji Go menjagai aturan token & arah relay server self-host agar tidak
menyimpang dari Worker produksi).

## Verifikasi izin push — **sedang NONAKTIF**

> **Status 6 Sep 2026: workflow `verify-push-auth.yml` dihapus operator
> sendiri** (commit `b4ce4a4`, 5 Sep 2026) dan branch `main` tidak
> memakai branch protection. Jadi saat ini **tidak ada satu pun workflow
> yang berjalan karena push**, dan tidak ada pemeriksaan yang menolak
> push ke `main`. Bagian di bawah ini disimpan sebagai resep bila gerbang
> ingin dihidupkan kembali.

Aturan yang tetap berlaku sebagai kebiasaan tim (bukan sebagai gerbang
mesin): setiap commit non-merge pada push ke `main` WAJIB memuat penanda
`Izin: <ID-SESI>` di body, dan ID-nya harus punya baris di
`AGENT_BOARD.md`. Pengecualian: commit merge (tindakan operator), commit
yang ditulis operator (`OPERATOR_LOGIN` di repository variables), dan
commit dari `Operator - XyDesk Team` (role Operator, `AGENT.md` bagian
2.1) — ia mewakili operator, jadi penanda `Izin:`-nya tetap dicatat
sebagai jejak, tetapi tidak perlu status `DISETUJUI`.

Untuk menghidupkan kembali pengawasannya, pilih salah satu:

1. **Audit (pelanggaran tampil merah)** — pulihkan workflow
   `verify-push-auth.yml` dari riwayat git (`git show b4ce4a4^:.github/
   workflows/verify-push-auth.yml`). Tidak perlu pengaturan lain; hasilnya
   tampil di tab Actions, tetapi push tetap tidak ditolak.
2. **Gerbang keras (push tanpa izin ditolak)** — selain workflow di atas,
   pasang salah satu:
   - branch protection `main` → *Require status checks* → wajibkan
     `Periksa izin push`; atau
   - wajibkan PR (tidak ada push langsung) — persetujuan adalah review
     operator + merge-nya. Commit feature branch tetap diperiksa: tulis
     `Izin: <ID>` di body commit (biasa) atau — untuk squash merge — di
     deskripsi/isi PR, karena squash memakai isi PR sebagai body commit.
     Merge commit sendiri (tindakan operator) dikecualikan.

Keduanya keputusan operator — bukan sesuatu yang bisa dipasang agent
sendiri, karena menyangkut siapa yang boleh menulis ke `main`.

## Notifikasi push tanpa izin

Saat gerbang menolak push, langkah terakhir workflow mengirim peringatan ke
operator. Dua kanal didukung — salah satu saja sudah cukup, keduanya juga
boleh:

**ntfy (paling cepat dipasang, tanpa akun)** — buat topic di
<https://ntfy.sh> (mis. `xydesk-izin`), lalu tambahkan repository variable:
`NTFY_WEBHOOK = https://ntfy.sh/xydesk-izin`. Untuk produksi, sebaiknya
self-host ntfy di server sendiri (topic publik bisa dibaca siapa pun yang
tahu namanya).

**Telegram** — buat bot lewat [@BotFather](https://t.me/BotFather)
(perintah `/newbot`, simpan token-nya), cari `chat_id` (kirim pesan ke bot,
lalu GET `https://api.telegram.org/bot<TOKEN>/getUpdates`), lalu:
- secret: `TELEGRAM_BOT_TOKEN` (Settings → Secrets and variables → Actions → Secrets)
- variable: `TELEGRAM_CHAT_ID`

Keduanya tidak wajib tersedia: kalau kosong, workflow hanya memberi
peringatan di log dan pelanggaran tetap terlihat merah. Tidak ada
dependensi baru — pengiriman memakai `curl` bawaan runner.



Sejak 1 Sep 2026 seluruh gerbang host berada di dalam `build.yml`. Sebelumnya
fmt/clippy/`cargo test` host tinggal di `build-host.yml` yang berdiri sendiri
dan tidak menjadi syarat rilis apa pun; akibatnya v6.1.0 sempat terbit pada
16:21 sementara gerbang itu merah pada commit yang sama pukul 16:15. Job
`windows` sekarang `needs: [check, host-test]`, dan `release.yml` hanya jalan
setelah run **Build** sukses — jadi tidak ada jalan memutar: gerbang merah =
tidak ada `.exe`, tidak ada Release.

Sebagai bonus, kompilasi host Windows tidak lagi dobel di dua workflow.

Test otomatis yang wajib hijau: `cargo test` host (loopback WebRTC +
pairguard) dan `node --test` Worker. Pengujian perilaku perangkat keras
(capture DXGI, audio WASAPI) tetap manual setelah EXE dipasang.

## Cross-check Windows sebelum push (`tool/check-host-windows.sh`)

Seluruh jalur WASAPI, DXGI, dan GDI berada di balik `cfg(target_os =
"windows")`. `cargo check` di Linux tidak menyentuh satu baris pun dari kode
itu — yang dikompilasi hanyalah stub non-Windows. Konsekuensinya nyata: salah
ketik dan salah tanda tangan API windows-rs baru ketahuan di GitHub Actions,
dengan siklus umpan balik ~8 menit per percobaan. Pada 31 Agu 2026 pola itu
menghasilkan tujuh commit `fix(host)` beruntun dalam satu jam di `main`,
semuanya error kompilasi sepele.

```bash
rustup target add x86_64-pc-windows-gnu
sudo apt-get install -y mingw-w64      # brew install mingw-w64 di macOS

tool/check-host-windows.sh             # detik, bukan menit
tool/check-host-windows.sh --clippy    # + lint
```

Target `-gnu` dipilih karena `-msvc` menuntut Windows SDK + CRT Microsoft
(~1 GB lewat cargo-xwin). Untuk MEMERIKSA kode keduanya setara — parser, type
checker, dan binding windows-rs identik; yang berbeda cuma ABI dan linker, dan
itu tetap diverifikasi runner Windows asli di `build.yml`.

Yang skrip ini TIDAK buktikan: linking MSVC, perilaku runtime, dan apakah
audionya benar-benar terdengar. Itu tetap tugas lab Windows.

## Build biasa

Push ke `main` menjalankan:

1. `flutter pub get`;
2. `dart format lib`;
3. `flutter analyze --fatal-infos`;
4. pemeriksaan aturan desain seamless;
5. build Android, Windows, dan Web;
6. upload hasil ke **Actions → run → Artifacts**.

Artefak build biasa disimpan 30 hari. Artefak Actions bukan GitHub Release dan
tidak otomatis tampil di halaman Releases.

## Deployment Flutter Web

Setelah workflow Build pada `main` sukses, workflow Web mengambil artefak
`XyDesk-Web` dari run yang sama dan memublikasikannya tanpa build ulang ke
Cloudflare Workers Static Assets. Produksi menggunakan
`https://app.xydesk.my.id`; API, autentikasi, dan signaling tetap terpisah di
`https://signal.xydesk.my.id`.

Konfigurasi publik berada di `web_deploy/wrangler.toml`. Deployment membutuhkan
GitHub Actions Secrets `CLOUDFLARE_ACCOUNT_ID` dan `CLOUDFLARE_API_TOKEN`.
Artefak Web tidak boleh di-commit ke repository.

## Menerbitkan GitHub Release

Versi aplikasi adalah syarat rilis, **bukan lagi pemicunya**. Sejak kebijakan
3 Sep 2026, push tidak menjalankan Build; alurnya: operator menetapkan versi →
naikkan nilai `version` di `pubspec.yaml` (SemVer + Android build, mis.
`6.4.0+27`) → push (dengan izin) → role CI/Release men-*dispatch* `build.yml`.
Setelah run Build itu sukses, workflow Release berjalan (dipicu `workflow_run`
dari Build, bukan dari push) dan:

1. memastikan tag `v<versi>` belum ada (tag menandai versi yang sudah dirilis);
2. memastikan Build sukses berasal dari commit yang sama;
3. memakai APK, Windows client, dan Web dari Build yang sudah lulus;
4. membangun host Rust Windows dari commit yang sama;
5. menerbitkan aset stabil, checksum, dan `update.json`;
6. mengirim OneSignal ke Android dengan `app_version` lebih kecil dari build
   baru.

Build yang sukses tanpa perubahan nilai versi tidak membuat Release. Trigger
manual (`workflow_dispatch` + `release_sha`) disediakan untuk pemulihan.

**Pengawal SHA tertinggal (sejak 3 Sep 2026).** `prepare` menolak merilis SHA
yang sudah dilewati `main`. Alasannya kejadian nyata: `pubspec.yaml` ikut
berubah di sebuah commit fitur, Build jalan, dan Release langsung menandai
`v6.3.0` di SHA itu — padahal perbaikan layar hitam baru masuk empat commit
setelahnya, sehingga tag menunjuk isi setengah jadi dan rilisnya harus
dianulir paksa. Kini:

- SHA rilis == HEAD `main` → lanjut seperti biasa;
- `main` sudah maju dan Release terpicu otomatis → **berhenti merah**, dengan
  pesan berapa commit tertinggal;
- `main` sudah maju tetapi operator mengisi `release_sha` sendiri → lanjut
  dengan peringatan, karena SHA itu memang disengaja.

Aset Release:

- `XyDesk-Android-arm64-v8a.apk` — client Android 64-bit;
- `XyDesk-Android-armeabi-v7a.apk` — client Android 32-bit;
- `XyDesk-Windows-x64-Setup.exe` dan `XyDesk-Windows-arm64-Setup.exe` — installer Windows terpadu;
- `XyDesk-Windows-x64.zip` dan `XyDesk-Windows-arm64.zip` — paket portable terpadu;
- `XyDesk-Host-x64.exe` dan `XyDesk-Host-arm64.exe` — engine standalone untuk otomasi;
- `XyDesk-Web.zip` — client Web;
- `SHA256SUMS.txt` — checksum unduhan;
- `update.json` — manifest update resmi untuk perbandingan build dan verifikasi
  APK;
- `xydesk_update_banner_1024x512.jpg` — gambar push update.

Rilis hanya terbit jika workflow Build untuk commit yang sama sukses dan GitHub
Secret OneSignal tersedia. APK kemudian diverifikasi aplikasi melalui checksum
SHA-256, package ID, nomor build, dan sertifikat signing sebelum installer
Android ditampilkan.

## Signing Android

Secrets berikut harus tersedia di **Settings → Secrets and variables →
Actions**:

- `KEYSTORE_BASE64`
- `KEYSTORE_PASSWORD`
- `KEY_ALIAS`
- `KEY_PASSWORD`

Keystore dan `android/key.properties` tidak boleh di-commit. Workflow membuatnya
sementara di runner dan menghapus runner setelah job selesai.

Push update otomatis juga memerlukan GitHub Actions Secret
`ONESIGNAL_REST_API_KEY`. Nilainya hanya dimasukkan langsung melalui GitHub dan
tidak boleh disimpan di source, log, issue, atau percakapan. Jika Secret ini
belum tersedia, workflow berhenti sebelum GitHub Release dipublikasikan.

## Konfigurasi publik build

Repository variable `GOOGLE_CLIENT_ID` diteruskan sebagai `dart-define` ke build
Android, Windows Flutter, dan Web. Nilai ini bukan secret, tetapi tetap dikelola
di GitHub agar konfigurasi build konsisten.

## Checklist manual setelah install

- buka aplikasi dan pastikan splash selesai;
- login OTP dan Google pada perangkat Android nyata;
- tutup/buka aplikasi untuk memeriksa pemulihan sesi;
- logout dan pastikan sesi terhapus;
- periksa keyboard virtual, HUD, rotasi landscape, dan panel sesi;
- hubungkan host Windows dan periksa video, mouse, keyboard, serta reconnect.

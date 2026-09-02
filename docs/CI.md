# CI/CD — XyDesk

Build dan rilis dijalankan melalui GitHub Actions agar perangkat pengguna tidak
perlu menjalankan Flutter, Android SDK, Rust, atau Visual Studio secara lokal.

## Workflow

| Berkas | Pemicu | Hasil |
|---|---|---|
| `.github/workflows/build.yml` | push/PR (semua branch PR, manual) | gerbang mutu per-area (difilter), APK Android, `XyDesk.exe` + `XyDesk-Host.exe`, bundle Web |
| `.github/workflows/deploy-signaling.yml` | perubahan `cloudflare/**`, manual | deploy Cloudflare Worker API/signaling |
| `.github/workflows/deploy-web.yml` | Build `main` sukses **yang menyentuh `web/`**, manual recovery | deploy bundle Flutter Web terverifikasi ke Cloudflare Static Assets |
| `.github/workflows/release.yml` | Build `main` sukses + nilai `version` berubah, manual recovery | GitHub Release multi-platform + push OneSignal |
| `.github/workflows/verify-push-auth.yml` | setiap push ke `main` | audit izin push: commit wajib memuat `Izin: <ID>` yang berstatus `DISETUJUI` di `AGENT_BOARD.md` |

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
- **Branch protection**: kalau ada, daftar required check nama-nama job
  berubah (mis. `Analisis Statis (Flutter)` menggantikan `Analisis Statis`).

Check yang lama (`Analisis Statis`, satu job raksasa) dipecah menjadi
`check-flutter`, `check-news`, `check-signaling`, dan `check-meta` supaya
filter per-area mungkin dilakukan tanpa kehilangan satu pun pengawal:
analyze/format/test/lisensi/audit aset tetap jalan pada perubahan client,
test Worker berita pada perubahan `news/`, test JWT/OTP/rate-limit + gofmt
pada perubahan `cloudflare/` atau `signaling/`.

## Verifikasi izin push (verify-push-auth.yml)

Push langsung ke `main` diawasi. Setiap commit non-merge pada push WAJIB
memuat penanda `Izin: <ID-SESI>` di body, dan ID-nya harus berstatus
`DISETUJUI` pada `AGENT_BOARD.md`. Pengecualian: commit merge (tindakan
operator) dan commit yang ditulis operator (`OPERATOR_LOGIN` di repository
variables — set mis. `xykalnotkel` kalau operator ingin push bebas).

Tanpa pengaturan tambahan, workflow ini berfungsi sebagai **audit**:
pelanggaran tampil merah di tab Actions. Agar menjadi **gerbang keras**
(push tanpa izin ditolak), perlu salah satu:

1. branch protection `main` → *Require status checks* → wajibkan
   `Periksa izin push`; atau
2. wajibkan PR (tidak ada push langsung) — persetujuan adalah review
   operator + merge-nya. Commit feature branch tetap diperiksa: tulis
   `Izin: <ID>` di body commit (biasa) atau — untuk squash merge — di
   deskripsi/isi PR, karena squash memakai isi PR sebagai body commit.
   Merge commit sendiri (tindakan operator) dikecualikan.



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
`https://app.xystudio.my.id`; API, autentikasi, dan signaling tetap terpisah di
`https://signal.xystudio.my.id`.

Konfigurasi publik berada di `web_deploy/wrangler.toml`. Deployment membutuhkan
GitHub Actions Secrets `CLOUDFLARE_ACCOUNT_ID` dan `CLOUDFLARE_API_TOKEN`.
Artefak Web tidak boleh di-commit ke repository.

## Menerbitkan GitHub Release

Versi aplikasi adalah satu-satunya pemicu rilis. Naikkan nilai `version` di
`pubspec.yaml` dengan format SemVer + Android build, misalnya `1.1.0+3`, lalu
push commit tersebut ke `main`. Workflow Build berjalan lebih dahulu. Setelah
seluruh analisis dan build sukses, workflow Release otomatis:

1. memastikan tag `v<versi>` belum ada (tag menandai versi yang sudah dirilis);
2. memastikan Build sukses berasal dari commit yang sama;
3. memakai APK, Windows client, dan Web dari Build yang sudah lulus;
4. membangun host Rust Windows dari commit yang sama;
5. menerbitkan aset stabil, checksum, dan `update.json`;
6. mengirim OneSignal ke Android dengan `app_version` lebih kecil dari build
   baru.

Push biasa tanpa perubahan nilai versi tidak membuat Release. Trigger manual
hanya disediakan untuk pemulihan jika run otomatis perlu dijalankan ulang.

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

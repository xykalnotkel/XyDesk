# CI/CD — XyDesk

Build dan rilis dijalankan melalui GitHub Actions agar perangkat pengguna tidak
perlu menjalankan Flutter, Android SDK, Rust, atau Visual Studio secara lokal.

## Workflow

| Berkas | Pemicu | Hasil |
|---|---|---|
| `.github/workflows/build.yml` | push/PR ke `main`, manual | APK Android, aplikasi Flutter Windows, bundle Web |
| `.github/workflows/build-host.yml` | perubahan `host/**`, manual | `xydesk-host.exe` |
| `.github/workflows/deploy-signaling.yml` | perubahan `cloudflare/**`, manual | deploy Cloudflare Worker API/signaling |
| `.github/workflows/deploy-web.yml` | Build `main` sukses, manual recovery | deploy bundle Flutter Web terverifikasi ke Cloudflare Static Assets |
| `.github/workflows/release.yml` | Build `main` sukses + nilai `version` berubah, manual recovery | GitHub Release multi-platform + push OneSignal |

Sesuai keputusan proyek, repositori tidak memiliki suite test otomatis. CI tetap
menjalankan format, analisis statis, dan build agar artefak yang diterbitkan
berasal dari source yang dapat dikompilasi. Pengujian perilaku dilakukan manual
setelah APK/EXE dipasang.

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

- `XyDesk.apk` — client Android universal ARM;
- `XyDesk-Host.exe` — host Windows;
- `XyDesk-Windows.zip` — client Flutter Windows;
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

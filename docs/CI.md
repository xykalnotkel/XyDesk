# CI/CD — XyDesk

Build dan rilis dijalankan melalui GitHub Actions agar perangkat pengguna tidak
perlu menjalankan Flutter, Android SDK, Rust, atau Visual Studio secara lokal.

## Workflow

| Berkas | Pemicu | Hasil |
|---|---|---|
| `.github/workflows/build.yml` | push/PR ke `main`, manual | APK Android, aplikasi Flutter Windows, bundle Web |
| `.github/workflows/build-host.yml` | perubahan `host/**`, manual | `xydesk-host.exe` |
| `.github/workflows/deploy-signaling.yml` | perubahan `cloudflare/**`, manual | deploy Cloudflare Worker |
| `.github/workflows/release.yml` | tag `v*`, manual | GitHub Release multi-platform |

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

## Menerbitkan GitHub Release

Versi aplikasi saat ini mengikuti `pubspec.yaml`. Buat dan push tag versi dari
commit yang ingin diterbitkan:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Workflow Release membangun dan melampirkan:

- `XyDesk.apk` — client Android universal ARM;
- `XyDesk-Host.exe` — host Windows;
- `XyDesk-Web.zip` — client Web;
- `SHA256SUMS.txt` — checksum unduhan.

Rilis hanya terbit jika seluruh job build berhasil. Jika salah satu job gagal,
job `Terbitkan Release` akan dilewati dan halaman Releases tetap kosong.

## Signing Android

Secrets berikut harus tersedia di **Settings → Secrets and variables →
Actions**:

- `KEYSTORE_BASE64`
- `KEYSTORE_PASSWORD`
- `KEY_ALIAS`
- `KEY_PASSWORD`

Keystore dan `android/key.properties` tidak boleh di-commit. Workflow membuatnya
sementara di runner dan menghapus runner setelah job selesai.

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

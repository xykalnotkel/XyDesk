# CI/CD — XyDesk

Build dan rilis otomatis lewat GitHub Actions. Tidak perlu Android Studio,
Xcode, atau Visual Studio di komputer kamu — semua dikerjakan runner GitHub.

---

## 1. Alur Kerja

| Berkas | Pemicu | Hasil |
|---|---|---|
| `.github/workflows/build.yml` | push & PR ke `main` | APK universal + Windows ZIP |
| `.github/workflows/release.yml` | tag `v*` | GitHub Release + checksum |

### build.yml

```
check ──┬─→ android   (XyDesk.apk — universal)
        └─→ windows   (XyDesk-Windows-x64.zip — portable)
              ↓
           summary
```

Job `check` jalan lebih dulu. Kalau gagal, kedua build dibatalkan — tidak ada
gunanya membangun kode yang tidak lolos analisis.

**Isi `check`:**
1. `dart format --set-exit-if-changed` — format wajib konsisten
2. `flutter analyze --fatal-infos` — bahkan peringatan `info` menggagalkan build
3. `flutter test` — 27 test
4. **Verifikasi aturan seamless** — CI mencari `Divider(` dan
   `scrolledUnderElevation: [1-9]` di `lib/`. Kalau ada, build gagal.

Poin terakhir yang membuat aturan desain benar-benar ditegakkan. Dokumen bisa
diabaikan; CI tidak bisa.

**Kenapa APK universal, bukan split-per-ABI:** split menghasilkan 3 berkas
terpisah dan pengguna harus tahu arsitektur HP-nya. Universal cuma satu berkas
— lebih besar sekitar 8 MB, tapi tinggal kirim dan pasang.

## 2. Cara Memakai

### Pertama kali

```bash
git init
git add .
git commit -m "feat: XyDesk v1.0.0"
git branch -M main
git remote add origin https://github.com/xykalnotkel/XyDesk.git
git push -u origin main
```

Buka tab **Actions** di GitHub — workflow langsung jalan.

### Mengunduh hasil build

Actions → pilih run → gulir ke bawah ke **Artifacts**:

| Artefak | Isi |
|---|---|
| `XyDesk-Android-APK` | `XyDesk.apk` — universal, semua arsitektur |
| `XyDesk-Windows-ZIP` | `XyDesk-Windows-x64.zip` — portable |

Artefak disimpan **30 hari**.

### Membuat rilis

```bash
git tag v1.0.0
git push origin v1.0.0
```

Workflow `release.yml` membangun semua platform, membuat `SHA256SUMS.txt`, dan
menerbitkan GitHub Release dengan catatan rilis otomatis.

---

## 3. Menandatangani Build (produksi)

Build bawaan **belum ditandatangani**. Untuk Play Store dan App Store:

### Android

Buat keystore:
```bash
keytool -genkey -v -keystore xydesk.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias xydesk
base64 -w0 xydesk.jks > keystore.b64
```

Tambahkan secrets di **Settings → Secrets and variables → Actions**:

| Secret | Isi |
|---|---|
| `KEYSTORE_BASE64` | isi `keystore.b64` |
| `KEYSTORE_PASSWORD` | kata sandi keystore |
| `KEY_ALIAS` | `xydesk` |
| `KEY_PASSWORD` | kata sandi kunci |

Sisipkan langkah ini sebelum `flutter build apk`:

```yaml
- name: Siapkan keystore
  run: |
    echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 -d > android/app/xydesk.jks
    cat > android/key.properties <<EOF
    storePassword=${{ secrets.KEYSTORE_PASSWORD }}
    keyPassword=${{ secrets.KEY_PASSWORD }}
    keyAlias=${{ secrets.KEY_ALIAS }}
    storeFile=xydesk.jks
    EOF
```

Lalu di `android/app/build.gradle.kts`, baca `key.properties` pada
`signingConfigs`.

> **Jangan pernah** memasukkan `.jks` atau `key.properties` ke repositori.
> Keduanya sudah masuk `.gitignore`.

### iOS

Perlu akun Apple Developer berbayar. Simpan sebagai secrets:
`BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`, `PROVISIONING_PROFILE_BASE64`,
`KEYCHAIN_PASSWORD`. Cara termudah memakai [fastlane match](https://docs.fastlane.tools/actions/match/).

---

## 4. Biaya Runner

Repositori **XyDesk publik**, jadi menit Actions **gratis tanpa batas**.

Perkiraan durasi per push:

| Job | Runner | Durasi |
|---|---|---|
| `check` | ubuntu | ~3 menit |
| `android` | ubuntu | ~6 menit |
| `windows` | windows | ~8 menit |

Android dan Windows jalan paralel, jadi total sekitar **11 menit** per push.

Yang tetap dibatasi walau repo publik: **penyimpanan artefak** (500 MB gratis).
Karena itu retensi diset 30 hari, dan hanya dua berkas yang diunggah per run.

## 5. Optimasi yang Sudah Dipasang

- **`concurrency`** — push baru membatalkan run lama di branch yang sama.
- **`cache: true`** pada `flutter-action` — menghemat ~2 menit per job.
- **Cache Gradle** — menghemat ~3 menit pada build Android.
- **`fail-fast: false`** pada matrix — kegagalan Windows tidak membatalkan
  Linux dan macOS, jadi kamu melihat semua masalah sekaligus.
- **`timeout-minutes`** — mencegah job menggantung menghabiskan kuota.

---

## 6. Masalah yang Sering Muncul

| Gejala | Penyebab | Solusi |
|---|---|---|
| `dart format` gagal | Format tidak konsisten | Jalankan `dart format lib test` lalu commit |
| `analyze --fatal-infos` gagal | Ada saran `info` | Jalankan `dart fix --apply` |
| Gradle: "Unsupported class file major version" | Java salah versi | Pastikan `setup-java` memakai `17` |
| Build iOS gagal soal signing | Tidak ada sertifikat | Gunakan `--no-codesign` (sudah dipakai) |
| Linux gagal soal GTK | Dependensi kurang | `libgtk-3-dev` sudah ada di workflow |
| Job macOS lambat sekali | Antrean runner macOS | Wajar; batasi hanya untuk rilis |

---

## 7. Menjalankan CI Secara Lokal

Sebelum push, jalankan langkah yang sama:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test --coverage

# verifikasi aturan seamless
grep -rn --include='*.dart' -E '\b(Divider|VerticalDivider)\(' lib/ && echo GAGAL || echo OK
```

Atau pakai [`act`](https://github.com/nektos/act) untuk menjalankan workflow
GitHub Actions di Docker lokal:

```bash
act -j analyze
```

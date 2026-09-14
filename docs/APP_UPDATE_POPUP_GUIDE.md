# Panduan Visual & Arsitektur Popup Pembaruan (App Update Guide)

> **Dokumen ini adalah sumber kebenaran dan panduan resmi pembuatan aset visual serta alur pembaruan aplikasi XyDesk.**
> Disusun agar tim selalu mengingat spesifikasi pembuatan banner pembaruan AI, alur dialog modal, unduhan latar belakang berprogres di notifikasi Android, hingga instalasi langsung di dalam aplikasi (*in-app installation*).

---

## 1. Alur Kerja Pembaruan (Update Flow)

```
[Aplikasi Terbuka]
       │
       ▼
[Cek updateAvailabilityProvider] ──(Metadata update.json dari GitHub Releases)
       │
       ├─► Update Tersedia & Belum Dilihat?
       │         │
       │         ▼
       │   [Munculkan UpdatePopupDialog]
       │   - Banner visual 4:3 3D morphing
       │   - Judul & ringkasan rilis
       │   - Tombol "Perbarui Sekarang" & "Nanti Saja"
       │         │
       │         ▼ (Pengguna Ketuk Gambar / Tombol)
       │   [Buka UpdatePage]
       │         │
       │         ▼ (Pengguna Ketuk "Unduh Update Resmi")
       │   [Android DownloadManager Berjalan di Background]
       │   - Progress bar tampil di status bar / push notification drawer
       │   - Pengguna bisa bebas menutup / meminimize aplikasi
       │         │
       │         ▼ (Unduhan Selesai)
       │   [Verifikasi Integritas Otomatis]
       │   - SHA-256 Checksum cocok
       │   - Signature & ABI match
       │         │
       │         ▼
       │   [Tombol Berubah: "Pasang Update Sekarang"]
       │   - Eksekusi Intent FileProvider / PackageInstaller bawaan Android
```

---

## 2. Standar Desain Visual Banner Pembaruan (AI Generated)

Setiap pembaruan resmi XyDesk menampilkan kartu popup: **banner visual 4:3
di atas + isi terstruktur di bawah** (chip versi, judul, pesan singkat, aksi
"Nanti" / "Perbarui Sekarang") + tombol X melayang di pojok. Desain
"pure image 3:4 tanpa teks UI" dipakai sampai 13 Sep 2026 dan **dipensiunkan
14 Sep 2026 atas umpan balik operator**: popup yang hanya gambar + tombol X
tidak memberi konteks versi maupun jalan aksi yang jelas; aset lamanya
(`update_popup_banner.jpg`) bahkan tidak pernah masuk git sehingga dialog
jatuh ke fallback kosong.

### A. Karakteristik Utama Kartu
1. **Banner atas (rasio 4:3)**: ilustrasi 3D glossy ungu (kanonik:
   `assets/img/update_popup_banner.jpg`), ketuk banner = buka `UpdatePage`.
   Gradien lembut ke warna permukaan kartu di tepi bawahnya.
2. **Isi terstruktur**: chip `v<versi> • build <n>` + chip "Release resmi",
   judul "Pembaruan tersedia", pesan singkat dari manifest, lalu dua aksi
   ("Nanti" menutup, "Perbarui Sekarang" membuka `UpdatePage`).
3. **Tombol X di Pojok**: tombol tutup melayang di pojok kanan atas dengan
   latar transparan gelap dan ikon `LucideIcons.x`.
4. **Gaya Visual banner**: 3D morphing glass violet, monitor menyala,
   panah upgrade kaca, energy trails — tanpa teks tertanam di gambar
   (teks kini hidup di lapisan UI, jadi selalu benar dan terlokalisasi).

### B. Variasi Tema per Rilis
Banner boleh diganti per rilis selama mengikuti palet Quiet Surface
(void gelap + violet #7C3AED/#A78BFA) dan menyisakan ruang gelap di tepi
atas/bawah untuk gradien permukaan. Contoh tema:
- **Gaming & Low-Latency Release**: kartu UI framerate/bitrate melayang.
- **Konektivitas & Network Release**: gelombang frekuensi neon biru-violet.
- **UI & Redesign Release**: formasi kaca morfis lembut palet lavender.

---

## 3. Formula Prompt AI Generator untuk Update Banner

Gunakan template prompt di bawah ini saat men-generate banner pembaruan baru:

```text
A vertical portrait 3:4 aspect ratio futuristic high-end 3D visual update announcement poster, featuring morphing translucent purple glass geometry, floating holographic UI cards, glossy neon violet and deep magenta chrome spheres, smooth motion-blur trails and energy streaks, high-tech glowing particle dust. Bold crystal-clear 3D embossed typography prominently readable stating 'NEW UPDATE AVAILABLE' and 'TAP TO UPDATE NOW' with 'XyDesk Next-Gen Engine'. Studio lighting, clean soft purple-void background, cinematic depth of field, ultra-detailed 8k render, octane render style, vertical composition.
```

**Lokasi Aset di Aplikasi**:
- `assets/img/update_popup_banner.jpg` (didaftarkan otomatis di `pubspec.yaml` di bawah `assets/img/`).

---

## 4. Mekanisme Background Download & Push Notification Progress

- **Service Unduhan**: Menggunakan `AndroidDownloadManager` bawaan sistem operasi Android melalui `MainActivity.kt`.
- **Notifikasi Sistem Otomatis**:
  - `DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED`
  - Menampilkan progress bar unduhan secara *real-time* di panel notifikasi sistem Android.
  - Pengguna dapat menutup aplikasi sepenuhnya tanpa menghentikan atau merusak proses unduhan APK.
- **Verifikasi Keamanan Mandiri**:
  - Begitu selesai, file divalidasi:
    1. Ukuran byte tepat sama dengan manifes `update.json`.
    2. SHA-256 Checksum dihitung dan dicocokkan dengan hash rilis resmi.
    3. ABI native library diverifikasi sesuai arsitektur CPU target (`arm64-v8a` / `armeabi-v7a`).
    4. Sertifikat signing dicocokkan dengan instalasi aplikasi saat ini untuk mencegah tampering.
- **Pemasangan 1-Ketukan**:
  - `AndroidUpdateDownloader.install()` memicu `FileProvider` dan membuka dialog instalasi sistem Android langsung tanpa membuka browser eksternal.

---

## 5. Komponen Kode Utama Terkait

| Berkas | Fungsi |
| :--- | :--- |
| `lib/features/notifications/update_popup_dialog.dart` | Dialog modal visual dengan banner 4:3, glow border, dan tombol CTA. |
| `lib/features/notifications/update_page.dart` | Layar pusat pembaruan dengan log perubahan lengkap dan tombol unduh/pasang `PrimaryButton`. |
| `lib/features/notifications/update_download_service.dart` | Jembatan status unduhan Android ke Flutter (idle, running, verifying, ready). |
| `lib/features/notifications/update_repository.dart` | Pengambil manifes resmi dari `https://github.com/xykalnotkel/XyDesk/releases/latest/download/update.json`. |
| `android/app/src/main/kotlin/com/xystudio/xydesk/MainActivity.kt` | Implementasi native Android `DownloadManager`, verifikasi SHA-256, dan `FileProvider`. |

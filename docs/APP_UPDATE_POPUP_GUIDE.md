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

Setiap pembaruan resmi XyDesk menggunakan modal popup visual murni (**Pure Image + Tombol X di Pojok**) dengan orientasi tinggi (**Portrait 3:4**).

### A. Karakteristik Utama Banner
1. **Rasio Aspek & Orientasi**: **Portrait 3:4** (Tinggi/Vertikal, misal $900 \times 1200$ atau $1080 \times 1440$).
2. **Struktur Popup Modal**:
   - **Pure Image**: Modal menampilkan banner visual penuh tanpa kotak teks atau tombol duplikat di bawahnya.
   - **Tipografi 3D di Dalam Gambar**: Teks sudah tertanam langsung di gambar dengan kontras tinggi dan jelas: *"NEW UPDATE AVAILABLE"*, *"TAP TO UPDATE NOW"*, dan logo mark *"X XyDesk Next-Gen Engine"*.
   - **Tombol X di Pojok**: Tombol tutup melayang di pojok kanan atas dengan latar transparan gelap dan ikon `LucideIcons.x`.
   - **Aksi Sentuh**: Mengetuk di area mana saja pada poster gambar langsung memicu haptik dan membuka layar `UpdatePage`.
3. **Gaya Visual**:
   - **3D Morphing Glass Geometry**: Bentuk kristal/kaca violet transparan organik yang membiaskan cahaya secara dinamis.
   - **Floating Holographic Cards**: Kartu UI melayang dengan indikator performa dan efek *motion blur*.
   - **Glowing Chrome Spheres**: Bola logam krom reflektif dengan pendaran neon violet dan magenta pekat.
   - **Energy Trails & Particle Dust**: Jejak cahaya orbit berkecepatan tinggi.

### B. Variasi Tema per Rilis
Setiap versi baru dapat mengusung aksen tema unik sesuai fokus rilis:
- **Gaming & Low-Latency Release**: Latar *void* gelap pekat dengan pendaran kristal violet menyala, kartu UI framerate/bitrate, dan bola energi berkecepatan tinggi.
- **Konektivitas & Network Release**: Gelombang frekuensi neon biru-violet, partikel kabel serat optik melayang, dan kartu status transmisi data.
- **UI & Redesign Release**: Formasi kaca morfis lembut, bevel transparan berkilau, dan kartu palet warna lavender yang mengambang elegan.

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

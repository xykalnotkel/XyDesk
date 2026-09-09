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

Setiap pembaruan resmi XyDesk menggunakan banner gambar 4:3 yang digenerate menggunakan AI dengan gaya visual futuristik khas XyDesk.

### A. Karakteristik Utama Banner
1. **Rasio Aspek**: **4:3** (misal $1200 \times 900$ atau $1024 \times 768$).
2. **Gaya Visual**:
   - **3D Morphing Glass**: Bentuk geometri kaca violet/lavender transparan yang melengkung organik.
   - **Floating Elements**: Kartu UI holografik melayang dengan statistik performa, ikon fitur, dan indikator versi.
   - **Motion Blur & Energy Trails**: Jejak partikel berkecepatan tinggi, lingkaran cahaya (*glowing orbital rings*), dan garis energi halus yang memberikan kesan dinamis dan cepat.
   - **Bola Logam / Chrome**: Bola krom reflektif dengan pendaran neon violet dan magenta pekat.
   - **Tipografi Jelas & Tegas**: Teks 3D timbul (*embossed/glowing typography*) bertuliskan *"NEW UPDATE AVAILABLE"* dan *"XyDesk Next-Gen Engine"*.

### B. Variasi Tema per Rilis
Setiap versi baru dapat mengusung aksen tema unik sesuai fokus rilis:
- **Gaming & Low-Latency Release**: Latar *void* gelap pekat dengan pendaran kristal violet menyala, kartu UI framerate/bitrate, dan bola energi berkecepatan tinggi.
- **Konektivitas & Network Release**: Gelombang frekuensi neon biru-violet, partikel kabel serat optik melayang, dan kartu status transmisi data.
- **UI & Redesign Release**: Formasi kaca morfis lembut, bevel transparan berkilau, dan kartu palet warna lavender yang mengambang elegan.

---

## 3. Formula Prompt AI Generator untuk Update Banner

Gunakan template prompt di bawah ini saat men-generate banner pembaruan baru:

```text
A futuristic high-end 3D visual update announcement banner in 4:3 aspect ratio, featuring morphing translucent purple glass geometry, floating holographic UI cards, glossy neon violet and deep magenta chrome spheres, smooth motion-blur trails and energy streaks, high-tech glowing particle dust. Bold stylish 3D embossed typography centered stating 'NEW UPDATE AVAILABLE' with subtitle 'XyDesk Next-Gen Engine'. Studio lighting, clean soft purple background with dark void contrast, cinematic depth of field, ultra-detailed 8k render, octane render style.
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

# Session UX — batas implementasi dan pengujian

## Permintaan yang diterapkan

- Pairing/negotiating masuk surface sesi dengan loading/cancel/retry, bukan
  tulisan di atas tombol konek. Cancel mencegah callback async menghidupkan
  sesi lama lagi. Error tetap di surface sampai user kembali/mencoba lagi.
- Panah lokal24–96px dan sensitivitas trackpad0,2–4x. Pilihan panah dalam
  video hanya menyembunyikan overlay setelah pengguna melihat kursor Windows;
  bukan menambahkan cursor capture GDI yang belum ada. Temukan panah
  memulihkan overlay lokal. Hotspot/flip tepi mengikuti ukuran baru.
- Mapping keyboard A–Z/angka/F-key/modifier/arrow, mouse3tombol, scroll,
  bisa geser/resize36–120px/add/delete, maksimal24. Layout lokal per orientasi.
  Inspector dapat disembunyikan agar tidak menutupi tombol saat diedit.
  Editor tidak mengirim input, capture/lostcapture/blur/unmount melepas hold;
  HUD+mapping mouse punya ownership terpisah agar tidak saling melepas.
- /history: nama PC, ID, waktu/durasi, hasil sesi, spesifikasi dari metadata
  host, preview JPEG opsional. Tamu localStorage; login endpoint privat
  /auth/session-history pada AuthStore. Tidak ada screenshot otomatis tanpa
  checkbox, defaultfalse/reset per sesi dan perubahan akun. Tidak ada sync
  otomatis riwayat tamu ke akun.
- Server memvalidasi JWT+account id, revalidasi dalam transaction, menyimpan
  hanya allowlist, max20record, JPEG32KiB/body48KiB, rate40writes/menit/user.
  Body tidak menentukan pemilik. Delete/clear hanya milik akun sendiri.
  Hapus akun membersihkan preview/index/rate dalam transaksi yang sama.
  Riwayat bersifat laporan sesi, BUKAN bukti ownership PC atau status online
  real-time. Tidak dipakai untuk otorisasi pairing atau pencarian ID global.
- Save server memakai keepalive. Jika jaringan/login gagal, tampil error;
  tidak fallback diam-diam menulis data akun ke storage tamu. Belum ada antrean
  offline akun persisten; penutupan browser mendadak bukan jaminan final record.

## Bukti yang dijalankan

- Web51tests + TypeScript/Vite; Worker155tests.
- Runtime Cloudflare/workerd SQLite: auth/admin regression lama PASS;
 21save bersamaan mempertahankan20record unik, delete akun bersaing dengan
 write tertunda meninggalkan0key riwayat. Fixture seed hanya ditambahkan
 ke bundle in-memory test, tidak masuk source deploy.
- Chromium actual React + CDP touch390x844/844x390, transport stub/canvas:
  loading/cancel-no-resurrection, cursor resize72px, mapping drag/resize84px/
  save, gesture/fullscreen, audio-play retry/mute, saved prefs, guest history
  dengan preview+hostname+halaman. Bukan host Windows atau Android fisik.

## Belum selesai — jangan dipromosikan seolah sudah didukung

- Selektor720p/1080p/Asli belum diaktifkan. Software encoder dan track SDP
  masih Level3.1, max1280x720.1080p memerlukan batas macroblock/level lebih
  tinggi;2336x1080 sumber pengguna memerlukan pengujian lebih lanjut. Turun
  FPS tidak mengatasi batas ukuran per-frame Level3.1. Harus negosiasi kedua
  sisi, ACK ukuran efektif dan fallback jika decoder tidak menerima.
-120fps, refresh-resume tiket aman, adaptive bitrate dan ACK setting encoder
  masih dari antrean sebelumnya, belum dikerjakan di perubahan UI ini.
- Audio/mic: kontrol web tersedia dan diuji sintetik; output/input nyata pada
  RDP belum terbukti. Audit menemukan Session::receive_mic berhenti menunggu
  track setelah~30detik; mic yang diaktifkan belakangan perlu perbaikan host
  dan pengujian. Tidak memasang driver/virtual mic atau mengubah RDP.
- Native cursor belum ditelemetri/digambar untuk GDI; overlay lokal bukan
  posisi/bentuk aktual kursor yang digerakkan dari aplikasi RDP lain.

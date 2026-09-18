XyDesk Host Test — installer NSIS Windows x64

Engine uji 6.8.5 dengan perbaikan audio, antrean keyboard/mouse, serta
permintaan otomatis desktop16:9. Bukan aplikasi desktop lengkap atau rilis
bertanda tangan. Source SHA dan checksum ada di manifest.json;
installer-source.json mengikat installer ke engine yang dibangun/diuji.

PASANG DAN MULAI
Jika host uji sebelumnya masih berjalan, putuskan sesi web lalu tekan Ctrl+C
di konsol XyDesk Host Test milik Anda. Jangan putuskan RDP untuk langkah ini.
1. Jalankan installer. Untuk instalasi baru pilih folder kosong; untuk versi
   uji sebelumnya gunakan lokasi yang sama. Identitas uji dipertahankan.
2. Buka shortcut "XyDesk Host Test" di Desktop atau Start Menu.
3. Gunakan https://app.xydesk.my.id dan ID/password dari konsol host.
   Jangan membagikan password, token, file identitas, atau screenshot konsol.
4. Uji suara PC, keyboard, pointer/klik di tengah dan empat sudut, serta
   pelepasan tombol ketika sesi ditutup. Jaga sesi Windows tetap aktif.

Shortcut membuka konsol PowerShell; ini memang antarmuka engine uji.
RemoteSigned berlaku hanya pada proses launcher dan tunduk pada Group Policy.
Installer tidak menjalankan host otomatis atau mengubah execution policy mesin.
Ctrl+C menghentikan host. Launcher memakai identitas uji terpisah di
%LOCALAPPDATA%\XyDesk-RemoteCore-Test, bukan identitas instalasi produk lama.

DESKTOP16:9 — PERUBAHAN PERILAKU
Saat sesi yang terotorisasi dimulai, host meminta1920x1080 atau1280x720 sesuai
kemampuan H264 yang dinegosiasikan. Hanya mode terdaftar yang lolos CDS_TEST
Windows yang digunakan. Posisi monitor/scaling tidak diubah. Hasil dibaca
kembali; Windows/RDP dapat menolak atau kemudian menerapkan ulang resolusinya.
Tidak ada restart/reconnect RDP, instalasi driver, atau penyimpanan mode ke
registry. Host tidak otomatis mengembalikan resolusi sebelumnya saat berhenti.

Untuk TIDAK meminta perubahan resolusi, buka PowerShell di folder instalasi:
  .\Start-TestHost.ps1 -KeepDesktopResolution
Engine langsung menyediakan flag --keep-desktop-resolution.

Panel Gambar web menampilkan desktop diminta, ukuran terbaca, serta hasil
permintaan. Ukuran gambar hasil decode dilaporkan terpisah. Jika perubahan
ditolak, sumber tetap mengikuti Windows/RDP; konten dijaga proporsional dalam
canvas720p/1080p. Desktop16:9 tidak bisa memenuhi seluruh viewport HP bukan16:9
sekaligus mempertahankan seluruh gambar tanpa crop atau distorsi.

SUARA PC DAN MIC HP
Suara PC direkam dari output default Windows melalui WASAPI loopback.
Di web, aktifkan Suara PC dan izinkan pemutaran bila browser menahannya.
Format perangkat44.1/48/96kHz dinormalisasi ke Opus48kHz dengan paket20ms.

Mic HP -> aplikasi Windows memerlukan virtual audio cable yang dipasang dan
disetujui sendiri oleh pengguna. Contoh: https://vb-audio.com/Cable/
Pilih recording endpoint-nya (misalnya CABLE Output) di Discord/Zoom/game.
Host merender mic ke pasangan render endpoint (misalnya CABLE Input).
Tanpa endpoint virtual, web menjelaskan input mic belum tersedia; tidak
memainkan mic HP melalui speaker sebagai pengganti. Tidak ada driver dibundel
atau dipasang otomatis. Izin mic browser tetap diperlukan.

KINERJA, KONTROL, DAN PREVIEW
Antrean injeksi penuh tidak lagi menghentikan penerimaan input. Posisi absolut
berurutan digabung, tetapi urutan tombol/klik/lepas dan delta relatif dijaga.
Ini bukan janji zero-lag. CPU/GPU, encode, jaringan, buffer dan decode tetap
menentukan kecepatan. Panel web memisahkan RTT, decode/frame, buffer video,
serta antrean input lokal. Aplikasi elevated/UAC dapat menolak injeksi.

Preview wallpaper HD otomatis saat diizinkan dan dapat dinonaktifkan. Hanya
wallpaper lokal, bukan aplikasi, ikon, atau taskbar. Tidak ada auto-minimize.
Jika sumber tidak tersedia, host tidak menggantinya dengan screenshot desktop.

UNINSTALL DAN BATAS
Gunakan Settings > Apps atau Start Menu > XyDesk Host Test > Uninstall.
Hentikan host sendiri dahulu. Uninstaller tidak membunuh proses dan menjaga
identitas uji serta file pribadi tambahan dalam folder instalasi.
Tidak ada service, autostart, firewall rule, atau konfigurasi RDP yang dipasang.
Installer tidak memperbarui APK/web/server; web diperbarui terpisah.

Installer/engine belum ditandatangani Authenticode. Verifikasi SHA-256 dan asal
paket; jangan menonaktifkan keamanan Windows secara global. Bila diblokir oleh
kebijakan mesin, gunakan proses persetujuan administrator yang berlaku.
Build, tes unit, roundtrip codec, dan uji installer bukan bukti suara, injeksi,
resolusi atau latensi pada RDP fisik Anda. Paket ini belum diuji pada PC Anda.

Lisensi: LICENSE-XyDesk.txt, THIRD-PARTY-LICENSES.md, dan folder licenses.

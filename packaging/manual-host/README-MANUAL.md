# XyDesk — paket uji host Windows x64

Ini **engine untuk uji manual**, bukan installer/rilis baru. Versi produk tidak
dinaikkan. Commit sumber dan SHA-256 executable tercatat di `manifest.json`.
Tidak ada RDP/Tailscale atau driver yang dibundel. Tidak ada penggantian host
lama, instalasi service, atau penyalinan otomatis ke Program Files.

## Mulai

1. Ekstrak seluruh ZIP ke folder baru pada VM Windows x64 milik Anda.
2. Masuk ke desktop RDP sebagai pengguna sendiri (`xydesk` pada workflow lab
   repo), bukan mengambil alih akun proses runner. Biarkan RDP terbuka.
3. Buka PowerShell di folder paket. Periksa integritas terlebih dahulu:

   ```powershell
   .\Start-TestHost.ps1 -CheckOnly
   ```

4. Jalankan secara manual:

   ```powershell
   .\Start-TestHost.ps1
   ```

   Jika kebijakan Windows memblokir skrip, jangan menonaktifkan perlindungan
   mesin secara global. Verifikasi asal ZIP/checksum dan minta administrator
   menyetujui eksekusi skrip ini sesuai kebijakan mesin. Paket uji tidak
   memiliki tanda tangan Authenticode.

Launcher mendaftarkan perangkat uji melalui layanan signaling XyDesk yang
sudah ada. ID/password disimpan terpisah di
`%LOCALAPPDATA%\XyDesk-RemoteCore-Test`, bukan konfigurasi instalasi lama.
Konsol menampilkan ID/password pairing; **jangan bagikan konsol lengkap,
transcript, token, atau file identitas**. Ctrl+C menghentikan host uji.
Menjalankan launcher lagi mempertahankan identitas uji dan meminta token baru.
Tidak ada restart otomatis oleh launcher.

Jangan gunakan dua engine sekaligus sebagai pembanding capture awal. Jika ada
host lama, pemilik sendiri yang memutuskan kapan menghentikannya; paket ini
tidak membunuh proses tersebut. Engine tetap memiliki mekanisme virtual display
produk yang sudah ada, sehingga driver yang sebelumnya terpasang pada VM dapat
ikut dipakai/diperiksa saat streaming. Jangan memasang atau merestart driver
secara spekulatif ketika akses RDP penting.

## Urutan pembuktian manual

1. Buka Notepad di RDP; tulis `XYDESK CAPTURE TEST` dan gerakkan jendelanya.
2. Hubungkan client web/APK dengan ID/password **host uji**, bukan host lama.
3. Pastikan isi Notepad dan pergerakan jendela benar-benar terlihat.
4. Dari client, gerakkan pointer, klik Notepad, ketik `input-dari-client`,
   kemudian coba Backspace, Enter, dan scroll. Ini bukti SendInput nyata;
   status connected atau statistik bitrate saja tidak cukup.
5. Putuskan dari client, lalu pairing ulang tiga kali. Pastikan host tidak
   menetap pada status sibuk dan tidak meninggalkan sesi lama.
6. Pertahankan sesi 30 menit; amati freeze, CPU, memory, frame, dan audio.
7. **Baru setelah langkah 1–6 berhasil**, uji RDP disconnect/lock secara
   terpisah. Jangan menjalankan `tscon`, mengganti driver, atau memindahkan sesi
   hanya karena petunjuk lama menyebutnya; tindakan itu dapat mengubah desktop
   yang ditangkap atau memutus akses. Virtual display bukan jaminan bisa
   menangkap secure desktop/layar terkunci.

## Bila layar hitam

Jalankan pemeriksaan ini di desktop RDP yang sama (bukan step Actions headless):

```powershell
.\xydesk-host.exe --capture-test
```

Kirim **hanya** hasil backend capture dan jumlah frame, versi/commit paket,
client yang dipakai, serta apakah RDP saat itu terbuka/terputus/terkunci.
Perintah ini tidak memulai signaling dan tidak mencetak password pairing.
Hasil `dxgi` gagal tetapi `gdi` menghasilkan frame bukan kegagalan WebRTC;
itu membedakan masalah capture dari masalah transport/decode.

Uji pertama tidak mengukur NVENC/1080p60 atau latency PC fisik. VM runner dapat
memakai encoder software dan adapter virtual. Lakukan uji Internet/TURN terpisah
setelah uji dasar berhasil.

## Batas paket ini

Paket engine tidak men-deploy perubahan Worker/web. Backend/panel produksi dan
APK yang terpasang tetap versinya masing-masing. Perbaikan Hub terbaru hanya
berlaku setelah rollout backend yang disetujui; jangan menyatakan seluruh
kontrol admin baru telah terpasang hanya karena executable ini sudah berjalan.
Build/tes compiler dan pemeriksaan executable tidak menggantikan pembuktian
capture, decode, input, audio, atau kestabilan di RDP Anda.

## Lisensi

Lisensi XyDesk ada di `LICENSE-XyDesk.txt`; inventaris komponen di
`THIRD-PARTY-LICENSES.md`. Direktori `licenses/` memuat notice/lisensi source
crate yang tersedia pada build serta libopus yang di-vendor. Paket ini untuk
uji manual pemilik, bukan publikasi rilis baru.

## Resolusi desktop dan mic HP

Saat sesi terotorisasi dimulai, host meminta 1920×1080 (atau 1280×720 untuk
negosiasi H264 terbatas). Hanya mode yang didaftarkan driver dan lolos uji
Windows yang diminta. Ukuran desktop dibaca kembali: penolakan RDP bukan
keberhasilan dan tidak diatasi dengan restart, driver, atau putus sambungan.
Tidak menulis mode ke registry; tidak otomatis mengembalikan mode sebelumnya.
RDP dapat menerapkan ulang resolusinya sendiri.

Untuk mempertahankan resolusi desktop: `.\Start-TestHost.ps1 -KeepDesktopResolution`.
Desktop 16:9 tetap bisa memiliki ruang kosong pada viewport HP bukan16:9 jika
seluruh gambar ditampilkan tanpa crop/distorsi.

Mic HP → aplikasi PC membutuhkan virtual audio cable yang disetujui/dipasang
oleh pengguna, lalu recording endpoint-nya dipilih di aplikasi. Paket ini
tidak memasang driver dan tidak memutar mic HP ke speaker sebagai pengganti.

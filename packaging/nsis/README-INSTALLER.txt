XyDesk Host Test — installer NSIS Windows x64

Paket engine uji 6.8.5; bukan installer aplikasi desktop lengkap.
Paket uji HOSTGEOMETRY: capture/input memakai koordinat monitor fisik,
DPI proses/thread, H264 720p/1080p/asli sesuai negosiasi browser, dan preview
wallpaper Windows HD manual (bukan frame aplikasi). Source SHA engine dan
checksum ada di manifest.json; installer-source.json mengikat paket ini
ke engine yang diuji. Bukan rilis produksi dan belum diuji pada RDP pengguna.
Web/backend harus mendukung protokol baru untuk HD/wallpaper. Installer saja
tidak memperbarui aplikasi web atau server. Tidak ada perubahan resolusi/
scaling Windows, restart RDP, autostart, atau layanan otomatis.

PASANG DAN MULAI
Jika versi uji sebelumnya masih berjalan, putuskan sesi web lalu tekan Ctrl+C
di konsol XyDesk Host Test milik Anda. Jangan tutup/disconnect aplikasi RDP.
Pasang ulang ke lokasi yang sama; identitas uji dipertahankan.
1. Jalankan installer .exe. Pilih folder kosong; default terpisah dari XyDesk lama.
2. Setelah selesai, klik shortcut "XyDesk Host Test" di Desktop atau Start Menu.
3. Setelah host siap, beralih ke Chrome HP tanpa mengakhiri sesi RDP.
   Tidak perlu mempertahankan aplikasi RDP di depan.
4. Masukkan ID/password yang ditampilkan host ke client web/APK.
5. Uji tampilan Notepad, gerakan pointer, klik, ketikan, dan pairing ulang.

Shortcut membuka konsol host melalui PowerShell. Jendela konsol memang
merupakan antarmuka paket engine uji ini, bukan kegagalan installer.
Launcher memakai RemoteSigned hanya pada proses PowerShell tersebut;
tidak mengubah execution policy mesin dan tetap tunduk pada Group Policy.
Host tidak dijalankan otomatis oleh installer. Ctrl+C menghentikan host uji.

IDENTITAS DAN UNINSTALL
Identitas uji ada di %LOCALAPPDATA%\XyDesk-RemoteCore-Test.
Tidak membaca/mengubah identitas instalasi lama. Jangan bagikan password,
token, berkas identitas, atau screenshot konsol lengkap.

Uninstall tersedia di Settings > Apps dan Start Menu > XyDesk Host Test.
Tutup host uji sendiri dahulu. Uninstaller tidak membunuh proses, tidak
menghapus identitas uji, dan tidak menghapus file pribadi tambahan di folder
instalasi. Karena itu folder yang masih berisi file tambahan dapat tetap ada.

Installer tidak memasang service, driver, autostart, firewall rule, atau RDP.
Saat host dijalankan manual, mekanisme capture/driver produk yang sudah ada
tetap berlaku. Jangan mengganti driver atau memakai tscon secara spekulatif.

MEMERIKSA GAMBAR DAN INPUT
Di panel web, pilih 720p/1080p/Asli. Periksa Ukuran gambar dari getStats;
label pilihan adalah batas, bukan jaminan ukuran 16:9 untuk sumber ultrawide.
Sumber2336x1080 akan menjadi1920x888 pada1080p, atau tetap2336x1080 padaAsli
jika browser menyetujui Level5.1. Browser lama dapat dibatasi1280x592.
Jangan mengubah resolusi atau scaling RDP untuk mengikuti pengujian ini.

Bandingkan pointer/klik di tengah dan keempat sudut pada direct dan trackpad.
Uji keyboard dan pelepasan tombol saat putus. Feedback posisi berasal dari
Windows; aplikasi secure desktop/UAC atau privilege lebih tinggi dapat menolak
injeksi. Resize/pergantian monitor punya jeda polling dan jaringan.

Preview wallpaper HD diambil manual setelah memberi consent. Hanya wallpaper
Windows lokal; tidak menangkap aplikasi, ikon atau taskbar. Jika sumber tidak
tersedia/terlalu besar, preview lama tidak diganti. Tidak ada auto-minimize.

Bila hitam, periksa log capture -> kirim, SPS, getStats framesDecoded dan ukuran
video. Angka capture adalah sumber; angka kirim/decoder adalah transport.
Kelancaran aktual mengikuti CPU/GPU dan jaringan VM. Tidak dijanjikan selalu
30fps; mode asli maksimal15fps untuk mengutamakan detail.

BATAS DAN LISENSI
Installer dan engine uji belum ditandatangani Authenticode. Periksa checksum
serta sumber unduhan; jangan menonaktifkan perlindungan mesin secara global.
Installer tidak men-deploy Worker/web atau memperbarui APK.
Build/smoke installer tidak membuktikan capture/input/audio di RDP Anda.

Lisensi XyDesk: LICENSE-XyDesk.txt. Komponen: THIRD-PARTY-LICENSES.md
serta folder licenses. Informasi sumber: manifest.json dan installer-source.json.

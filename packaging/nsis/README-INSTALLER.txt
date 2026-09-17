XyDesk Host Test — installer NSIS Windows x64

Paket engine uji 6.8.5; bukan installer aplikasi desktop lengkap.
Engine MSVC eea2aca memilih GDI secara nyata untuk sesi RDP.
Perbaikan penantian capture dari 9887131 tetap disertakan.
Tes regresi WebRTC lulus; tampilan RDP/Android tetap perlu diuji manual.

PASANG DAN MULAI
Jika versi uji sebelumnya masih berjalan, putuskan sesi web lalu tekan Ctrl+C
di konsol XyDesk Host Test milik Anda. Jangan tutup/disconnect aplikasi RDP.
Pasang ulang ke lokasi yang sama; identitas uji dipertahankan.
1. Jalankan installer .exe. Pilih folder kosong; default terpisah dari XyDesk lama.
2. Setelah selesai, klik shortcut "XyDesk Host Test" di Desktop atau Start Menu.
3. Biarkan RDP terbuka dan desktop tidak terkunci untuk tes pertama.
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

BILA LAYAR HITAM
Setelah pairing, periksa apakah "capture gdi-bitblt mulai" muncul.
Pada sesi RDP, engine ini tidak mencoba membuat/memasang virtual display. Laporkan hanya pesan video dan jumlah frame; jangan kirim
ID/password/token atau konsol lengkap. Fullscreen web dan audio bukan bagian
dari patch ini.

Buka PowerShell di folder instalasi, jalankan:
  .\xydesk-host.exe --capture-test
Saat probe, tampilkan Notepad putih dan gerakkan jendelanya.
Laporkan hanya baris dxgi/gdi, jumlah frame, dan RGB-nonzero.
Probe membaca piksel lokal tetapi tidak menyimpan screenshot atau membuka
signaling. RGB-nonzero bukan bukti desktop benar atau decoder Android berhasil.
Sebutkan apakah RDP terlihat di perangkat lain atau berada di HP yang sama
dan masuk background ketika Anda berpindah ke Chrome. Jangan ubah driver,
memutus RDP, atau menjalankan tscon hanya berdasarkan log.
Baca juga README-MANUAL.md untuk urutan uji lengkap dan batas pengujian.

BATAS DAN LISENSI
Installer dan engine uji belum ditandatangani Authenticode. Periksa checksum
serta sumber unduhan; jangan menonaktifkan perlindungan mesin secara global.
Installer tidak men-deploy Worker/web atau memperbarui APK.
Build/smoke installer tidak membuktikan capture/input/audio di RDP Anda.

Lisensi XyDesk: LICENSE-XyDesk.txt. Komponen: THIRD-PARTY-LICENSES.md
serta folder licenses. Informasi sumber: manifest.json dan installer-source.json.

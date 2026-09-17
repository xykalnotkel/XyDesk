XyDesk Host Test — installer NSIS Windows x64

Paket engine uji 6.8.5; bukan installer aplikasi desktop lengkap.
Engine sama dengan paket MSVC c5feae3 yang sebelumnya sudah diuji.

PASANG DAN MULAI
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
Buka PowerShell di folder instalasi, jalankan:
  .\xydesk-host.exe --capture-test
Laporkan hasil backend/jumlah frame, keadaan RDP, dan client yang dipakai.
Baca juga README-MANUAL.md untuk urutan uji lengkap dan batas pengujian.

BATAS DAN LISENSI
Installer dan engine uji belum ditandatangani Authenticode. Periksa checksum
serta sumber unduhan; jangan menonaktifkan perlindungan mesin secara global.
Installer tidak men-deploy Worker/web atau memperbarui APK.
Build/smoke installer tidak membuktikan capture/input/audio di RDP Anda.

Lisensi XyDesk: LICENSE-XyDesk.txt. Komponen: THIRD-PARTY-LICENSES.md
serta folder licenses. Informasi sumber: manifest.json dan installer-source.json.

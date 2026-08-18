Driver Display Virtual (VDD) untuk XyDesk
========================================

Driver ini BUNDLING OPTIONAL dari installer XyDesk. Lisensi: MIT (ge9).
Source: https://github.com/ge9/IddSampleDriver

KAPAN DIPAKAI:
- PC tanpa monitor fisik (server, VPS, headless workstation)
- Mesin yang GPU-nya tidak aktif karena Windows deteksi vendor 0x1414
  (Microsoft Basic Render Driver)
- Butuh FPS optimal untuk screen streaming

KAPAN TIDAK PERLU:
- PC dengan monitor fisik aktif
- GPU aktif dan Windows mengenali adapter non-Microsoft
- Hanya butuh akses remote desktop biasa

CARA PASANG ULANG MANUAL:
1. Buka Device Manager (devmgmt.msc)
2. Action > Add Legacy Hardware > Install manually
3. Pilih IddSampleDriver.inf dari folder ini
4. Restart PC atau restart Display service:
   powershell Restart-Service -Name TermService -Force

CARA HAPUS MANUAL:
1. Device Manager > Display adapters > "XyDesk Virtual Display"
2. Right-click > Uninstall device > check "Delete driver software"
3. Restart

TROUBLESHOOTING:
- Device Manager Code 52 = driver belum ditandatangani trusted.
  Solusi: pastikan sertifikat ge9 sudah di Trusted Root (install.bat
  langkah 1).
- Monitor tidak muncul di Display Settings = install gagal. Cek
  Application log Event Viewer untuk IDD errors.

ALTERNATIF HARDWARE (lebih sederhana):
Beli HDMI dummy plug ($5-10 di Amazon). Plug ke port HDMI. Windows
auto-detect monitor virtual tanpa perlu driver signature drama.

Untuk dokumentasi lengkap XyDesk:
https://github.com/xykalnotkel/XyDesk

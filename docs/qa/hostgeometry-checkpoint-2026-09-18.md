# HOSTGEOMETRY — gerbang lokal selesai; build Windows berikutnya

Base 244c52250e43a25b5d8a7c47832181e90df350c5. Operator - XyDesk Team.
Arahan terakhir: **lanjut kerjakan semua sampai selesai dulu baru build**.
Tidak ada deploy, bump versi, restart RDP/VM, perubahan scaling/resolusi Windows atau secret/OAuth.

## Perbaikan sumber
- DPI per-monitor proses/thread; input absolut pada rect fisik monitor backend yang benar-benar dibuka, termasuk origin negatif. GDI dimensi fisik+origin fallback+resize polling500ms. WGC pemilihan device-name (API from_index sebelumnya one-based), geometri baru aktif setelah frame sukses, perubahan geometri meminta reopen. DXGI output berotasi ditolak untuk fallback yang orientasinya benar.
- GetCursorInfo feedback20Hz; overlay mengikuti feedback tanpa menginjeksikan gerakan. WGC cursor embedded tidak digambar dua kali. Keyboard extended scancode diperbaiki, Pause memakai VK. Input downs dilacak dan dilepas saat channel tutup; antrean dibatasi, pesan gagal tidak mencetak teks yang diketik.
- Codec H264 dinegosiasi lewat kemampuan receiver; software output720p/1080p/native dibatasi Level3.1/4.0/5.1. Tidak upscale/stretch/crop. Native maksimal4096×2160/15fps, lain30fps, software≤14Mbps. NVENC hanya dipakai jika sumber sudah memenuhi ukuran terpilih; level/fps/VBV mengikuti batas. Telemetri encoder dan decoded dimensions terpisah.
- Preview manual Windows-configured wallpaper, tanpa minimize/screenshot aplikasi/ikon/taskbar. Hanya fixed local drive, tolak UNC/device/ADS/relative/reparse. Sumber≤16MiB, decode≤64MiB, output≤1920×1080 tanpa upscale, JPEGquality90..75≤256KiB. Kegagalan mempertahankan gambar lama.
- DC chunk≤16KiB,≤22bagian,request id/rate/timeout; bounded JPEGheader/decoded dimensions. Penyimpanan akun tetap terotorisasi+transaksional; preview≤350000karakter dibagi≤4nilai96K. Delete/retensi/revokasi ikut membersihkan chunk. Body≤384KiB. Guest dedup perID dan quota pruning tidak mengaku menyimpan gambar baru jika gagal. Large fetch tidak keepalive.
- Klik Konek meminta fullscreen di gesture, lalu landscape; penolakan browser ditangani jujur. Tidak memaksa pada retry.
- Workflow NSIS tidak lagi terikat run lama: hanya engine run sukses dari commit yang sama, hash ZIP/manifest/engine diverifikasi. Bukan workflow Build/Release produksi dan tidak membuka RDP lab.

## Bukti lokal
- Host Linux **148 tes** (139unit+5binary+4integration), format dan lockfile lulus.
- Pemeriksa MSVC sempit pada sumber asli geometry/input/GDI/DXGI/NVENC/wallpaper/video_policy lulus. Bukan kompilasi penuh screen.rs/main.rs. Checker Win32 penuh terlalu berat di sandbox; tidak diulang.
- Web **64 tes** dan TypeScript/Vite build lulus.
- Worker **184 tes** lulus; Wrangler dry-run dan runtime SQLite HDchunk roundtrip+21concurrent saves/retensi20+account deletion race lulus.
- NSIS builder **7 tes** lulus, termasuk hash/source mismatch dan paket valid.
- `node tool/gen-licenses.mjs --check` lulus; inventory dibuat generator, bukan edit tangan.
- `hd-chromium-2026-09-18.json`: **Chromium nyata↔Rust Session/SoftwareEncoder nyata**, SDP/RTP/decode;1920×1080,2336×1080,1280×720 masing-masing≥3framesDecoded. Gambar sintetis, bukan desktop Windows. H264answer42e033.
- `hostgeometry-ui-2026-09-18.json`: React/Chromium390×844+844×390, DC wallpaper chunk fixture1920×1080 independen dari video1280×592; saved history, controls, cancel/release/chords, fullscreen gesture, cursor feedback tanpa injeksi lulus, nolpageerror. Transport UI fixture, bukan Windows/Android runtime.

## Batas yang tetap jujur
- Belum ada bukti manual pada VM RDP pengguna/Chrome Android. Tidak boleh menyatakan pointer presisi runtime hanya dari pemetaan/unit/Chromium sintetis.
- Resize/pergantian monitor punya polling500ms dan beda latency video/DC. Belum ada epoch/ACK yang mengikat tiap frame decoded dengan monitor. Secure desktop/UAC, privilege, cursor clipping dan game raw-input tetap pembatas OS.
- Wallpaper-only tidak mencakup ikon/taskbar. Wallpaper tidak tersedia/terlalu besar/terlalu rinci tidak diganti diam-diam dengan screenshot atau preview buram.
- Landscape lock tergantung browser, OS dan fullscreen; request bukan jaminan rotasi fisik.
- Native dibatasi4096×2160 dan tidak menjanjikan FPS tetap. Source2336×1080 pada1080p→1920×888; padaNative+Level5.1 tetap2336×1080.
- Build lokal web tidak dipakai untuk produksi: konfigurasi OAuth produksi harus dipertahankan saat rollout berizin terpisah.
- Installer baru saja tidak memperbarui web/backend live. Produksi tetap paket CONTROLREPAIR sampai ada persetujuan deploy tersendiri.

Mode executable tool/check_backend_live.py berasal dari pekerjaan sebelumnya dan tidak termasuk commit ini.

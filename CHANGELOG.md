# Changelog XyDesk

Semua perubahan penting XyDesk dicatat di sini.
Format mengikuti [Keep a Changelog](https://keepachangelog.com/id/1.1.0/),
versi mengikuti [Semantic Versioning](https://semver.org/lang/id/).

> **Kebijakan baru 2026-09-07 (Founder Lock):** Changelog tidak digabung numpuk
> di satu file lagi. Setiap versi punya file sendiri di `changelogs/` — biar ga
> numpuk dan mudah dibaca. File ini hanya ringkasan + index. Detail lengkap ada
> di file per versi. Lihat `changelogs/README.md`.

Kebijakan rilis:
- Setiap update aplikasi **wajib menaikkan versi** (`pubspec.yaml X.Y.Z+NN`,
  `web`/`desktop` package.json, `host` Cargo.toml).
- Setiap rilis **wajib punya artikel Berita** dengan changelog yang jelas dan
  panjang (lihat `news/README.md` untuk alur penerbitan).
- **Berita dan changelog adalah dua hal berbeda.** File ini untuk tim dan
  untuk catatan GitHub Release. Berita di `news.xydesk.my.id` ditulis untuk
  pengguna: tanpa nama berkas, tanpa nomor versi di judul, tanpa daftar
  commit. Panduan lengkap nadanya ada di [`docs/NEWS_STYLE.md`](docs/NEWS_STYLE.md).
- File ini otomatis dilampirkan ke GitHub Release oleh `release.yml`.
- **Banner artikel wajib 3D glossy morphing + floating motion blur** —
  lihat `docs/NEWS_STYLE.md` §11.

## [Belum terbit]

- **UXFINISH:** scoped member/guest remembered history with automatic resume; automatic wallpaper without opt-in/manual capture panel; WebP hero; border/name mouse/key controls with automatic chord labels and size/radius; pointer-down keyboard; adaptive bitrate presets and capability-gated30/60FPS through real encoder policy; bundled pinned VDD with explicit administrator setup preserving existing devices/configuration and no reboot/RDP changes. Validation and exact package revision recorded separately; no claim of zero lag or user-machine validation.

- **Console/guest repair (Windows35421194650 + NSIS35421544833 SUCCESS):** suppressed native pointer composition + real mouse events; managed host ticket refresh/heartbeat and console process-tree supervision; no guest duration cap; short connection tickets with remembered, host-revocable browser grants. Sourcece95f51; Linux176/Windows165, web84/backend188, PS5/PS7 kill-on-close PASS. Web/backend deployed; user verified real console720 with previous build, new cursor/reconnect still requires field verification. No RDP/driver/security-policy changes. `docs/qa/console-guest-2026-09-19.md`.

- **VDD3010 hotfix (Windows35412599966 SUCCESS; PS5/PS7 masing-masing35 assertions, WhatIf dan catalog trust PASS):**3010 adalah sukses-butuh-reboot, bukan penolakan. Jangan rollback device accepted0/3010; simpan pending state, jangan ulang install pada boot yang sama. Resume opt-in memvalidasi ownership, pinned driver bytes, config dan existing hardware ID sebelum meneruskan setup lama. Tanpa reboot/service/RDP restart otomatis. Bug lama menghapus device setelah3010 pada laporan pengguna; visibleVirtual kosong sesudah cleanup bukan bukti session isolation.

- **VDISPLAY720 closure:** source691dd09, Windows35408521780 **SUCCESS Linux168/Windows157**; setup/native helper WhatIf + real pinned archive/Windows catalog trust PASS. NSIS35408977237 **SUCCESS** termasuk shortcut Virtual720. Belum driver install/virtual capture di runner atau RDP pengguna; integration candidate, bukan bukti lock mutlak. Tidak deploy web/backend. `docs/qa/virtual720-package-2026-09-18.json`.

- **Virtual720 — paket uji siap:** profil opt-in1280×720 dengan adapter identity + current-session monitor verification, canvas720 terkunci, monitor lain/fallbackRDP ditolak. Discovery lama tidak lagi menebak dari resolusi/file, install/service restart/manager command tebakan dihapus. Setup eksplisit memakai driver resmi terpinSHA dan Windows catalog trust, tanpa security bypass/reboot/tscon; driver console belum tentu terlihat dari RDP. Tidak mengklaim field proof atau session-isolation bypass.

- **HOST-FINISH closure:** final source56317a2 (runtime43fc35c), Windows run35403913522 **SUCCESS: Linux164/Windows153** termasuk real-Opus roundtrip; NSIS35404435326 **SUCCESS** install/reinstall/uninstall. Installer baru SHA256704f2adda398d034042fa22648fd07e110359a333a757c30826405b01e5f91fd. Web76/browser2viewport + live asset/OAuth/bindings PASS, versi1d669576; backend55cdda7c tetap. Petunjuk installer diperbaiki dan paket43fc35c disupersede. Tidak version bump/official release/driver/RDP access. Bukti `docs/qa/host-finish-{package,production}-2026-09-18.json`; batas field-test di `host-finish-2026-09-18.md`.

- **Host finish — siap installer + web live:** permintaan otomatis mode desktop16:9 pada sesi terotorisasi, hanya mode terdaftar + CDS_TEST, baca ukuran kembali dan status penolakan/override. Tidak registry/driver/restart RDP; opt-out launcher -KeepDesktopResolution. Web menampilkan requested/observed, bukan label HD palsu. Tambah Windows real-Opus roundtrip44.1/48/96kHz. Menyertakan patch audio bd75757 dan input ec0f047.

- **Input queue (kode, belum installer):** full queue tidak mematikan input; backpressure async + batal saat disconnect, coalesce posisi absolut berurutan tanpa melewati klik/key-up. Host Linux **161 tests PASS**, format PASS; belum pembuktian latency Windows/RDP. `docs/qa/input-queue-2026-09-18.md`.

- **Audio repair (kode; belum build Windows/deploy):** format WASAPI lengkap + packetizer streaming tepat 960 frame, perbaikan drain/silence dan frame render, mic tanpa expiry 30 detik + queue bounded, web replaceTrack/cancel cleanup, virtual-input requirement tanpa speaker fallback/driver install. Linux **156**, web **76**, format/build web dan Windows ABI checker PASS. Bukti/batas: `docs/qa/audio-repair-2026-09-18.md`. Keluhan input lambat dan otomatis 16:9 belum selesai.

### CONTROL-REFINE — web sudah live
- Mapping transparan border+label, custom picker/search tanpa select browser, tombol tambahan dan shortcut; tap kiri/tahan500ms kanan di dua mode; HUD rounded kiri/kanan/scroll/Windows/switch.
- Riwayat baris wallpaper+nama+chevron, reconnect pairing inline mempertahankan perangkat dan route/history tanpa menyimpan password. Gerak absolut belum terkirim digabung saat antrean penuh; tombol/release tetap berurutan.
- Web70/build/Chromium2viewport+gesture+F1+reconnect/privacy PASS. Tidak mengubah host/RDP atau menyimpulkan sebab delay jaringan; mode desktop16:9 masih perlu detail RDP pengguna. Bukti `docs/qa/control-refine-2026-09-18.md`.
- Deploy web-only diizinkan user: source87427ae, versi Worker740345c3. Hash JS/CSS cocok, HTML cocok tanpa beacon Cloudflare, OAuth/bindings tetap; Chromium produksi portrait/landscape membuktikan kartu horizontal dan pairing inline tanpa mengirim password/pairing. Backend/installer tetap. Bukti `docs/qa/control-refine-production-2026-09-18.json`.

### LETTERBOX-LATENCY — paket uji tervalidasi; web/backend sudah deploy
- Menggantikan interpretasi HD/preview sebelumnya: kanvas tepat1280×720/1920×1080 dengan desktop utuh + pita hitam, pemetaan input padding, cursor Windows di video GDI/DXGI/WGC tanpa panah web pengganti, wallpaper otomatis sekali saat koneksi dengan opt-out/cancellation.
- Gap frame H264 memerlukan IDR baru, antrean lama dibuang, RTP mengikuti timestamp capture; telemetry host encode/queue/write dan web RTT/jitter/buffer/decode/loss dipisah. Wallpaper background dibatasi buffering/pacing/deadline.
- Linux152, web66, Windows release141, NSIS builder7/install-reinstall-uninstall, narrow Windows cross-check dan Chromium real decode3mode/UI2viewport+privacy PASS. Installer baru source37c5eea, Windows35391667677/NSIS35392306102. Bukan bukti runtime RDP/Android atau bebas lag. Versi tetap. Bukti paket `docs/qa/letterbox-package-2026-09-18.json`.
- Rollout produksi diizinkan operator: backend55cdda7c/web8f093d6d. Backend184/web66 dan SQLite runtime PASS; hash JS/CSS sama dengan build, HTML cocok setelah mengabaikan beacon analytics Cloudflare yang sudah ada. OAuth/bindings dipertahankan, auth tanpa login401, React produksi portrait/landscape PASS. RDP/host tidak diubah; login akun dan streaming perangkat nyata belum diuji. Bukti `docs/qa/letterbox-production-2026-09-18.json`.

### Perbaikan dalam validasi — HOSTGEOMETRY
- Host: konteks DPI proses/thread, koordinat fisik monitor capture untuk pointer absolut, pemilihan WGC melalui nama perangkat (bukan indeks nol ke API indeks satu), origin fallback GDI, dan deteksi perubahan geometri GDI/RDP setiap 500 ms.
- Web: klik Konek meminta fullscreen dari gesture lalu mencoba landscape; browser yang menolak mendapat petunjuk manual. Retry otomatis tidak meminta fullscreen.
- H264 menerima batas decoder ternegosiasi Level3.1/4.0/5.1, pilihan720p/1080p/asli dengan aspek utuh tanpa upscale, native maksimal4096×2160/15fps. Chromium nyata sudah mendecode1920×1080 dan2336×1080 dari encoder host melalui RTP sintetis.
- Feedback cursor Windows20Hz, overlay tidak diduplikasi pada WGC; input down yang sukses dilepas saat channel tutup, antrean input dibatasi, tombol Pause tidak salah menjadi Ctrl.
- Preview manual kini wallpaper Windows lokal HD≤1920×1080/256KiB, bukan frame aplikasi; path dan decoder dibatasi. Transfer chunk, validasi JPEG, penyimpanan akun bertransaksi/chunk dan kuota browser diselaraskan tanpa mengubah auth/OAuth.
- NSIS hanya menerima artifact run engine sukses dari SHA yang sama, dengan checksum ZIP/engine; tidak lagi memakai engine lama. Windows137tes dan NSIS install/reinstall/uninstall sudah lulus pada source4a3e75a. Belum deploy; uji RDP pengguna tetap diperlukan. Bukti: `docs/qa/hostgeometry-checkpoint-2026-09-18.md`.

- Kontrol web: preview diambil/ganti manual dan dipakai ulang per ID, riwayat satu kartu per perangkat; keyboard memiliki tombol tutup atas dan melepas modifier. Mapping menambah shortcut kombinasi, F1–F24/numpad/navigasi/tanda baca, mouse samping dan scroll horizontal; ownership keyboard fisik/virtual/mapping disatukan. Preset WASD digital tersedia. HD dan presisi input Windows belum dinyatakan selesai.

- Backend sesi baru: ticket client terikat identitas/generasi akun; WS dan penerbitan TURN memeriksa pencabutan. Alarm Hub memeriksa client diam tiap ~15 detik dan mengirim bye ke host sesuai nonce koneksi. Ticket/koneksi legacy tetap kompatibel; belum ada pemutusan massal atau bukti media Windows.

- Backend: validasi identitas/ban/generasi JWT akun pada profil, riwayat, mutasi akun dan penerbitan token signaling; token legacy sehat tetap berlaku. Login dan perubahan akun transaksional, OTP sekali pakai saat konkurensi; respons auth tidak boleh dicache. Tidak mencabut ticket signaling yang sudah terbit atau otomatis memutus sesi P2P aktif.

- Sesi web: loading di dalam viewport, ukuran panah/sensitivitas, editor mapping keyboard/mouse dengan posisi/ukuran bebas, riwayat tamu lokal dan akun di server dengan preview opt-in. Pemilihan HD dan resume belum tersedia.

- Web sesi: panah lebih besar/tidak terpotong di tepi, tombol Temukan panah, pemulihan layout; audio play/retry dan mute lokal, diagnostik audio, preferensi terkirim setelah channel siap. URL memakai ID acak (belum resume saat refresh).

- Host software: filter bilinear menggantikan nearest-neighbor tanpa mengubah batas H.264 Level3.1. Antrean mouse mempertahankan posisi sebelum klik/drag.

- Kontrol web HP: trackpad default, panah lokal, koordinat gambar tanpa pita hitam, tap/cancel/dua jari dan tahan-geser. Label kualitas menunjukkan target dan batas encoder, bukan janji resolusi/fps.


### Fixed
- H264 software: batasi ukuran kirim ke 1280x720 proporsional, 30fps dan 14Mbps sesuai Level3.1 yang diiklankan, bukan mengirim capture besar dengan SPS Level5.1. Desktop RDP tidak diubah; log membedakan resolusi capture/kirim dan SPS.
- Sesi web memenuhi viewport saat Connected, tidak lagi terkotak 16:9 dalam halaman. Fullscreen native diminta dari tombol untuk seluruh surface beserta kontrol; fallback tetap memenuhi viewport. Toolbar landscape tidak terpotong, scroll halaman dipulihkan saat sesi berakhir.
- Pemutar web: pisahkan track video dari audio, panggil play setelah sesi tampil, sediakan retry melalui gesture, dan laporkan keadaan elemen video. Penghitung decode yang tidak tersedia tidak lagi ditampilkan sebagai nol.
- Video host: baca RTCP sender agar interceptor memproses NACK/retransmisi dan PLI/FIR meminta keyframe (dibatasi 500ms). Statistik web memilih video utama, bukan RTX, serta menampilkan byte/paket/frame/keyframe dan PLI/NACK tanpa pembulatan Mbps.
- Host RDP: benar-benar memilih GDI, bukan hanya mencetak fallback sambil menjalankan DXGI; jalur RDP tidak memanggil pembuatan/pemasangan virtual display. Diagnostik membedakan sampel pojok dari seluruh RGB, dan nol frame tidak lagi menyuruh tscon.
- Host video: penantian frame kini dibatasi agar state Connected dapat menyalakan capture Windows yang belum menghasilkan frame. Koneksi tertutup tetap menghentikan pump saat sumber diam; jadwal penyelamatan IDR tidak dipercepat oleh tick state.
- Launcher host uji memakai SHA-256 .NET agar tidak bergantung pada autoload Get-FileHash di Windows PowerShell; installer NSIS membedakan direktori default dan /D eksplisit tanpa mengabaikan pilihan pengguna.
- Host menutup media dan mencabut izin pairing saat signaling putus; Hub mengaitkan answer dengan nonce socket agar kick/close memberitahu peer terkait, termasuk client yang mengabaikan close.
- Web: cleanup pada fase terminal, antrean SDP/ICE, validasi asal pesan media, UUID client, tipe clipboard biner, track tanpa stream, dan label codec dari statistik yang benar.
- Host LAN-only menerima STUN kosong; lockfile diselaraskan dengan manifest 6.8.5 yang sudah ada; koreksi parser FU-A pada tes loopback.
- Sesi admin setelah aktivasi password memakai cookie HttpOnly host-only, pemeriksaan Origin pada POST, dan pencabutan sesi saat logout; JWT Google lama ditolak setelah migrasi.
- OAuth admin memakai client khusus melalui `ADMIN_GOOGLE_CLIENT_ID`; client web/APK tidak diubah dan tidak menjadi fallback untuk login admin. Konfigurasi publik build admin dipisahkan dari secret.
- Worker: entrypoint runtime hanya mengekspor handler dan kelas Durable Object; konstanta helper untuk tes tidak lagi membuat startup workerd gagal.
- Backend admin: hapus fallback identitas Google palsu dan bypass captcha; pakai verifikasi Google dengan signature helper yang benar, hostname Turnstile, dan sesi admin audience khusus satu jam.
- Maintenance backend: transaksi batch + audit log + pemeriksaan revision; galat storage menjadi 503 dan konflik menjadi 409, tidak sukses palsu. Pembacaan publik tidak mengungkap email pengubah.
- Statistik backend: metrik tanpa sumber menjadi null; kegagalan pembacaan tidak dilaporkan sebagai data kosong/nol.
- Panel: login GIS asli dengan penanganan captcha kedaluwarsa, logout saat 401, simpan maintenance satu request; halaman Backend/Server memakai pemeriksaan RPC nyata. Purge belum tersedia menghasilkan 501.
- Admin: hapus fallback statistik dummy; tampilkan kegagalan API dan perbarui statistik setiap 15 detik setelah tersedia token.
- Dashboard: hapus grafik, tren, latensi, dan status kesehatan statis yang menyerupai hasil pengukuran.
- Maintenance: kontrol dikunci sebelum status dimuat; edit sebagai draft, simpan dalam satu batch, lalu verifikasi baca ulang. Kegagalan meminta muat ulang sebelum mencoba lagi.
- Logs: kegagalan HTTP ditampilkan sebagai galat, bukan daftar kosong yang tampak sukses.

### Added
- Installer NSIS per-user untuk paket engine uji Windows x64: wizard, shortcut Desktop/Start Menu, entri Apps, dan uninstaller berbasis daftar berkas. Folder lain/identitas uji tidak dihapus; tanpa autostart, driver, service, atau deploy.
- Paket uji host Windows x64 terpisah: workflow build-only MSVC, smoke executable, launcher manual dengan verifikasi PE/checksum dan identitas uji terisolasi; tanpa Test Lab, installer, rilis, atau deploy otomatis.
- Harness remote lintas runtime memakai Worker/SQLite, binary host Rust, dan Chromium: pairing, decode/render H264, kontrol bitrate, kick dua arah, reconnect, dan putus manual. Bukti serta batas Windows/TURN di `docs/REMOTE_CORE_QA.md`.
- Setup satu kali username/password + TOTP, kode pemulihan sekali pakai, limiter login, enkripsi seed TOTP, verifier password ber-pepper, dan audit login paralel yang tidak saling menimpa. Google ditutup hanya setelah akun baru terverifikasi; tidak membuat password pemilik otomatis.
- `cloudflare npm run test:runtime`: uji bundle pada runtime SQLite lokal, mencakup transaksi, konflik konkurensi, audit, health, dan pembatasan akses.
- Endpoint admin health read-only untuk Worker/AuthStore/Hub; status engine dinyatakan belum tersedia.
- Panduan konfigurasi dan rollout di `admin/README.md`; total 28 tes backend admin baru dan 3 tes API panel tambahan.
- Dua belas tes regresi API admin memakai Node test runner dan TypeScript yang sudah tersedia.

## [6.8.5] - 2026-09-13

> Build 59. Semua tombol admin nyata — ban/role/revoke/kick/terminate/purge/logs Hibernation+storage, gada dummy.

Lihat detail di [changelogs/6.8.5.md](changelogs/6.8.5.md).

## [6.8.4] - 2026-09-13

> Build 58. Realtime nyata — Hub + AuthStore live, gada dummy placeholder.

Lihat detail di [changelogs/6.8.4.md](changelogs/6.8.4.md).

## [6.8.3] - 2026-09-13

> Build 57. Admin endpoint nyata — Worker `/admin/*` live, login Turnstile + Google, stats/devices/maintenance konek web+apk.

Lihat detail di [changelogs/6.8.3.md](changelogs/6.8.3.md).

## [6.8.2] - 2026-09-13

> Build 56. Rebuild admin — Vite kotak, no rounded, lucide, login Turnstile nyata, konek web+apk.

Lihat detail di [changelogs/6.8.2.md](changelogs/6.8.2.md).

## [6.8.1] - 2026-09-13

> Build 55. Fix E0599 Write import — `use std::io::Write` untuk `writeln!`.

Lihat detail di [changelogs/6.8.1.md](changelogs/6.8.1.md).

## [6.8.0] - 2026-09-13

> Build 54. Super lengkap — Admin dashboard (statistik, maintenance, control user/mesin/hosting/backend/server) + Hero 2D kartun responsif.

Lihat detail di [changelogs/6.8.0.md](changelogs/6.8.0.md).

## [6.7.18] - 2026-09-13

> Build 53. CRITICAL — Fix panic no reactor running, window gagal kebuka. `tokio::spawn` → `tauri::async_runtime::spawn` + `start()` di `setup`.

Lihat detail di [changelogs/6.7.18.md](changelogs/6.7.18.md).

## [6.7.17] - 2026-09-13

> Build 52. Fix Build Desktop writeln — `writeln!` macro, bukan trait. PowerShell quote fix.

Lihat detail di [changelogs/6.7.17.md](changelogs/6.7.17.md).

## [6.7.16] - 2026-09-13

> Build 51. Windows Tauri Debug + License English + Adaptive No Box — window log, license EN, adaptive transparan.

Lihat detail di [changelogs/6.7.16.md](changelogs/6.7.16.md).

## [6.7.15] - 2026-09-13

> Build 50. Tauri Window Fix + Logo Transparan (No White BG) — window pasti show, semua logo transparan identik README.

Lihat detail di [changelogs/6.7.15.md](changelogs/6.7.15.md).

## [6.7.14] - 2026-09-11

> Build 49. Driver Offline Bundle + 1-Klik Auto-Download (No Manual) — fix hitam tapi konek tanpa PowerShell manual.

Lihat detail di [changelogs/6.7.14.md](changelogs/6.7.14.md).

## [6.7.13] - 2026-09-11

> Build 48. Installer Windows (Inno Setup), Logo README identik all platform, Windows blink fix, Pengaturan lengkap (Tampilan/Bahasa, Kontrol/Pintasan, Jaringan/Keamanan), Guard tile #F5F3FF lolos.

Lihat detail di [changelogs/6.7.13.md](changelogs/6.7.13.md).

## [6.7.12] - 2026-09-09

> Build 47. In-App Update Modal Portrait 3:4 AI, Background Android Notification Download, Splash Luminous Glow, Desktop Tauri v2 fixes, 1-Click Virtual Driver Installers, dan pembaruan README.

### Ditambahkan
- **In-App Update Experience (AI Portrait Modal 3:4)**: Dialog visual pembaruan murni rasio 3:4 portrait AI dengan elemen 3D gaming morphing, motion blur, dan tombol floating close `X`.
- **Background Download Progress Notification (Android)**: Notifikasi progress unduh APK pada drawer sistem Android, memungkinkan download tetap jalan di background.
- **Direct APK Install Flow**: Pemasangan langsung APK terverifikasi setelah unduhan selesai.
- **Splash Screen Luminous Ambient Glow (Flutter)**: Aura ambient bloom violet lembut di belakang logo watermark dengan kurva transisi halus.
- **1-Click Elevated Driver Installer (Desktop)**: Dukungan instalasi instan untuk Virtual Display Driver (IddSampleDriver) dan Virtual Mic/Audio (VB-CABLE) langsung via Tauri backend dengan PowerShell UAC elevation.
- **Updater desktop (PC)**: kartu "Pembaruan aplikasi" di Pengaturan — cek otomatis, unduh installer terverifikasi SHA-256, pasang lalu mulai ulang. Manifest `update.json` kini membawa kunci `windows` (x64/arm64).
- **Artikel arsip 6.5.2**: `changelog-v6-5-2` diterbitkan retroaktif — tidak ada lagi tautan versi yang 404.
- **README.md Komprehensif**: Penambahan badge status CI/CD lengkap, dukungan platform, matriks teknologi, dan panduan kontribusi komunitas.
- **Panduan Update Popup Guide (`docs/APP_UPDATE_POPUP_GUIDE.md`)**: Dokumentasi arsitektur, prompt template, dan alur notifikasi.

### Diperbaiki
- **Unifikasi UI/UX tiga platform** (operator: web = acuan): token Paper mengikuti web — `bg #ffffff`,
  `overlay`/`input #f5f3ff`, `accent-soft` 10%; radius satu skala 8/12/16/20 + pil + tuts-3 (kartu = 16
  di semua platform); garis pemisah dihapus di desktop + web (kartu = bayangan, baris daftar = ubin
  overlay + gap, strip/tab = jalur input + tab putih, tabel = zebra/ubin, chip = isi overlay dengan
  aktif isi-lembut + teks dalam); switch desktop = trek `textLow @45%` tanpa outline + flat aksen saat
  on; aturan tersisa yang disengaja tercatat tertutup di `docs/DESIGN.md` ("Garis yang disengaja").
- **Installer Windows di-brand**: gambar wizard `wizard-image.bmp` (164×314) + `wizard-small.bmp` (55×55)
  dari logo asli — bukan lagi default polos Inno Setup.
- **Korupsi CSS web**: blok `@media` rusak di `web/src/style.css` (~L1067) dihapus; ~10 deklarasi yatim
  (`margin`, `padding`, `border`, `grid-*`) ikut terbuang, aturan `.sesi-panel h2` duplikat digabung.
- **Tempel teks panjang dari HP**: dipecah otomatis per 2.000 karakter (tidak lagi dipotong host di 4.096).
- **Profil desktop**: versi & server kini tampil (kontrak `get_info` diluruskan; versi tidak lagi hardcode basi).
- **Label perangkat**: nama akun tampil di pesan pairing web; hub Go tidak lagi membuang `name`/`platform` saat relay.
- **`news/seed.sql`**: 5 alias slug diluruskan + 5 artikel lama ditarik dari produksi — repo kembali jadi cermin penuh.
- **`build-apk-only.yml`**: signing rilis + Google client id + hapus step license palsu (belum pernah jalan sebelum diperbaiki).
- **Ikon launcher kembali ke logo asli**: tile terang `#F5F3FF` + X ungu glossy di Android (legacy, adaptive, splash-safe), favicon web, dan semua `.ico` Windows. Lapisan foreground adaptive icon dibuat murni transparan (100% alpha = 0 di luar glyph X) agar serasi sempurna dengan adaptive system background plate di Android.
- **Desktop Tauri v2 Config**: Konfigurasi bundle targets pada `desktop/src-tauri/tauri.conf.json` untuk stabilitas kompilasi release Windows x64 & arm64.
- **Inventaris Lisensi Pihak Ketiga**: Sinkronisasi seluruh dependensi lockfile ke 509 komponen resmi.

## [6.7.11] - 2026-09-07

> Build 46. Fix CI Build 34249803875 — Windows x64/arm64 3 errors PROPERTYKEY not found.

### Diperbaiki
- **CI Build 34249803875**: 2 job gagal — `Windows x64` + `Windows arm64` 3 errors PROPERTYKEY not found in PropertiesSystem, actually in Foundation. Fixed.
- Lihat detail di [6.7.11](./changelogs/6.7.11.md)

## [6.7.10] - 2026-09-07

> Build 45. Fix CI Build 34245728600 — Windows x64/arm64 cargo build 8 errors (Win32 not found, PROPERTYKEY, PWSTR).

### Diperbaiki
- **CI Build 34245728600**: 2 job gagal — `Windows x64` + `Windows arm64` cargo build 8 errors: `screen.rs` Win32 not found, `audio.rs` PROPERTYKEY not found, `audio.rs` PWSTR mismatched. Fixed with Foundation+Com features, ::windows absolute, PWSTR direct.
- Lihat detail di [6.7.10](./changelogs/6.7.10.md)

## [6.7.9] - 2026-09-07

> Build 44. Fix CI Build 34171262232 — Windows x64/arm64 cargo build errors (format, PropertiesSystem, GetSystemMetrics, Security/Threading).

### Diperbaiki
- **CI Build 34171262232**: 2 job gagal — `Windows x64` + `Windows arm64` cargo build release error 4 distinct: `screen.rs` format `{:.1}` no arg, `audio.rs` PropertiesSystem feature, `gdi.rs` GetSystemMetrics wrong module, `virtual_display.rs` Security/Threading features. Fixed.
- Lihat detail di [6.7.9](./changelogs/6.7.9.md)

## [6.7.8] - 2026-09-07

> Build 43. Fix CI Build 34170927923 — flutter seamless Divider + clippy single_element_loop.

### Diperbaiki
- **CI Build 34170927923**: 2 job gagal — `Verifikasi aturan seamless` (Divider) + `Clippy single_element_loop`. Fixed.
- Lihat detail di [6.7.8](./changelogs/6.7.8.md)

## [6.7.7] - 2026-09-07

> Build 42. Fix CI Build 34170387236 — flutter analyze unused + host bitrate 0 auto.

### Diperbaiki
- **CI Build 34170387236**: 2 job gagal — `Analisis Statis Flutter` (unused _connecting, _ConnectingView, missing tokens import) + `Uji Logika Host` (bitrate 0 auto should be allowed). Fixed, 122 tests pass.
- Lihat detail di [6.7.7](./changelogs/6.7.7.md)

## [6.7.6] - 2026-09-07

> Build 41. Hotfix CI — format Dart + Rust + CHANGELOG + TURN direct kind. Build 6.7.5 gagal 4 jobs, fixed.

### Diperbaiki
- **CI Build 34169492118**: 4 job gagal — `Cek Lintas-Dokumen`, `Analisis Statis Flutter`, `Uji Logika Host Rust`, `Uji Backend`. Fixed.
- Lihat detail di [6.7.6](./changelogs/6.7.6.md)

## [6.7.5] - 2026-09-07

> Build 40. Web Perfection — Founder: "Sempurnakan web, serta jalur jalur dan lain lain okey? Gas"

### Ditambahkan
- **Web quality & bitrate UI** `web/src/session_ui.tsx`: `StreamQuality auto|medium|high|ultra`, `BitrateMbps 0|8|15|25|50`, `QUALITY_META`, `BITRATE_OPTIONS`, `DEFAULT_PREFS` quality auto bitrate 0. Tab Gambar: chips Otomatis/Sedang/Tinggi/Ultra + Otomatis/8/15/25/50 Mbps + live stats. Callback `onQuality`/`onBitrate` ke host via 0x0A/0x0B.
- **Host protocol 0x0A/0x0B** `host/src/input.rs` + `main.rs`: `VideoQuality(u8)` `VideoBitrate(u16)`, mapping quality auto→DEFAULT medium 8M high 15M ultra 25M, bitrate 0 auto else 1-50M.
- **Web rtc codec** `web/src/rtc.ts`: `InputCodec.quality()` `bitrateMbps()` + `RtcSession.setQuality/setBitrate`.
- **Hero 3D glossy morphing + floating motion blur** `web/src/style.css` + `App.tsx`: 3 orb radial glossy blur morph + 3 glass card 1080p60 LIVE 24ms NVENC backdrop blur motion blur, hero-glow-morph 9s, logo translateZ.
- **Routing /n/:slug** `web/src/App.tsx`: `currentRoute()` handle `/n/:slug` share short link `news.xydesk.my.id/n/:slug` + `/n` → `/news`. Static routes /, /connect, /download, /legal, /news, /billing, /news/:slug, /n/:slug verified.
- **Download ABI active** `web/src/App.tsx`: switcher active class dari localStorage `xydesk.download.arch`.

### Diperbaiki
- **NEWS_IMAGE_BLOCK domain** `web/src/App.tsx` + `desktop/app/page.tsx`: `app.xystudio.my.id` salah → `(app.)?xydesk.my.id` allow app.xydesk.my.id & xydesk.my.id, fix image block.
- **device.ts** `web/src/device.ts`: `XyDesk-Windows-x64-Setup.exe` → `XyDesk-x64.exe` / `XyDesk-arm64.exe` match RELEASE_BASE.
- **Panel sempit** `web/src/style.css`: `.spanel` min 460px calc(100%-108px) max 480 min 380 padding 20 gap 14 mobile 440px 92vw.
- **Prefs migration** `web/src/App.tsx`: spread DEFAULT untuk localStorage lama tanpa quality/bitrate.

### Build
- `web` vite 8.2.1 37 modules 295.69kB gzip 93.22kB SUCCESS
- `desktop` Next.js 15.1.6 4 static pages 15.8kB SUCCESS
- `host` Cargo.toml 6.7.5 + protocol 0x0A/0x0B ready
- `pubspec.yaml` 6.7.5+40, `web/package.json` 6.7.5, `desktop/package.json` 6.7.5

## Daftar versi (per file)

- [6.7.11](./changelogs/6.7.11.md) - 2026-09-07 — Fix CI Windows PROPERTYKEY Foundation
- [6.7.10](./changelogs/6.7.10.md) - 2026-09-07 — Fix CI Windows cargo build 8 errors (Win32, PROPERTYKEY, PWSTR)
- [6.7.9](./changelogs/6.7.9.md) - 2026-09-07 — Fix CI Windows cargo build 4 errors
- [6.7.8](./changelogs/6.7.8.md) - 2026-09-07 — Fix CI seamless Divider + clippy
- [6.7.7](./changelogs/6.7.7.md) - 2026-09-07 — Fix CI flutter analyze + host bitrate 0 auto
- [6.7.6](./changelogs/6.7.6.md) - 2026-09-07 — Hotfix CI format + TURN direct
- [6.7.5](./changelogs/6.7.5.md) - 2026-09-07 — Web Perfection
- [6.7.4](./changelogs/6.7.4.md) - 2026-09-07 — License EN + Admin Auto + Simple Splash + Quality + Spacious Panel
- [6.7.3](./changelogs/6.7.3.md) - 2026-09-07 — Fix Android update + Session Loading + Banner lock + Changelog split
- [6.7.2](./changelogs/6.7.2.md) - 2026-09-07 — Virtual Display + Virtual Mic + NSIS auto-installer
- [6.7.1](./changelogs/6.7.1.md) - 2026-09-07 — Fix VM/RDP hitam + audio mati + UI desktop v3.0
- [6.7.0](./changelogs/6.7.0.md) - 2026-09-07 — DXGI utama, audio 0x88890008 fix, auth desktop
- [6.6.1](./changelogs/6.6.1.md) - 2026-09-06 — Fix layar hitam saat diam
- [6.6.0](./changelogs/6.6.0.md) - 2026-09-06 — Fix splash stuck + CSP web
- [6.5.4](./changelogs/6.5.4.md) - 2026-09-05
- [6.5.3](./changelogs/6.5.3.md) - 2026-09-04
- [6.5.2](./changelogs/6.5.2.md) - 2026-09-03
- [6.5.1](./changelogs/6.5.1.md) - 2026-09-02
- [6.5.0](./changelogs/6.5.0.md) - 2026-09-01
- [6.4.0](./changelogs/6.4.0.md) - 2026-08-30
- [6.3.0](./changelogs/6.3.0.md) - 2026-08-25
- [6.2.2](./changelogs/6.2.2.md) - 2026-08-20
- [6.2.1](./changelogs/6.2.1.md) - 2026-08-18
- [6.2.0](./changelogs/6.2.0.md) - 2026-08-15
- [6.1.0](./changelogs/6.1.0.md) - 2026-08-10
- [6.0.0](./changelogs/6.0.0.md) - 2026-08-01
- [2.5.0](./changelogs/2.5.0.md) - 2026-07-20
- [2.4.0](./changelogs/2.4.0.md) - 2026-07-15

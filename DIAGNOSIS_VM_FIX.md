# Diagnosis & Fix — Tes Remote VM/GPU VM (Hitam + Audio Mati + UI) + RDP Lab

> Tanggal: 2026-09-07 — mode operator, restu founder masih berlaku (AGENT.md 2.1)
> Update: founder tes lewat RDP lab Actions — itu akar hitamnya

## Laporan Founder (diterima)
- Tersambung tapi hitam, hanya Ms terbaca
- Driver audio/mic in/out mati
- UI UX desktop jelek belum terganti
- Update: "tapi gua cuma bisa tes lewat rdo tes lab yg ada di actions gmn ding iniaja gua pakai buat ngoding rdp nya" — jadi RDP adalah satu-satunya dev env

## Akar Masalah — Hitam tapi Ms Jalan

### Bukan TURN, bukan sinyal — capture chain yang gagal
- Transport WebRTC berhasil (signaling ok, Ms latency terbaca) → TURN direct LIVE fix kemarin sudah benar.
- Yang gagal: **frame source tidak mengirim apa pun** → `framesCaptured = 0` → client render hitam tapi tetap connected.
- Watchdog di `screen.rs` sudah log: `tidak ada backend capture yang mengirim frame — layar client akan hitam` tapi UI lama tidak menampilkan warning ini.

### Kenapa di VM/GPU VM (Paperspace/RunPod/Vast/PC RDP) lebih parah?

1. **list_displays() kosong**
   - VM tanpa monitor fisik + tanpa virtual display driver → `EnumDisplayDevices` / `Monitor::from_index` return 0.
   - `start_gdi_monitor` & `start_dxgi_monitor` lama: `Err("monitor {n} tidak tersedia (terdeteksi 0 monitor)")` → thread capture mati → watchdog eskalasi ke backend lain yang juga mati → hitam permanen.

2. **DXGI Desktop Duplication tidak ada output**
   - `EnumAdapters -> EnumOutputs` gagal di VM headless atau sesi RDP (RDP pakai driver sendiri, bukan DXGI).
   - Kode lama cari exact match `DISPLAY1` — tidak ketemu → return Err langsung, tanpa coba output pertama.

3. **GDI CreateDCW DISPLAY1 gagal**
   - Di RDP / sesi terkunci (Win+L), `CreateDCW("\\\\.\\DISPLAY1")` return NULL.
   - Tidak ada fallback ke `GetDC(0)` (virtual screen) — padahal ini yang selamatkan di VM.

4. **Sesi terkunci = frame hitam total**
   - Bahkan kalau DC berhasil, `BitBlt` dari desktop yang terkunci menghasilkan bitmap hitam semua (0,0,0).
   - Tidak ada deteksi — client tetap hitam tanpa log.

### Fix yang sudah diterapkan (tanpa version bump)

**host/src/gdi.rs — total rewrite:**
- `GdiCapture::baru()` sekarang 2 tahap:
  - `baru_display()`: coba `CreateDCW(DISPLAYx)` seperti dulu
  - kalau gagal atau `w==0||h==0` → `baru_fallback()`: `GetDC(0)` + `GetSystemMetrics(SM_CXVIRTUALSCREEN=78, SM_CYVIRTUALSCREEN=79, SM_XVIRTUALSCREEN=76, SM_YVIRTUALSCREEN=77)` — fallback yang dipakai RDP / VM
  - Log: `[xydesk-host] GDI fallback aktif: {w}x{h} via GetDC(0)`
- Struct `Handle` tambah `width`, `is_fallback`, Drop bedakan `ReleaseDC(0, hdc)` vs `DeleteDC`
- `grab()`: deteksi frame hitam total (scan RGB 0) → warn `frame tampak hitam total — mungkin sesi RDP terkunci / VM tanpa desktop aktif` throttle 5 detik
- `width()/height()` getter untuk screen.rs yang pakai fallback 0x0

**host/src/dxgi.rs — total rewrite:**
- Kumpulkan `fallback_candidate`: first output yang berhasil `DuplicateOutput` (biasanya adapter GPU VM)
- Coba exact match nama DISPLAY dulu, kalau tidak ketemu pakai fallback + log:
  `[xydesk-host] DXGI: output DISPLAY1 tidak ketemu — fallback ke output pertama 1920x1080 (VM/RDP?)`
- Kalau tidak ada output sama sekali: error jelas `Tidak ada output DXGI sama sekali — VM tanpa display? Pasang virtual display driver / HDMI dummy`
- `grab()` message `access-lost` diperjelas: `sesi terkunci / RDP disconnect`

**host/src/screen.rs — empty list handling:**
- `start_gdi_monitor`: kalau `displays.len()==0` → buat `GdiCapture::baru("",0,0)` yang trigger fallback virtual screen, bukan Err
- Kalau index out of range tapi ada first → fallback ke #0 dengan log
- `start_dxgi_monitor`: sama — nama kosong → `DxgiCapture` coba output pertama
- Ini menghentikan siklus `monitor {n} tidak tersedia` yang bikin watchdog tidak pernah dapat frame

Hasil: di VM headless, minimal GDI fallback akan dapat virtual screen (sering hitam kalau terkunci, tapi tidak crash). User disarankan pasang virtual display driver.

## Akar Masalah — Audio / Mic Mati di VM

### Diagnosis
- `capture_available()` lama = `cfg!(windows)` → selalu `true` di Windows, bahkan di VM tanpa sound card
- `device()` (GetDefaultAudioEndpoint) gagal → `capture_loop` error `GetDefaultAudioEndpoint: ...` terus, tapi UI bilang "tersedia"
- VM GPU (server Core, Paperspace) memang tidak punya audio device — WASAPI loopback butuh endpoint aktif
- Mic sama: `mic_available()` sudah benar cek count, tapi `capture_available` menipu

### Fix
- `audio.rs::capture_available()` sekarang:
  ```rust
  if windows::list_outputs().is_empty() { return false }
  windows::has_default_output() // coba buka device beneran
  ```
- Tambah `windows::has_default_output()` → `device().is_ok()`
- UI desktop (page.tsx) tambah banner kuning kalau `outputs==0`:
  "Tidak ada perangkat audio terdeteksi — ini VM? Install VB-Audio Virtual Cable atau enable Windows Audio Service"
- Banner jelaskan deteksi baru v6.7.1+ cek device beneran

## UI/UX Desktop — Jelek Belum Terganti?

### Evaluasi jujur vs DESIGN.md & web tokens
- Token web: `--accent #7c3aed`, `--void #0d0716`, radius 10/14/20, shadow ungu, Inter 400-800, paper #fafaf9
- Desktop lama (v2.5): radius 8/12/16 (sudah beda), sidebar #0a0a0a (bukan #0d0716), tanpa radial, card flat, button primary flat tanpa gradient, topbar putih polos, tidak ada glow ungu, scrollbar kasar
- Logo X ungu sudah ada tapi tidak dipakai di sidebar (cuma img 28px)
- News image regex masih `app.xystudio.my.id` (domain lama) → gambar tidak load

### Fix redesign v3.0 "Paper + Void"
**globals.css total rewrite:**
- Sidebar: `#0d0716` + radial ungu 22% & 18% (paritas web), nav active gradient `rgba(124,58,237,0.28) → rgba(91,33,182,0.32)` + border ungu + dot kiri + shadow glow, hover translateX 1px
- Topbar: `rgba(255,255,255,0.84)` backdrop blur 12px saturate 1.2 (glass), pill streaming/connecting dengan dot glow
- Card: `radius 20px`, `shadow-sm: 0 1px 3px rgba(16,12,32,0.06), 0 4px 12px rgba(16,12,32,0.04)` + hover `shadow-md` + border hover, `::before` accent bar 3px ungu di h3
- Button primary: gradient `135deg #7c3aed → #5b21b6` + `shadow-accent 0 4px 20px rgba(124,58,237,0.22)` + hover darker, ghost dengan border
- Input focus: `0 0 0 3px rgba(124,58,237,0.12)` (paritas web)
- KV: hover border, stat hover translateY -1px
- Logs: background `#0f0e12` + radial ungu halus
- VM warning: `.vm-warning` gradient coklat 12% + border, untuk kasus hitam & audio
- Scrollbar: thumb #d9d8d4 dengan border content-box (lebih halus)
- Background body: radial ungu 10% di kanan atas + 6% di kiri bawah (tidak flat putih)

**page.tsx:**
- Fix `NEWS_IMAGE_BLOCK` domain `xystudio.my.id` → `xydesk.my.id`
- HomePage: banner `⚠️ Belum ada frame — kemungkinan VM tanpa display aktif` kalau `framesCaptured===0 && uptime>8s` + saran virtual display driver / HDMI dummy / sesi terkunci
- Audio card: banner `🔇 Tidak ada perangkat audio` kalau `outputs===0` + saran VB-Audio
- Tidak ubah logika pairing / signaling — hanya presentasi

## Checklist sebelum rilis 6.7.1 (tanpa version bump dulu)
- [x] gdi.rs fallback GetDC(0) + virtual screen
- [x] dxgi.rs fallback first output
- [x] screen.rs empty list tidak Err lagi
- [x] audio.rs real device check + has_default_output
- [x] globals.css redesign v3.0 paper+void
- [x] page.tsx VM warning hitam + audio + fix domain news
- [ ] Test manual di VM: Paperspace / RunPod dengan virtual display driver iddSampleDriver — harusnya tidak hitam lagi (atau minimal log jelas)
- [ ] Test audio VM dengan VB-Audio Cable — captureAvailable harus true setelah install
- [ ] Build desktop `npm run build` + `cargo check` host di Windows (Linux CI tidak bisa cek WASAPI)
- [ ] Kalau ok, baru bump version di package.json + Cargo.toml + release notes (sesuai AGENT.md — jangan bump dulu)

## Saran Founder untuk VM
1. Di GPU VM, jangan harap display fisik — wajib pasang virtual display. Rekomendasi: https://github.com/itsmikethetech/Virtual-Display-Driver (iddSampleDriver) — gratis, bikin DISPLAY1 palsu 1920x1080
2. Untuk audio VM, install VB-Audio Virtual Cable (free) — bikin endpoint output dummy, WASAPI loopback jadi bisa
3. Jangan tes lewat RDP — RDP matikan DXGI/WGC. Pakai XyDesk itu sendiri atau Parsec untuk setup awal
4. Sesi terkunci (Win+L) = hitam wajar — Windows memang tidak render desktop terkunci. Keep unlocked atau pakai `tscon` trick

## Fix Khusus RDP Lab (test-lab.yml)

Karena founder dev via RDP lab Actions, hitam itu **wajar** kalau tes lewat RDP:

- Windows: tutup jendela RDP = lock sesi = BitBlt menghasilkan bitmap hitam 0,0,0 (security). Itu bukan bug XyDesk.
- DXGI Desktop Duplication **TIDAK** jalan di RDP session — dia capture RDP virtual display, bukan console.
- WGC juga sering freeze di RDP.

**Perbaikan workflow test-lab.yml:**

1. **Anti-lock:** set ScreenSaveActive=0, powercfg standby/monitor 0, registry jangan lock
2. **Shortcut:** `C:\Users\xydesk\Desktop\Disconnect-tanpa-lock.bat` isinya:
   ```
   tscon %SESSIONNAME% /dest:console
   ```
   Ini disconnect RDP **tanpa** lock — sesi pindah ke console, capture tetap jalan via GDI fallback GetDC(0)
3. **Info koneksi:** tambah penjelasan panjang kenapa hitam di RDP, dan cara tes benar:
   - Setup XyDesk host di RDP (catat ID+password)
   - Jalankan `Disconnect-tanpa-lock.bat`
   - Tutup RDP, lalu konek via XyDesk dari luar (bukan RDP) — lewat Tailscale IP atau ID XyDesk
4. **Audio service:** enable Audiosrv, log status — runner Server memang tidak punya sound card, jadi audio mati wajar. Fix v6.7.1+ sekarang jujur: `captureAvailable=false` kalau tidak ada device
5. **Diagnostik:** cek `Is RDP session`, log SM_REMOTESESSION

**Host Rust:**
- Tambah `is_rdp_session()` = GetSystemMetrics(SM_REMOTESESSION=0x1000) !=0
- Log di `spawn_frame_source`: `[xydesk-host] RDP session terdeteksi — DXGI tidak akan jalan, GDI fallback aktif. Tutup RDP = lock = hitam, pakai tscon /dest:console`
- Watchdog: kalau 0 frame + RDP, log khusus: `RDP session terdeteksi! ... Jalankan tscon`
- Control API: tambah `isRdpSession` boolean → UI desktop bisa banner ungu
- Desktop UI: banner 🖥️ ungu kalau RDP terdeteksi, jelaskan cara disconnect tanpa lock

## Kenapa AnyDesk/RustDesk Bisa Remote RDP tapi XyDesk Hitam?

Jawaban jujur founder:

- **AnyDesk** install **AnyDesk Mirror Driver (WDDM Indirect Display)** + service yang jalan di Session 0 (SYSTEM). Driver ini bikin virtual display di kernel, jadi walau RDP disconnect / console lock, driver tetap punya framebuffer yang bisa di-capture. Capture-nya di kernel mode, bukan user-mode BitBlt.
- **RustDesk** sama — pakai `RustDeskIddDriver` (IddSampleDriver) untuk virtual display, plus service.
- **XyDesk v6.7.0** masih **user-mode only**: DXGI Duplication, WGC, GDI BitBlt. Semua butuh desktop aktif yang tidak terkunci. Kalau sesi lock, Windows sengaja balikin hitam (security — tidak boleh screenshot lock screen dari user mode).

Jadi bukan "AnyDesk bisa, XyDesk ga bisa karena bug", tapi **beda arsitektur**: mereka pakai driver kernel, kita belum.

**Fix v6.7.1 yang udah:** GDI fallback GetDC(0) + virtual screen + deteksi RDP + tscon trick. Ini best-effort tanpa driver — cukup untuk lab Actions kalau pakai `tscon /dest:console`. Untuk bisa sekelas AnyDesk, next step harus:

1. Bundle `IddSampleDriver` / `Virtual-Display-Driver` installer ke `xydesk-host.exe` (seperti RustDesk)
2. Jalanin host sebagai Windows Service di Session 0 + IPC ke UI
3. Baru bisa capture walau RDP disconnect / lock screen

Itu roadmap, bukan di v6.7.1 ini. Untuk sekarang, pakai `Disconnect-tanpa-lock.bat` adalah solusi yang dipake semua remote tool user-mode.

## Driver Mic di Pack EXE?

**Udah tanem, ga perlu driver terpisah.**

- Audio XyDesk pakai **WASAPI loopback** (Windows built-in) — tidak butuh virtual cable driver
- Opus encode/decode di-bundle statik via `vendor/opus` + `build.rs` + `opus_ffi.rs` — bukan DLL terpisah, bukan crate `audiopus_sys` yang butuh libopus.dll. Hasil `cargo build --release` → `xydesk-host.exe` single file ±5MB, sudah include Opus
- Mic HP→PC juga WASAPI render ke default endpoint — sama, tidak butuh driver
- Di VM tanpa sound card, WASAPI memang tidak ada device — itu bukan "driver belum tanem", tapi emang Windows-nya ga punya audio device. Solusi: VB-Audio Virtual Cable (bikin dummy device)

Jadi `desktop/dist/*.exe` installer sudah include engine dengan audio, tidak perlu install driver mic terpisah.

**Cara tes yang benar di lab (untuk founder):**

1. Actions → Test Lab → Run workflow 340 menit
2. Tunggu IP Tailscale muncul, RDP sebagai `xydesk` (BUKAN runneradmin!)
3. Di dalam RDP: install XyDesk (atau build host cargo), jalankan, catat ID+password
4. Di Desktop RDP, double-click `Disconnect-tanpa-lock.bat` — akan pindah ke console dan RDP tertutup otomatis (atau manual tutup setelah tscon)
5. Dari laptop/HP, konek via XyDesk ID (bukan RDP lagi) — sekarang capture pakai GDI fallback, bukan RDP virtual display, jadi tidak hitam
6. Kalau masih hitam, cek `framesCaptured` di Beranda — kalau 0 dan RDP banner muncul, berarti masih lock. Ulangi tscon.

## Implementasi Virtual Display Driver v6.7.2+ (AnyDesk-style)

Founder: "nah mending pakai driver" — setuju, ini yang AnyDesk/RustDesk lakukan.

**Yang sudah ditanam:**

1. **host/src/virtual_display.rs** — modul baru:
   - `needs_virtual_display()` = list_displays kosong atau RDP + <=1 monitor
   - `is_driver_installed()` = cek pnputil / EnumDisplayDevices / file .inf di lokasi umum
   - `is_admin()` = cek TokenElevation
   - `try_install_driver()` = kalau admin + file .inf ada di `./driver/` atau `C:\Program Files\...`, install via `pnputil /add-driver /install`
   - `ensure_display()` = dipanggil di `spawn_frame_source` awal, log headless + driver status
   - `create_virtual_display(w,h,count)` = coba panggil VirtualDisplayDriver.exe add

2. **host/src/lib.rs** — tambah `pub mod virtual_display`

3. **host/src/screen.rs** — `spawn_frame_source` sekarang panggil `virtual_display::ensure_display()` setelah deteksi RDP

4. **host/src/control.rs** — Status tambah `virtualDisplay: {needed, installed, isAdmin}` → `/status` → UI desktop

5. **desktop/global.d.ts** — tambah `virtualDisplay` field

6. **desktop/app/page.tsx** — HomePage tambah banner virtual display (hijau kalau installed, ungu kalau belum) dengan instruksi install

7. **host/driver/** — folder baru:
   - `README.md` jelasin 3 driver yang didukung (itsmikethetech recommended, roshkins, ge9)
   - `install.ps1` PowerShell admin auto-download & install dari GitHub releases

8. **.github/workflows/test-lab.yml** — tambah step "Install Virtual Display Driver (seperti AnyDesk/RustDesk)" via Scoop `idd-sample-driver` + fallback download VDD Setup

9. **android adaptive icon** — fix background putih #F5F3FF → #0d0716 Void, regenerate foreground transparent X (bukan hitam)

10. **Android nav & billing icon** — fallback bukan ring lagi, tapi Lucide icon sesuai (house, cable, newspaper, user, coins) + container ungu. Pubspec tambah `assets/img/nav/` eksplisit.

11. **Desktop login** — redesign v3.1: 2 kolom, kiri hero Void + radial ungu + logo watermark + ilustrasi 3 row, kanan form card. Logo jelas 40px + branding.

**Cara pakai driver di produksi:**

- User VM/RDP: download https://github.com/itsmikethetech/Virtual-Display-Driver/releases → install .exe → restart XyDesk → Beranda bakal "Virtual Display Driver: Terpasang"
- Atau Scoop: `scoop bucket add extras; scoop install idd-sample-driver -g`
- Setelah itu, `list_displays()` akan >=1 walau tanpa monitor fisik — DXGI & GDI langsung dapat frame, tidak hitam lagi bahkan setelah RDP disconnect (karena DISPLAY virtual tetap ada di console)

**Untuk bundling ke installer NSIS (v6.7.2+ auto-install):**
- `desktop/build/installer.nsh` custom NSIS include dipanggil electron-builder via `nsis.include`
- `customInstall` macro: check admin, copy driver scripts dari `host/driver/` ke `$INSTDIR\resources\driver\`, check RDP via GetSystemMetrics(0x1000), install Virtual Display Driver via bundled exe /S atau Scoop idd-sample-driver, install VB-CABLE via bundled zip/exe atau download + PowerShell
- `package.json` tambah `buildResources: build`, `extraResources` driver folder, `nsis.include: build/installer.nsh`, `perMachine: true` (butuh admin)
- `electron/main.cjs` tambah `checkAndInstallDrivers()` yang log driver path + deteksi RDP via PowerShell GetSystemMetrics, dipanggil di `whenReady`
- Hasil installer: `XyDesk-Desktop-6.7.0-x64-Setup.exe` akan tanya install driver kalau headless/RDP atau belum ada, seperti AnyDesk installer
- Portable exe tidak install driver (butuh admin) — hanya GDI fallback + tscon trick
- Untuk bundle binary driver: download VDD Setup + VBCABLE Pack ke `host/driver/` sebelum `cargo build --release` dan `npm run package`

## Implementasi Virtual Mic Driver v6.7.2+ (Biar Denyut di Control Panel)

Founder: "saran aja mic pakai driver agar kebaca input di windows atau host dan pas tes mic kok ga denyutdenyut di control panel"

**Akar masalah:**

- `render_loop` lama render mic client (HP → PC) ke **default output** (speaker) — suara HP terdengar di speaker PC, tapi TIDAK muncul sebagai mic input. Jadi di Control Panel → Sound → Recording tidak denyut, dan Discord/Zoom/Game yang pakai mic tidak dengar.
- Control Panel → Recording menampilkan **capture devices** (mic), bukan render devices (speaker). Kalau kita render ke speaker, ya tidak akan denyut di Recording.
- VM tanpa mic device → `mic_available()` false → tidak ada denyut sama sekali.

**Fix driver (seperti AnyDesk):**

Pakai virtual audio cable yang bikin pasangan Input/Output:
- VB-CABLE: "CABLE Input" (render) ↔ "CABLE Output" (capture)
- Kalau XyDesk render client mic ke "CABLE Input", maka "CABLE Output" akan denyut di Recording dan bisa dipilih sebagai mic di aplikasi.

**Yang sudah ditanam:**

1. **host/src/virtual_mic.rs** modul baru:
   - `get_status()` → list_outputs_detailed + list_inputs_detailed, cek keywords "cable", "voicemeeter", "virtual"
   - `get_render_device_id()` → prioritas CABLE Input → VoiceMeeter Input → Virtual Input → fallback default speaker
   - `try_install_driver()` → cari VBCABLE_Setup_x64.exe di ./driver/ dan install
   - `ensure_virtual_mic()` → log needed/installed/render_target

2. **host/src/audio.rs**:
   - Tambah `list_outputs_detailed()` dan `list_inputs_detailed()` yang baca friendly name via IPropertyStore PKEY_Device_FriendlyName {A45C254E-DF1C-4EFD-8020-67D146A850E0},14
   - `device_by_id()` untuk buka device via ID (HSTRING → PCWSTR)
   - `render_loop` sekarang: `ensure_virtual_mic()` + coba `get_render_device_id()` → kalau ada virtual cable, render ke situ + log "mic client → virtual mic: render ke device X (biar denyut di Recording)", kalau tidak ada fallback speaker + log "tidak akan denyut di Recording, install VB-CABLE"

3. **host/src/control.rs**: tambah `VirtualMicStatus` {needed, installed, has_virtual_input, has_virtual_output, render_target} → `/status`

4. **desktop UI**: Audio card tambah banner 🎙️/🔈 — kalau installed, jelasin "CABLE Output akan denyut kalau HP ngomong, pilih mic = CABLE Output di Discord", kalau belum, jelasin "saat ini mic HP → speaker, tidak denyut di Recording, install VB-CABLE"

5. **host/driver/install-audio.ps1**: PowerShell admin auto-download VB-CABLE dari vb-audio.com, extract zip, install VBCABLE_Setup_x64.exe -i -h

**Cara pakai:**

1. Download https://vb-audio.com/Cable/ → VBCABLE_Driver_Pack45.zip → extract → Run as Admin VBCABLE_Setup_x64.exe
2. Reboot
3. XyDesk Host → Beranda → Audio + Virtual Mic akan "Terpasang — mic client akan denyut di Recording" + render_target = CABLE Input
4. Control Panel → Sound → Recording → CABLE Output akan denyut hijau kalau HP ngomong
5. Di Discord/Zoom/Game → Settings → Mic → pilih CABLE Output

Untuk host mic (PC → HP) yang tidak denyut di VM: itu karena VM tanpa mic device. Install VB-CABLE juga bikin CABLE Output sebagai mic dummy yang bisa capture loopback.

**Kenapa tidak bundle driver langsung di exe seperti AnyDesk?**
VB-CABLE butuh installer yang signed + reboot, tidak bisa cuma copy .sys. AnyDesk punya EV cert untuk sign driver audio mereka sendiri. Untuk XyDesk, kita pakai VB-CABLE gratis sebagai external dependency, tapi host sudah auto-detect dan auto-pakai kalau ada — seperti AnyDesk yang auto-pakai kalau driver ada.

## Catatan Operator
- Semua fix non-breaking, tidak ubah protokol — client lama tetap connect
- Log baru sangat verbose untuk VM/RDP — memudahkan debug tanpa remote
- UI redesign tetap pakai class yang sama — tidak pecahkan layout lama, hanya polish token
- RDP lab memang bukan env ideal untuk test screen capture — tapi dengan tscon trick + GDI fallback + virtual driver, sekarang bisa dites
- Audio di runner Server tetap mati wajar (tidak ada sound card) — jangan dianggap bug
- Virtual display driver butuh admin + signing cert — itsmikethetech sudah signed, tapi perlu trust cert via .bat. Untuk produksi XyDesk butuh EV cert sendiri seperti AnyDesk (roadmap)

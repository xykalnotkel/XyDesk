# Virtual Display Driver untuk XyDesk — seperti AnyDesk/RustDesk

## Kenapa perlu driver?
XyDesk user-mode (DXGI/WGC/GDI) tidak bisa capture layar yang terkunci atau VM tanpa monitor.
AnyDesk/RustDesk bisa karena mereka pakai WDDM Indirect Display Driver (IddCx) di kernel.

## Driver yang didukung (pilih salah satu)

### Rekomendasi: itsmikethetech/Virtual-Display-Driver
- Repo: https://github.com/itsmikethetech/Virtual-Display-Driver
- Ada installer .exe, support Windows 10/11, bisa atur resolusi, HDR, 60Hz+
- Download latest release: `Virtual-Display-Driver-Setup-v*.exe`
- Install → restart XyDesk → DISPLAY virtual muncul

### Alternatif: roshkins/IddSampleDriver (ge9 fork)
- Repo: https://github.com/roshkins/IddSampleDriver
- Scoop: `scoop install idd-sample-driver`
- Atau download zip, jalankan .bat sebagai admin untuk trust cert, lalu Add Legacy Hardware di Device Manager → Display adapters → Have Disk → pilih .inf

### Alternatif: ge9/IddSampleDriver
- Repo: https://github.com/ge9/IddSampleDriver
- Sama seperti di atas

## Cara install untuk XyDesk

1. Download driver (rekomendasi itsmikethetech)
2. Install sebagai Administrator
3. Buka XyDesk Host → Beranda → cek "Virtual Display" status
4. Kalau `installed=true` dan `needed=true`, driver akan otomatis bikin display 1920x1080
5. Kalau RDP lab Actions: setelah install driver, `tscon %SESSIONNAME% /dest:console` tetap disarankan

## Integrasi di xydesk-host.exe

- `virtual_display.rs` deteksi headless/RDP
- Kalau driver ada, log: "virtual display driver sudah ada"
- Kalau tidak ada dan admin, coba install dari `./driver/*.inf` via pnputil
- Control API `/status` sekarang ada `virtualDisplay: {needed, installed, isAdmin}` → UI desktop bisa banner

## Untuk bundling ke installer NSIS

Copy driver .inf + .cat + .sys ke `host/driver/` sebelum `cargo build --release`.
`electron-builder` akan bundle `host/target/release/xydesk-host.exe` yang sudah tau cara cari driver di `./driver/`.

Atau bundle installer terpisah: `Virtual-Display-Driver-Setup.exe` di `desktop/assets/` dan panggil dari main.cjs kalau `virtualDisplay.needed && !installed`.

## Test di VM/RDP

1. Di VM tanpa monitor, `list_displays()` = 0 → `needs_virtual_display()=true`
2. Setelah install driver, `list_displays()` >=1 → capture jalan, tidak hitam
3. Di RDP, driver bikin DISPLAY virtual yang tetap ada walau RDP disconnect (tidak lock)

## Catatan signing

Driver IddSampleDriver butuh test signing atau cert trusted. itsmikethetech sudah signed dengan cert yang perlu di-trust via .bat (Add cert to Trusted Root). Untuk produksi XyDesk, perlu EV cert untuk sign driver sendiri (seperti AnyDesk).

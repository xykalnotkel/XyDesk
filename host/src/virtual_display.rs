//! Virtual Display Driver — solusi hitam di VM/RDP seperti AnyDesk/RustDesk
//!
//! ## Kenapa perlu driver?
//! XyDesk v6.7.0 masih user-mode only (DXGI/WGC/GDI). Kalau sesi RDP tutup atau
//! VM tanpa monitor, Windows lock sesi → BitBlt hitam. AnyDesk/RustDesk bisa
//! tetap jalan karena mereka pakai WDDM Indirect Display Driver (IddCx) yang
//! bikin virtual display di kernel — framebuffer tetap ada walau lock.
//!
//! ## Implementasi v6.7.1+ (driver capture langsung)
//! Modul ini sekarang **driver-first** untuk headless/RDP:
//! 1. Deteksi headless / RDP (pakai is_rdp_session + list_displays + GPU vendor check)
//! 2. Cek apakah virtual display driver sudah terinstal (IddSampleDriver /
//!    Virtual-Display-Driver dari itsmikethetech)
//! 3. Kalau driver ada tapi virtual display belum muncul → buat via IOCTL/exe/restart
//! 4. Kalau admin + driver bundling ada di `C:\Program Files\XyDesk\drivers\` → install via pnputil
//! 5. Capture via **driver display** (DXGI pada virtual adapter) — bukan DXGI fisik yang gagal di RDP
//! 6. Fallback: GDI GetDC(0) bila driver belum siap
//!
//! Driver yang didukung:
//! - https://github.com/itsmikethetech/Virtual-Display-Driver (rekomendasi, ada installer)
//! - https://github.com/roshkins/IddSampleDriver (ge9 fork, Scoop: `scoop install idd-sample-driver`)
//! - https://github.com/ge9/IddSampleDriver
//!
//! Setelah driver terpasang, Windows akan lihat DISPLAY tambahan walau tanpa
//! monitor fisik — DXGI & GDI fallback langsung dapat frame, tidak hitam lagi.
//! Driver ge9 baca `option.txt` untuk resolusi; itsmikethetech pakai exe `add`.

#[cfg(target_os = "windows")]
use std::process::Command;

#[cfg(target_os = "windows")]
const DRIVER_HWIDS: &[&str] = &[
    "IddSampleDriver",      // roshkins/ge9
    "VirtualDisplayDriver", // itsmikethetech
    "ROOT\\VirtualDisplayDriver",
    "ROOT\\IddSampleDriver",
];

/// Benar bila sistem terlihat headless / RDP — butuh virtual display
pub fn needs_virtual_display() -> bool {
    #[cfg(target_os = "windows")]
    {
        let displays = crate::screen::list_displays();
        let rdp = crate::screen::is_rdp_session();
        let empty = displays.is_empty();
        let rdp_single = rdp && displays.len() <= 1;
        // Juga cek GPU Microsoft Basic Render Driver (VM tanpa GPU passthrough)
        let basic_render = is_basic_render_driver();
        empty || rdp_single || (basic_render && displays.len() <= 1)
    }
    #[cfg(not(target_os = "windows"))]
    {
        false
    }
}

/// Cek apakah VM pakai Microsoft Basic Render Driver (0x1414) — indikasi headless tanpa GPU
#[cfg(target_os = "windows")]
fn is_basic_render_driver() -> bool {
    // Cek via hwinfo: kalau semua adapter vendor 0x1414 atau tidak ada adapter aktif
    // Simpler: cek apakah list_displays kosong atau GDI fallback akan hitam
    // Untuk sekarang, pakai heuristic: cek registry Display adapters
    if let Ok(output) = Command::new("pnputil")
        .arg("/enum-devices")
        .arg("/class")
        .arg("Display")
        .output()
    {
        let stdout = String::from_utf8_lossy(&output.stdout).to_lowercase();
        // Kalau hanya Microsoft Basic Display Adapter terdeteksi
        if stdout.contains("microsoft basic display")
            && !stdout.contains("nvidia")
            && !stdout.contains("amd")
            && !stdout.contains("intel")
        {
            return true;
        }
    }
    false
}

#[cfg(not(target_os = "windows"))]
#[allow(dead_code)]
fn is_basic_render_driver() -> bool {
    false
}

/// Cek apakah virtual display driver sudah terinstal
#[cfg(target_os = "windows")]
pub fn is_driver_installed() -> bool {
    // 1. Cek driver store via pnputil
    if let Ok(output) = Command::new("pnputil").arg("/enum-drivers").output() {
        let stdout = String::from_utf8_lossy(&output.stdout).to_lowercase();
        for hwid in DRIVER_HWIDS {
            if stdout.contains(&hwid.to_lowercase()) {
                return true;
            }
        }
    }
    // 2. Cek via display devices — kalau ada yang namanya mengandung Idd/Virtual
    let displays = crate::screen::list_displays();
    for d in &displays {
        let name = d.name.to_lowercase();
        if name.contains("idd") || name.contains("virtual") || name.contains("xydesk") {
            return true;
        }
        // Juga cek via EnumDisplayDevices yang lebih rendah: GDI device name
        // Untuk virtual display ge9, nama biasanya \\.\DISPLAYx dengan driver IddSampleDriver
    }
    // 3. Cek via PnP devices
    if let Ok(output) = Command::new("pnputil")
        .arg("/enum-devices")
        .arg("/present")
        .output()
    {
        let stdout = String::from_utf8_lossy(&output.stdout).to_lowercase();
        if stdout.contains("iddsampledriver")
            || stdout.contains("virtualdisplaydriver")
            || stdout.contains("xydesk virtual")
        {
            return true;
        }
    }
    // 4. Cek file driver di lokasi umum
    let common_paths = [
        r"C:\Program Files\Virtual Display Driver\VirtualDisplayDriver.inf",
        r"C:\Program Files\IddSampleDriver\IddSampleDriver.inf",
        r"C:\Program Files\XyDesk\drivers\IddSampleDriver\iddsampledriver.inf",
        r"C:\IddSampleDriver\IddSampleDriver.inf",
        r"./drivers/IddSampleDriver/iddsampledriver.inf",
        r"../drivers/IddSampleDriver/iddsampledriver.inf",
        r"./driver/IddSampleDriver.inf",
        r"./driver/VirtualDisplayDriver.inf",
        r"C:\Program Files\XyDesk\drivers\IddSampleDriver\option.txt",
    ];
    for p in common_paths {
        if std::path::Path::new(p).exists() {
            return true;
        }
    }
    false
}

#[cfg(not(target_os = "windows"))]
pub fn is_driver_installed() -> bool {
    false
}

/// Cari virtual display yang sudah ada — mengembalikan DisplayInfo-nya kalau ketemu
#[cfg(target_os = "windows")]
pub fn find_virtual_display() -> Option<crate::screen::DisplayInfo> {
    let displays = crate::screen::list_displays();
    for d in displays {
        let lname = d.name.to_lowercase();
        // ge9 driver: nama device mengandung DISPLAY tapi driver = IddSampleDriver
        // itsmikethetech: nama mengandung Virtual
        // Kita cek juga apakah ini virtual dengan cara: cek apakah primary false dan resolusi 1920x1080 (default ge9)
        if lname.contains("idd") || lname.contains("virtual") || lname.contains("xydesk") {
            return Some(d);
        }
        // Heuristic tambahan: kalau ada >1 display dan salah satunya resolusi 1920x1080 dan bukan primary,
        // kemungkinan itu virtual (ge9 default). Tapi jangan false positive di multi-monitor fisik.
        // Untuk aman, hanya kalau needs_virtual_display() true dan ada display extra
        if needs_virtual_display() && !d.is_primary && d.width == 1920 && d.height == 1080 {
            // Cek apakah ini benar-benar virtual dengan melihat PnP
            return Some(d);
        }
    }
    None
}

#[cfg(not(target_os = "windows"))]
pub fn find_virtual_display() -> Option<crate::screen::DisplayInfo> {
    None
}

/// Dapatkan indeks virtual display — untuk select_display
#[cfg(target_os = "windows")]
pub fn virtual_display_index() -> Option<usize> {
    find_virtual_display().map(|d| d.index)
}

#[cfg(not(target_os = "windows"))]
pub fn virtual_display_index() -> Option<usize> {
    None
}

/// Cek apakah proses jalan sebagai admin — butuh untuk install driver
#[cfg(target_os = "windows")]
pub fn is_admin() -> bool {
    unsafe {
        use windows::Win32::Foundation::HANDLE;
        use windows::Win32::Security::{
            GetTokenInformation, TokenElevation, TOKEN_ELEVATION, TOKEN_QUERY,
        };
        use windows::Win32::System::Threading::{GetCurrentProcess, OpenProcessToken};

        let mut token = HANDLE::default();
        if OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &mut token).is_err() {
            return false;
        }
        let mut elevation = TOKEN_ELEVATION { TokenIsElevated: 0 };
        let mut size = 0u32;
        let res = GetTokenInformation(
            token,
            TokenElevation,
            Some(&mut elevation as *mut _ as *mut _),
            std::mem::size_of::<TOKEN_ELEVATION>() as u32,
            &mut size,
        );
        let _ = windows::Win32::Foundation::CloseHandle(token);
        res.is_ok() && elevation.TokenIsElevated != 0
    }
}

#[cfg(not(target_os = "windows"))]
pub fn is_admin() -> bool {
    false
}

/// Coba install driver dari lokasi yang ada
#[cfg(target_os = "windows")]
pub fn try_install_driver() -> Result<String, String> {
    if !is_admin() {
        return Err(
            "butuh admin untuk install driver — jalankan xydesk-host sebagai Administrator"
                .to_string(),
        );
    }

    let candidates = [
        r"C:\Program Files\XyDesk\drivers\IddSampleDriver\iddsampledriver.inf",
        r"./drivers/IddSampleDriver/iddsampledriver.inf",
        r"../drivers/IddSampleDriver/iddsampledriver.inf",
        r"C:\Program Files\Virtual Display Driver\VirtualDisplayDriver.inf",
        r"C:\Program Files\IddSampleDriver\IddSampleDriver.inf",
        r"./driver/VirtualDisplayDriver.inf",
        r"./driver/IddSampleDriver.inf",
        r"C:\IddSampleDriver\IddSampleDriver.inf",
    ];

    for inf in candidates {
        if std::path::Path::new(inf).exists() {
            // pnputil /add-driver inf /install
            let output = Command::new("pnputil")
                .args(["/add-driver", inf, "/install"])
                .output()
                .map_err(|e| format!("pnputil gagal: {e}"))?;
            let stdout = String::from_utf8_lossy(&output.stdout);
            let stderr = String::from_utf8_lossy(&output.stderr);
            if output.status.success() {
                return Ok(format!("driver terpasang dari {inf}: {stdout}"));
            } else {
                eprintln!("[xydesk-host] pnputil gagal untuk {inf}: {stdout} {stderr}");
                // Coba fallback: pnputil tanpa /install lalu devcon
                let _ = Command::new("pnputil").args(["/add-driver", inf]).output();
            }
        }
    }

    // Kalau tidak ada file inf, coba pakai installer exe itsmikethetech jika ada
    let exe_candidates = [
        r"C:\Program Files\XyDesk\drivers\VirtualDisplayDriver\Virtual-Display-Driver-Setup.exe",
        r"./drivers/Virtual-Display-Driver-Setup.exe",
        r"C:\Program Files\Virtual Display Driver\VirtualDisplayDriver.exe",
    ];
    for exe in exe_candidates {
        if std::path::Path::new(exe).exists() {
            let output = Command::new(exe)
                .args(["/S"])
                .output()
                .map_err(|e| format!("installer gagal: {e}"))?;
            if output.status.success() {
                return Ok(format!("driver terpasang via {exe}"));
            }
        }
    }

    Err(
        "driver virtual display tidak ditemukan. Install manual:\n\
         1. Download https://github.com/itsmikethetech/Virtual-Display-Driver/releases (rekomendasi)\n\
         2. Atau Scoop: `scoop install idd-sample-driver` (https://github.com/roshkins/IddSampleDriver)\n\
         3. Atau `ge9/IddSampleDriver`\n\
         4. Setelah install, restart XyDesk — DISPLAY virtual akan muncul dan tidak hitam lagi\n\
         \n\
         Untuk lab RDP GitHub Actions, driver tidak bisa di-install tanpa reboot — pakai tscon trick:\n\
         `tscon %SESSIONNAME% /dest:console` atau klik Disconnect-tanpa-lock.bat di Desktop"
            .to_string(),
    )
}

#[cfg(not(target_os = "windows"))]
pub fn try_install_driver() -> Result<String, String> {
    Err("virtual display hanya Windows".to_string())
}

/// Pastikan virtual display ada — buat kalau belum ada tapi driver sudah terpasang
#[cfg(target_os = "windows")]
pub fn ensure_virtual_display_created() -> bool {
    if let Some(vd) = find_virtual_display() {
        println!(
            "[xydesk-host] virtual display sudah ada: {} {}x{} (index {})",
            vd.name, vd.width, vd.height, vd.index
        );
        return true;
    }
    if !is_driver_installed() {
        return false;
    }
    // Driver ada tapi display belum muncul — coba buat
    // Untuk ge9: driver baca option.txt dan butuh restart service atau re-enumerate
    // Untuk itsmikethetech: panggil exe add
    match create_virtual_display(1920, 1080, 1) {
        Ok(msg) => {
            println!("[xydesk-host] {}", msg);
            // Tunggu sebentar biar Windows enumerasi display baru
            std::thread::sleep(std::time::Duration::from_secs(2));
            if find_virtual_display().is_some() {
                println!("[xydesk-host] virtual display berhasil dibuat");
                return true;
            } else {
                eprintln!("[xydesk-host] virtual display belum muncul setelah create — coba restart service Display");
                // Coba restart TermService atau PnP
                let _ = Command::new("powershell")
                    .args(["-Command", "Restart-Service -Name \"DisplayEnhancementService\" -ErrorAction SilentlyContinue"])
                    .output();
                std::thread::sleep(std::time::Duration::from_secs(1));
                return find_virtual_display().is_some();
            }
        }
        Err(e) => {
            // Untuk ge9, create akan gagal karena tidak ada exe, tapi display seharusnya auto muncul setelah install
            // Jadi cek lagi: mungkin display sudah ada tapi find_virtual_display gagal karena nama tidak mengandung virtual
            // Fallback: cek apakah list_displays bertambah
            eprintln!("[xydesk-host] create virtual display: {e}");
            // Coba enable driver via Device Manager: devcon enable
            let _ = Command::new("pnputil").args(["/scan-devices"]).output();
            std::thread::sleep(std::time::Duration::from_secs(1));
            return find_virtual_display().is_some();
        }
    }
}

#[cfg(not(target_os = "windows"))]
pub fn ensure_virtual_display_created() -> bool {
    false
}

/// Pastikan ada display — kalau headless, coba install driver atau kasih warning
/// Versi driver-first: bila headless, prioritas adalah virtual display, bukan GDI GetDC(0) yang akan hitam saat lock
#[cfg(target_os = "windows")]
pub fn ensure_display() {
    if !needs_virtual_display() {
        return;
    }

    let displays = crate::screen::list_displays();
    eprintln!(
        "[xydesk-host] HEADLESS/RDP terdeteksi: {} monitor, RDP={}, driver_installed={}, basic_render={}",
        displays.len(),
        crate::screen::is_rdp_session(),
        is_driver_installed(),
        is_basic_render_driver()
    );

    if is_driver_installed() {
        if find_virtual_display().is_some() {
            println!(
                "[xydesk-host] virtual display driver sudah ada + virtual display aktif — capture via driver (bukan DXGI fisik) akan dipakai, tidak hitam di RDP/headless"
            );
            return;
        }
        // Driver ada tapi virtual display belum ada — coba buat
        println!("[xydesk-host] driver ada tapi virtual display belum muncul — mencoba buat...");
        if ensure_virtual_display_created() {
            println!("[xydesk-host] virtual display berhasil disiapkan — siap capture via driver");
        } else {
            eprintln!(
                "[xydesk-host] driver ada tapi virtual display belum muncul. Cek Device Manager → Display adapters. \
                 Coba: pnputil /scan-devices atau restart XyDesk sebagai admin."
            );
        }
        return;
    }

    // Driver belum ada
    if is_admin() {
        println!(
            "[xydesk-host] headless terdeteksi + admin → coba install virtual display driver..."
        );
        match try_install_driver() {
            Ok(msg) => {
                println!("[xydesk-host] {}", msg);
                // Setelah install, coba buat virtual display
                std::thread::sleep(std::time::Duration::from_secs(3));
                if ensure_virtual_display_created() {
                    println!("[xydesk-host] virtual display driver terpasang + virtual display aktif — headless teratasi");
                } else {
                    eprintln!("[xydesk-host] driver terpasang tapi virtual display belum muncul — butuh reboot atau pnputil /scan-devices");
                }
            }
            Err(e) => eprintln!("[xydesk-host] virtual display: {e}"),
        }
    } else {
        eprintln!(
            "[xydesk-host] BUTUH virtual display driver untuk VM/RDP tanpa monitor (driver-first, bukan DXGI fisik).\n\
             Saat ini {} monitor, RDP={}, basic_render={}. Install:\n\
             - https://github.com/itsmikethetech/Virtual-Display-Driver (installer exe, rekomendasi)\n\
             - Atau Scoop: scoop install idd-sample-driver\n\
             - Jalankan XyDesk Host sebagai admin, lalu restart — virtual display auto dibuat\n\
             \n\
             Sementara: GDI fallback GetDC(0) aktif, tapi akan hitam kalau sesi lock (RDP disconnect tanpa /dest:console).\n\
             Di lab RDP, pakai tscon %SESSIONNAME% /dest:console untuk disconnect tanpa lock.",
            displays.len(),
            crate::screen::is_rdp_session(),
            is_basic_render_driver()
        );
    }
}

#[cfg(not(target_os = "windows"))]
pub fn ensure_display() {}

/// Buat virtual display via driver IOCTL (kalau driver support)
///
/// Untuk itsmikethetech driver, ada app `VirtualDisplayDriver` yang bisa dipanggil
/// dengan argumen. Untuk ge9, display auto muncul dari option.txt (tidak perlu exe).
#[cfg(target_os = "windows")]
pub fn create_virtual_display(width: u32, height: u32, count: u32) -> Result<String, String> {
    // 1. Coba cari executable driver manager (itsmikethetech)
    let managers = [
        r"C:\Program Files\Virtual Display Driver\VirtualDisplayDriver.exe",
        r"C:\Program Files\IddSampleDriver\IddSampleDriver.exe",
        r"./driver/VirtualDisplayDriver.exe",
        r"C:\Program Files\XyDesk\drivers\Virtual-Display-Driver\VirtualDisplayDriver.exe",
        r"./drivers/VirtualDisplayDriver.exe",
    ];

    for exe in managers {
        if std::path::Path::new(exe).exists() {
            // itsmikethetech driver: VirtualDisplayDriver.exe add 1 1920 1080
            // Cek help dulu
            let output = Command::new(exe)
                .args([
                    "add",
                    &count.to_string(),
                    &width.to_string(),
                    &height.to_string(),
                ])
                .output()
                .map_err(|e| format!("gagal jalankan {exe}: {e}"))?;
            let stdout = String::from_utf8_lossy(&output.stdout);
            let stderr = String::from_utf8_lossy(&output.stderr);
            if output.status.success() {
                return Ok(format!(
                    "virtual display {}x{} dibuat via {exe}: {stdout}",
                    width, height
                ));
            } else {
                eprintln!("[xydesk-host] {} add gagal: {stdout} {stderr}", exe);
            }
        }
    }

    // 2. Untuk ge9 driver: cek option.txt — kalau ada, display seharusnya auto muncul setelah driver terpasang
    // Kita coba trigger re-enumerasi via pnputil
    let ge9_option = r"C:\Program Files\XyDesk\drivers\IddSampleDriver\option.txt";
    if std::path::Path::new(ge9_option).exists() {
        // ge9 driver baca option.txt saat device start — coba scan devices
        let _ = Command::new("pnputil").args(["/scan-devices"]).output();
        std::thread::sleep(std::time::Duration::from_secs(1));
        if find_virtual_display().is_some() {
            return Ok(format!(
                "virtual display {}x{} siap via ge9 option.txt",
                width, height
            ));
        }
        // Coba restart device
        let _ = Command::new("powershell").args(["-Command", "Get-PnpDevice -FriendlyName '*IddSampleDriver*' | Enable-PnpDevice -Confirm:$false; Get-PnpDevice -FriendlyName '*Virtual*' | Enable-PnpDevice -Confirm:$false"]).output();
        std::thread::sleep(std::time::Duration::from_secs(1));
        if find_virtual_display().is_some() {
            return Ok("virtual display ge9 diaktifkan via PnP".to_string());
        }
    }

    // 3. Fallback: coba via registry / config file driver itsmikethetech
    // Driver baca config dari %PROGRAMDATA%\VirtualDisplayDriver\config.json
    let program_data =
        std::env::var("PROGRAMDATA").unwrap_or_else(|_| r"C:\ProgramData".to_string());
    let config_path = format!("{}\\VirtualDisplayDriver\\config.json", program_data);
    if std::path::Path::new(&config_path).exists() {
        return Ok(format!(
            "config ditemukan di {} — driver itsmikethetech akan baca otomatis",
            config_path
        ));
    }

    Err("virtual display manager tidak ditemukan — install driver dulu dari https://github.com/itsmikethetech/Virtual-Display-Driver (atau ge9 IddSampleDriver sudah terpasang tapi virtual display belum muncul, coba reboot)".to_string())
}

#[cfg(not(target_os = "windows"))]
pub fn create_virtual_display(_w: u32, _h: u32, _c: u32) -> Result<String, String> {
    Err("hanya Windows".to_string())
}

#[cfg(test)]
mod tests {
    #[test]
    #[cfg(not(target_os = "windows"))]
    fn non_windows_tidak_butuh_display() {
        assert!(!super::needs_virtual_display());
        assert!(!super::is_driver_installed());
    }

    #[test]
    #[cfg(target_os = "windows")]
    fn driver_hwids_valid() {
        // Pastikan HWID tidak typo
        assert!(super::DRIVER_HWIDS.contains(&"IddSampleDriver"));
        assert!(super::DRIVER_HWIDS.contains(&"VirtualDisplayDriver"));
    }
}

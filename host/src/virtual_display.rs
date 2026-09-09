//! Virtual Display Driver — solusi hitam di VM/RDP seperti AnyDesk/RustDesk
//!
//! ## Kenapa perlu driver?
//! XyDesk v6.7.0 masih user-mode only (DXGI/WGC/GDI). Kalau sesi RDP tutup atau
//! VM tanpa monitor, Windows lock sesi → BitBlt hitam. AnyDesk/RustDesk bisa
//! tetap jalan karena mereka pakai WDDM Indirect Display Driver (IddCx) yang
//! bikin virtual display di kernel — framebuffer tetap ada walau lock.
//!
//! ## Implementasi v6.7.1+
//! Modul ini TIDAK bundle driver binary (butuh signing, size besar), tapi:
//! 1. Deteksi headless / RDP (pakai is_rdp_session + list_displays)
//! 2. Cek apakah virtual display driver sudah terinstal (IddSampleDriver /
//!    Virtual-Display-Driver dari itsmikethetech)
//! 3. Kalau admin + driver ada di `C:\Program Files\XyDesk\driver\` atau
//!    `./driver/`, install via pnputil
//! 4. Kalau driver sudah ada, buat virtual display via IOCTL / registry
//! 5. Fallback: log instruksi jelas untuk user pasang driver manual
//!
//! Driver yang didukung:
//! - https://github.com/itsmikethetech/Virtual-Display-Driver (rekomendasi, ada installer)
//! - https://github.com/roshkins/IddSampleDriver (ge9 fork, Scoop: `scoop install idd-sample-driver`)
//! - https://github.com/ge9/IddSampleDriver
//!
//! Setelah driver terpasang, Windows akan lihat DISPLAY tambahan walau tanpa
//! monitor fisik — DXGI & GDI fallback langsung dapat frame, tidak hitam lagi.

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
        displays.is_empty() || (rdp && displays.len() <= 1)
    }
    #[cfg(not(target_os = "windows"))]
    {
        false
    }
}

/// Cek apakah virtual display driver sudah terinstal
#[cfg(target_os = "windows")]
pub fn is_driver_installed() -> bool {
    // Cek via pnputil / EnumDisplayDevices / registry
    // 1. Cek driver store
    if let Ok(output) = Command::new("pnputil").arg("/enum-drivers").output() {
        let stdout = String::from_utf8_lossy(&output.stdout).to_lowercase();
        for hwid in DRIVER_HWIDS {
            if stdout.contains(&hwid.to_lowercase()) {
                return true;
            }
        }
    }
    // 2. Cek via display devices — kalau ada >1 dan salah satunya IddSampleDriver
    //    (nama device mengandung "Idd" atau "Virtual")
    let displays = crate::screen::list_displays();
    for d in &displays {
        let name = d.name.to_lowercase();
        if name.contains("idd") || name.contains("virtual") {
            return true;
        }
    }
    // 3. Cek file driver di lokasi umum
    let common_paths = [
        r"C:\Program Files\Virtual Display Driver\VirtualDisplayDriver.inf",
        r"C:\Program Files\IddSampleDriver\IddSampleDriver.inf",
        r"C:\Program Files\XyDesk\drivers\IddSampleDriver\iddsampledriver.inf",
        r"C:\IddSampleDriver\IddSampleDriver.inf",
        r"./drivers/IddSampleDriver/iddsampledriver.inf",
        r"../drivers/IddSampleDriver/iddsampledriver.inf",
        r"./driver/IddSampleDriver.inf",
        r"./driver/VirtualDisplayDriver.inf",
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
                // Coba devcon / Add Legacy Hardware via PowerShell
                eprintln!("[xydesk-host] pnputil gagal untuk {inf}: {stdout} {stderr}");
            }
        }
    }

    // Kalau tidak ada file inf, kasih instruksi download
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

/// Pastikan ada display — kalau headless, coba install driver atau kasih warning
#[cfg(target_os = "windows")]
pub fn ensure_display() {
    if !needs_virtual_display() {
        return;
    }

    eprintln!(
        "[xydesk-host] HEADLESS/RDP terdeteksi: {} monitor, RDP={}, driver_installed={}",
        crate::screen::list_displays().len(),
        crate::screen::is_rdp_session(),
        is_driver_installed()
    );

    if is_driver_installed() {
        println!(
            "[xydesk-host] virtual display driver sudah ada — DISPLAY virtual seharusnya tersedia"
        );
        return;
    }

    if is_admin() {
        match try_install_driver() {
            Ok(msg) => println!("[xydesk-host] {msg}"),
            Err(e) => eprintln!("[xydesk-host] virtual display: {e}"),
        }
    } else {
        eprintln!(
            "[xydesk-host] BUTUH virtual display driver untuk VM/RDP tanpa monitor.\n\
             Saat ini {} monitor, RDP={}. Install:\n\
             - https://github.com/itsmikethetech/Virtual-Display-Driver (installer exe)\n\
             - Atau Scoop: scoop install idd-sample-driver\n\
             - Jalankan sebagai admin, lalu restart XyDesk\n\
             \n\
             Sementara: GDI fallback GetDC(0) aktif, tapi akan hitam kalau sesi lock.\n\
             Di lab RDP, pakai tscon %SESSIONNAME% /dest:console untuk disconnect tanpa lock.",
            crate::screen::list_displays().len(),
            crate::screen::is_rdp_session()
        );
    }
}

#[cfg(not(target_os = "windows"))]
pub fn ensure_display() {}

/// Buat virtual display via driver IOCTL (kalau driver support)
///
/// Untuk itsmikethetech driver, ada app `VirtualDisplayDriver` yang bisa dipanggil
/// dengan argumen. Kita coba panggil kalau ada.
#[cfg(target_os = "windows")]
pub fn create_virtual_display(width: u32, height: u32, count: u32) -> Result<String, String> {
    // Coba cari executable driver manager
    let managers = [
        r"C:\Program Files\Virtual Display Driver\VirtualDisplayDriver.exe",
        r"C:\Program Files\IddSampleDriver\IddSampleDriver.exe",
        r"./driver/VirtualDisplayDriver.exe",
    ];

    for exe in managers {
        if std::path::Path::new(exe).exists() {
            // itsmikethetech driver: VirtualDisplayDriver.exe add 1 1920 1080
            let output = Command::new(exe)
                .args([
                    "add",
                    &count.to_string(),
                    &width.to_string(),
                    &height.to_string(),
                ])
                .output()
                .map_err(|e| format!("gagal jalankan {exe}: {e}"))?;
            if output.status.success() {
                return Ok(format!(
                    "virtual display {}x{} dibuat via {exe}",
                    width, height
                ));
            }
        }
    }

    // Fallback: coba via registry / config file driver itsmikethetech
    // Driver baca config dari %PROGRAMDATA%\VirtualDisplayDriver\config.json atau similar
    Err("virtual display manager tidak ditemukan — install driver dulu dari https://github.com/itsmikethetech/Virtual-Display-Driver".to_string())
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
}

//! Virtual display detection by adapter identity, not resolution or files.
//! Discovery never installs drivers, runs guessed manager commands, or restarts
//! services. A monitor must be visible in THIS interactive Windows session.

#[derive(Clone, Debug, serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Adapter {
    pub device: String,
    pub description: String,
    pub hardware_id: String,
    pub attached: bool,
    pub known_virtual: bool,
}

pub fn known_virtual(description: &str, hardware_id: &str) -> bool {
    let d = description.trim().to_ascii_lowercase();
    let id = hardware_id.to_ascii_lowercase();
    if d.contains("remote") || d.contains("rdp") {
        return false;
    }
    matches!(
        d.as_str(),
        "virtual display driver"
            | "iddsampledriver"
            | "mtt virtual display"
            | "mikethetech virtual display"
    ) || id.starts_with("root\\mttvdd")
        || id.starts_with("root\\iddsampledriver")
}

pub fn adapters() -> Vec<Adapter> {
    #[cfg(target_os = "windows")]
    {
        use windows::Win32::Graphics::Gdi::{
            EnumDisplayDevicesW, DISPLAY_DEVICEW, DISPLAY_DEVICE_ATTACHED_TO_DESKTOP,
        };
        let text = |v: &[u16]| {
            String::from_utf16_lossy(&v[..v.iter().position(|x| *x == 0).unwrap_or(v.len())])
        };
        let mut out = Vec::new();
        for i in 0..64 {
            let mut d = DISPLAY_DEVICEW {
                cb: std::mem::size_of::<DISPLAY_DEVICEW>() as u32,
                ..Default::default()
            };
            if !unsafe { EnumDisplayDevicesW(None, i, &mut d, 0) }.as_bool() {
                break;
            }
            let description = text(&d.DeviceString);
            let hardware_id = text(&d.DeviceID);
            out.push(Adapter {
                device: text(&d.DeviceName),
                attached: d.StateFlags.0 & DISPLAY_DEVICE_ATTACHED_TO_DESKTOP.0 != 0,
                known_virtual: known_virtual(&description, &hardware_id),
                description,
                hardware_id,
            });
        }
        out
    }
    #[cfg(not(target_os = "windows"))]
    {
        Vec::new()
    }
}

pub fn visible_virtual_displays() -> Vec<crate::screen::DisplayInfo> {
    let known = adapters();
    crate::screen::list_displays()
        .into_iter()
        .filter(|d| {
            known
                .iter()
                .any(|a| a.attached && a.known_virtual && a.device == d.name)
        })
        .collect()
}
pub fn needs_virtual_display() -> bool {
    crate::screen::is_rdp_session() || crate::screen::list_displays().is_empty()
}
/// Detected display adapter, not a guessed file/driver-store installation.
pub fn is_driver_installed() -> bool {
    adapters().iter().any(|a| a.known_virtual)
}
pub fn find_virtual_display() -> Option<crate::screen::DisplayInfo> {
    visible_virtual_displays().into_iter().next()
}
pub fn virtual_display_index() -> Option<usize> {
    find_virtual_display().map(|d| d.index)
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

pub fn try_install_driver() -> Result<String, String> {
    Err("Gunakan Setup-VirtualDisplay.ps1 -Install secara eksplisit sebagai Administrator. Discovery tidak memasang driver atau melemahkan keamanan Windows.".into())
}
pub fn ensure_virtual_display_created() -> bool {
    find_virtual_display().is_some()
}
pub fn ensure_display() {
    if needs_virtual_display() && find_virtual_display().is_none() {
        eprintln!("[xydesk-host] virtual display belum terlihat pada sesi ini. Driver console tidak selalu terlihat dari RDP; tidak ada restart, install, atau tscon otomatis.");
    }
}
pub fn create_virtual_display(width: u32, height: u32, count: u32) -> Result<String, String> {
    if count != 1 {
        return Err("Konfigurasi jumlah monitor dilakukan melalui driver; tidak ada perintah manager tebakan.".into());
    }
    if visible_virtual_displays()
        .iter()
        .any(|d| d.width == width && d.height == height)
    {
        Ok(format!("Virtual display aktif teramati {width}x{height}"))
    } else {
        Err("Display dengan ukuran yang diminta belum terlihat. Gunakan setup driver eksplisit lalu periksa --display-probe.".into())
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn identity_not_shape() {
        assert!(super::known_virtual(
            "Virtual Display Driver",
            "ROOT\\DISPLAY\\0001"
        ));
        assert!(super::known_virtual("IddSampleDriver", ""));
        for d in [
            "NVIDIA RTX",
            "Microsoft Remote Display Adapter",
            "RDP Virtual Display Driver",
            "Generic PnP Monitor",
            "DISPLAY2",
            "Some Virtual Device",
        ] {
            assert!(!super::known_virtual(d, ""), "{d}");
        }
    }
    #[test]
    fn hardware_id_and_remote_exclusion() {
        assert!(super::known_virtual("Adapter", "ROOT\\MTTVDD\\0000"));
        assert!(!super::known_virtual(
            "Remote adapter",
            "ROOT\\MTTVDD\\0000"
        ));
        assert!(!super::known_virtual("", "PCI\\VEN_10DE"));
    }
}

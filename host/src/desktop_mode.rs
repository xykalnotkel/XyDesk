//! Supported desktop mode requests, distinct from encoder canvas size.
//! No driver install, registry persistence, reboot, or RDP reconnect.
use std::sync::Mutex;

#[derive(Clone, Debug, serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Report {
    pub device: String,
    pub requested: [u32; 2],
    pub observed: Option<[u32; 2]>,
    pub status: &'static str,
}
static LAST: Mutex<Option<Report>> = Mutex::new(None);

pub fn requested_size(level: u8) -> [u32; 2] {
    if level >= 40 {
        [1920, 1080]
    } else {
        [1280, 720]
    }
}
fn outcome(
    supported: bool,
    accepted: bool,
    wanted: [u32; 2],
    actual: Option<[u32; 2]>,
) -> &'static str {
    if !supported {
        "unsupported"
    } else if !accepted {
        "rejected"
    } else if actual == Some(wanted) {
        "applied"
    } else {
        "unverified"
    }
}
pub fn request(device: String, level: u8) -> Report {
    let requested = requested_size(level);
    let report = platform_request(device, requested);
    *LAST
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner) = Some(report.clone());
    report
}
pub fn telemetry() -> Option<Report> {
    let mut report = LAST
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner)
        .clone()?;
    #[cfg(target_os = "windows")]
    {
        report.observed = observed(&report.device);
        if matches!(report.status, "applied" | "already")
            && report.observed != Some(report.requested)
        {
            report.status = "overridden";
        }
    }
    Some(report)
}
#[cfg(not(target_os = "windows"))]
fn platform_request(device: String, requested: [u32; 2]) -> Report {
    Report {
        device,
        requested,
        observed: None,
        status: "unavailable",
    }
}
#[cfg(target_os = "windows")]
fn observed(device: &str) -> Option<[u32; 2]> {
    crate::desktop_geometry::init_thread_dpi();
    crate::desktop_geometry::monitor_rect(device).map(|r| [r.width, r.height])
}
#[cfg(target_os = "windows")]
fn platform_request(device: String, requested: [u32; 2]) -> Report {
    use windows::{core::PCWSTR, Win32::Graphics::Gdi::*};
    crate::desktop_geometry::init_thread_dpi();
    let mut report = Report {
        observed: observed(&device),
        device,
        requested,
        status: "unsupported",
    };
    if report.observed == Some(requested) {
        report.status = "already";
        return report;
    }
    let wide: Vec<u16> = report.device.encode_utf16().chain(Some(0)).collect();
    let name = PCWSTR(wide.as_ptr());
    let mut current = DEVMODEW {
        dmSize: std::mem::size_of::<DEVMODEW>() as u16,
        ..Default::default()
    };
    unsafe {
        if !EnumDisplaySettingsW(name, ENUM_CURRENT_SETTINGS, &mut current).as_bool() {
            report.status = "unavailable";
            return report;
        }
        let mut candidate = None;
        for index in 0..1024 {
            let mut mode = DEVMODEW {
                dmSize: std::mem::size_of::<DEVMODEW>() as u16,
                ..Default::default()
            };
            if !EnumDisplaySettingsW(name, ENUM_DISPLAY_SETTINGS_MODE(index), &mut mode).as_bool() {
                break;
            }
            if [mode.dmPelsWidth, mode.dmPelsHeight] == requested
                && mode.dmBitsPerPel == current.dmBitsPerPel
                && mode.Anonymous1.Anonymous2.dmDisplayOrientation
                    == current.Anonymous1.Anonymous2.dmDisplayOrientation
            {
                // Prefer current refresh. Never manufacture an unsupported mode.
                if candidate.is_none() || mode.dmDisplayFrequency == current.dmDisplayFrequency {
                    candidate = Some(mode);
                }
                if mode.dmDisplayFrequency == current.dmDisplayFrequency {
                    break;
                }
            }
        }
        let Some(mut mode) = candidate else {
            return report;
        };
        // Do not alter position/orientation/topology; only the tested mode fields.
        mode.dmFields = DM_PELSWIDTH | DM_PELSHEIGHT | DM_BITSPERPEL | DM_DISPLAYFREQUENCY;
        if ChangeDisplaySettingsExW(name, Some(&mode), None, CDS_TEST, None)
            != DISP_CHANGE_SUCCESSFUL
        {
            report.status = "rejected";
            return report;
        }
        // No CDS_UPDATEREGISTRY. DISP_CHANGE_RESTART is a rejection, never a reboot.
        let accepted = ChangeDisplaySettingsExW(name, Some(&mode), None, CDS_TYPE(0), None)
            == DISP_CHANGE_SUCCESSFUL;
        for _ in 0..8 {
            report.observed = observed(&report.device);
            if !accepted || report.observed == Some(requested) {
                break;
            }
            std::thread::sleep(std::time::Duration::from_millis(125));
        }
        report.status = outcome(true, accepted, requested, report.observed);
    }
    report
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn only_exact_hd_targets() {
        assert_eq!(requested_size(31), [1280, 720]);
        assert_eq!(requested_size(40), [1920, 1080]);
        assert_eq!(requested_size(51), [1920, 1080]);
    }
    #[test]
    fn success_requires_observed_dimensions_not_just_api_success() {
        assert_eq!(
            outcome(true, true, [1920, 1080], Some([1920, 1080])),
            "applied"
        );
        assert_eq!(
            outcome(true, true, [1920, 1080], Some([2336, 1080])),
            "unverified"
        );
        assert_eq!(outcome(true, true, [1920, 1080], None), "unverified");
    }
    #[test]
    fn refusal_is_not_reported_as_applied() {
        assert_eq!(
            outcome(false, false, [1920, 1080], Some([1280, 720])),
            "unsupported"
        );
        assert_eq!(
            outcome(true, false, [1920, 1080], Some([1920, 1080])),
            "rejected"
        );
    }
}

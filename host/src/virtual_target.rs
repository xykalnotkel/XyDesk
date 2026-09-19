//! Explicit strict virtual720 mode. Refuse other sources rather than silently
//! streaming the RDP monitor. This does not bridge Windows session isolation.
use std::sync::Mutex;
static DEVICE: Mutex<Option<String>> = Mutex::new(None);
pub fn enabled() -> bool {
    DEVICE
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner)
        .is_some()
}
pub fn device() -> Option<String> {
    DEVICE
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner)
        .clone()
}

pub fn choose(
    displays: &[crate::screen::DisplayInfo],
    name: Option<&str>,
) -> Result<crate::screen::DisplayInfo, String> {
    let matches: Vec<_> = displays
        .iter()
        .filter(|d| name.is_none_or(|name| d.name == name))
        .collect();
    match matches.as_slice() {
        [d] => Ok((*d).clone()),
        [] => Err("Virtual display tidak terlihat dalam sesi host ini. Driver bisa aktif di console tetapi tersembunyi dari RDP. Jalankan --display-probe; tidak beralih diam-diam ke layar RDP.".into()),
        _ => Err("Lebih dari satu virtual display: pilih --virtual-display-device dengan nama dari --display-probe.".into()),
    }
}
pub fn prepare(name: Option<&str>) -> Result<(), String> {
    let selected = choose(&crate::virtual_display::visible_virtual_displays(), name)?;
    let report = crate::desktop_mode::request(selected.name.clone(), 31);
    if !matches!(report.status, "applied" | "already") || report.observed != Some([1280, 720]) {
        return Err(format!("Virtual720 belum siap: {report:?}"));
    }
    if !crate::screen::select_display(selected.index) {
        return Err("Virtual display menghilang saat pemilihan".into());
    }
    *DEVICE
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner) = Some(selected.name);
    Ok(())
}
pub fn permits_index(index: usize) -> bool {
    let Some(name) = device() else {
        return true;
    };
    crate::virtual_display::visible_virtual_displays()
        .iter()
        .any(|d| d.index == index && d.name == name && d.width == 1280 && d.height == 720)
}
pub fn accepts_rect(rect: crate::desktop_geometry::CaptureRect) -> bool {
    let Some(name) = device() else {
        return true;
    };
    let valid = crate::virtual_display::visible_virtual_displays()
        .iter()
        .any(|d| d.name == name && d.width == 1280 && d.height == 720);
    #[cfg(target_os = "windows")]
    {
        valid
            && crate::desktop_geometry::monitor_rect(&name) == Some(rect)
            && rect.width == 1280
            && rect.height == 720
    }
    #[cfg(not(target_os = "windows"))]
    {
        let _ = (valid, rect);
        false
    }
}
pub fn healthy() -> bool {
    let Some(name) = device() else {
        return true;
    };
    crate::virtual_display::visible_virtual_displays()
        .iter()
        .any(|d| d.name == name && d.width == 1280 && d.height == 720)
}
pub fn probe() -> serde_json::Value {
    serde_json::json!({"rdpSession":crate::screen::is_rdp_session(),"adapters":crate::virtual_display::adapters(),"displays":crate::screen::list_displays(),"visibleVirtual":crate::virtual_display::visible_virtual_displays(),"lockedDevice":device(),"target":[1280,720]})
}
#[cfg(test)]
mod tests {
    fn display(index: usize) -> crate::screen::DisplayInfo {
        crate::screen::DisplayInfo {
            index,
            name: format!("DISPLAY{index}"),
            width: 1280,
            height: 720,
            is_primary: false,
            refresh_rate: Some(60),
        }
    }
    #[test]
    fn refuses_missing_or_ambiguous_device() {
        assert!(super::choose(&[], None).is_err());
        assert!(super::choose(&[display(1), display(2)], None).is_err());
    }
    #[test]
    fn selects_by_name_not_monitor_number_guess() {
        assert_eq!(
            super::choose(&[display(1), display(2)], Some("DISPLAY2"))
                .unwrap()
                .index,
            2
        );
        assert!(super::choose(&[display(1)], Some("DISPLAY0")).is_err());
    }
}

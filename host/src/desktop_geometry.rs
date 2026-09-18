//! Satu ruang piksel fisik untuk capture dan injeksi, termasuk monitor di kiri.
use std::sync::Mutex;

#[derive(Clone, Copy, Debug, PartialEq, Eq, serde::Serialize)]
pub struct CaptureRect {
    pub left: i32,
    pub top: i32,
    pub width: u32,
    pub height: u32,
}
impl CaptureRect {
    pub fn point(self, x: u16, y: u16) -> Option<(i32, i32)> {
        if self.width == 0 || self.height == 0 {
            return None;
        }
        let axis = |origin: i32, size: u32, n: u16| {
            i32::try_from(i64::from(origin) + (i64::from(n) * i64::from(size - 1) + 32767) / 65535)
                .ok()
        };
        Some((
            axis(self.left, self.width, x)?,
            axis(self.top, self.height, y)?,
        ))
    }
}
static ACTIVE: Mutex<Option<CaptureRect>> = Mutex::new(None);
pub fn active() -> Option<CaptureRect> {
    *ACTIVE
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner)
}
pub fn publish(rect: Option<CaptureRect>) {
    *ACTIVE
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner) = rect;
}

#[cfg(target_os = "windows")]
pub fn init_process_dpi() {
    use windows::Win32::UI::HiDpi::{
        SetProcessDpiAwarenessContext, DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2,
    };
    // Hanya proses ini; tidak mengubah scaling atau resolusi desktop/RDP.
    let result =
        unsafe { SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2) };
    if result.is_err() {
        eprintln!("[xydesk-host] DPI process sudah ditetapkan; capture/input memakai konteks thread per-monitor");
    }
    init_thread_dpi();
}
#[cfg(not(target_os = "windows"))]
pub fn init_process_dpi() {}
#[cfg(target_os = "windows")]
pub fn init_thread_dpi() {
    use windows::Win32::UI::HiDpi::{
        SetThreadDpiAwarenessContext, DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2,
    };
    unsafe {
        SetThreadDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    }
}
#[cfg(not(target_os = "windows"))]
pub fn init_thread_dpi() {}

#[cfg(target_os = "windows")]
pub fn monitor_rect(name: &str) -> Option<CaptureRect> {
    use windows::{
        core::BOOL,
        Win32::{
            Foundation::LPARAM,
            Graphics::Gdi::{
                EnumDisplayMonitors, GetMonitorInfoW, HDC, HMONITOR, MONITORINFO, MONITORINFOEXW,
            },
        },
    };
    struct Search<'a> {
        name: &'a str,
        found: Option<CaptureRect>,
    }
    unsafe extern "system" fn visit(
        h: HMONITOR,
        _: HDC,
        _: *mut windows::Win32::Foundation::RECT,
        p: LPARAM,
    ) -> BOOL {
        let search = &mut *(p.0 as *mut Search<'_>);
        let mut info: MONITORINFOEXW = std::mem::zeroed();
        info.monitorInfo.cbSize = std::mem::size_of::<MONITORINFOEXW>() as u32;
        if GetMonitorInfoW(h, &mut info as *mut _ as *mut MONITORINFO).as_bool() {
            let device = String::from_utf16_lossy(&info.szDevice);
            let r = info.monitorInfo.rcMonitor;
            if device.trim_end_matches('\0') == search.name && r.right > r.left && r.bottom > r.top
            {
                search.found = Some(CaptureRect {
                    left: r.left,
                    top: r.top,
                    width: (r.right - r.left) as u32,
                    height: (r.bottom - r.top) as u32,
                });
                return BOOL(0);
            }
        }
        BOOL(1)
    }
    let mut search = Search { name, found: None };
    unsafe {
        let _ = EnumDisplayMonitors(
            None,
            None,
            Some(visit),
            LPARAM(&mut search as *mut _ as isize),
        );
    }
    search.found
}
#[cfg(target_os = "windows")]
pub fn virtual_rect() -> Option<CaptureRect> {
    use windows::Win32::UI::WindowsAndMessaging::{
        GetSystemMetrics, SM_CXVIRTUALSCREEN, SM_CYVIRTUALSCREEN, SM_XVIRTUALSCREEN,
        SM_YVIRTUALSCREEN,
    };
    let (left, top, w, h) = unsafe {
        (
            GetSystemMetrics(SM_XVIRTUALSCREEN),
            GetSystemMetrics(SM_YVIRTUALSCREEN),
            GetSystemMetrics(SM_CXVIRTUALSCREEN),
            GetSystemMetrics(SM_CYVIRTUALSCREEN),
        )
    };
    (w > 0 && h > 0).then_some(CaptureRect {
        left,
        top,
        width: w.max(0) as u32,
        height: h.max(0) as u32,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn secondary_negative_origin_endpoints_and_center() {
        let r = CaptureRect {
            left: -1920,
            top: -200,
            width: 1920,
            height: 1080,
        };
        assert_eq!(r.point(0, 0), Some((-1920, -200)));
        assert_eq!(r.point(65535, 65535), Some((-1, 879)));
        assert_eq!(r.point(32768, 32768), Some((-960, 340)));
    }
    #[test]
    fn one_pixel_invalid_and_overflow() {
        assert_eq!(
            CaptureRect {
                left: 10,
                top: 20,
                width: 1,
                height: 1
            }
            .point(65535, 0),
            Some((10, 20))
        );
        assert_eq!(
            CaptureRect {
                left: 0,
                top: 0,
                width: 0,
                height: 1
            }
            .point(1, 1),
            None
        );
        assert_eq!(
            CaptureRect {
                left: i32::MAX,
                top: 0,
                width: 2,
                height: 1
            }
            .point(65535, 0),
            None
        );
    }
    #[test]
    fn different_dpi_still_uses_physical_pixel_dimensions() {
        for (w, h) in [(1280, 720), (1920, 1080), (2336, 1080), (3840, 2160)] {
            let r = CaptureRect {
                left: 300,
                top: 100,
                width: w,
                height: h,
            };
            assert_eq!(
                r.point(65535, 65535),
                Some((300 + w as i32 - 1, 100 + h as i32 - 1))
            );
        }
    }
}

/// Posisi cursor yang dibaca dari Windows; None when capture is not active.
#[cfg(target_os = "windows")]
pub fn cursor_feedback() -> Option<serde_json::Value> {
    use windows::Win32::UI::WindowsAndMessaging::{GetCursorInfo, CURSORINFO, CURSOR_SHOWING};
    init_thread_dpi();
    let rect = active()?;
    let mut info = CURSORINFO {
        cbSize: std::mem::size_of::<CURSORINFO>() as u32,
        ..Default::default()
    };
    unsafe { GetCursorInfo(&mut info) }.ok()?;
    let x = i64::from(info.ptScreenPos.x) - i64::from(rect.left);
    let y = i64::from(info.ptScreenPos.y) - i64::from(rect.top);
    let visible = info.flags == CURSOR_SHOWING
        && x >= 0
        && y >= 0
        && x < i64::from(rect.width)
        && y < i64::from(rect.height);
    Some(
        serde_json::json!({"type":"cursor","x":x.max(0).min(i64::from(rect.width.saturating_sub(1))) as f64/rect.width.saturating_sub(1).max(1) as f64,"y":y.max(0).min(i64::from(rect.height.saturating_sub(1))) as f64/rect.height.saturating_sub(1).max(1) as f64,"visible":visible}),
    )
}
#[cfg(not(target_os = "windows"))]
pub fn cursor_feedback() -> Option<serde_json::Value> {
    None
}

//! XyDesk untuk Windows — GUI NATIVE Win32 murni (tanpa WebView/browser).
//!
//! Keputusan owner setelah WebView gagal ("Failed to fetch", terasa asing):
//! satu jendela native yang menampilkan identitas host dan menjaga engine
//! tetap hidup (always-on). Semua jaringan dilakukan dari Rust (ureq +
//! rustls) — tidak ada CORS, tidak ada preflight, tidak ada browser.
//!
//! Arsitektur: EXE ini adalah launcher + panel; engine streaming tetap
//! `xydesk-host.exe` (proses terpisah, di-supervisi thread watchdog).

#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

#[cfg(not(target_os = "windows"))]
fn main() {
    eprintln!("xydesk (GUI) hanya untuk Windows.");
}

#[cfg(target_os = "windows")]
mod win {

    use std::process::{Child, Command, Stdio};
    use std::sync::atomic::{AtomicBool, Ordering};
    use std::sync::Mutex;

    use windows::core::{w, PCWSTR};
    use windows::Win32::Foundation::{COLORREF, HWND, LPARAM, LRESULT, WPARAM};
    use windows::Win32::Graphics::Gdi::{
        BeginPaint, CreateFontW, CreateSolidBrush, DeleteObject, EndPaint, FillRect,
        InvalidateRect, SelectObject, SetBkMode, SetTextColor, TextOutW, CLEARTYPE_QUALITY,
        FF_DONTCARE, FW_BOLD, FW_NORMAL, HBRUSH, HFONT, HGDIOBJ, PAINTSTRUCT, TRANSPARENT,
    };
    use windows::Win32::System::DataExchange::{
        CloseClipboard, EmptyClipboard, OpenClipboard, SetClipboardData,
    };
    use windows::Win32::System::LibraryLoader::GetModuleHandleW;
    use windows::Win32::System::Memory::{GlobalAlloc, GlobalLock, GlobalUnlock, GMEM_MOVEABLE};
    use windows::Win32::UI::WindowsAndMessaging::{
        CreateWindowExW, DefWindowProcW, DispatchMessageW, GetMessageW, LoadCursorW,
        PostQuitMessage, RegisterClassW, SetTimer, ShowWindow, TranslateMessage, CW_USEDEFAULT,
        IDC_ARROW, MSG, SW_SHOW, WINDOW_EX_STYLE, WM_COMMAND, WM_DESTROY, WM_LBUTTONUP, WM_PAINT,
        WM_TIMER, WNDCLASSW, WS_CAPTION, WS_MINIMIZEBOX, WS_SYSMENU, WS_VISIBLE,
    };

    const SIGNALING_HTTP: &str = "https://signal.xystudio.my.id";
    const SIGNALING_WS: &str = "wss://signal.xystudio.my.id/ws";

    // ── Palet Quiet Surface (COLORREF = 0x00BBGGRR) ──
    const BG: u32 = 0x00120A0B; // #0B0A12
    const SURFACE: u32 = 0x001F1416; // #16141F
    const TEXT_HI: u32 = 0x00F4F2F2; // #F2F2F4
    const TEXT_MID: u32 = 0x00ABA2A2; // #A2A2AB
    const ACCENT: u32 = 0x00F65476; // #7654F6
    const SUCCESS: u32 = 0x007AA94F; // #4FA97A
    const DANGER: u32 = 0x0068_5FD8; // #D85F68

    static ENGINE_OK: AtomicBool = AtomicBool::new(false);
    static LAST_ERR: Mutex<String> = Mutex::new(String::new());
    static IDENTITY: Mutex<Option<(String, String)>> = Mutex::new(None); // (id, password)
    static SHOW_PW: AtomicBool = AtomicBool::new(false);

    const TIMER_WATCHDOG: usize = 1;

    fn engine_exe() -> Option<std::path::PathBuf> {
        let me = std::env::current_exe().ok()?;
        let dir = me.parent()?;
        for c in [
            dir.join("Host").join("XyDesk-Host.exe"),
            dir.join("xydesk-host.exe"),
        ] {
            if c.exists() {
                return Some(c);
            }
        }
        None
    }

    fn no_window(cmd: &mut Command) {
        use std::os::windows::process::CommandExt;
        const CREATE_NO_WINDOW: u32 = 0x0800_0000;
        cmd.creation_flags(CREATE_NO_WINDOW);
    }

    /// Identitas dari engine (--identity-json), sekali di awal.
    fn load_identity() {
        let Some(exe) = engine_exe() else {
            *LAST_ERR.lock().unwrap() = "XyDesk-Host.exe tidak ditemukan.".into();
            return;
        };
        let mut cmd = Command::new(&exe);
        cmd.arg("--identity-json")
            .stdout(Stdio::piped())
            .stderr(Stdio::null());
        no_window(&mut cmd);
        if let Ok(out) = cmd.output() {
            if let Ok(v) = serde_json::from_slice::<serde_json::Value>(&out.stdout) {
                let id = v["deviceId"].as_str().unwrap_or("").to_string();
                let pw = v["password"].as_str().unwrap_or("").to_string();
                if !id.is_empty() {
                    *IDENTITY.lock().unwrap() = Some((id, pw));
                    return;
                }
            }
        }
        *LAST_ERR.lock().unwrap() = "Identitas host tidak terbaca.".into();
    }

    /// Tukar id+password -> token signaling host. Rust murni, tanpa browser.
    fn fetch_host_token(id: &str, pw: &str) -> Result<String, String> {
        let resp = ureq::post(&format!("{SIGNALING_HTTP}/host-token"))
            .send_json(ureq::json!({ "id": id, "claim": pw }))
            .map_err(|e| match e {
                ureq::Error::Status(403, _) => {
                    "Password tidak cocok dengan klaim device.".to_string()
                }
                ureq::Error::Status(code, _) => format!("Server menolak (HTTP {code})."),
                _ => "Tidak dapat menghubungi server.".to_string(),
            })?;
        resp.into_string()
            .map(|s| s.trim().to_string())
            .map_err(|e| e.to_string())
    }

    /// Watchdog: pastikan engine hidup; start ulang dengan token baru bila mati.
    fn ensure_engine(child_slot: &Mutex<Option<Child>>) {
        let mut guard = child_slot.lock().unwrap();
        if let Some(c) = guard.as_mut() {
            if matches!(c.try_wait(), Ok(None)) {
                ENGINE_OK.store(true, Ordering::Relaxed);
                return;
            }
        }
        ENGINE_OK.store(false, Ordering::Relaxed);
        let Some((id, pw)) = IDENTITY.lock().unwrap().clone() else {
            return;
        };
        let token = match fetch_host_token(&id, &pw) {
            Ok(t) => t,
            Err(e) => {
                *LAST_ERR.lock().unwrap() = e;
                return;
            }
        };
        let Some(exe) = engine_exe() else { return };
        let mut cmd = Command::new(&exe);
        cmd.arg("--url")
            .arg(SIGNALING_WS)
            .arg("--token")
            .arg(&token);
        cmd.stdout(Stdio::null()).stderr(Stdio::null());
        no_window(&mut cmd);
        match cmd.spawn() {
            Ok(c) => {
                *guard = Some(c);
                ENGINE_OK.store(true, Ordering::Relaxed);
                LAST_ERR.lock().unwrap().clear();
            }
            Err(e) => *LAST_ERR.lock().unwrap() = format!("Gagal start engine: {e}"),
        }
    }

    fn copy_to_clipboard(hwnd: HWND, text: &str) {
        let wide: Vec<u16> = text.encode_utf16().chain(std::iter::once(0)).collect();
        unsafe {
            if OpenClipboard(Some(hwnd)).is_ok() {
                let _ = EmptyClipboard();
                if let Ok(h) = GlobalAlloc(GMEM_MOVEABLE, wide.len() * 2) {
                    let p = GlobalLock(h) as *mut u16;
                    if !p.is_null() {
                        std::ptr::copy_nonoverlapping(wide.as_ptr(), p, wide.len());
                        let _ = GlobalUnlock(h);
                        // CF_UNICODETEXT = 13
                        let _ = SetClipboardData(13, Some(windows::Win32::Foundation::HANDLE(h.0)));
                    }
                }
                let _ = CloseClipboard();
            }
        }
    }

    struct Fonts {
        title: HFONT,
        id_big: HFONT,
        label: HFONT,
        body: HFONT,
    }

    fn make_font(height: i32, weight: u32) -> HFONT {
        unsafe {
            CreateFontW(
                height,
                0,
                0,
                0,
                weight as i32,
                0,
                0,
                0,
                0,
                0,
                0,
                CLEARTYPE_QUALITY.0 as u32,
                FF_DONTCARE.0 as u32,
                w!("Segoe UI"),
            )
        }
    }

    fn draw_text(
        hdc: windows::Win32::Graphics::Gdi::HDC,
        font: HFONT,
        color: u32,
        x: i32,
        y: i32,
        s: &str,
    ) {
        let wide: Vec<u16> = s.encode_utf16().collect();
        unsafe {
            let old: HGDIOBJ = SelectObject(hdc, font.into());
            SetTextColor(hdc, COLORREF(color));
            SetBkMode(hdc, TRANSPARENT);
            let _ = TextOutW(hdc, x, y, &wide);
            SelectObject(hdc, old);
        }
    }

    fn pretty_id(id: &str) -> String {
        let d: String = id.chars().filter(|c| c.is_ascii_digit()).collect();
        if d.len() == 9 {
            format!("{} {} {}", &d[0..3], &d[3..6], &d[6..9])
        } else {
            id.to_string()
        }
    }

    unsafe extern "system" fn wndproc(hwnd: HWND, msg: u32, wp: WPARAM, lp: LPARAM) -> LRESULT {
        static CHILD: Mutex<Option<Child>> = Mutex::new(None);
        match msg {
            WM_TIMER => {
                if wp.0 == TIMER_WATCHDOG {
                    std::thread::spawn(|| {
                        static SLOT: Mutex<Option<Child>> = Mutex::new(None);
                        ensure_engine(&SLOT);
                    });
                    let _ = InvalidateRect(Some(hwnd), None, false);
                }
                LRESULT(0)
            }
            WM_LBUTTONUP => {
                let x = (lp.0 & 0xFFFF) as i16 as i32;
                let y = ((lp.0 >> 16) & 0xFFFF) as i16 as i32;
                // Tombol "Salin" ID (area) & toggle password (area)
                if (330..430).contains(&x) && (150..185).contains(&y) {
                    if let Some((id, _)) = IDENTITY.lock().unwrap().clone() {
                        copy_to_clipboard(hwnd, &id);
                    }
                } else if (330..430).contains(&x) && (230..265).contains(&y) {
                    let cur = SHOW_PW.load(Ordering::Relaxed);
                    SHOW_PW.store(!cur, Ordering::Relaxed);
                    let _ = InvalidateRect(Some(hwnd), None, false);
                } else if (240..430).contains(&x) && (270..305).contains(&y) {
                    if let Some((_, pw)) = IDENTITY.lock().unwrap().clone() {
                        copy_to_clipboard(hwnd, &pw);
                    }
                }
                LRESULT(0)
            }
            WM_PAINT => {
                let mut ps = PAINTSTRUCT::default();
                let hdc = BeginPaint(hwnd, &mut ps);
                let bg: HBRUSH = CreateSolidBrush(COLORREF(BG));
                FillRect(hdc, &ps.rcPaint, bg);
                let _ = DeleteObject(bg.into());

                let fonts = Fonts {
                    title: make_font(-26, FW_BOLD.0),
                    id_big: make_font(-40, FW_BOLD.0),
                    label: make_font(-13, FW_BOLD.0),
                    body: make_font(-15, FW_NORMAL.0),
                };

                draw_text(hdc, fonts.title, TEXT_HI, 28, 22, "XyDesk");
                let (status_txt, status_col) = if ENGINE_OK.load(Ordering::Relaxed) {
                    ("HOST AKTIF", SUCCESS)
                } else {
                    ("MENYAMBUNG…", TEXT_MID)
                };
                draw_text(hdc, fonts.label, status_col, 330, 32, status_txt);
                draw_text(
                    hdc,
                    fonts.body,
                    TEXT_MID,
                    28,
                    56,
                    "Selalu aktif selama jendela ini terbuka",
                );

                // Kartu identitas (digambar sederhana: blok surface)
                let card = windows::Win32::Foundation::RECT {
                    left: 20,
                    top: 96,
                    right: 440,
                    bottom: 320,
                };
                let sb: HBRUSH = CreateSolidBrush(COLORREF(SURFACE));
                FillRect(hdc, &card, sb);
                let _ = DeleteObject(sb.into());

                let ident = IDENTITY.lock().unwrap().clone();
                match ident {
                    Some((id, pw)) => {
                        draw_text(hdc, fonts.label, ACCENT, 36, 112, "ID PERANGKAT");
                        draw_text(hdc, fonts.id_big, TEXT_HI, 36, 134, &pretty_id(&id));
                        draw_text(hdc, fonts.label, TEXT_MID, 340, 158, "[ Salin ]");

                        draw_text(hdc, fonts.label, ACCENT, 36, 210, "PASSWORD PAIRING");
                        let shown = if SHOW_PW.load(Ordering::Relaxed) {
                            pw
                        } else {
                            "••••••••".into()
                        };
                        draw_text(hdc, fonts.body, TEXT_HI, 36, 234, &shown);
                        draw_text(hdc, fonts.label, TEXT_MID, 340, 236, "[ Lihat ]");
                        draw_text(hdc, fonts.label, TEXT_MID, 240, 276, "[ Salin password ]");
                    }
                    None => {
                        let err = LAST_ERR.lock().unwrap().clone();
                        draw_text(
                            hdc,
                            fonts.body,
                            DANGER,
                            36,
                            140,
                            if err.is_empty() {
                                "Memuat identitas…"
                            } else {
                                &err
                            },
                        );
                    }
                }

                let err = LAST_ERR.lock().unwrap().clone();
                if !err.is_empty() && IDENTITY.lock().unwrap().is_some() {
                    draw_text(hdc, fonts.body, DANGER, 28, 336, &err);
                    draw_text(hdc, fonts.body, TEXT_MID, 28, 358, "Dicoba ulang otomatis…");
                } else {
                    draw_text(
                        hdc,
                        fonts.body,
                        TEXT_MID,
                        28,
                        336,
                        "Masukkan ID + password di XyDesk Android / app.xystudio.my.id",
                    );
                }

                for f in [fonts.title, fonts.id_big, fonts.label, fonts.body] {
                    let _ = DeleteObject(f.into());
                }
                let _ = EndPaint(hwnd, &ps);
                LRESULT(0)
            }
            WM_DESTROY => {
                // Matikan engine saat jendela ditutup.
                if let Some(mut c) = CHILD.lock().unwrap().take() {
                    let _ = c.kill();
                }
                PostQuitMessage(0);
                LRESULT(0)
            }
            WM_COMMAND => LRESULT(0),
            _ => DefWindowProcW(hwnd, msg, wp, lp),
        }
    }

    pub fn main() -> windows::core::Result<()> {
        load_identity();
        // Start engine segera di thread terpisah (always-on dari detik pertama).
        std::thread::spawn(|| {
            static SLOT: Mutex<Option<Child>> = Mutex::new(None);
            ensure_engine(&SLOT);
        });

        unsafe {
            let hinstance = GetModuleHandleW(None)?;
            let class = w!("XyDeskMain");
            let wc = WNDCLASSW {
                hInstance: hinstance.into(),
                lpszClassName: class,
                lpfnWndProc: Some(wndproc),
                hCursor: LoadCursorW(None, IDC_ARROW)?,
                hbrBackground: CreateSolidBrush(COLORREF(BG)),
                ..Default::default()
            };
            RegisterClassW(&wc);

            let hwnd = CreateWindowExW(
                WINDOW_EX_STYLE::default(),
                class,
                w!("XyDesk"),
                WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX | WS_VISIBLE,
                CW_USEDEFAULT,
                CW_USEDEFAULT,
                478,
                430,
                None,
                None,
                Some(hinstance.into()),
                None,
            )?;
            let _ = ShowWindow(hwnd, SW_SHOW);
            SetTimer(Some(hwnd), TIMER_WATCHDOG, 5000, None);

            let mut msg = MSG::default();
            while GetMessageW(&mut msg, None, 0, 0).into() {
                let _ = TranslateMessage(&msg);
                DispatchMessageW(&msg);
            }
        }
        Ok(())
    }
}

#[cfg(target_os = "windows")]
fn main() -> windows::core::Result<()> {
    win::main()
}

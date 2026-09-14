pub mod auth;
pub mod commands;
pub mod engine;
pub mod tray;
pub mod update;

use auth::AuthManager;
use engine::EngineSupervisor;
use std::sync::Arc;
use tauri::{Manager, WindowEvent};

/// Tulis satu baris log diagnostik ke `%TEMP%/xydesk-startup.log`.
///
/// Di Windows GUI (`windows_subsystem = "windows"`) stderr tidak terlihat
/// dan panic keluar tanpa pesan apa pun — file ini satu-satunya jejak saat
/// aplikasi mati diam-diam ("kedip lalu hilang").
fn temp_log(line: &str) {
    use std::io::Write;
    if let Ok(mut f) = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(std::env::temp_dir().join("xydesk-startup.log"))
    {
        let _ = writeln!(f, "[{:?}] {line}", std::time::SystemTime::now());
    }
}

/// Kotak pesan native Windows (user32) tanpa dependensi tambahan.
/// Mengembalikan id tombol yang ditekan (6 = IDYES), atau 0 bila gagal.
#[cfg(target_os = "windows")]
fn message_box(caption: &str, text: &str, flags: u32) -> i32 {
    use std::os::windows::ffi::OsStrExt;

    #[link(name = "user32")]
    extern "system" {
        fn MessageBoxW(hwnd: isize, text: *const u16, caption: *const u16, flags: u32) -> i32;
    }

    let text_w: Vec<u16> = std::ffi::OsStr::new(text)
        .encode_wide()
        .chain(std::iter::once(0))
        .collect();
    let cap_w: Vec<u16> = std::ffi::OsStr::new(caption)
        .encode_wide()
        .chain(std::iter::once(0))
        .collect();
    unsafe { MessageBoxW(0, text_w.as_ptr(), cap_w.as_ptr(), flags) }
}

/// CLSID komponen WebView2 Evergreen di registry (dokumentasi Microsoft).
#[cfg(target_os = "windows")]
const WEBVIEW2_CLSID: &str = "{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}";

/// Apakah runtime WebView2 Evergreen terpasang di mesin ini?
///
/// Tauri tidak bisa membuat jendela tanpa WebView2 — prosesnya langsung
/// keluar tanpa pesan, yang di layar pengguna terlihat sebagai "kedip".
/// Nilai `pv` "0.0.0.0" / kosong berarti runtime belum benar-benar ada.
#[cfg(target_os = "windows")]
fn webview2_installed() -> bool {
    use winreg::enums::{HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE};
    use winreg::RegKey;

    let paths = [
        format!("SOFTWARE\\WOW6432Node\\Microsoft\\EdgeUpdate\\Clients\\{WEBVIEW2_CLSID}"),
        format!("SOFTWARE\\Microsoft\\EdgeUpdate\\Clients\\{WEBVIEW2_CLSID}"),
    ];
    for root in [HKEY_LOCAL_MACHINE, HKEY_CURRENT_USER] {
        let hkey = RegKey::predef(root);
        for path in &paths {
            if let Ok(sub) = hkey.open_subkey(path) {
                if let Ok(pv) = sub.get_value::<String, _>("pv") {
                    let berarti = pv.split('.').any(|segmen| segmen != "0");
                    if !pv.is_empty() && berarti {
                        return true;
                    }
                }
            }
        }
    }
    false
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    // Jangan biarkan panic masa depan hilang tanpa jejak: catat ke log
    // temp dan (di Windows) tunjukkan kotak pesan — subsystem GUI
    // menyembunyikan stderr, jadi panic dulu terlihat seperti "kedip".
    std::panic::set_hook(Box::new(|info| {
        let msg = format!("panic: {info}");
        temp_log(&msg);
        eprintln!("[XyDesk] {msg}");
        #[cfg(target_os = "windows")]
        message_box(
            "XyDesk gagal berjalan",
            &format!(
                "Terjadi kesalahan fatal saat memulai XyDesk:\n\n{info}\n\n\
                 Rincian dicatat di %TEMP%\\xydesk-startup.log"
            ),
            0x10, // MB_ICONERROR
        );
    }));

    temp_log("run() mulai");

    // Tanpa WebView2 Tauri keluar tanpa pesan apa pun (gejala "kedip").
    // Deteksi dulu dan jelaskan ke pengguna apa yang harus dipasang.
    #[cfg(target_os = "windows")]
    if !webview2_installed() {
        temp_log("WebView2 TIDAK ditemukan — keluar dengan penjelasan");
        let jawab = message_box(
            "XyDesk butuh WebView2",
            "XyDesk memerlukan komponen Microsoft Edge WebView2 yang belum \
             terpasang di Windows ini, jadi jendela tidak bisa ditampilkan.\n\n\
             Buka tautan unduhan penginstal WebView2 sekarang?",
            0x24, // MB_YESNO | MB_ICONQUESTION
        );
        if jawab == 6 {
            let _ = open::that("https://go.microsoft.com/fwlink/p/?LinkId=2124703");
        }
        std::process::exit(9);
    }

    let engine_supervisor = Arc::new(EngineSupervisor::new());
    let auth_manager = Arc::new(AuthManager::new());

    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_autostart::init(
            tauri_plugin_autostart::MacosLauncher::LaunchAgent,
            Some(vec!["--minimized"]),
        ))
        .manage(engine_supervisor.clone())
        .manage(auth_manager)
        .setup(move |app| {
            temp_log("setup() mulai");
            // Start engine supervisor inside Tauri runtime (fix panic: no reactor running)
            engine_supervisor.start();
            let handle = app.handle();
            if let Err(e) = tray::setup_tray(handle) {
                temp_log(&format!("gagal setup tray: {e}"));
                eprintln!("[XyDesk] gagal setup tray: {e}");
            }
            // Pastikan window utama nampak (fix Tauri pindah: window kadang hidden)
            if let Some(win) = handle.get_webview_window("main") {
                let _ = win.show();
                let _ = win.set_focus();
            } else {
                temp_log("window 'main' tidak ditemukan di setup");
                eprintln!("[XyDesk] window 'main' tidak ditemukan di setup");
            }
            temp_log("setup() selesai");
            Ok(())
        })
        .on_window_event(|window, event| {
            if let WindowEvent::CloseRequested { api, .. } = event {
                // Sembunyi ke system tray alih-alih menutup aplikasi
                api.prevent_close();
                let _ = window.hide();
            }
        })
        .invoke_handler(tauri::generate_handler![
            commands::get_status,
            commands::run_action,
            commands::get_logs,
            commands::get_info,
            commands::get_autostart,
            commands::set_autostart,
            commands::restart_engine,
            commands::set_hint,
            commands::check_drivers_status,
            commands::install_driver,
            commands::auth_session,
            commands::auth_google,
            commands::auth_email_request,
            commands::auth_email_verify,
            commands::auth_logout,
            commands::check_update,
            commands::download_update,
            commands::install_update,
        ])
        .run(tauri::generate_context!())
        .expect("gagal menjalankan aplikasi Tauri XyDesk");
}

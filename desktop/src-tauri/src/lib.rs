pub mod auth;
pub mod commands;
pub mod engine;
pub mod tray;
pub mod update;

use auth::AuthManager;
use engine::EngineSupervisor;
use std::sync::Arc;
use tauri::{Manager, WindowEvent};

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
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
            // Start engine supervisor inside Tauri runtime (fix panic: no reactor running)
            engine_supervisor.start();
            let handle = app.handle();
            let _ = tray::setup_tray(handle);
            // Pastikan window utama nampak (fix Tauri pindah: window kadang hidden)
            if let Some(win) = handle.get_webview_window("main") {
                let _ = win.show();
                let _ = win.set_focus();
                // Log untuk diagnosa: tulis ke file temp kalau gagal
                if let Err(e) = win.show() {
                    eprintln!("[XyDesk] gagal show window: {e}");
                }
            } else {
                eprintln!("[XyDesk] window 'main' tidak ditemukan di setup");
            }
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

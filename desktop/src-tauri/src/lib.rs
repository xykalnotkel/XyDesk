pub mod auth;
pub mod commands;
pub mod engine;
pub mod tray;

use auth::AuthManager;
use engine::EngineSupervisor;
use std::sync::Arc;
use tauri::{Manager, WindowEvent};

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let engine_supervisor = Arc::new(EngineSupervisor::new());
    engine_supervisor.start();

    let auth_manager = Arc::new(AuthManager::new());

    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_autostart::init(
            tauri_plugin_autostart::MacosLauncher::LaunchAgent,
            Some(vec!["--minimized"]),
        ))
        .manage(engine_supervisor)
        .manage(auth_manager)
        .setup(|app| {
            let handle = app.handle();
            let _ = tray::setup_tray(handle);
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
            commands::auth_session,
            commands::auth_google,
            commands::auth_email_request,
            commands::auth_email_verify,
            commands::auth_logout,
        ])
        .run(tauri::generate_context!())
        .expect("gagal menjalankan aplikasi Tauri XyDesk");
}

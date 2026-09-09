use tauri::menu::{Menu, MenuItem};
use tauri::tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent};
use tauri::{AppHandle, Manager, Wry};

pub fn setup_tray(app: &AppHandle) -> Result<(), Box<dyn std::error::Error>> {
    let show_i = MenuItem::with_id(app, "show", "Buka XyDesk", true, None::<&str>)?;
    let stop_i = MenuItem::with_id(app, "stop_session", "Akhiri Sesi Aktif", true, None::<&str>)?;
    let quit_i = MenuItem::with_id(app, "quit", "Keluar", true, None::<&str>)?;

    let menu = Menu::with_items(app, &[&show_i, &stop_i, &quit_i])?;

    let _tray = TrayIconBuilder::<Wry>::with_id("xydesk-tray")
        .tooltip("XyDesk Host")
        .icon(app.default_window_icon().unwrap().clone())
        .menu(&menu)
        .show_menu_on_left_click(false)
        .on_menu_event(|app, event| match event.id.as_ref() {
            "show" => {
                if let Some(window) = app.get_webview_window("main") {
                    let _ = window.show();
                    let _ = window.set_focus();
                }
            }
            "stop_session" => {
                let app_handle = app.clone();
                tauri::async_runtime::spawn(async move {
                    if let Some(engine) = app_handle.try_state::<std::sync::Arc<crate::engine::EngineSupervisor>>() {
                        let _ = engine.run_action(serde_json::json!({ "action": "stop-session" })).await;
                    }
                });
            }
            "quit" => {
                app.exit(0);
            }
            _ => {}
        })
        .on_tray_icon_event(|tray, event| {
            if let TrayIconEvent::Click {
                button: MouseButton::Left,
                button_state: MouseButtonState::Up,
                ..
            } = event
            {
                let app = tray.app_handle();
                if let Some(window) = app.get_webview_window("main") {
                    let _ = window.show();
                    let _ = window.set_focus();
                }
            }
        })
        .build(app)?;

    Ok(())
}

use crate::auth::{AuthManager, AuthSessionResponse};
use crate::engine::{EngineSupervisor, InfoPayload, LogEntry};
use std::sync::Arc;
use tauri::State;

#[tauri::command]
pub async fn get_status(
    engine: State<'_, Arc<EngineSupervisor>>,
) -> Result<serde_json::Value, String> {
    engine.get_status().await
}

#[tauri::command]
pub async fn run_action(
    req: serde_json::Value,
    engine: State<'_, Arc<EngineSupervisor>>,
) -> Result<serde_json::Value, String> {
    engine.run_action(req).await
}

#[tauri::command]
pub async fn get_logs(engine: State<'_, Arc<EngineSupervisor>>) -> Result<Vec<LogEntry>, String> {
    Ok(engine.get_logs().await)
}

#[tauri::command]
pub async fn get_info(engine: State<'_, Arc<EngineSupervisor>>) -> Result<InfoPayload, String> {
    Ok(engine.get_info())
}

#[tauri::command]
pub async fn get_autostart() -> Result<bool, String> {
    #[cfg(target_os = "windows")]
    {
        // Cek registry Run entry
        Ok(true)
    }
    #[cfg(not(target_os = "windows"))]
    {
        Ok(false)
    }
}

#[tauri::command]
pub async fn set_autostart(enable: bool) -> Result<bool, String> {
    // Pengaturan autostart
    Ok(enable)
}

#[tauri::command]
pub async fn restart_engine(
    engine: State<'_, Arc<EngineSupervisor>>,
) -> Result<bool, String> {
    // Supervisor loop akan otomatis restart saat proses berhenti
    let _ = engine.run_action(serde_json::json!({ "action": "stop-session" })).await;
    Ok(true)
}

#[tauri::command]
pub async fn set_hint(_hint: serde_json::Value) -> Result<(), String> {
    Ok(())
}

#[tauri::command]
pub async fn auth_session(
    auth: State<'_, Arc<AuthManager>>,
) -> Result<AuthSessionResponse, String> {
    Ok(auth.get_session().await)
}

#[tauri::command]
pub async fn auth_google(
    auth: State<'_, Arc<AuthManager>>,
) -> Result<AuthSessionResponse, String> {
    auth.login_google().await
}

#[tauri::command]
pub async fn auth_email_request(
    email: String,
    name: Option<String>,
    auth: State<'_, Arc<AuthManager>>,
) -> Result<serde_json::Value, String> {
    auth.request_email_otp(&email, name.as_deref()).await
}

#[tauri::command]
pub async fn auth_email_verify(
    email: String,
    otp: String,
    name: Option<String>,
    auth: State<'_, Arc<AuthManager>>,
) -> Result<serde_json::Value, String> {
    auth.verify_email_otp(&email, &otp, name.as_deref()).await
}

#[tauri::command]
pub async fn auth_logout(auth: State<'_, Arc<AuthManager>>) -> Result<bool, String> {
    Ok(auth.logout().await)
}

// ── Pembaruan aplikasi ───────────────────────────────────────────────

#[tauri::command]
pub async fn check_update() -> Result<crate::update::UpdateStatus, String> {
    crate::update::check_update().await
}

#[tauri::command]
pub async fn download_update() -> Result<String, String> {
    crate::update::download_update().await
}

#[tauri::command]
pub fn install_update(path: String) -> Result<(), String> {
    crate::update::install_update(path)
}

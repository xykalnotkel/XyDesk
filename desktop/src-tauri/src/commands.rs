use crate::auth::{AuthManager, AuthSessionResponse};
use crate::engine::{EngineSupervisor, InfoPayload, LogEntry};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tauri::State;

#[derive(Clone, Serialize, Deserialize, Debug)]
pub struct DriversStatusResponse {
    pub vdd_installed: bool,
    pub audio_installed: bool,
    pub is_admin: bool,
    pub can_install: bool,
}

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
        Ok(true)
    }
    #[cfg(not(target_os = "windows"))]
    {
        Ok(false)
    }
}

#[tauri::command]
pub async fn set_autostart(enable: bool) -> Result<bool, String> {
    Ok(enable)
}

#[tauri::command]
pub async fn restart_engine(
    engine: State<'_, Arc<EngineSupervisor>>,
) -> Result<bool, String> {
    let _ = engine.run_action(serde_json::json!({ "action": "stop-session" })).await;
    Ok(true)
}

#[tauri::command]
pub async fn set_hint(_hint: serde_json::Value) -> Result<(), String> {
    Ok(())
}

#[tauri::command]
pub async fn check_drivers_status() -> Result<DriversStatusResponse, String> {
    #[cfg(target_os = "windows")]
    {
        use std::process::Command;

        let mut vdd_installed = false;
        if let Ok(output) = Command::new("pnputil").arg("/enum-drivers").output() {
            let stdout = String::from_utf8_lossy(&output.stdout).to_lowercase();
            if stdout.contains("iddsampledriver") || stdout.contains("virtualdisplaydriver") {
                vdd_installed = true;
            }
        }

        let audio_installed = std::path::Path::new(r"C:\Program Files\VB\CABLE\VBCABLE_Setup_x64.exe").exists()
            || std::path::Path::new(r"C:\Program Files\VB\CABLE\VBCABLE_Setup.exe").exists();

        let is_admin = match Command::new("powershell")
            .args([
                "-NoProfile",
                "-NonInteractive",
                "-Command",
                "([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)",
            ])
            .output()
        {
            Ok(out) => String::from_utf8_lossy(&out.stdout).trim().eq_ignore_ascii_case("True"),
            Err(_) => false,
        };

        Ok(DriversStatusResponse {
            vdd_installed,
            audio_installed,
            is_admin,
            can_install: true,
        })
    }
    #[cfg(not(target_os = "windows"))]
    {
        Ok(DriversStatusResponse {
            vdd_installed: false,
            audio_installed: false,
            is_admin: false,
            can_install: false,
        })
    }
}

#[tauri::command]
pub async fn install_driver(driver_type: String) -> Result<String, String> {
    #[cfg(target_os = "windows")]
    {
        use std::process::Command;

        let exe_dir = std::env::current_exe()
            .ok()
            .and_then(|p| p.parent().map(|d| d.to_path_buf()))
            .unwrap_or_else(|| std::path::PathBuf::from("."));

        let vdd_bat = [
            exe_dir.join("drivers").join("IddSampleDriver").join("install.bat"),
            exe_dir.join("..").join("drivers").join("IddSampleDriver").join("install.bat"),
            std::path::PathBuf::from(r"C:\Program Files\XyDesk\drivers\IddSampleDriver\install.bat"),
            std::path::PathBuf::from(r"packaging\windows\drivers\IddSampleDriver\install.bat"),
        ]
        .into_iter()
        .find(|p| p.exists());

        let audio_bat = [
            exe_dir.join("drivers").join("audio").join("install-audio.bat"),
            exe_dir.join("..").join("drivers").join("audio").join("install-audio.bat"),
            std::path::PathBuf::from(r"C:\Program Files\XyDesk\drivers\audio\install-audio.bat"),
            std::path::PathBuf::from(r"packaging\windows\drivers\audio\install-audio.bat"),
        ]
        .into_iter()
        .find(|p| p.exists());

        let mut results = Vec::new();

        if driver_type == "vdd" || driver_type == "all" {
            if let Some(bat) = vdd_bat {
                let cmd = format!(
                    "Start-Process -FilePath '{}' -ArgumentList '/silent' -Verb RunAs -Wait",
                    bat.display()
                );
                let out = Command::new("powershell")
                    .args(["-NoProfile", "-NonInteractive", "-Command", &cmd])
                    .output()
                    .map_err(|e| format!("Gagal memanggil PowerShell untuk VDD: {e}"))?;
                if out.status.success() {
                    results.push("Driver Virtual Display berhasil dipasang.".to_string());
                } else {
                    results.push(format!(
                        "Driver Virtual Display gagal dipasang: {}",
                        String::from_utf8_lossy(&out.stderr)
                    ));
                }
            } else {
                results.push("Berkas instalasi driver Virtual Display tidak ditemukan.".to_string());
            }
        }

        if driver_type == "audio" || driver_type == "all" {
            if let Some(bat) = audio_bat {
                let cmd = format!(
                    "Start-Process -FilePath '{}' -Verb RunAs -Wait",
                    bat.display()
                );
                let out = Command::new("powershell")
                    .args(["-NoProfile", "-NonInteractive", "-Command", &cmd])
                    .output()
                    .map_err(|e| format!("Gagal memanggil PowerShell untuk Audio: {e}"))?;
                if out.status.success() {
                    results.push("Driver Virtual Audio & Mic berhasil dipasang.".to_string());
                } else {
                    results.push(format!(
                        "Driver Virtual Audio gagal dipasang: {}",
                        String::from_utf8_lossy(&out.stderr)
                    ));
                }
            } else {
                results.push("Berkas instalasi driver Virtual Audio tidak ditemukan.".to_string());
            }
        }

        Ok(results.join(" "))
    }
    #[cfg(not(target_os = "windows"))]
    {
        Err("Instalasi driver hanya berlaku pada sistem operasi Windows.".to_string())
    }
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

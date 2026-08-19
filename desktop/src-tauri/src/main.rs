// XyDesk Desktop — shell Tauri (WebView2) untuk Windows.
//
// UI (Vite, folder ../src) memanggil command di bawah untuk mengelola engine
// host native (XyDesk-Host.exe, Rust — folder /host repo). Menggantikan
// runner Flutter Windows yang crash fail-fast (0xC0000409) di mesin tanpa
// GPU dedicated.

#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::process::{Child, Command, Stdio};
use std::sync::Mutex;

use serde::Serialize;
use tauri::State;

/// Jangan buka jendela console saat menjalankan engine (program konsol).
/// Tanpa flag ini setiap pemanggilan memunculkan CMD window sekejap.
#[cfg(windows)]
fn hide_console(cmd: &mut Command) {
    use std::os::windows::process::CommandExt;
    const CREATE_NO_WINDOW: u32 = 0x0800_0000;
    cmd.creation_flags(CREATE_NO_WINDOW);
}

#[cfg(not(windows))]
fn hide_console(_cmd: &mut Command) {}

/// Proses engine host yang sedang berjalan (bila ada).
struct EngineState(Mutex<Option<Child>>);

#[derive(Serialize)]
struct EngineStatus {
    running: bool,
    pid: Option<u32>,
}

/// Lokasi XyDesk-Host.exe: berdampingan dengan EXE desktop (layout installer:
/// {app}\xydesk-desktop.exe + {app}\Host\XyDesk-Host.exe).
fn host_exe_path() -> Result<std::path::PathBuf, String> {
    let me = std::env::current_exe().map_err(|e| e.to_string())?;
    let dir = me.parent().ok_or("EXE tanpa direktori induk")?;
    for candidate in [
        dir.join("Host").join("XyDesk-Host.exe"),
        dir.join("XyDesk-Host.exe"),
    ] {
        if candidate.exists() {
            return Ok(candidate);
        }
    }
    Err("XyDesk-Host.exe tidak ditemukan di samping aplikasi.".into())
}

/// Identitas host (ID 9 digit + password pairing) dari `--identity-json`.
#[tauri::command]
fn host_identity() -> Result<serde_json::Value, String> {
    let exe = host_exe_path()?;
    let mut cmd = Command::new(&exe);
    cmd.arg("--identity-json")
        .stdout(Stdio::piped())
        .stderr(Stdio::null());
    hide_console(&mut cmd);
    let out = cmd
        .output()
        .map_err(|e| format!("gagal menjalankan engine: {e}"))?;
    let text = String::from_utf8_lossy(&out.stdout);
    serde_json::from_str(text.trim()).map_err(|e| format!("identitas tidak valid: {e}"))
}

/// Mulai engine host (register ke signaling; siap menerima pairing).
#[tauri::command]
fn start_engine(
    state: State<EngineState>,
    url: String,
    token: String,
) -> Result<EngineStatus, String> {
    let mut guard = state.0.lock().map_err(|e| e.to_string())?;
    if let Some(child) = guard.as_mut() {
        if child.try_wait().map_err(|e| e.to_string())?.is_none() {
            return Ok(EngineStatus {
                running: true,
                pid: Some(child.id()),
            });
        }
    }
    let exe = host_exe_path()?;
    let mut cmd = Command::new(&exe);
    cmd.arg("--url").arg(&url);
    if !token.is_empty() {
        cmd.arg("--token").arg(&token);
    }
    cmd.stdout(Stdio::null()).stderr(Stdio::null());
    hide_console(&mut cmd);
    let child = cmd
        .spawn()
        .map_err(|e| format!("gagal start engine: {e}"))?;
    let pid = child.id();
    *guard = Some(child);
    Ok(EngineStatus {
        running: true,
        pid: Some(pid),
    })
}

/// Hentikan engine host.
#[tauri::command]
fn stop_engine(state: State<EngineState>) -> Result<EngineStatus, String> {
    let mut guard = state.0.lock().map_err(|e| e.to_string())?;
    if let Some(mut child) = guard.take() {
        let _ = child.kill();
        let _ = child.wait();
    }
    Ok(EngineStatus {
        running: false,
        pid: None,
    })
}

/// Status engine saat ini.
#[tauri::command]
fn engine_status(state: State<EngineState>) -> Result<EngineStatus, String> {
    let mut guard = state.0.lock().map_err(|e| e.to_string())?;
    if let Some(child) = guard.as_mut() {
        if child.try_wait().map_err(|e| e.to_string())?.is_none() {
            return Ok(EngineStatus {
                running: true,
                pid: Some(child.id()),
            });
        }
        *guard = None;
    }
    Ok(EngineStatus {
        running: false,
        pid: None,
    })
}

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .manage(EngineState(Mutex::new(None)))
        .invoke_handler(tauri::generate_handler![
            host_identity,
            start_engine,
            stop_engine,
            engine_status
        ])
        .run(tauri::generate_context!())
        .expect("gagal menjalankan XyDesk Desktop");
}

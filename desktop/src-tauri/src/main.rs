// Matikan jendela konsol cmd di Windows release
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::fs::OpenOptions;
use std::io::Write;

fn main() {
    // Log startup for debugging Windows launch issues (since Tauri window hidden)
    if let Ok(mut f) = std::fs::OpenOptions::new().create(true).append(true).open(std::env::temp_dir().join("xydesk-main.log")) {
        let _ = std::io::Write::writeln(&mut f, "[{:?}] main() start", std::time::SystemTime::now());
    }
    xydesk_desktop_lib::run();
}

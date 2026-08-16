//! Identitas host — ID perangkat stabil + PIN pairing per sesi.
//!
//! - **Device ID** digenerasi sekali (acak), disimpan ke `~/.xydesk/device_id`
//!   (Windows: `%USERPROFILE%\.xydesk\device_id`). ID ini stabil antar-run,
//!   sehingga perangkat dikenali konsisten oleh client & server signaling.
//! - **PIN** (6 digit) digenerasi baru setiap aplikasi host dibuka. PIN ini
//!   yang diketik pengguna di app client untuk pairing (atau discan via QR
//!   di Fase berikutnya). PIN bersifat sesi, bukan rahasia permanen.

use std::fs;
use std::path::PathBuf;

use rand::Rng;

/// Muat ID perangkat yang sudah ada, atau buat + simpan yang baru.
pub fn load_or_create_device_id() -> String {
    let path = config_dir().join("device_id");
    if let Ok(raw) = fs::read_to_string(&path) {
        let id = raw.trim().to_string();
        if !id.is_empty() {
            return id;
        }
    }
    let id = format!("xydesk-{:08x}", rand::thread_rng().gen::<u32>());
    let _ = fs::create_dir_all(config_dir());
    let _ = fs::write(&path, &id);
    id
}

/// Generate PIN pairing 6 digit (baru setiap sesi host dibuka).
pub fn generate_pin() -> String {
    format!("{:06}", rand::thread_rng().gen_range(0..1_000_000))
}

/// Direktori konfigurasi host (lintas platform, tanpa crate tambahan).
fn config_dir() -> PathBuf {
    let base = std::env::var("USERPROFILE")
        .or_else(|_| std::env::var("HOME"))
        .unwrap_or_else(|_| ".".to_string());
    PathBuf::from(base).join(".xydesk")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pin_is_six_digits() {
        for _ in 0..100 {
            let pin = generate_pin();
            assert_eq!(pin.len(), 6, "PIN harus 6 digit");
            assert!(pin.chars().all(|c| c.is_ascii_digit()), "PIN harus angka");
        }
    }

    #[test]
    fn device_id_format() {
        let id = load_or_create_device_id();
        assert!(id.starts_with("xydesk-"), "ID harus berawalan xydesk-");
    }
}

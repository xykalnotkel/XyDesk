//! Identitas host — ID perangkat (9 digit) + password pairing.
//!
//! - **Device ID**: 9 digit acak, unik per perangkat, disimpan permanen ke
//!   `~/.xydesk/device_id` (Windows: `%USERPROFILE%\.xydesk\device_id`).
//!   Ditampilkan berkelompok `123 456 789` agar mudah diketik di HP.
//!   Nilai kanonik (tanpa spasi) dipakai sebagai id di signaling.
//! - **Password**: acak saat pertama kali host dibuka, disimpan permanen ke
//!   `~/.xydesk/password`. Bisa diganti kapan saja (customize) lewat
//!   `--set-password` atau digenerasi ulang lewat `--new-password`.
//!
//! ID + password inilah yang diketik pengguna di aplikasi client (HP) untuk
//! pairing.

use std::fs;
use std::path::PathBuf;

use rand::Rng;

/// Panjang ID perangkat (digit).
pub const ID_LEN: usize = 9;
/// Panjang minimum password.
pub const PW_MIN_LEN: usize = 6;

// Charset password: tanpa karakter yang mudah tertukar (I/O/0/1).
const PW_CHARS: &[u8] = b"ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

/// Muat ID perangkat yang sudah ada, atau buat + simpan yang baru.
/// Mengembalikan 9 digit (tanpa spasi).
pub fn load_or_create_device_id() -> String {
    let path = config_dir().join("device_id");
    if let Ok(raw) = fs::read_to_string(&path) {
        let id: String = raw.chars().filter(|c| c.is_ascii_digit()).collect();
        if id.len() == ID_LEN {
            return id;
        }
    }
    let id = generate_id();
    let _ = fs::create_dir_all(config_dir());
    let _ = fs::write(&path, &id);
    id
}

/// Generate ID perangkat 9 digit acak.
pub fn generate_id() -> String {
    let mut rng = rand::thread_rng();
    let mut s = String::with_capacity(ID_LEN);
    for _ in 0..ID_LEN {
        s.push(char::from(b'0' + rng.gen_range(0..10)));
    }
    s
}

/// Format "123456789" → "123 456 789" (untuk ditampilkan).
pub fn format_id(id: &str) -> String {
    let digits: String = id.chars().filter(|c| c.is_ascii_digit()).collect();
    digits
        .as_bytes()
        .chunks(3)
        .map(|c| std::str::from_utf8(c).unwrap_or("").to_string())
        .collect::<Vec<_>>()
        .join(" ")
}

/// Muat password yang sudah ada, atau buat + simpan yang baru.
pub fn load_or_create_password() -> String {
    let path = config_dir().join("password");
    if let Ok(raw) = fs::read_to_string(&path) {
        let pw = raw.trim().to_string();
        if pw.len() >= PW_MIN_LEN {
            return pw;
        }
    }
    let pw = generate_password();
    let _ = fs::create_dir_all(config_dir());
    let _ = fs::write(&path, &pw);
    pw
}

/// Generate password acak (8 karakter, tanpa karakter membingungkan).
pub fn generate_password() -> String {
    let mut rng = rand::thread_rng();
    (0..8)
        .map(|_| PW_CHARS[rng.gen_range(0..PW_CHARS.len())] as char)
        .collect()
}

/// Set password kustom (persisten). Gagal bila < 6 karakter.
pub fn set_password(pw: &str) -> std::io::Result<()> {
    if pw.len() < PW_MIN_LEN {
        return Err(std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            format!("password minimal {PW_MIN_LEN} karakter"),
        ));
    }
    fs::create_dir_all(config_dir())?;
    fs::write(config_dir().join("password"), pw)
}

/// Direktori konfigurasi host (lintas platform, tanpa crate tambahan).
fn config_dir() -> PathBuf {
    let base = std::env::var("USERPROFILE")
        .or_else(|_| std::env::var("HOME"))
        .unwrap_or_else(|_| ".".to_string());
    PathBuf::from(base).join(".xydesk")
}

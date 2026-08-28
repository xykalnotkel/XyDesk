//! XyDesk host — library publik.
//!
//! Modul dipisah dari binary (`main.rs`) agar komponen sesi WebRTC, input,
//! identitas perangkat, dan sumber video tetap terstruktur.

pub mod identity;
pub mod input;
pub mod pairedpeers;
pub mod pairguard;
pub mod screen;
pub mod session;

// Tipe data FFI NVENC (layout diverifikasi vs header C — test jalan di semua
// platform). Driver NVENC sendiri hanya untuk Windows.
#[allow(non_camel_case_types, dead_code, non_snake_case)]
pub mod nvenc_types;
#[cfg(target_os = "windows")]
pub mod nvenc;

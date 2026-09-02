//! XyDesk host — library publik.
//!
//! Modul dipisah dari binary (`main.rs`) agar komponen sesi WebRTC, input,
//! identitas perangkat, dan sumber video tetap terstruktur.

pub mod audio;
pub mod clipboard;
pub mod control;
pub mod identity;
pub mod input;
/// FFI libopus vendor (dikompilasi build.rs; dipakai audio.rs di Windows).
pub mod opus_ffi;
pub mod pairedpeers;
pub mod pairguard;
/// Konversi format piksel (RGBA → NV12) untuk jalur encode NVENC.
pub mod pixfmt;
pub mod screen;
pub mod session;

// Tipe data FFI NVENC (layout diverifikasi vs header C — test jalan di semua
// platform). Driver NVENC sendiri hanya untuk Windows.
#[cfg(target_os = "windows")]
pub mod nvenc;
#[allow(
    non_camel_case_types,
    dead_code,
    non_snake_case,
    clippy::upper_case_acronyms
)]
pub mod nvenc_types;

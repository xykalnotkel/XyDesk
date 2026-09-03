//! XyDesk host — library publik.
//!
//! Modul dipisah dari binary (`main.rs`) agar komponen sesi WebRTC, input,
//! identitas perangkat, dan sumber video tetap terstruktur.

use std::sync::{Mutex, MutexGuard};

/// Kunci sebuah [`Mutex`] tanpa panik bila mutex ter-poison.
///
/// Untuk host yang harus **SELALU AKTIF**, satu panic di task media (video/
/// audio/input) tidak boleh merobohkan seluruh proses. Mutex yang ter-poison
/// berarti thread pemegangnya panik di tengah seksi kritis — datanya masih
/// utuh dan layak dipakai. Helper ini mengembalikan guard biasa sehingga
/// seksi kritis berikutnya tetap jalan.
pub fn recover_lock<T>(m: &Mutex<T>) -> MutexGuard<'_, T> {
    m.lock().unwrap_or_else(std::sync::PoisonError::into_inner)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn recover_lock_pulih_dari_mutex_terpoison() {
        let m = Mutex::new(42u32);
        // Poison mutex: panik saat guard masih dipegang.
        let res = std::panic::catch_unwind(|| {
            let _g = m.lock().unwrap();
            panic!("boom saat memegang kunci");
        });
        assert!(res.is_err());
        // Data tetap bisa dibaca dan ditulis tanpa panik.
        {
            let mut g = recover_lock(&m);
            assert_eq!(*g, 42);
            *g = 7;
        }
        assert_eq!(*recover_lock(&m), 7);
    }
}

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
pub mod video;

// Tipe data FFI NVENC (layout diverifikasi vs header C — test jalan di semua
// platform). Driver NVENC sendiri hanya untuk Windows.
#[cfg(target_os = "windows")]
pub mod nvenc;
/// Konstanta, status, dan perakit konfigurasi NVENC — lintas platform, teruji.
pub mod nvenc_config;
#[allow(
    non_camel_case_types,
    dead_code,
    non_snake_case,
    clippy::upper_case_acronyms
)]
pub mod nvenc_types;

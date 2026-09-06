//! Pemeriksa tipe lintas-target untuk kode `cfg(target_os = "windows")` host.
//!
//! `cargo check`/`cargo clippy` dengan `--target x86_64-pc-windows-msvc`
//! melakukan type-check penuh terhadap API Win32 **tanpa** linker, MSVC, atau
//! mesin Windows: fase check tidak menghasilkan kode dan tidak menautkan apa
//! pun. Yang dibutuhkan hanya `rustup target add x86_64-pc-windows-msvc`
//! (std untuk target itu) dan crate `windows` yang murni Rust.
//!
//! Modul host disertakan lewat `#[path]` langsung dari sumbernya, jadi yang
//! diperiksa adalah kode yang benar-benar dikirim — bukan salinan yang bisa
//! menyimpang diam-diam.
//!
//! Batas yang harus diingat: ini memeriksa TIPE, bukan perilaku. Salah nama
//! field, salah tipe parameter, salah fitur Cargo → tertangkap. Salah logika,
//! salah urutan panggilan COM, kebocoran handle, atau API yang mengembalikan
//! HRESULT gagal saat runtime → TIDAK tertangkap; itu urusan job Windows dan
//! uji di mesin sungguhan.

#[path = "../../../host/src/pixfmt.rs"]
pub mod pixfmt;

#[path = "../../../host/src/hwinfo.rs"]
pub mod hwinfo;

/// Primitif capture GDI: seluruh kode `unsafe` Win32-nya terperiksa di sini.
/// `screen.rs` (pemanggilnya) tidak bisa ikut karena menarik webrtc + openh264.
#[path = "../../../host/src/gdi.rs"]
pub mod gdi;

/// Cermin ekspresi `screen.rs::list_displays` untuk menandai monitor utama.
///
/// Ditulis di sini karena `screen.rs` tidak bisa disertakan utuh (ia menarik
/// separuh crate host: webrtc, openh264, encoder). Ekspresinya disalin persis
/// supaya perubahan tipe `dwFlags` di crate `windows` tertangkap di sini lebih
/// dulu. Bila `screen.rs` berubah, ubah juga fungsi ini.
#[cfg(target_os = "windows")]
pub fn primary_bit_ok(info: &windows::Win32::Graphics::Gdi::MONITORINFOEXW) -> bool {
    (info.monitorInfo.dwFlags & 0x1) != 0
}

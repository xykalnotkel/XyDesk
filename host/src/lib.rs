//! XyDesk host — library publik.
//!
//! Modul dipisah dari binary (`main.rs`) agar bisa diuji lewat
//! integration test (`tests/`). Lihat `session.rs` (WebRTC) dan `screen.rs`
//! (sumber video).

pub mod identity;
pub mod input;
pub mod screen;
pub mod session;

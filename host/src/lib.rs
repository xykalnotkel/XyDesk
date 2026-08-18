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

//! Capture & encode layar — Windows-only, BELUM diimplementasi.
//!
//! Ini adalah peta jalan yang sudah dipelajari, bukan kode jadi. Urutan yang
//! disarankan (lihat README):
//!
//!   1. `windows-capture` crate untuk DXGI Desktop Duplication.
//!   2. FFmpeg (`ffmpeg-next`) dengan `h264_nvenc -preset p1 -tune ll` untuk
//!      PoC — paling cepat membuktikan latency, ganti ke NVENC SDK nanti.
//!   3. `webrtc` crate: dorong frame ke `VideoTrack` sebagai RTP.
//!
//! Rancangan modul (tulis implementasinya di sini, satu per satu):

#[cfg(target_os = "windows")]
mod windows_impl {
    // pub async fn capture_loop() -> ...
    //   1. buat D3D11 device + duplication
    //   2. AcquireNextFrame (timeout 8 ms)
    //   3. kirim texture ke encoder (zero-copy)
    //   -> diukur: berapa ms per frame?
    // pub async fn encode_loop() -> ...
    //   NVENC/AMF/QuickSync; fallback openh264
    // pub async fn stream_loop() -> ...
    //   SampleBuilder -> VideoTrack.WriteSample -> RTP
}

#[cfg(not(target_os = "windows"))]
mod windows_impl {
    // Di platform lain modul ini kosong; compile tetap sukses agar
    // signaling client (main.rs) bisa diuji di CI Linux.
}

pub use windows_impl::*;

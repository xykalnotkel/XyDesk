//! Compile-only WASAPI check, not a substitute for Windows device tests.
#[path = "../../../host/src/audio.rs"] pub mod audio;
#[path = "../../../host/src/pcmconv.rs"] pub mod pcmconv;
#[path = "../../../host/src/opus_ffi.rs"] pub mod opus_ffi;
// Routing is validated in the full host. This checker isolates Win32 ABI.
pub mod virtual_mic {
    pub fn ensure_virtual_mic() {}
    pub fn get_render_device_id() -> Option<String> { None }
}

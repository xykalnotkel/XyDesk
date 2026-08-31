//! Pembungkus FFI tipis untuk libopus yang di-vendor (`vendor/opus`,
//! dikompilasi statis oleh `build.rs` khusus target Windows).
//!
//! Hanya memakai API inti yang dibutuhkan XyDesk: encoder & decoder
//! 48 kHz stereo (OPUS_APPLICATION_AUDIO). Tidak ada `opus_encoder_ctl`
//! (variadik) — bitrate default Opus (≈96 kbps stereo 48 kHz) sudah pas
//! untuk forward audio sistem.
//!
//! Deklarasi tangan agar TIDAK bergantung pada crate `opus` yang menarik
//! `audiopus_sys` (build CMake-nya gagal di runner Windows modern).

#![allow(non_camel_case_types)]

#[cfg_attr(target_os = "windows", link(name = "opus", kind = "static"))]
extern "C" {
    fn opus_encoder_create(
        fs: i32,
        channels: i32,
        application: i32,
        error: *mut i32,
    ) -> *mut OpusEncoderState;
    fn opus_encode(
        st: *mut OpusEncoderState,
        pcm: *const i16,
        frame_size: i32,
        data: *mut u8,
        max_data_bytes: i32,
    ) -> i32;
    fn opus_encoder_destroy(st: *mut OpusEncoderState);
    fn opus_decoder_create(fs: i32, channels: i32, error: *mut i32) -> *mut OpusDecoderState;
    fn opus_decode(
        st: *mut OpusDecoderState,
        data: *const u8,
        len: i32,
        pcm: *mut i16,
        frame_size: i32,
        decode_fec: i32,
    ) -> i32;
    fn opus_decoder_destroy(st: *mut OpusDecoderState);
}

#[repr(C)]
struct OpusEncoderState {
    _priv: [u8; 0],
}

#[repr(C)]
struct OpusDecoderState {
    _priv: [u8; 0],
}

/// OPUS_APPLICATION_AUDIO — profil untuk musik/audio sistem.
const OPUS_APPLICATION_AUDIO: i32 = 2049;

/// Encoder Opus — satu instance per sesi audio.
pub struct Encoder {
    st: *mut OpusEncoderState,
    channels: usize,
}

// libopus thread-safe per-instance; encoder dipakai dari satu thread
// capture — aman menandai Send agar bisa dipegang lintas task.
unsafe impl Send for Encoder {}

impl Encoder {
    pub fn new(sample_rate: u32, channels: usize) -> Result<Self, String> {
        let mut err: i32 = 0;
        let st = unsafe {
            opus_encoder_create(
                sample_rate as i32,
                channels as i32,
                OPUS_APPLICATION_AUDIO,
                &mut err,
            )
        };
        if st.is_null() || err != 0 {
            return Err(format!("opus_encoder_create gagal (kode {err})"));
        }
        Ok(Self { st, channels })
    }

    /// Encode `pcm` (interleaved i16) menjadi satu paket Opus.
    /// `pcm.len()` harus kelipatan `channels`.
    pub fn encode(&mut self, pcm: &[i16], out: &mut [u8]) -> Result<usize, i32> {
        let frame_size = (pcm.len() / self.channels) as i32;
        let n = unsafe {
            opus_encode(
                self.st,
                pcm.as_ptr(),
                frame_size,
                out.as_mut_ptr(),
                out.len() as i32,
            )
        };
        if n < 0 {
            Err(n)
        } else {
            Ok(n as usize)
        }
    }
}

impl Drop for Encoder {
    fn drop(&mut self) {
        unsafe { opus_encoder_destroy(self.st) };
    }
}

/// Decoder Opus — satu instance per sesi (mic passthrough).
pub struct Decoder {
    st: *mut OpusDecoderState,
    channels: usize,
}

unsafe impl Send for Decoder {}

impl Decoder {
    pub fn new(sample_rate: u32, channels: usize) -> Result<Self, String> {
        let mut err: i32 = 0;
        let st = unsafe { opus_decoder_create(sample_rate as i32, channels as i32, &mut err) };
        if st.is_null() || err != 0 {
            return Err(format!("opus_decoder_create gagal (kode {err})"));
        }
        Ok(Self { st, channels })
    }

    /// Decode satu paket Opus; kembalikan JUMLAH SAMPEL per channel yang
    /// ditulis (pcm = interleaved, panjang = n * channels).
    pub fn decode(&mut self, data: &[u8], pcm: &mut [i16]) -> Result<usize, i32> {
        let frame_size = (pcm.len() / self.channels) as i32;
        let n = unsafe {
            opus_decode(
                self.st,
                data.as_ptr(),
                data.len() as i32,
                pcm.as_mut_ptr(),
                frame_size,
                0,
            )
        };
        if n < 0 {
            Err(n)
        } else {
            Ok(n as usize)
        }
    }
}

impl Drop for Decoder {
    fn drop(&mut self) {
        unsafe { opus_decoder_destroy(self.st) };
    }
}

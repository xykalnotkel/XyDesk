//! Sumber frame video.
//!
//! Dua mode, dipilih otomatis berdasar platform:
//!   - **Non-Windows / test**: [TestPatternEncoder] — menghasilkan pola uji
//!     (I420) lalu di-encode H264 memakai openh264 (software, tanpa GPU).
//!     Ini membuktikan jalur `capture → encode → RTP` bekerja end-to-end.
//!   - **Windows**: DXGI Desktop Duplication + NVENC (lihat catatan di bawah).

use openh264::encoder::{Encoder, EncoderConfig};
use openh264::formats::YUVBuffer;

/// Lebar/tinggi default pola uji (kecil agar encode cepat; cukup untuk
/// membuktikan jalur video).
pub const TEST_WIDTH: usize = 320;
pub const TEST_HEIGHT: usize = 180;

/// Encoder pola uji — menghasilkan frame H264 (Annex-B) dari pola I420.
///
/// Ini adalah "sumber frame" pengganti sementara sampai DXGI diimplementasi
/// di Windows. Output-nya sudah siap ditulis ke `TrackLocalStaticSample`
/// (lihat `Session::add_video_track`).
pub struct TestPatternEncoder {
    encoder: Encoder,
    frame_index: u64,
}

impl TestPatternEncoder {
    pub fn new() -> Result<Self, openh264::Error> {
        let config = EncoderConfig::new();
        let encoder = Encoder::with_api_config(openh264::OpenH264API::from_source(), config)?;
        Ok(Self {
            encoder,
            frame_index: 0,
        })
    }

    /// Encode satu frame pola uji. Mengembalikan bitstream H264 (Annex-B).
    pub fn encode_next(&mut self, width: usize, height: usize) -> Result<Vec<u8>, openh264::Error> {
        let yuv = self.make_pattern(width, height, self.frame_index);
        self.frame_index = self.frame_index.wrapping_add(1);
        Ok(self.encoder.encode(&yuv)?.to_vec())
    }

    /// Bangun frame I420: latar abu-abu + bilah bergerak (posisi bergeser tiap
    /// frame) agar terlihat "hidup" saat di-decode di client.
    fn make_pattern(&self, width: usize, height: usize, frame: u64) -> YUVBuffer {
        let mut yuv = vec![128u8; width * height * 3 / 2];
        // Y plane (luma)
        let bar_x = ((frame as usize) * 8) % width;
        for y in 0..height {
            for x in 0..width {
                let luma = if x >= bar_x && x < bar_x + 24 {
                    220 // bilah terang
                } else {
                    60 + ((x * 160 / width) as u8) // gradasi horizontal
                };
                yuv[y * width + x] = luma;
            }
        }
        // U & V plane (chroma netral → gambar abu-abu)
        let uv_start = width * height;
        let uv_len = (width / 2) * (height / 2);
        for i in 0..uv_len {
            yuv[uv_start + i] = 128;
            yuv[uv_start + uv_len + i] = 128;
        }
        YUVBuffer::from_vec(yuv, width, height)
    }
}

/// Status implementasi sumber video pada platform ini.
pub fn capture_status() -> &'static str {
    #[cfg(target_os = "windows")]
    {
        "windows-dxgi (belum diimplementasi — lihat host/README.md)"
    }
    #[cfg(not(target_os = "windows"))]
    {
        "test-pattern (openh264) — jalur video RTP dapat diuji"
    }
}

// TODO(Fase 0, Windows): implementasi capture loop DXGI + encode NVENC.
//   1. `windows-capture` crate → DXGI Desktop Duplication (AcquireNextFrame ≤ 8 ms).
//   2. Encode NVENC/AMF via FFmpeg (`ffmpeg-next`, `-c:v h264_nvenc -preset p1 -tune ll`)
//      ATAU SDK (NVIDIA Video Codec SDK) untuk zero-copy CUDA→NVENC.
//   3. Dorong frame ter-encode ke `Session::add_video_track` (Sample → WriteSample → RTP).
//
//   Struktur `TestPatternEncoder` sengaja menyerupai sumber DXGI (panggil
//   `encode_next()` per frame), sehingga penggantian sumber cukup menukar
//   implementasi, bukan mengubah alur.

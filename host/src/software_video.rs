//! Jalur software yang sesuai batas penerimaan H264 Level 3.1 pada SDP.
//! Capture tetap pada desktop asli; hanya gambar kirim yang diperkecil.
use openh264::encoder::Encoder;
use openh264::formats::{RgbaSliceU8, YUVBuffer};

pub const MAX_WIDTH: usize = 1280;
pub const MAX_HEIGHT: usize = 720;
pub const MAX_FPS: u32 = 30;
pub const MAX_BITRATE: u32 = 14_000_000;

pub fn output_size(width: usize, height: usize) -> Result<(usize, usize), String> {
    if width < 2 || height < 2 {
        return Err("capture lebih kecil dari 2x2".into());
    }
    let scale = (MAX_WIDTH as f64 / width as f64)
        .min(MAX_HEIGHT as f64 / height as f64)
        .min(1.0);
    let w = ((width as f64 * scale).round() as usize & !1).max(2);
    let h = ((height as f64 * scale).round() as usize & !1).max(2);
    Ok((w, h))
}

pub fn sps_profile_level(data: &[u8]) -> Option<[u8; 3]> {
    for i in 0..data.len() {
        let tail = &data[i..];
        let prefix = if tail.starts_with(&[0, 0, 0, 1]) {
            4
        } else if tail.starts_with(&[0, 0, 1]) {
            3
        } else {
            continue;
        };
        if tail.len() >= prefix + 4 && tail[prefix] & 31 == 7 {
            return Some([tail[prefix + 1], tail[prefix + 2], tail[prefix + 3]]);
        }
    }
    None
}

pub struct SoftwareEncoder {
    encoder: Encoder,
    resized: Vec<u8>,
    logged_size: Option<(usize, usize)>,
}
impl SoftwareEncoder {
    pub fn new() -> Result<Self, openh264::Error> {
        Ok(Self {
            encoder: Encoder::with_api_config(
                openh264::OpenH264API::from_source(),
                crate::screen::prod_encoder_config(),
            )?,
            resized: Vec::new(),
            logged_size: None,
        })
    }
    pub fn encode(&mut self, rgba: &[u8], width: usize, height: usize) -> Result<Vec<u8>, String> {
        let len = width
            .checked_mul(height)
            .and_then(|n| n.checked_mul(4))
            .ok_or("dimensi capture meluap")?;
        if rgba.len() != len {
            return Err("panjang RGBA tidak cocok dengan dimensi capture".into());
        }
        let (w, h) = output_size(width, height)?;
        let pixels = if (w, h) == (width, height) {
            rgba
        } else {
            // Nearest-neighbor tanpa alokasi ulang per frame. Tidak mengubah
            // ukuran desktop atau koordinat input yang dinormalisasi.
            self.resized.resize(w * h * 4, 0);
            for y in 0..h {
                for x in 0..w {
                    let src = ((y * height / h) * width + x * width / w) * 4;
                    let dst = (y * w + x) * 4;
                    self.resized[dst..dst + 4].copy_from_slice(&rgba[src..src + 4]);
                }
            }
            &self.resized
        };
        let yuv = YUVBuffer::from_rgb_source(RgbaSliceU8::new(pixels, (w, h)));
        let data = self
            .encoder
            .encode(&yuv)
            .map_err(|e| format!("openh264: {e}"))?
            .to_vec();
        if self.logged_size != Some((width, height)) {
            if let Some([profile, constraints, level]) = sps_profile_level(&data) {
                println!("[xydesk-host] video software: capture {width}x{height} -> kirim {w}x{h}, maks {MAX_FPS} fps, bitrate {} bps, SPS {profile:02x}{constraints:02x}{level:02x}", crate::screen::target_bitrate_bps().min(MAX_BITRATE));
                self.logged_size = Some((width, height));
            }
        }
        Ok(data)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use openh264::formats::YUVSource;
    #[test]
    fn ukuran_aspek_genap_dan_batas_macroblock() {
        assert_eq!(output_size(2336, 1080).unwrap(), (1280, 592));
        for (w, h) in [
            (2336, 1080),
            (3840, 2160),
            (1080, 2336),
            (1280, 720),
            (321, 181),
            (2, 2),
        ] {
            let (ow, oh) = output_size(w, h).unwrap();
            assert!(ow <= 1280 && oh <= 720 && ow % 2 == 0 && oh % 2 == 0);
            assert!(ow.div_ceil(16) * oh.div_ceil(16) <= 3600);
            assert!(ow.div_ceil(16) * oh.div_ceil(16) * MAX_FPS as usize <= 108000);
        }
        assert!(output_size(0, 100).is_err());
    }
    #[test]
    fn produksi_rgba_rdp_menjadi_sps_level31_dan_bisa_didecode() {
        let (w, h) = (2336, 1080);
        let pixels = vec![220u8; w * h * 4];
        let mut enc = SoftwareEncoder::new().unwrap();
        let data = enc.encode(&pixels, w, h).unwrap();
        let [profile, constraints, level] = sps_profile_level(&data).unwrap();
        assert_eq!(profile, 66);
        assert_ne!(constraints & 0x40, 0);
        assert_eq!(level, 31, "SPS harus sesuai batas Level3.1, bukan 5.1");
        let mut decoder = openh264::decoder::Decoder::new().unwrap();
        let decoded = decoder.decode(&data).unwrap().expect("IDR harus terdecode");
        assert_eq!(decoded.dimensions(), output_size(w, h).unwrap());
    }
    #[test]
    fn input_rgba_rusak_ditolak() {
        assert!(SoftwareEncoder::new()
            .unwrap()
            .encode(&[0; 4], 320, 180)
            .is_err());
    }
}

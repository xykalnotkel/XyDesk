//! Konversi format PCM antar-representasi WASAPI — murni Rust, tanpa Win32.
//!
//! ## Kenapa modul ini ada
//!
//! WASAPI mode SHARED hanya menerima FORMAT MIX perangkat (`GetMixFormat`):
//! memaksa PCM16 48 kHz ke device yang mix-nya float32 44,1 kHz menghasilkan
//! `AUDCLNT_E_UNSUPPORTED_FORMAT` (0x88890008) — kesalahan audio yang selama
//! ini dilaporkan terpisah dari layar hitam dan tidak pernah sembuh karena
//! inisialisasinya yang salah, bukan perangkatnya.
//!
//! Jadi host kini menerima format apa pun yang diberikan device, lalu
//! menormalkannya ke kebutuhan Opus (48 kHz, stereo/mono, PCM16) di sini.
//! Semua fungsi bebas Win32 supaya bisa diuji sungguhan di Linux — konversi
//! sampel adalah tempat di mana kesalahan satu bit terdengar sebagai suara
//! pecah di telinga pengguna, dan itu tidak boleh dikirim tanpa test.

/// Representasi sampel per titik yang dipakai mesin audio Windows.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Sampel {
    I16,
    I24,
    I32,
    F32,
}

impl Sampel {
    pub fn byte_per_sampel(self) -> usize {
        match self {
            Sampel::I16 => 2,
            Sampel::I24 => 3,
            Sampel::I32 | Sampel::F32 => 4,
        }
    }
}

/// Bentuk sumber mentah: interleaved, seperti yang datang dari `GetBuffer`.
#[derive(Debug, Clone, Copy)]
pub struct Sumber {
    pub channels: usize,
    pub rate: u32,
    pub sampel: Sampel,
}

/// Bytes interleaved → f32 interleaved ternormalisasi (-1..1).
pub fn decode(bytes: &[u8], sampel: Sampel) -> Vec<f32> {
    let n = bytes.len() / sampel.byte_per_sampel();
    let mut out = Vec::with_capacity(n);
    for i in 0..n {
        let b = &bytes[i * sampel.byte_per_sampel()..];
        out.push(match sampel {
            Sampel::I16 => f32::from(i16::from_le_bytes([b[0], b[1]])) / 32_768.0,
            Sampel::I24 => {
                let mut v = u32::from(b[0]) | (u32::from(b[1]) << 8) | (u32::from(b[2]) << 16);
                if v & 0x80_00_00 != 0 {
                    v |= 0xFF00_0000; // perluas tanda 24-bit ke 32-bit
                }
                (v as i32) as f32 / 8_388_608.0
            }
            Sampel::I32 => i32::from_le_bytes([b[0], b[1], b[2], b[3]]) as f32 / 2_147_483_648.0,
            Sampel::F32 => f32::from_le_bytes([b[0], b[1], b[2], b[3]]),
        });
    }
    out
}

/// f32 interleaved → bytes interleaved pada representasi tujuan, dengan clamp
/// supaya sampel hasil mix/resample yang lewat 0 dB tidak membungkus jadi
/// bunyi ledakan (wrap i16 jauh lebih jahat daripada clip).
pub fn encode(buf: &[f32], sampel: Sampel) -> Vec<u8> {
    let mut out = Vec::with_capacity(buf.len() * sampel.byte_per_sampel());
    for &s in buf {
        let s = s.clamp(-1.0, 1.0);
        match sampel {
            Sampel::I16 => out.extend_from_slice(&((s * 32_767.0) as i16).to_le_bytes()),
            Sampel::I24 => {
                let v = ((s * 8_388_607.0) as i32) & 0x00FF_FFFF;
                out.extend_from_slice(&v.to_le_bytes()[..3]);
            }
            Sampel::I32 => out.extend_from_slice(&((s * 2_147_483_647.0) as i32).to_le_bytes()),
            Sampel::F32 => out.extend_from_slice(&s.to_le_bytes()),
        }
    }
    out
}

/// Ubah jumlah channel: mono→stero menduplikat, stereo→mono merata-rata,
/// dan seterusnya (channel tambahan diisi nol bila sumber lebih sedikit).
pub fn remix(buf: &[f32], dari: usize, ke: usize, frames: usize) -> Vec<f32> {
    if dari == ke || dari == 0 {
        return buf.to_vec();
    }
    let mut out = Vec::with_capacity(frames * ke);
    for f in 0..frames {
        for c in 0..ke {
            let v = if dari == ke {
                buf[f * dari + c]
            } else if dari == 1 {
                buf[f] // mono → banyak channel: duplikat
            } else if ke == 1 {
                // banyak channel → mono: rata-rata, bukan channel kiri saja.
                // Mengambil kiri saja membuat suara yang hanya ada di kanan
                // (mis. suara game di channel belakang) lenyap sama sekali.
                (0..dari).map(|c2| buf[f * dari + c2]).sum::<f32>() / dari as f32
            } else if c < dari {
                buf[f * dari + c]
            } else {
                0.0
            };
            out.push(v);
        }
    }
    out
}

/// Resample linier antar laju sampel. Bukan konverter kualitas studio —
/// untuk suara sistem dan mic remote, artefak linier jauh di bawah ambbar
/// perhatian, sedangkan kegagalan resample terdengar sebagai suara hilang.
pub fn resample(buf: &[f32], channels: usize, dari: u32, ke: u32) -> Vec<f32> {
    if dari == ke || dari == 0 || channels == 0 {
        return buf.to_vec();
    }
    let frames_in = buf.len() / channels;
    let frames_out = (u64::from(frames_in as u32) * u64::from(ke) / u64::from(dari)) as usize;
    let mut out = Vec::with_capacity(frames_out * channels);
    for o in 0..frames_out {
        let pos = o as f64 * f64::from(dari) / f64::from(ke);
        let i0 = pos.floor() as usize;
        let i1 = (i0 + 1).min(frames_in.saturating_sub(1));
        let t = (pos - i0 as f64) as f32;
        for c in 0..channels {
            let a = buf[i0.min(frames_in.saturating_sub(1)) * channels + c];
            let b = buf[i1 * channels + c];
            out.push(a + (b - a) * t);
        }
    }
    out
}

/// Satu pintu: bytes format sumber → bytes format tujuan.
pub fn konversi(
    bytes: &[u8],
    src: &Sumber,
    dst_channels: usize,
    dst_rate: u32,
    dst: Sampel,
) -> Vec<u8> {
    let mut buf = decode(bytes, src.sampel);
    let frames = buf.len().checked_div(src.channels).unwrap_or(0);
    buf = remix(&buf, src.channels, dst_channels, frames);
    buf = resample(&buf, dst_channels, src.rate, dst_rate);
    encode(&buf, dst)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn i16_bytes(v: &[i16]) -> Vec<u8> {
        v.iter().flat_map(|x| x.to_le_bytes()).collect()
    }

    #[test]
    fn decode_i16_menormalkan() {
        let d = decode(&i16_bytes(&[0, 32_767, -32_768]), Sampel::I16);
        assert!((d[0]).abs() < 1e-6);
        assert!((d[1] - 0.99997).abs() < 1e-3);
        assert!(d[2] <= -0.9999);
    }

    #[test]
    fn decode_i24_tanda_diperpanjang() {
        // Little-endian: 0x80 0x00 0x00 = -8388608 (full-scale negatif);
        // 0xFF FF FF = -1 LSB (nyaris hening, tapi TETAP negatif — di sinilah
        // perpanjangan tanda sering salah dan bunyi pelan jadi bunyi ledakan).
        let bytes = [0x00u8, 0x00, 0x80, 0xFF, 0xFF, 0xFF];
        let d = decode(&bytes, Sampel::I24);
        assert!(d[0] <= -0.9999, "full-scale negatif: {}", d[0]);
        assert!(d[1] < 0.0, "-1 LSB harus tetap negatif: {}", d[1]);
        assert!(d[1].abs() < 1e-4);
    }

    #[test]
    fn decode_f32_lolos_apa_adanya() {
        let bytes = 0.5f32.to_le_bytes();
        let d = decode(&bytes, Sampel::F32);
        assert_eq!(d[0], 0.5);
    }

    #[test]
    fn encode_i16_clip_bukan_membungkus() {
        let out = encode(&[1.5, -1.5], Sampel::I16);
        let a = i16::from_le_bytes([out[0], out[1]]);
        let b = i16::from_le_bytes([out[2], out[3]]);
        assert_eq!(a, 32_767);
        assert_eq!(b, -32_767);
    }

    #[test]
    fn remix_mono_ke_stereo_menduplikat() {
        let out = remix(&[0.25, -0.5], 1, 2, 2);
        assert_eq!(out, vec![0.25, 0.25, -0.5, -0.5]);
    }

    #[test]
    fn remix_stereo_ke_mono_merata() {
        let out = remix(&[0.2, 0.6], 2, 1, 1);
        assert!((out[0] - 0.4).abs() < 1e-6);
    }

    #[test]
    fn resample_panjangnya_masuk_akal() {
        // 100 frame 44.1k -> ~108 frame 48k
        let buf = vec![0.5f32; 100 * 2];
        let out = resample(&buf, 2, 44_100, 48_000);
        let frames = out.len() / 2;
        assert!((108..=109).contains(&frames), "frames: {frames}");
        // sinyal konstan tetap konstan setelah resample
        assert!(out.iter().all(|v| (*v - 0.5).abs() < 1e-6));
    }

    #[test]
    fn konversi_utuh_float44k_ke_pcm16_48k() {
        // Sumber seperti mix device sungguhan: float32, 44.1 kHz, stereo.
        let src = Sumber {
            channels: 2,
            rate: 44_100,
            sampel: Sampel::F32,
        };
        let mut bytes = Vec::new();
        for _ in 0..441 {
            bytes.extend_from_slice(&0.5f32.to_le_bytes());
            bytes.extend_from_slice(&(-0.5f32).to_le_bytes());
        }
        let out = konversi(&bytes, &src, 2, 48_000, Sampel::I16);
        // 441 frame -> ~480 frame, stereo, 2 byte per sampel
        assert_eq!(out.len(), 480 * 2 * 2);
        let s = i16::from_le_bytes([out[0], out[1]]);
        assert!((s - 16_383).abs() <= 2, "nilai i16: {s}");
    }
}

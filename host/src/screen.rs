//! Sumber frame video.
//!
//! Dua mode, dipilih otomatis berdasar platform:
//!   - **Windows**: [windows] — DXGI Desktop Duplication (Graphics Capture API)
//!     via crate `windows-capture`, lalu di-encode H264. (Encode software
//!     openh264 untuk PoC; ganti NVENC untuk produksi.)
//!   - **Non-Windows / fallback**: [TestPatternEncoder] — pola visual untuk
//!     menjalankan jalur `capture → encode → RTP` tanpa GPU.

use std::sync::mpsc;

use openh264::encoder::{
    BitRate, Complexity, Encoder, EncoderConfig, FrameRate, IntraFramePeriod, Profile,
    RateControlMode, SpsPpsStrategy, UsageType,
};
use openh264::formats::YUVBuffer;

/// Lebar/tinggi default pola uji (kecil agar encode cepat; cukup untuk
/// membuktikan jalur video).
pub const TEST_WIDTH: usize = 320;
pub const TEST_HEIGHT: usize = 180;

/// Bitrate target jalur produksi. 8 Mbps cukup untuk 1080p screen content
/// dengan openh264; disengaja konservatif agar Wi-Fi rumah kuat.
pub const TARGET_BPS: u32 = 8_000_000;

/// Keyframe (IDR) tiap ~2 detik @60fps: pemulihan cepat setelah packet loss
/// tanpa membebani bitrate (IDR jauh lebih besar dari P-frame).
pub const IDR_INTERVAL_FRAMES: u32 = 120;

/// Konfigurasi encoder yang dipakai jalur produksi (capture layar Windows
/// dan benchmark `--bench`). Dipisah agar benchmark mengukur konfigurasi
/// yang SAMA dengan yang dipakai sesi nyata — bukan default pabrik.
///
/// Alasan tiap tuner (lihat juga `ScreenCapturer::new`):
///   - ScreenContentRealTime: mode deteksi konten teks/UI openh264.
///   - Bitrate + 8 Mbps: kualitas konsisten, bukan default 120 kbps.
///   - skip_frames(true): WAJIB. OpenH264 mengeluarkan peringatan
///     "bitrate can't be controlled ... without enabling skip frame" —
///     dengan skip mati, mode bitrate tidak berfungsi dan stream bisa
///     meledak jauh di atas 8 Mbps (memacetkan Wi-Fi rumah).
///   - IDR berkala 120 frame (~2 dtk @60fps): pulih cepat dari packet loss.
///
/// Catatan jujur dari `--bench`: openh264 (software) tidak kuat menembus
/// target <10 ms @1080p60 (di 640x360 saja sudah ~30 ms). Hardware encode
/// (NVENC/AMF/QuickSync) adalah prasyarat target itu — bukan opsi.
pub fn prod_encoder_config() -> EncoderConfig {
    EncoderConfig::new()
        .usage_type(UsageType::ScreenContentRealTime)
        .rate_control_mode(RateControlMode::Bitrate)
        .bitrate(BitRate::from_bps(TARGET_BPS))
        .max_frame_rate(FrameRate::from_hz(60.0))
        .skip_frames(true)
        .profile(Profile::Baseline)
        .complexity(Complexity::Low)
        .sps_pps_strategy(SpsPpsStrategy::ConstantId)
        .intra_frame_period(IntraFramePeriod::from_num_frames(IDR_INTERVAL_FRAMES))
        .num_threads(2)
}

/// Encoder pola uji — menghasilkan frame H264 (Annex-B) dari pola I420.
pub struct TestPatternEncoder {
    encoder: Encoder,
    frame_index: u64,
}

impl TestPatternEncoder {
    pub fn new() -> Result<Self, openh264::Error> {
        Self::with_config(EncoderConfig::new())
    }

    /// Encoder dengan konfigurasi eksplisit (dipakai benchmark `--bench`
    /// agar mengukur konfigurasi produksi yang sebenarnya).
    pub fn with_config(config: EncoderConfig) -> Result<Self, openh264::Error> {
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

    fn make_pattern(&self, width: usize, height: usize, frame: u64) -> YUVBuffer {
        let mut yuv = vec![128u8; width * height * 3 / 2];
        let bar_x = ((frame as usize) * 8) % width;
        for y in 0..height {
            for x in 0..width {
                let luma = if x >= bar_x && x < bar_x + 24 {
                    220
                } else {
                    60 + ((x * 160 / width) as u8)
                };
                yuv[y * width + x] = luma;
            }
        }
        let uv_start = width * height;
        let uv_len = (width / 2) * (height / 2);
        for i in 0..uv_len {
            yuv[uv_start + i] = 128;
            yuv[uv_start + uv_len + i] = 128;
        }
        YUVBuffer::from_vec(yuv, width, height)
    }
}

/// Mulai sumber frame di thread terpisah; kembalikan receiver frame H264
/// (Annex-B) ter-encode. Channel berukuran kecil agar frame usang dibuang
/// (penting untuk latency — selalu kirim frame terbaru).
pub fn spawn_frame_source() -> mpsc::Receiver<Vec<u8>> {
    #[cfg(target_os = "windows")]
    {
        let (tx, rx) = mpsc::sync_channel::<Vec<u8>>(2);
        std::thread::spawn(move || {
            if let Err(e) = windows::start_primary_monitor(tx) {
                eprintln!("[xydesk-host] capture layar gagal: {e}");
            }
        });
        rx
    }
    #[cfg(not(target_os = "windows"))]
    {
        let (tx, rx) = mpsc::sync_channel::<Vec<u8>>(2);
        std::thread::spawn(move || {
            let mut enc = match TestPatternEncoder::new() {
                Ok(e) => e,
                Err(e) => {
                    eprintln!("[xydesk-host] encoder gagal: {e}");
                    return;
                }
            };
            loop {
                match enc.encode_next(TEST_WIDTH, TEST_HEIGHT) {
                    Ok(data) => {
                        if tx.send(data).is_err() {
                            break;
                        }
                    }
                    Err(e) => {
                        eprintln!("[xydesk-host] encode gagal: {e}");
                        break;
                    }
                }
                std::thread::sleep(std::time::Duration::from_millis(33)); // ~30 fps
            }
        });
        rx
    }
}

/// Status implementasi sumber video pada platform ini.
pub fn capture_status() -> &'static str {
    #[cfg(target_os = "windows")]
    {
        "windows-dxgi (Graphics Capture API) — openh264; NVENC menyusul"
    }
    #[cfg(not(target_os = "windows"))]
    {
        "test-pattern (openh264) — jalur video RTP dapat diuji"
    }
}

// ── Implementasi Windows: DXGI Desktop Duplication + encode ──────────────
#[cfg(target_os = "windows")]
mod windows {
    use std::sync::mpsc;

    use openh264::encoder::Encoder;
    use openh264::formats::{RgbaSliceU8, YUVBuffer};
    use windows_capture::capture::{Context, GraphicsCaptureApiHandler};
    use windows_capture::frame::Frame;
    use windows_capture::graphics_capture_api::InternalCaptureControl;
    use windows_capture::monitor::Monitor;
    use windows_capture::settings::{
        ColorFormat, CursorCaptureSettings, DirtyRegionSettings, DrawBorderSettings,
        MinimumUpdateIntervalSettings, SecondaryWindowSettings, Settings,
    };

    /// Penangkap layar primer: tiap frame → konversi RGBA→I420 → encode H264
    /// → kirim ke channel (mpsc::Sender<Vec<u8>>).
    struct ScreenCapturer {
        encoder: Encoder,
        sender: mpsc::SyncSender<Vec<u8>>,
        /// Buffer strip padding — dialokasi sekali, dipakai ulang tiap frame.
        packed: Vec<u8>,
        frames: u64,
        /// Statistik durasi encode (mikrodetik) — bahan ukur target
        /// roadmap: encode < 10 ms @1080p60.
        encode_us_sum: u128,
        encode_us_max: u128,
        encode_count: u64,
    }

    impl GraphicsCaptureApiHandler for ScreenCapturer {
        type Flags = mpsc::SyncSender<Vec<u8>>;
        type Error = Box<dyn std::error::Error + Send + Sync>;

        fn new(ctx: Context<Self::Flags>) -> Result<Self, Self::Error> {
            // Konfigurasi produksi terpusat di `super::prod_encoder_config`
            // (dipakai juga oleh benchmark `--bench`, supaya angka benchmark
            // mencerminkan sesi nyata). Komentar tuning ada di sana.
            let encoder = Encoder::with_api_config(
                openh264::OpenH264API::from_source(),
                super::prod_encoder_config(),
            )?;
            Ok(Self {
                encoder,
                sender: ctx.flags,
                packed: Vec::new(),
                frames: 0,
                encode_us_sum: 0,
                encode_us_max: 0,
                encode_count: 0,
            })
        }

        fn on_frame_arrived(
            &mut self,
            frame: &mut Frame,
            _capture_control: InternalCaptureControl,
        ) -> Result<(), Self::Error> {
            // Baca dimensi SEBELUM buffer() (buffer meminjam frame secara mut).
            let width = frame.width() as usize;
            let height = frame.height() as usize;

            let mut buffer = frame.buffer()?; // FrameBuffer (RGBA, ColorFormat::Rgba8)
            let row_pitch = buffer.row_pitch() as usize;
            let has_padding = buffer.has_padding();
            let raw = buffer.as_raw_buffer(); // &[u8]

            // GPU sering menambah padding per baris (row_pitch > width*4),
            // terutama pada resolusi yang bukan kelipatan 64. Encoder butuh
            // baris rapat — strip padding ke buffer packed yang dipakai ulang.
            let tight: &[u8] = if has_padding {
                let row_bytes = width * 4;
                self.packed.resize(row_bytes * height, 0);
                for y in 0..height {
                    let src = &raw[y * row_pitch..y * row_pitch + row_bytes];
                    self.packed[y * row_bytes..(y + 1) * row_bytes].copy_from_slice(src);
                }
                &self.packed
            } else {
                raw
            };

            let rgba = RgbaSliceU8::new(tight, (width, height));
            let yuv = YUVBuffer::from_rgb_source(rgba);

            // Ukur encode: roadmap menargetkan < 10 ms @1080p60. Kalau
            // angka ini jebol, openh264 di CPU harus diganti NVENC.
            let t0 = std::time::Instant::now();
            let encoded = self.encoder.encode(&yuv)?.to_vec();
            let encode_us = t0.elapsed().as_micros();
            self.encode_us_sum += encode_us;
            self.encode_us_max = self.encode_us_max.max(encode_us);
            self.encode_count += 1;

            self.frames = self.frames.wrapping_add(1);
            if self.frames % 300 == 0 {
                let avg_ms = self.encode_us_sum as f64 / self.encode_count as f64 / 1000.0;
                let max_ms = self.encode_us_max as f64 / 1000.0;
                println!(
                    "[xydesk-host] capture {}x{} frame ke-{} | encode avg {avg_ms:.2} ms, max {max_ms:.2} ms",
                    width, height, self.frames
                );
            }
            // Kirim; bila channel penuh, buang frame terbaru (try_send) —
            // frame usang tidak boleh mengantre (latency > kelengkapan).
            let _ = self.sender.try_send(encoded);
            Ok(())
        }

        fn on_closed(&mut self) -> Result<(), Self::Error> {
            Ok(())
        }
    }

    /// Mulai capture layar primer. Fungsi memblok thread yang memanggilnya
    /// (dijalankan di thread terpisah oleh `spawn_frame_source`).
    pub fn start_primary_monitor(
        sender: mpsc::SyncSender<Vec<u8>>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let monitor = Monitor::primary()?;
        let settings = Settings::new(
            monitor,
            CursorCaptureSettings::WithCursor,
            DrawBorderSettings::WithoutBorder,
            SecondaryWindowSettings::Default,
            MinimumUpdateIntervalSettings::Default,
            DirtyRegionSettings::Default,
            ColorFormat::Rgba8,
            sender,
        );
        ScreenCapturer::start(settings)?;
        Ok(())
    }
}

// TODO(optimasi lanjutan): NVENC zero-copy (ID3D11Texture2D → CUDA → NVENC)
// menggantikan jalur CPU RGBA→I420→openh264 bila profil latency menuntutnya.

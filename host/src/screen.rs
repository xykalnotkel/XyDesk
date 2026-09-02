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

/// Bitrate target bawaan jalur produksi: 8 Mbps. Cukup untuk 1080p screen
/// content, disengaja konservatif agar Wi-Fi rumah kuat.
pub const DEFAULT_TARGET_BPS: u32 = 8_000_000;

/// Batas bawah bitrate yang bisa diatur lewat control API (1 Mbps).
pub const MIN_TARGET_BPS: u32 = 1_000_000;

/// Batas atas bitrate yang bisa diatur lewat control API (50 Mbps).
pub const MAX_TARGET_BPS: u32 = 50_000_000;

/// Bitrate target yang sedang aktif (bps). Dibaca tiap kali encoder dibangun;
/// berubah lewat [`set_target_bitrate_bps`] (control API aksi
/// `video-bitrate`). Bawaan [`DEFAULT_TARGET_BPS`].
static TARGET_BPS: std::sync::atomic::AtomicU32 =
    std::sync::atomic::AtomicU32::new(DEFAULT_TARGET_BPS);

/// Tanda bitrate berubah dan capture perlu di-respawn (encoder dibangun ulang
/// dengan nilai baru). Disetel `set_target_bitrate_bps`, dikosongkan thread
/// capture saat respawn.
static BITRATE_DIRTY: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);

/// Bitrate target aktif dalam bps.
pub fn target_bitrate_bps() -> u32 {
    TARGET_BPS.load(std::sync::atomic::Ordering::Relaxed)
}

/// Setel bitrate target (bps). Berlaku seketika bila ada sesi berjalan
/// (capture di-respawn dengan encoder baru); selain itu menjadi nilai sesi
/// berikutnya. Ditolak (mengembalikan `false`) bila di luar
/// [`MIN_TARGET_BPS`]..=[`MAX_TARGET_BPS`].
pub fn set_target_bitrate_bps(bps: u32) -> bool {
    if !(MIN_TARGET_BPS..=MAX_TARGET_BPS).contains(&bps) {
        return false;
    }
    TARGET_BPS.store(bps, std::sync::atomic::Ordering::Relaxed);
    BITRATE_DIRTY.store(true, std::sync::atomic::Ordering::Relaxed);
    true
}

/// Keyframe (IDR) tiap ~2 detik @60fps: pemulihan cepat setelah packet loss
/// tanpa membebani bitrate (IDR jauh lebih besar dari P-frame).
pub const IDR_INTERVAL_FRAMES: u32 = 120;

/// Konfigurasi encoder yang dipakai jalur produksi (capture layar Windows
/// dan benchmark `--bench`). Dipisah agar benchmark mengukur konfigurasi
/// yang SAMA dengan yang dipakai sesi nyata — bukan default pabrik.
///
/// Alasan tiap tuner (lihat juga `ScreenCapturer::new`):
///   - ScreenContentRealTime: mode deteksi konten teks/UI openh264.
///   - Bitrate target (bawaan 8 Mbps): kualitas konsisten, bukan default 120 kbps.
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
        .bitrate(BitRate::from_bps(target_bitrate_bps()))
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
            let mut current = wanted_display();
            loop {
                if let Err(e) = windows::start_monitor(tx.clone(), current) {
                    eprintln!("[xydesk-host] capture layar (monitor {current}) gagal: {e}");
                }
                // Ada permintaan pindah monitor? Respawn dengan indeks baru.
                let next = SWITCH_TO.swap(usize::MAX, std::sync::atomic::Ordering::Relaxed);
                if next != usize::MAX {
                    current = next;
                    println!("[xydesk-host] pindah capture ke monitor {current}");
                    continue;
                }
                // Bitrate berubah di tengah sesi? Respawn dengan monitor yang
                // sama — encoder dibangun ulang dengan target bitrate baru.
                if BITRATE_DIRTY.swap(false, std::sync::atomic::Ordering::Relaxed) {
                    println!(
                        "[xydesk-host] capture di-respawn: bitrate target {} kbps",
                        target_bitrate_bps() / 1000
                    );
                    continue;
                }
                // Tanpa permintaan apa pun, capture berakhir karena sesi
                // selesai (handler berhenti) — thread ini pun keluar.
                break;
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
        "windows-dxgi (Graphics Capture API) — NVENC hardware; fallback openh264"
    }
    #[cfg(not(target_os = "windows"))]
    {
        "test-pattern (openh264) — jalur video RTP dapat diuji"
    }
}

/// Info satu monitor/display untuk pemilihan layar di client.
#[derive(Clone, Debug, serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DisplayInfo {
    /// Indeks sistem (0 = primer) — dipakai `select_display`.
    pub index: usize,
    /// Nama perangkat GDI (mis. `\\.\DISPLAY1`) — untuk label UI.
    pub name: String,
    pub width: u32,
    pub height: u32,
}

/// Daftar semua monitor aktif (urutan sistem Windows).
pub fn list_displays() -> Vec<DisplayInfo> {
    #[cfg(target_os = "windows")]
    {
        windows::list_displays()
    }
    #[cfg(not(target_os = "windows"))]
    {
        Vec::new()
    }
}

/// Monitor yang sedang dipilih untuk capture (default 0 = primer).
static WANTED_MONITOR: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(0);

/// Permintaan pindah monitor DI TENGAH SESI. Dibaca thread capture
/// (`on_frame_arrived` menghentikan handler → thread respawn dengan monitor
/// baru). `usize::MAX` = tidak ada permintaan.
static SWITCH_TO: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(usize::MAX);

/// Pilih monitor. Berlaku langsung bila ada sesi berjalan (capture di-respawn);
/// selain itu menjadi pilihan sesi berikutnya.
pub fn select_display(index: usize) -> bool {
    let count = list_displays().len();
    if count == 0 || index >= count {
        return false;
    }
    WANTED_MONITOR.store(index, std::sync::atomic::Ordering::Relaxed);
    SWITCH_TO.store(index, std::sync::atomic::Ordering::Relaxed);
    true
}

/// Indeks monitor yang akan dipakai sesi berikutnya.
pub fn wanted_display() -> usize {
    WANTED_MONITOR.load(std::sync::atomic::Ordering::Relaxed)
}

/// Benar bila encoder NVENC hardware sedang dipakai (hanya bisa di Windows).
/// Dibaca oleh control API (`control::VideoStats`) untuk ditampilkan shell
/// desktop. Ditulis oleh modul `windows` saat encoder dipilih.
static NVENC_ACTIVE: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);

pub fn nvenc_active() -> bool {
    NVENC_ACTIVE.load(std::sync::atomic::Ordering::Relaxed)
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

    /// Encoder aktif: NVENC (hardware) bila tersedia, openh264 (software)
    /// sebagai fallback. Dibuat lazy di frame pertama karena resolusi baru
    /// diketahui saat itu.
    enum EncoderKind {
        Nvenc(crate::nvenc::NvEnc),
        Soft(Box<Encoder>),
    }

    impl EncoderKind {
        fn encode(
            &mut self,
            rgba_tight: &[u8],
            width: usize,
            height: usize,
            nv12: &mut Vec<u8>,
        ) -> Result<Vec<u8>, String> {
            match self {
                EncoderKind::Nvenc(enc) => {
                    crate::pixfmt::rgba_to_nv12(rgba_tight, width, height, nv12);
                    enc.encode(nv12)
                }
                EncoderKind::Soft(enc) => {
                    let rgba = RgbaSliceU8::new(rgba_tight, (width, height));
                    let yuv = YUVBuffer::from_rgb_source(rgba);
                    enc.encode(&yuv)
                        .map(|b| b.to_vec())
                        .map_err(|e| format!("openh264: {e}"))
                }
            }
        }
    }

    /// RGBA8 (baris rapat) → NV12 dikerjakan `crate::pixfmt::rgba_to_nv12`
    /// (lintas platform, teruji — lihat `pixfmt.rs`).

    /// Penangkap layar primer: tiap frame → proper → encode H264 (NVENC
    /// bila ada; fallback openh264) → kirim ke channel (mpsc::SyncSender<Vec<u8>>).
    struct ScreenCapturer {
        encoder: EncoderKind,
        sender: mpsc::SyncSender<Vec<u8>>,
        /// Buffer strip padding — dialokasi sekali, dipakai ulang tiap frame.
        packed: Vec<u8>,
        /// Buffer NV12 (jalur NVENC) — dipakai ulang.
        nv12: Vec<u8>,
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
            // Encoder dibangun lazy di frame pertama (resolusi belum diketahui
            // di sini). Sementara diisi fallback software; `on_frame_arrived`
            // akan mengganti ke NVENC bila GPU NVIDIA tersedia.
            let encoder = Encoder::with_api_config(
                openh264::OpenH264API::from_source(),
                super::prod_encoder_config(),
            )?;
            Ok(Self {
                encoder: EncoderKind::Soft(Box::new(encoder)),
                sender: ctx.flags,
                packed: Vec::new(),
                nv12: Vec::new(),
                frames: 0,
                encode_us_sum: 0,
                encode_us_max: 0,
                encode_count: 0,
            })
        }

        fn on_frame_arrived(
            &mut self,
            frame: &mut Frame,
            capture_control: InternalCaptureControl,
        ) -> Result<(), Self::Error> {
            // Permintaan pindah monitor ATAU bitrate baru: hentikan handler
            // ini — thread capture di atasnya akan respawn (monitor baru,
            // atau monitor sama dengan encoder bitrate baru).
            if super::SWITCH_TO.load(std::sync::atomic::Ordering::Relaxed) != usize::MAX
                || super::BITRATE_DIRTY.load(std::sync::atomic::Ordering::Relaxed)
            {
                capture_control.stop();
                return Ok(());
            }
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

            // Lazy init encoder: frame pertama menentukan resolusi. NVENC
            // butuh dimensi genap; kalau tidak cocok atau gagal (tidak ada
            // GPU NVIDIA / driver < R550), tetap di openh264 — tidak crash.
            if self.frames == 0 {
                super::NVENC_ACTIVE.store(false, std::sync::atomic::Ordering::Relaxed);
                if width.is_multiple_of(2) && height.is_multiple_of(2) {
                    match crate::nvenc::NvEnc::new(
                        width as u32,
                        height as u32,
                        super::target_bitrate_bps(),
                    ) {
                        Ok(enc) => {
                            println!(
                                "[xydesk-host] NVENC aktif: H264 hardware {}x{} @ {} kbps CBR",
                                width,
                                height,
                                super::target_bitrate_bps() / 1000
                            );
                            super::NVENC_ACTIVE.store(true, std::sync::atomic::Ordering::Relaxed);
                            self.encoder = EncoderKind::Nvenc(enc);
                        }
                        Err(e) => {
                            eprintln!(
                                "[xydesk-host] NVENC tidak tersedia, pakai openh264 (software): {e}"
                            );
                        }
                    }
                } else {
                    eprintln!(
                        "[xydesk-host] resolusi ganjil {}x{}, NVENC dilewati (butuh dimensi genap)",
                        width, height
                    );
                }
            }

            // Ukur encode (termasuk konversi RGBA→NV12 di jalur NVENC): target
            // roadmap < 10 ms @1080p60.
            let t0 = std::time::Instant::now();
            let encoded = match self.encoder.encode(tight, width, height, &mut self.nv12) {
                Ok(data) => data,
                Err(e) => {
                    eprintln!("[xydesk-host] encode frame gagal: {e}");
                    return Ok(());
                }
            };
            let encode_us = t0.elapsed().as_micros();
            self.encode_us_sum += encode_us;
            self.encode_us_max = self.encode_us_max.max(encode_us);
            self.encode_count += 1;

            self.frames = self.frames.wrapping_add(1);
            if self.frames.is_multiple_of(300) {
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
    pub fn start_monitor(
        sender: mpsc::SyncSender<Vec<u8>>,
        index: usize,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        // `from_index` gagal bila indeks di luar jangkauan — fallback ke
        // monitor primer agar sesi tidak mati hanya karena pemilihan layar.
        let monitor = Monitor::from_index(index).or_else(|_| Monitor::primary())?;
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

    /// Daftar monitor aktif via GDI (`EnumDisplayMonitors` + `GetMonitorInfoW`)
    /// — urutan dan nama konsisten dengan yang dilihat sistem Windows.
    pub fn list_displays() -> Vec<super::DisplayInfo> {
        use windows::core::BOOL;
        use windows::Win32::Foundation::LPARAM;
        use windows::Win32::Graphics::Gdi::{
            EnumDisplayMonitors, GetMonitorInfoW, HDC, HMONITOR, MONITORINFO, MONITORINFOEXW,
        };

        unsafe extern "system" fn collect(
            hmonitor: HMONITOR,
            _hdc: HDC,
            _rect: *mut windows::Win32::Foundation::RECT,
            lparam: LPARAM,
        ) -> BOOL {
            let list = &mut *(lparam.0 as *mut Vec<super::DisplayInfo>);
            let mut info: MONITORINFOEXW = std::mem::zeroed();
            info.monitorInfo.cbSize = std::mem::size_of::<MONITORINFOEXW>() as u32;
            if unsafe {
                GetMonitorInfoW(
                    hmonitor,
                    &mut info as *mut MONITORINFOEXW as *mut MONITORINFO,
                )
            }
            .as_bool()
            {
                let rc = info.monitorInfo.rcMonitor;
                let name = String::from_utf16_lossy(&info.szDevice)
                    .trim_end_matches('\0')
                    .to_string();
                list.push(super::DisplayInfo {
                    index: list.len(),
                    name,
                    width: (rc.right - rc.left).max(0) as u32,
                    height: (rc.bottom - rc.top).max(0) as u32,
                });
            }
            BOOL(1)
        }

        let mut list: Vec<super::DisplayInfo> = Vec::new();
        unsafe {
            let _ = EnumDisplayMonitors(
                None, // hdc: Option<HDC> — null = semua display di desktop
                None,
                Some(collect),
                LPARAM(&mut list as *mut Vec<super::DisplayInfo> as isize),
            );
        }
        list
    }
}

// TODO(optimasi lanjutan): NVENC zero-copy (ID3D11Texture2D → CUDA → NVENC)
// menggantikan jalur CPU RGBA→I420→openh264 bila profil latency menuntutnya.

#[cfg(test)]
pub mod test_support {
    use std::sync::Mutex;

    /// Serialisasi test yang menyentuh bitrate global (AtomicU32 proses-wide).
    /// Test di modul berbeda (screen, control) boleh mengubah nilainya — tanpa
    /// lock ini test paralel saling menimpa dan hasil baca-ulang jadi acak.
    /// Setiap test memegang lock ini seumur test.
    pub static BITRATE_LOCK: Mutex<()> = Mutex::new(());
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bitrate_bawaan_dan_batas_ditolak() {
        let _g = test_support::BITRATE_LOCK.lock().unwrap();
        set_target_bitrate_bps(DEFAULT_TARGET_BPS);
        assert_eq!(target_bitrate_bps(), DEFAULT_TARGET_BPS);
        // Di bawah batas minimum: ditolak, nilai tidak berubah.
        assert!(!set_target_bitrate_bps(MIN_TARGET_BPS - 1));
        assert_eq!(target_bitrate_bps(), DEFAULT_TARGET_BPS);
        // Di atas batas maksimum: ditolak, nilai tidak berubah.
        assert!(!set_target_bitrate_bps(MAX_TARGET_BPS + 1));
        assert_eq!(target_bitrate_bps(), DEFAULT_TARGET_BPS);
    }

    #[test]
    fn bitrate_valid_disimpan_dan_tepi_batas_diterima() {
        let _g = test_support::BITRATE_LOCK.lock().unwrap();
        assert!(set_target_bitrate_bps(12_000_000));
        assert_eq!(target_bitrate_bps(), 12_000_000);
        // Tepi batas sah.
        assert!(set_target_bitrate_bps(MIN_TARGET_BPS));
        assert_eq!(target_bitrate_bps(), MIN_TARGET_BPS);
        assert!(set_target_bitrate_bps(MAX_TARGET_BPS));
        assert_eq!(target_bitrate_bps(), MAX_TARGET_BPS);
        // Kembalikan bawaan agar test lain yang membaca nilai bawaan aman.
        set_target_bitrate_bps(DEFAULT_TARGET_BPS);
    }
}

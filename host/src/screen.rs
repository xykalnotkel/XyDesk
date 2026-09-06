//! Sumber frame video.
//!
//! Dua mode, dipilih otomatis berdasar platform:
//!   - **Windows**: [windows] — DXGI Desktop Duplication (Graphics Capture API)
//!     via crate `windows-capture`, lalu di-encode H264. (Encode software
//!     openh264 untuk PoC; ganti NVENC untuk produksi.)
//!   - **Non-Windows / fallback**: [TestPatternEncoder] — pola visual untuk
//!     menjalankan jalur `capture → encode → RTP` tanpa GPU.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{mpsc, Arc};

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
/// Permintaan keyframe dari task streaming: encoder di-respawn sehingga
/// frame berikutnya adalah IDR yang membawa SPS/PPS. Dipakai saat koneksi
/// WebRTC baru saja Connected — frame yang ditulis sebelum transport siap
/// dibuang jaringan, dan tanpa SPS/PPS decoder klien tidak pernah bisa
/// memulai (layar hitam selamanya).
static REQUEST_KEYFRAME: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);

/// Minta encoder menghasilkan IDR (SPS/PPS + slice) secepatnya.
pub fn request_keyframe() {
    REQUEST_KEYFRAME.store(true, std::sync::atomic::Ordering::Relaxed);
}

/// Ambil (dan bersihkan) permintaan keyframe. Dipakai loop sumber frame
/// (produksi) dan uji integrasi — memakai satu helper agar tidak ada dua
/// sumber kebenaran untuk bendera ini.
pub fn take_keyframe_request() -> bool {
    REQUEST_KEYFRAME.swap(false, std::sync::atomic::Ordering::Relaxed)
}

/// Lihat permintaan keyframe TANPA mengambilnya.
///
/// Dibutuhkan handler capture Windows: ia harus menghentikan diri supaya thread
/// di atasnya membangun ulang encoder (frame pertama encoder baru = IDR),
/// sedangkan hak mengonsumsi bendera tetap milik thread itu
/// ([`take_keyframe_request`]). Tanpa pemeriksaan ini, permintaan keyframe saat
/// koneksi baru `Connected` tidak pernah dilayani selama layar tidak berubah —
/// handler capture hanya berjalan bila ada frame, thread capture terblokir di
/// dalam `start_monitor`, dan decoder klien tidak pernah mendapat SPS/PPS.
/// Gejala di lapangan: layar hitam walau sesi `Connected`.
pub fn peek_keyframe_request() -> bool {
    REQUEST_KEYFRAME.load(std::sync::atomic::Ordering::Relaxed)
}

/// Umur maksimum IDR simpanan yang masih boleh dikirim ke klien.
///
/// Simpanan ini biasanya berumur 1-3 detik (capture menghasilkan IDR begitu
/// sesi mulai, sebelum transport `Connected`). Bila yang tersimpan ternyata
/// sisa sesi lama — monitor sudah diganti, resolusi berbeda, atau layar PC
/// sudah berubah total — mengirimnya berarti menampilkan gambar basi seolah
/// siaran langsung. Lebih baik jujur: tidak ada simpanan, tunggu IDR hidup.
pub const KEYFRAME_CACHE_TTL: std::time::Duration = std::time::Duration::from_secs(30);

/// IDR terakhir (SPS/PPS + slice) yang dihasilkan encoder, beserta waktu
/// penyimpanannya.
///
/// Simpanan inilah yang membuat penyelamatan layar hitam di
/// [`crate::video::pump_video`] mungkin: host selalu punya satu IDR untuk
/// diberikan kepada decoder klien segera setelah transport `Connected`, walau
/// sumber frame sedang tidak menghasilkan apa pun karena layarnya diam.
static LAST_KEYFRAME: std::sync::Mutex<Option<(std::time::Instant, Vec<u8>)>> =
    std::sync::Mutex::new(None);

/// Simpan `data` sebagai IDR terakhir bila ia memang memuat IDR.
///
/// Dipanggil dari satu tempat per jalur encode (Windows: `EncoderKind::encode`;
/// pola uji: `TestPatternEncoder::encode_next`) supaya tidak ada bitstream yang
/// lolos tanpa diperiksa.
pub fn remember_keyframe(data: &[u8]) {
    simpan_idr_pada(data, std::time::Instant::now());
}

/// Simpan IDR dengan waktu penyimpanan eksplisit — dipisah dari
/// [`remember_keyframe`] supaya kelayakan kedaluwarsa bisa diuji tanpa menunggu
/// [`KEYFRAME_CACHE_TTL`] detik.
fn simpan_idr_pada(data: &[u8], at: std::time::Instant) {
    if annexb_has_idr(data) {
        *crate::recover_lock(&LAST_KEYFRAME) = Some((at, data.to_vec()));
    }
}

/// IDR terakhir yang tersimpan, bila masih cukup muda
/// ([`KEYFRAME_CACHE_TTL`]). `None` bila tidak ada atau sudah basi.
pub fn last_keyframe() -> Option<Vec<u8>> {
    let slot = crate::recover_lock(&LAST_KEYFRAME);
    let (at, data) = slot.as_ref()?;
    (at.elapsed() <= KEYFRAME_CACHE_TTL).then(|| data.clone())
}

/// Benar bila bitstream H264 Annex-B memuat NAL IDR (tipe 5) atau SPS (tipe 7).
///
/// SPS ikut dihitung karena encoder kita memakai `SpsPpsStrategy::ConstantId`:
/// parameter set ditempelkan pada IDR, dan kehadirannya menandakan awal urutan
/// yang bisa didecode dari nol. Pemindaian berhenti pada kecocokan pertama —
/// ini keputusan ya/tidak, bukan parser NAL penuh.
pub fn annexb_has_idr(data: &[u8]) -> bool {
    let n = data.len();
    let mut i = 0usize;
    while i + 2 < n {
        let payload = if data[i] == 0 && data[i + 1] == 0 && data[i + 2] == 1 {
            Some(i + 3) // start code 3 byte
        } else if i + 3 < n
            && data[i] == 0
            && data[i + 1] == 0
            && data[i + 2] == 0
            && data[i + 3] == 1
        {
            Some(i + 4) // start code 4 byte
        } else {
            None
        };
        match payload {
            Some(p) if p < n => {
                let nal = data[p] & 0x1f;
                if nal == 5 || nal == 7 {
                    return true;
                }
                i = p;
            }
            Some(_) => return false, // start code terpotong di ujung buffer
            None => i += 1,
        }
    }
    false
}

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

/// FPS nominal jalur produksi (target roadmap 1080p60). Dipakai sebagai
/// durasi sampel video (RTP timestamp maju per frame) dan pacing sumber
/// pola uji.
pub const NOMINAL_FPS: u32 = 60;

/// Durasi satu frame pada [`NOMINAL_FPS`] — dipakai sebagai `duration`
/// sampel video saat menulis ke track RTP.
pub fn frame_duration() -> std::time::Duration {
    std::time::Duration::from_micros(1_000_000 / u64::from(NOMINAL_FPS))
}

/// Frame H264 ter-encode beserta metrik produksinya. Timestamp dibawa sejak
/// lahir di thread capture supaya `main.rs` bisa mengukur latensi pipeline
/// host (capture → encode → antre → tulis RTP) dan melaporkannya ke control
/// API — bahan ukur target roadmap < 40 ms tanpa alat eksternal.
pub struct EncodedFrame {
    pub data: Vec<u8>,
    /// Kapan frame ditangkap (jam monotonik) — awal pipeline.
    pub captured_at: std::time::Instant,
    /// Durasi encode frame ini (mikrodetik) — porsi dominan pipeline.
    pub encode_us: u64,
}

/// Label encoder aktif, untuk control API (`video.encoder`). Dibaca tiap
/// frame karena NVENC baru terpilih di frame pertama (deteksi GPU malas).
pub fn encoder_label() -> &'static str {
    #[cfg(target_os = "windows")]
    {
        if nvenc_active() {
            "nvenc"
        } else {
            "openh264"
        }
    }
    #[cfg(not(target_os = "windows"))]
    {
        "test-pattern"
    }
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
        let data = self.encoder.encode(&yuv)?.to_vec();
        // Jalur non-Windows ikut menyimpan IDR-nya: `tests/loopback.rs`
        // menjalankan `pump_video` produksi, termasuk penyelamatan layar hitam
        // yang membaca `last_keyframe`.
        remember_keyframe(&data);
        Ok(data)
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

/// Sumber frame yang membawa sinyal hidup konsumennya.
///
/// Saat receiver di-drop (loop video berhenti karena sesi berakhir), bendera
/// internal menjadi `false` — dipakai thread capture untuk berhenti
/// men-capture monitor tanpa penonton. Tanpa ini, capture+encode berjalan
/// terus setelah sesi tutup (memboroskan GPU/CPU), dan thread capture tidak
/// tahu kapan boleh keluar saat memutuskan retry.
pub struct FrameSource {
    rx: mpsc::Receiver<EncodedFrame>,
    alive: Arc<AtomicBool>,
}

impl FrameSource {
    /// Ambil frame berikutnya (memblokir) — sama seperti
    /// [`mpsc::Receiver::recv`].
    pub fn recv(&self) -> Result<EncodedFrame, mpsc::RecvError> {
        self.rx.recv()
    }

    /// Ambil frame dengan batas waktu — sama seperti
    /// [`mpsc::Receiver::recv_timeout`].
    pub fn recv_timeout(
        &self,
        timeout: std::time::Duration,
    ) -> Result<EncodedFrame, mpsc::RecvTimeoutError> {
        self.rx.recv_timeout(timeout)
    }
}

impl Drop for FrameSource {
    fn drop(&mut self) {
        self.alive.store(false, Ordering::Release);
        // Jaring pengaman: jalur yang tidak melewati `pump_video` (mis. sesi
        // gagal sebelum Connected) tetap tidak meninggalkan capture armed.
        disarm_capture();
    }
}

/// Mulai sumber frame di thread terpisah; kembalikan receiver frame H264
/// (Annex-B) ter-encode. Channel berukuran kecil agar frame usang dibuang
/// (penting untuk latency — selalu kirim frame terbaru).
pub fn spawn_frame_source() -> FrameSource {
    #[cfg(target_os = "windows")]
    {
        let (tx, rx) = mpsc::sync_channel::<EncodedFrame>(2);
        let alive = Arc::new(AtomicBool::new(true));
        let alive_thr = alive.clone();
        let alive_watch = alive.clone();
        std::thread::spawn(move || {
            let mut current = wanted_display();
            // Throttle peringatan "semua backend gagal" (lihat watchdog).
            let mut log_semua_gagal = std::time::Instant::now()
                .checked_sub(std::time::Duration::from_secs(30))
                .unwrap_or_else(std::time::Instant::now);
            loop {
                // Konsumen (loop video) sudah berhenti — sesi selesai. Jangan
                // capture lagi; thread ini keluar dengan bersih.
                if !alive_thr.load(Ordering::Relaxed) {
                    break;
                }
                // Belum ada penonton: tidur, jangan buka sesi capture. Ini
                // yang menahan border kuning WGC sampai transport Connected.
                if !capture_armed() {
                    std::thread::sleep(std::time::Duration::from_millis(100));
                    continue;
                }
                let backend = BACKEND.load(Ordering::Relaxed);
                let frame_sebelum = frames_captured();
                let mulai = std::time::Instant::now();
                let hasil = match backend {
                    BACKEND_GDI => windows::start_gdi_monitor(tx.clone(), current),
                    _ => windows::start_monitor(tx.clone(), current),
                };
                let gagal = hasil.err();
                if let Some(e) = &gagal {
                    eprintln!(
                        "[xydesk-host] capture {} (monitor {current}) gagal: {e}",
                        label_backend(backend)
                    );
                }
                let dihasilkan = frames_captured().saturating_sub(frame_sebelum);
                // Ada permintaan pindah monitor? Respawn dengan indeks baru.
                let next = SWITCH_TO.swap(usize::MAX, Ordering::Relaxed);
                if next != usize::MAX {
                    current = next;
                    println!("[xydesk-host] pindah capture ke monitor {current}");
                    continue;
                }
                // Bitrate berubah di tengah sesi? Respawn dengan monitor yang
                // sama — encoder dibangun ulang dengan target bitrate baru.
                if BITRATE_DIRTY.swap(false, Ordering::Relaxed) {
                    println!(
                        "[xydesk-host] capture di-respawn: bitrate target {} kbps",
                        target_bitrate_bps() / 1000
                    );
                    continue;
                }
                // Koneksi baru siap? Respawn agar frame berikutnya IDR
                // (SPS/PPS + slice) — kalau tidak, decoder klien tidak
                // pernah mendapatkan parameter set dan layarnya hitam.
                if take_keyframe_request() {
                    println!("[xydesk-host] capture di-respawn: keyframe diminta");
                    continue;
                }
                // ── Watchdog: backend yang terbukti tidak mengirim frame ──
                //
                // `start_monitor` bisa kembali tanpa satu frame pun: WGC membuka
                // sesi (border kuning terlihat, jadi dari luar tampak "capture
                // jalan") tapi `on_frame_arrived` tidak pernah dipanggil —
                // dilaporkan terjadi pada mesin ber-HDR dan pada sebagian
                // driver. Tanpa escalation host mengulang backend mati itu
                // selamanya dan layar client hitam permanen.
                if dihasilkan == 0 && capture_armed() {
                    let lama = mulai.elapsed();
                    // Gagal seketika (error) tidak perlu menunggu grace: tidak
                    // ada gunanya memberi waktu kepada backend yang melempar
                    // error, dan menunggunya memperlama layar hitam.
                    if gagal.is_some() || lama >= NO_FRAME_GRACE {
                        match backend_berikutnya(backend) {
                            Some(next) => {
                                eprintln!(
                                    "[xydesk-host] PERINGATAN: backend {} tidak mengirim satu frame pun selama {:.1} detik — pindah ke {}",
                                    label_backend(backend),
                                    lama.as_secs_f64(),
                                    label_backend(next)
                                );
                                BACKEND.store(next, Ordering::Relaxed);
                                continue;
                            }
                            None => {
                                // Semua backend sudah dicoba. Jangan banjiri log:
                                // satu peringatan per 30 detik cukup, dan
                                // percobaan tetap berjalan (transien seperti
                                // secure desktop/UAC bisa pulih sendiri).
                                let sekarang = std::time::Instant::now();
                                if sekarang
                                    .checked_duration_since(log_semua_gagal)
                                    .map(|d| d.as_secs() >= 30)
                                    .unwrap_or(true)
                                {
                                    eprintln!(
                                        "[xydesk-host] PERINGATAN: tidak ada backend capture yang mengirim frame ({:.1} detik, armed) — layar client akan hitam",
                                        lama.as_secs_f64()
                                    );
                                    log_semua_gagal = sekarang;
                                }
                            }
                        }
                    }
                }

                // Tanpa permintaan apa pun, capture berakhir karena dua sebab:
                // (1) konsumen berhenti (sesi selesai) — berhenti bersih;
                // (2) capture ditutup OS (secure desktop, monitor lepas,
                //     driver reset) — coba lagi dengan jeda singkat supaya
                //     sesi tidak membeku permanen. Jeda juga mencegah spin
                //     penuh bila capture gagal seketika berulang kali.
                if !alive_thr.load(Ordering::Relaxed) {
                    break;
                }
                std::thread::sleep(std::time::Duration::from_millis(500));
            }
        });
        // Watchdog log per detik. Terpisah dari thread capture karena thread
        // capture terblokir di dalam backend (WGC/GDI) dan tidak bisa melapor —
        // persis sebabnya sesi yang macet dulu terlihat "baik-baik saja":
        // tidak ada log sama sekali, bukan log yang menyebut masalah.
        std::thread::spawn(move || {
            let mut terakhir = frames_captured();
            let mut nol_beruntun = 0u32;
            loop {
                std::thread::sleep(std::time::Duration::from_secs(1));
                if !alive_watch.load(Ordering::Relaxed) {
                    break;
                }
                if !capture_armed() {
                    // Belum/tidak ada penonton: nol frame itu normal.
                    nol_beruntun = 0;
                    terakhir = frames_captured();
                    continue;
                }
                let total = frames_captured();
                let fps = total.saturating_sub(terakhir);
                terakhir = total;
                if fps == 0 {
                    nol_beruntun += 1;
                    eprintln!(
                        "[xydesk-host] PERINGATAN: capture {} armed tapi 0 frame selama {} detik (total {} frame)",
                        backend_label(),
                        nol_beruntun,
                        total
                    );
                } else {
                    if nol_beruntun > 0 {
                        println!(
                            "[xydesk-host] capture pulih: {} frame/detik setelah {} detik kosong",
                            fps, nol_beruntun
                        );
                    }
                    nol_beruntun = 0;
                    println!(
                        "[xydesk-host] capture {} | {} fps | total {} frame | encoder {}",
                        backend_label(),
                        fps,
                        total,
                        encoder_label()
                    );
                }
            }
        });
        FrameSource { rx, alive }
    }
    #[cfg(not(target_os = "windows"))]
    {
        let (tx, rx) = mpsc::sync_channel::<EncodedFrame>(2);
        let alive = Arc::new(AtomicBool::new(true));
        let alive_thr = alive.clone();
        std::thread::spawn(move || {
            let mut enc = match TestPatternEncoder::new() {
                Ok(e) => e,
                Err(e) => {
                    eprintln!("[xydesk-host] encoder gagal: {e}");
                    return;
                }
            };
            loop {
                // Konsumen berhenti — sesi selesai; keluar bersih.
                if !alive_thr.load(Ordering::Relaxed) {
                    break;
                }
                // Keyframe diminta (mis. koneksi baru Connected): bangun
                // encoder baru supaya frame berikutnya IDR + SPS/PPS.
                if take_keyframe_request() {
                    println!("[xydesk-host] pola uji: encoder di-reset untuk keyframe");
                    match TestPatternEncoder::new() {
                        Ok(e) => enc = e,
                        Err(e) => {
                            eprintln!("[xydesk-host] encoder gagal di-reset: {e}");
                            break;
                        }
                    }
                }
                let t0 = std::time::Instant::now();
                match enc.encode_next(TEST_WIDTH, TEST_HEIGHT) {
                    Ok(data) => {
                        let frame = EncodedFrame {
                            data,
                            captured_at: t0,
                            encode_us: t0.elapsed().as_micros() as u64,
                        };
                        if tx.send(frame).is_err() {
                            break;
                        }
                    }
                    Err(e) => {
                        eprintln!("[xydesk-host] encode gagal: {e}");
                        break;
                    }
                }
                // Pacing ke NOMINAL_FPS: tunggu sisa jatah frame ini.
                let elapsed = t0.elapsed();
                if elapsed < frame_duration() {
                    std::thread::sleep(frame_duration() - elapsed);
                }
            }
        });
        FrameSource { rx, alive }
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
    /// Refresh rate nyata dari `EnumDisplaySettingsW`. `None` = tidak
    /// dilaporkan driver (sebagian driver virtual menulis 0/1 Hz) — client
    /// menyembunyikan barisnya alih-alih menulis "0 Hz".
    #[serde(skip_serializing_if = "Option::is_none")]
    pub refresh_rate: Option<u32>,
    /// Benar bila monitor ini yang utama (`MONITORINFOF_PRIMARY`). Client
    /// menempelkan lencana "UTAMA"; sebelumnya tidak pernah muncul karena
    /// host tidak mengirim tandanya.
    pub is_primary: bool,
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

// ── Backend capture: rantai dengan watchdog yang mengukur dirinya sendiri ──

/// Windows Graphics Capture API. Backend awal: paling cepat, lintas GPU, dan
/// satu-satunya yang menangani fullscreen exclusive dengan benar. Kelemahannya:
/// border kuning (Win10; bisa dimatikan di Win11) dan — yang dilaporkan di
/// lapangan — sesi terbuka tapi `on_frame_arrived` tidak pernah dipanggil.
pub const BACKEND_WGC: u8 = 0;

/// GDI BitBlt. Lambat (satu BitBlt + GetDIBits per frame, tanpa notifikasi
/// perubahan) tapi **selalu ada**: tidak butuh Windows 10 1903+, tidak butuh
/// GPU, tidak menggambar border, dan tetap bekerja di sesi RDP — relevan untuk
/// PC/server sewaan yang diakses tanpa monitor fisik.
pub const BACKEND_GDI: u8 = 1;

/// Backend yang sedang dipakai. Diubah watchdog bila backend aktif terbukti
/// tidak mengirim frame — jadi nilainya hasil pengukuran, bukan preferensi.
static BACKEND: std::sync::atomic::AtomicU8 = std::sync::atomic::AtomicU8::new(BACKEND_WGC);

/// Nama backend untuk log, control API, dan UI.
pub fn label_backend(id: u8) -> &'static str {
    match id {
        BACKEND_GDI => "gdi-bitblt",
        _ => "windows-graphics-capture",
    }
}

/// Backend yang sedang aktif (label).
pub fn backend_label() -> &'static str {
    label_backend(BACKEND.load(std::sync::atomic::Ordering::Relaxed))
}

/// Capture hanya boleh berjalan bila ada penonton.
///
/// Di-set saat transport benar-benar `Connected` ([`crate::video::pump_video`]),
/// dilucuti saat sesi berakhir. Alasannya: sesi capture WGC yang dibuka lebih
/// awal memunculkan border kuning padahal belum ada yang menonton, dan
/// capture+encode tanpa penonton membuang GPU/CPU.
static ARMED: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);

/// Izinkan capture mulai (dipanggil saat Connected).
pub fn arm_capture() {
    ARMED.store(true, std::sync::atomic::Ordering::Release);
}

/// Hentikan capture karena tidak ada penonton lagi.
pub fn disarm_capture() {
    ARMED.store(false, std::sync::atomic::Ordering::Release);
}

/// Benar bila capture sedang diizinkan berjalan.
pub fn capture_armed() -> bool {
    ARMED.load(std::sync::atomic::Ordering::Acquire)
}

/// Total frame yang benar-benar ditangkap (semua backend, sejak proses mulai).
///
/// Inilah angka yang membedakan dua keadaan yang gejalanya sama-sama "layar
/// hitam": capture tidak pernah dimulai (counter tidak naik karena belum armed)
/// versus capture berjalan tapi sumbernya tidak mengirim frame (counter juga
/// tidak naik, padahal armed). Watchdog membaca selisihnya per detik.
#[cfg(target_os = "windows")]
static FRAMES_TOTAL: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);

/// Catat satu frame tertangkap. Dipanggil setiap backend tepat sebelum frame
/// ter-encode diserahkan ke channel — bukan saat frame mentah diterima, supaya
/// angka ini berarti "ada yang sampai ke client".
///
/// Hanya jalur Windows: di platform lain sumber frame-nya pola uji dan tidak
/// ikut rantai backend, jadi tanpa cfg fungsi ini dead code dan clippy
/// `-D warnings` menolaknya.
#[cfg(target_os = "windows")]
fn catat_frame() {
    FRAMES_TOTAL.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
}

/// Total frame tertangkap (untuk control API / UI).
///
/// Selalu 0 di platform non-Windows: sumber frame di sana pola uji dan tidak
/// ikut rantai backend. Mengembalikan angka nyata hanya dari jalur yang benar-
/// benar menangkap layar menjaga arti angka ini jujur.
pub fn frames_captured() -> u64 {
    #[cfg(target_os = "windows")]
    {
        FRAMES_TOTAL.load(std::sync::atomic::Ordering::Relaxed)
    }
    #[cfg(not(target_os = "windows"))]
    {
        0
    }
}

/// Backend berikutnya bila backend aktif terbukti tidak mengirim frame.
/// `None` = sudah yang terakhir; tidak ada tempat mundur lagi.
#[cfg(target_os = "windows")]
fn backend_berikutnya(now: u8) -> Option<u8> {
    match now {
        BACKEND_WGC => Some(BACKEND_GDI),
        _ => None,
    }
}

/// Berapa lama sebuah backend boleh tidak mengirim frame sebelum watchdog
/// menyimpulkan backend itu mati dan pindah ke berikutnya.
///
/// Dua detik cukup longgar untuk WGC yang frame pertamanya bisa tertunda saat
/// encoder NVENC dibangun, dan cukup pendek supaya layar hitam tidak bertahan
/// lama. Dipakai bersama syarat `armed` — sebelum Connected, nol frame adalah
/// keadaan normal, bukan kegagalan.
#[cfg(target_os = "windows")]
const NO_FRAME_GRACE: std::time::Duration = std::time::Duration::from_secs(2);

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
            let out = match self {
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
            };
            // Satu tempat untuk kedua encoder: IDR disimpan sebagai penyelamat
            // layar hitam (lihat `remember_keyframe`). Frame yang dihasilkan
            // SEBELUM transport Connected dibuang `pump_video`, jadi tanpa
            // simpanan ini decoder klien bisa tidak pernah mendapat SPS/PPS.
            if let Ok(data) = &out {
                super::remember_keyframe(data);
            }
            out
        }
    }

    // RGBA8 (baris rapat) → NV12 dikerjakan `crate::pixfmt::rgba_to_nv12`
    // (lintas platform, teruji — lihat `pixfmt.rs`). Catatan ini sengaja
    // komentar biasa: sebagai `///` ia menggantung di atas baris kosong dan
    // tidak mendokumentasikan apa pun (clippy `empty_line_after_doc_comments`,
    // yang hanya terlihat di cross-check Windows karena modul ini `cfg(windows)`).

    /// Penangkap layar primer: tiap frame → proper → encode H264 (NVENC
    /// bila ada; fallback openh264) → kirim ke channel
    /// (mpsc::SyncSender<EncodedFrame>).
    struct ScreenCapturer {
        encoder: EncoderKind,
        sender: mpsc::SyncSender<super::EncodedFrame>,
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
        /// Kapan log statistik terakhir dicetak (log berbasis waktu, lihat
        /// `on_frame_arrived`).
        log_terakhir: std::time::Instant,
        /// Jumlah frame saat log terakhir dicetak — untuk fps per interval.
        frame_log_terakhir: u64,
    }

    impl GraphicsCaptureApiHandler for ScreenCapturer {
        type Flags = mpsc::SyncSender<super::EncodedFrame>;
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
                log_terakhir: std::time::Instant::now(),
                frame_log_terakhir: 0,
            })
        }

        fn on_frame_arrived(
            &mut self,
            frame: &mut Frame,
            capture_control: InternalCaptureControl,
        ) -> Result<(), Self::Error> {
            // Awal pipeline latensi: detik frame ditangkap (jam monotonik).
            let captured_at = std::time::Instant::now();
            // Permintaan pindah monitor, bitrate baru, ATAU keyframe yang belum
            // dilayani: hentikan handler ini — thread capture di atasnya akan
            // respawn (monitor baru, encoder dengan bitrate baru, atau encoder
            // baru yang frame pertamanya IDR membawa SPS/PPS).
            //
            // Keyframe diperiksa DI SINI karena hanya handler ini yang tahu
            // capture masih hidup: thread capture terblokir di dalam
            // `start_monitor` dan baru melihat bendera itu sesudah capture
            // berhenti. Pemeriksaan memakai `peek` (bukan `take`) supaya hak
            // mengonsumsi bendera tetap di thread capture.
            if super::SWITCH_TO.load(std::sync::atomic::Ordering::Relaxed) != usize::MAX
                || super::BITRATE_DIRTY.load(std::sync::atomic::Ordering::Relaxed)
                || super::peek_keyframe_request()
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
            // Log berbasis WAKTU, bukan jumlah frame. Yang lama (tiap 300
            // frame) tidak pernah tercetak di mesin yang bermasalah — justru
            // karena frame tidak pernah mencapai 300 — jadi log diam tepat saat
            // paling dibutuhkan. Interval 5 detik: liveness per detik sudah
            // dilapor watchdog, yang di sini khusus budget encode.
            if self.log_terakhir.elapsed() >= std::time::Duration::from_secs(5) {
                let avg_ms = self.encode_us_sum as f64 / self.encode_count.max(1) as f64 / 1000.0;
                let max_ms = self.encode_us_max as f64 / 1000.0;
                println!(
                    "[xydesk-host] capture {}x{} | {} frame/5dtk | encode avg {avg_ms:.2} ms, max {max_ms:.2} ms | total {}",
                    width,
                    height,
                    self.frames - self.frame_log_terakhir,
                    self.frames
                );
                self.log_terakhir = std::time::Instant::now();
                self.frame_log_terakhir = self.frames;
                self.encode_us_sum = 0;
                self.encode_us_max = 0;
                self.encode_count = 0;
            }
            // Kirim; bila channel penuh, buang frame terbaru (try_send) —
            // frame usang tidak boleh mengantre (latency > kelengkapan).
            // Hitung sebagai frame tertangkap HANYA bila encode berhasil —
            // angka ini yang dibaca watchdog untuk memutuskan backend mati.
            super::catat_frame();
            match self.sender.try_send(super::EncodedFrame {
                data: encoded,
                captured_at,
                encode_us: encode_us as u64,
            }) {
                // Konsumen (loop video) sudah berhenti — sesi selesai.
                // Hentikan capture SEKARANG: tanpa ini, capture+encode
                // berjalan terus tanpa penonton setelah sesi tutup
                // (memboroskan GPU/CPU, dan bisa mengganggu sesi berikut).
                Err(mpsc::TrySendError::Disconnected(_)) => {
                    capture_control.stop();
                    return Ok(());
                }
                // Channel penuh — buang frame usang (latency > kelengkapan).
                Ok(()) | Err(mpsc::TrySendError::Full(_)) => {}
            }
            Ok(())
        }

        fn on_closed(&mut self) -> Result<(), Self::Error> {
            Ok(())
        }
    }

    /// Capture layar lewat GDI BitBlt — backend cadangan (`BACKEND_GDI`).
    ///
    /// Memblok thread pemanggil seperti `start_monitor` dan berhenti pada syarat
    /// yang sama (pindah monitor, bitrate berubah, keyframe diminta, capture
    /// dilucuti, konsumen selesai) supaya perpindahan itu berlaku identik di
    /// backend mana pun.
    ///
    /// Pembagian tugasnya sengaja: primitif capture (BitBlt/GetDIBits, handle
    /// GDI, buffer BGRA) ada di [`crate::gdi`] yang tidak bergantung pada
    /// webrtc/openh264 sehingga bisa di-type-check untuk target Windows di
    /// Linux lewat `tool/wincheck`. Encode, simpanan IDR penyelamat layar hitam,
    /// pace, dan pengiriman tetap di sini — identik dengan jalur WGC, karena
    /// client tidak boleh bisa membedakan backend dari perilakunya.
    pub fn start_gdi_monitor(
        tx: mpsc::SyncSender<super::EncodedFrame>,
        monitor: usize,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        /// Target fps backend ini. BitBlt + GetDIBits di 1080p butuh beberapa
        /// ms dan encode software bisa lebih dari 20 ms; 30 fps target yang
        /// realistis tanpa menghabiskan CPU. Fps nyata dilapor watchdog.
        const TARGET_FPS: u64 = 30;

        let displays = super::list_displays();
        let info = displays.get(monitor).ok_or_else(|| {
            format!(
                "monitor {monitor} tidak tersedia (terdeteksi {} monitor)",
                displays.len()
            )
        })?;
        let w = info.width as usize;
        let h = info.height as usize;
        let mut cap = crate::gdi::GdiCapture::baru(&info.name, w, h)?;

        // Resolusi sudah diketahui di depan (beda dari WGC yang baru tahu di
        // frame pertama), jadi NVENC bisa dicoba sekali di sini.
        let mut encoder = EncoderKind::Soft(Box::new(Encoder::with_api_config(
            openh264::OpenH264API::from_source(),
            super::prod_encoder_config(),
        )?));
        super::NVENC_ACTIVE.store(false, std::sync::atomic::Ordering::Relaxed);
        if w % 2 == 0 && h % 2 == 0 {
            match crate::nvenc::NvEnc::new(w as u32, h as u32, super::target_bitrate_bps()) {
                Ok(enc) => {
                    println!(
                        "[xydesk-host] GDI: NVENC aktif: H264 hardware {w}x{h} @ {} kbps CBR",
                        super::target_bitrate_bps() / 1000
                    );
                    super::NVENC_ACTIVE.store(true, std::sync::atomic::Ordering::Relaxed);
                    encoder = EncoderKind::Nvenc(enc);
                }
                Err(e) => eprintln!(
                    "[xydesk-host] GDI: NVENC tidak tersedia, pakai openh264 (software): {e}"
                ),
            }
        }

        let mut nv12: Vec<u8> = Vec::new();
        let interval = std::time::Duration::from_millis(1000 / TARGET_FPS);
        let mut detik_terakhir = std::time::Instant::now();
        let mut frame_detik = 0u64;
        let mut enc_sum: u128 = 0;
        let mut enc_max: u128 = 0;
        let mut enc_n: u64 = 0;

        println!(
            "[xydesk-host] capture gdi-bitblt mulai {w}x{h} (monitor {monitor}, target {TARGET_FPS} fps)"
        );
        loop {
            // Awal pipeline latensi — sebelum piksel diambil, sama seperti WGC.
            let captured_at = std::time::Instant::now();
            // Syarat berhenti identik dengan jalur WGC: perpindahan monitor,
            // bitrate, dan keyframe harus berlaku sama di backend mana pun.
            if super::SWITCH_TO.load(std::sync::atomic::Ordering::Relaxed) != usize::MAX
                || super::BITRATE_DIRTY.load(std::sync::atomic::Ordering::Relaxed)
                || super::peek_keyframe_request()
                || !super::capture_armed()
            {
                break;
            }
            let (rgba, fw, fh) = match cap.grab() {
                Ok(frame) => frame,
                Err(e) => {
                    eprintln!("[xydesk-host] GDI tidak bisa mengambil frame: {e}");
                    break;
                }
            };
            let t0 = std::time::Instant::now();
            let encoded = match encoder.encode(rgba, fw, fh, &mut nv12) {
                Ok(data) => data,
                Err(e) => {
                    eprintln!("[xydesk-host] GDI: encode frame gagal: {e}");
                    break;
                }
            };
            let encode_us = t0.elapsed().as_micros();
            enc_sum += encode_us;
            enc_max = enc_max.max(encode_us);
            enc_n += 1;
            frame_detik += 1;
            super::catat_frame();
            match tx.try_send(super::EncodedFrame {
                data: encoded,
                captured_at,
                encode_us: encode_us as u64,
            }) {
                // Konsumen berhenti — sesi selesai.
                Err(mpsc::TrySendError::Disconnected(_)) => break,
                // Channel penuh: buang frame usang (latency > kelengkapan).
                Ok(()) | Err(mpsc::TrySendError::Full(_)) => {}
            }

            if detik_terakhir.elapsed() >= std::time::Duration::from_secs(1) {
                let avg = enc_sum as f64 / enc_n.max(1) as f64 / 1000.0;
                let max = enc_max as f64 / 1000.0;
                println!(
                    "[xydesk-host] capture gdi-bitblt {w}x{h} | {frame_detik} fps | encode avg {avg:.2} ms, max {max:.2} ms"
                );
                detik_terakhir = std::time::Instant::now();
                frame_detik = 0;
                enc_sum = 0;
                enc_max = 0;
                enc_n = 0;
            }

            // Pace: BitBlt lebih cepat dari target hanya membakar CPU.
            let dipakai = captured_at.elapsed();
            if dipakai < interval {
                std::thread::sleep(interval - dipakai);
            }
        }
        println!("[xydesk-host] capture gdi-bitblt berhenti (monitor {monitor})");
        Ok(())
    }

    /// Mulai capture layar primer. Fungsi memblok thread yang memanggilnya
    /// (dijalankan di thread terpisah oleh `spawn_frame_source`).
    pub fn start_monitor(
        sender: mpsc::SyncSender<super::EncodedFrame>,
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

        // MONITORINFOF_PRIMARY = 0x1 (Win32). Ditulis literal karena crate
        // `windows` 0.61 tidak mengekspor konstanta itu di bawah Gdi; nilai
        // bitnya stabil sejak Windows 95 dan didokumentasikan Win32.
        const MONITORINFOF_PRIMARY_BIT: u32 = 0x1;

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
                // Refresh rate dibaca dari mode tampilan perangkat itu, bukan
                // ditebak dari resolusi (1080p bisa 60, 144, atau 240 Hz).
                let refresh_rate = crate::hwinfo::refresh_rate_hz(&name);
                list.push(super::DisplayInfo {
                    index: list.len(),
                    name,
                    width: (rc.right - rc.left).max(0) as u32,
                    height: (rc.bottom - rc.top).max(0) as u32,
                    refresh_rate,
                    is_primary: (info.monitorInfo.dwFlags & MONITORINFOF_PRIMARY_BIT) != 0,
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

    /// Serialisasi test yang menyentuh simpanan IDR global (`LAST_KEYFRAME`).
    /// Simpanan itu dibaca `video::pump_video` untuk penyelamatan layar hitam;
    /// dua test yang menulisnya paralel akan membuat hasil baca acak.
    pub static KEYFRAME_LOCK: Mutex<()> = Mutex::new(());
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

    #[test]
    fn durasi_frame_nominal_60fps() {
        let d = frame_duration();
        let us = d.as_micros();
        assert!(
            (16_000..=17_000).contains(&us),
            "durasi frame harus ~16,667 ms, dapat {us} us"
        );
    }

    #[test]
    fn frame_source_drop_mematikan_bendera_hidup() {
        // Kontrak Drop: begitu konsumen melepas FrameSource, bendera hidup
        // menjadi false — dipakai thread capture untuk berhenti men-capture
        // monitor tanpa penonton.
        let (tx, rx) = mpsc::sync_channel::<EncodedFrame>(1);
        let alive = Arc::new(AtomicBool::new(true));
        let fs = FrameSource {
            rx,
            alive: alive.clone(),
        };
        assert!(alive.load(Ordering::Relaxed));
        drop(fs);
        assert!(!alive.load(Ordering::Relaxed));
        drop(tx);
    }

    #[test]
    fn sumber_frame_membawa_timestamp_monoton_dan_payload() {
        // Jalur non-Windows (pola uji) — ikut dijalankan CI Linux.
        let rx = spawn_frame_source();
        let mut last: Option<std::time::Instant> = None;
        for _ in 0..3 {
            let f = rx
                .recv_timeout(std::time::Duration::from_secs(3))
                .expect("frame pertama harus tiba");
            assert!(!f.data.is_empty(), "payload H264 tidak boleh kosong");
            if let Some(prev) = last {
                assert!(f.captured_at >= prev, "timestamp harus monoton");
            }
            last = Some(f.captured_at);
        }
        drop(rx); // hentikan thread capture: test lain juga memakai sumber frame
    }

    #[test]
    fn annexb_menemukan_idr_dan_sps() {
        // Start code 3 byte + NAL tipe 5 (IDR slice).
        assert!(annexb_has_idr(&[0, 0, 1, 0x65, 0xaa, 0xbb]));
        // Start code 4 byte + NAL tipe 7 (SPS) — encoder kita menempelkan
        // parameter set pada IDR (SpsPpsStrategy::ConstantId).
        assert!(annexb_has_idr(&[0, 0, 0, 1, 0x67, 0x42, 0x00, 0x1f]));
        // Access unit lengkap: SPS + PPS + IDR.
        assert!(annexb_has_idr(&[
            0, 0, 0, 1, 0x67, 1, 0, 0, 1, 0x68, 1, 0, 0, 1, 0x65, 9
        ]));
        // IDR yang muncul SETELAH beberapa P-frame tetap ketemu.
        assert!(annexb_has_idr(&[
            0, 0, 1, 0x41, 0x9a, 0x24, 0, 0, 1, 0x65, 0x01
        ]));
    }

    #[test]
    fn annexb_tanpa_idr_ditolak_dan_tidak_panik() {
        // P-frame (NAL tipe 1) — bukan awal urutan yang bisa didecode.
        assert!(!annexb_has_idr(&[0, 0, 1, 0x41, 0x9a, 0x24]));
        // Bukan Annex-B sama sekali.
        assert!(!annexb_has_idr(&[0xff, 0xff, 0xff, 0xff]));
        // Input pendek / start code terpotong: tidak boleh panik.
        assert!(!annexb_has_idr(&[]));
        assert!(!annexb_has_idr(&[0, 0]));
        assert!(!annexb_has_idr(&[0, 0, 1]));
        assert!(!annexb_has_idr(&[0, 0, 0, 1]));
    }

    #[test]
    fn hanya_idr_yang_menimpa_simpanan_keyframe() {
        let _g = test_support::KEYFRAME_LOCK.lock().unwrap();
        let idr = vec![0u8, 0, 0, 1, 0x67, 0x42, 0x00, 0x1f, 0, 0, 1, 0x65, 0x11];
        remember_keyframe(&idr);
        assert_eq!(last_keyframe().as_deref(), Some(idr.as_slice()));
        // P-frame tidak boleh menimpa: simpanan inilah yang dipakai decoder
        // klien untuk memulai saat layar host sedang diam.
        remember_keyframe(&[0u8, 0, 1, 0x41, 0x9a, 0x24]);
        assert_eq!(
            last_keyframe().as_deref(),
            Some(idr.as_slice()),
            "P-frame menimpa IDR tersimpan"
        );
    }

    #[test]
    fn idr_basi_tidak_dipakai() {
        // Kontrak `last_keyframe`: hanya IDR yang cukup muda yang boleh dikirim
        // ke klien. Simpanan sisa sesi lama bisa berasal dari monitor atau
        // resolusi yang berbeda — menampilkannya berarti menyajikan gambar basi
        // seolah siaran langsung.
        let _g = test_support::KEYFRAME_LOCK.lock().unwrap();
        let idr = vec![0u8, 0, 1, 0x65, 0x22, 0x33];
        simpan_idr_pada(&idr, std::time::Instant::now());
        assert_eq!(last_keyframe().as_deref(), Some(idr.as_slice()));

        // Uptime mesin yang lebih pendek dari TTL tidak bisa membuat Instant di
        // masa lalu; bagian ini otomatis terlewat di mesin seperti itu.
        let lewat = KEYFRAME_CACHE_TTL + std::time::Duration::from_secs(1);
        if let Some(basi) = std::time::Instant::now().checked_sub(lewat) {
            simpan_idr_pada(&idr, basi);
            assert_eq!(last_keyframe(), None, "IDR basi masih dipakai");
        }
    }

    #[test]
    fn idr_dari_sumber_frame_tersimpan_untuk_penyelamatan() {
        // Kontrak yang diandalkan `video::pump_video`: begitu sumber frame
        // menghasilkan IDR, host menyimpannya. Tanpa ini, penyelamatan layar
        // hitam tidak punya bahan pada sesi pertama.
        let _g = test_support::KEYFRAME_LOCK.lock().unwrap();
        let rx = spawn_frame_source();
        let mut idr: Option<Vec<u8>> = None;
        for _ in 0..300 {
            let f = rx
                .recv_timeout(std::time::Duration::from_secs(3))
                .expect("frame harus tiba dari sumber pola uji");
            if annexb_has_idr(&f.data) {
                idr = Some(f.data.clone());
                break;
            }
        }
        drop(rx);
        let idr = idr.expect("sumber frame harus menghasilkan IDR dalam 300 frame");
        assert_eq!(
            last_keyframe().as_deref(),
            Some(idr.as_slice()),
            "IDR dari sumber frame tidak tersimpan"
        );
    }

    #[test]
    fn permintaan_keyframe_bisa_dilihat_tanpa_diambil() {
        // Handler capture Windows memakai `peek` (tidak boleh mengonsumsi),
        // thread capture memakai `take`. Kalau `peek` ikut mengambil, thread
        // capture tidak pernah melihat permintaan itu dan encoder tidak pernah
        // dibangun ulang — layar hitam lagi.
        let _g = test_support::KEYFRAME_LOCK.lock().unwrap();
        let _ = take_keyframe_request(); // mulai dari keadaan bersih
        assert!(!peek_keyframe_request());
        request_keyframe();
        assert!(peek_keyframe_request(), "peek tidak melihat permintaan");
        assert!(
            peek_keyframe_request(),
            "peek tidak boleh mengonsumsi bendera"
        );
        assert!(take_keyframe_request(), "take harus melihat permintaan");
        assert!(!peek_keyframe_request(), "take harus membersihkan bendera");
    }
}

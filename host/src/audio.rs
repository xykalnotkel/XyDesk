//! Audio XyDesk — forward (host → client) dan passthrough mic (client → host).
//!
//! ## Alur forward (host → client)
//! WASAPI loopback (`AUDCLNT_STREAMFLAGS_LOOPBACK`) merekam semua bunyi yang
//! keluar dari perangkat output default Windows — persis yang didengar
//! pengguna di depan PC — tanpa perangkat virtual apa pun. Format yang
//! diminta eksplisit: PCM 16-bit, 48 kHz, stereo (audio engine Windows
//! mengonversi bila perlu). Setiap 20 ms (960 sampel) di-encode menjadi satu
//! paket Opus lalu dikirim lewat channel. Latency pipeline ±30-60 ms.
//!
//! ## Alur mic (client → host)
//! Paket Opus yang diterima dari client didecode menjadi PCM dan dirender
//! ke perangkat output default via `IAudioRenderClient` — suara mic client
//! terdengar di speaker PC host. (Istilah "mic passthrough": suara dari
//! aplikasi client diteruskan ke host.)
//!
//! ## Alur mic (host → client)
//! Mikrofon PC host direkam via WASAPI `eCapture` (perangkat komunikasi
//! default) — PCM 16-bit, 48 kHz, mono — lalu di-encode Opus 20 ms dan
//! dikirim sebagai track audio kedua (stream `mic`). Aktif otomatis hanya
//! bila ada perangkat capture; `AUDCLNT_BUFFERFLAGS_SILENT` ditangani agar
//! mic yang dimute tetap menghasilkan hening yang sah.
//!
//! ## Non-Windows
//! Kode nyata berada di bawah `cfg(target_os = "windows")`; platform lain
//! mendapat stub yang melaporkan "belum didukung" — jalur Linux/CI test
//! tetap ter-compile.

use std::sync::mpsc;

/// Status implementasi audio pada platform ini (dilaporkan control API).
pub fn capture_status() -> &'static str {
    #[cfg(target_os = "windows")]
    {
        "wasapi-loopback → opus 48kHz stereo"
    }
    #[cfg(not(target_os = "windows"))]
    {
        "belum didukung di platform ini (butuh WASAPI Windows)"
    }
}

/// Benar bila platform ini bisa menangkap audio loopback.
pub fn capture_available() -> bool {
    cfg!(target_os = "windows")
}

/// Status implementasi mic host (mikrofon PC → client).
pub fn mic_capture_status() -> &'static str {
    #[cfg(target_os = "windows")]
    {
        "wasapi-capture (eCapture) → opus 48kHz mono"
    }
    #[cfg(not(target_os = "windows"))]
    {
        "belum didukung di platform ini (butuh WASAPI Windows)"
    }
}

/// Benar bila ada mikrofon aktif yang bisa direkam dan diteruskan ke client.
/// Otomatis: jalur mic hanya menyala di Windows dan hanya bila perangkat
/// capture terdeteksi — tidak ada toggle yang perlu diatur.
pub fn mic_capture_available() -> bool {
    #[cfg(target_os = "windows")]
    {
        windows::mic_available()
    }
    #[cfg(not(target_os = "windows"))]
    {
        false
    }
}

/// Daftar perangkat output (ID endpoint WASAPI). Nama ramah butuh property
/// store COM yang berat; untuk v1 cukup ID + label berurutan. Dapatkan nama
/// via control API → shell menampilkan "Output 1..N".
pub fn list_outputs() -> Vec<String> {
    #[cfg(target_os = "windows")]
    {
        windows::list_outputs()
    }
    #[cfg(not(target_os = "windows"))]
    {
        Vec::new()
    }
}

/// Volume master perangkat output default (0.0–1.0); `None` bila tak bisa.
pub fn master_volume() -> Option<f32> {
    #[cfg(target_os = "windows")]
    {
        windows::master_volume()
    }
    #[cfg(not(target_os = "windows"))]
    {
        None
    }
}

/// Setel volume master (0.0–1.0, di-clamp).
pub fn set_master_volume(vol: f32) -> bool {
    #[cfg(target_os = "windows")]
    {
        windows::set_master_volume(vol)
    }
    #[cfg(not(target_os = "windows"))]
    {
        let _ = vol;
        false
    }
}

/// Mulai sumber audio loopback; channel berisi paket Opus (20 ms per paket).
/// Thread berhenti sendiri bila receiver di-drop.
pub fn spawn_audio_source() -> mpsc::Receiver<Vec<u8>> {
    #[cfg(target_os = "windows")]
    {
        let (tx, rx) = mpsc::sync_channel::<Vec<u8>>(4);
        std::thread::spawn(move || {
            if let Err(e) = windows::capture_loop(tx) {
                eprintln!("[xydesk-host] audio loopback gagal: {e}");
            }
        });
        rx
    }
    #[cfg(not(target_os = "windows"))]
    {
        let (_tx, rx) = mpsc::sync_channel::<Vec<u8>>(4);
        rx
    }
}

/// Sink pemutar audio mic client. Kirim paket Opus; thread render memutar.
pub fn spawn_audio_sink() -> mpsc::SyncSender<Vec<u8>> {
    #[cfg(target_os = "windows")]
    {
        let (tx, rx) = mpsc::sync_channel::<Vec<u8>>(8);
        std::thread::spawn(move || {
            if let Err(e) = windows::render_loop(rx) {
                eprintln!("[xydesk-host] audio render gagal: {e}");
            }
        });
        tx
    }
    #[cfg(not(target_os = "windows"))]
    {
        let (tx, _rx) = mpsc::sync_channel::<Vec<u8>>(8);
        tx
    }
}

/// Mulai sumber audio mikrofon host (host → client); channel berisi paket
/// Opus (20 ms, mono). Thread berhenti sendiri bila receiver di-drop.
pub fn spawn_mic_source() -> mpsc::Receiver<Vec<u8>> {
    #[cfg(target_os = "windows")]
    {
        let (tx, rx) = mpsc::sync_channel::<Vec<u8>>(4);
        std::thread::spawn(move || {
            if let Err(e) = windows::mic_capture_loop(tx) {
                eprintln!("[xydesk-host] mic host gagal: {e}");
            }
        });
        rx
    }
    #[cfg(not(target_os = "windows"))]
    {
        let (_tx, rx) = mpsc::sync_channel::<Vec<u8>>(4);
        rx
    }
}

// ── Implementasi Windows: WASAPI ─────────────────────────────────────────
#[cfg(target_os = "windows")]
mod windows {
    use std::sync::mpsc::{Receiver, SyncSender};

    use windows::core::Interface;
    use windows::Win32::Media::Audio::{
        eCapture, eCommunications, eMultimedia, eRender, IAudioCaptureClient, IAudioClient,
        IAudioRenderClient, IMMDeviceEnumerator, MMDeviceEnumerator, AUDCLNT_SHAREMODE_SHARED,
        AUDCLNT_STREAMFLAGS_LOOPBACK,
    };
    use windows::Win32::System::Com::{
        CoCreateInstance, CoInitializeEx, CLSCTX_ALL, COINIT_MULTITHREADED,
    };

    const SAMPLE_RATE: u32 = 48_000;
    const CHANNELS: u16 = 2;
    const MIC_CHANNELS: u16 = 1;
    const FRAME_MS: usize = 20;
    const SAMPLES_PER_PACKET: usize = (SAMPLE_RATE as usize) * FRAME_MS / 1000;
    /// `AUDCLNT_BUFFERFLAGS_SILENT` — buffer capture berisi hening (mis. mic
    /// dimute) dan boleh diisi nol tanpa membaca memori perangkat.
    const BUFFERFLAGS_SILENT: u32 = 0x2;

    fn init_com() -> anyhow::Result<()> {
        unsafe {
            CoInitializeEx(None, COINIT_MULTITHREADED)
                .ok()
                .map_err(|e| anyhow::anyhow!("CoInitializeEx gagal: {e:?}"))?;
        }
        Ok(())
    }

    fn device() -> anyhow::Result<windows::Win32::Media::Audio::IMMDevice> {
        init_com()?;
        let enumerator: IMMDeviceEnumerator = unsafe {
            CoCreateInstance(&MMDeviceEnumerator, None, CLSCTX_ALL)
                .map_err(|e| anyhow::anyhow!("MMDeviceEnumerator: {e:?}"))?
        };
        let device = unsafe {
            enumerator
                .GetDefaultAudioEndpoint(eRender, eMultimedia)
                .map_err(|e| anyhow::anyhow!("GetDefaultAudioEndpoint: {e:?}"))?
        };
        Ok(device)
    }

    /// Perangkat capture default (mikrofon) — jalur mic host → client.
    fn capture_device() -> anyhow::Result<windows::Win32::Media::Audio::IMMDevice> {
        init_com()?;
        let enumerator: IMMDeviceEnumerator = unsafe {
            CoCreateInstance(&MMDeviceEnumerator, None, CLSCTX_ALL)
                .map_err(|e| anyhow::anyhow!("MMDeviceEnumerator: {e:?}"))?
        };
        let device = unsafe {
            enumerator
                .GetDefaultAudioEndpoint(eCapture, eCommunications)
                .map_err(|e| anyhow::anyhow!("GetDefaultAudioEndpoint (mic): {e:?}"))?
        };
        Ok(device)
    }

    /// Benar bila ada minimal satu perangkat capture aktif (mikrofon).
    pub fn mic_available() -> bool {
        use windows::Win32::Media::Audio::DEVICE_STATE_ACTIVE;
        let _ = init_com();
        let enumerator: IMMDeviceEnumerator =
            match unsafe { CoCreateInstance(&MMDeviceEnumerator, None, CLSCTX_ALL) } {
                Ok(e) => e,
                Err(_) => return false,
            };
        let collection =
            match unsafe { enumerator.EnumAudioEndpoints(eCapture, DEVICE_STATE_ACTIVE) } {
                Ok(c) => c,
                Err(_) => return false,
            };
        let count = match unsafe { collection.GetCount() } {
            Ok(c) => c,
            Err(_) => return false,
        };
        count > 0
    }

    fn client(device: &windows::Win32::Media::Audio::IMMDevice) -> anyhow::Result<IAudioClient> {
        let client: IAudioClient = unsafe {
            device
                .Activate(CLSCTX_ALL, None)
                .map_err(|e| anyhow::anyhow!("Activate IAudioClient: {e:?}"))?
        };
        Ok(client)
    }

    fn pcm_format() -> windows::Win32::Media::Audio::WAVEFORMATEX {
        windows::Win32::Media::Audio::WAVEFORMATEX {
            wFormatTag: 1, // WAVE_FORMAT_PCM
            nChannels: CHANNELS,
            nSamplesPerSec: SAMPLE_RATE,
            nAvgBytesPerSec: SAMPLE_RATE * u32::from(CHANNELS) * 2,
            nBlockAlign: CHANNELS * 2,
            wBitsPerSample: 16,
            cbSize: 0,
        }
    }

    /// Format PCM mono 48 kHz untuk jalur mic (bandwidth lebih hemat dari
    /// stereo; suara mic nyaris selalu mono).
    fn mic_pcm_format() -> windows::Win32::Media::Audio::WAVEFORMATEX {
        windows::Win32::Media::Audio::WAVEFORMATEX {
            wFormatTag: 1, // WAVE_FORMAT_PCM
            nChannels: MIC_CHANNELS,
            nSamplesPerSec: SAMPLE_RATE,
            nAvgBytesPerSec: SAMPLE_RATE * u32::from(MIC_CHANNELS) * 2,
            nBlockAlign: MIC_CHANNELS * 2,
            wBitsPerSample: 16,
            cbSize: 0,
        }
    }

    /// Daftar ID endpoint output aktif.
    pub fn list_outputs() -> Vec<String> {
        use windows::Win32::Media::Audio::DEVICE_STATE_ACTIVE;
        let Ok(device) = device() else {
            return Vec::new();
        };
        let Ok(enumerator) = device.cast::<IMMDeviceEnumerator>() else {
            return Vec::new();
        };
        let Ok(collection) =
            (unsafe { enumerator.EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE) })
        else {
            return Vec::new();
        };
        let Ok(count) = (unsafe { collection.GetCount() }) else {
            return Vec::new();
        };
        let mut out = Vec::new();
        for i in 0..count {
            if let Ok(item) = unsafe { collection.Item(i) } {
                if let Ok(id) = unsafe { item.GetId() } {
                    if let Ok(id) = unsafe { id.to_string() } {
                        out.push(id);
                    }
                }
            }
        }
        out
    }

    /// Volume master 0.0–1.0 dari perangkat output default.
    pub fn master_volume() -> Option<f32> {
        use windows::Win32::Media::Audio::Endpoints::IAudioEndpointVolume;
        let device = device().ok()?;
        let vol: IAudioEndpointVolume = unsafe { device.Activate(CLSCTX_ALL, None).ok()? };
        unsafe { vol.GetMasterVolumeLevelScalar().ok() }
    }

    pub fn set_master_volume(vol: f32) -> bool {
        use windows::Win32::Media::Audio::Endpoints::IAudioEndpointVolume;
        let Ok(device) = device() else { return false };
        let Ok(volume) = (unsafe { device.Activate::<IAudioEndpointVolume>(CLSCTX_ALL, None) })
        else {
            return false;
        };
        unsafe { volume.SetMasterVolumeLevelScalar(vol.clamp(0.0, 1.0), std::ptr::null()) }.is_ok()
    }

    /// Loop penangkap: WASAPI loopback → encode Opus → `tx`.
    pub fn capture_loop(tx: SyncSender<Vec<u8>>) -> anyhow::Result<()> {
        init_com()?;
        let device = device()?;
        let client = client(&device)?;
        let format = pcm_format();
        unsafe {
            client
                .Initialize(
                    AUDCLNT_SHAREMODE_SHARED,
                    AUDCLNT_STREAMFLAGS_LOOPBACK,
                    0, // durasi buffer default
                    0,
                    &format,
                    None,
                )
                .map_err(|e| anyhow::anyhow!("IAudioClient::Initialize: {e:?}"))?;
        }
        let capture: IAudioCaptureClient = unsafe {
            client
                .GetService::<IAudioCaptureClient>()
                .map_err(|e| anyhow::anyhow!("GetService IAudioCaptureClient: {e:?}"))?
        };

        let mut encoder = crate::opus_ffi::Encoder::new(SAMPLE_RATE, usize::from(CHANNELS))
            .map_err(|e| anyhow::anyhow!("opus encoder: {e}"))?;

        // Mulai stream.
        unsafe {
            client
                .Start()
                .map_err(|e| anyhow::anyhow!("IAudioClient::Start: {e:?}"))?;
        }

        let block = usize::from(format.nBlockAlign);
        let mut pending = Vec::<u8>::with_capacity(block * SAMPLES_PER_PACKET * 4);

        loop {
            let packet_len = unsafe {
                let len = capture.GetNextPacketSize()?;
                if len == 0 {
                    std::thread::sleep(std::time::Duration::from_millis(2));
                    continue;
                }
                len
            };
            // Konsumsi semua paket yang tersedia sekarang.
            for _ in 0..packet_len {
                let mut data: *mut u8 = std::ptr::null_mut();
                let mut frames: u32 = 0;
                let mut flags: u32 = 0;
                unsafe {
                    capture
                        .GetBuffer(&mut data, &mut frames, &mut flags, None, None)
                        .map_err(|e| anyhow::anyhow!("GetBuffer: {e:?}"))?;
                    if frames > 0 && !data.is_null() {
                        let bytes = std::slice::from_raw_parts(data, frames as usize * block);
                        pending.extend_from_slice(bytes);
                    }
                    capture
                        .ReleaseBuffer(frames)
                        .map_err(|e| anyhow::anyhow!("ReleaseBuffer: {e:?}"))?;
                }
            }
            // Encode per 20 ms (960 sampel stereo = 3840 byte PCM16).
            let packet_bytes = SAMPLES_PER_PACKET * block;
            while pending.len() >= packet_bytes {
                let chunk: Vec<u8> = pending.drain(..packet_bytes).collect();
                let samples: Vec<i16> = chunk
                    .as_chunks::<2>()
                    .0
                    .iter()
                    .map(|b| i16::from_le_bytes(*b))
                    .collect();
                let mut out = vec![0u8; 4000];
                match encoder.encode(&samples, &mut out) {
                    Ok(n) => {
                        if tx.send(out[..n].to_vec()).is_err() {
                            return Ok(()); // receiver di-drop → sesi selesai
                        }
                    }
                    Err(e) => {
                        eprintln!("[xydesk-host] opus encode: {e}");
                    }
                }
            }
        }
    }

    /// Loop penangkap mikrofon: WASAPI eCapture → encode Opus (mono) → `tx`.
    /// Mirip `capture_loop`, tetapi membaca perangkat capture (bukan
    /// loopback) dan menangani `AUDCLNT_BUFFERFLAGS_SILENT` (mic dimute).
    pub fn mic_capture_loop(tx: SyncSender<Vec<u8>>) -> anyhow::Result<()> {
        init_com()?;
        let device = capture_device()?;
        let client = client(&device)?;
        let format = mic_pcm_format();
        unsafe {
            client
                .Initialize(
                    AUDCLNT_SHAREMODE_SHARED,
                    windows::Win32::Media::Audio::AUDCLNT_STREAMFLAGS_NOPERSIST,
                    0, // durasi buffer default (engine menentukan)
                    0,
                    &format,
                    None,
                )
                .map_err(|e| anyhow::anyhow!("mic Initialize: {e:?}"))?;
        }
        let capture: IAudioCaptureClient = unsafe {
            client
                .GetService::<IAudioCaptureClient>()
                .map_err(|e| anyhow::anyhow!("mic GetService IAudioCaptureClient: {e:?}"))?
        };

        let mut encoder = crate::opus_ffi::Encoder::new(SAMPLE_RATE, usize::from(MIC_CHANNELS))
            .map_err(|e| anyhow::anyhow!("opus encoder (mic): {e}"))?;

        unsafe {
            client
                .Start()
                .map_err(|e| anyhow::anyhow!("mic Start: {e:?}"))?;
        }

        let block = usize::from(format.nBlockAlign);
        let mut pending = Vec::<u8>::with_capacity(block * SAMPLES_PER_PACKET * 4);

        loop {
            let packet_len = unsafe {
                let len = capture.GetNextPacketSize()?;
                if len == 0 {
                    std::thread::sleep(std::time::Duration::from_millis(2));
                    continue;
                }
                len
            };
            for _ in 0..packet_len {
                let mut data: *mut u8 = std::ptr::null_mut();
                let mut frames: u32 = 0;
                let mut flags: u32 = 0;
                unsafe {
                    capture
                        .GetBuffer(&mut data, &mut frames, &mut flags, None, None)
                        .map_err(|e| anyhow::anyhow!("mic GetBuffer: {e:?}"))?;
                    if frames > 0 {
                        if flags & BUFFERFLAGS_SILENT != 0 || data.is_null() {
                            // Mic senyap/dimute — isi hening yang sah, tanpa
                            // membaca memori perangkat.
                            pending.resize(pending.len() + frames as usize * block, 0);
                        } else {
                            let bytes = std::slice::from_raw_parts(data, frames as usize * block);
                            pending.extend_from_slice(bytes);
                        }
                    }
                    capture
                        .ReleaseBuffer(frames)
                        .map_err(|e| anyhow::anyhow!("mic ReleaseBuffer: {e:?}"))?;
                }
            }
            // Encode per 20 ms (960 sampel mono = 1920 byte PCM16).
            let packet_bytes = SAMPLES_PER_PACKET * block;
            while pending.len() >= packet_bytes {
                let chunk: Vec<u8> = pending.drain(..packet_bytes).collect();
                let samples: Vec<i16> = chunk
                    .as_chunks::<2>()
                    .0
                    .iter()
                    .map(|b| i16::from_le_bytes(*b))
                    .collect();
                let mut out = vec![0u8; 4000];
                match encoder.encode(&samples, &mut out) {
                    Ok(n) => {
                        if tx.send(out[..n].to_vec()).is_err() {
                            return Ok(()); // receiver di-drop → sesi selesai
                        }
                    }
                    Err(e) => {
                        eprintln!("[xydesk-host] opus encode (mic): {e}");
                    }
                }
            }
        }
    }

    /// Loop render: decode Opus → tulis ke IAudioRenderClient.
    pub fn render_loop(rx: Receiver<Vec<u8>>) -> anyhow::Result<()> {
        init_com()?;
        let device = device()?;
        let client = client(&device)?;
        let format = pcm_format();
        // Buffer 100 ms (10.000.000 satuan 100 ns) — jitter kecil, latency rendah.
        unsafe {
            client
                .Initialize(
                    AUDCLNT_SHAREMODE_SHARED,
                    windows::Win32::Media::Audio::AUDCLNT_STREAMFLAGS_NOPERSIST,
                    10_000_000,
                    0,
                    &format,
                    None,
                )
                .map_err(|e| anyhow::anyhow!("render Initialize: {e:?}"))?;
        }
        let render: IAudioRenderClient = unsafe {
            client
                .GetService::<IAudioRenderClient>()
                .map_err(|e| anyhow::anyhow!("GetService IAudioRenderClient: {e:?}"))?
        };
        let buffer_frames = unsafe { client.GetBufferSize()? } as usize;

        let mut decoder = crate::opus_ffi::Decoder::new(SAMPLE_RATE, usize::from(CHANNELS))
            .map_err(|e| anyhow::anyhow!("opus decoder: {e}"))?;
        let mut pcm_queue: Vec<i16> = Vec::with_capacity(SAMPLE_RATE as usize);

        unsafe {
            client
                .Start()
                .map_err(|e| anyhow::anyhow!("render Start: {e:?}"))?;
        }

        // Terima non-blok; bila kosong, isi senyap agar buffer tidak underrun.
        loop {
            while let Ok(pkt) = rx.try_recv() {
                let mut pcm = vec![0i16; SAMPLES_PER_PACKET * usize::from(CHANNELS) * 4];
                match decoder.decode(&pkt, &mut pcm) {
                    Ok(n) => {
                        pcm_queue.extend_from_slice(&pcm[..n * usize::from(CHANNELS)]);
                    }
                    Err(e) => eprintln!("[xydesk-host] opus decode: {e}"),
                }
            }
            // Tulis bertahap sesuai ruang kosong di buffer render.
            while pcm_queue.len() >= usize::from(CHANNELS) {
                let padding = unsafe { client.GetCurrentPadding()? } as usize;
                let avail = buffer_frames.saturating_sub(padding);
                if avail < usize::from(CHANNELS) {
                    std::thread::sleep(std::time::Duration::from_millis(2));
                    continue;
                }
                let want =
                    (avail / usize::from(CHANNELS)).min(pcm_queue.len() / usize::from(CHANNELS));
                let take = want * usize::from(CHANNELS);
                let chunk: Vec<i16> = pcm_queue.drain(..take).collect();
                unsafe {
                    // windows 0.61: GetBuffer mengembalikan pointer langsung.
                    let data = render
                        .GetBuffer(want as u32)
                        .map_err(|e| anyhow::anyhow!("render GetBuffer: {e:?}"))?;
                    let dst = std::slice::from_raw_parts_mut(data as *mut i16, chunk.len());
                    dst.copy_from_slice(&chunk);
                    render
                        .ReleaseBuffer(want as u32, 0)
                        .map_err(|e| anyhow::anyhow!("render ReleaseBuffer: {e:?}"))?;
                }
            }
            std::thread::sleep(std::time::Duration::from_millis(2));
        }
    }
}

#[cfg(test)]
mod tests {
    #[test]
    #[cfg(not(target_os = "windows"))]
    fn mic_tidak_tersedia_di_platform_non_windows() {
        // Di luar Windows jalur mic tidak tersedia; sumber mic menghasilkan
        // channel kosong (tidak pernah mengirim paket).
        assert!(!crate::audio::mic_capture_available());
        let rx = crate::audio::spawn_mic_source();
        assert!(
            rx.recv_timeout(std::time::Duration::from_millis(50))
                .is_err(),
            "channel mic non-Windows tidak boleh mengirim apa pun"
        );
    }
}

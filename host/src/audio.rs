//! Audio XyDesk — forward (host → client) dan passthrough mic (client → host).
//!
//! ## Alur forward (host → client)
//! WASAPI loopback (`AUDCLNT_STREAMFLAGS_LOOPBACK`) merekam semua bunyi yang
//! keluar dari perangkat output default Windows — persis yang didengar
//! pengguna di depan PC — tanpa perangkat virtual apa pun. Format yang
//! mengikuti mix device, lalu streaming resampler menghasilkan tepat 960
//! frame PCM16 48 kHz per paket Opus. Latency nyata perlu pengukuran.
//!
//! ## Alur mic (client → host)
//! Paket Opus yang diterima dari client didecode menjadi PCM dan dirender
//! ke virtual audio cable via `IAudioRenderClient`. Aplikasi Windows harus
//! memilih recording endpoint kabel itu. Tanpa kabel, gagal dengan jelas;
//! tidak fallback ke speaker dan tidak memasang driver otomatis.
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

/// Benar bila platform ini bisa menangkap audio loopback — cek device beneran,
/// bukan cuma cfg. Di VM tanpa audio device (GPU VM, server core), ini false
/// dan UI harus jelaskan "tidak ada perangkat audio" bukan "pipeline mati".
pub fn capture_available() -> bool {
    #[cfg(target_os = "windows")]
    {
        if windows::list_outputs().is_empty() {
            return false;
        }
        windows::has_default_output()
    }
    #[cfg(not(target_os = "windows"))]
    {
        false
    }
}

/// Endpoint virtual terdeteksi; aplikasi Windows tetap perlu memilih recording
/// endpoint-nya. Bukan janji driver sehat atau pilihan input aplikasi otomatis.
pub fn mic_input_available() -> bool {
    #[cfg(target_os = "windows")]
    {
        crate::virtual_mic::get_render_device_id().is_some()
    }
    #[cfg(not(target_os = "windows"))]
    {
        false
    }
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

pub fn list_outputs_detailed() -> Vec<(String, String)> {
    #[cfg(target_os = "windows")]
    {
        windows::list_outputs_detailed()
    }
    #[cfg(not(target_os = "windows"))]
    {
        Vec::new()
    }
}

pub fn list_inputs_detailed() -> Vec<(String, String)> {
    #[cfg(target_os = "windows")]
    {
        windows::list_inputs_detailed()
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
        let (tx, rx) = mpsc::sync_channel::<Vec<u8>>(4);
        std::thread::spawn(move || {
            if let Err(e) = windows::render_loop(rx) {
                eprintln!("[xydesk-host] audio render gagal: {e}");
            }
        });
        tx
    }
    #[cfg(not(target_os = "windows"))]
    {
        let (tx, _rx) = mpsc::sync_channel::<Vec<u8>>(4);
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
        CoCreateInstance, CoInitializeEx, CoTaskMemFree, CLSCTX_ALL, COINIT_MULTITHREADED,
    };

    use crate::pcmconv::{Sampel, Sumber};

    const SAMPLE_RATE: u32 = 48_000;
    const CHANNELS: u16 = 2;
    const MIC_CHANNELS: u16 = 1;
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

    fn device_by_id(id: &str) -> anyhow::Result<windows::Win32::Media::Audio::IMMDevice> {
        init_com()?;
        let enumerator: IMMDeviceEnumerator = unsafe {
            CoCreateInstance(&MMDeviceEnumerator, None, CLSCTX_ALL)
                .map_err(|e| anyhow::anyhow!("MMDeviceEnumerator: {e:?}"))?
        };
        // HSTRING auto converts to PCWSTR via windows crate
        let h: windows::core::HSTRING = id.into();
        let device = unsafe {
            enumerator
                .GetDevice(windows::core::PCWSTR::from_raw(h.as_ptr()))
                .map_err(|e| anyhow::anyhow!("GetDevice {id}: {e:?}"))?
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

    /// Daftar ID endpoint output aktif.
    pub fn list_outputs() -> Vec<String> {
        list_outputs_detailed()
            .into_iter()
            .map(|(id, _)| id)
            .collect()
    }

    /// Daftar (ID, friendly name) output — dipakai virtual_mic.rs untuk deteksi VB-CABLE
    pub fn list_outputs_detailed() -> Vec<(String, String)> {
        use windows::Win32::Media::Audio::DEVICE_STATE_ACTIVE;
        use windows::Win32::System::Com::STGM_READ;
        use windows::Win32::UI::Shell::PropertiesSystem::IPropertyStore;
        let _ = init_com();
        let enumerator: IMMDeviceEnumerator =
            match unsafe { CoCreateInstance(&MMDeviceEnumerator, None, CLSCTX_ALL) } {
                Ok(e) => e,
                Err(_) => return Vec::new(),
            };
        let collection =
            match unsafe { enumerator.EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE) } {
                Ok(c) => c,
                Err(_) => return Vec::new(),
            };
        let count = match unsafe { collection.GetCount() } {
            Ok(c) => c,
            Err(_) => return Vec::new(),
        };
        let mut out = Vec::new();
        for i in 0..count {
            if let Ok(item) = unsafe { collection.Item(i) } {
                if let Ok(id_pw) = unsafe { item.GetId() } {
                    if let Ok(id) = unsafe { id_pw.to_string() } {
                        // Friendly name via property store
                        let name = unsafe {
                            if let Ok(props) = item.OpenPropertyStore(STGM_READ) {
                                // PKEY_Device_FriendlyName = {A45C254E-DF1C-4EFD-8020-67D146A850E0},14
                                // PKEY_Device_DeviceDesc = {A45C254E-DF1C-4EFD-8020-67D146A850E0},2
                                // Kita coba baca friendly name, fallback ke DeviceDesc
                                let friendly_key = windows::Win32::Foundation::PROPERTYKEY {
                                    fmtid: windows::core::GUID::from_u128(
                                        0xA45C254E_DF1C_4EFD_8020_67D146A850E0,
                                    ),
                                    pid: 14,
                                };
                                if let Ok(var) = props.GetValue(&friendly_key) {
                                    // PROPVARIANT to string — coba baca sebagai PWSTR
                                    // Simplified: pakai DisplayName via ToString? Fallback ke ID
                                    // Kita coba ambil via PropVariantToString tidak ada, jadi pakai Debug
                                    // Untuk sekarang, pakai ID sebagai fallback, tapi coba baca via IPropertyStore string
                                    // Workaround: gunakan DisplayName dari IMMDevice? Tidak ada, jadi pakai ID
                                    // Kita akan coba baca via variant.Anonymous.Anonymous.bstrVal atau pwszVal
                                    // Simplifikasi: kalau PROPVARIANT vt=31 (LPWSTR), ambil pointer
                                    let s = format!("{:?}", var);
                                    // Kalau s mengandung "CABLE" atau "VoiceMeeter", pakai s, else ID
                                    // Untuk robust, kita coba baca langsung via GetValue dan convert manual
                                    // Karena windows crate tidak expose PropVariantToString, kita pakai unsafe baca pwszVal
                                    let pwsz = var.Anonymous.Anonymous.Anonymous.pwszVal;
                                    if !pwsz.is_null() && var.Anonymous.Anonymous.vt.0 == 31 {
                                        let ws = pwsz;
                                        if let Ok(str) = unsafe { ws.to_string() } {
                                            str
                                        } else {
                                            id.clone()
                                        }
                                    } else {
                                        // Fallback: coba baca DeviceDesc (pid 2)
                                        let desc_key = windows::Win32::Foundation::PROPERTYKEY {
                                            fmtid: windows::core::GUID::from_u128(
                                                0xA45C254E_DF1C_4EFD_8020_67D146A850E0,
                                            ),
                                            pid: 2,
                                        };
                                        if let Ok(var2) = props.GetValue(&desc_key) {
                                            let pwsz2 = var2.Anonymous.Anonymous.Anonymous.pwszVal;
                                            if !pwsz2.is_null()
                                                && var2.Anonymous.Anonymous.vt.0 == 31
                                            {
                                                let ws2 = pwsz2;
                                                if let Ok(str2) = unsafe { ws2.to_string() } {
                                                    str2
                                                } else {
                                                    id.clone()
                                                }
                                            } else {
                                                id.clone()
                                            }
                                        } else {
                                            id.clone()
                                        }
                                    }
                                } else {
                                    id.clone()
                                }
                            } else {
                                id.clone()
                            }
                        };
                        out.push((id, name));
                    }
                }
            }
        }
        out
    }

    /// Daftar (ID, friendly name) input (capture) — untuk deteksi virtual mic
    pub fn list_inputs_detailed() -> Vec<(String, String)> {
        use windows::Win32::Media::Audio::DEVICE_STATE_ACTIVE;
        use windows::Win32::System::Com::STGM_READ;
        let _ = init_com();
        let enumerator: IMMDeviceEnumerator =
            match unsafe { CoCreateInstance(&MMDeviceEnumerator, None, CLSCTX_ALL) } {
                Ok(e) => e,
                Err(_) => return Vec::new(),
            };
        let collection =
            match unsafe { enumerator.EnumAudioEndpoints(eCapture, DEVICE_STATE_ACTIVE) } {
                Ok(c) => c,
                Err(_) => return Vec::new(),
            };
        let count = match unsafe { collection.GetCount() } {
            Ok(c) => c,
            Err(_) => return Vec::new(),
        };
        let mut out = Vec::new();
        for i in 0..count {
            if let Ok(item) = unsafe { collection.Item(i) } {
                if let Ok(id_pw) = unsafe { item.GetId() } {
                    if let Ok(id) = unsafe { id_pw.to_string() } {
                        let name = unsafe {
                            if let Ok(props) = item.OpenPropertyStore(STGM_READ) {
                                let friendly_key = windows::Win32::Foundation::PROPERTYKEY {
                                    fmtid: windows::core::GUID::from_u128(
                                        0xA45C254E_DF1C_4EFD_8020_67D146A850E0,
                                    ),
                                    pid: 14,
                                };
                                if let Ok(var) = props.GetValue(&friendly_key) {
                                    let pwsz = var.Anonymous.Anonymous.Anonymous.pwszVal;
                                    if !pwsz.is_null() && var.Anonymous.Anonymous.vt.0 == 31 {
                                        let ws = pwsz;
                                        if let Ok(str) = unsafe { ws.to_string() } {
                                            str
                                        } else {
                                            id.clone()
                                        }
                                    } else {
                                        id.clone()
                                    }
                                } else {
                                    id.clone()
                                }
                            } else {
                                id.clone()
                            }
                        };
                        out.push((id, name));
                    }
                }
            }
        }
        out
    }

    /// Cek apakah default output device ada dan bisa dibuka — dipakai
    /// `capture_available()` supaya VM tanpa audio device tidak dilaporkan
    /// "tersedia" padahal `capture_loop` bakal gagal terus.
    pub fn has_default_output() -> bool {
        device().is_ok()
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

    /// Format mix perangkat + representasi sampelnya.
    ///
    /// Own the complete CoTaskMem allocation, including WAVEFORMATEXTENSIBLE.
    /// Passing a copied WAVEFORMATEX header loses the required extension.
    struct MixFormat {
        ptr: *mut windows::Win32::Media::Audio::WAVEFORMATEX,
        src: Sumber,
    }
    impl Drop for MixFormat {
        fn drop(&mut self) {
            unsafe { CoTaskMemFree(Some(self.ptr.cast())) };
        }
    }
    fn mix_format(client: &IAudioClient) -> anyhow::Result<MixFormat> {
        use windows::Win32::Media::Audio::WAVEFORMATEXTENSIBLE;
        unsafe {
            let ptr = client.GetMixFormat()?;
            anyhow::ensure!(!ptr.is_null(), "GetMixFormat returned null");
            // Establish ownership before any validation can fail.
            let mut mix = MixFormat {
                ptr,
                src: Sumber {
                    channels: 0,
                    rate: 0,
                    sampel: Sampel::I16,
                },
            };
            let fmt = *ptr;
            let tag = if fmt.wFormatTag == 0xfffe {
                anyhow::ensure!(fmt.cbSize >= 22, "truncated WAVEFORMATEXTENSIBLE");
                let sub = (*(ptr as *const WAVEFORMATEXTENSIBLE)).SubFormat;
                if sub == windows::core::GUID::from_u128(0x00000003_0000_0010_8000_00aa00389b71) {
                    3
                } else if sub
                    == windows::core::GUID::from_u128(0x00000001_0000_0010_8000_00aa00389b71)
                {
                    1
                } else {
                    anyhow::bail!("unsupported WASAPI subformat");
                }
            } else {
                fmt.wFormatTag
            };
            let sampel = match (tag, fmt.wBitsPerSample) {
                (3, 32) => Sampel::F32,
                (1, 16) => Sampel::I16,
                (1, 24) => Sampel::I24,
                (1, 32) => Sampel::I32,
                _ => anyhow::bail!("unsupported WASAPI sample format"),
            };
            anyhow::ensure!(
                fmt.nChannels > 0
                    && fmt.nSamplesPerSec > 0
                    && usize::from(fmt.nBlockAlign)
                        == usize::from(fmt.nChannels) * sampel.byte_per_sampel(),
                "invalid WASAPI frame layout"
            );
            mix.src = Sumber {
                channels: usize::from(fmt.nChannels),
                rate: fmt.nSamplesPerSec,
                sampel,
            };
            Ok(mix)
        }
    }

    pub fn capture_loop(tx: SyncSender<Vec<u8>>) -> anyhow::Result<()> {
        capture(tx, false)
    }
    pub fn mic_capture_loop(tx: SyncSender<Vec<u8>>) -> anyhow::Result<()> {
        capture(tx, true)
    }
    fn capture(tx: SyncSender<Vec<u8>>, microphone: bool) -> anyhow::Result<()> {
        init_com()?;
        let device = if microphone {
            capture_device()?
        } else {
            device()?
        };
        let client = client(&device)?;
        let mix = mix_format(&client)?;
        let block = unsafe { usize::from((*mix.ptr).nBlockAlign) };
        let channels = if microphone { MIC_CHANNELS } else { CHANNELS };
        unsafe {
            client.Initialize(
                AUDCLNT_SHAREMODE_SHARED,
                if microphone {
                    windows::Win32::Media::Audio::AUDCLNT_STREAMFLAGS_NOPERSIST
                } else {
                    AUDCLNT_STREAMFLAGS_LOOPBACK
                },
                0,
                0,
                mix.ptr,
                None,
            )?;
        }
        let mut packetizer = crate::pcmconv::OpusPcm::new(mix.src, usize::from(channels));
        drop(mix);
        let capture: IAudioCaptureClient = unsafe { client.GetService()? };
        let mut encoder = crate::opus_ffi::Encoder::new(SAMPLE_RATE, usize::from(channels))
            .map_err(|e| anyhow::anyhow!("opus encoder: {e}"))?;
        unsafe { client.Start()? };
        loop {
            // The return value is FRAMES in the next packet, not packet count.
            while unsafe { capture.GetNextPacketSize()? } != 0 {
                let mut data = std::ptr::null_mut();
                let mut frames = 0;
                let mut flags = 0;
                unsafe { capture.GetBuffer(&mut data, &mut frames, &mut flags, None, None)? };
                let bytes = if flags & BUFFERFLAGS_SILENT != 0 || data.is_null() {
                    vec![0; frames as usize * block]
                } else {
                    unsafe { std::slice::from_raw_parts(data, frames as usize * block).to_vec() }
                };
                // Release WASAPI before conversion, encoding, or channel work.
                unsafe { capture.ReleaseBuffer(frames)? };
                for samples in packetizer.push(&bytes) {
                    let mut out = vec![0; 4000];
                    let n = encoder
                        .encode(&samples, &mut out)
                        .map_err(|e| anyhow::anyhow!("opus encode: {e}"))?;
                    out.truncate(n);
                    if tx.send(out).is_err() {
                        return Ok(());
                    }
                }
            }
            std::thread::sleep(std::time::Duration::from_millis(2));
        }
    }

    /// Loop render: decode Opus → tulis ke IAudioRenderClient.
    /// Virtual cable input → recording endpoint untuk aplikasi Windows.
    pub fn render_loop(rx: Receiver<Vec<u8>>) -> anyhow::Result<()> {
        init_com()?;
        crate::virtual_mic::ensure_virtual_mic();
        // Prioritas: virtual cable input (biar jadi mic input di Windows)
        // Speaker playback is NOT an input to Discord/Zoom/game. Fail clearly
        // instead of leaking the phone microphone through host speakers.
        let id = crate::virtual_mic::get_render_device_id()
            .ok_or_else(|| anyhow::anyhow!("mic input unavailable: install/select a virtual audio cable explicitly; no driver was installed"))?;
        let device = device_by_id(&id)?;
        let client = client(&device)?;
        let mix = mix_format(&client)?;
        let src_mix = mix.src;
        let block = unsafe { usize::from((*mix.ptr).nBlockAlign) };
        unsafe {
            // 100 ms = 1,000,000 units of 100 ns (not 10,000,000 = 1 s).
            client.Initialize(
                AUDCLNT_SHAREMODE_SHARED,
                windows::Win32::Media::Audio::AUDCLNT_STREAMFLAGS_NOPERSIST,
                1_000_000,
                0,
                mix.ptr,
                None,
            )?;
        }
        drop(mix);
        let render: IAudioRenderClient = unsafe {
            client
                .GetService::<IAudioRenderClient>()
                .map_err(|e| anyhow::anyhow!("GetService IAudioRenderClient: {e:?}"))?
        };
        let buffer_frames = unsafe { client.GetBufferSize()? } as usize;

        let mut decoder = crate::opus_ffi::Decoder::new(SAMPLE_RATE, usize::from(CHANNELS))
            .map_err(|e| anyhow::anyhow!("opus decoder: {e}"))?;
        // Queue DEVICE-format frames, never confuse 48 kHz frames with the
        // render endpoint's rate or divide WASAPI frame counts by channels.
        let mut pcm_queue = Vec::<u8>::new();
        let max_bytes = (src_mix.rate as usize / 10) * block; // ≤100 ms PCM
        unsafe { client.Start()? };
        loop {
            // Bound each drain pass: sustained traffic must not starve render.
            for _ in 0..4 {
                let pkt = match rx.try_recv() {
                    Ok(pkt) => pkt,
                    Err(std::sync::mpsc::TryRecvError::Empty) => break,
                    Err(std::sync::mpsc::TryRecvError::Disconnected) => return Ok(()),
                };
                // Opus permits packets up to 120 ms, not just 20 ms.
                let mut pcm = vec![0i16; 5_760 * usize::from(CHANNELS)];
                match decoder.decode(&pkt, &mut pcm) {
                    Ok(n) => {
                        let bytes: Vec<u8> = pcm[..n * usize::from(CHANNELS)]
                            .iter()
                            .flat_map(|s| s.to_le_bytes())
                            .collect();
                        pcm_queue.extend(crate::pcmconv::konversi(
                            &bytes,
                            &Sumber {
                                channels: usize::from(CHANNELS),
                                rate: SAMPLE_RATE,
                                sampel: Sampel::I16,
                            },
                            src_mix.channels,
                            src_mix.rate,
                            src_mix.sampel,
                        ));
                        if pcm_queue.len() > max_bytes {
                            pcm_queue.drain(..pcm_queue.len() - max_bytes);
                        }
                    }
                    Err(e) => eprintln!("[xydesk-host] opus decode: {e}"),
                }
            }
            let padding = unsafe { client.GetCurrentPadding()? } as usize;
            let want = buffer_frames
                .saturating_sub(padding)
                .min(pcm_queue.len() / block);
            if want > 0 {
                unsafe {
                    let data = render.GetBuffer(want as u32)?;
                    std::ptr::copy_nonoverlapping(pcm_queue.as_ptr(), data, want * block);
                    render.ReleaseBuffer(want as u32, 0)?;
                }
                pcm_queue.drain(..want * block);
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

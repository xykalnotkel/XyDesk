//! Konstanta, status, dan perakit konfigurasi NVENC — lintas platform, teruji.
//!
//! Dua hal yang sebelumnya tersembunyi di `nvenc.rs` (Windows-only) tanpa
//! satu pun pengujian:
//!
//! 1. **Pemetaan kode status NVENC ke nama.** Sebelumnya log hanya menulis
//!    "NVENC status 15" — tidak bisa dibedakan apakah itu versi struct yang
//!    salah atau GPU yang tidak didukung. `status_name` + `status_hint`
//!    mengubahnya jadi pesan yang bisa ditindaklanjuti manusia.
//! 2. **Perakitan `NV_ENC_CONFIG` / `NV_ENC_INITIALIZE_PARAMS`.** Inilah
//!    kontrak low-latency yang mengejar target roadmap (encode < 10 ms,
//!    glass-to-glass < 40 ms). Satu bit yang bergeser = latensi meledak,
//!    dan tidak ada yang tahu. Uji di bawah mengunci setiap field penting.
//!
//! Modul ini murni aritmetika integer + struct FFI tanpa dependensi Windows,
//! jadi ikut dikompilasi dan diuji CI Linux (`host-test`) padahal pemakainya
//! (`nvenc.rs`) hanya hidup di Windows. Nilai enum & GUID diambil dari
//! `nvEncodeAPI.h` (proyek nv-codec-headers, SDK NVIDIA 12.x — lisensi MIT).

use crate::nvenc_types::{GUID, NV_ENC_CONFIG, NV_ENC_INITIALIZE_PARAMS};

// ── Versi API & struct (SDK 12.2) ───────────────────────────────────────────
/// MAJOR=12, MINOR=2 — driver target R550+ (2024+).
pub const NVENCAPI_VERSION: u32 = 12 | (2u32 << 24);

/// Nomor versi struct NVENC = api | (ver << 16) | (0x7 << 28).
pub const fn struct_ver(ver: u32) -> u32 {
    NVENCAPI_VERSION | (ver << 16) | (0x7 << 28)
}
pub const NV_ENC_CONFIG_VER: u32 = struct_ver(9) | (1u32 << 31);
pub const NV_ENC_INITIALIZE_PARAMS_VER: u32 = struct_ver(7) | (1u32 << 31);
pub const NV_ENC_PIC_PARAMS_VER: u32 = struct_ver(7) | (1u32 << 31);
pub const NV_ENC_LOCK_BITSTREAM_VER: u32 = struct_ver(2) | (1u32 << 31);
pub const NV_ENC_REGISTER_RESOURCE_VER: u32 = struct_ver(5);
pub const NV_ENC_MAP_INPUT_RESOURCE_VER: u32 = struct_ver(4);
pub const NV_ENC_CREATE_BITSTREAM_BUFFER_VER: u32 = struct_ver(1);
pub const NV_ENC_RC_PARAMS_VER: u32 = struct_ver(1);
pub const NV_ENCODE_API_FUNCTION_LIST_VER: u32 = struct_ver(2);

// ── GUID (dari nvEncodeAPI.h) ──────────────────────────────────────────────
/// Perakit GUID — konstanta di bawah ditulis persis seperti header C.
pub const fn guid(d1: u32, d2: u16, d3: u16, d4: [u8; 8]) -> GUID {
    GUID {
        Data1: d1,
        Data2: d2,
        Data3: d3,
        Data4: d4,
    }
}
pub const NV_ENC_CODEC_H264_GUID: GUID = guid(
    0x6bc82762,
    0x4e63,
    0x4ca4,
    [0xaa, 0x85, 0x1e, 0x50, 0xf3, 0x21, 0xf6, 0xbf],
);
pub const NV_ENC_H264_PROFILE_BASELINE_GUID: GUID = guid(
    0x0727bcaa,
    0x78c4,
    0x4c83,
    [0x8c, 0x2f, 0xef, 0x3d, 0xff, 0x26, 0x7c, 0x6a],
);
/// P4 = cepat tapi masih menjaga kualitas teks (layar). Kalau lab nanti
/// menunjukkan encode > 10 ms @1080p60, turunkan ke P1
/// (`0xfc0a8d3e-45f8-4cf8-80c7-298871590ebf`).
pub const NV_ENC_PRESET_P4_GUID: GUID = guid(
    0x90a7b826,
    0xdf06,
    0x4862,
    [0xb9, 0xd2, 0xcd, 0x6d, 0x73, 0xa0, 0x86, 0x81],
);

// ── Nilai enum (dari header) ───────────────────────────────────────────────
pub const NV_ENC_DEVICE_TYPE_DIRECTX: u32 = 0;
pub const NV_ENC_BUFFER_FORMAT_NV12: u32 = 0x1;
pub const NV_ENC_PIC_STRUCT_FRAME: u32 = 0x01;
pub const NV_ENC_PIC_FLAG_FORCEIDR: u32 = 0x2;
pub const NV_ENC_PARAMS_RC_CBR: u32 = 0x2;
pub const NV_ENC_BUFFER_USAGE_INPUT_IMAGE: u32 = 0x0;
pub const NV_ENC_INPUT_RESOURCE_TYPE_DIRECTX: u32 = 0x0;
pub const NV_ENC_MEMORY_HEAP_AUTOSELECT: u32 = 0;
/// Tuning low-latency (berlaku untuk H264) — minta driver mengatur preset
/// untuk streaming latensi rendah.
pub const NV_ENC_TUNING_INFO_LOW_LATENCY: u32 = 2;

// ── Bit flag di field bitfield (posisi bit = urutan deklarasi header) ──────
/// `RC_PARAMS.zeroReorderDelay` — bit ke-9 (tanpa buffer reorder → latensi
/// rendah).
pub const RC_FLAG_ZERO_REORDER_DELAY: u32 = 1 << 9;
/// `CONFIG_H264.repeatSPSPPS` — bit ke-12 (SPS/PPS berulang tiap IDR; klien
/// bisa mulai decode kapan pun — penting untuk WebRTC).
pub const H264_FLAG_REPEAT_SPSPPS: u32 = 1 << 12;

// ── Perakit konfigurasi ─────────────────────────────────────────────────────
/// Frame per detik yang diasumsikan encoder (timestamp & rate control).
pub const ENCODE_FPS: u32 = 60;

/// GOP 120 frame = IDR tiap ~2 dtk @60fps — pulih cepat dari packet loss
/// tanpa membebani bitrate (IDR jauh lebih besar dari P-frame).
pub const GOP_LENGTH: u32 = 120;

/// Rakit `NV_ENC_CONFIG` low-latency untuk H264 CBR `width`x`height` @
/// `bitrate_bps`.
///
/// Alasan tiap keputusan (mengejar target roadmap < 40 ms):
/// - `frameIntervalP = 1`: tanpa B-frame — B-frame butuh buffer reorder.
/// - CBR average == max: bitrate konsisten, tidak meledak di Wi-Fi rumah.
/// - `vbvBufferSize`/`vbvInitialDelay` = 1 frame (`bitrate/60`): buffer VBV
///   0,5 detik (nilai lama `bitrate/2`) boleh menahan bit sampai 500 ms —
///   bertentangan langsung dengan target latensi. Satu frame adalah ukuran
///   terkecil yang wajar; tukarnya fluktuasi kualitas halus saat adegan
///   berubah, yang untuk konten layar tidak masalah.
/// - `zeroReorderDelay`: tanpa antrean reorder di encoder.
/// - `repeatSPSPPS`: parameter set ikut tiap IDR — decoder WebRTC boleh
///   mulai kapan pun.
/// - `videoFullRangeFlag = 1`: layar = RGB 0..255 penuh, bukan studio swing;
///   kalau tidak, kontras jadi pudar.
pub fn build_config(width: u32, height: u32, bitrate_bps: u32) -> NV_ENC_CONFIG {
    let vbv = bitrate_bps / ENCODE_FPS;
    let mut cfg: NV_ENC_CONFIG = unsafe { std::mem::zeroed() };
    cfg.version = NV_ENC_CONFIG_VER;
    cfg.profileGUID = NV_ENC_H264_PROFILE_BASELINE_GUID;
    cfg.gopLength = GOP_LENGTH;
    cfg.frameIntervalP = 1;
    cfg.rcParams.version = NV_ENC_RC_PARAMS_VER;
    cfg.rcParams.rateControlMode = NV_ENC_PARAMS_RC_CBR;
    cfg.rcParams.averageBitRate = bitrate_bps;
    cfg.rcParams.maxBitRate = bitrate_bps;
    cfg.rcParams.vbvBufferSize = vbv;
    cfg.rcParams.vbvInitialDelay = vbv;
    cfg.rcParams
        .bitfieldsEnableminqpEnablemaxqpEnableinitialrcqpEnableaqReservedbitfield1EnablelookaheadDisableiadaptDisablebadaptEnabletemporalaqZeroreorderdelayEnablenonrefpStrictgoptargetAqstrengthEnableextlookaheadReservedbitfields =
        RC_FLAG_ZERO_REORDER_DELAY;
    cfg.encodeCodecConfig
        .h264Config
        .bitfieldsEnabletemporalsvcEnablestereomvcHierarchicalpframesHierarchicalbframesOutputbufferingperiodseiOutputpicturetimingseiOutputaudDisablespsppsOutputframepackingseiOutputrecoverypointseiEnableintrarefreshEnableconstrainedencodingRepeatspsppsEnablevfrEnableltrQpprimeyzerotransformbypassflagUseconstrainedintrapredEnablefillerdatainsertionDisablesvcprefixnaluEnablescalabilityinfoseiSinglesliceintrarefreshEnabletimecodeReservedbitfields =
        H264_FLAG_REPEAT_SPSPPS;
    cfg.encodeCodecConfig
        .h264Config
        .h264VUIParameters
        .videoFullRangeFlag = 1;
    // `width`/`height` tidak dipakai di sini — dimensi disetel di
    // `build_init` (initialize params), bukan di `NV_ENC_CONFIG`.
    let _ = (width, height);
    cfg
}

/// Rakit `NV_ENC_INITIALIZE_PARAMS` untuk sesi H264 sinkron latensi rendah.
/// `cfg` harus hidup selama `NvEncInitializeEncoder` dipanggil (pointer-nya
/// disimpan di struct ini).
pub fn build_init(width: u32, height: u32, cfg: &mut NV_ENC_CONFIG) -> NV_ENC_INITIALIZE_PARAMS {
    let mut init: NV_ENC_INITIALIZE_PARAMS = unsafe { std::mem::zeroed() };
    init.version = NV_ENC_INITIALIZE_PARAMS_VER;
    init.encodeGUID = NV_ENC_CODEC_H264_GUID;
    init.presetGUID = NV_ENC_PRESET_P4_GUID;
    init.encodeWidth = width;
    init.encodeHeight = height;
    init.frameRateNum = ENCODE_FPS;
    init.frameRateDen = 1;
    // Sinkron — PoC latensi rendah, tanpa event queue (lihat nvenc.rs).
    init.enableEncodeAsync = 0;
    // NVENC memilih tipe frame (kecuali force IDR) — tidak ada B-frame karena
    // frameIntervalP = 1 di config.
    init.enablePTD = 1;
    init.tuningInfo = NV_ENC_TUNING_INFO_LOW_LATENCY;
    init.bufferFormat = NV_ENC_BUFFER_FORMAT_NV12;
    init.encodeConfig = cfg as *mut NV_ENC_CONFIG;
    init
}

// ── Pemetaan status → nama ─────────────────────────────────────────────────
/// Nama resmi kode status NVENC (nilai 0–26 dari `nvEncodeAPI.h`).
/// `NV_ENC_ERR_EVENT_NOT_REGISTERD` memakai ejaan NVIDIA apa adanya
/// (tanpa E kedua — begitu di header).
pub fn status_name(code: i32) -> &'static str {
    match code {
        0 => "NV_ENC_SUCCESS",
        1 => "NV_ENC_ERR_NO_ENCODE_DEVICE",
        2 => "NV_ENC_ERR_UNSUPPORTED_DEVICE",
        3 => "NV_ENC_ERR_INVALID_ENCODERDEVICE",
        4 => "NV_ENC_ERR_INVALID_DEVICE",
        5 => "NV_ENC_ERR_DEVICE_NOT_EXIST",
        6 => "NV_ENC_ERR_INVALID_PTR",
        7 => "NV_ENC_ERR_INVALID_EVENT",
        8 => "NV_ENC_ERR_INVALID_PARAM",
        9 => "NV_ENC_ERR_INVALID_CALL",
        10 => "NV_ENC_ERR_OUT_OF_MEMORY",
        11 => "NV_ENC_ERR_ENCODER_NOT_INITIALIZED",
        12 => "NV_ENC_ERR_UNSUPPORTED_PARAM",
        13 => "NV_ENC_ERR_LOCK_BUSY",
        14 => "NV_ENC_ERR_NOT_ENOUGH_BUFFER",
        15 => "NV_ENC_ERR_INVALID_VERSION",
        16 => "NV_ENC_ERR_MAP_FAILED",
        17 => "NV_ENC_ERR_NEED_MORE_INPUT",
        18 => "NV_ENC_ERR_ENCODER_BUSY",
        19 => "NV_ENC_ERR_EVENT_NOT_REGISTERD",
        20 => "NV_ENC_ERR_GENERIC",
        21 => "NV_ENC_ERR_INCOMPATIBLE_CLIENT_KEY",
        22 => "NV_ENC_ERR_UNIMPLEMENTED",
        23 => "NV_ENC_ERR_RESOURCE_REGISTER_FAILED",
        24 => "NV_ENC_ERR_RESOURCE_NOT_REGISTERED",
        25 => "NV_ENC_ERR_RESOURCE_NOT_MAPPED",
        26 => "NV_ENC_ERR_NEED_MORE_OUTPUT",
        _ => "NV_ENC_STATUS_TIDAK_DIKENAL",
    }
}

/// Petunjuk manusiawi untuk kegagalan yang umum dijumpai. `None` = tidak ada
/// petunjuk khusus (status sukses atau error langka).
pub fn status_hint(code: i32) -> Option<&'static str> {
    match code {
        1 => Some("tidak ada GPU NVIDIA yang bisa meng-encode"),
        2 => Some("GPU tidak didukung NVENC (driver terlalu lama?)"),
        3..=5 => Some("device D3D11 tidak sah atau sudah hilang"),
        10 => Some("memori video tidak cukup"),
        11 => Some("encoder belum diinisialisasi"),
        12 => Some("parameter tidak didukung versi driver ini"),
        15 => Some("versi struct tidak cocok dengan driver"),
        18 => Some("encoder sibuk — frame sebelumnya belum selesai"),
        23..=25 => Some("resource D3D11 gagal didaftarkan/dipetakan"),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::screen::DEFAULT_TARGET_BPS;

    const W: u32 = 1920;
    const H: u32 = 1080;

    #[test]
    fn status_terpetakan_ke_nama_resmi() {
        assert_eq!(status_name(0), "NV_ENC_SUCCESS");
        assert_eq!(status_name(2), "NV_ENC_ERR_UNSUPPORTED_DEVICE");
        assert_eq!(status_name(15), "NV_ENC_ERR_INVALID_VERSION");
        assert_eq!(status_name(19), "NV_ENC_ERR_EVENT_NOT_REGISTERD");
        assert_eq!(status_name(26), "NV_ENC_ERR_NEED_MORE_OUTPUT");
    }

    #[test]
    fn semua_kode_sah_dikenali() {
        // 0..=26 adalah rentang NVENCSTATUS dari nvEncodeAPI.h — tidak boleh
        // ada yang jatuh ke "tidak dikenal".
        for code in 0..=26 {
            assert_ne!(
                status_name(code),
                "NV_ENC_STATUS_TIDAK_DIKENAL",
                "kode {code} harus dikenal"
            );
        }
    }

    #[test]
    fn kode_di_luar_rentang_jatuh_ke_tidak_dikenal() {
        for code in [-1, 27, 9999] {
            assert_eq!(status_name(code), "NV_ENC_STATUS_TIDAK_DIKENAL");
            assert_eq!(status_hint(code), None);
        }
    }

    #[test]
    fn petunjuk_untuk_kegagalan_umum() {
        assert_eq!(
            status_hint(2),
            Some("GPU tidak didukung NVENC (driver terlalu lama?)")
        );
        assert_eq!(status_hint(10), Some("memori video tidak cukup"));
        assert_eq!(
            status_hint(15),
            Some("versi struct tidak cocok dengan driver")
        );
        assert_eq!(status_hint(0), None);
        assert_eq!(status_hint(20), None); // generic — tanpa petunjuk khusus
    }

    #[test]
    fn guid_konstanta_sesuai_header() {
        // Kunci byte persis dari nvEncodeAPI.h — jaga-jaga kalau ada yang
        // tidak sengaja mengedit konstanta.
        assert_eq!(NV_ENC_CODEC_H264_GUID.Data1, 0x6bc82762);
        assert_eq!(
            NV_ENC_CODEC_H264_GUID.Data4,
            [0xaa, 0x85, 0x1e, 0x50, 0xf3, 0x21, 0xf6, 0xbf]
        );
        assert_eq!(NV_ENC_PRESET_P4_GUID.Data1, 0x90a7b826);
        assert_eq!(
            NV_ENC_PRESET_P4_GUID.Data4,
            [0xb9, 0xd2, 0xcd, 0x6d, 0x73, 0xa0, 0x86, 0x81]
        );
        assert_eq!(NV_ENC_H264_PROFILE_BASELINE_GUID.Data1, 0x0727bcaa);
    }

    #[test]
    fn config_mengunci_kontrak_low_latency() {
        let cfg = build_config(W, H, DEFAULT_TARGET_BPS);
        assert_eq!(cfg.version, NV_ENC_CONFIG_VER);
        assert_eq!(cfg.profileGUID, NV_ENC_H264_PROFILE_BASELINE_GUID);
        assert_eq!(cfg.gopLength, GOP_LENGTH);
        assert_eq!(cfg.frameIntervalP, 1);
        // Rate control CBR, average == max, VBV satu frame.
        assert_eq!(cfg.rcParams.version, NV_ENC_RC_PARAMS_VER);
        assert_eq!(cfg.rcParams.rateControlMode, NV_ENC_PARAMS_RC_CBR);
        assert_eq!(cfg.rcParams.averageBitRate, DEFAULT_TARGET_BPS);
        assert_eq!(cfg.rcParams.maxBitRate, DEFAULT_TARGET_BPS);
        assert_eq!(cfg.rcParams.vbvBufferSize, DEFAULT_TARGET_BPS / ENCODE_FPS);
        assert_eq!(
            cfg.rcParams.vbvInitialDelay,
            DEFAULT_TARGET_BPS / ENCODE_FPS
        );
        // Bitfield: hanya bit yang kita maksud, tidak lebih.
        assert_eq!(
            cfg.rcParams
                .bitfieldsEnableminqpEnablemaxqpEnableinitialrcqpEnableaqReservedbitfield1EnablelookaheadDisableiadaptDisablebadaptEnabletemporalaqZeroreorderdelayEnablenonrefpStrictgoptargetAqstrengthEnableextlookaheadReservedbitfields,
            RC_FLAG_ZERO_REORDER_DELAY
        );
        // `encodeCodecConfig` union — baca di dalam `unsafe`.
        unsafe {
            assert_eq!(
                cfg.encodeCodecConfig
                    .h264Config
                    .bitfieldsEnabletemporalsvcEnablestereomvcHierarchicalpframesHierarchicalbframesOutputbufferingperiodseiOutputpicturetimingseiOutputaudDisablespsppsOutputframepackingseiOutputrecoverypointseiEnableintrarefreshEnableconstrainedencodingRepeatspsppsEnablevfrEnableltrQpprimeyzerotransformbypassflagUseconstrainedintrapredEnablefillerdatainsertionDisablesvcprefixnaluEnablescalabilityinfoseiSinglesliceintrarefreshEnabletimecodeReservedbitfields,
                H264_FLAG_REPEAT_SPSPPS
            );
            // Layar full-range — kontras tidak dipudarkan decoder.
            assert_eq!(
                cfg.encodeCodecConfig
                    .h264Config
                    .h264VUIParameters
                    .videoFullRangeFlag,
                1
            );
        }
    }

    #[test]
    fn init_mengunci_kontrak_sesi_sinkron() {
        let mut cfg = build_config(W, H, DEFAULT_TARGET_BPS);
        let init = build_init(W, H, &mut cfg);
        assert_eq!(init.version, NV_ENC_INITIALIZE_PARAMS_VER);
        assert_eq!(init.encodeGUID, NV_ENC_CODEC_H264_GUID);
        assert_eq!(init.presetGUID, NV_ENC_PRESET_P4_GUID);
        assert_eq!(init.encodeWidth, W);
        assert_eq!(init.encodeHeight, H);
        assert_eq!(init.frameRateNum, ENCODE_FPS);
        assert_eq!(init.frameRateDen, 1);
        assert_eq!(init.enableEncodeAsync, 0);
        assert_eq!(init.enablePTD, 1);
        assert_eq!(init.tuningInfo, NV_ENC_TUNING_INFO_LOW_LATENCY);
        assert_eq!(init.bufferFormat, NV_ENC_BUFFER_FORMAT_NV12);
        assert_eq!(init.encodeConfig, &mut cfg as *mut NV_ENC_CONFIG);
    }
}

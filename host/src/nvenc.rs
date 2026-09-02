//! NVENC — encoder H.264 hardware NVIDIA (SDK 12.2), dimuat dinamis.
//!
//! Kenapa dinamis (`LoadLibraryW` + `GetProcAddress` alih-alih link langsung):
//! mesin tanpa GPU NVIDIA tetap bisa jalan (fallback openh264 di `screen.rs`),
//! dan program tidak crash saat startup bila DLL tidak ada. Target driver:
//! R550+ (API NVENC 12.x); driver lebih lama → `NvEnc::new` gagal dengan
//! pesan jelas dan `screen.rs` otomatis jatuh ke encoder software.
//!
//! Alur per frame: NV12 (CPU, hasil konversi RGBA) → UpdateSubresource →
//! texture D3D11 → MapInputResource (sekali daftar) → EncodePicture →
//! LockBitstream → salin. Semua sinkron (`enableEncodeAsync = 0`) — PoC
//! latensi rendah, tanpa event queue.
//!
//! Tipe data FFI: `nvenc_types.rs` (hasil generator, layout diverifikasi
//! terhadap header C n12.2 — lisensi MIT, NVIDIA Corporation).
//! Konstanta API, pemetaan status, dan perakit konfigurasi: `nvenc_config.rs`.

#![allow(non_snake_case, dead_code)]

use std::ffi::c_void;
use std::sync::OnceLock;

use windows::core::{s, w, Interface, PCSTR, PCWSTR};
use windows::Win32::Graphics::Direct3D::{D3D_DRIVER_TYPE_HARDWARE, D3D_FEATURE_LEVEL_11_0};
use windows::Win32::Graphics::Direct3D11::{
    D3D11CreateDevice, ID3D11Device, ID3D11DeviceContext, ID3D11Texture2D, D3D11_BIND_DECODER,
    D3D11_SDK_VERSION, D3D11_TEXTURE2D_DESC, D3D11_USAGE_DEFAULT,
};
use windows::Win32::Graphics::Dxgi::Common::DXGI_FORMAT_NV12;
use windows::Win32::System::LibraryLoader::{GetProcAddress, LoadLibraryW};

// Tipe FFI dari modul lintas platform `nvenc_types` (lib.rs) — BUKAN
// instansiasi lokal. Sebelumnya `mod types { include!(...) }` membuat salinan
// tipe tersendiri, sehingga `nvenc_config::build_init` (yang memakai
// `crate::nvenc_types`) dan `FnInitialize` di sini (yang memakai `types::*`)
// dianggap dua tipe berbeda → E0308 di build Windows.
use crate::nvenc_types::*;

// Konstanta API, status, dan perakit konfigurasi pindah ke `nvenc_config.rs`
// (lintas platform, teruji) — nvenc.rs kini hanya memakai, tidak menduplikasi.
// Nilai enum & GUID di sana diambil dari nvEncodeAPI.h SDK 12.x.
use crate::nvenc_config::{
    build_config, build_init, status_hint, status_name, NVENCAPI_VERSION,
    NV_ENCODE_API_FUNCTION_LIST_VER, NV_ENC_BUFFER_FORMAT_NV12, NV_ENC_BUFFER_USAGE_INPUT_IMAGE,
    NV_ENC_CREATE_BITSTREAM_BUFFER_VER, NV_ENC_DEVICE_TYPE_DIRECTX,
    NV_ENC_INPUT_RESOURCE_TYPE_DIRECTX, NV_ENC_LOCK_BITSTREAM_VER, NV_ENC_MAP_INPUT_RESOURCE_VER,
    NV_ENC_MEMORY_HEAP_AUTOSELECT, NV_ENC_PIC_FLAG_FORCEIDR, NV_ENC_PIC_PARAMS_VER,
    NV_ENC_PIC_STRUCT_FRAME, NV_ENC_REGISTER_RESOURCE_VER,
};

type NvEncApiList = NV_ENCODE_API_FUNCTION_LIST;
type FnOpenSession = unsafe extern "system" fn(*mut c_void, u32, *mut *mut c_void) -> i32;
type FnInitialize = unsafe extern "system" fn(*mut c_void, *mut NV_ENC_INITIALIZE_PARAMS) -> i32;
type FnCreateBitstream =
    unsafe extern "system" fn(*mut c_void, *mut NV_ENC_CREATE_BITSTREAM_BUFFER) -> i32;
type FnDestroyBitstream = unsafe extern "system" fn(*mut c_void, *mut c_void) -> i32;
type FnRegisterResource =
    unsafe extern "system" fn(*mut c_void, *mut NV_ENC_REGISTER_RESOURCE) -> i32;
type FnUnregisterResource = unsafe extern "system" fn(*mut c_void, *mut c_void) -> i32;
type FnMapInput = unsafe extern "system" fn(*mut c_void, *mut NV_ENC_MAP_INPUT_RESOURCE) -> i32;
type FnUnmapInput = unsafe extern "system" fn(*mut c_void, *mut c_void) -> i32;
type FnEncodePicture = unsafe extern "system" fn(*mut c_void, *mut NV_ENC_PIC_PARAMS) -> i32;
type FnLockBitstream = unsafe extern "system" fn(*mut c_void, *mut NV_ENC_LOCK_BITSTREAM) -> i32;
type FnUnlockBitstream = unsafe extern "system" fn(*mut c_void, *mut NV_ENC_LOCK_BITSTREAM) -> i32;
type FnDestroyEncoder = unsafe extern "system" fn(*mut c_void) -> i32;

/// Kumpulan fungsi NVENC bertipe — Send+Sync (aman untuk static OnceLock).
#[derive(Clone, Copy)]
struct ApiFns {
    open_session: FnOpenSession,
    initialize: FnInitialize,
    create_bb: FnCreateBitstream,
    destroy_bb: FnDestroyBitstream,
    register: FnRegisterResource,
    unregister: FnUnregisterResource,
    map: FnMapInput,
    unmap: FnUnmapInput,
    encode: FnEncodePicture,
    lock: FnLockBitstream,
    unlock: FnUnlockBitstream,
    destroy: FnDestroyEncoder,
}

/// Status NVENC (NVENCSTATUS) — sukses = 0. Kegagalan diberi nama resmi
/// (`status_name`) + petunjuk (`status_hint`) supaya log terbaca manusia,
/// bukan angka telanjang.
#[inline]
fn ok(status: i32) -> Result<(), String> {
    if status == 0 {
        Ok(())
    } else {
        let name = status_name(status);
        match status_hint(status) {
            Some(hint) => Err(format!("{name} ({status}): {hint}")),
            None => Err(format!("{name} ({status})")),
        }
    }
}

/// Ambil satu fungsi dari daftar API; null → error jelas.
fn take_fn<T: Copy>(ptr: *mut c_void, name: &str) -> Result<T, String> {
    if ptr.is_null() {
        Err(format!("{name} tidak ditemukan di nvEncodeAPI64.dll"))
    } else {
        // T selalu bertipe fn pointer (pointer-sized); baca lewat cast pointer
        // karena transmute generik tidak bisa diverifikasi ukurannya.
        Ok(unsafe { std::ptr::read(ptr as *const T) })
    }
}

/// Muat DLL + ambil daftar fungsi (sekali per proses).
fn load_api() -> Result<&'static ApiFns, String> {
    static API: OnceLock<Result<ApiFns, String>> = OnceLock::new();
    match API.get_or_init(load_impl) {
        Ok(fns) => Ok(fns),
        Err(e) => Err(e.clone()),
    }
}

fn load_impl() -> Result<ApiFns, String> {
    unsafe {
        let dll = LoadLibraryW(PCWSTR(w!("nvEncodeAPI64.dll").as_ptr())).map_err(|e| {
            format!("nvEncodeAPI64.dll tidak dimuat ({e}) — GPU NVIDIA/driver R550+ tidak ada?")
        })?;
        let proc = GetProcAddress(dll, PCSTR(s!("NvEncodeAPICreateInstance").as_ptr()))
            .ok_or_else(|| "NvEncodeAPICreateInstance tidak ditemukan".to_string())?;
        let create: unsafe extern "system" fn(*mut NvEncApiList) -> i32 = std::mem::transmute(proc);
        let mut list: NvEncApiList = std::mem::zeroed();
        list.version = NV_ENCODE_API_FUNCTION_LIST_VER;
        let status = create(&mut list);
        if status != 0 {
            return Err(format!("NvEncodeAPICreateInstance gagal: status {status}"));
        }
        let major = (list.version >> 24) & 0xFF;
        let required_major = (NVENCAPI_VERSION >> 24) & 0xFF;
        if major < required_major {
            return Err(format!(
                "driver NVENC terlalu lama (major {major}); butuh {required_major}+ (driver R550+, 2024+)"
            ));
        }
        Ok(ApiFns {
            open_session: take_fn(list.nvEncOpenEncodeSession, "nvEncOpenEncodeSession")?,
            initialize: take_fn(list.nvEncInitializeEncoder, "nvEncInitializeEncoder")?,
            create_bb: take_fn(
                list.nvEncCreateBitstreamBuffer,
                "nvEncCreateBitstreamBuffer",
            )?,
            destroy_bb: take_fn(
                list.nvEncDestroyBitstreamBuffer,
                "nvEncDestroyBitstreamBuffer",
            )?,
            register: take_fn(list.nvEncRegisterResource, "nvEncRegisterResource")?,
            unregister: take_fn(list.nvEncUnregisterResource, "nvEncUnregisterResource")?,
            map: take_fn(list.nvEncMapInputResource, "nvEncMapInputResource")?,
            unmap: take_fn(list.nvEncUnmapInputResource, "nvEncUnmapInputResource")?,
            encode: take_fn(list.nvEncEncodePicture, "nvEncEncodePicture")?,
            lock: take_fn(list.nvEncLockBitstream, "nvEncLockBitstream")?,
            unlock: take_fn(list.nvEncUnlockBitstream, "nvEncUnlockBitstream")?,
            destroy: take_fn(list.nvEncDestroyEncoder, "nvEncDestroyEncoder")?,
        })
    }
}

/// Ketersediaan NVENC: DLL dimuat + instance API dibuat.
pub fn available() -> bool {
    load_api().is_ok()
}

/// Alasan NVENC tidak tersedia (untuk log/status).
pub fn unavailable_reason() -> Option<String> {
    load_api().err()
}

/// Encoder NVENC. Resource D3D11 dipegang sebagai objek COM; dilepas otomatis
/// saat `drop`.
pub struct NvEnc {
    fns: &'static ApiFns,
    encoder: *mut c_void,

    /// Device & context dipertahankan hidup (resource bergantung pada device).
    #[allow(dead_code)]
    device: ID3D11Device,
    #[allow(dead_code)]
    context: ID3D11DeviceContext,
    texture: ID3D11Texture2D,

    bitstream_buffer: *mut c_void,
    registered_resource: *mut c_void,
    mapped_resource: *mut c_void,

    width: u32,
    height: u32,
    frame_idx: u32,
}

// Aman: windows-capture memindahkan handler sekali ke thread capture-nya,
// dan raw pointer (session NVENC + resource) hanya diakses lewat `&mut self`
// dari thread itu (tidak pernah bersamaan). COM object D3D11 di dalam juga
// diperlakukan sama oleh windows-rs (Send+Sync).
unsafe impl Send for NvEnc {}

impl NvEnc {
    /// Buat encoder H264 hardware [width]x[height] (harus genap).
    pub fn new(width: u32, height: u32, bitrate_bps: u32) -> Result<Self, String> {
        let fns = load_api()?;
        if !width.is_multiple_of(2) || !height.is_multiple_of(2) {
            return Err(format!("dimensi NVENC harus genap: {width}x{height}"));
        }

        unsafe {
            // 1) Device D3D11 — sekaligus "device" session NVENC.
            let mut device: Option<ID3D11Device> = None;
            let mut context: Option<ID3D11DeviceContext> = None;
            D3D11CreateDevice(
                None,
                D3D_DRIVER_TYPE_HARDWARE,
                Default::default(),
                Default::default(),
                Some(&[D3D_FEATURE_LEVEL_11_0]),
                D3D11_SDK_VERSION,
                Some(&mut device as *mut Option<ID3D11Device>),
                None,
                Some(&mut context as *mut Option<ID3D11DeviceContext>),
            )
            .map_err(|e| format!("D3D11CreateDevice gagal: {e}"))?;
            let device = device.ok_or("device D3D11 null")?;
            let context = context.ok_or("context D3D11 null")?;

            // 2) Buka session NVENC.
            let device_raw = device.as_raw();
            let mut encoder: *mut c_void = std::ptr::null_mut();
            ok((fns.open_session)(
                device_raw,
                NV_ENC_DEVICE_TYPE_DIRECTX,
                &mut encoder,
            ))
            .map_err(|e| format!("NvEncOpenEncodeSession: {e}"))?;

            // 3) Inisialisasi: H264 baseline, CBR, low-latency. Kontrak
            // (GOP, frameIntervalP, VBV, bitfield, full-range) dirakit &
            // dikunci uji di nvenc_config.rs — di sini tinggal memakai.
            let mut cfg = build_config(width, height, bitrate_bps);
            let mut init = build_init(width, height, &mut cfg);

            ok((fns.initialize)(encoder, &mut init))
                .map_err(|e| format!("NvEncInitializeEncoder: {e}"))?;

            // 4) Bitstream buffer. Field `size`/`memoryHeap` deprecated di 12.2
            // (driver mengatur sendiri), tapi diisi sesuai konvensi lama agar
            // driver lama tetap memberikan buffer yang cukup besar.
            let mut bb: NV_ENC_CREATE_BITSTREAM_BUFFER = std::mem::zeroed();
            bb.version = NV_ENC_CREATE_BITSTREAM_BUFFER_VER;
            bb.size = width
                .checked_mul(height)
                .and_then(|v| v.checked_mul(2))
                .ok_or_else(|| "ukuran bitstream overflow".to_string())?;
            bb.memoryHeap = NV_ENC_MEMORY_HEAP_AUTOSELECT;
            ok((fns.create_bb)(encoder, &mut bb))
                .map_err(|e| format!("NvEncCreateBitstreamBuffer: {e}"))?;
            let bitstream_buffer = bb.bitstreamBuffer;
            if bitstream_buffer.is_null() {
                return Err("NvEncCreateBitstreamBuffer mengembalikan null".into());
            }

            // 5) Texture NV12 — dibuat sekali, dipakai ulang (upper = Y,
            //    lower = interleaved UV; depth pitch = width*height).
            let desc = D3D11_TEXTURE2D_DESC {
                Width: width,
                Height: height,
                MipLevels: 1,
                ArraySize: 1,
                Format: DXGI_FORMAT_NV12,
                SampleDesc: windows::Win32::Graphics::Dxgi::Common::DXGI_SAMPLE_DESC {
                    Count: 1,
                    Quality: 0,
                },
                Usage: D3D11_USAGE_DEFAULT,
                BindFlags: D3D11_BIND_DECODER.0 as u32,
                CPUAccessFlags: Default::default(),
                MiscFlags: Default::default(),
            };
            let mut texture: Option<ID3D11Texture2D> = None;
            device
                .CreateTexture2D(
                    &desc,
                    None,
                    Some(&mut texture as *mut Option<ID3D11Texture2D>),
                )
                .map_err(|e| format!("CreateTexture2D NV12 gagal: {e}"))?;
            let texture = texture.ok_or("texture null")?;

            // 6) Daftarkan texture (sekali). Untuk DIRECTX, pitch wajib 0.
            let mut rr: NV_ENC_REGISTER_RESOURCE = std::mem::zeroed();
            rr.version = NV_ENC_REGISTER_RESOURCE_VER;
            rr.resourceType = NV_ENC_INPUT_RESOURCE_TYPE_DIRECTX;
            rr.width = width;
            rr.height = height;
            rr.pitch = 0;
            rr.subResourceIndex = 0;
            rr.resourceToRegister = texture.as_raw();
            rr.bufferFormat = NV_ENC_BUFFER_FORMAT_NV12;
            rr.bufferUsage = NV_ENC_BUFFER_USAGE_INPUT_IMAGE;
            ok((fns.register)(encoder, &mut rr))
                .map_err(|e| format!("NvEncRegisterResource: {e}"))?;
            let registered_resource = rr.registeredResource;
            if registered_resource.is_null() {
                return Err("NvEncRegisterResource mengembalikan null".into());
            }

            Ok(Self {
                fns,
                encoder,
                device,
                context,
                texture,
                bitstream_buffer,
                registered_resource,
                mapped_resource: std::ptr::null_mut(),
                width,
                height,
                frame_idx: 0,
            })
        }
    }

    /// Encode satu frame NV12 (ukuran `w*h*3/2`, rapat tanpa padding).
    /// Keluaran: bitstream H264 Annex-B.
    pub fn encode(&mut self, nv12: &[u8]) -> Result<Vec<u8>, String> {
        let expected = (self.width as usize) * (self.height as usize) * 3 / 2;
        if nv12.len() != expected {
            return Err(format!(
                "ukuran input NV12 {} != ekspektasi {expected} ({}x{})",
                nv12.len(),
                self.width,
                self.height
            ));
        }
        unsafe {
            // Salin NV12 CPU → texture (row pitch = width, depth pitch = w*h).
            self.context.UpdateSubresource(
                &self.texture,
                0,
                None,
                nv12.as_ptr() as *const c_void,
                self.width,
                self.width * self.height,
            );

            // Map resource terdaftar → pointer yang dipakai sebagai input.
            let mut map: NV_ENC_MAP_INPUT_RESOURCE = std::mem::zeroed();
            map.version = NV_ENC_MAP_INPUT_RESOURCE_VER;
            map.registeredResource = self.registered_resource;
            ok((self.fns.map)(self.encoder, &mut map))
                .map_err(|e| format!("NvEncMapInputResource: {e}"))?;
            self.mapped_resource = map.mappedResource;

            let mut pp: NV_ENC_PIC_PARAMS = std::mem::zeroed();
            pp.version = NV_ENC_PIC_PARAMS_VER;
            pp.inputWidth = self.width;
            pp.inputHeight = self.height;
            pp.inputPitch = self.width;
            pp.encodePicFlags = if self.frame_idx == 0 {
                NV_ENC_PIC_FLAG_FORCEIDR
            } else {
                0
            };
            pp.frameIdx = self.frame_idx;
            pp.inputTimeStamp = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map(|d| d.as_nanos() as u64)
                .unwrap_or(0);
            pp.inputDuration = 16_666_667; // 60 fps (ns)
            pp.inputBuffer = self.mapped_resource;
            pp.outputBitstream = self.bitstream_buffer;
            pp.bufferFmt = NV_ENC_BUFFER_FORMAT_NV12;
            pp.pictureStruct = NV_ENC_PIC_STRUCT_FRAME;

            ok((self.fns.encode)(self.encoder, &mut pp))
                .map_err(|e| format!("NvEncEncodePicture: {e}"))?;

            // Kunci bitstream → salin → buka (doNotWait = 0 → memblokir sampai
            // frame selesai — sinkron, tanpa spin/event).
            let mut lock: NV_ENC_LOCK_BITSTREAM = std::mem::zeroed();
            lock.version = NV_ENC_LOCK_BITSTREAM_VER;
            lock.outputBitstream = self.bitstream_buffer;
            ok((self.fns.lock)(self.encoder, &mut lock))
                .map_err(|e| format!("NvEncLockBitstream: {e}"))?;
            let size = lock.bitstreamSizeInBytes as usize;
            let data = if size > 0 && !lock.bitstreamBufferPtr.is_null() {
                std::slice::from_raw_parts(lock.bitstreamBufferPtr as *const u8, size).to_vec()
            } else {
                Vec::new()
            };

            let _ = (self.fns.unlock)(self.encoder, &mut lock);
            let _ = (self.fns.unmap)(self.encoder, self.mapped_resource);
            self.mapped_resource = std::ptr::null_mut();

            self.frame_idx = self.frame_idx.wrapping_add(1);
            if self.frame_idx.is_multiple_of(300) {
                println!(
                    "[xydesk-host] nvenc: frame ke-{} ({}x{}, {size} B)",
                    self.frame_idx, self.width, self.height
                );
            }
            Ok(data)
        }
    }
}

impl Drop for NvEnc {
    fn drop(&mut self) {
        unsafe {
            if !self.mapped_resource.is_null() {
                let _ = (self.fns.unmap)(self.encoder, self.mapped_resource);
            }
            if !self.registered_resource.is_null() {
                let _ = (self.fns.unregister)(self.encoder, self.registered_resource);
            }
            if !self.bitstream_buffer.is_null() {
                let _ = (self.fns.destroy_bb)(self.encoder, self.bitstream_buffer);
            }
            if !self.encoder.is_null() {
                let _ = (self.fns.destroy)(self.encoder);
            }
        }
    }
}

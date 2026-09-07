//! Primitif capture DXGI Desktop Duplication — piksel mentah saja.
//!
//! Pembagian tugasnya sama seperti [`crate::gdi`: semua yang menyentuh Win32
//! ada di sini dan TIDAK bergantung pada webrtc/openh264, supaya berkas ini
//! bisa di-type-check untuk target Windows dari Linux lewat `tool/wincheck`.
//! Encode, pace, penyimpanan IDR, dan pengiriman tetap di `screen`, identik
//! dengan jalur WGC/GDI — client tidak boleh bisa membedakan backend dari
//! perilakunya.
//!
//! Mengapa backend ini ada: Desktop Duplication membaca framebuffer langsung
//! dari DXGI output tanpa border kuning WGC dan tanpa round-trip GDI, dan ia
//! satu-satunya jalur yang konsisten 60 fps di GPU modern. Risiko utamanya
//! dikenal dan sudah diantisipasi: pada mesin GPU hibrida, duplikasi harus
//! dibuat dari adapter yang sama dengan display-nya, dan bila tidak, frame
//! datang hitam. Karena itu pemilihan output dicocokkan lewat NAMA perangkat
//! (`\\.\DISPLAYn`) yang dipakai seluruh aplikasi, bukan lewat urutan enum,
//! dan kegagalan di sini tidak fatal — watchdog `screen` akan menurunkan ke
//! WGC lalu GDI.

#[cfg(target_os = "windows")]
#[cfg(target_os = "windows")]
use windows::core::Interface; // menyediakan .cast() antar-interface COM
#[cfg(target_os = "windows")]
use windows::Win32::Foundation::HMODULE;
#[cfg(target_os = "windows")]
use windows::Win32::Graphics::Direct3D::D3D_DRIVER_TYPE_HARDWARE;
#[cfg(target_os = "windows")]
use windows::Win32::Graphics::Direct3D11::{
    D3D11CreateDevice, ID3D11Device, ID3D11DeviceContext, ID3D11Texture2D, D3D11_CPU_ACCESS_READ,
    D3D11_CREATE_DEVICE_BGRA_SUPPORT, D3D11_MAPPED_SUBRESOURCE, D3D11_MAP_READ, D3D11_SDK_VERSION,
    D3D11_TEXTURE2D_DESC, D3D11_USAGE_STAGING,
};
#[cfg(target_os = "windows")]
use windows::Win32::Graphics::Dxgi::{
    Common::{DXGI_FORMAT_B8G8R8A8_UNORM, DXGI_SAMPLE_DESC},
    CreateDXGIFactory1, IDXGIFactory1, IDXGIOutputDuplication, IDXGIResource,
    DXGI_ERROR_ACCESS_LOST, DXGI_ERROR_WAIT_TIMEOUT, DXGI_OUTDUPL_FRAME_INFO,
};

/// Satu sesi Desktop Duplication pada satu output, plus tekstur staging untuk
/// menarik piksel ke CPU.
#[cfg(target_os = "windows")]
pub struct DxgiCapture {
    dupl: IDXGIOutputDuplication,
    context: ID3D11DeviceContext,
    staging: ID3D11Texture2D,
    buf: Vec<u8>,
    width: usize,
    height: usize,
}

#[cfg(target_os = "windows")]
impl DxgiCapture {
    /// Buka sesi duplikasi untuk perangkat bernama `nama_perangkat`
    /// (mis. `\\.\DISPLAY1`) — nama yang sama dengan yang dilaporkan
    /// `screen::list_displays`, jadi pilihan monitor konsisten di seluruh
    /// aplikasi dan tidak bergantung pada urutan enum adapter.
    pub fn baru(nama_perangkat: &str) -> Result<Self, String> {
        unsafe {
            let mut device: Option<ID3D11Device> = None;
            let mut context: Option<ID3D11DeviceContext> = None;
            // BGRA_SUPPORT wajib: tekstur hasil duplikasi berformat BGRA.
            // Daftar feature level kosong = biar runtime memilih yang terbaik.
            D3D11CreateDevice(
                None,
                D3D_DRIVER_TYPE_HARDWARE,
                HMODULE::default(),
                D3D11_CREATE_DEVICE_BGRA_SUPPORT,
                None, // feature level: biar runtime memilih yang terbaik
                D3D11_SDK_VERSION,
                Some(&mut device),
                None,
                Some(&mut context),
            )
            .map_err(|e| format!("d3d11 device: {e}"))?;
            let device = device.ok_or("d3d11 device: kosong")?;
            let context = context.ok_or("d3d11 context: kosong")?;

            let factory: IDXGIFactory1 =
                CreateDXGIFactory1().map_err(|e| format!("dxgi factory: {e}"))?;

            let mut ai = 0u32;
            while let Ok(adapter) = factory.EnumAdapters1(ai) {
                let mut oi = 0u32;
                while let Ok(output) = adapter.EnumOutputs(oi) {
                    oi += 1;
                    let desc = output.GetDesc().map_err(|e| format!("desc output: {e}"))?;
                    let nama = String::from_utf16_lossy(&desc.DeviceName);
                    let nama = nama.trim_matches('\0');
                    if nama != nama_perangkat {
                        continue;
                    }
                    let output1 = output
                        .cast::<windows::Win32::Graphics::Dxgi::IDXGIOutput1>()
                        .map_err(|e| format!("output1: {e}"))?;
                    let dupl = output1
                        .DuplicateOutput(&device)
                        .map_err(|e| format!("duplikasi output {nama}: {e}"))?;
                    let ddesc = dupl.GetDesc();
                    let width = ddesc.ModeDesc.Width as usize;
                    let height = ddesc.ModeDesc.Height as usize;
                    if width == 0 || height == 0 {
                        return Err(format!("output {nama}: resolusi nol"));
                    }

                    // Tekstur staging sekali di depan: CopyResource + Map per
                    // frame jauh lebih murah daripada membuat tekstur baru.
                    let td = D3D11_TEXTURE2D_DESC {
                        Width: width as u32,
                        Height: height as u32,
                        MipLevels: 1,
                        ArraySize: 1,
                        Format: DXGI_FORMAT_B8G8R8A8_UNORM,
                        SampleDesc: DXGI_SAMPLE_DESC {
                            Count: 1,
                            Quality: 0,
                        },
                        Usage: D3D11_USAGE_STAGING,
                        BindFlags: 0,
                        CPUAccessFlags: D3D11_CPU_ACCESS_READ.0 as u32,
                        MiscFlags: 0,
                    };
                    let mut staging: Option<ID3D11Texture2D> = None;
                    device
                        .CreateTexture2D(&td, None, Some(&mut staging))
                        .map_err(|e| format!("staging: {e}"))?;
                    let staging = staging.ok_or("staging: kosong")?;

                    return Ok(Self {
                        dupl,
                        context,
                        staging,
                        buf: vec![0u8; width * height * 4],
                        width,
                        height,
                    });
                }
                ai += 1;
            }
            Err(format!(
                "output {nama_perangkat} tidak ditemukan di adapter DXGI"
            ))
        }
    }

    pub fn width(&self) -> usize {
        self.width
    }

    pub fn height(&self) -> usize {
        self.height
    }

    /// Piksel BGRA frame terakhir, stride rapat `width * 4`.
    pub fn pixels(&self) -> &[u8] {
        &self.buf
    }

    /// Ambil frame berikutnya dari output.
    ///
    /// `Ok(true)`  = buffer diperbarui dengan frame baru.
    /// `Ok(false)` = tidak ada perubahan layar sampai batas tunggu (normal
    ///               untuk Desktop Duplication; pemanggil cukup mencoba lagi).
    /// `Err("access-lost")` = sesi duplikasi mati (ganti resolusi, ganti
    ///               monitor, kunci sesi) — pemanggil harus respawn/escalate.
    pub fn grab(&mut self, tunggu_ms: u32) -> Result<bool, String> {
        unsafe {
            let mut info = DXGI_OUTDUPL_FRAME_INFO::default();
            let mut res: Option<IDXGIResource> = None;
            if let Err(e) = self.dupl.AcquireNextFrame(tunggu_ms, &mut info, &mut res) {
                if e.code() == DXGI_ERROR_WAIT_TIMEOUT {
                    return Ok(false);
                }
                if e.code() == DXGI_ERROR_ACCESS_LOST {
                    return Err("access-lost".to_string());
                }
                return Err(format!("acquire: {e}"));
            }
            // Frame sudah di tangan walaupun salinannya gagal: lepas dulu
            // supaya antrean duplikasi tidak macet.
            let hasil = self.salin_ke_staging(res.as_ref());
            let _ = self.dupl.ReleaseFrame();
            hasil
        }
    }

    fn salin_ke_staging(&mut self, res: Option<&IDXGIResource>) -> Result<bool, String> {
        let Some(res) = res else { return Ok(false) };
        unsafe {
            let tex: ID3D11Texture2D = res.cast().map_err(|e| format!("cast tekstur: {e}"))?;
            self.context.CopyResource(&self.staging, &tex);
            let mut mapped = D3D11_MAPPED_SUBRESOURCE::default();
            self.context
                .Map(&self.staging, 0, D3D11_MAP_READ, 0, Some(&mut mapped))
                .map_err(|e| format!("map: {e}"))?;
            let src = mapped.pData as *const u8;
            let row = mapped.RowPitch as usize;
            let rapat = self.width * 4;
            // RowPitch bisa lebih lebar dari baris nyata (padding GPU), jadi
            // disalin per baris, bukan satu memcpy besar.
            if src.is_null() || row < rapat {
                self.context.Unmap(&self.staging, 0);
                return Err("map: pointer baris tidak sah".to_string());
            }
            for y in 0..self.height {
                self.buf[y * rapat..(y + 1) * rapat]
                    .copy_from_slice(std::slice::from_raw_parts(src.add(y * row), rapat));
            }
            self.context.Unmap(&self.staging, 0);
        }
        Ok(true)
    }
}

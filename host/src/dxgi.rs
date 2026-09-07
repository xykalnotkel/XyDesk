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
//! (`\\.\\DISPLAYn`) yang dipakai seluruh aplikasi, bukan lewat urutan enum,
//! dan kegagalan di sini tidak fatal — watchdog `screen` akan menurunkan ke
//! WGC lalu GDI.

#[cfg(target_os = "windows")]
use windows::core::Interface;
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
    /// (mis. `\\.\\DISPLAY1`) — nama yang sama dengan yang dilaporkan
    /// `screen::list_displays`, jadi pilihan monitor konsisten di seluruh
    /// aplikasi dan tidak bergantung pada urutan enum adapter.
    ///
    /// Untuk VM / RDP tanpa monitor fisik, kalau nama tidak ketemu, fallback
    /// ke output pertama yang tersedia (adapter 0, output 0) — itu sering
    /// jadi satu-satunya display di GPU VM (mis. NVIDIA vGPU, Paperspace).
    pub fn baru(nama_perangkat: &str) -> Result<Self, String> {
        unsafe {
            let mut device: Option<ID3D11Device> = None;
            let mut context: Option<ID3D11DeviceContext> = None;
            D3D11CreateDevice(
                None,
                D3D_DRIVER_TYPE_HARDWARE,
                HMODULE::default(),
                D3D11_CREATE_DEVICE_BGRA_SUPPORT,
                None,
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

            // Simpan kandidat fallback (output pertama) untuk VM headless
            let mut fallback: Option<(IDXGIOutputDuplication, usize, usize)> = None;
            let mut exact: Option<(IDXGIOutputDuplication, usize, usize)> = None;

            let mut ai = 0u32;
            while let Ok(adapter) = factory.EnumAdapters1(ai) {
                let mut oi = 0u32;
                while let Ok(output) = adapter.EnumOutputs(oi) {
                    oi += 1;
                    let desc = output.GetDesc().map_err(|e| format!("desc output: {e}"))?;
                    let nama = String::from_utf16_lossy(&desc.DeviceName);
                    let nama = nama.trim_matches('\0');
                    let output1 = match output.cast::<windows::Win32::Graphics::Dxgi::IDXGIOutput1>() {
                        Ok(o) => o,
                        Err(_) => continue,
                    };
                    let dupl = match output1.DuplicateOutput(&device) {
                        Ok(d) => d,
                        Err(_) => continue,
                    };
                    let ddesc = dupl.GetDesc();
                    let width = ddesc.ModeDesc.Width as usize;
                    let height = ddesc.ModeDesc.Height as usize;
                    if width == 0 || height == 0 {
                        continue;
                    }
                    if nama == nama_perangkat {
                        exact = Some((dupl, width, height));
                        break;
                    }
                    if fallback.is_none() {
                        fallback = Some((dupl, width, height));
                    }
                }
                if exact.is_some() {
                    break;
                }
                ai += 1;
            }

            let (dupl, width, height) = if let Some(e) = exact {
                e
            } else if let Some(f) = fallback {
                eprintln!(
                    "[xydesk-host] DXGI: output {nama_perangkat} tidak ketemu — fallback ke output pertama {}x{} (VM/RDP?)",
                    f.1, f.2
                );
                f
            } else {
                return Err(format!(
                    "output {nama_perangkat} tidak ditemukan di adapter DXGI (tidak ada output sama sekali — VM tanpa display?)"
                ));
            };

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

            Ok(Self {
                dupl,
                context,
                staging,
                buf: vec![0u8; width * height * 4],
                width,
                height,
            })
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
    pub fn grab(&mut self, tunggu_ms: u32) -> Result<bool, String> {
        unsafe {
            let mut info = DXGI_OUTDUPL_FRAME_INFO::default();
            let mut res: Option<IDXGIResource> = None;
            if let Err(e) = self.dupl.AcquireNextFrame(tunggu_ms, &mut info, &mut res) {
                if e.code() == DXGI_ERROR_WAIT_TIMEOUT {
                    return Ok(false);
                }
                if e.code() == DXGI_ERROR_ACCESS_LOST {
                    return Err("access-lost (resolusi ganti / sesi terkunci / RDP disconnect)".to_string());
                }
                return Err(format!("acquire: {e}"));
            }
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
            if src.is_null() || row < rapat {
                self.context.Unmap(&self.staging, 0);
                return Err("map: pointer baris tidak sah (GPU reset?)".to_string());
            }
            for y in 0..self.height {
                self.buf[y * rapat..(y + 1) * rapat]
                    .copy_from_slice(std::slice::from_raw_parts(src.add(y * row), rapat));
            }
            self.context.Unmap(&self.staging, 0);
        }
        // Deteksi frame hitam total di DXGI juga — di VM GPU kadang duplikasi
        // berhasil tapi frame hitam karena adapter salah.
        if self.buf.iter().take(400).all(|&b| b == 0) {
            static mut LAST_WARN: Option<std::time::Instant> = None;
            let now = std::time::Instant::now();
            let should = unsafe {
                if let Some(last) = LAST_WARN {
                    now.duration_since(last).as_secs() >= 5
                } else {
                    true
                }
            };
            if should {
                eprintln!("[xydesk-host] DXGI: frame hitam total terdeteksi — mungkin GPU hibrida / VM tanpa output");
                unsafe { LAST_WARN = Some(now); }
            }
        }
        Ok(true)
    }
}

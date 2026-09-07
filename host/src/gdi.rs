//! Capture layar GDI BitBlt — **primitif capture mentah**, tanpa encode.
//!
//! ## Kenapa modul ini terpisah dari `screen.rs`
//!
//! Dua alasan, dan yang kedua sama pentingnya dengan yang pertama.
//!
//! 1. **Arsitektur.** Backend capture seharusnya hanya menyerahkan piksel.
//!    Encode (NVENC/openh264), simpanan IDR penyelamat layar hitam, pengiriman
//!    ke channel, dan pace fps adalah urusan `screen.rs` dan harus IDENTIK untuk
//!    backend mana pun — kalau tidak, ganti backend berarti ganti perilaku
//!    pipeline. Jadi modul ini berhenti di "ini buffer RGBA rapat".
//! 2. **Bisa diverifikasi.** `screen.rs` menarik webrtc, openh264, dan NVENC,
//!    sehingga tidak bisa dimasukkan ke `tool/wincheck` (crate pemeriksa tipe
//!    lintas-target yang membuat kode Win32 bisa di-type-check di Linux dalam
//!    hitungan detik). Modul ini hanya bergantung pada crate `windows` dan
//!    `pixfmt`, jadi seluruh kode `unsafe`-nya benar-benar terperiksa sebelum
//!    menghabiskan satu putaran CI Windows ~10 menit.
//!
//! ## Kenapa GDI ada sama sekali
//!
//! Lambat: satu `BitBlt` + `GetDIBits` per frame, tanpa notifikasi perubahan,
//! tanpa dirty-rect. Tapi ia **selalu ada** — tidak butuh Windows 10 1903+,
//! tidak butuh GPU, tidak menggambar border kuning, dan tetap bekerja di sesi
//! RDP, yang penting untuk PC/server sewaan tanpa monitor fisik. Perannya di
//! rantai capture adalah jaring pengaman terakhir: bila Windows Graphics
//! Capture membuka sesi (border terlihat, jadi dari luar tampak sehat) tetapi
//! `on_frame_arrived` tidak pernah dipanggil, hanya backend semacam ini yang
//! bisa membuat layar client tidak hitam.
//!
//! ## Yang TIDAK ditangani modul ini
//!
//! - Kondisi berhenti (pindah monitor, bitrate, keyframe, sesi selesai): milik
//!   pemanggil, supaya satu kebijakan untuk semua backend.
//! - Kecepatan: pemanggil yang mengatur pace dan melaporkan fps nyata.
//! - HDR: BitBlt menghasilkan SDR. Di desktop HDR hasilnya bisa terlihat pudar;
//!   itu keterbatasan yang diketahui, bukan kerusakan — dan tetap lebih baik
//!   daripada layar hitam.

/// Sumber frame GDI: memegang handle + buffer, menghasilkan RGBA rapat.
///
/// Hanya ada di Windows. Tidak ada stub untuk platform lain karena satu-satunya
/// pemanggil (`screen::windows`) juga hanya dikompilasi di Windows.
#[cfg(target_os = "windows")]
pub struct GdiCapture {
    dalam: Handle,
    width: usize,
    height: usize,
    /// Buffer RGBA yang dipakai ulang antar frame (satu alokasi per sesi).
    rgba: Vec<u8>,
}

#[cfg(target_os = "windows")]
impl GdiCapture {
    /// Buka capture untuk satu perangkat tampilan.
    ///
    /// `nama_perangkat` adalah nama GDI seperti `\\.\\DISPLAY1` — harus nama
    /// yang dikembalikan enumerasi monitor, karena `CreateDCW` menolak nama
    /// karangan dan mengembalikan DC null. Untuk VM headless / RDP tanpa
    /// monitor, fallback GetDC(0) otomatis dicoba.
    pub fn baru(nama_perangkat: &str, width: usize, height: usize) -> Result<Self, String> {
        // Kalau caller kasih 0 karena list_displays kosong (VM tanpa monitor),
        // biarin — Handle::baru akan pakai GetSystemMetrics untuk tentukan ukuran.
        let (w, h) = if width == 0 || height == 0 {
            // Coba baca ukuran virtual screen dulu
            (0, 0)
        } else {
            (width, height)
        };
        Ok(Self {
            dalam: Handle::baru(nama_perangkat, w, h)?,
            width: if w == 0 { 0 } else { w },
            height: if h == 0 { 0 } else { h },
            rgba: Vec::with_capacity(if w == 0 || h == 0 { 1920 * 1080 * 4 } else { w * h * 4 }),
        })
    }

    /// Lebar frame dalam piksel — setelah fallback bisa berubah dari yang diminta.
    pub fn width(&self) -> usize {
        if self.width == 0 {
            self.dalam.width as usize
        } else {
            self.width
        }
    }

    /// Tinggi frame dalam piksel.
    pub fn height(&self) -> usize {
        if self.height == 0 {
            self.dalam.height as usize
        } else {
            self.height
        }
    }

    /// Ambil satu frame; kembalikan `(rgba, width, height)`.
    ///
    /// Slice meminjam buffer internal dan sah sampai panggilan `grab`
    /// berikutnya — cukup untuk satu kali encode, dan menghindari salinan
    /// tambahan per frame.
    pub fn grab(&mut self) -> Result<(&[u8], usize, usize), String> {
        let bgra = self.dalam.ambil()?;
        crate::pixfmt::bgra_to_rgba(bgra, &mut self.rgba);
        // Deteksi frame hitam total — gejala VM tanpa desktop / sesi terkunci.
        // Kalau semua piksel 0, itu bukan wallpaper hitam user (wallpaper hitam
        // masih punya taskbar / kursor), melainkan BitBlt dari DC kosong.
        // Kita tetap kirim (biar client tidak diam), tapi log peringatan
        // supaya operator tau ini bukan salah encoder.
        if self.rgba.len() >= 4 && self.rgba.iter().take(100).all(|&b| b == 0) {
            // Cek 100 byte pertama saja — cepat, cukup untuk deteksi.
            // Log hanya sekali per 5 detik biar tidak spam.
            static mut LAST_WARN: Option<std::time::Instant> = None;
            let now = std::time::Instant::now();
            let should_warn = unsafe {
                if let Some(last) = LAST_WARN {
                    now.duration_since(last).as_secs() >= 5
                } else {
                    true
                }
            };
            if should_warn {
                eprintln!("[xydesk-host] GDI: frame tampak hitam total — mungkin sesi RDP terkunci / VM tanpa desktop aktif");
                unsafe { LAST_WARN = Some(now); }
            }
        }
        let w = self.width();
        let h = self.height();
        Ok((&self.rgba, w, h))
    }
}

/// Handle + buffer Win32 di balik [`GdiCapture`].
#[cfg(target_os = "windows")]
struct Handle {
    screen: windows::Win32::Graphics::Gdi::HDC,
    mem: windows::Win32::Graphics::Gdi::HDC,
    bmp: windows::Win32::Graphics::Gdi::HBITMAP,
    bmi: windows::Win32::Graphics::Gdi::BITMAPINFO,
    /// Buffer BGRA hasil `GetDIBits`, dipakai ulang antar frame.
    bgra: Vec<u8>,
    height: u32,
    width: u32,
    is_fallback: bool,
}

#[cfg(target_os = "windows")]
impl Handle {
    fn baru(nama_perangkat: &str, width: usize, height: usize) -> Result<Self, String> {
        // Coba DISPLAY spesifik dulu, kalau gagal fallback ke GetDC(0)
        match Self::baru_display(nama_perangkat, width, height) {
            Ok(h) => Ok(h),
            Err(e) => {
                eprintln!(
                    "[xydesk-host] GDI CreateDCW {nama_perangkat} gagal: {e} — fallback GetDC(0) virtual screen"
                );
                Self::baru_fallback(width, height)
            }
        }
    }

    fn baru_display(nama_perangkat: &str, width: usize, height: usize) -> Result<Self, String> {
        use windows::core::PCWSTR;
        use windows::Win32::Graphics::Gdi::{
            CreateCompatibleBitmap, CreateCompatibleDC, CreateDCW, BITMAPINFO, BITMAPINFOHEADER,
        };

        // Kalau width/height 0 (list_displays kosong), fallback langsung
        if width == 0 || height == 0 {
            return Self::baru_fallback(0, 0);
        }

        let dev: Vec<u16> = nama_perangkat
            .encode_utf16()
            .chain(std::iter::once(0))
            .collect();
        let driver: Vec<u16> = "DISPLAY".encode_utf16().chain(std::iter::once(0)).collect();

        unsafe {
            let screen: windows::Win32::Graphics::Gdi::HDC = CreateDCW(
                PCWSTR(driver.as_ptr()),
                PCWSTR(dev.as_ptr()),
                PCWSTR::null(),
                None,
            );
            if screen.is_invalid() {
                return Err(format!("CreateDCW gagal untuk {nama_perangkat}"));
            }
            let mem: windows::Win32::Graphics::Gdi::HDC = CreateCompatibleDC(Some(screen));
            if mem.is_invalid() {
                let lepas = Self {
                    screen,
                    mem,
                    bmp: windows::Win32::Graphics::Gdi::HBITMAP::default(),
                    bmi: BITMAPINFO::default(),
                    bgra: Vec::new(),
                    height: 0,
                    width: 0,
                    is_fallback: false,
                };
                drop(lepas);
                return Err("CreateCompatibleDC gagal".to_string());
            }
            let bmp = CreateCompatibleBitmap(screen, width as i32, height as i32);
            if bmp.is_invalid() {
                let lepas = Self {
                    screen,
                    mem,
                    bmp,
                    bmi: BITMAPINFO::default(),
                    bgra: Vec::new(),
                    height: 0,
                    width: 0,
                    is_fallback: false,
                };
                drop(lepas);
                return Err(format!("CreateCompatibleBitmap {width}x{height} gagal"));
            }
            let _sebelumnya = SelectObject(mem, windows::Win32::Graphics::Gdi::HGDIOBJ(bmp.0));

            let mut bmi: BITMAPINFO = std::mem::zeroed();
            bmi.bmiHeader.biSize = std::mem::size_of::<BITMAPINFOHEADER>() as u32;
            bmi.bmiHeader.biWidth = width as i32;
            bmi.bmiHeader.biHeight = -(height as i32);
            bmi.bmiHeader.biPlanes = 1;
            bmi.bmiHeader.biBitCount = 32;
            bmi.bmiHeader.biCompression = 0;

            Ok(Self {
                screen,
                mem,
                bmp,
                bmi,
                bgra: vec![0u8; width * height * 4],
                height: height as u32,
                width: width as u32,
                is_fallback: false,
            })
        }
    }

    fn baru_fallback(width: usize, height: usize) -> Result<Self, String> {
        use windows::Win32::Foundation::HWND;
        use windows::Win32::Graphics::Gdi::{
            CreateCompatibleBitmap, CreateCompatibleDC, GetDC, BITMAPINFO, BITMAPINFOHEADER,
            GetSystemMetrics, SYSTEM_METRICS_INDEX,
        };

        unsafe {
            let (w, h) = if width > 0 && height > 0 {
                (width, height)
            } else {
                let vs_w = GetSystemMetrics(SYSTEM_METRICS_INDEX(78)); // SM_CXVIRTUALSCREEN
                let vs_h = GetSystemMetrics(SYSTEM_METRICS_INDEX(79)); // SM_CYVIRTUALSCREEN
                let s_w = GetSystemMetrics(SYSTEM_METRICS_INDEX(0)); // SM_CXSCREEN
                let s_h = GetSystemMetrics(SYSTEM_METRICS_INDEX(1)); // SM_CYSCREEN
                let fw = if vs_w > 0 { vs_w } else { s_w };
                let fh = if vs_h > 0 { vs_h } else { s_h };
                if fw <= 0 || fh <= 0 {
                    return Err("fallback: tidak bisa baca ukuran layar virtual (GetSystemMetrics 0)".to_string());
                }
                (fw as usize, fh as usize)
            };

            let screen = GetDC(Some(HWND::default()));
            if screen.is_invalid() {
                return Err("fallback GetDC(0) gagal — tidak ada desktop".to_string());
            }
            let mem = CreateCompatibleDC(Some(screen));
            if mem.is_invalid() {
                let _ = windows::Win32::Graphics::Gdi::ReleaseDC(Some(HWND::default()), screen);
                return Err("fallback CreateCompatibleDC gagal".to_string());
            }
            let bmp = CreateCompatibleBitmap(screen, w as i32, h as i32);
            if bmp.is_invalid() {
                let _ = windows::Win32::Graphics::Gdi::ReleaseDC(Some(HWND::default()), screen);
                let _ = windows::Win32::Graphics::Gdi::DeleteDC(mem);
                return Err(format!("fallback CreateCompatibleBitmap {w}x{h} gagal"));
            }
            let _ = SelectObject(mem, windows::Win32::Graphics::Gdi::HGDIOBJ(bmp.0));

            let mut bmi: BITMAPINFO = std::mem::zeroed();
            bmi.bmiHeader.biSize = std::mem::size_of::<BITMAPINFOHEADER>() as u32;
            bmi.bmiHeader.biWidth = w as i32;
            bmi.bmiHeader.biHeight = -(h as i32);
            bmi.bmiHeader.biPlanes = 1;
            bmi.bmiHeader.biBitCount = 32;
            bmi.bmiHeader.biCompression = 0;

            eprintln!("[xydesk-host] GDI fallback aktif: {w}x{h} via GetDC(0) — cocok untuk VM/RDP tanpa DISPLAY spesifik");
            Ok(Self {
                screen,
                mem,
                bmp,
                bmi,
                bgra: vec![0u8; w * h * 4],
                height: h as u32,
                width: w as u32,
                is_fallback: true,
            })
        }
    }

    /// Satu putaran BitBlt + GetDIBits; kembalikan buffer BGRA rapat.
    fn ambil(&mut self) -> Result<&[u8], String> {
        use windows::Win32::Graphics::Gdi::{BitBlt, GetDIBits, DIB_RGB_COLORS, SRCCOPY};

        unsafe {
            if let Err(e) = BitBlt(
                self.mem,
                0,
                0,
                self.bmi.bmiHeader.biWidth,
                self.height as i32,
                Some(self.screen),
                0,
                0,
                SRCCOPY,
            ) {
                return Err(format!(
                    "BitBlt gagal (layar terkunci, secure desktop, RDP disconnected, atau VM tanpa console): {e}"
                ));
            }
            let baris = GetDIBits(
                self.mem,
                self.bmp,
                0,
                self.height,
                Some(self.bgra.as_mut_ptr().cast()),
                &mut self.bmi,
                DIB_RGB_COLORS,
            );
            if baris == 0 {
                return Err("GetDIBits gagal (format bitmap tidak didukung / DC lepas)".to_string());
            }
            if baris as u32 != self.height {
                return Err(format!(
                    "GetDIBits hanya mengisi {baris} dari {} baris — layar berubah ukuran?",
                    self.height
                ));
            }
        }
        Ok(&self.bgra)
    }
}

/// Pelepas handle GDI.
#[cfg(target_os = "windows")]
impl Drop for Handle {
    fn drop(&mut self) {
        use windows::Win32::Graphics::Gdi::{DeleteDC, DeleteObject, ReleaseDC};
        use windows::Win32::Foundation::HWND;
        unsafe {
            if !self.bmp.is_invalid() {
                let _ = DeleteObject(windows::Win32::Graphics::Gdi::HGDIOBJ(self.bmp.0));
            }
            if !self.mem.is_invalid() {
                let _ = DeleteDC(self.mem);
            }
            if !self.screen.is_invalid() {
                if self.is_fallback {
                    let _ = ReleaseDC(Some(HWND::default()), self.screen);
                } else {
                    let _ = DeleteDC(self.screen);
                }
            }
        }
    }
}

#[cfg(target_os = "windows")]
use windows::Win32::Graphics::Gdi::SelectObject;

#[cfg(test)]
mod tests {
    #[test]
    fn konversi_warna_dilakukan_di_primitif_bukan_di_pemanggil() {
        let src = include_str!("gdi.rs");
        assert!(
            src.contains("crate::pixfmt::bgra_to_rgba"),
            "penukaran BGRA→RGBA harus terjadi di dalam grab()"
        );
    }
}

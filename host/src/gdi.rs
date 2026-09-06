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
    /// `nama_perangkat` adalah nama GDI seperti `\\.\DISPLAY1` — harus nama
    /// yang dikembalikan enumerasi monitor, karena `CreateDCW` menolak nama
    /// karangan dan mengembalikan DC null.
    pub fn baru(nama_perangkat: &str, width: usize, height: usize) -> Result<Self, String> {
        if width == 0 || height == 0 {
            return Err(format!("ukuran capture tidak sah: {width}x{height}"));
        }
        Ok(Self {
            dalam: Handle::baru(nama_perangkat, width, height)?,
            width,
            height,
            rgba: Vec::with_capacity(width * height * 4),
        })
    }

    /// Lebar frame dalam piksel.
    pub fn width(&self) -> usize {
        self.width
    }

    /// Tinggi frame dalam piksel.
    pub fn height(&self) -> usize {
        self.height
    }

    /// Ambil satu frame; kembalikan `(rgba, width, height)`.
    ///
    /// Slice meminjam buffer internal dan sah sampai panggilan `grab`
    /// berikutnya — cukup untuk satu kali encode, dan menghindari salinan
    /// tambahan per frame.
    pub fn grab(&mut self) -> Result<(&[u8], usize, usize), String> {
        // `dalam` dan `rgba` adalah field berbeda, jadi borrow keduanya tidak
        // bertabrakan: hasil BitBlt (BGRA) langsung ditukar ke RGBA di sini.
        let bgra = self.dalam.ambil()?;
        crate::pixfmt::bgra_to_rgba(bgra, &mut self.rgba);
        Ok((&self.rgba, self.width, self.height))
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
}

#[cfg(target_os = "windows")]
impl Handle {
    fn baru(nama_perangkat: &str, width: usize, height: usize) -> Result<Self, String> {
        use windows::core::PCWSTR;
        use windows::Win32::Graphics::Gdi::{
            CreateCompatibleBitmap, CreateCompatibleDC, CreateDCW, BITMAPINFO, BITMAPINFOHEADER,
        };

        let dev: Vec<u16> = nama_perangkat
            .encode_utf16()
            .chain(std::iter::once(0))
            .collect();
        let driver: Vec<u16> = "DISPLAY".encode_utf16().chain(std::iter::once(0)).collect();

        unsafe {
            // `CreateDCW`/`CreateCompatibleDC` mengembalikan `HDC` langsung di
            // crate `windows` 0.61 (dulu dibungkus `CreatedHDC`). Dipastikan
            // lewat `tool/wincheck`, bukan ditebak — konversi `.into()` yang
            // berjaga-jaga justru ditolak clippy sebagai useless_conversion.
            let screen: windows::Win32::Graphics::Gdi::HDC = CreateDCW(
                PCWSTR(driver.as_ptr()),
                PCWSTR(dev.as_ptr()),
                PCWSTR::null(),
                None,
            );
            if screen.is_invalid() {
                return Err(format!("CreateDCW gagal untuk {nama_perangkat}"));
            }
            // Parameter HDC sumber bertipe Option<HDC> di 0.61 (boleh null untuk
            // DC layar saat itu); kita selalu punya DC layar sendiri.
            let mem: windows::Win32::Graphics::Gdi::HDC = CreateCompatibleDC(Some(screen));
            if mem.is_invalid() {
                // DC layar sudah terbuka — Handle yang melepasnya di Drop.
                let lepas = Self {
                    screen,
                    mem,
                    bmp: windows::Win32::Graphics::Gdi::HBITMAP::default(),
                    bmi: BITMAPINFO::default(),
                    bgra: Vec::new(),
                    height: 0,
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
                };
                drop(lepas);
                return Err(format!("CreateCompatibleBitmap {width}x{height} gagal"));
            }
            // Bitmap harus ter-select ke memory DC; kalau tidak, BitBlt
            // menggambar ke permukaan 1x1 bawaan dan frame selalu kosong.
            let _sebelumnya = SelectObject(mem, windows::Win32::Graphics::Gdi::HGDIOBJ(bmp.0));

            let mut bmi: BITMAPINFO = std::mem::zeroed();
            bmi.bmiHeader.biSize = std::mem::size_of::<BITMAPINFOHEADER>() as u32;
            bmi.bmiHeader.biWidth = width as i32;
            // Tinggi NEGATIF = baris atas lebih dulu. Default GetDIBits
            // bottom-up, yang akan mengirim frame terbalik ke client.
            bmi.bmiHeader.biHeight = -(height as i32);
            bmi.bmiHeader.biPlanes = 1;
            bmi.bmiHeader.biBitCount = 32;
            // 0 = BI_RGB (tanpa kompresi). Ditulis literal agar tidak bergantung
            // pada nama konstanta yang pernah pindah antar versi crate.
            bmi.bmiHeader.biCompression = 0;

            Ok(Self {
                screen,
                mem,
                bmp,
                bmi,
                bgra: vec![0u8; width * height * 4],
                height: height as u32,
            })
        }
    }

    /// Satu putaran BitBlt + GetDIBits; kembalikan buffer BGRA rapat.
    fn ambil(&mut self) -> Result<&[u8], String> {
        use windows::Win32::Graphics::Gdi::{BitBlt, GetDIBits, DIB_RGB_COLORS, SRCCOPY};

        unsafe {
            // BitBlt mengembalikan Result<()> di 0.61, bukan BOOL — pesan
            // errornya ikut terbawa, jadi gagal di sini bisa dijelaskan.
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
                    "BitBlt gagal (layar terkunci, secure desktop, atau DC lepas): {e}"
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
                return Err("GetDIBits gagal (format bitmap tidak didukung)".to_string());
            }
            if baris as u32 != self.height {
                // Sebagian baris tidak terisi. Mengirimnya akan menghasilkan
                // gambar terpotong tanpa penjelasan; lebih baik gagal terang-
                // terangan supaya watchdog memindahkan backend.
                return Err(format!(
                    "GetDIBits hanya mengisi {baris} dari {} baris",
                    self.height
                ));
            }
        }
        Ok(&self.bgra)
    }
}

/// Pelepas handle GDI.
///
/// Host bisa hidup berhari-hari di server sewaan dan kuota GDI object per
/// proses terbatas (10.000). Capture di-respawn setiap kali monitor, bitrate,
/// atau keyframe berubah — bocor satu bitmap per respawn menghabiskan kuota
/// itu dalam beberapa jam dan membuat seluruh GUI Windows gagal menggambar.
#[cfg(target_os = "windows")]
impl Drop for Handle {
    fn drop(&mut self) {
        use windows::Win32::Graphics::Gdi::{DeleteDC, DeleteObject};
        unsafe {
            if !self.bmp.is_invalid() {
                let _ = DeleteObject(windows::Win32::Graphics::Gdi::HGDIOBJ(self.bmp.0));
            }
            // Crate `windows` 0.61: DeleteDC menerima HDC langsung (tipe
            // CreatedHDC yang dulu membungkus DC hasil CreateDCW sudah tidak
            // diekspor dari Win32::Graphics::Gdi).
            if !self.mem.is_invalid() {
                let _ = DeleteDC(self.mem);
            }
            if !self.screen.is_invalid() {
                let _ = DeleteDC(self.screen);
            }
        }
    }
}

#[cfg(target_os = "windows")]
use windows::Win32::Graphics::Gdi::SelectObject;

#[cfg(test)]
mod tests {
    //! Penjaga arsitektur modul ini BUKAN test yang mencari kata di sumbernya,
    //! melainkan daftar dependensi `tool/wincheck`: crate itu mengompilasi
    //! `gdi.rs` hanya dengan `windows` + `pixfmt`. Bila encode, webrtc, atau
    //! openh264 menyusup ke sini, wincheck gagal kompilasi — penjaga yang tidak
    //! bisa dikelabui.
    //!
    //! Pelajaran yang dibayar di commit ini: test versi pertama memakai
    //! `include_str!("gdi.rs")` untuk memastikan kata `EncoderKind` dan
    //! `try_send` TIDAK ada, padahal `include_str!` ikut membaca test itu
    //! sendiri — assertion-nya memuat kata terlarangnya, jadi test selalu gagal
    //! justru karena ia benar. Test yang memeriksa dirinya sendiri bukan test.

    #[test]
    fn konversi_warna_dilakukan_di_primitif_bukan_di_pemanggil() {
        // `grab` harus menyerahkan RGBA, bukan BGRA mentah dari GetDIBits: bila
        // penukaran warna pindah ke pemanggil, backend berikutnya (DXGI, yang
        // juga memberi BGRA) harus mengulanginya dan berisiko lupa — gejalanya
        // layar kebiruan di client, bukan error.
        let src = include_str!("gdi.rs");
        assert!(
            src.contains("crate::pixfmt::bgra_to_rgba"),
            "penukaran BGRA→RGBA harus terjadi di dalam grab()"
        );
    }
}

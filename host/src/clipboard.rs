//! Papan klip sistem host — jembatan sinkronisasi papan klip XyDesk.
//!
//! Kenapa FFI mentah, bukan crate `windows`
//! ----------------------------------------
//! Proyek ini memakai crate `windows` untuk audio, tetapi tipe kembalian
//! fungsi-fungsinya berubah antar-versi (`BOOL` vs `Result<()>`) mengikuti
//! metadata. Untuk clipboard, yang dipakai cuma tujuh fungsi ABI Win32 yang
//! sudah stabil sejak 1995 dengan tipe primitif. Menuliskannya sendiri
//! membuat modul ini kebal terhadap naik-turun versi crate, dan tidak
//! menambah dependensi baru.
//!
//! Kenapa tidak ada pengamat perubahan
//! -----------------------------------
//! Menjanjikan "salin di PC, langsung muncul di HP" butuh
//! `AddClipboardFormatListener`, yang hanya berjalan bila ada loop pesan
//! jendela. Host XyDesk tidak memilikinya. Karena itu arah PC → HP memakai
//! model tarik: klien meminta (`CLIPBOARD_REQ`), host membalas dengan isi
//! papan klipnya (`CLIPBOARD_SET`). Janji palsu lebih mahal daripada satu
//! ketukan tambahan.
//!
//! Di sistem selain Windows kedua fungsi mengembalikan `Err` — sengaja.
//! Lebih jujur daripada pura-pura berhasil lalu papan klip tidak berubah.

#[cfg(target_os = "windows")]
mod raw {
    #[link(name = "user32")]
    extern "system" {
        pub fn OpenClipboard(hwnd: *mut core::ffi::c_void) -> i32;
        pub fn CloseClipboard() -> i32;
        pub fn EmptyClipboard() -> i32;
        pub fn SetClipboardData(format: u32, mem: *mut core::ffi::c_void)
            -> *mut core::ffi::c_void;
        pub fn GetClipboardData(format: u32) -> *mut core::ffi::c_void;
    }

    #[link(name = "kernel32")]
    extern "system" {
        pub fn GlobalAlloc(flags: u32, bytes: usize) -> *mut core::ffi::c_void;
        pub fn GlobalLock(mem: *mut core::ffi::c_void) -> *mut core::ffi::c_void;
        pub fn GlobalUnlock(mem: *mut core::ffi::c_void) -> i32;
        pub fn GlobalSize(mem: *mut core::ffi::c_void) -> usize;
        pub fn GlobalFree(mem: *mut core::ffi::c_void) -> *mut core::ffi::c_void;
    }
}

/// `CF_UNICODETEXT` — format teks clipboard Windows (UTF-16LE).
#[cfg(target_os = "windows")]
const CF_UNICODETEXT: u32 = 13;

/// `GMEM_MOVEABLE` — memori global yang boleh digeser; wajib untuk clipboard.
#[cfg(target_os = "windows")]
const GMEM_MOVEABLE: u32 = 0x0002;

/// Batas aman pembacaan: 64 KiB karakter. Papan klip bisa berisi apa saja,
/// termasuk gambar puluhan megabita yang tersimpan sebagai format lain —
/// batas ini mencegah kita menyalin itu semua ke dalam kawat.
#[cfg(target_os = "windows")]
const MAX_CHARS: usize = 64 * 1024;

/// Penjaga yang menutup clipboard walau fungsi berakhir karena error.
///
/// Clipboard Windows itu kunci global: kalau kita buka lalu lupa menutup,
/// seluruh aplikasi lain di komputer itu tidak bisa menyalin apa pun sampai
/// prosesnya mati. Kegagalan seperti ini tidak berisik — ia cuma membuat
/// komputer orang terasa rusak.
#[cfg(target_os = "windows")]
struct ClipboardGuard;

#[cfg(target_os = "windows")]
impl Drop for ClipboardGuard {
    fn drop(&mut self) {
        unsafe {
            raw::CloseClipboard();
        }
    }
}

/// Tulis teks ke papan klip PC.
#[cfg(target_os = "windows")]
pub fn set_text(text: &str) -> anyhow::Result<()> {
    // UTF-16LE + penutup NUL, format yang diwajibkan CF_UNICODETEXT.
    let wide: Vec<u16> = text.encode_utf16().chain(std::iter::once(0)).collect();
    let byte_len = wide.len() * std::mem::size_of::<u16>();

    unsafe {
        if raw::OpenClipboard(std::ptr::null_mut()) == 0 {
            anyhow::bail!("papan klip sedang dipakai aplikasi lain");
        }
        let _guard = ClipboardGuard;

        if raw::EmptyClipboard() == 0 {
            anyhow::bail!("gagal mengosongkan papan klip");
        }
        let mem = raw::GlobalAlloc(GMEM_MOVEABLE, byte_len);
        if mem.is_null() {
            anyhow::bail!("kehabisan memori untuk papan klip");
        }
        // Sampai `SetClipboardData` sukses, memori ini masih milik kita.
        // Setiap jalan keluar sebelum itu harus membebaskannya sendiri —
        // kalau tidak, ia bocor di heap global dan tidak bisa dipulihkan
        // proses mana pun selain ini, yang seharusnya hidup berhari-hari.
        let ptr = raw::GlobalLock(mem) as *mut u16;
        if ptr.is_null() {
            raw::GlobalFree(mem);
            anyhow::bail!("gagal mengunci memori papan klip");
        }
        std::ptr::copy_nonoverlapping(wide.as_ptr(), ptr, wide.len());
        raw::GlobalUnlock(mem);

        // Sukses = kepemilikan memori pindah ke sistem; jangan dibebaskan.
        if raw::SetClipboardData(CF_UNICODETEXT, mem).is_null() {
            raw::GlobalFree(mem);
            anyhow::bail!("gagal menulis papan klip");
        }
    }
    Ok(())
}

/// Baca teks dari papan klip PC. Papan klip kosong (atau bukan teks)
/// dikembalikan sebagai string kosong, bukan error.
#[cfg(target_os = "windows")]
pub fn get_text() -> anyhow::Result<String> {
    unsafe {
        if raw::OpenClipboard(std::ptr::null_mut()) == 0 {
            anyhow::bail!("papan klip sedang dipakai aplikasi lain");
        }
        let _guard = ClipboardGuard;

        let mem = raw::GetClipboardData(CF_UNICODETEXT);
        if mem.is_null() {
            // Bukan teks (gambar, berkas) atau kosong. Bukan kegagalan.
            return Ok(String::new());
        }
        let ptr = raw::GlobalLock(mem) as *const u16;
        if ptr.is_null() {
            anyhow::bail!("gagal mengunci memori papan klip");
        }
        let units = (raw::GlobalSize(mem) / std::mem::size_of::<u16>()).min(MAX_CHARS);
        // Panjang memori global hanya batas atas yang bisa dipercaya sedikit;
        // teksnya sendiri berakhir di NUL pertama.
        let mut len = 0usize;
        while len < units && *ptr.add(len) != 0 {
            len += 1;
        }
        let slice = std::slice::from_raw_parts(ptr, len);
        let out = String::from_utf16_lossy(slice);
        raw::GlobalUnlock(mem);
        Ok(out)
    }
}

#[cfg(not(target_os = "windows"))]
pub fn set_text(_text: &str) -> anyhow::Result<()> {
    anyhow::bail!("sinkronisasi papan klip baru tersedia untuk host Windows")
}

#[cfg(not(target_os = "windows"))]
pub fn get_text() -> anyhow::Result<String> {
    anyhow::bail!("sinkronisasi papan klip baru tersedia untuk host Windows")
}

#[cfg(test)]
mod tests {
    /// Di luar Windows, modul ini harus mengaku tidak mendukung — bukan
    /// mengembalikan `Ok(())` dan membuat klien mengira teksnya tersalin.
    #[cfg(not(target_os = "windows"))]
    #[test]
    fn di_luar_windows_mengaku_tidak_didukung() {
        assert!(super::set_text("apa pun").is_err());
        assert!(super::get_text().is_err());
    }
}

//! Preview hanya dari wallpaper Windows yang dikonfigurasi, bukan frame aplikasi.
use std::io::Cursor;
#[cfg(target_os = "windows")]
use std::io::Read;
pub const MAX_JPEG: usize = 256 * 1024;

pub fn preview_from_bytes(bytes: &[u8]) -> Result<Vec<u8>, String> {
    if bytes.len() > 16 * 1024 * 1024 {
        return Err("wallpaper terlalu besar".into());
    }
    let mut reader = image::ImageReader::new(Cursor::new(bytes))
        .with_guessed_format()
        .map_err(|e| e.to_string())?;
    let mut limits = image::Limits::default();
    limits.max_image_width = Some(16384);
    limits.max_image_height = Some(16384);
    limits.max_alloc = Some(64 * 1024 * 1024);
    reader.limits(limits);
    let source = reader
        .decode()
        .map_err(|_| "format wallpaper tidak didukung")?;
    let image = if source.width() > 1920 || source.height() > 1080 {
        source.resize(1920, 1080, image::imageops::FilterType::Lanczos3)
    } else {
        source
    };
    let rgb = image.to_rgb8();
    for quality in [90, 85, 80, 75] {
        let mut out = Vec::new();
        image::codecs::jpeg::JpegEncoder::new_with_quality(&mut out, quality)
            .encode_image(&rgb)
            .map_err(|e| e.to_string())?;
        if out.len() <= MAX_JPEG {
            return Ok(out);
        }
    }
    Err("wallpaper terlalu rinci untuk batas preview HD; gambar lama dipertahankan".into())
}

#[cfg(target_os = "windows")]
pub fn configured_preview() -> Result<Vec<u8>, String> {
    use windows::core::PCWSTR;
    use windows::Win32::Storage::FileSystem::GetDriveTypeW;
    use windows::Win32::UI::WindowsAndMessaging::{
        SystemParametersInfoW, SPI_GETDESKWALLPAPER, SYSTEM_PARAMETERS_INFO_UPDATE_FLAGS,
    };
    let mut path = vec![0u16; 32768];
    unsafe {
        SystemParametersInfoW(
            SPI_GETDESKWALLPAPER,
            path.len() as u32,
            Some(path.as_mut_ptr().cast()),
            SYSTEM_PARAMETERS_INFO_UPDATE_FLAGS(0),
        )
    }
    .map_err(|_| "wallpaper Windows tidak tersedia")?;
    let end = path.iter().position(|&v| v == 0).unwrap_or(path.len());
    let raw = String::from_utf16_lossy(&path[..end]);
    // Tolak UNC/device/relative sebelum canonicalize agar tidak mengakses jaringan.
    if !local_drive_path(&raw) {
        return Err("wallpaper bukan berkas lokal".into());
    }
    let root: Vec<u16> = raw[..3].encode_utf16().chain(Some(0)).collect();
    if unsafe { GetDriveTypeW(PCWSTR(root.as_ptr())) } != 3 {
        return Err("wallpaper harus di drive lokal tetap".into());
    }
    use std::os::windows::fs::MetadataExt;
    let mut component_path = std::path::PathBuf::new();
    for component in std::path::Path::new(&raw).components() {
        component_path.push(component);
        if component_path.is_absolute() {
            let metadata = std::fs::symlink_metadata(&component_path)
                .map_err(|_| "jalur wallpaper tidak tersedia")?;
            if metadata.file_attributes() & 0x400 != 0 {
                return Err("junction/symlink wallpaper ditolak".into());
            }
        }
    }
    let canonical = std::fs::canonicalize(&raw).map_err(|_| "wallpaper tidak dapat dibuka")?;
    let canonical_text = canonical.to_string_lossy();
    let normalized = canonical_text
        .strip_prefix("\\\\?\\")
        .unwrap_or(&canonical_text);
    if !local_drive_path(normalized) {
        return Err("tautan wallpaper ke jaringan ditolak".into());
    }
    let root: Vec<u16> = normalized[..3].encode_utf16().chain(Some(0)).collect();
    if unsafe { GetDriveTypeW(PCWSTR(root.as_ptr())) } != 3 {
        return Err("drive wallpaper tidak diizinkan".into());
    }
    let file = std::fs::File::open(canonical).map_err(|_| "wallpaper tidak dapat dibuka")?;
    if !file
        .metadata()
        .map_err(|_| "metadata wallpaper gagal")?
        .is_file()
    {
        return Err("wallpaper bukan berkas".into());
    }
    let mut bytes = Vec::new();
    file.take(16 * 1024 * 1024 + 1)
        .read_to_end(&mut bytes)
        .map_err(|_| "gagal membaca wallpaper")?;
    preview_from_bytes(&bytes)
}
#[cfg(not(target_os = "windows"))]
pub fn configured_preview() -> Result<Vec<u8>, String> {
    Err("preview wallpaper hanya tersedia di Windows".into())
}
#[cfg(any(target_os = "windows", test))]
fn local_drive_path(path: &str) -> bool {
    let b = path.as_bytes();
    b.len() >= 3
        && b[0].is_ascii_alphabetic()
        && b[1] == b':'
        && b[2] == b'\\'
        && !b[2..].contains(&b':')
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn paths_reject_network_device_relative_ads() {
        for p in [
            "\\\\server\\file.jpg",
            "\\\\?\\C:\\x",
            "C:relative",
            "https://x",
            "C:\\x:secret",
        ] {
            assert!(!local_drive_path(p));
        }
        assert!(local_drive_path("C:\\Users\\test\\wallpaper.jpg"));
    }
    #[test]
    fn hd_without_upscale_and_invalid_bounded() {
        let image = image::RgbImage::from_pixel(2560, 1440, image::Rgb([24, 80, 120]));
        let mut png = Cursor::new(Vec::new());
        image.write_to(&mut png, image::ImageFormat::Png).unwrap();
        let jpeg = preview_from_bytes(png.get_ref()).unwrap();
        let decoded = image::load_from_memory(&jpeg).unwrap();
        assert_eq!((decoded.width(), decoded.height()), (1920, 1080));
        assert!(jpeg.len() <= MAX_JPEG);
        assert!(preview_from_bytes(b"not a picture").is_err());
        assert!(preview_from_bytes(&vec![0; 16 * 1024 * 1024 + 1]).is_err());
    }
}

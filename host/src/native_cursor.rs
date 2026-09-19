//! Draw the current Windows cursor into a small desktop tile, not a client arrow.
// A suppressed touch/pen pointer is different from an application's hidden cursor.
// Only suppression permits the Windows standard arrow when no current shape exists.
pub fn cursor_policy(flags: u32, has_shape: bool) -> (bool, bool) {
    let showing = flags & 1 != 0;
    let suppressed = flags & 2 != 0;
    (showing || suppressed, suppressed && !has_shape)
}

#[cfg(target_os = "windows")]
pub fn draw_bgra(
    pixels: &mut [u8],
    width: usize,
    height: usize,
    rect: crate::desktop_geometry::CaptureRect,
) -> Result<(), String> {
    use windows::Win32::{Graphics::Gdi::*, UI::WindowsAndMessaging::*};
    if width.checked_mul(height).and_then(|n| n.checked_mul(4)) != Some(pixels.len()) {
        return Err("cursor: ukuran buffer tidak cocok".into());
    }
    unsafe {
        let mut cursor = CURSORINFO {
            cbSize: std::mem::size_of::<CURSORINFO>() as u32,
            ..Default::default()
        };
        GetCursorInfo(&mut cursor).map_err(|e| e.to_string())?;
        let (draw, default_shape) = cursor_policy(cursor.flags.0, !cursor.hCursor.is_invalid());
        if !draw {
            return Ok(());
        }
        let handle = if default_shape {
            LoadCursorW(None, IDC_ARROW).map_err(|e| e.to_string())?
        } else {
            cursor.hCursor
        };
        if handle.is_invalid() {
            return Err("cursor: Windows tidak menyediakan bentuk".into());
        }
        struct Icon {
            handle: HICON,
            info: ICONINFO,
        }
        impl Drop for Icon {
            fn drop(&mut self) {
                unsafe {
                    let _ = DeleteObject(self.info.hbmMask.into());
                    let _ = DeleteObject(self.info.hbmColor.into());
                    let _ = DestroyIcon(self.handle);
                }
            }
        }
        let mut icon = Icon {
            handle: CopyIcon(HICON(handle.0)).map_err(|e| e.to_string())?,
            info: ICONINFO::default(),
        };
        GetIconInfo(icon.handle, &mut icon.info).map_err(|e| e.to_string())?;
        let monochrome = icon.info.hbmColor.is_invalid();
        let bitmap = if monochrome {
            icon.info.hbmMask
        } else {
            icon.info.hbmColor
        };
        let mut bm = BITMAP::default();
        if GetObjectW(
            bitmap.into(),
            std::mem::size_of::<BITMAP>() as i32,
            Some((&mut bm as *mut BITMAP).cast()),
        ) == 0
        {
            return Err("cursor: bitmap tidak tersedia".into());
        }
        let (cw, ch) = (bm.bmWidth, bm.bmHeight / if monochrome { 2 } else { 1 });
        if cw <= 0 || ch <= 0 || cw > 512 || ch > 512 {
            return Err("cursor: ukuran bitmap di luar batas".into());
        }
        let x =
            i64::from(cursor.ptScreenPos.x) - i64::from(rect.left) - i64::from(icon.info.xHotspot);
        let y =
            i64::from(cursor.ptScreenPos.y) - i64::from(rect.top) - i64::from(icon.info.yHotspot);
        if x >= width as i64
            || y >= height as i64
            || x + i64::from(cw) <= 0
            || y + i64::from(ch) <= 0
        {
            return Ok(());
        }
        struct Tile {
            dc: HDC,
            bmp: HBITMAP,
            old: HGDIOBJ,
        }
        impl Drop for Tile {
            fn drop(&mut self) {
                unsafe {
                    if !self.old.is_invalid() {
                        let _ = SelectObject(self.dc, self.old);
                    }
                    let _ = DeleteObject(self.bmp.into());
                    let _ = DeleteDC(self.dc);
                }
            }
        }
        let mut tile = Tile {
            dc: CreateCompatibleDC(None),
            bmp: HBITMAP::default(),
            old: HGDIOBJ::default(),
        };
        if tile.dc.is_invalid() {
            return Err("cursor: CreateCompatibleDC gagal".into());
        }
        let mut info = BITMAPINFO::default();
        info.bmiHeader.biSize = std::mem::size_of::<BITMAPINFOHEADER>() as u32;
        info.bmiHeader.biWidth = cw;
        info.bmiHeader.biHeight = -ch;
        info.bmiHeader.biPlanes = 1;
        info.bmiHeader.biBitCount = 32;
        let mut bits = std::ptr::null_mut();
        tile.bmp = CreateDIBSection(Some(tile.dc), &info, DIB_RGB_COLORS, &mut bits, None, 0)
            .map_err(|e| e.to_string())?;
        tile.old = SelectObject(tile.dc, tile.bmp.into());
        if bits.is_null() || tile.old.is_invalid() {
            return Err("cursor: bitmap tidak terpilih".into());
        }
        let data = std::slice::from_raw_parts_mut(bits as *mut u8, cw as usize * ch as usize * 4);
        data.fill(0);
        for cy in 0..ch as usize {
            for cx in 0..cw as usize {
                let (px, py) = (x + cx as i64, y + cy as i64);
                if px >= 0 && py >= 0 && px < width as i64 && py < height as i64 {
                    let src = (py as usize * width + px as usize) * 4;
                    let dst = (cy * cw as usize + cx) * 4;
                    data[dst..dst + 4].copy_from_slice(&pixels[src..src + 4]);
                }
            }
        }
        DrawIconEx(tile.dc, 0, 0, icon.handle, cw, ch, 0, None, DI_NORMAL)
            .map_err(|e| e.to_string())?;
        if !GdiFlush().as_bool() {
            return Err("cursor: GDI flush gagal".into());
        }
        for cy in 0..ch as usize {
            for cx in 0..cw as usize {
                let (px, py) = (x + cx as i64, y + cy as i64);
                if px >= 0 && py >= 0 && px < width as i64 && py < height as i64 {
                    let dst = (py as usize * width + px as usize) * 4;
                    let src = (cy * cw as usize + cx) * 4;
                    pixels[dst..dst + 4].copy_from_slice(&data[src..src + 4]);
                }
            }
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn suppression_uses_native_default_only_when_shape_missing() {
        assert_eq!(cursor_policy(2, false), (true, true));
        assert_eq!(cursor_policy(2, true), (true, false));
        assert_eq!(cursor_policy(1, true), (true, false));
        assert_eq!(cursor_policy(3, true), (true, false));
    }
    #[test]
    fn deliberate_application_hide_is_preserved() {
        assert_eq!(cursor_policy(0, true), (false, false));
        assert_eq!(cursor_policy(0, false), (false, false));
    }
}

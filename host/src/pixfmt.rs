//! Konversi format piksel untuk jalur encode video.
//!
//! Host memakai dua jalur encode: NVENC (hardware) menerima **NV12**;
//! openh264 (software) menerima RGB lewat `RgbaSliceU8` dan konversinya
//! ditangani pustaka. Fungsi di sini khusus jalur NVENC: mengubah frame
//! RGBA8 (baris rapat, hasil capture `windows-capture`) menjadi NV12
//! (BT.601 full-range, subsampling 2x2) — format yang diminta
//! `nvEncodeAPI64.dll`.
//!
//! Modul ini sengaja lintas platform: konversinya murni aritmetika integer
//! tanpa satu pun dependensi Windows, jadi bisa diuji di Linux (CI
//! `host-test`) padahal pemanggilnya (`screen.rs`) hanya hidup di Windows.
//! Sebelum dipisah, fungsi ini tersembunyi di dalam modul `windows`
//! `screen.rs` tanpa satu pun pengujian — persis jenis kode yang paling
//! gampang rusak diam-diam.

/// RGBA8 (baris rapat, 4 byte/piksel) → NV12 (BT.601 full-range, 2x2).
///
/// Keluaran diletakkan di `out` (dipakai ulang antar frame; ukuran akhir
/// `w*h*3/2`). Layout NV12: plane Y (`w*h`) lalu plane UV berselang-seling
/// (U,V,U,V…, `w` byte per baris, `h/2` baris).
///
/// Koefisien BT.601 full-range (layar = RGB 0..255 dipetakan langsung,
/// bukan studio swing) — konsisten dengan `videoFullRangeFlag = 1` yang
/// disetel `nvenc.rs`, supaya decoder tidak memudarkan kontras.
///
/// # Kontrak
/// `width` dan `height` **wajib genap**. Pemanggil (`screen.rs`) menjaminnya:
/// NVENC baru dipilih bila resolusi genap. Dimensi ganjil ditolak
/// `debug_assert!` di build debug; di build release, memanggil dengan
/// dimensi ganjil menulis melewati batas plane — jangan lakukan.
pub fn rgba_to_nv12(rgba: &[u8], width: usize, height: usize, out: &mut Vec<u8>) {
    debug_assert!(
        width.is_multiple_of(2) && height.is_multiple_of(2),
        "rgba_to_nv12 butuh dimensi genap, dapat {width}x{height}"
    );
    let size = width * height * 3 / 2;
    out.resize(size, 0);
    let (y_out, uv_part) = out.split_at_mut(width * height);
    let y_dst = &mut y_out[..];
    let uv_dst = &mut uv_part[..];
    // Iterasi blok 2x2 sekaligus untuk U/V (subsampling horizontal+vertikal).
    for y in (0..height).step_by(2) {
        let row_y0 = y * width * 4;
        let row_y1 = (y + 1) * width * 4;
        let y_row = y * width;
        let uv_row = (y / 2) * width;
        for x in (0..width).step_by(2) {
            let i00 = row_y0 + x * 4;
            let i01 = row_y0 + (x + 1) * 4;
            let i10 = row_y1 + x * 4;
            let i11 = row_y1 + (x + 1) * 4;
            let (r0, g0, b0) = (rgba[i00] as u32, rgba[i00 + 1] as u32, rgba[i00 + 2] as u32);
            let (r1, g1, b1) = (rgba[i01] as u32, rgba[i01 + 1] as u32, rgba[i01 + 2] as u32);
            let (r2, g2, b2) = (rgba[i10] as u32, rgba[i10 + 1] as u32, rgba[i10 + 2] as u32);
            let (r3, g3, b3) = (rgba[i11] as u32, rgba[i11 + 1] as u32, rgba[i11 + 2] as u32);
            let (rr, gg, bb) = (
                (r0 + r1 + r2 + r3) / 4,
                (g0 + g1 + g2 + g3) / 4,
                (b0 + b1 + b2 + b3) / 4,
            );
            // Y untuk keempat piksel; U/V dari rata-rata 2x2.
            y_dst[y_row + x] = ((77 * r0 + 150 * g0 + 29 * b0 + 128) >> 8) as u8;
            y_dst[y_row + x + 1] = ((77 * r1 + 150 * g1 + 29 * b1 + 128) >> 8) as u8;
            y_dst[y_row + width + x] = ((77 * r2 + 150 * g2 + 29 * b2 + 128) >> 8) as u8;
            y_dst[y_row + width + x + 1] = ((77 * r3 + 150 * g3 + 29 * b3 + 128) >> 8) as u8;
            let c_u = ((128i32 * bb as i32 - 43 * rr as i32 - 85 * gg as i32 + 128) >> 8) + 128;
            let c_v = ((128i32 * rr as i32 - 107 * gg as i32 - 21 * bb as i32 + 128) >> 8) + 128;
            let uv = uv_row + x;
            uv_dst[uv] = c_u.clamp(0, 255) as u8;
            uv_dst[uv + 1] = c_v.clamp(0, 255) as u8;
        }
    }
}

/// BGRA (baris rapat) → RGBA, ditulis ke `out` yang dipakai ulang.
///
/// `GetDIBits` GDI dengan `biBitCount = 32` dan `BI_RGB` menghasilkan byte
/// B,G,R,A — kebalikan dari yang diharapkan encoder dan dari yang diberikan
/// Windows Graphics Capture API (RGBA). Menukar B↔R di sini, sekali per frame,
/// jauh lebih murah daripada memperbaiki warna di sisi client, dan membuat
/// kedua backend menyerahkan buffer yang identik ke `EncoderKind::encode`.
///
/// Byte sisa yang tidak membentuk piksel utuh dibuang, bukan diisi nol: frame
/// sedikit terpotong lebih baik daripada warna bergeser satu piksel.
pub fn bgra_to_rgba(bgra: &[u8], out: &mut Vec<u8>) {
    let n = bgra.len() / 4 * 4;
    // Ukuran hanya disesuaikan saat berubah: frame berikutnya memakai buffer
    // yang sama, jadi tidak ada memset 8 MB per frame.
    if out.len() != n {
        out.clear();
        out.resize(n, 0);
    }
    // Indeks eksplisit, bukan chunks_exact_mut(4): clippy menuntut `as_chunks`
    // untuk ukuran konstan, dan API itu masih terlalu baru untuk dipatok.
    for i in (0..n).step_by(4) {
        out[i] = bgra[i + 2];
        out[i + 1] = bgra[i + 1];
        out[i + 2] = bgra[i];
        out[i + 3] = bgra[i + 3];
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Frame RGBA8 solid `w`x`h` berisi satu warna (alpha 255).
    fn frame_solid(w: usize, h: usize, rgb: [u8; 3]) -> Vec<u8> {
        let mut v = Vec::with_capacity(w * h * 4);
        for _ in 0..w * h {
            v.extend_from_slice(&[rgb[0], rgb[1], rgb[2], 255]);
        }
        v
    }

    #[test]
    fn ukuran_keluaran_nv12() {
        for (w, h) in [(2, 2), (16, 10), (320, 180), (1920, 1080)] {
            let src = frame_solid(w, h, [10, 20, 30]);
            let mut out = Vec::new();
            rgba_to_nv12(&src, w, h, &mut out);
            assert_eq!(out.len(), w * h * 3 / 2, "ukuran {w}x{h}");
        }
    }

    #[test]
    fn warna_netral_titik_jangkar_full_range() {
        // Hitam, abu, putih: Y mengikuti nilai RGB (full-range), kroma netral.
        for (rgb, y_harap) in [
            ([0u8, 0, 0], 0u8),
            ([128, 128, 128], 128),
            ([255, 255, 255], 255),
        ] {
            let (w, h) = (4, 4);
            let src = frame_solid(w, h, rgb);
            let mut out = Vec::new();
            rgba_to_nv12(&src, w, h, &mut out);
            let (y, uv) = out.split_at(w * h);
            assert!(y.iter().all(|&v| v == y_harap), "Y {rgb:?} harus {y_harap}");
            assert!(uv.iter().all(|&c| c == 128), "U/V {rgb:?} harus netral 128");
        }
    }

    #[test]
    fn warna_primer_bt601_full_range() {
        // Nilai referensi BT.601 full-range (dihitung terpisah, bukan dari
        // implementasi) — mengunci koefisien Y/U/V. Merah: Y=77 U=85 V=255;
        // hijau: Y=149 U=43 V=21; biru: Y=29 U=255 V=107.
        let cases: [([u8; 3], u8, [u8; 2]); 3] = [
            ([255, 0, 0], 77, [85, 255]),
            ([0, 255, 0], 149, [43, 21]),
            ([0, 0, 255], 29, [255, 107]),
        ];
        for (rgb, y_harap, uv_harap) in cases {
            let (w, h) = (2, 2);
            let src = frame_solid(w, h, rgb);
            let mut out = Vec::new();
            rgba_to_nv12(&src, w, h, &mut out);
            let (y, uv) = out.split_at(w * h);
            assert_eq!(y, &[y_harap; 4], "Y {rgb:?}");
            assert_eq!(uv, &uv_harap, "U/V {rgb:?}");
        }
    }

    #[test]
    fn blok_2x2_rata_rata_kroma_dan_y_empat_piksel() {
        // Empat piksel berbeda dalam satu blok: setiap piksel menghasilkan Y
        // sendiri; U/V dari rata-rata keempatnya ((255+0+0+255)/4=127 per
        // kanal → U=128, V=128). Menjaga indeks i00/i01/i10/i11 tidak
        // tertukar antar baris/kolom.
        let (w, h) = (2, 2);
        let src: Vec<u8> = vec![
            255, 0, 0, 255, // merah   → Y 77
            0, 255, 0, 255, // hijau   → Y 149
            0, 0, 255, 255, // biru    → Y 29
            255, 255, 255, 255, // putih → Y 255
        ];
        let mut out = Vec::new();
        rgba_to_nv12(&src, w, h, &mut out);
        let (y, uv) = out.split_at(w * h);
        assert_eq!(y, &[77, 149, 29, 255], "Y per piksel");
        assert_eq!(uv, &[128, 128], "U/V rata-rata 2x2");
    }

    #[test]
    fn kroma_konstan_untuk_warna_seragam() {
        // Warna seragam 8x6: U dan V harus konstan di seluruh plane (menangkap
        // bug stride/baris yang membuat kroma bergeser antar baris). U dan V
        // sendiri boleh beda nilainya — kroma netral hanya untuk abu.
        let (w, h) = (8, 6);
        let src = frame_solid(w, h, [200, 60, 120]);
        let mut out = Vec::new();
        rgba_to_nv12(&src, w, h, &mut out);
        let uv = &out[w * h..];
        assert!(!uv.is_empty());
        let pasangan = [uv[0], uv[1]];
        assert!(
            uv.as_chunks::<2>().0.iter().all(|c| *c == pasangan),
            "plane UV harus konstan per blok"
        );
    }

    #[test]
    fn buffer_keluaran_dipakai_ulang_tanpa_sisa() {
        // `out` dipakai ulang antar frame: ukurannya menyesuaikan, tidak
        // menyisakan byte frame lama yang lebih besar.
        let mut out = vec![9u8; 64];
        rgba_to_nv12(&frame_solid(2, 2, [0, 0, 0]), 2, 2, &mut out);
        assert_eq!(out.len(), 6, "mengecil ke 2x2x3/2");
        rgba_to_nv12(&frame_solid(4, 4, [0, 0, 0]), 4, 4, &mut out);
        assert_eq!(out.len(), 24, "membesar ke 4x4x3/2");
    }

    #[test]
    fn bgra_ke_rgba_menukar_merah_dan_biru() {
        let mut out = Vec::new();
        bgra_to_rgba(&[0x10, 0x20, 0x30, 0xFF], &mut out);
        assert_eq!(out, vec![0x30, 0x20, 0x10, 0xFF]);
    }

    #[test]
    fn bgra_ke_rgba_buffer_dipakai_ulang_tanpa_sisa() {
        // Buffer dipakai ulang antar frame: harus menyusut ke panjang masukan,
        // bukan menyisakan byte frame lama yang lebih besar.
        let mut out = vec![9u8; 64];
        bgra_to_rgba(&[1, 2, 3, 4, 5, 6, 7, 8], &mut out);
        assert_eq!(out.len(), 8, "sisa buffer lama tidak dibuang");
        assert_eq!(out, vec![3, 2, 1, 4, 7, 6, 5, 8]);
    }

    #[test]
    fn bgra_ke_rgba_byte_sisa_dibuang_bukan_diisi_nol() {
        let mut out = Vec::new();
        bgra_to_rgba(&[1, 2, 3, 4, 5], &mut out);
        assert_eq!(out, vec![3, 2, 1, 4], "byte ke-5 mengarang piksel");
    }

    #[test]
    #[should_panic(expected = "dimensi genap")]
    fn dimensi_ganjil_ditolak_di_build_debug() {
        // Kontrak terdokumentasi: dimensi ganjil bukan input yang sah.
        let src = frame_solid(3, 2, [0, 0, 0]);
        let mut out = Vec::new();
        rgba_to_nv12(&src, 3, 2, &mut out);
    }
}

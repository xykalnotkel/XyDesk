"""Generator logo XyDesk kanonikal.

Menghasilkan seluruh varian aset visual resmi dari satu fungsi
matematis yang konsisten:
  - `web/public/logo.png` (1024x1024, kanvas lingkaran glossy)
  - `web/public/logo-192.png` / `logo-512.png` (PWA)
  - `web/public/favicon.ico` (multi-resolusi 16, 32, 48)
  - `android/app/src/main/res/mipmap-*/ic_launcher.png` (legacy)
  - `android/app/src/main/res/mipmap-*/ic_launcher_foreground.png` (adaptive)
  - `packaging/windows/xydesk.ico`, `app.ico` (Windows installer & binary)
  - `desktop/assets/icon.ico`, `desktop/electron/tray.ico`
  - `desktop/src-tauri/icons/*` (icon.ico, tray.ico, PNGs)

Aturan desain XyDesk:
  - Logo adalah glyph "X" futuristik berlapis ganda dengan gradien ungu neon.
  - Warna aksen: #7C3AED (primer), #9333EA (aksen), #A855F7 (highlight), #C084FC (glow).
  - Latar kanvas aplikasi / splash: #F5F3FF (Paper Light) atau #0F0A1F (Dark).
  - Tidak boleh ada kotak hitam atau artefak visual tak sengaja.
"""

from __future__ import annotations

import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent

# Dimensi mipmap Android (legacy vs adaptive foreground)
ANDROID_DENSITIES: dict[str, tuple[int, int]] = {
    "mdpi": (48, 108),
    "hdpi": (72, 162),
    "xhdpi": (96, 216),
    "xxhdpi": (144, 324),
    "xxxhdpi": (192, 432),
}


def draw_cyber_x(size: int = 1024) -> Image.Image:
    """Menggambar glyph X kanonikal XyDesk pada kanvas transparan supersampled (4x)."""
    scale = 4
    ss_size = size * scale
    im = Image.new("RGBA", (ss_size, ss_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)

    cx = ss_size / 2.0
    cy = ss_size / 2.0
    span = ss_size * 0.38
    stroke_w = ss_size * 0.105

    # 1. Glow halus di belakang glyph (ambient luminous purple)
    glow_layer = Image.new("RGBA", (ss_size, ss_size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_layer)

    glow_draw.line(
        [(cx - span, cy - span), (cx + span, cy + span)],
        fill=(168, 85, 247, 90),
        width=int(stroke_w * 1.6),
    )
    glow_draw.line(
        [(cx + span, cy - span), (cx - span, cy + span)],
        fill=(124, 58, 237, 90),
        width=int(stroke_w * 1.6),
    )
    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(radius=scale * 18))
    im.alpha_composite(glow_layer)

    # 2. Diagonal Primer (\) — Gradien Ungu Elektrik ke Fuchsia
    d1_steps = 120
    for i in range(d1_steps):
        t0 = i / float(d1_steps)
        t1 = (i + 1) / float(d1_steps)

        x_start = cx - span + t0 * (2 * span)
        y_start = cy - span + t0 * (2 * span)
        x_end = cx - span + t1 * (2 * span)
        y_end = cy - span + t1 * (2 * span)

        # Interpolasi warna neon
        r = int(124 + (192 - 124) * t0)
        g = int(58 + (132 - 58) * (1.0 - math.fabs(t0 - 0.5) * 2))
        b = int(237 + (252 - 237) * t0)

        draw.line(
            [(x_start, y_start), (x_end, y_end)],
            fill=(r, g, b, 255),
            width=int(stroke_w),
        )

    # 3. Diagonal Sekunder (/) — Gradien Indigo Dalam ke Ungu Aksen
    for i in range(d1_steps):
        t0 = i / float(d1_steps)
        t1 = (i + 1) / float(d1_steps)

        x_start = cx + span - t0 * (2 * span)
        y_start = cy - span + t0 * (2 * span)
        x_end = cx + span - t1 * (2 * span)
        y_end = cy - span + t1 * (2 * span)

        dist_from_center = abs(t0 - 0.5)
        if dist_from_center < 0.12:
            alpha = int(255 * (dist_from_center / 0.12 * 0.4 + 0.6))
        else:
            alpha = 255

        r = int(147 + (124 - 147) * t0)
        g = int(51 + (58 - 51) * t0)
        b = int(234 + (237 - 234) * t0)

        draw.line(
            [(x_start, y_start), (x_end, y_end)],
            fill=(r, g, b, alpha),
            width=int(stroke_w * 0.92),
        )

    # 4. Caps membulat rapi di ujung diagonal
    caps = [
        (cx - span, cy - span, (124, 58, 237, 255)),
        (cx + span, cy + span, (192, 132, 252, 255)),
        (cx + span, cy - span, (147, 51, 234, 255)),
        (cx - span, cy + span, (124, 58, 237, 255)),
    ]
    for px, py, col in caps:
        draw.ellipse(
            [
                px - stroke_w / 2.0,
                py - stroke_w / 2.0,
                px + stroke_w / 2.0,
                py + stroke_w / 2.0,
            ],
            fill=col,
        )

    # 5. Highlight kilau glossy (Specular Reflex) di lengan atas
    spec_layer = Image.new("RGBA", (ss_size, ss_size), (0, 0, 0, 0))
    spec_draw = ImageDraw.Draw(spec_layer)
    spec_draw.line(
        [
            (cx - span * 0.85, cy - span * 0.85),
            (cx - span * 0.15, cy - span * 0.15),
        ],
        fill=(255, 255, 255, 160),
        width=int(stroke_w * 0.28),
    )
    spec_draw.ellipse(
        [
            cx - span * 0.85 - stroke_w * 0.14,
            cy - span * 0.85 - stroke_w * 0.14,
            cx - span * 0.85 + stroke_w * 0.14,
            cy - span * 0.85 + stroke_w * 0.14,
        ],
        fill=(255, 255, 255, 160),
    )
    spec_layer = spec_layer.filter(ImageFilter.GaussianBlur(radius=scale * 2.5))
    im.alpha_composite(spec_layer)

    return im.resize((size, size), Image.Resampling.LANCZOS)


def build_source(
    size: int,
    tile: bool = True,
    bg_color: tuple[int, int, int, int] = (245, 243, 255, 255),
    fill: float = 0.82,
) -> Image.Image:
    """Membangun kanvas dengan latar ubin squircle halus atau murni transparan."""
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    if tile:
        draw = ImageDraw.Draw(out)
        margin = max(1, int(size * 0.04))
        r = int(size * 0.22)
        shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        sdraw = ImageDraw.Draw(shadow)
        sdraw.rounded_rectangle(
            [margin + 2, margin + 4, size - margin - 2, size - margin],
            radius=r,
            fill=(124, 58, 237, 45),
        )
        shadow = shadow.filter(ImageFilter.GaussianBlur(radius=max(1, size // 32)))
        out.alpha_composite(shadow)

        draw.rounded_rectangle(
            [margin, margin, size - margin, size - margin],
            radius=r,
            fill=bg_color,
        )

    glyph_sz = int(size * fill)
    glyph = draw_cyber_x(glyph_sz)
    offset = (size - glyph_sz) // 2
    out.alpha_composite(glyph, (offset, offset))
    return out


def _from_design(size: int, fill: float = 0.82) -> Image.Image:
    """Render logo dari design/logo-asli.png (README 128) ke kanvas persegi transparan.
    Sumber 768x729 di-fit ke kotak fill*size, center, tanpa tile/squircle.
    Ini bikin SEMUA artefak (ICO, PNG, mipmap, favicon) identik README."""
    src_path = ROOT / "design/logo-asli.png"
    if not src_path.exists():
        # fallback ke glyph matematis jika file hilang
        return build_source(size, tile=False, fill=fill)
    src = Image.open(src_path).convert("RGBA")
    # Hitung ukuran agar proporsi tetap (fit, bukan stretch)
    sw, sh = src.size
    target = int(size * fill)
    scale = min(target / sw, target / sh)
    nw, nh = int(sw * scale), int(sh * scale)
    # Resize dengan LANCZOS kualitas tinggi
    # Pillow 10+: Resampling.LANCZOS
    try:
        resized = src.resize((nw, nh), Image.Resampling.LANCZOS)
    except AttributeError:
        resized = src.resize((nw, nh), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ox = (size - nw) // 2
    oy = (size - nh) // 2
    out.alpha_composite(resized, (ox, oy))
    return out


def _from_design_tile(size: int, fill: float = 0.82, bg_color=(245, 243, 255, 255)) -> Image.Image:
    """Tile #F5F3FF + glyph design/logo-asli.png (untuk legacy & ICO wajib terang)."""
    from PIL import ImageDraw, ImageFilter
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(out)
    margin = max(1, int(size * 0.04))
    r = int(size * 0.22)
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.rounded_rectangle([margin+2, margin+4, size-margin-2, size-margin], radius=r, fill=(124,58,237,45))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=max(1, size//32)))
    out.alpha_composite(shadow)
    draw.rounded_rectangle([margin, margin, size-margin, size-margin], radius=r, fill=bg_color)
    src_path = ROOT / "design/logo-asli.png"
    src = Image.open(src_path).convert("RGBA")
    sw, sh = src.size
    target = int(size * fill)
    scale = min(target / sw, target / sh)
    nw, nh = int(sw * scale), int(sh * scale)
    resized = src.resize((nw, nh), Image.Resampling.LANCZOS)
    ox = (size - nw)//2
    oy = (size - nh)//2
    out.alpha_composite(resized, (ox, oy))
    return out


def save_ico(path: Path, sizes: list[int] = [16, 32, 48, 64, 128, 256]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    # Semua ICO sekarang dari design/logo-asli.png (README) — konsisten, transparan, no tile
    largest = max(sizes)
    base = _from_design_tile(largest)
    # Pillow akan resize otomatis dari base ke setiap ukuran di `sizes`
    base.save(
        path,
        format="ICO",
        sizes=[(s, s) for s in sizes],
    )
    print(f"OK {path.relative_to(ROOT)} ({len(sizes)} sizes, base {largest}px, from design/logo-asli.png)")


def main() -> None:
    print("🎨 Menggenerasi seluruh aset logo kanonikal XyDesk...")

    # 1. Logo Master Web / App
    ROOT.joinpath("web/public").mkdir(parents=True, exist_ok=True)
    logo_1024 = _from_design(1024, fill=0.88)
    logo_1024.save(ROOT / "web/public/logo.png")
    logo_1024.save(ROOT / "web/public/logo-512.png")
    print("OK web/public/logo.png (1024x1024 from design/logo-asli.png)")
    # Desktop logo: 256 dari design/logo-asli.png via _from_design (persegi, proporsional, transparan)
    try:
        (ROOT / "desktop/public").mkdir(parents=True, exist_ok=True)
        _from_design(256, fill=0.82).save(ROOT / "desktop/public/logo.png", "PNG")
        print("OK desktop/public/logo.png (256x256 from design/logo-asli.png via _from_design)")
    except Exception as e:
        print(f"[WARN] gagal generate desktop logo dari design/logo-asli.png: {e}")
        build_source(256, tile=False, fill=0.88).save(ROOT / "desktop/public/logo.png")
        print("OK desktop/public/logo.png (256 fallback)")

    # 2. PWA 192x192
    logo_192 = _from_design(192, fill=0.88)
    logo_192.save(ROOT / "web/public/logo-192.png")
    print("OK web/public/logo-192.png (192x192 from design/logo-asli.png)")

    # 3. Android mipmaps
    for density, (legacy, foreground) in ANDROID_DENSITIES.items():
        base = ROOT / "android/app/src/main/res" / f"mipmap-{density}"
        base.mkdir(parents=True, exist_ok=True)
        # Legacy & adaptive SEMUA dari design/logo-asli.png (README) — konsisten
        # Legacy icon (Android < 8.0) dulu pakai tile, sekarang transparan dari design agar sama README
        _from_design_tile(legacy, fill=0.82).save(base / "ic_launcher.png")
        _from_design(foreground, fill=0.88).save(
            base / "ic_launcher_foreground.png"
        )
        print(f"OK mipmap-{density:<8} legacy={legacy} foreground={foreground} (transparent)")

    # Favicon multi-ukuran untuk peramban lama.
    save_ico(ROOT / "web/public/favicon.ico", [16, 32, 48])

    # Windows App & Installer ICOs
    save_ico(ROOT / "packaging/windows/xydesk.ico")
    save_ico(ROOT / "packaging/windows/app.ico")
    save_ico(ROOT / "desktop/assets/icon.ico")
    save_ico(ROOT / "desktop/electron/tray.ico", [16, 32, 48])
    save_ico(ROOT / "desktop/src-tauri/icons/icon.ico")
    save_ico(ROOT / "desktop/src-tauri/icons/tray.ico", [16, 32, 48])

    # Tauri PNG Icons
    tauri_icons = ROOT / "desktop/src-tauri/icons"
    tauri_icons.mkdir(parents=True, exist_ok=True)
    _from_design(32, fill=0.82).save(tauri_icons / "32x32.png")
    _from_design(128, fill=0.82).save(tauri_icons / "128x128.png")
    _from_design(256, fill=0.82).save(tauri_icons / "128x128@2x.png")
    _from_design(512, fill=0.88).save(tauri_icons / "icon.png")
    print("OK desktop/src-tauri/icons/*.png")

    print("\n✅ Semua aset logo berhasil diperbarui!")


if __name__ == "__main__":
    main()

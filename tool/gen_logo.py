#!/usr/bin/env python3
"""Generator logo XyDesk — satu sumber geometri untuk semua platform.

## Kenapa digambar kode, bukan diekspor dari editor

Logo XyDesk dipakai di 20+ ukuran: mipmap Android enam kepadatan, favicon web
tiga ukuran, apple-touch-icon, tile splash, badge komentar 16 px. Setiap kali
logo direvisi, semuanya harus ikut — dan yang selalu terjadi adalah dua atau
tiga berkas ketinggalan, lalu aplikasi memajang dua logo berbeda sekaligus.

Revisi terakhir juga gagal gerbang `tool/audit_assets.py` karena hasil ekspor
punya matte opaque di tepi. Menggambar dari kode membuat transparansi menjadi
sifat bawaan, bukan sesuatu yang harus diingat.

## Geometri

Tile squircle gelap dengan margin transparan 9%. Di dalamnya huruf X dari dua
goresan tebal berujung rata:

- Goresan `\\` putih murni — sisi "kamu", perangkat yang kamu pegang.
- Goresan `/` gradien ungu #7C3AED → #A78BFA — sisi "PC", yang dikendalikan.
- Keduanya bertemu di tengah dengan simpul terang tipis: dua sisi tersambung.

Digambar 6x lalu diperkecil (supersampling) supaya tepi miringnya bersih tanpa
bergantung pada antialias bawaan yang kasar.

Pakai:
    python3 tool/gen_logo.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]

SS = 6  # faktor supersampling
BASE = 1024

TILE_DARK = (13, 7, 22, 255)  # #0D0716
VIOLET = (124, 58, 237)  # #7C3AED
LAVENDER = (167, 139, 250)  # #A78BFA
WHITE = (255, 255, 255)


def _lerp(a: tuple[int, int, int], b: tuple[int, int, int], t: float):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def _gradient(size: int, top: tuple[int, int, int], bottom: tuple[int, int, int]):
    """Gradien vertikal seukuran kanvas."""
    grad = Image.new("RGB", (1, size))
    px = grad.load()
    for y in range(size):
        px[0, y] = _lerp(top, bottom, y / max(1, size - 1))
    return grad.resize((size, size), Image.NEAREST)


def _stroke_mask(size: int, direction: str, thickness: float, inset: float):
    """Mask satu goresan diagonal berujung rata.

    `direction` "\\" dari kiri-atas ke kanan-bawah, "/" sebaliknya.
    """
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    a = inset * size
    b = size - a
    half = thickness * size / 2
    if direction == "\\":
        poly = [(a - half, a), (a + half, a), (b + half, b), (b - half, b)]
    else:
        poly = [(b - half, a), (b + half, a), (a + half, b), (a - half, b)]
    d.polygon(poly, fill=255)
    return mask


def _squircle(size: int, radius_ratio: float, margin_ratio: float):
    """Mask tile rounded-square dengan margin transparan."""
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    m = margin_ratio * size
    d.rounded_rectangle(
        (m, m, size - m, size - m),
        radius=radius_ratio * (size - 2 * m),
        fill=255,
    )
    return mask


def build_mark(size: int, *, tile: bool) -> Image.Image:
    """Bangun logo pada ukuran akhir `size`."""
    s = size * SS
    canvas = Image.new("RGBA", (s, s), (0, 0, 0, 0))

    # Tanpa tile, huruf X butuh margin lebih besar supaya tidak menyentuh tepi
    # (gerbang audit menolak piksel opaque di 4 baris terluar).
    inset = 0.30 if tile else 0.22
    thickness = 0.15 if tile else 0.17

    if tile:
        tile_mask = _squircle(s, radius_ratio=0.22, margin_ratio=0.09)
        plate = Image.new("RGBA", (s, s), TILE_DARK)
        canvas.paste(plate, (0, 0), tile_mask)

    # Goresan ungu (dibawah), lalu goresan putih (di atas) — urutan ini yang
    # membuat simpul di tengah terbaca sebagai "putih menyeberang".
    grad = _gradient(s, VIOLET, LAVENDER).convert("RGBA")
    canvas.paste(grad, (0, 0), _stroke_mask(s, "/", thickness, inset))

    white_mask = _stroke_mask(s, "\\", thickness, inset)
    white_layer = Image.new("RGBA", (s, s), WHITE + (255,))
    if not tile:
        # Versi tanpa tile dipakai di atas latar terang; putih murni akan
        # hilang. Pakai ungu tua sebagai gantinya.
        white_layer = Image.new("RGBA", (s, s), (109, 40, 217, 255))
    canvas.paste(white_layer, (0, 0), white_mask)

    return canvas.resize((size, size), Image.LANCZOS)


def build_wordmark_tile(size: int, light: bool) -> Image.Image:
    """Varian monokrom untuk latar yang berlawanan."""
    s = size * SS
    canvas = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    color = (255, 255, 255, 255) if light else (13, 7, 22, 255)
    layer = Image.new("RGBA", (s, s), color)
    canvas.paste(layer, (0, 0), _stroke_mask(s, "/", 0.17, 0.22))
    canvas.paste(layer, (0, 0), _stroke_mask(s, "\\", 0.17, 0.22))
    return canvas.resize((size, size), Image.LANCZOS)


# Android adaptive icon.
#
# Yang diperbaiki di sini: berkas `ic_launcher_foreground.png` sebelumnya
# berukuran sama dengan ikon legacy (48–192 px). Lapisan foreground adaptive
# icon berukuran 108dp, jadi di xxxhdpi ia seharusnya 432 px — yang lama
# di-upscale peluncur dan tampak buram di layar kepadatan tinggi.
ANDROID_DENSITIES = {
    "mdpi": (48, 108),
    "hdpi": (72, 162),
    "xhdpi": (96, 216),
    "xxhdpi": (144, 324),
    "xxxhdpi": (192, 432),
}


def build_foreground(size: int) -> Image.Image:
    """Lapisan foreground adaptive icon: hanya huruf X, tanpa tile.

    Latarnya disediakan `@color/ic_launcher_background`, dan XML memberi inset
    16% supaya X jatuh di dalam zona aman 72dp.
    """
    s = size * SS
    canvas = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    grad = _gradient(s, VIOLET, LAVENDER).convert("RGBA")
    canvas.paste(grad, (0, 0), _stroke_mask(s, "/", 0.17, 0.05))
    white = Image.new("RGBA", (s, s), WHITE + (255,))
    canvas.paste(white, (0, 0), _stroke_mask(s, "\\", 0.17, 0.05))
    return canvas.resize((size, size), Image.LANCZOS)


OUTPUTS = [
    # (path, ukuran, jenis)
    ("assets/img/logo.png", BASE, "tile"),
    ("design/x-white.png", 512, "white"),
    ("design/x-black.png", 512, "black"),
    ("web/public/logo.png", 512, "tile"),
    ("web/public/logo-white.png", 512, "white"),
    ("web/public/icon-192.png", 192, "tile"),
    ("web/public/icon-512.png", 512, "tile"),
    ("web/public/apple-touch-icon.png", 180, "tile"),
    ("web/public/favicon-32.png", 32, "tile"),
    ("web/public/favicon-16.png", 16, "tile"),
]


def main() -> None:
    for rel, size, kind in OUTPUTS:
        path = ROOT / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        if kind == "tile":
            img = build_mark(size, tile=True)
        elif kind == "white":
            img = build_wordmark_tile(size, light=True)
        else:
            img = build_wordmark_tile(size, light=False)
        img.save(path)
        print(f"OK {rel:38} {size}x{size}")

    # Android: ikon legacy + lapisan foreground adaptive icon.
    for density, (legacy, foreground) in ANDROID_DENSITIES.items():
        base = ROOT / "android/app/src/main/res" / f"mipmap-{density}"
        base.mkdir(parents=True, exist_ok=True)
        build_mark(legacy, tile=True).save(base / "ic_launcher.png")
        build_foreground(foreground).save(base / "ic_launcher_foreground.png")
        print(f"OK mipmap-{density:<8} legacy={legacy} foreground={foreground}")

    # Favicon multi-ukuran untuk peramban lama.
    ico = ROOT / "web/public/favicon.ico"
    build_mark(64, tile=True).save(
        ico, sizes=[(16, 16), (32, 32), (48, 48), (64, 64)]
    )
    print(f"OK {'web/public/favicon.ico':38} multi")


if __name__ == "__main__":
    main()

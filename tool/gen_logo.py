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
# ── Sumber logo: berkas, bukan geometri ───────────────────────────────────
#
# Identitas XyDesk dikembalikan ke logo asli (mark biru-ungu transparan).
# Geometri kode di atas tetap disimpan sebagai cadangan dan dokumentasi
# bentuk, tetapi yang dipakai semua platform sekarang adalah berkas ini -
# karena kalau ada dua sumber, pasti ada berkas yang ketinggalan dan
# aplikasi akhirnya memajang dua logo berbeda sekaligus.
#
# Ganti identitas? Timpa `design/logo-asli.png` (persegi, latar transparan,
# isi tidak menyentuh tepi), lalu jalankan ulang skrip ini.
SOURCE = ROOT / "design" / "logo-asli.png"


def source_is_dark() -> bool:
    """Apakah logo asli bernilai gelap?

    Logo XyDesk pernah berganti-ganti: ada yang biru-ungu, ada yang monokrom
    hitam. Beberapa target duduk di atas latar gelap (ikon launcher, .ico
    Windows) dan sisanya di latar terang (splash Android #FAFAF9). Kalau
    pembuatnya memilih warna sendiri, cepat atau lambat ada logo yang
    tenggelam di latarnya — jadi terang/gelapnya diukur, bukan ditebak.
    """
    im = _source_image()
    small = im.resize((64, 64), Image.LANCZOS)
    total = 0.0
    weight = 0
    for r, g, b, a in small.convert("RGBA").getdata():
        if a < 128:
            continue
        lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
        total += lum * a
        weight += a
    if not weight:
        return False
    return (total / weight) < 0.5


def _source_image() -> Image.Image:
    """Buka sumber logo, dipangkas ke isinya supaya margin simetris."""
    im = Image.open(SOURCE).convert("RGBA")
    bbox = im.getchannel("A").getbbox()
    return im.crop(bbox) if bbox else im


def build_source(
    size: int,
    *,
    fill: float = 0.92,
    mono: tuple[int, int, int] | None = None,
    tile: bool = False,
) -> Image.Image:
    """Render logo asli pada kanvas `size x size`.

    fill  proporsi kanvas yang diisi logo (0..1).
    mono  bila diisi, logo dijadikan siluet warna itu (dipakai di latar yang
          bertolak belakang: putih untuk latar gelap, gelap untuk latar muda).
    tile  kompositkan di atas tile squircle gelap. Wajib untuk ikon launcher
          dan .ico Windows: peluncur lama tidak memberi latar, jadi logo
          transparan bisa tenggelam di wallpaper terang.
    """
    s = size * SS
    canvas = Image.new("RGBA", (s, s), (0, 0, 0, 0))

    if tile:
        plate = Image.new("RGBA", (s, s), TILE_DARK)
        canvas.paste(plate, (0, 0), _squircle(s, 0.22, 0.02))
        inner = 0.72  # logo duduk di dalam tile, tidak menyentuh tepi tile
        # Tile-nya gelap (#0D0716), jadi logo gelap harus jadi siluet putih
        # supaya tidak lenyap. Ini yang menjaga ikon tetap terbaca di
        # wallpaper apa pun, berapa kali pun identitasnya berganti.
        if source_is_dark():
            mono = mono or WHITE
    else:
        inner = fill

    im = _source_image()
    if mono is not None:
        alpha = im.getchannel("A")
        flat = Image.new("RGBA", im.size, mono + (255,))
        flat.putalpha(alpha)
        im = flat

    target = int(round(s * inner))
    im = im.resize((target, target), Image.LANCZOS)
    canvas.paste(im, ((s - target) // 2, (s - target) // 2), im)
    return canvas.resize((size, size), Image.LANCZOS)


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
    ("assets/img/logo.png", BASE, "mark"),
    ("design/x-white.png", 512, "white"),
    ("design/x-black.png", 512, "black"),
    ("web/public/logo.png", 512, "mark"),
    ("web/public/logo-white.png", 512, "white"),
    ("web/public/icon-192.png", 192, "mark"),
    ("web/public/icon-512.png", 512, "mark"),
    ("web/public/apple-touch-icon.png", 180, "mark"),
    ("web/public/favicon-32.png", 32, "mark"),
    ("web/public/favicon-16.png", 16, "mark"),
    # Splash Android. Yang "tight" digambar utuh di 104dp; yang android12
    # ditutup sistem dengan lingkaran berdiameter 2/3 kanvas, jadi isinya
    # dikecilkan agar tidak terpotong.
    ("android/app/src/main/res/drawable-nodpi/splash_logo_tight.png", 640, "splash"),
    ("android/app/src/main/res/drawable-nodpi/splash_logo_android12.png", 640, "splash12"),
    ("packaging/windows/xydesk.ico", 256, "ico"),
    # Shell desktop (Electron + Next.js). `tray.ico` dipakai TIGA tempat sekaligus
    # di desktop/package.json (ikon jendela, tray, dan build Windows), jadi dia
    # harus ikut di sini — bukan file hasil ekspor manual. `logo.png` untuk merek
    # di sidebar: dulu `page.tsx` menggambar "X" ungu inline (SVG bikinan
    # sendiri) sehingga shell memajang logo yang berbeda dari platform lain.
    ("desktop/public/logo.png", 256, "mark"),
    ("desktop/electron/tray.ico", 256, "ico"),
]

# Ukuran yang ikut dibundel dalam satu berkas .ico.
ICO_SIZES = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]


def _render(size: int, kind: str) -> Image.Image:
    """Bangun logo sesuai jenis keluaran."""
    if kind == "mark":
        return build_source(size)
    if kind == "white":
        return build_source(size, mono=WHITE, fill=0.86)
    if kind == "black":
        return build_source(size, mono=TILE_DARK[:3], fill=0.86)
    if kind == "splash":
        return build_source(size, fill=0.86)
    if kind == "splash12":
        return build_source(size, fill=0.66)
    if kind == "ico":
        return build_source(size, tile=True)
    raise ValueError(f"jenis keluaran tidak dikenal: {kind}")

def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(
            f"Sumber logo tidak ada: {SOURCE}\n"
            "Taruh logo asli di sana, atau jalankan dengan geometri cadangan "
            "memakai build_mark() secara manual."
        )

    for rel, size, kind in OUTPUTS:
        path = ROOT / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        img = _render(size, kind)
        if rel.endswith(".ico"):
            img.save(path, sizes=[s for s in ICO_SIZES if s[0] <= size])
        else:
            img.save(path)
        print(f"OK {rel:64} {size}x{size}")

    # Android: ikon legacy + lapisan foreground adaptive icon.
    for density, (legacy, foreground) in ANDROID_DENSITIES.items():
        base = ROOT / "android/app/src/main/res" / f"mipmap-{density}"
        base.mkdir(parents=True, exist_ok=True)
        build_source(legacy, tile=True).save(base / "ic_launcher.png")
        # XML memberi inset 16%, jadi isi efektifnya 0.92 x (1 - 0.32) = 0.63
        # kanvas — aman di dalam zona aman 72dp adaptive icon.
        # Latar adaptive icon ikut @color/ic_launcher_background (#0D0716),
        # jadi logo gelap dipaksa jadi siluet putih (lihat build_source).
        build_source(foreground, tile=source_is_dark()).save(
            base / "ic_launcher_foreground.png"
        )
        print(f"OK mipmap-{density:<8} legacy={legacy} foreground={foreground}")

    # Favicon multi-ukuran untuk peramban lama.
    ico = ROOT / "web/public/favicon.ico"
    build_source(64, fill=0.90).save(
        ico, sizes=[(16, 16), (32, 32), (48, 48), (64, 64)]
    )
    print(f"OK {'web/public/favicon.ico':64} multi")


if __name__ == "__main__":
    main()

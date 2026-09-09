#!/usr/bin/env python3
"""Penjaga ikon launcher XyDesk.

Ikon launcher dua kali regresi ke varian hitam (Sep 2026): sekali karena
flatten alpha, sekali karena generator memutihkan sumber gelap + memanggang
tile gelap opak ke foreground adaptive icon. Gerbang ini mengunci FAKTA
pikselnya supaya tidak terulang:

- foreground adaptive icon wajib transparan (tanpa tile panggangan);
- tile legacy + .ico wajib terang (#F5F3FF) dengan warna logo asli;
- warna latar adaptive icon di XML wajib #F5F3FF.

Jalankan ulang generator (`python3 tool/gen_logo.py`) bila gerbang ini merah
setelah ganti identitas — jangan edit PNG-nya manual.
"""
from pathlib import Path
from xml.etree import ElementTree

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "android" / "app" / "src" / "main" / "res"
DENSITIES = ("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi")
ICOS = (
    "packaging/windows/xydesk.ico",
    "desktop/electron/tray.ico",
    "desktop/src-tauri/icons/icon.ico",
    "desktop/src-tauri/icons/tray.ico",
)
BG_XML = RES / "values" / "ic_launcher_background.xml"
BG_COLOR = "#F5F3FF"

# Ambang dipilih dari celah yang lebar: tile terang lum ~0.76, tile gelap
# #0D0716 lum ~0.05 (campur siluet putih pun cuma ~0.34).
MIN_TILE_LUMINANCE = 0.45
# Foreground logo ungu opak ~43%; tile panggangan mendorongnya ke ~88%.
MAX_FOREGROUND_OPAQUE = 0.85


def fail(message: str) -> None:
    raise SystemExit(f"IKON GAGAL: {message}")


def stats(path: Path) -> tuple[float, float]:
    """Kembalikan (fraksi opak, luminance rata-rata piksel opak)."""
    pixels = list(Image.open(path).convert("RGBA").get_flattened_data())
    opaque = [(r, g, b) for r, g, b, a in pixels if a > 128]
    if not opaque:
        fail(f"{path} seluruhnya transparan")
    lum = sum((0.2126 * r + 0.7152 * g + 0.0722 * b) / 255 for r, g, b in opaque)
    return len(opaque) / len(pixels), lum / len(opaque)


def main() -> None:
    for density in DENSITIES:
        legacy = RES / f"mipmap-{density}" / "ic_launcher.png"
        opaque, lum = stats(legacy)
        if lum < MIN_TILE_LUMINANCE:
            fail(
                f"{legacy.name} ({density}) gelap (lum {lum:.2f}) — tile "
                "wajib terang #F5F3FF dengan warna logo asli"
            )
        fg = RES / f"mipmap-{density}" / "ic_launcher_foreground.png"
        alpha_min = Image.open(fg).convert("RGBA").getchannel("A").getextrema()[0]
        if alpha_min != 0:
            fail(f"{fg.name} ({density}) tidak punya piksel transparan")
        opaque, _ = stats(fg)
        if opaque > MAX_FOREGROUND_OPAQUE:
            fail(
                f"{fg.name} ({density}) {opaque:.0%} opak — tile terpanggang "
                "ke foreground, wajib transparan"
            )

    for rel in ICOS:
        _, lum = stats(ROOT / rel)
        if lum < MIN_TILE_LUMINANCE:
            fail(f"{rel} gelap (lum {lum:.2f}) — .ico wajib tile terang")

    color = ElementTree.parse(BG_XML).getroot().findtext("color")
    if (color or "").strip().upper() != BG_COLOR:
        fail(f"{BG_XML.name} = {color}, wajib {BG_COLOR}")

    print(f"Ikon OK: {len(DENSITIES) * 2} mipmap + {len(ICOS)} ico + XML terang.")


if __name__ == "__main__":
    main()

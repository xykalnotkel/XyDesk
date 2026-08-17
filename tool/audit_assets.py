#!/usr/bin/env python3
"""Gerbang ilustrasi transparan XyDesk.

Menolak matte putih/opaque yang menyentuh tepi, alpha palsu, dimensi terlalu
kecil, dan margin transparan yang hilang. Ini bukan penilai estetika; tujuannya
mencegah hasil remove-background mentah masuk lagi ke UI light/dark.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets" / "img"
EXCLUDED = {"google_g.png", "xydesk_update_banner.jpg"}


def fail(message: str) -> None:
    raise SystemExit(f"ASSET GAGAL: {message}")


def main() -> None:
    checked = 0
    for path in sorted(ASSET_DIR.iterdir()):
        if path.name in EXCLUDED or path.suffix.lower() not in {".png", ".webp"}:
            continue
        image = Image.open(path).convert("RGBA")
        width, height = image.size
        if min(width, height) < 192:
            fail(f"{path.name} terlalu kecil ({width}x{height})")

        alpha = image.getchannel("A")
        extrema = alpha.getextrema()
        if extrema[0] != 0:
            fail(f"{path.name} tidak memiliki background transparan")

        border = []
        for offset in range(4):
            border.extend(alpha.crop((0, offset, width, offset + 1)).get_flattened_data())
            border.extend(alpha.crop((0, height - 1 - offset, width, height - offset)).get_flattened_data())
            border.extend(alpha.crop((offset, 0, offset + 1, height)).get_flattened_data())
            border.extend(alpha.crop((width - 1 - offset, 0, width - offset, height)).get_flattened_data())
        opaque_border = sum(value > 24 for value in border)
        if opaque_border:
            fail(f"{path.name} punya {opaque_border} piksel matte/objek di tepi")

        transparent_ratio = sum(value < 8 for value in alpha.get_flattened_data()) / (width * height)
        if transparent_ratio < 0.05:
            fail(f"{path.name} margin transparannya kurang dari 5%")

        print(
            f"OK {path.name:30} {width:4}x{height:<4} "
            f"transparan={transparent_ratio:6.1%}"
        )
        checked += 1

    if checked < 10:
        fail(f"hanya {checked} ilustrasi yang diperiksa")
    print(f"Lulus: {checked} ilustrasi konsisten untuk tema terang dan gelap.")


if __name__ == "__main__":
    main()

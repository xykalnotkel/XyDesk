#!/usr/bin/env python3
"""Buat ikon launcher Android dari logo transparan.

Android butuh dua bentuk:
  • ic_launcher            — ikon legacy, latar solid
  • ic_launcher_foreground — lapisan depan adaptive icon (API 26+), dengan
    safe zone: hanya ~66% tengah dijamin terlihat.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ART = Path(__file__).parent
SRC = ART / 'out' / 'logo_1024.png'
DEST = Path(sys.argv[1]) if len(sys.argv) > 1 else (
    ART.parent / 'xydesk' / 'android' / 'app' / 'src' / 'main' / 'res')

BG = (19, 19, 21, 255)  # #131315 — sama dengan background aplikasi
DENS = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}


def legacy(logo, size):
    canvas = Image.new('RGBA', (size, size), BG)
    inner = int(size * 0.68)
    im = logo.resize((inner, inner), Image.LANCZOS)
    canvas.paste(im, ((size - inner) // 2, (size - inner) // 2), im)
    mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=int(size * 0.22), fill=255)
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.paste(canvas, (0, 0), mask)
    return out


def foreground(logo, size):
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    inner = int(size * 0.46)  # aman di semua bentuk mask peluncur
    im = logo.resize((inner, inner), Image.LANCZOS)
    canvas.paste(im, ((size - inner) // 2, (size - inner) // 2), im)
    return canvas


def main():
    logo = Image.open(SRC).convert('RGBA')
    for dens, size in DENS.items():
        d = DEST / f'mipmap-{dens}'
        d.mkdir(parents=True, exist_ok=True)
        legacy(logo, size).save(d / 'ic_launcher.png', optimize=True)
        fg = int(size * 108 / 48)
        foreground(logo, fg).save(d / 'ic_launcher_foreground.png', optimize=True)
        print(f'  mipmap-{dens:8} {size}px + fg {fg}px')

    v = DEST / 'values'
    v.mkdir(parents=True, exist_ok=True)
    (v / 'ic_launcher_background.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <color name="ic_launcher_background">#131315</color>\n</resources>\n')

    d = DEST / 'mipmap-anydpi-v26'
    d.mkdir(parents=True, exist_ok=True)
    xml = ('<?xml version="1.0" encoding="utf-8"?>\n'
           '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
           '    <background android:drawable="@color/ic_launcher_background"/>\n'
           '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
           '    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>\n'
           '</adaptive-icon>\n')
    (d / 'ic_launcher.xml').write_text(xml)
    (d / 'ic_launcher_round.xml').write_text(xml)
    print('  + adaptive icon (v26) & warna latar')


if __name__ == '__main__':
    main()

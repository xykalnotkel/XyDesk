#!/usr/bin/env python3
"""Compositor banner push notification XyDesk.

Menempelkan tipografi (brand, headline, versi, tanggal, tombol CTA) di atas
artwork dasar HD. Teks digambar dengan font Inter dari assets/fonts — bukan
bagian dari gambar — sehingga versi SELALU benar dan tajam di setiap rilis.

Dipanggil dari workflow Release:
    python3 tool/art/banner.py --version 1.2.1 --build 5 --out dist/banner.jpg

Output: JPEG 1024x512 (big picture OneSignal) berkualitas tinggi.
"""

import argparse
import datetime
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
BASE_ART = ROOT / 'design' / 'notifications' / 'banner_art_hd.png'
FONTS = ROOT / 'assets' / 'fonts'

W, H = 1024, 512
MARGIN_X = 64

WHITE = (255, 255, 255)
LAVENDER = (200, 186, 255)
MUTED = (168, 167, 180)
ACCENT = (118, 84, 246)
ACCENT_HI = (154, 123, 255)


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONTS / name), size)


def rounded_rect(draw, xy, radius, fill):
    draw.rounded_rectangle(xy, radius=radius, fill=fill)


def text_w(draw, s, f):
    left, _, right, _ = draw.textbbox((0, 0), s, font=f)
    return right - left


def build(version: str, build_number: str, out_path: Path, generic: bool = False) -> None:
    art = Image.open(BASE_ART).convert('RGB')
    # Art dasar dirender 2:1; samakan ukuran output.
    art = art.resize((W, H), Image.LANCZOS)

    # Gelapkan sepertiga kiri secukupnya supaya kontras teks terjamin
    # berapa pun hasil generate art-nya (WCAG-ish, bukan asal cakep).
    shade = Image.new('L', (W, H), 0)
    sd = ImageDraw.Draw(shade)
    for x in range(W // 2):
        # gradasi 150 -> 0 dari kiri ke tengah
        sd.line([(x, 0), (x, H)], fill=int(150 * (1 - x / (W / 2))))
    black = Image.new('RGB', (W, H), (7, 5, 14))
    art = Image.composite(black, art, shade.filter(ImageFilter.GaussianBlur(24)))

    draw = ImageDraw.Draw(art)

    f_brand = font('Inter-Bold.ttf', 30)
    f_sub = font('Inter-SemiBold.ttf', 16)
    f_head = font('Inter-Bold.ttf', 88)
    f_ver = font('Inter-SemiBold.ttf', 30)
    f_meta = font('Inter-Medium.ttf', 19)
    f_btn = font('Inter-Bold.ttf', 21)

    y = 74

    # ── Brand lockup ──
    # Logo: kotak gradasi sederhana dengan huruf X (vektor teks, selalu tajam).
    logo = 44
    lx, ly = MARGIN_X, y - 6
    for i in range(logo):
        t = i / logo
        r = int(154 + (59 - 154) * t)
        g = int(123 + (124 - 123) * t)
        b = int(255 + (255 - 255) * t)
        draw.line([(lx, ly + i), (lx + logo, ly + i)], fill=(r, g, b))
    # bulatkan sudut logo dengan mask
    mask = Image.new('L', (logo, logo), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, logo - 1, logo - 1], 12, fill=255)
    region = art.crop((lx, ly, lx + logo, ly + logo))
    base_region = Image.new('RGB', (logo, logo), (11, 7, 20))
    base_region.paste(region, (0, 0), mask)
    art.paste(base_region, (lx, ly))
    draw = ImageDraw.Draw(art)
    fx = font('Inter-Bold.ttf', 28)
    xw = text_w(draw, 'X', fx)
    draw.text((lx + (logo - xw) / 2, ly + 5), 'X', font=fx, fill=WHITE)

    draw.text((lx + logo + 14, y - 4), 'XYDESK', font=f_brand, fill=WHITE)
    draw.text(
        (lx + logo + 14, y + 28),
        'NEW RELEASE',
        font=f_sub,
        fill=ACCENT_HI,
    )

    # ── Headline ──
    y = 176
    draw.text((MARGIN_X, y), 'UPDATE!', font=f_head, fill=WHITE)

    # ── Versi + tanggal (otomatis) — dilewati pada banner generic in-app ──
    tanggal = ''
    if generic:
        y += 118
        draw.text(
            (MARGIN_X, y),
            'Versi baru sudah tersedia',
            font=f_ver,
            fill=LAVENDER,
        )
        y += 44
    else:
        y += 118
        ver_label = f'Versi {version}'
        draw.text((MARGIN_X, y), ver_label, font=f_ver, fill=LAVENDER)
        vw = text_w(draw, ver_label, f_ver)
        # chip build number
        chip_x = MARGIN_X + vw + 14
        chip_text = f'build {build_number}'
        cw = text_w(draw, chip_text, f_meta)
        rounded_rect(draw, [chip_x, y + 2, chip_x + cw + 22, y + 32], 15, (34, 28, 58))
        draw.text((chip_x + 11, y + 6), chip_text, font=f_meta, fill=ACCENT_HI)

        y += 44
        bulan = [
            'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
            'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
        ]
        now = datetime.datetime.now(datetime.timezone.utc)
        tanggal = f'{now.day} {bulan[now.month - 1]} {now.year}'
        draw.text(
            (MARGIN_X, y),
            f'Sudah tersedia • {tanggal}',
            font=f_meta,
            fill=MUTED,
        )

    # ── Tombol CTA ──
    y += 46
    btn_text = 'CEK SEKARANG  \u2192'
    bw = text_w(draw, btn_text, f_btn)
    bx0, by0 = MARGIN_X, y
    bx1, by1 = MARGIN_X + bw + 48, y + 52
    # bayangan lembut
    shadow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [bx0, by0 + 6, bx1, by1 + 6], 16, fill=(0, 0, 0, 110),
    )
    art = Image.alpha_composite(art.convert('RGBA'), shadow.filter(ImageFilter.GaussianBlur(8))).convert('RGB')
    draw = ImageDraw.Draw(art)
    rounded_rect(draw, [bx0, by0, bx1, by1], 16, ACCENT)
    draw.text((bx0 + 24, by0 + 13), btn_text, font=f_btn, fill=WHITE)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    art.save(out_path, 'JPEG', quality=92, optimize=True, progressive=True)
    print(f'banner: {out_path} ({out_path.stat().st_size // 1024} KB) '
          f'versi={version} build={build_number} tanggal={tanggal}')


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--version', default='')
    ap.add_argument('--build', default='')
    ap.add_argument('--out', required=True)
    ap.add_argument(
        '--generic',
        action='store_true',
        help='Tanpa versi/tanggal — untuk banner in-app yang dibundel di APK.',
    )
    a = ap.parse_args()
    if not a.generic and (not a.version or not a.build):
        ap.error('--version dan --build wajib kecuali --generic')
    build(a.version, a.build, Path(a.out), generic=a.generic)

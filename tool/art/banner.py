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
LOGO = ROOT / 'assets' / 'img' / 'logo.png'
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

    f_brand = font('Inter-Bold.ttf', 31)
    f_sub = font('Inter-SemiBold.ttf', 15)
    f_head = font('Inter-Bold.ttf', 92)
    f_ver = font('Inter-SemiBold.ttf', 31)
    f_meta = font('Inter-Medium.ttf', 19)
    f_desc = font('Inter-Regular.ttf', 18)

    y = 66

    # ── Brand lockup: logo ASLI XyDesk (assets/img/logo.png, alpha) ──
    logo_size = 52
    lx, ly = MARGIN_X, y - 8
    logo_img = Image.open(LOGO).convert('RGBA')
    logo_img.thumbnail((logo_size, logo_size), Image.LANCZOS)
    art = art.convert('RGBA')
    # pusatkan vertikal di kotak logo_size
    ox = lx + (logo_size - logo_img.width) // 2
    oy = ly + (logo_size - logo_img.height) // 2
    art.alpha_composite(logo_img, (ox, oy))
    art = art.convert('RGB')
    draw = ImageDraw.Draw(art)

    draw.text((lx + logo_size + 16, y - 5), 'XYDESK', font=f_brand, fill=WHITE)
    draw.text(
        (lx + logo_size + 16, y + 29),
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
        y += 122
        draw.text(
            (MARGIN_X, y),
            'Versi baru sudah tersedia',
            font=f_ver,
            fill=LAVENDER,
        )
        y += 50
    else:
        y += 122
        ver_label = f'Versi {version}'
        draw.text((MARGIN_X, y), ver_label, font=f_ver, fill=LAVENDER)
        vw = text_w(draw, ver_label, f_ver)
        # chip build number
        chip_x = MARGIN_X + vw + 16
        chip_text = f'build {build_number}'
        cw = text_w(draw, chip_text, f_meta)
        rounded_rect(draw, [chip_x, y + 3, chip_x + cw + 22, y + 33], 15, (34, 28, 58))
        draw.text((chip_x + 11, y + 7), chip_text, font=f_meta, fill=ACCENT_HI)

        y += 50
        bulan = [
            'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
            'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
        ]
        now = datetime.datetime.now(datetime.timezone.utc)
        tanggal = f'{now.day} {bulan[now.month - 1]} {now.year}'
        draw.text(
            (MARGIN_X, y),
            f'Dirilis {tanggal}',
            font=f_meta,
            fill=MUTED,
        )

    # ── Penjelasan (tanpa tombol — notifikasi bukan tempat CTA palsu) ──
    y += 40
    desc_lines = [
        'Buka XyDesk untuk melihat detail pembaruan.',
        'APK resmi diverifikasi otomatis sebelum dipasang.',
    ]
    for line in desc_lines:
        draw.text((MARGIN_X, y), line, font=f_desc, fill=MUTED)
        y += 28

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

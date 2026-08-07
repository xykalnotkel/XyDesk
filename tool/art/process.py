#!/usr/bin/env python3
"""
Pipeline aset XyDesk.

1. Hapus background putih -> alpha transparan (flood-fill dari tepi, supaya
   bagian putih DI DALAM gambar tidak ikut terhapus).
2. Rapikan tepi (buang halo abu).
3. Potong margin kosong, beri padding proporsional.
4. Ekspor PNG (logo, butuh presisi) + WebP (ilustrasi, jauh lebih ringan).
"""
from collections import deque
from pathlib import Path

from PIL import Image

RAW = Path(__file__).parent / 'raw'
OUT = Path(__file__).parent / 'out'


def remove_white_bg(img: Image.Image, tol: int = 26) -> Image.Image:
    """Flood-fill dari tepi. Putih yang terkurung (mis. layar monitor di
    tengah logo) sengaja dibiarkan agar tidak ikut hilang."""
    img = img.convert('RGBA')
    w, h = img.size
    px = img.load()

    def is_bg(x, y):
        r, g, b, a = px[x, y]
        return a > 0 and r >= 255 - tol and g >= 255 - tol and b >= 255 - tol

    seen = bytearray(w * h)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if is_bg(x, y) and not seen[y * w + x]:
                seen[y * w + x] = 1
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if is_bg(x, y) and not seen[y * w + x]:
                seen[y * w + x] = 1
                q.append((x, y))

    while q:
        x, y = q.popleft()
        px[x, y] = (255, 255, 255, 0)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx]:
                if is_bg(nx, ny):
                    seen[ny * w + nx] = 1
                    q.append((nx, ny))
    return img


def clean_edges(img: Image.Image) -> Image.Image:
    """Piksel nyaris-putih di tepi dibuat semi-transparan agar tidak ada
    garis halo saat ditaruh di latar gelap."""
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            lum = (r * 299 + g * 587 + b * 114) // 1000
            if lum > 238:
                px[x, y] = (r, g, b, int(a * max(0.0, (255 - lum) / 17)))
    return img


def trim_and_pad(img: Image.Image, pad_ratio: float = 0.10) -> Image.Image:
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    w, h = img.size
    side = max(w, h)
    pad = int(side * pad_ratio)
    canvas = Image.new('RGBA', (side + pad * 2, side + pad * 2), (0, 0, 0, 0))
    canvas.paste(img, ((canvas.width - w) // 2, (canvas.height - h) // 2), img)
    return canvas


def save_all(img, name, sizes, webp=True):
    OUT.mkdir(parents=True, exist_ok=True)
    made = []
    for s in sizes:
        im = img.resize((s, s), Image.LANCZOS)
        p = OUT / f'{name}_{s}.png'
        im.save(p, 'PNG', optimize=True)
        made.append(p)
        if webp:
            pw = OUT / f'{name}_{s}.webp'
            im.save(pw, 'WEBP', quality=92, method=6)
            made.append(pw)
    return made


JOBS = [
    ('logo_v3.png', 'logo', [1024, 512, 192, 96, 48]),
    ('pc_online.png', 'pc_online', [384]),
    ('pc_offline.png', 'pc_offline', [384]),
    ('il_auth.png', 'il_auth', [512]),
    ('il_settings.png', 'il_settings', [512]),
    ('il_screen.png', 'il_screen', [512]),
]


def main():
    for src, name, sizes in JOBS:
        p = RAW / src
        if not p.exists():
            print(f'  ! lewati {src}')
            continue
        img = Image.open(p)
        img = remove_white_bg(img)
        img = clean_edges(img)
        img = trim_and_pad(img)
        files = save_all(img, name, sizes)
        total = sum(f.stat().st_size for f in files)
        print(f'  {name:14} {len(files):2} berkas  {total / 1024:7.1f} KB')


if __name__ == '__main__':
    main()

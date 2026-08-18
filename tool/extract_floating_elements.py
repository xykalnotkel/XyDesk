#!/usr/bin/env python3
"""Ekstrak elemen 3D kiriman owner menjadi WebP transparan untuk hero web."""
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
UPLOADS = ROOT.parent / "uploads"
OUT = ROOT / "web" / "public"

# Crop dibuat longgar; trim alpha setelah remove-background menentukan batas akhir.
JOBS = [
    ("elemen-xydesk-collection.png", "cursor", (35, 590, 315, 860)),
    ("elemen-xydesk-collection.png", "rocket", (365, 570, 700, 840)),
    ("elemen-xydesk-collection.png", "cloud", (730, 290, 1065, 575)),
    ("elemen-xydesk-collection.png", "wifi", (1135, 275, 1530, 575)),
    ("3d-elemen-glossy.png", "vr", (10, 55, 405, 485)),
    ("3d-elemen-glossy.png", "headphones", (355, 500, 790, 1015)),
    ("3d-elemen-glossy.png", "remote", (15, 480, 350, 1005)),
    ("3d-elemen-glossy.png", "joystick", (1080, 500, 1525, 1015)),
]


def remove_connected_white(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    width, height = image.size
    pixels = image.load()
    seen = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def background(x: int, y: int) -> bool:
        red, green, blue, _ = pixels[x, y]
        return min(red, green, blue) >= 240 and max(red, green, blue) - min(
            red, green, blue
        ) <= 24

    for x in range(width):
        for y in (0, height - 1):
            if background(x, y):
                seen[y * width + x] = 1
                queue.append((x, y))
    for y in range(height):
        for x in (0, width - 1):
            if background(x, y) and not seen[y * width + x]:
                seen[y * width + x] = 1
                queue.append((x, y))

    while queue:
        x, y = queue.popleft()
        pixels[x, y] = (0, 0, 0, 0)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if (
                0 <= nx < width
                and 0 <= ny < height
                and not seen[ny * width + nx]
                and background(nx, ny)
            ):
                seen[ny * width + nx] = 1
                queue.append((nx, ny))

    # Lunakkan hanya matte putih yang menempel langsung ke alpha transparan.
    for _ in range(2):
        updates = []
        for y in range(1, height - 1):
            for x in range(1, width - 1):
                red, green, blue, alpha = pixels[x, y]
                if alpha == 0 or min(red, green, blue) < 170:
                    continue
                if max(red, green, blue) - min(red, green, blue) > 34:
                    continue
                touches_alpha = any(
                    pixels[x + dx, y + dy][3] == 0
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                )
                if not touches_alpha:
                    continue
                luminance = (red + green + blue) / 3
                new_alpha = max(0, min(alpha, int((240 - luminance) / 58 * 255)))
                if new_alpha < alpha:
                    updates.append((x, y, red, green, blue, new_alpha))
        for update in updates:
            x, y, red, green, blue, alpha = update
            pixels[x, y] = (red, green, blue, alpha)
    return image


def keep_largest_component(image: Image.Image) -> Image.Image:
    """Buang drop-shadow putih dan serpihan crop yang tidak menyatu ke objek."""
    width, height = image.size
    alpha = image.getchannel("A")
    source = alpha.load()
    visited = bytearray(width * height)
    components: list[list[tuple[int, int]]] = []
    for start_y in range(height):
        for start_x in range(width):
            index = start_y * width + start_x
            if visited[index] or source[start_x, start_y] < 12:
                continue
            visited[index] = 1
            queue = deque([(start_x, start_y)])
            component: list[tuple[int, int]] = []
            while queue:
                x, y = queue.popleft()
                component.append((x, y))
                for dx, dy in (
                    (1, 0),
                    (-1, 0),
                    (0, 1),
                    (0, -1),
                    (1, 1),
                    (-1, -1),
                    (1, -1),
                    (-1, 1),
                ):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < width and 0 <= ny < height):
                        continue
                    next_index = ny * width + nx
                    if visited[next_index] or source[nx, ny] < 12:
                        continue
                    visited[next_index] = 1
                    queue.append((nx, ny))
            components.append(component)
    if not components:
        return image
    keep = set(max(components, key=len))
    pixels = image.load()
    for y in range(height):
        for x in range(width):
            if (x, y) not in keep:
                pixels[x, y] = (0, 0, 0, 0)
    return image


def export(source: Path, name: str, crop: tuple[int, int, int, int]) -> None:
    image = Image.open(source).crop(crop)
    image = remove_connected_white(image)
    if name in {"rocket", "vr", "headphones", "remote", "joystick"}:
        image = keep_largest_component(image)
    if name in {"vr", "headphones", "remote", "joystick"}:
        pixels = image.load()
        width, height = image.size
        for y in range(int(height * 0.68), height):
            for x in range(width):
                red, green, blue, alpha = pixels[x, y]
                if (
                    alpha > 0
                    and min(red, green, blue) > 225
                    and max(red, green, blue) - min(red, green, blue) < 24
                ):
                    pixels[x, y] = (red, green, blue, 0)
    bounds = image.getbbox()
    if bounds is None:
        raise RuntimeError(f"{name}: hasil crop kosong")
    image = image.crop(bounds)
    side = max(image.size)
    padding = max(14, int(side * 0.07))
    canvas = Image.new("RGBA", (side + padding * 2, side + padding * 2))
    canvas.alpha_composite(
        image,
        ((canvas.width - image.width) // 2, (canvas.height - image.height) // 2),
    )
    canvas.thumbnail((560, 560), Image.Resampling.LANCZOS)
    destination = OUT / f"float-{name}.webp"
    canvas.save(destination, "WEBP", quality=90, method=6)
    print(f"OK {destination.name:24} {canvas.width}x{canvas.height}")


def main() -> None:
    for filename, name, crop in JOBS:
        export(UPLOADS / filename, name, crop)


if __name__ == "__main__":
    main()

"""P3 VFX decals: boot prints, blood, chain scrape, wet ice (own textures)."""
from __future__ import annotations

import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parents[1] / "materials" / "textures"


def footprints() -> None:
    size = 512
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(image, "RGBA")
    # A single boot sole, transparent edges; decals can be rotated/scaled.
    cx, cy = size // 2, size // 2
    d.rounded_rectangle((cx - 52, cy - 150, cx + 52, cy + 150), radius=48,
                        fill=(32, 38, 46, 220), outline=(18, 22, 28, 245), width=8)
    # tread blocks
    for i in range(7):
        y = cy - 115 + i * 38
        d.rounded_rectangle((cx - 43, y, cx + 43, y + 18), radius=8, fill=(12, 16, 22, 235))
    d.ellipse((cx - 46, cy + 100, cx + 46, cy + 145), fill=(15, 19, 25, 220))
    image = image.filter(ImageFilter.GaussianBlur(0.7))
    image.save(OUT / "p3_footprint.png")


def blood() -> None:
    rng = random.Random(31)
    size = 512
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(image, "RGBA")
    for _ in range(18):
        cx = rng.uniform(80, 432)
        cy = rng.uniform(80, 432)
        rx = rng.uniform(18, 85)
        ry = rng.uniform(10, 45)
        d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=(72, 8, 7, rng.randint(120, 215)))
    for _ in range(14):
        x = rng.uniform(60, 450)
        y = rng.uniform(90, 430)
        length = rng.uniform(25, 150)
        angle = rng.uniform(-0.5, 0.5)
        d.line((x, y, x + length, y + angle * length), fill=(62, 6, 5, rng.randint(90, 180)),
               width=rng.choice((2, 3, 5)))
    image = image.filter(ImageFilter.GaussianBlur(1.8))
    image.save(OUT / "p3_blood.png")


def chain_scrape() -> None:
    rng = random.Random(9)
    size = 512
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(image, "RGBA")
    for _ in range(28):
        x = rng.uniform(40, 470)
        y = rng.uniform(40, 470)
        ln = rng.uniform(20, 110)
        d.line((x, y, x + ln, y + rng.uniform(-16, 16)), fill=(52, 58, 66, rng.randint(90, 180)), width=2)
    for _ in range(10):
        x = rng.uniform(100, 400)
        y = rng.uniform(100, 400)
        d.ellipse((x - 9, y - 6, x + 9, y + 6), fill=(70, 76, 84, 130), outline=(22, 26, 32, 170), width=2)
    image = image.filter(ImageFilter.GaussianBlur(0.5))
    image.save(OUT / "p3_chain_scrape.png")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    footprints()
    blood()
    chain_scrape()
    print("P3 decals written to", OUT)


if __name__ == "__main__":
    main()

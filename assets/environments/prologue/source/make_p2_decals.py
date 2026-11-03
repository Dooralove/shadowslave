"""Generate P2 wet-floor and scratch decals (own textures, no external source)."""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parents[1] / "materials" / "textures"


def wet_stain(size=1024, seed=7) -> Image.Image:
    rng = random.Random(seed)
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image, "RGBA")
    for _ in range(34):
        cx = rng.uniform(size * 0.12, size * 0.88)
        cy = rng.uniform(size * 0.12, size * 0.88)
        rx = rng.uniform(size * 0.04, size * 0.22)
        ry = rng.uniform(size * 0.03, size * 0.16)
        alpha = rng.randint(35, 110)
        color = (rng.randint(42, 66), rng.randint(52, 78), rng.randint(60, 92), alpha)
        draw.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=color)
    for _ in range(12):
        x = rng.uniform(0, size)
        width = rng.randint(3, 22)
        draw.line((x, 0, x + rng.uniform(-80, 80), size), fill=(45, 55, 68, rng.randint(20, 60)), width=width)
    image = image.filter(ImageFilter.GaussianBlur(18))
    # Keep some crisp dark puddle edges.
    edge = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ed = ImageDraw.Draw(edge, "RGBA")
    for _ in range(16):
        cx = rng.uniform(0, size)
        cy = rng.uniform(0, size)
        rx = rng.uniform(30, 120)
        ry = rng.uniform(20, 80)
        ed.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), outline=(20, 25, 32, 40), width=3)
    return Image.alpha_composite(image, edge)


def scratches(size=1024, seed=11) -> Image.Image:
    rng = random.Random(seed)
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image, "RGBA")
    for _ in range(90):
        x = rng.uniform(0, size)
        y = rng.uniform(0, size)
        length = rng.uniform(20, 240)
        angle = rng.uniform(-0.7, 0.7) + (math.pi if rng.random() < 0.15 else 0)
        x2 = x + math.cos(angle) * length
        y2 = y + math.sin(angle) * length
        c = rng.randint(90, 170)
        draw.line((x, y, x2, y2), fill=(c, c, c, rng.randint(18, 65)), width=rng.choice((1, 1, 2)))
    for _ in range(14):
        cx = rng.uniform(0, size)
        cy = rng.uniform(0, size)
        r = rng.uniform(20, 80)
        draw.arc((cx - r, cy - r, cx + r, cy + r), rng.uniform(0, 6), rng.uniform(0, 6), fill=(150, 150, 150, 35), width=1)
    return image.filter(ImageFilter.GaussianBlur(0.4))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    wet_stain().save(OUT / "p2_wet_stain.png")
    scratches().save(OUT / "p2_scratch.png")
    print(OUT / "p2_wet_stain.png")
    print(OUT / "p2_scratch.png")


if __name__ == "__main__":
    main()

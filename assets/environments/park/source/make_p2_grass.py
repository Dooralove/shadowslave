"""Generate a tileable-ish P2 park lawn albedo (own texture, deterministic)."""
from __future__ import annotations

import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parents[1] / "materials" / "textures"
SIZE = 1024


def noise_layer(rng, scale):
    small = rng.random((scale, scale)).astype(np.float32)
    image = Image.fromarray((small * 255).astype(np.uint8), "L").resize((SIZE, SIZE), Image.Resampling.BICUBIC)
    return np.asarray(image, dtype=np.float32) / 255.0


def main() -> None:
    rng = np.random.default_rng(20261102)
    height = (noise_layer(rng, 8) * 0.55 + noise_layer(rng, 24) * 0.25 + noise_layer(rng, 64) * 0.20)
    # Park lawn: muted cold green with dry/brown patches.
    base = np.zeros((SIZE, SIZE, 3), dtype=np.float32)
    base[..., 0] = 0.075 + height * 0.12
    base[..., 1] = 0.13 + height * 0.24
    base[..., 2] = 0.075 + height * 0.10
    dry = noise_layer(rng, 12)
    base[..., 0] += dry * 0.10
    base[..., 1] += dry * 0.06
    base[..., 2] += dry * 0.02
    image = Image.fromarray(np.clip(base * 255, 0, 255).astype(np.uint8), "RGB")
    draw = ImageDraw.Draw(image, "RGBA")
    prng = random.Random(77)
    for _ in range(4000):
        x = prng.uniform(0, SIZE)
        y = prng.uniform(0, SIZE)
        ln = prng.uniform(4, 22)
        angle = prng.uniform(-0.5, 0.5)
        color = (prng.randint(36, 76), prng.randint(58, 104), prng.randint(34, 70), prng.randint(20, 65))
        draw.line((x, y, x + math.cos(angle) * ln, y + math.sin(angle) * ln), fill=color, width=1)
    image = image.filter(ImageFilter.GaussianBlur(0.5))
    # Blend the edges for tiling.
    arr = np.asarray(image).astype(np.float32)
    for i in range(SIZE):
        t = i / SIZE
        arr[:, i] = arr[:, i] * (1 - t) + arr[:, (i + SIZE // 2) % SIZE] * t * 0.08
    image = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
    OUT.mkdir(parents=True, exist_ok=True)
    image.save(OUT / "p2_grass_diff_1k.jpg", quality=90)
    print(OUT / "p2_grass_diff_1k.jpg")


if __name__ == "__main__":
    main()

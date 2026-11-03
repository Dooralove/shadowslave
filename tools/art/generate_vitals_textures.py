"""Generate tiling HUD textures for the coral vitals bar.

These are deterministic CLI-generated assets: no external textures, no AI
backend. The frame and medallion are rendered from Hyper3D reliefs; these maps
provide the fill, plate, glow, notch and gloss layers.

Usage:
  python tools/art/generate_vitals_textures.py --out assets/ui/vitals
"""

from __future__ import annotations

import argparse
import math
import os
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


def periodic_noise(width: int, height: int, components: int, seed: int) -> np.ndarray:
    """Smooth periodic value noise in [0, 1] with seamless edges."""
    rng = np.random.default_rng(seed)
    x = np.linspace(0.0, 1.0, width, endpoint=False, dtype=np.float64)
    y = np.linspace(0.0, 1.0, height, endpoint=False, dtype=np.float64)
    field = np.zeros((height, width), dtype=np.float64)
    for _ in range(components):
        kx = int(rng.integers(1, 9))
        ky = int(rng.integers(1, 6))
        amplitude = 1.0 / (kx * kx + ky * ky) ** 0.72
        phase = float(rng.uniform(0.0, math.tau))
        field += amplitude * np.sin(math.tau * (kx * x[None, :] + ky * y[:, None]) + phase)
    field -= field.min()
    field /= max(field.max(), 1e-6)
    return field


def make_veins(width: int, height: int, seed: int, count: int, strength: float) -> np.ndarray:
    """Wrapped, soft organic veins for a horizontally tiling strip."""
    rng = np.random.default_rng(seed)
    yy = np.arange(height, dtype=np.float64)[:, None]
    vein = np.zeros((height, width), dtype=np.float64)
    for index in range(count):
        base = float(rng.uniform(height * 0.12, height * 0.88))
        amp = float(rng.uniform(2.0, height * 0.10))
        freq = float(rng.uniform(0.6, 2.4))
        phase = float(rng.uniform(0.0, math.tau))
        thickness = float(rng.uniform(0.7, 1.8))
        for x in range(width):
            t = x / float(width)
            center = base + amp * math.sin(math.tau * freq * t + phase)
            center += amp * 0.35 * math.sin(math.tau * (freq * 2.0) * t + phase * 1.7)
            dist = np.abs(yy[:, 0] - center)
            dist = np.minimum(dist, height - dist)
            vein[:, x] = np.maximum(vein[:, x], np.exp(-(dist / thickness) ** 2) * strength)
    return np.clip(vein, 0.0, 1.0)


def make_pores(width: int, height: int, seed: int, count: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    pores = np.zeros((height, width), dtype=np.float64)
    for _ in range(count):
        x = float(rng.uniform(0.0, width))
        y = float(rng.uniform(0.0, height))
        radius = float(rng.uniform(0.5, 2.2))
        strength = float(rng.uniform(0.25, 0.9))
        for dx in (-width, 0, width):
            for dy in (-height, 0, height):
                cx = x + dx
                cy = y + dy
                x0 = max(0, int(math.floor(cx - radius * 3)))
                x1 = min(width, int(math.ceil(cx + radius * 3)) + 1)
                y0 = max(0, int(math.floor(cy - radius * 3)))
                y1 = min(height, int(math.ceil(cy + radius * 3)) + 1)
                if x0 >= x1 or y0 >= y1:
                    continue
                gx = np.arange(x0, x1, dtype=np.float64)[None, :] - cx
                gy = np.arange(y0, y1, dtype=np.float64)[:, None] - cy
                spot = np.exp(-((gx * gx + gy * gy) / (radius * radius)))
                pores[y0:y1, x0:x1] = np.maximum(pores[y0:y1, x0:x1], spot * strength)
    return np.clip(pores, 0.0, 1.0)


def gradient(width: int, height: int, top: np.ndarray, bottom: np.ndarray) -> np.ndarray:
    t = np.linspace(0.0, 1.0, height, dtype=np.float64)[:, None, None]
    return top[None, None, :] * (1.0 - t) + bottom[None, None, :] * t


def to_image(array: np.ndarray, alpha: np.ndarray | None = None) -> Image.Image:
    rgb = np.clip(array * 255.0, 0.0, 255.0).astype(np.uint8)
    if alpha is None:
        return Image.fromarray(rgb, "RGB")
    a = np.clip(alpha * 255.0, 0.0, 255.0).astype(np.uint8)
    return Image.fromarray(np.dstack([rgb, a]), "RGBA")


def make_fill(width: int = 1024, height: int = 128) -> Image.Image:
    noise = periodic_noise(width, height, 56, 1101)
    fine = periodic_noise(width, height, 90, 1102)
    veins = make_veins(width, height, 1103, 9, 0.9)
    pores = make_pores(width, height, 1104, 90)
    grain = np.clip(noise * 0.7 + fine * 0.3, 0.0, 1.0)

    dark = np.array([0.28, 0.29, 0.30])
    mid = np.array([0.60, 0.61, 0.62])
    light = np.array([0.88, 0.88, 0.86])
    base = dark[None, None, :] * (1.0 - grain[..., None]) + mid[None, None, :] * grain[..., None]
    base = base * (1.0 - 0.45 * veins[..., None]) + light[None, None, :] * (0.45 * veins[..., None])
    bone = np.array([0.95, 0.94, 0.89])
    base = base * (1.0 - 0.38 * veins[..., None]) + bone[None, None, :] * (0.38 * veins[..., None])
    base *= (1.0 - 0.55 * pores[..., None])
    base *= gradient(width, height, np.array([1.12, 1.12, 1.10]), np.array([0.80, 0.80, 0.82]))
    # A faint cool rim at the top; tinting in-engine supplies the final hue.
    base += np.array([0.0, 0.025, 0.045])[None, None, :] * (1.0 - np.linspace(0, 1, height))[:, None, None]
    return to_image(np.clip(base, 0.0, 1.0))


def make_plate(width: int = 1024, height: int = 256) -> Image.Image:
    noise = periodic_noise(width, height, 48, 2201)
    fine = periodic_noise(width, height, 80, 2202)
    veins = make_veins(width, height, 2203, 5, 0.45)
    pores = make_pores(width, height, 2204, 140)
    grain = np.clip(noise * 0.65 + fine * 0.35, 0.0, 1.0)

    dark = np.array([0.035, 0.045, 0.060])
    mid = np.array([0.075, 0.078, 0.090])
    cold = np.array([0.10, 0.13, 0.17])
    base = dark[None, None, :] * (1.0 - grain[..., None]) + mid[None, None, :] * grain[..., None]
    base = base * (1.0 - 0.25 * veins[..., None]) + cold[None, None, :] * (0.25 * veins[..., None])
    base *= (1.0 - 0.35 * pores[..., None])
    # Sediment bands, wrapped by construction.
    band = 0.05 * np.sin(math.tau * 3.0 * np.linspace(0, 1, height))[:, None, None]
    base += band
    base *= gradient(width, height, np.array([1.05, 1.04, 1.03]), np.array([0.72, 0.74, 0.78]))
    return to_image(np.clip(base, 0.0, 1.0))


def make_glow(size: int = 512) -> Image.Image:
    yy, xx = np.mgrid[0:size, 0:size]
    cx = (size - 1) * 0.5
    cy = (size - 1) * 0.5
    r = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / (size * 0.5)
    core = np.exp(-(r / 0.22) ** 2)
    halo = np.exp(-(r / 0.62) ** 2) * 0.55
    alpha = np.clip(core + halo, 0.0, 1.0)
    color = np.zeros((size, size, 3), dtype=np.float64)
    color += np.array([0.55, 0.82, 1.00])[None, None, :] * core[..., None] * 0.75
    color += np.array([0.95, 0.80, 0.58])[None, None, :] * halo[..., None] * 0.35
    rgb = np.clip(color, 0.0, 1.0)
    return to_image(rgb, alpha)


def make_shine(width: int = 1024, height: int = 128) -> Image.Image:
    yy, xx = np.mgrid[0:height, 0:width]
    x = xx / float(width)
    # Diagonal soft band, wrapped horizontally.
    center = 0.28 + 0.10 * (yy / float(height))
    dist = np.abs(((x - center + 0.5) % 1.0) - 0.5)
    alpha = np.exp(-(dist / 0.075) ** 2) * 0.55
    alpha *= np.sin(np.pi * yy / float(height)) ** 0.7
    rgb = np.ones((height, width, 3), dtype=np.float64) * np.array([0.92, 0.90, 0.82])[None, None, :]
    return to_image(rgb, np.clip(alpha, 0.0, 1.0))


def make_notch(width: int = 64, height: int = 128) -> Image.Image:
    scale = 4
    w = width * scale
    h = height * scale
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx = w * 0.5
    top = h * 0.06
    bottom = h * 0.94
    # Bone pin silhouette: tapered shaft with two rounded collars.
    shaft_w = w * 0.18
    collar_w = w * 0.38
    collar_h = h * 0.10
    outline = (28, 24, 20, 235)
    bone_dark = (122, 112, 96, 255)
    bone = (196, 184, 162, 255)
    bone_light = (232, 221, 198, 255)
    outline_w = max(1, int(round(scale * 1.2)))
    draw.rounded_rectangle((cx - collar_w / 2, top, cx + collar_w / 2, top + collar_h), radius=collar_h * 0.45, fill=bone_dark, outline=outline, width=outline_w)
    draw.rounded_rectangle((cx - shaft_w / 2, top + collar_h * 0.55, cx + shaft_w / 2, bottom - collar_h * 0.55), radius=shaft_w * 0.45, fill=bone, outline=outline, width=outline_w)
    draw.rounded_rectangle((cx - collar_w / 2, bottom - collar_h, cx + collar_w / 2, bottom), radius=collar_h * 0.45, fill=bone_dark, outline=outline, width=outline_w)
    # Bevel highlights.
    draw.line((cx - shaft_w * 0.20, top + collar_h * 1.1, cx - shaft_w * 0.20, bottom - collar_h * 1.1), fill=bone_light, width=max(1, int(round(scale * 0.7))))
    draw.line((cx + shaft_w * 0.22, top + collar_h * 1.1, cx + shaft_w * 0.22, bottom - collar_h * 1.1), fill=(95, 86, 74, 180), width=max(1, int(round(scale * 0.5))))
    # Central coral inlay.
    draw.ellipse((cx - w * 0.10, h * 0.42, cx + w * 0.10, h * 0.58), fill=(112, 38, 42, 255), outline=(52, 22, 24, 230), width=scale)
    draw.ellipse((cx - w * 0.045, h * 0.46, cx + w * 0.01, h * 0.51), fill=(190, 96, 82, 190))
    img = img.resize((width, height), Image.Resampling.LANCZOS)
    return img


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="assets/ui/vitals")
    args = parser.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    make_fill().save(out / "hp_fill.png", optimize=True)
    make_plate().save(out / "hp_plate.png", optimize=True)
    make_glow().save(out / "hp_glow.png", optimize=True)
    make_shine().save(out / "hp_shine.png", optimize=True)
    make_notch().save(out / "hp_notch.png", optimize=True)
    print(f"WROTE {out / 'hp_fill.png'}")
    print(f"WROTE {out / 'hp_plate.png'}")
    print(f"WROTE {out / 'hp_glow.png'}")
    print(f"WROTE {out / 'hp_shine.png'}")
    print(f"WROTE {out / 'hp_notch.png'}")


if __name__ == "__main__":
    main()

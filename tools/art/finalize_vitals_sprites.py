"""Trim and downscale rendered UI props into game-ready sprites.

Usage:
  python tools/art/finalize_vitals_sprites.py
"""

from pathlib import Path

import cv2
import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "ui" / "vitals" / "source"
OUT = ROOT / "assets" / "ui" / "vitals"


def recolor_coral(image: Image.Image) -> Image.Image:
    """Shift the generator's pink coral toward the project's dark crimson."""
    image = image.convert("RGBA")
    rgb = np.asarray(image, dtype=np.float32)[:, :, :3] / 255.0
    alpha = np.asarray(image, dtype=np.uint8)[:, :, 3]
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    hue = hsv[:, :, 0]
    sat = hsv[:, :, 1]
    val = hsv[:, :, 2]
    mask = (((hue > 320) | (hue < 10)) & (sat > 0.34) & (val > 0.12))
    hue[mask] = 354.0
    sat[mask] = np.clip(sat[mask] * 0.86, 0.0, 1.0)
    val[mask] = np.clip(val[mask] * 0.60, 0.0, 1.0)
    out = cv2.cvtColor(hsv, cv2.COLOR_HSV2RGB)
    out = np.clip(out * 255.0, 0.0, 255.0).astype(np.uint8)
    return Image.fromarray(np.dstack([out, alpha]), "RGBA")


def trim_alpha(image: Image.Image, padding: int = 4) -> Image.Image:
    image = image.convert("RGBA")
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return image
    left, top, right, bottom = bbox
    left = max(0, left - padding)
    top = max(0, top - padding)
    right = min(image.width, right + padding)
    bottom = min(image.height, bottom + padding)
    return image.crop((left, top, right, bottom))


def resize_width(image: Image.Image, width: int) -> Image.Image:
    height = max(1, round(image.height * width / image.width))
    return image.resize((width, height), Image.Resampling.LANCZOS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    frame = trim_alpha(Image.open(SRC / "hp_frame_wide_render.png"))
    frame = resize_width(recolor_coral(frame), 1536)
    frame.save(OUT / "hp_frame.png", optimize=True)
    print(f"WROTE {OUT / 'hp_frame.png'} {frame.size}")

    medallion = trim_alpha(Image.open(SRC / "hp_medallion_render.png"), padding=6)
    medallion = recolor_coral(medallion).resize((512, 512), Image.Resampling.LANCZOS)
    medallion.save(OUT / "hp_medallion.png", optimize=True)
    print(f"WROTE {OUT / 'hp_medallion.png'} {medallion.size}")


if __name__ == "__main__":
    main()

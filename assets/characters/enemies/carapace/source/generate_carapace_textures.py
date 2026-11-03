"""Generate tileable PBR textures for the Carapace Scavenger.

Project-owned procedural textures: chitin base-color tints, one shared normal map
and one shared ORM map. Run from the project root with system Python:

  python assets/characters/enemies/carapace/source/generate_carapace_textures.py
"""
from __future__ import annotations

import os
import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "characters", "enemies", "carapace", "textures")
os.makedirs(OUT, exist_ok=True)
RNG = np.random.default_rng(20261102)


def smooth_noise(size, cells, octaves=4, persistence=0.55):
    """Tileable-ish multi-octave value noise from upscaled random grids."""
    total = np.zeros((size, size), dtype=np.float32)
    amp = 1.0
    norm = 0.0
    for o in range(octaves):
        n = cells * (2 ** o)
        grid = RNG.random((n, n)).astype(np.float32)
        img = Image.fromarray((grid * 255).astype(np.uint8), mode="L")
        img = img.resize((size, size), Image.Resampling.BICUBIC)
        arr = np.asarray(img, dtype=np.float32) / 255.0
        total += arr * amp
        norm += amp
        amp *= persistence
    return total / max(norm, 1e-6)


def voronoi_cracks(size, points=70):
    """Distance-to-edge proxy with a cheap wrapped Euclidean Voronoi."""
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    seeds = RNG.random((points, 2)).astype(np.float32) * size
    d1 = np.full((size, size), 1e9, dtype=np.float32)
    d2 = np.full((size, size), 1e9, dtype=np.float32)
    for sx, sy in seeds:
        dx = np.abs(xx - sx)
        dy = np.abs(yy - sy)
        dx = np.minimum(dx, size - dx)
        dy = np.minimum(dy, size - dy)
        d = np.sqrt(dx * dx + dy * dy)
        nearer = d < d1
        d2 = np.where(nearer, d1, np.minimum(d2, d))
        d1 = np.where(nearer, d, d1)
    edge = d2 - d1
    # Cracks are the narrow boundaries between cells.
    cracks = np.clip(1.0 - edge / 2.4, 0.0, 1.0)
    return cracks


def height_field(size=1024):
    n1 = smooth_noise(size, 8, 5, 0.55)
    n2 = smooth_noise(size, 24, 4, 0.5)
    ridges = 1.0 - np.abs(smooth_noise(size, 12, 3, 0.5) * 2.0 - 1.0)
    cracks = voronoi_cracks(size, points=90)
    height = 0.58 + 0.16 * n1 + 0.10 * n2 + 0.12 * ridges - 0.42 * cracks
    return np.clip(height, 0.0, 1.0), cracks, n2


def save_png(arr, name):
    a = np.clip(arr * 255.0, 0, 255).astype(np.uint8)
    path = os.path.join(OUT, name)
    Image.fromarray(a, mode="RGB").save(path, optimize=True)
    print("WROTE", path, os.path.getsize(path))


def main():
    size = 1024
    height, cracks, fine = height_field(size)
    # Shared tangent-space normal.
    strength = 7.0
    dx = np.gradient(height, axis=1) * strength
    dy = np.gradient(height, axis=0) * strength
    nz = np.ones_like(height)
    length = np.sqrt(dx * dx + dy * dy + nz * nz)
    normal = np.stack((-dx / length, -dy / length, nz / length), axis=-1)
    normal = normal * 0.5 + 0.5
    save_png(normal, "carapace_normal.png")

    # Shared ORM: R = AO, G = roughness variation, B = metallic.
    ao = np.clip(0.62 + 0.38 * height, 0, 1)
    rough = np.clip(0.70 + 0.22 * fine - 0.12 * cracks, 0, 1)
    orm = np.stack((ao, rough, np.zeros_like(height)), axis=-1)
    save_png(orm, "carapace_orm.png")

    # Detail mask for base-color tints.
    detail = np.clip(0.70 + 0.30 * height - 0.22 * cracks, 0, 1)
    tints = {
        "carapace_base_chitin.png": (0.115, 0.018, 0.024),
        "carapace_base_plate.png": (0.175, 0.032, 0.040),
        "carapace_base_bone.png": (0.62, 0.54, 0.39),
        "carapace_base_dark.png": (0.050, 0.012, 0.016),
        "carapace_base_maw.png": (0.130, 0.016, 0.018),
    }
    for name, color in tints.items():
        tint = np.array(color, dtype=np.float32).reshape(1, 1, 3)
        rgb = detail[..., None] * tint
        save_png(rgb, name)
    print("DONE")


if __name__ == "__main__":
    main()

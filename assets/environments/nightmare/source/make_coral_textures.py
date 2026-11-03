"""Процедурные PBR-текстуры кораллового кита Забытого берега.

Запуск из корня проекта:
    python assets/environments/nightmare/source/make_coral_textures.py

Пишет в assets/environments/nightmare/materials/textures/:
  nm_coral_live_{diff,nor_gl,arm}_2k.jpg
  nm_coral_dead_{diff,nor_gl,arm}_2k.jpg
  nm_coral_crust_{diff,nor_gl,arm}_1k.jpg
  nm_bone_aged_{diff,nor_gl,arm}_1k.jpg

Текстуры бесшовные: низкочастотный шум строится через FFT-фильтр, импульсы пор
размываются с mode="wrap". Нормали — OpenGL (+Y up), ARM — R=AO, G=roughness, B=metallic.
Палитра: docs/art/forgotten-shore-art / forgotten_shore_labyrinth_research.md §9.8.
"""

from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

SRC = Path(__file__).resolve().parent
ROOT = SRC.parents[3]
TEX = ROOT / "assets" / "environments" / "nightmare" / "materials" / "textures"
TEX.mkdir(parents=True, exist_ok=True)


def fft_noise(size: int, sigma: float, seed: int) -> np.ndarray:
    """Периодический гауссов шум: sigma в пикселях, чем больше — тем крупнее пятна."""
    rng = np.random.default_rng(seed)
    white = rng.standard_normal((size, size)).astype(np.float32)
    f = np.fft.fftfreq(size).astype(np.float32)
    fx, fy = np.meshgrid(f, f)
    kernel = np.exp(-2.0 * math.pi**2 * sigma**2 * (fx * fx + fy * fy))
    out = np.real(np.fft.ifft2(np.fft.fft2(white) * kernel))
    out -= out.min()
    out /= max(out.max(), 1e-6)
    return out.astype(np.float32)


def fbm(size: int, layers: list[tuple[float, float]], seed: int) -> np.ndarray:
    acc = np.zeros((size, size), np.float32)
    total = 0.0
    for i, (sigma, amp) in enumerate(layers):
        acc += amp * fft_noise(size, sigma, seed + i * 101)
        total += amp
    return acc / total


def pits(size: int, count: int, sigma: float, seed: int) -> np.ndarray:
    """Мелкие поры/раковины: импульсы, размытые с заворотом, чтобы шов не читался."""
    rng = np.random.default_rng(seed)
    img = np.zeros((size, size), np.float32)
    xs = rng.integers(0, size, count)
    ys = rng.integers(0, size, count)
    vals = rng.uniform(0.4, 1.0, count).astype(np.float32)
    img[ys, xs] = vals
    img = gaussian_filter(img, sigma=sigma, mode="wrap")
    img -= img.min()
    img /= max(img.max(), 1e-6)
    return img


def smoothstep(a: float, b: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - a) / max(b - a, 1e-6), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def normal_from_height(h: np.ndarray, strength: float) -> np.ndarray:
    h = gaussian_filter(h, 1.1, mode="wrap")
    dx = np.gradient(h, axis=1)
    dy = np.gradient(h, axis=0)
    nx = -dx * strength
    ny = dy * strength
    nz = np.ones_like(nx)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.stack((nx / ln, ny / ln, nz / ln), axis=-1)
    return np.clip(n * 0.5 + 0.5, 0.0, 1.0)


def ao_from_height(h: np.ndarray, sigma: float = 12.0, strength: float = 0.85) -> np.ndarray:
    blur = gaussian_filter(h, sigma=sigma, mode="wrap")
    cav = np.clip(blur - h, 0.0, None)
    cav /= max(np.percentile(cav, 99.0), 1e-6)
    ao = 1.0 - strength * np.clip(cav, 0.0, 1.0)
    return np.clip(0.55 + 0.45 * ao, 0.0, 1.0)


def to_u8(rgb: np.ndarray) -> np.ndarray:
    return np.clip(rgb * 255.0 + 0.5, 0, 255).astype(np.uint8)


def save_set(name: str, size: int, albedo: np.ndarray, normal: np.ndarray, arm: np.ndarray) -> None:
    Image.fromarray(to_u8(albedo), "RGB").save(
        TEX / f"{name}_diff_{size // 1024}k.jpg", quality=92, subsampling=0, optimize=True)
    Image.fromarray(to_u8(normal), "RGB").save(
        TEX / f"{name}_nor_gl_{size // 1024}k.jpg", quality=95, subsampling=0, optimize=True)
    Image.fromarray(to_u8(arm), "RGB").save(
        TEX / f"{name}_arm_{size // 1024}k.jpg", quality=95, subsampling=0, optimize=True)
    print(f"TEX {name} {size}x{size}")


def coral_fields(size: int, seed: int, dead: bool = False) -> dict[str, np.ndarray]:
    big = fbm(size, [(140.0, 1.0), (60.0, 0.55), (22.0, 0.30), (7.0, 0.14)], seed)
    med = fbm(size, [(30.0, 0.7), (10.0, 0.4), (3.0, 0.2)], seed + 17)
    fine = fbm(size, [(4.0, 0.6), (1.5, 0.4)], seed + 31)
    micro = fbm(size, [(2.2, 0.6), (0.9, 0.4)], seed + 37)
    # Вертикальные, слегка изогнутые рёбра — главный признак коралла.
    x = np.arange(size, dtype=np.float32)[None, :] / size
    phase = fbm(size, [(55.0, 1.0), (18.0, 0.5)], seed + 41)
    ribs = 0.5 + 0.5 * np.sin(2.0 * math.pi * (x * 26.0 + 0.45 * phase))
    ribs = gaussian_filter(ribs, 1.8, mode="wrap")
    pores = pits(size, int(size * size / 2400), max(1.6, size / 950.0), seed + 53)
    # Тонкие прожилки: узкие линии, а не широкие контуры.
    cracks = 1.0 - smoothstep(0.0, 0.022, np.abs(fbm(size, [(50.0, 1.0), (12.0, 0.4)], seed + 67) - 0.5))
    cells = fbm(size, [(8.0, 0.55), (3.5, 0.45)], seed + 81)
    cell_edges = 1.0 - smoothstep(0.0, 0.035, np.abs(cells - 0.5))
    h = 0.40 * big + 0.20 * med + 0.14 * fine + 0.10 * micro + 0.20 * ribs
    h -= 0.16 * pores + 0.08 * cracks + 0.09 * cell_edges
    if dead:
        h += 0.10 * pits(size, int(size * size / 800), max(2.0, size / 700.0), seed + 71)
    h -= h.min()
    h /= max(h.max(), 1e-6)
    return {"h": h.astype(np.float32), "big": big, "med": med, "fine": fine,
            "micro": micro, "ribs": ribs, "pores": pores, "cracks": cracks,
            "cell_edges": cell_edges}


def make_live(size: int = 2048, seed: int = 1701) -> None:
    f = coral_fields(size, seed, dead=False)
    h, big, med, pores, cracks = f["h"], f["big"], f["med"], f["pores"], f["cracks"]
    ribs, cells = f["ribs"], f["cell_edges"]
    dark = np.array([0.290, 0.110, 0.133], np.float32)   # #4a1c22
    light = np.array([0.549, 0.290, 0.290], np.float32)  # #8c4a4a
    tip = np.array([0.720, 0.430, 0.400], np.float32)    # светлые кончики
    base = dark + (light - dark) * smoothstep(0.30, 0.82, big)[..., None]
    base = base + (tip - base) * (smoothstep(0.72, 0.98, h) * 0.55)[..., None]
    base *= (1.0 - 0.24 * cracks)[..., None]
    base *= (1.0 - 0.26 * pores)[..., None]
    base *= (1.0 - 0.18 * cells)[..., None]
    base *= (0.80 + 0.42 * ribs)[..., None]
    base *= (0.88 + 0.24 * med)[..., None]
    albedo = np.clip(base, 0.0, 1.0)
    normal = normal_from_height(h, 10.0)
    rough = 0.40 + 0.26 * (1.0 - h) + 0.10 * med + 0.08 * pores
    arm = np.stack((ao_from_height(h, 12.0, 0.8), np.clip(rough, 0.0, 1.0), np.zeros_like(h)), axis=-1)
    save_set("nm_coral_live", size, albedo, normal, arm)


def make_dead(size: int = 2048, seed: int = 2701) -> None:
    f = coral_fields(size, seed, dead=True)
    h, big, med, pores, cracks = f["h"], f["big"], f["med"], f["pores"], f["cracks"]
    ribs, cells = f["ribs"], f["cell_edges"]
    dark = np.array([0.420, 0.333, 0.314], np.float32)   # #6b5550
    light = np.array([0.720, 0.660, 0.600], np.float32)  # сухая кость/известняк
    pale = np.array([0.820, 0.780, 0.710], np.float32)
    base = dark + (light - dark) * smoothstep(0.25, 0.78, big)[..., None]
    base = base + (pale - base) * (smoothstep(0.70, 0.98, h) * 0.35)[..., None]
    base *= (1.0 - 0.20 * cracks)[..., None]
    base *= (1.0 - 0.30 * pores)[..., None]
    base *= (1.0 - 0.16 * cells)[..., None]
    base *= (0.86 + 0.26 * ribs)[..., None]
    base *= (0.90 + 0.18 * med)[..., None]
    albedo = np.clip(base, 0.0, 1.0)
    normal = normal_from_height(h, 7.0)
    rough = 0.66 + 0.20 * (1.0 - h) + 0.08 * med
    arm = np.stack((ao_from_height(h, 11.0, 0.7), np.clip(rough, 0.0, 1.0), np.zeros_like(h)), axis=-1)
    save_set("nm_coral_dead", size, albedo, normal, arm)


def make_crust(size: int = 1024, seed: int = 3701) -> None:
    f = coral_fields(size, seed, dead=True)
    h, big, med, pores, cracks = f["h"], f["big"], f["med"], f["pores"], f["cracks"]
    ribs, cells = f["ribs"], f["cell_edges"]
    live = np.array([0.290, 0.110, 0.133], np.float32)
    dead = np.array([0.520, 0.440, 0.400], np.float32)
    shell = np.array([0.850, 0.820, 0.760], np.float32)
    base = live + (dead - live) * smoothstep(0.30, 0.70, big)[..., None]
    # Белые пятна ракушек/балянусов.
    barn = smoothstep(0.72, 0.88, pits(size, int(size * size / 2400), 2.3, seed + 5))
    base = base + (shell - base) * (barn * 0.75)[..., None]
    base *= (1.0 - 0.28 * cracks)[..., None]
    base *= (1.0 - 0.35 * pores)[..., None]
    albedo = np.clip(base, 0.0, 1.0)
    normal = normal_from_height(h, 8.0)
    rough = 0.58 + 0.26 * (1.0 - h) + 0.10 * pores
    arm = np.stack((ao_from_height(h, 8.0, 0.8), np.clip(rough, 0.0, 1.0), np.zeros_like(h)), axis=-1)
    save_set("nm_coral_crust", size, albedo, normal, arm)


def make_bone(size: int = 1024, seed: int = 4701) -> None:
    h = fbm(size, [(60.0, 0.8), (18.0, 0.5), (5.0, 0.25)], seed)
    pores = pits(size, int(size * size / 1800), 1.8, seed + 9)
    cracks = 1.0 - smoothstep(0.0, 0.05, np.abs(fbm(size, [(36.0, 1.0), (8.0, 0.5)], seed + 13) - 0.5))
    h = 0.65 * h + 0.20 * pores - 0.22 * cracks
    h -= h.min()
    h /= max(h.max(), 1e-6)
    ivory = np.array([0.847, 0.812, 0.753], np.float32)  # #d8cfc0
    dark = np.array([0.420, 0.333, 0.314], np.float32)
    base = dark + (ivory - dark) * smoothstep(0.15, 0.75, h)[..., None]
    base *= (1.0 - 0.30 * cracks)[..., None]
    base *= (1.0 - 0.20 * pores)[..., None]
    albedo = np.clip(base, 0.0, 1.0)
    normal = normal_from_height(h, 3.2)
    rough = 0.58 + 0.22 * (1.0 - h) + 0.06 * pores
    arm = np.stack((ao_from_height(h, 9.0, 0.65), np.clip(rough, 0.0, 1.0), np.zeros_like(h)), axis=-1)
    save_set("nm_bone_aged", size, albedo, normal, arm)


if __name__ == "__main__":
    make_bone()
    print("DONE", TEX)

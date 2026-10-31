"""Производные текстуры Первого Кошмара (системный Python: numpy + Pillow).

Запуск из корня проекта:
    python assets/environments/nightmare/source/make_nm_textures.py

Источники — CC0-наборы Poly Haven в `materials/textures/` (см. docs/ASSET_LICENSES.md).
Карты нормалей, ARM (AO/шероховатость/металл = ORM Godot) и высоты берутся из наборов
как есть; здесь перекрашивается только альбедо под палитру
`docs/art/mountain_pass_environment_art.md` и генерируется процедурный чёрный мрамор
(канон гл. 14: храм и алтарь — чёрный мрамор; рисунок прожилок — ART-DIRECTION).
Все выходные текстуры бесшовные (исходники бесшовные, мрамор — через FFT/периодические функции).
"""

from pathlib import Path

import numpy as np
from PIL import Image

TEX = Path(__file__).resolve().parents[1] / "materials" / "textures"


def load(name):
    return np.asarray(Image.open(TEX / name).convert("RGB"), dtype=np.float32) / 255.0


def save(arr, name, quality=92):
    img = Image.fromarray(np.clip(arr * 255.0 + 0.5, 0, 255).astype(np.uint8))
    img.save(TEX / name, quality=quality, subsampling=0)
    print("saved", name, img.size, np.round(arr.reshape(-1, arr.shape[-1]).mean(0) * 255).astype(int))


def luminance(rgb):
    return rgb @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)


def hex_rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32) / 255.0


def recolor(src, dark, light, contrast=1.0, keep_chroma=0.0, pivot=None):
    """Перекраска по яркости: нормированная яркость → градиент dark..light (sRGB).

    contrast растягивает отклонения яркости от среднего; keep_chroma оставляет
    долю исходного оттенка (0 — полностью новый тон)."""
    lum = luminance(src)
    mean = lum.mean() if pivot is None else pivot
    std = lum.std() + 1e-6
    t = 0.5 + (lum - mean) / std * 0.18 * contrast
    t = np.clip(t, 0.0, 1.0)[..., None]
    out = dark * (1 - t) + light * t
    if keep_chroma:
        chroma = src - lum[..., None]
        out = out + chroma * keep_chroma
    return np.clip(out, 0, 1)


def fft_noise(size, beta, seed):
    """Бесшовный фрактальный шум 1/f^beta (периодичен по построению)."""
    rng = np.random.default_rng(seed)
    white = rng.standard_normal((size, size))
    f = np.fft.fftfreq(size)
    fx, fy = np.meshgrid(f, f)
    rad = np.sqrt(fx ** 2 + fy ** 2)
    rad[0, 0] = 1.0
    spec = np.fft.fft2(white) / rad ** beta
    spec[0, 0] = 0
    n = np.real(np.fft.ifft2(spec))
    n -= n.mean()
    return n / (n.std() + 1e-9)


def normal_from_height(h, strength):
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5
    nx, ny = -dx * strength, dy * strength  # OpenGL: +Y вверх по изображению
    nz = np.ones_like(h)
    ln = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
    return np.stack([nx / ln, ny / ln, nz / ln], -1) * 0.5 + 0.5


def black_marble(size=2048, seed=14):
    """Чёрный мрамор: почти чёрная масса, редкие тонкие графитовые прожилки, мягкие облака."""
    yy, xx = np.meshgrid(np.arange(size), np.arange(size), indexing="ij")
    u, v = xx / size, yy / size
    warp1 = fft_noise(size, 2.7, seed)
    warp2 = fft_noise(size, 2.4, seed + 1)
    clouds = fft_noise(size, 1.9, seed + 2)
    grain = fft_noise(size, 0.6, seed + 3)
    two_pi = 2 * np.pi
    # Две системы прожилок под разными углами; частоты целые — бесшовность сохраняется.
    # Маски присутствия оставляют от каждой системы обрывки: прожилки редкие и рваные.
    p1 = two_pi * (2 * u + 1 * v) + 1.8 * warp1 + 0.25 * fft_noise(size, 1.8, seed + 5)
    p2 = two_pi * (-1 * u + 3 * v) + 1.6 * warp2 + 0.3 * fft_noise(size, 1.7, seed + 6) + 1.3
    pres1 = np.clip((fft_noise(size, 2.2, seed + 7) + 0.1) * 1.6, 0, 1)
    pres2 = np.clip((fft_noise(size, 2.2, seed + 8) - 0.35) * 1.6, 0, 1)
    vein1 = np.exp(-(np.sin(p1) / 0.05) ** 2) * pres1
    vein2 = np.exp(-(np.sin(p2) / 0.022) ** 2) * pres2
    veins = np.clip(vein1 + vein2 * 0.7, 0, 1)
    base = 0.035 + 0.012 * np.tanh(clouds * 0.8) + 0.006 * grain
    lum = base + veins * 0.14
    tint = np.array([0.94, 0.97, 1.04], dtype=np.float32)
    albedo = np.clip(lum[..., None] * tint, 0, 1)
    # Перевод линейной яркости в sRGB для хранения в JPEG.
    srgb = np.where(albedo <= 0.0031308, albedo * 12.92, 1.055 * np.power(albedo, 1 / 2.4) - 0.055)
    height = 0.5 + 0.06 * clouds - 0.12 * veins + 0.02 * grain
    normal = normal_from_height(height, 6.0)
    rough = np.clip(0.34 + 0.05 * np.tanh(clouds) + 0.12 * veins + 0.03 * grain, 0.2, 0.7)
    arm = np.stack([np.ones_like(rough), rough, np.zeros_like(rough)], -1)
    return srgb.astype(np.float32), normal.astype(np.float32), arm.astype(np.float32), height


def main():
    # Порода перевала: графит #303943 с холодными сине-серыми вариациями.
    rock = load("dark_rock_02_diff_2k.jpg")
    save(recolor(rock, hex_rgb("#1e252e"), hex_rgb("#56616f"), contrast=1.25, keep_chroma=0.45),
         "nm_rock_albedo_2k.jpg")
    # Обработанный камень (плиты старой дороги, ступени): холодный серый, чуть светлее породы.
    worked = load("rock_surface_diff_2k.jpg")
    save(recolor(worked, hex_rgb("#3a3f46"), hex_rgb("#7d838b"), contrast=1.7, keep_chroma=0.1),
         "nm_stone_worked_albedo_2k.jpg")
    # Снег: грязно-белый #D0D6DA, светлые гребни #E6EAEC, без чистого белого.
    snow = load("snow_02_diff_2k.jpg")
    save(recolor(snow, hex_rgb("#b4bcc3"), hex_rgb("#e6eaec"), contrast=0.75), "nm_snow_albedo_2k.jpg")
    # Мешковина: некрашеный грубый лён/пенька (исходник — голубой лён).
    linen = load("rough_linen_diff_1k.jpg")
    save(recolor(linen, hex_rgb("#5e4e3a"), hex_rgb("#a48c68"), contrast=3.0), "nm_linen_albedo_1k.jpg")
    # Кость: желтовато-серая, не белее снега.
    bone = load("rock_surface_diff_2k.jpg")[::2, ::2]
    save(recolor(bone, hex_rgb("#8e8676"), hex_rgb("#c9c0aa"), contrast=1.4), "nm_bone_albedo_1k.jpg")
    # Кованое железо: тёмный металл, ржавчина #754432 пятнами по светлым участкам исходника.
    rust = load("rust_coarse_01_diff_1k.jpg")
    lum = luminance(rust)
    m = np.clip((lum - np.quantile(lum, 0.45)) / (np.quantile(lum, 0.9) - np.quantile(lum, 0.45)), 0, 1)
    dark_iron = recolor(rust, hex_rgb("#1d1c1b"), hex_rgb("#3c3833"), contrast=1.5)
    rusty = recolor(rust, hex_rgb("#4a2a1d"), hex_rgb("#8a5238"), contrast=1.2)
    save(dark_iron * (1 - m[..., None]) + rusty * m[..., None], "nm_iron_albedo_1k.jpg")
    # Чёрный мрамор храма.
    alb, nor, arm, height = black_marble()
    save(alb, "nm_marble_black_albedo_2k.jpg")
    save(nor, "nm_marble_black_nor_gl_2k.jpg")
    save(arm, "nm_marble_black_arm_2k.jpg")
    save(np.repeat(np.clip(height, 0, 1)[..., None], 3, -1), "nm_marble_black_disp_2k.jpg")


if __name__ == "__main__":
    main()

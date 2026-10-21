"""S3.2: текстуры старой ржавой скамейки из CC0-набора Poly Haven `rusty_metal_02`.

    python make_bench_textures.py <папка textures>

1. `bench_paint_rust_albedo.png` — белая краска исходника перекрашена в выцветший тёмно-зелёный
   (ИНТЕРПРЕТАЦИЯ: старый «парковый» цвет), ржавчина затемнена до бурой и чуть расширена,
   чтобы скамейка читалась именно ржавой. Маска ржавчины — насыщенность цвета исходника.
2. `rust_stain.png` — пятно ржавых потёков для декалей на плитке под ножками (альфа — маска).
Карты нормалей и ARM используются исходные.
"""

import sys

import numpy as np
from PIL import Image, ImageFilter

PAINT = np.array([0.25, 0.32, 0.26])
RUST = np.array([0.36, 0.17, 0.07])
RUST_GROW = 2  # px при 2K: ржавые пятна чуть крупнее исходных
# Доля поверхности под ржавчиной: порог маски берётся по квантилям насыщенности
# (у «белой» краски исходника тоже тёплый оттенок, фиксированный порог захватывает всё).
RUST_QUANTILES = (0.52, 0.64)


def smoothstep(edge0, edge1, x):
    t = np.clip((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def rust_mask(rgb):
    high = rgb.max(axis=2)
    low = rgb.min(axis=2)
    saturation = (high - low) / np.maximum(high, 1e-4)
    mask = smoothstep(*np.quantile(saturation, RUST_QUANTILES), saturation)
    image = Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(RUST_GROW * 2 + 1))
    return np.asarray(image.filter(ImageFilter.GaussianBlur(1.5)), dtype=np.float32) / 255.0


def main():
    folder = sys.argv[1]
    source = np.asarray(Image.open(f"{folder}/rusty_metal_02_diff_2k.jpg").convert("RGB"), dtype=np.float32) / 255.0
    mask = rust_mask(source)[..., None]
    luminance = source.mean(axis=2, keepdims=True)
    paint = PAINT * (0.75 + 0.5 * luminance / max(float(luminance.mean()), 1e-4))
    rust = RUST * (0.55 + 0.9 * luminance)
    albedo = paint * (1.0 - mask) + rust * mask
    Image.fromarray((np.clip(albedo, 0, 1) * 255).astype(np.uint8)).save(f"{folder}/bench_paint_rust_albedo.png")

    # Пятно: радиальный спад, вытянутый вниз (потёк), с рваным краем по маске ржавчины.
    size = 512
    crop = np.asarray(Image.fromarray((source * 255).astype(np.uint8)).resize((size, size)), dtype=np.float32) / 255.0
    yy, xx = np.mgrid[0:size, 0:size] / (size - 1) * 2.0 - 1.0
    falloff = 1.0 - smoothstep(0.25, 1.0, np.sqrt(xx ** 2 + (yy * 0.8) ** 2))
    alpha = np.clip(falloff * (0.35 + 0.9 * rust_mask(crop)), 0.0, 1.0) * 0.85
    color = RUST * (0.6 + 0.6 * crop.mean(axis=2, keepdims=True))
    stain = np.concatenate([color, alpha[..., None]], axis=2)
    Image.fromarray((np.clip(stain, 0, 1) * 255).astype(np.uint8), "RGBA").save(f"{folder}/rust_stain.png")
    print("rust coverage", round(float(mask.mean()), 3))


main()

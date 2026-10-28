"""Процедурные текстуры пролога (системный Python: numpy + Pillow).

Запуск из корня проекта:
    python assets/environments/prologue/source/make_pr_textures.py

Твёрдые поверхности участка и изолятора (бриф `docs/design/level_brief_quarantine_cell.md`, §10):
матовая порошковая краска с царапинами у мест контакта, нескользкое покрытие пола со следами
уборки, виниловые накладки, тканые ремни, шлифованная сталь, два экрана терминалов.
Альбедо нейтральные (средняя линейная яркость ≈ 0,5): цвет задаёт `tint` материала
(`pr_materials.py`), поэтому одна текстура служит и графитовым стенам бокса, и бронеплитам лобби.
Все карты бесшовные (FFT-шум, линии с переносом через край). Помощники — из `make_nm_textures.py`.
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "assets" / "environments" / "nightmare" / "source"))
import make_nm_textures as NT  # noqa: E402

TEX = Path(__file__).resolve().parents[1] / "materials" / "textures"
LEATHER = ROOT / "assets" / "environments" / "nightmare" / "materials" / "textures" / "brown_leather_diff_1k.jpg"


def to_srgb(lin):
    lin = np.clip(lin, 0, 1)
    return np.where(lin <= 0.0031308, lin * 12.92, 1.055 * np.power(lin, 1 / 2.4) - 0.055)


def save(arr, name, quality=92):
    arr = np.asarray(arr, dtype=np.float32)
    if arr.ndim == 2:
        arr = np.repeat(arr[..., None], 3, -1)
    img = Image.fromarray(np.clip(arr * 255.0 + 0.5, 0, 255).astype(np.uint8))
    if name.endswith(".png"):
        img.save(TEX / name)
    else:
        img.save(TEX / name, quality=quality, subsampling=0)
    print("saved", name, img.size)


def wrap_lines(size, lines, width=1, blur=0.0):
    """Маска отрезков с переносом через край (бесшовно): lines — [(x0, y0, x1, y1, value)] в пикселях."""
    img = Image.new("F", (size, size), 0.0)
    d = ImageDraw.Draw(img)
    for x0, y0, x1, y1, val in lines:
        for ox in (-size, 0, size):
            for oy in (-size, 0, size):
                d.line((x0 + ox, y0 + oy, x1 + ox, y1 + oy), fill=val, width=width)
    arr = np.asarray(img, dtype=np.float32)
    return blur_wrap(arr, blur) if blur else arr


def blur_wrap(arr, sigma):
    """Гауссово размытие по тору (через FFT): края стыкуются."""
    f = np.fft.fftfreq(arr.shape[0])
    fx, fy = np.meshgrid(f, f)
    k = np.exp(-2 * (np.pi * sigma) ** 2 * (fx ** 2 + fy ** 2))
    return np.real(np.fft.ifft2(np.fft.fft2(arr) * k)).astype(np.float32)


def scratches(size, count, seed, length=(0.01, 0.08), bias=None):
    """Тонкие царапины: в основном короткие, часть — пучками (следы инструмента, пряжек)."""
    r = np.random.default_rng(seed)
    lines = []
    for _ in range(count):
        x, y = r.uniform(0, size, 2)
        ang = r.uniform(0, np.pi) if bias is None else bias + r.normal(0, 0.35)
        ln = r.uniform(*length) * size
        n = 1 if r.random() < 0.7 else r.integers(2, 5)
        for k in range(n):
            dx, dy = np.cos(ang) * ln, np.sin(ang) * ln
            off = k * r.uniform(1.5, 3.0)
            lines.append((x - np.sin(ang) * off, y + np.cos(ang) * off, x + dx, y + dy, r.uniform(0.4, 1.0)))
    return np.clip(wrap_lines(size, lines, 1, 0.6), 0, 1)


def paint(size=1024, seed=31):
    """Порошковая краска / композит: «апельсиновая корка», мягкие пятна тона, царапины до металла."""
    peel = NT.fft_noise(size, 1.1, seed)
    micro = NT.fft_noise(size, 0.2, seed + 1)
    mottle = NT.fft_noise(size, 2.3, seed + 2)
    sc = scratches(size, 340, seed + 3)
    dent = np.clip(NT.fft_noise(size, 2.8, seed + 4) - 1.6, 0, None)  # редкие вмятины
    height = 0.5 + 0.012 * peel + 0.004 * micro - 0.05 * sc - 0.04 * dent
    normal = NT.normal_from_height(height, 9.0)
    lum = 0.5 * (1 + 0.045 * mottle + 0.015 * micro) * (1 - 0.05 * np.clip(dent, 0, 1))
    lum = lum * (1 - sc * 0.35) + sc * 0.35 * 0.85  # обнажённый металл светлее
    rough = np.clip(0.58 + 0.05 * mottle + 0.02 * micro - 0.25 * sc, 0.2, 0.9)
    arm = np.stack([np.ones_like(rough), rough, np.clip(sc * 1.4, 0, 1)], -1)
    return to_srgb(lum), normal, arm


def coating(size=1024, seed=41):
    """Нескользкое покрытие пола: зерно наполнителя, следы уборки — более светлые и гладкие полосы."""
    r = np.random.default_rng(seed)
    grains = np.zeros((size, size), np.float32)
    idx = r.integers(0, size, (size * size // 14, 2))
    grains[idx[:, 0], idx[:, 1]] = r.uniform(0.4, 1.0, len(idx))
    grains = blur_wrap(grains, 0.8)
    grains /= grains.max() + 1e-6
    coarse = NT.fft_noise(size, 1.6, seed + 1)
    patches = NT.fft_noise(size, 2.6, seed + 2)
    # Следы уборки: мягкие размытые пятна (не полосы — регулярный рисунок читался как шлифовка).
    mop = np.clip((NT.fft_noise(size, 2.8, seed + 3) - 0.2) * 0.9, 0, 1) * np.clip(patches * 0.5 + 0.6, 0, 1)
    height = 0.5 + 0.06 * grains + 0.01 * coarse
    normal = NT.normal_from_height(height, 7.0)
    lum = 0.5 * (1 + 0.1 * (grains - 0.3) + 0.04 * patches) * (1 + 0.04 * mop)
    rough = np.clip(0.84 - 0.06 * mop + 0.05 * grains, 0.5, 0.95)
    arm = np.stack([np.ones_like(rough), rough, np.zeros_like(rough)], -1)
    return to_srgb(lum), normal, arm


def vinyl(size=1024):
    """Винил накладок: рисунок кожи Poly Haven, обесцвеченный и нормированный к нейтральному серому."""
    src = np.asarray(Image.open(LEATHER).convert("RGB").resize((size, size), Image.LANCZOS), dtype=np.float32) / 255
    lum = NT.luminance(src)
    lum = 0.5 + (lum - lum.mean()) / (lum.std() + 1e-6) * 0.06
    wear = np.clip(NT.fft_noise(size, 2.5, 51) - 0.8, 0, None) * 0.08  # вытертые места светлее
    return to_srgb(np.clip(lum + wear, 0, 1))


def webbing(size=512, seed=61):
    """Тканый ремень (саржа 2/2): нити вдоль U, диагональный рубчик; тайл — 6 см."""
    yy, xx = np.meshgrid(np.arange(size), np.arange(size), indexing="ij")
    u, v = xx / size, yy / size
    n = 32
    warp = np.abs(np.sin(np.pi * n * v)) ** 0.6
    twill = 0.5 + 0.5 * np.sin(2 * np.pi * n / 2 * (u + v))
    fuzz = NT.fft_noise(size, 0.4, seed)
    height = 0.5 + 0.25 * warp * (0.6 + 0.4 * twill) + 0.03 * fuzz
    normal = NT.normal_from_height(height, 4.0)
    lum = 0.5 * (0.82 + 0.18 * warp * twill + 0.03 * fuzz)
    rough = np.clip(0.85 + 0.05 * fuzz, 0, 1)
    arm = np.stack([0.8 + 0.2 * warp, rough, np.zeros_like(rough)], -1)
    return to_srgb(lum), normal, arm


def brushed(size=1024, seed=71):
    """Шлифованная сталь: продольные риски вдоль U, редкие царапины поперёк."""
    white = np.random.default_rng(seed).standard_normal((size, size))
    f = np.fft.fftfreq(size)
    fx, fy = np.meshgrid(f, f)
    spec = np.fft.fft2(white) * np.exp(-(fx / 0.004) ** 2) / (np.abs(fy) * 40 + 1)
    streak = np.real(np.fft.ifft2(spec))
    streak = (streak - streak.mean()) / (streak.std() + 1e-9)
    sc = scratches(size, 90, seed + 1, length=(0.02, 0.1))
    height = 0.5 + 0.02 * streak - 0.04 * sc
    normal = NT.normal_from_height(height, 6.0)
    lum = 0.55 * (1 + 0.05 * streak) + 0.1 * sc
    rough = np.clip(0.34 + 0.06 * streak + 0.1 * sc, 0.1, 0.8)
    arm = np.stack([np.ones_like(rough), rough, np.ones_like(rough)], -1)
    return to_srgb(lum), normal, arm


# --------------------------------------------------------------------------------------
# Экраны. Бриф §5 Z2: не более 3–4 элементов, без обязательного мелкого текста.
# --------------------------------------------------------------------------------------
def _glow(img, radius=3):
    blur = img.filter(ImageFilter.GaussianBlur(radius))
    a = np.asarray(img, dtype=np.float32)
    b = np.asarray(blur, dtype=np.float32)
    return Image.fromarray(np.clip(a + b * 0.6, 0, 255).astype(np.uint8))


def screen_cell(w=512, h=384):
    """Терминал бокса: шапка статуса, кривая пульса, состояние фиксаторов, кольцо глубины сна."""
    img = Image.new("RGB", (w, h), (4, 7, 9))
    d = ImageDraw.Draw(img)
    cyan, dim, grey = (150, 215, 225), (40, 70, 78), (70, 84, 90)
    d.rectangle((0, 0, w, 34), fill=(14, 26, 30))
    d.rectangle((14, 11, 120, 23), fill=dim)  # «КАРАНТИН» — плашка без текста
    d.rectangle((w - 70, 11, w - 14, 23), fill=(28, 52, 58))
    # Кривая пульса.
    d.rectangle((14, 52, 300, 170), outline=dim, width=1)
    rng = np.random.default_rng(3)
    pts = []
    for x in range(16, 298, 2):
        t = (x - 16) / 282
        beat = (x // 2) % 48
        y = 112 + (-38 if beat == 20 else 22 if beat == 22 else 0) + rng.normal(0, 1.2) + 6 * np.sin(t * 9)
        pts.append((x, y))
    d.line(pts, fill=cyan, width=2)
    # Фиксаторы: четыре строки с «замками».
    for k in range(4):
        y = 192 + k * 34
        d.rectangle((14, y, 300, y + 24), fill=(10, 18, 21))
        d.rectangle((24, y + 6, 36, y + 18), fill=cyan)          # корпус замка
        d.arc((26, y - 1, 34, y + 11), 180, 360, fill=cyan, width=2)
        d.rectangle((48, y + 9, 48 + 60 + k * 25, y + 15), fill=grey)
    # Кольцо глубины сна (почти заполнено).
    cx, cy, rr = 400, 150, 70
    d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), outline=dim, width=10)
    d.arc((cx - rr, cy - rr, cx + rr, cy + rr), -90, 205, fill=cyan, width=10)
    d.rectangle((cx - 30, cy - 6, cx + 30, cy + 6), fill=grey)
    d.rectangle((330, 290, 490, 300), fill=dim)
    d.rectangle((330, 290, 450, 300), fill=(90, 140, 150))
    return _glow(img)


def screen_lobby(w=640, h=400):
    """Терминал дежурного: журнал (строки), план этажа, кнопка тревоги на экране (не нажата)."""
    img = Image.new("RGB", (w, h), (5, 7, 9))
    d = ImageDraw.Draw(img)
    cyan, dim, grey = (140, 200, 210), (36, 62, 70), (64, 76, 82)
    d.rectangle((0, 0, w, 30), fill=(14, 24, 28))
    d.rectangle((12, 10, 150, 20), fill=dim)
    rng = np.random.default_rng(5)
    for k in range(10):
        y = 46 + k * 30
        d.rectangle((12, y, 330, y + 20), fill=(10, 16, 19) if k % 2 else (13, 21, 24))
        d.rectangle((20, y + 7, 60, y + 13), fill=grey)
        d.rectangle((72, y + 7, 72 + int(rng.uniform(80, 220)), y + 13), fill=(52, 66, 72))
    # План этажа: прямоугольники помещений.
    d.rectangle((350, 46, 628, 300), outline=dim, width=2)
    for rect in ((360, 56, 470, 150), (480, 56, 618, 120), (480, 130, 618, 220), (360, 160, 470, 290),
                 (480, 230, 560, 290)):
        d.rectangle(rect, outline=(44, 74, 82), width=2)
    d.rectangle((388, 92, 404, 108), fill=cyan)  # «вы здесь»
    # Кнопка тревоги (экранная), тусклая.
    d.rectangle((350, 318, 628, 384), fill=(40, 8, 8), outline=(90, 20, 18), width=2)
    d.rectangle((380, 344, 600, 358), fill=(80, 18, 16))
    return _glow(img)


def main():
    TEX.mkdir(parents=True, exist_ok=True)
    a, n, arm = paint()
    save(a, "pr_paint_albedo_1k.jpg")
    save(n, "pr_paint_nor_gl_1k.jpg")
    save(arm, "pr_paint_arm_1k.jpg")
    a, n, arm = coating()
    save(a, "pr_coating_albedo_1k.jpg")
    save(n, "pr_coating_nor_gl_1k.jpg")
    save(arm, "pr_coating_arm_1k.jpg")
    save(vinyl(), "pr_vinyl_albedo_1k.jpg")
    a, n, arm = webbing()
    save(a, "pr_webbing_albedo_512.jpg")
    save(n, "pr_webbing_nor_gl_512.jpg")
    save(arm, "pr_webbing_arm_512.jpg")
    a, n, arm = brushed()
    save(a, "pr_brushed_albedo_1k.jpg")
    save(n, "pr_brushed_nor_gl_1k.jpg")
    save(arm, "pr_brushed_arm_1k.jpg")
    screen_cell().save(TEX / "pr_screen_cell.png")
    screen_lobby().save(TEX / "pr_screen_lobby.png")
    print("saved screens")


if __name__ == "__main__":
    main()

"""Процедурная живопись карт: шум, рельеф, светотень, маски и цвет.

Без внешних картинок: всё строится из детерминированного шума (numpy + scipy),
поэтому карты воспроизводимы и лицензионно чисты. Координаты — пиксели растра.
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage


def value_noise(h, w, cell, rng):
    """Гладкий шум: случайная сетка с шагом cell, бикубическое увеличение."""
    gh, gw = int(h / cell) + 4, int(w / cell) + 4
    grid = rng.random((gh, gw)).astype(np.float32)
    big = ndimage.zoom(grid, cell, order=3)
    return big[:h, :w]


def fbm(h, w, cell, octaves, rng, persistence=0.5):
    total = np.zeros((h, w), np.float32)
    amp, norm = 1.0, 0.0
    for _ in range(octaves):
        if cell < 1.5:
            break
        total += amp * value_noise(h, w, cell, rng)
        norm += amp
        amp *= persistence
        cell /= 2.0
    return total / norm


def ridged(h, w, cell, octaves, rng):
    """Хребтовый шум: острые гребни вместо округлых холмов."""
    total = np.zeros((h, w), np.float32)
    amp, norm = 1.0, 0.0
    for _ in range(octaves):
        if cell < 1.5:
            break
        n = value_noise(h, w, cell, rng)
        total += amp * (1.0 - np.abs(2.0 * n - 1.0)) ** 2
        norm += amp
        amp *= 0.5
        cell /= 2.0
    return total / norm


def warp(field, strength, cell, rng):
    """Изгиб поля: естественные неровные края вместо геометрических форм."""
    h, w = field.shape
    dx = (fbm(h, w, cell, 4, rng) - 0.5) * 2.0 * strength
    dy = (fbm(h, w, cell, 4, rng) - 0.5) * 2.0 * strength
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    return ndimage.map_coordinates(field, [yy + dy, xx + dx], order=1, mode="reflect")


def polygon_mask(h, w, points, blur=0.0):
    img = Image.new("L", (w, h), 0)
    ImageDraw.Draw(img).polygon([tuple(p) for p in points], fill=255)
    if blur > 0:
        img = img.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(img, np.float32) / 255.0


def line_mask(h, w, points, width, blur=0.0):
    img = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(img)
    pts = [tuple(p) for p in points]
    draw.line(pts, fill=255, width=int(width), joint="curve")
    for p in pts:
        r = width / 2.0
        draw.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=255)
    if blur > 0:
        img = img.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(img, np.float32) / 255.0


def distance_to(mask):
    """Расстояние (в пикселях) до ближайшей точки маски."""
    return ndimage.distance_transform_edt(mask < 0.5).astype(np.float32)


def ellipse_mask(h, w, cx, cy, rx, ry):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    return (((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2).astype(np.float32)


def hillshade(height, scale=1.0, azimuth=315.0, altitude=45.0):
    """Светотень: свет с северо-запада, как на рисованных картах."""
    gy, gx = np.gradient(height * scale)
    slope = np.pi / 2.0 - np.arctan(np.hypot(gx, gy))
    aspect = np.arctan2(-gx, gy)
    az = np.radians(azimuth)
    alt = np.radians(altitude)
    shade = np.sin(alt) * np.sin(slope) + np.cos(alt) * np.cos(slope) * np.cos(az - aspect)
    return np.clip(shade, 0.0, 1.0).astype(np.float32)


def ramp(values, stops):
    """Цвет по высоте: stops — [(значение, (r, g, b)), ...] по возрастанию."""
    keys = np.array([s[0] for s in stops], np.float32)
    cols = np.array([s[1] for s in stops], np.float32) / 255.0
    out = np.zeros(values.shape + (3,), np.float32)
    for c in range(3):
        out[..., c] = np.interp(values, keys, cols[:, c])
    return out


def mix(a, b, t):
    t = np.clip(t, 0.0, 1.0)[..., None]
    return a * (1.0 - t) + b * t


def tint(rgb):
    return np.array(rgb, np.float32) / 255.0


def finish(color, rng, grain=0.06, vignette=0.35, desaturate=0.12):
    """Общая обработка: лёгкое обесцвечивание, зерно бумаги, виньетка."""
    h, w, _ = color.shape
    gray = color.mean(axis=2, keepdims=True)
    color = color * (1.0 - desaturate) + gray * desaturate
    paper = fbm(h, w, 3.0, 2, rng) - 0.5
    paper2 = fbm(h, w, 40.0, 3, rng) - 0.5
    color = color * (1.0 + paper[..., None] * grain + paper2[..., None] * grain * 1.5)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.hypot((xx - w / 2) / (w / 2), (yy - h / 2) / (h / 2))
    color = color * (1.0 - vignette * np.clip(d - 0.55, 0, 1) ** 1.5)[..., None]
    return color


def save(color, path):
    arr = (np.clip(color, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
    Image.fromarray(arr, "RGB").save(path, optimize=True)


def meander(curve, amplitude, seed):
    """Извивы реки: смещение точек поперёк направления по гладкому шуму."""
    curve = np.array(curve, np.float32)
    n = len(curve)
    rng = np.random.default_rng(seed)
    noise = ndimage.gaussian_filter1d(rng.normal(size=n), sigma=max(n / 40.0, 1.0))
    noise = noise / (np.abs(noise).max() or 1.0)
    tangent = np.gradient(curve, axis=0)
    normal = np.stack([-tangent[:, 1], tangent[:, 0]], axis=1)
    normal /= np.linalg.norm(normal, axis=1, keepdims=True) + 1e-6
    fade = np.sin(np.linspace(0, np.pi, n)) ** 0.5
    return curve + normal * (noise * amplitude * fade)[:, None]


def smooth_curve(points, samples=12):
    """Сглаженная ломаная (Catmull-Rom) для рек, дорог и хребтов."""
    pts = np.array(points, np.float32)
    if len(pts) < 3:
        return pts
    out = []
    padded = np.vstack([pts[0], pts, pts[-1]])
    for i in range(1, len(padded) - 2):
        p0, p1, p2, p3 = padded[i - 1], padded[i], padded[i + 1], padded[i + 2]
        for t in np.linspace(0, 1, samples, endpoint=False):
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(pts[-1])
    return np.array(out, np.float32)

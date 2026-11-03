"""Сборщик кораллового кита Забытого берега (Blender 5.1, фоновый).

Запуск из корня проекта:
    blender -b --factory-startup --python assets/environments/nightmare/source/build_coral_kit.py -- [опции]

Опции:
    --only wall_tall_a,mass_a,...   собрать только указанные ассеты
    --test <файл.jpg>               превью-рендер выбранных ассетов
    --no-export                     не писать .glb
    --list                          показать имена ассетов

Результат: assets/environments/nightmare/coral/<name>.glb,
source/coral_kit.blend, превью docs/art/previews/forgotten_shore/coral_<name>.jpg.
"""

from __future__ import annotations

import importlib
import math
import random
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Vector, noise

SRC = Path(__file__).resolve().parent
if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))

import nm_lib as L  # noqa: E402
import nm_props as P  # noqa: E402
import nm_coral_materials as CM  # noqa: E402
import nm_coral_lib as CL  # noqa: E402

importlib.reload(L)
importlib.reload(P)
importlib.reload(CM)
importlib.reload(CL)

OUT = L.NM_DIR / "coral"
PREV = L.ROOT / "docs" / "art" / "previews" / "forgotten_shore"
T = lambda x, y, z: Matrix.Translation((x, y, z))
TAU = 2.0 * math.pi


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / max(b - a, 1e-6)))
    return t * t * (3.0 - 2.0 * t)


# ---------------------------------------------------------------------------
# Ассеты
# ---------------------------------------------------------------------------
def _blade_at(height, width, thickness, x, y, z, curve=(0.1, 0.05), seed=0, ridge=0.10):
    bm = CL.blade(height, width, thickness, curve=curve, seed=seed, ridge=ridge)
    bm.transform(T(x, y, z))
    return bm


def _detail(coll, name, bm, mat="nm_coral_live", mask=(0.85, 0.65, 0.35, 0.10), rot=None):
    if rot is not None:
        bm.transform(rot)
    obj = L.object_from_bmesh(name, bm, coll, mat)
    L.plain_masks(obj, mask)
    L.uv_box(obj, 1.0)
    L.shade(obj, 65.0)
    return obj


def coral_details(coll, scale: float, seed: int, branches=4, blades=4, brains=2, fans=0,
                  z_max=None, y_span=None):
    rng = random.Random(seed)
    z_max = z_max if z_max is not None else scale * 1.7
    y_span = y_span if y_span is not None else scale * 0.8
    for i in range(blades):
        h = rng.uniform(0.7, 2.2) * max(0.6, scale / 3.0)
        bm = CL.blade(h, rng.uniform(0.18, 0.38) * max(0.7, scale / 3.0),
                      rng.uniform(0.10, 0.20) * max(0.7, scale / 3.0),
                      curve=(rng.uniform(-0.12, 0.12), rng.uniform(-0.04, 0.04)),
                      seed=seed + 10 + i, ridge=0.20, segs=10, rings=7)
        _detail(coll, f"detail_blade_{i}", bm, "nm_coral_live" if i % 4 else "nm_coral_dead",
                mask=(0.9, 0.45, 0.30, 0.05),
                rot=T(rng.uniform(-scale, scale), rng.uniform(-y_span, y_span), rng.uniform(0.1, z_max))
                @ Matrix.Rotation(rng.uniform(-0.25, 0.25), 4, "Z"))
    for i in range(branches):
        base = (rng.uniform(-scale, scale), rng.uniform(-y_span, y_span), rng.uniform(0.3, z_max))
        bm = _branch_cluster(seed + 100 + i, base,
                             direction=(rng.uniform(-0.5, 0.5), rng.choice((-1.0, 1.0)), rng.uniform(0.1, 0.6)),
                             count=3, length=rng.uniform(1.0, 2.6) * max(0.6, scale / 3.0),
                             radius=rng.uniform(0.14, 0.28) * max(0.7, scale / 3.0))
        _detail(coll, f"detail_branch_{i}", bm, "nm_coral_live" if i % 3 else "nm_coral_dead",
                mask=(0.9, 0.25, 0.35, 0.05))
    for i in range(brains):
        bm = CL.brain(rng.uniform(0.25, 0.55) * max(0.6, scale / 3.0),
                      height_scale=rng.uniform(0.4, 0.65), segs=24, rings=12, seed=seed + 200 + i)
        _detail(coll, f"detail_brain_{i}", bm, "nm_coral_live",
                mask=(0.9, 0.25, 0.45, 0.05),
                rot=T(rng.uniform(-scale, scale), rng.uniform(-y_span, y_span), rng.uniform(0.05, 0.4)))
    for i in range(fans):
        bm = CL.fan(rng.uniform(0.4, 0.75) * max(0.7, scale / 3.0), rng.uniform(0.9, 1.2),
                    thickness=0.06, spread=0.9, ribs=9, nu=18, nv=9, seed=seed + 300 + i)
        _detail(coll, f"detail_fan_{i}", bm, "nm_coral_live",
                mask=(0.9, 0.25, 0.35, 0.05),
                rot=T(rng.uniform(-scale, scale), rng.uniform(-y_span, y_span), rng.uniform(0.2, z_max * 0.8))
                @ Matrix.Rotation(rng.uniform(-0.5, 0.5), 4, "Z"))


def _branch_cluster(seed: int, base: tuple[float, float, float], direction=(0.0, -1.0, 0.3),
                    count=3, length=3.0, radius=0.26):
    rng = random.Random(seed)
    parts = []
    for i in range(count):
        bx, by, bz = base
        dx, dy, dz = direction
        path = []
        for j in range(9):
            t = j / 8.0
            spread = length * 0.22 * t
            path.append(Vector((bx + dx * length * t + math.sin(t * 2.7 + i) * spread,
                                by + dy * length * t + math.cos(t * 2.1 + i) * spread * 0.5,
                                bz + dz * length * t + math.sin(t * 2.0 + i * 1.7) * length * 0.12)))
        parts.append(P.tube(path, radius * rng.uniform(0.75, 1.15), segs=8,
                            radius_fn=lambda t: 0.55 + 0.55 * math.sin(math.pi * t) ** 0.45))
    return L.join_bmeshes([(p, Matrix.Identity(4)) for p in parts])


def wall_details(coll, v: int = 0):
    rng = random.Random(1700 + v)
    # Мелкие лезвия на кромке и лице: рвут гладкий силуэт.
    for i in range(7):
        h = rng.uniform(1.2, 3.4)
        bm = CL.blade(h, rng.uniform(0.32, 0.62), rng.uniform(0.16, 0.28),
                      curve=(rng.uniform(-0.10, 0.10), rng.uniform(-0.03, 0.03)),
                      seed=1710 + i + v * 13, ridge=0.20, segs=10, rings=8)
        x = rng.uniform(-4.4, 4.4)
        y = rng.choice((-1.55, 1.45, rng.uniform(-0.8, 0.8)))
        z = rng.uniform(3.5, 11.5)
        _detail(coll, f"detail_blade_{i}", bm, "nm_coral_live" if i % 4 else "nm_coral_dead",
                mask=(0.9, 0.35, 0.35, 0.06), rot=T(x, y, z) @ Matrix.Rotation(rng.uniform(-0.35, 0.35), 4, "Z"))
    # Толстые ветви-кусты: главный признак живого коралла.
    for i in range(8):
        base = (rng.uniform(-4.0, 4.0), rng.choice((-1.15, 1.10)), rng.uniform(2.0, 9.5))
        bm = _branch_cluster(1900 + i + v * 7, base,
                             direction=(rng.uniform(-0.3, 0.3), -1.0 if base[1] < 0 else 1.0, rng.uniform(0.15, 0.55)),
                             count=3, length=rng.uniform(1.7, 3.4), radius=rng.uniform(0.30, 0.52))
        _detail(coll, f"detail_branch_{i}", bm, "nm_coral_live",
                mask=(0.9, 0.30, 0.35, 0.05))
    # Мозговые купола у основания и на полке.
    for i in range(4):
        bm = CL.brain(rng.uniform(0.38, 0.68), height_scale=rng.uniform(0.45, 0.65), segs=28, rings=14,
                      seed=1780 + i + v)
        _detail(coll, f"detail_brain_{i}", bm, "nm_coral_live",
                mask=(0.9, 0.35, 0.45, 0.05),
                rot=T(rng.uniform(-3.8, 3.8), rng.uniform(-1.2, 1.2), rng.uniform(0.1, 0.5)))
    # Обломки у основания.
    for i in range(5):
        bm = CL.ellipsoid(rng.uniform(0.25, 0.55), rng.uniform(0.22, 0.45), rng.uniform(0.2, 0.4),
                          center=(rng.uniform(-4.8, 4.8), rng.uniform(-2.2, 2.2), 0.15),
                          wobble=0.45, seed=1800 + i + v, segs=12, rings=8)
        _detail(coll, f"detail_rubble_{i}", bm, "nm_coral_dead",
                mask=(0.8, 0.15, 0.55, 0.20))


def wall_tall(v: int = 0):
    length, height, thick = 10.0 + v * 0.8, 14.0 + v * 1.4, 3.0
    parts = []
    rng = random.Random(100 + v)
    # Нижний слитый вал: не плита, а ряд сросшихся лопастей.
    for i in range(5):
        x = -length * 0.40 + i * length * 0.20
        parts.append(CL.ellipsoid(1.55, 1.65, 1.15,
                                  center=(x, rng.uniform(-0.35, 0.35), 1.0),
                                  wobble=0.28, seed=110 + i + v * 7))
    # Вертикальные плавники — основная форма стены; между ними остаются глубокие щели.
    for i in range(6):
        x = -length * 0.40 + i * length * 0.16
        h = height * (0.62 + 0.22 * math.sin(i * 1.7 + v * 0.9) + rng.uniform(-0.06, 0.06))
        w = 1.35 + rng.uniform(0.18, 0.55)
        th = 1.35 + rng.uniform(0.12, 0.45)
        parts.append(_blade_at(h, w, th, x, rng.uniform(-0.5, 0.5), 0.45,
                               curve=(rng.uniform(-0.12, 0.14), rng.uniform(-0.05, 0.05)),
                               seed=200 + i + v * 11, ridge=0.22))
    # Сросшиеся перемычки только в двух поясах: в середине остаются тёмные щели.
    for i in range(3):
        x = -length * 0.30 + i * length * 0.30
        z = height * (0.24 if i != 1 else 0.46)
        parts.append(CL.ellipsoid(rng.uniform(1.1, 1.7), rng.uniform(0.7, 1.2), rng.uniform(0.6, 1.0),
                                  center=(x, rng.uniform(-0.5, 0.5), z),
                                  wobble=0.30, seed=300 + i + v * 13))
    # Толстые ветви: коралл, а не скала.
    for i in range(9):
        bx = rng.uniform(-length * 0.42, length * 0.42)
        by = rng.choice((-1.15, 1.0, rng.uniform(-0.8, 0.8)))
        bz = rng.uniform(2.5, height * 0.68)
        length_b = rng.uniform(1.6, 4.2)
        path = []
        for j in range(9):
            t = j / 8.0
            path.append(Vector((bx + math.sin(t * 2.4 + i) * 0.55 * t,
                                by + (rng.uniform(-0.1, 0.1) + 0.55 * t * (1 if by < 0 else -1)),
                                bz + length_b * t + 0.25 * math.sin(t * 3.0 + i))))
        parts.append(P.tube(path, rng.uniform(0.18, 0.34), segs=8,
                            radius_fn=lambda t: 0.55 + 0.55 * math.sin(math.pi * t) ** 0.5))
    # Крупный нависающий козырёк сверху, из трёх смещённых лопастей.
    parts.append(CL.ellipsoid(length * 0.34, 1.25, 1.25,
                              center=(-1.0, -1.05, height * 0.69), rot_z=0.20, wobble=0.26, seed=400 + v))
    parts.append(CL.ellipsoid(length * 0.30, 1.5, 1.0,
                              center=(1.3, -0.95, height * 0.61), rot_z=-0.16, wobble=0.28, seed=410 + v))
    parts.append(CL.ellipsoid(length * 0.20, 1.05, 1.15,
                              center=(0.1, -1.55, height * 0.75), rot_z=0.08, wobble=0.25, seed=420 + v))
    # Верхние обломанные зубья и развилки.
    for i, x in enumerate((-length * 0.30, -length * 0.10, length * 0.12, length * 0.31)):
        parts.append(_blade_at(height * rng.uniform(0.13, 0.24), 1.15, 0.42,
                               x, rng.uniform(-0.6, 0.6), height * 0.72,
                               curve=(rng.uniform(-0.12, 0.12), 0.02),
                               seed=500 + v * 7 + i, ridge=0.20))
    obj = CL.fuse(f"coral_wall_tall_{'abc'[v]}", parts, L.asset_collection(f"coral_wall_tall_{'abc'[v]}"),
                  "nm_coral_live", voxel=0.12, target_tris=11000, seed=500 + v,
                  size=max(length, height) * 0.5, smooth_iter=1, tip_start=0.72, flat_wet=0.22)
    wall_details(obj.users_collection[0], v)
    return obj


def wall_low(v: int = 0):
    length, height, thick = 6.8 + v * 0.7, 6.4 + v * 0.8, 1.9
    parts = []
    bm = P.board(length, thick, height * 0.72, bevel=0.22)
    bm.transform(T(0, 0, height * 0.36))
    parts.append(bm)
    for i in range(3):
        x = -length * 0.32 + i * length * 0.32
        parts.append(CL.ellipsoid(0.55, thick * 0.55, height * 0.28,
                                  center=(x, 0, height * 0.35), wobble=0.30, seed=20 + i + v * 5))
    parts.append(CL.ellipsoid(length * 0.40, thick * 0.60, height * 0.10,
                              center=(0, -thick * 0.18, height * 0.70), wobble=0.24, seed=30 + v))
    obj = CL.fuse(f"coral_wall_low_{'abc'[v]}", parts, L.asset_collection(f"coral_wall_low_{'abc'[v]}"),
                  "nm_coral_live", voxel=0.11, target_tris=6500, seed=600 + v,
                  size=max(length, height) * 0.5, smooth_iter=2, tip_start=0.68, flat_wet=0.25)
    coral_details(obj.users_collection[0], 4.2, 1600 + v, branches=3, blades=3, brains=1)
    return obj


def mass(v: int = 0):
    rng = random.Random(700 + v)
    parts = []
    if v == 0:
        parts += [
            CL.ellipsoid(2.8, 2.4, 2.1, center=(-1.0, 0.2, 1.8), wobble=0.26, seed=11),
            CL.ellipsoid(2.2, 2.0, 1.8, center=(1.4, -0.4, 1.4), wobble=0.30, seed=12),
            CL.ellipsoid(1.7, 1.8, 1.4, center=(0.2, 0.9, 1.0), wobble=0.28, seed=13),
            _blade_at(6.8, 1.35, 0.55, -0.9, 0.1, 2.2, curve=(0.16, 0.06), seed=14, ridge=0.16),
            _blade_at(5.2, 1.0, 0.45, 1.3, -0.2, 1.8, curve=(-0.12, 0.04), seed=15, ridge=0.14),
        ]
    elif v == 1:
        parts += [
            CL.ellipsoid(3.2, 2.3, 1.5, center=(0, 0, 1.3), wobble=0.25, seed=21),
            CL.ellipsoid(2.4, 2.7, 1.9, center=(-0.8, 0.3, 2.8), wobble=0.28, seed=22),
            CL.ellipsoid(1.8, 1.6, 1.7, center=(1.5, 0.1, 2.2), wobble=0.32, seed=23),
            _blade_at(7.5, 1.2, 0.50, -1.7, -0.4, 2.0, curve=(0.20, 0.08), seed=24, ridge=0.18),
        ]
    elif v == 2:
        parts += [
            CL.ellipsoid(3.8, 1.8, 2.8, center=(0, 0, 2.3), rot_z=0.25, wobble=0.24, seed=31),
            CL.ellipsoid(2.1, 2.1, 1.6, center=(-1.8, 0.7, 1.2), wobble=0.30, seed=32),
            _blade_at(5.8, 1.5, 0.52, 0.0, -0.6, 2.5, curve=(0.10, 0.02), seed=33, ridge=0.18),
            _blade_at(4.2, 1.0, 0.45, 1.6, 0.2, 2.1, curve=(-0.08, 0.02), seed=34, ridge=0.14),
        ]
    elif v == 3:
        parts += [
            CL.ellipsoid(2.6, 2.6, 1.9, center=(-1.5, 0, 1.6), wobble=0.26, seed=41),
            CL.ellipsoid(2.6, 2.6, 1.9, center=(1.5, 0, 1.6), wobble=0.26, seed=42),
            CL.ellipsoid(2.0, 1.4, 1.0, center=(0, 0, 2.4), wobble=0.30, seed=43),
            _blade_at(4.8, 1.0, 0.42, -1.8, 0.1, 2.2, curve=(0.06, 0.08), seed=44, ridge=0.12),
            _blade_at(5.6, 1.1, 0.44, 1.6, -0.1, 2.3, curve=(-0.06, -0.04), seed=45, ridge=0.12),
        ]
    else:
        parts += [
            CL.ellipsoid(3.4, 2.4, 1.2, center=(0, 0, 0.9), wobble=0.30, seed=51),
            CL.ellipsoid(2.0, 1.8, 1.0, center=(-1.8, 0.8, 0.7), wobble=0.32, seed=52),
            CL.ellipsoid(1.8, 2.0, 0.9, center=(2.0, -0.5, 0.6), wobble=0.32, seed=53),
        ]
        for i in range(4):
            parts.append(CL.ellipsoid(rng.uniform(0.4, 0.7), rng.uniform(0.35, 0.6),
                                      rng.uniform(0.35, 0.7),
                                      center=(rng.uniform(-3.2, 3.2), rng.uniform(-2.0, 2.0), 0.35),
                                      wobble=0.4, seed=60 + i))
    obj = CL.fuse(f"coral_mass_{'abcde'[v]}", parts, L.asset_collection(f"coral_mass_{'abcde'[v]}"),
                  "nm_coral_live", voxel=0.14, target_tris=9000, seed=800 + v,
                  size=4.0, smooth_iter=2, tip_start=0.52, flat_wet=0.28)
    coral_details(obj.users_collection[0], 3.4, 1800 + v, branches=3, blades=4, brains=2)
    return obj


def blade_asset(v: int = 0):
    seed = 900 + v
    h = (9.5, 11.5, 12.5, 8.0)[v]
    parts = [
        CL.blade(h, 1.6 + 0.2 * v, 0.55 + 0.05 * v,
                 curve=((0.16, 0.06), (-0.12, 0.04), (0.22, -0.04), (0.08, 0.02))[v],
                 ridge=0.18, seed=seed),
    ]
    for i in range(2):
        parts.append(CL.blade(h * (0.45 + 0.1 * i), 0.75, 0.34,
                              curve=((0.06, 0.02), (-0.05, 0.01))[i],
                              seed=seed + 10 + i))
    parts.append(CL.ellipsoid(1.5, 1.15, 0.55, center=(0, 0, 0.3), wobble=0.35, seed=seed + 20))
    obj = CL.fuse(f"coral_blade_{'abcd'[v]}", parts, L.asset_collection(f"coral_blade_{'abcd'[v]}"),
                  "nm_coral_live", voxel=0.10, target_tris=7500, seed=seed,
                  size=h * 0.45, smooth_iter=2, tip_start=0.28, flat_wet=0.20)
    coral_details(obj.users_collection[0], 2.4, 2200 + v, branches=2, blades=3, brains=1)
    return obj


def blade_hero():
    seed = 950
    parts = [
        CL.blade(32.0, 3.8, 1.05, curve=(0.14, 0.03), ridge=0.16, seed=seed, rings=18),
        CL.blade(23.0, 2.5, 0.8, curve=(-0.10, 0.02), ridge=0.18, seed=seed + 1, rings=16),
        CL.blade(16.0, 1.7, 0.6, curve=(0.08, -0.02), ridge=0.18, seed=seed + 2, rings=14),
        CL.ellipsoid(4.0, 3.0, 1.4, center=(0, 0, 1.0), wobble=0.35, seed=seed + 3),
    ]
    obj = CL.fuse("coral_blade_hero", parts, L.asset_collection("coral_blade_hero"),
                  "nm_coral_live", voxel=0.18, target_tris=13000, seed=seed,
                  size=12.0, smooth_iter=2, tip_start=0.20, flat_wet=0.18)
    coral_details(obj.users_collection[0], 7.0, 2400, branches=4, blades=6, brains=2)
    return obj


def ledge(v: int = 0):
    rng = random.Random(1000 + v)
    radius = 4.2 + 0.5 * v

    def hfn(x, y, a, t):
        n = CL.noise.noise(Vector((x * 0.55 + v, y * 0.55, 1.7))) if hasattr(CL, "noise") else 0.0
        return 0.035 * n * (1.0 - t) + 0.03 * math.sin(a * 5 + v) * (1.0 - t) * t

    parts = [CL.radial_patch(radius, rings=10, segs=44, height_fn=hfn, thickness=0.9,
                             edge_wobble=0.14, seed=1000 + v)]
    for i in range(7):
        a = TAU * i / 7 + rng.uniform(-0.4, 0.4)
        r = radius * rng.uniform(0.45, 0.92)
        parts.append(CL.ellipsoid(rng.uniform(0.5, 1.0), rng.uniform(0.45, 0.85), rng.uniform(0.4, 0.8),
                                  center=(r * math.cos(a), r * math.sin(a), -0.55),
                                  wobble=0.35, seed=1010 + i))
    # Обломанный край.
    a = rng.uniform(0, TAU)
    parts.append(CL.ellipsoid(0.8, 0.6, 0.7, center=(radius * 0.95 * math.cos(a),
                                                     radius * 0.95 * math.sin(a), -0.15),
                              wobble=0.4, seed=1030 + v))
    bm = L.join_bmeshes([(p, Matrix.Identity(4)) for p in parts])
    name = f"coral_ledge_{'abcd'[v]}"
    obj = L.object_from_bmesh(name, bm, L.asset_collection(name), "nm_coral_live")
    CL.coral_detail(obj, 1100 + v, radius, amp=0.016, ridge=0.010, micro=0.005)
    L.decimate(obj, 6000)
    CL.recenter_base(obj, 0.02)
    L.shade(obj, 42.0)
    CL.bake_coral_mask(obj, seed=1100 + v, rays=6, ao_dist=1.0, flat_wet=0.32, tip_start=0.95)
    L.uv_box(obj, 1.0)
    coral_details(obj.users_collection[0], radius * 0.9, 2800 + v, branches=2, blades=4, brains=2,
                  z_max=0.45, y_span=radius * 0.7)
    return obj


def ramp(v: int = 0):
    length, width, height = 10.0 + v * 1.0, 6.0, 4.2 + v * 0.9
    parts = [CL.wedge(length, width, height, thickness=0.8, edge_noise=0.10, seed=1200 + v)]
    rng = random.Random(1200 + v)
    for i in range(12):
        side = -1 if i % 2 == 0 else 1
        x = side * (width * 0.50 + rng.uniform(-0.10, 0.10))
        y = rng.uniform(-length * 0.48, length * 0.48)
        parts.append(CL.ellipsoid(rng.uniform(0.55, 1.15), rng.uniform(0.60, 1.20), rng.uniform(0.45, 1.00),
                                  center=(x, y, rng.uniform(-0.05, height * 0.62)),
                                  wobble=0.38, seed=1210 + i))
    # ?????????? ????? ? ??????: ???? ????? ?? ?????? ???? ????????.
    for i in range(4):
        side = -1 if i % 2 == 0 else 1
        parts.append(CL.ellipsoid(rng.uniform(0.65, 1.15), rng.uniform(0.55, 0.95), rng.uniform(0.45, 0.85),
                                  center=(rng.uniform(-width * 0.42, width * 0.42),
                                          side * length * 0.47, rng.uniform(-0.1, height * 0.35)),
                                  wobble=0.40, seed=1230 + i))
    bm = L.join_bmeshes([(p, Matrix.Identity(4)) for p in parts])
    name = f"coral_ramp_{'abc'[v]}"
    obj = L.object_from_bmesh(name, bm, L.asset_collection(name), "nm_coral_live")
    CL.coral_detail(obj, 1300 + v, max(length, height), amp=0.012, ridge=0.008, micro=0.004)
    L.decimate(obj, 6500)
    CL.recenter_base(obj, 0.02)
    L.shade(obj, 44.0)
    CL.bake_coral_mask(obj, seed=1300 + v, rays=6, ao_dist=1.0, flat_wet=0.35, tip_start=0.95)
    L.uv_box(obj, 1.0)
    coral_details(obj.users_collection[0], 3.0, 3000 + v, branches=3, blades=3, brains=1,
                  z_max=1.2, y_span=length * 0.35)
    return obj


def arch(v: int = 0):
    parts = CL.arch(6.0 + 0.8 * v, 5.4 + 0.4 * v, 0.78, 1.35, ribs=2 + (v % 2), seed=1400 + v)
    obj = CL.fuse(f"coral_arch_{'abc'[v]}", parts, L.asset_collection(f"coral_arch_{'abc'[v]}"),
                  "nm_coral_live", voxel=0.11, target_tris=10500, seed=1400 + v,
                  size=5.0, smooth_iter=2, tip_start=0.62, flat_wet=0.25)
    coral_details(obj.users_collection[0], 4.2, 2600 + v, branches=3, blades=3, brains=1, fans=1, z_max=5.5)
    return obj


def bone_asset(name, parts, target=1200, voxel=0.035, smooth_iter=1):
    bm = L.join_bmeshes([(p, Matrix.Identity(4)) for p in parts])
    obj = L.object_from_bmesh(name, bm, L.asset_collection(name), "nm_bone_aged")
    L.voxel_remesh(obj, voxel)
    if smooth_iter:
        L.smooth(obj, 0.45, smooth_iter)
    L.decimate(obj, target)
    CL.recenter_base(obj, 0.01)
    L.shade(obj, 38.0)
    CL.bone_mask(obj)
    L.uv_box(obj, 1.0)
    return obj


def rib(v: int = 0):
    length = 4.2 + v * 1.3
    path = []
    for i in range(13):
        a = math.pi * i / 12
        path.append(Vector((length * 0.5 * math.cos(a), 0.18 * math.sin(a * 2 + v),
                            0.15 + length * 0.34 * math.sin(a))))
    parts = [P.tube(path, 0.10 + 0.02 * v, segs=10,
                    radius_fn=lambda t: 0.62 + 0.38 * math.sin(math.pi * t) ** 0.5)]
    for sx in (-1, 1):
        parts.append(CL.ellipsoid(0.16, 0.13, 0.12,
                                  center=(sx * length * 0.49, 0.0, 0.16),
                                  wobble=0.25, seed=3100 + v + sx, segs=10, rings=6))
    return bone_asset(f"bone_rib_{'abc'[v]}", parts, target=1200 - v * 150, voxel=0.035)


def vertebra(v: int = 0):
    profile = [(0.28, 0.0), (0.34, 0.08), (0.30, 0.22), (0.22, 0.34), (0.26, 0.44), (0.20, 0.55)]
    parts = [P.lathe(profile, segs=18, close_bottom=True, close_top=True)]
    for i in range(6):
        a = TAU * i / 6
        bm = P.cylinder(0.085, 0.52 + 0.10 * v, segs=8, axis="X", radius2=0.04)
        bm.transform(Matrix.Rotation(a, 4, "Z") @ T(0.26, 0, 0.26) @ Matrix.Rotation(math.radians(18), 4, "Y"))
        parts.append(bm)
    parts.append(CL.ellipsoid(0.20, 0.20, 0.14, center=(0, 0, 0.32), wobble=0.2, seed=3200 + v))
    return bone_asset(f"bone_vertebra_{'abc'[v]}", parts, target=900 + v * 100, voxel=0.03)


def bone_pile(v: int = 0):
    rng = random.Random(3300 + v)
    parts = []
    for i in range(7 + v):
        ln = rng.uniform(0.7, 2.0)
        bm = P.cylinder(rng.uniform(0.035, 0.075), ln, segs=7, axis="X",
                        radius2=rng.uniform(0.02, 0.045))
        bm.transform(T(rng.uniform(-1.2, 1.2), rng.uniform(-1.0, 1.0), rng.uniform(0.05, 0.25))
                     @ Matrix.Rotation(rng.uniform(-1.2, 1.2), 4, "Z")
                     @ Matrix.Rotation(rng.uniform(-0.5, 0.5), 4, "Y"))
        parts.append(bm)
    bm = L.join_bmeshes([(p, Matrix.Identity(4)) for p in parts])
    name = f"bone_pile_{'abc'[v]}"
    obj = L.object_from_bmesh(name, bm, L.asset_collection(name), "nm_bone_aged")
    L.decimate(obj, 900 + v * 150)
    CL.recenter_base(obj, 0.01)
    L.shade(obj, 36.0)
    CL.bone_mask(obj)
    L.uv_box(obj, 1.0)
    return obj


def bone_shell(v: int = 0):
    bm = CL.fan(0.55 + 0.15 * v, 0.65, thickness=0.055, spread=1.0, ribs=7, nu=18, nv=7, seed=3400 + v)
    name = f"bone_shell_{'abc'[v]}"
    obj = L.object_from_bmesh(name, bm, L.asset_collection(name), "nm_bone_aged")
    L.decimate(obj, 700)
    CL.recenter_base(obj, 0.01)
    L.shade(obj, 60.0)
    CL.bone_mask(obj)
    L.uv_box(obj, 1.0)
    return obj


def ground_patch(v: int = 0, large=False):
    radius = (15.0 if large else 7.0) + 0.5 * v
    rng = random.Random(3500 + v + (10 if large else 0))
    mat = "nm_mud_wet"

    def hfn(x, y, a, t):
        n = noise.noise(Vector((x * 0.35 + v, y * 0.35, 2.2)))
        return -0.10 * smoothstep(0.55, 1.0, t) + 0.025 * n * (1.0 - t) + 0.02 * math.sin(a * 6 + v) * t * (1.0 - t)

    bm = CL.radial_patch(radius, rings=14 if large else 10, segs=56 if large else 40,
                         height_fn=hfn, thickness=0.55, edge_wobble=0.12, seed=3500 + v)
    name = f"ground_patch_large_{'ab'[v]}" if large else f"ground_patch_{'abcd'[v]}"
    obj = L.object_from_bmesh(name, bm, L.asset_collection(name), mat)
    CL.coral_detail(obj, 3600 + v, radius, amp=0.012, ridge=0.0, micro=0.005)
    L.decimate(obj, 9000 if large else 4500)
    CL.recenter_base(obj, 0.02)
    L.shade(obj, 45.0)
    CL.bake_coral_mask(obj, seed=3600 + v, rays=5, ao_dist=0.9, flat_wet=0.55, tip_start=0.95)
    L.uv_box(obj, 1.0)
    # Обломки и ракушки по краю — не «ковёр».
    for i in range(7 if large else 4):
        a = TAU * i / (7 if large else 4) + rng.uniform(-0.4, 0.4)
        r = radius * rng.uniform(0.75, 0.98)
        bm2 = CL.ellipsoid(rng.uniform(0.25, 0.55), rng.uniform(0.22, 0.5), rng.uniform(0.18, 0.35),
                           center=(r * math.cos(a), r * math.sin(a), 0.12),
                           wobble=0.4, seed=3700 + i + v * 5)
        _detail(obj.users_collection[0], f"detail_rubble_{i}", bm2, "nm_coral_dead",
                mask=(0.8, 0.15, 0.55, 0.20))
    return obj


def mud_pool(v: int = 0):
    radius = 2.2 + 0.5 * v

    def hfn(x, y, a, t):
        return -0.22 * (1.0 - t * t) + 0.05 * math.sin(a * 5 + v) * t

    bm = CL.radial_patch(radius, rings=8, segs=36, height_fn=hfn, thickness=0.3,
                         edge_wobble=0.15, seed=3800 + v)
    name = f"mud_pool_{'abc'[v]}"
    obj = L.object_from_bmesh(name, bm, L.asset_collection(name), "nm_mud_wet")
    L.decimate(obj, 1800)
    CL.recenter_base(obj, 0.02)
    L.shade(obj, 45.0)
    CL.bake_coral_mask(obj, seed=3800 + v, rays=4, ao_dist=0.8, flat_wet=0.9, tip_start=0.95)
    L.uv_box(obj, 1.0)
    return obj


def mud_bank(v: int = 0):
    parts = []
    rng = random.Random(3900 + v)
    for i in range(4):
        parts.append(CL.ellipsoid(rng.uniform(0.9, 1.5), rng.uniform(0.7, 1.1), rng.uniform(0.45, 0.8),
                                  center=(-3.0 + i * 2.0, rng.uniform(-0.2, 0.2), 0.5),
                                  wobble=0.35, seed=3910 + i + v))
    bm = L.join_bmeshes([(p, Matrix.Identity(4)) for p in parts])
    name = f"mud_bank_{'ab'[v]}"
    obj = L.object_from_bmesh(name, bm, L.asset_collection(name), "nm_mud_wet")
    CL.coral_detail(obj, 4000 + v, 3.0, amp=0.025, ridge=0.0, micro=0.008)
    L.decimate(obj, 2800)
    CL.recenter_base(obj, 0.02)
    L.shade(obj, 45.0)
    CL.bake_coral_mask(obj, seed=4000 + v, rays=5, ao_dist=0.9, flat_wet=0.65, tip_start=0.9)
    L.uv_box(obj, 1.0)
    return obj


def campfire(v: int = 0):
    coll = L.asset_collection("campfire_a")
    rng = random.Random(4100 + v)
    stones = []
    for i in range(10):
        a = TAU * i / 10
        stones.append(CL.ellipsoid(rng.uniform(0.14, 0.25), rng.uniform(0.13, 0.22), rng.uniform(0.10, 0.18),
                                   center=(math.cos(a) * 1.0, math.sin(a) * 1.0, 0.12),
                                   wobble=0.35, seed=4110 + i, segs=10, rings=6))
    bm = L.join_bmeshes([(p, Matrix.Identity(4)) for p in stones])
    obj = L.object_from_bmesh("campfire_stones", bm, coll, "nm_coral_dead")
    L.shade(obj, 50.0)
    L.plain_masks(obj, (0.9, 0.10, 0.45, 0.20))
    L.uv_box(obj, 1.0)
    logs = []
    for i in range(3):
        bm = P.cylinder(0.075, 1.25, segs=8, axis="X", radius2=0.06)
        bm.transform(T(0, 0, 0.12) @ Matrix.Rotation(TAU * i / 3, 4, "Z") @ Matrix.Rotation(math.radians(8), 4, "Y"))
        logs.append(bm)
    bm = L.join_bmeshes([(p, Matrix.Identity(4)) for p in logs])
    obj = L.object_from_bmesh("campfire_logs", bm, coll, "nm_wood_dark")
    L.uv_box(obj, 1.0)
    L.shade(obj, 40.0)
    L.plain_masks(obj, (1.0, 1.0, 1.0, 1.0))
    bm = CL.radial_patch(0.75, rings=6, segs=24, height_fn=lambda x, y, a, t: 0.02 * (1 - t),
                         thickness=0.06, edge_wobble=0.1, seed=4120)
    obj = L.object_from_bmesh("campfire_ash", bm, coll, "nm_charcoal")
    L.uv_box(obj, 1.0)
    L.shade(obj, 50.0)
    L.plain_masks(obj, (1.0, 1.0, 1.0, 1.0))
    return obj


def bedroll(v: int = 0):
    coll = L.asset_collection(f"bedroll_{'abc'[v]}")
    parts = [CL.ellipsoid(0.62, 0.26, 0.12, center=(0, 0, 0.12), wobble=0.10, seed=4200 + v, segs=20, rings=10)]
    parts.append(P.cylinder(0.16, 1.25, segs=12, axis="X", radius2=0.14))
    bm = L.join_bmeshes([(p, Matrix.Identity(4)) for p in parts])
    obj = L.object_from_bmesh(f"bedroll_{'abc'[v]}", bm, coll, "nm_linen")
    L.uv_box(obj, 1.0)
    L.shade(obj, 35.0)
    L.plain_masks(obj, (1.0, 1.0, 1.0, 1.0))
    for i in range(2):
        bm = P.board(0.08, 1.2, 0.03, bevel=0.005)
        bm.transform(T(-0.3 + 0.6 * i, 0, 0.24))
        obj2 = L.object_from_bmesh(f"strap_{i}", bm, coll, "nm_leather")
        L.uv_box(obj2, 1.0)
        L.shade(obj2, 35.0)
        L.plain_masks(obj2, (1.0, 1.0, 1.0, 1.0))
    return obj


def windbreak(v: int = 0):
    coll = L.asset_collection(f"windbreak_{'ab'[v]}")
    parts = []
    for x in (-1.3, 1.3):
        bm = P.cylinder(0.06, 2.2, segs=8, axis="Z")
        bm.transform(T(x, 0, 1.1))
        parts.append(bm)
    bm = L.join_bmeshes([(p, Matrix.Identity(4)) for p in parts])
    obj = L.object_from_bmesh(f"windbreak_posts_{'ab'[v]}", bm, coll, "nm_wood_dark")
    L.uv_box(obj, 1.0)
    L.shade(obj, 35.0)
    L.plain_masks(obj, (1.0, 1.0, 1.0, 1.0))
    bm = P.board(2.7, 0.08, 1.6, bevel=0.03, warp=0.08, seed=4300 + v)
    bm.transform(T(0, -0.1, 1.25) @ Matrix.Rotation(math.radians(12), 4, "X"))
    obj = L.object_from_bmesh(f"windbreak_hide_{'ab'[v]}", bm, coll, "nm_linen" if v == 0 else "nm_leather")
    L.uv_box(obj, 1.0)
    L.shade(obj, 35.0)
    L.plain_masks(obj, (1.0, 1.0, 1.0, 1.0))
    return obj


def _column(height, base_r, top_r, offset=(0.0, 0.0), lean=(0.0, 0.0), seed=0):
    rings = []
    for i in range(11):
        t = i / 10.0
        z = height * t
        r = base_r * (1.0 - t) + top_r * t + 0.30 * math.sin(t * 5.0 + seed)
        lx = offset[0] + lean[0] * t
        ly = offset[1] + lean[1] * t
        ring = []
        for k in range(20):
            a = TAU * k / 20
            rr = r * (1.0 + 0.13 * math.sin(5 * a + t * 7 + seed) + 0.06 * math.sin(9 * a - t * 3))
            ring.append((lx + rr * math.cos(a), ly + rr * math.sin(a), z))
        rings.append(ring)
    return CL.ring_loft(rings)


def pillar(v: int = 0):
    # Гигантский коралловый «бомми»: пучок сросшихся лезвий, а не ствол с ветками.
    height = 36.0 if v == 0 else 40.0
    parts = []
    rng = random.Random(4400 + v)
    # Широкое основание.
    for i in range(6):
        a = TAU * i / 6 + 0.3
        parts.append(CL.ellipsoid(rng.uniform(2.2, 3.2), rng.uniform(2.0, 2.8), rng.uniform(1.8, 2.8),
                                  center=(math.cos(a) * rng.uniform(2.0, 3.8),
                                          math.sin(a) * rng.uniform(2.0, 3.8), 1.6),
                                  wobble=0.32, seed=4410 + i + v))
    # Пучок вертикальных лезвий разной высоты — главный силуэт.
    for i in range(9):
        a = TAU * i / 9 + v * 0.2
        r = rng.uniform(0.5, 3.0)
        h = height * rng.uniform(0.55, 1.0)
        w = rng.uniform(1.4, 2.8)
        th = rng.uniform(1.0, 2.0)
        bm = CL.blade(h, w, th, curve=(rng.uniform(-0.10, 0.10), rng.uniform(-0.04, 0.04)),
                      seed=4420 + i + v, ridge=0.22, segs=16, rings=14)
        bm.transform(T(math.cos(a) * r, math.sin(a) * r, 0.4) @ Matrix.Rotation(a, 4, "Z"))
        parts.append(bm)
    # Перемычки на разных высотах: слитая масса, а не частокол.
    for i in range(6):
        z = rng.uniform(4.0, 24.0)
        a = TAU * i / 6 + v
        parts.append(CL.ellipsoid(rng.uniform(1.6, 2.6), rng.uniform(1.4, 2.2), rng.uniform(1.0, 1.8),
                                  center=(math.cos(a) * rng.uniform(1.0, 2.6),
                                          math.sin(a) * rng.uniform(1.0, 2.6), z),
                                  wobble=0.34, seed=4430 + i + v))
    # Нависания на верхней трети.
    for i in range(3):
        a = TAU * i / 3 + 0.7
        parts.append(CL.ellipsoid(rng.uniform(2.0, 3.2), rng.uniform(1.8, 2.6), rng.uniform(0.9, 1.5),
                                  center=(math.cos(a) * rng.uniform(2.2, 3.5),
                                          math.sin(a) * rng.uniform(2.2, 3.5), rng.uniform(18.0, 28.0)),
                                  wobble=0.28, seed=4440 + i + v))
    name = "coral_pillar_camp" if v == 0 else "coral_spire_west"
    obj = CL.fuse(name, parts, L.asset_collection(name), "nm_coral_live",
                  voxel=0.18, target_tris=15000 if v == 0 else 13000, seed=4600 + v,
                  size=12.0, smooth_iter=1, tip_start=0.28, flat_wet=0.18)
    coll = obj.users_collection[0]
    # Верхние лезвия и веера — отдельно, чтобы не сплавить в «лопату».
    for i in range(7):
        a = TAU * i / 7 + v * 0.3
        hb = rng.uniform(4.0, 9.5)
        bm = CL.blade(hb, rng.uniform(0.55, 1.15), rng.uniform(0.30, 0.55),
                      curve=(rng.uniform(-0.10, 0.10), 0.02), seed=4500 + i + v, ridge=0.22)
        _detail(coll, f"crown_{i}", bm, "nm_coral_live" if i % 4 else "nm_coral_dead",
                mask=(0.9, 0.80, 0.20, 0.05),
                rot=T(math.cos(a) * rng.uniform(0.5, 2.8), math.sin(a) * rng.uniform(0.5, 2.8),
                      height * rng.uniform(0.72, 0.90)) @ Matrix.Rotation(a, 4, "Z"))
    for i in range(4):
        a = TAU * i / 4
        bm = CL.fan(rng.uniform(1.2, 2.2), rng.uniform(1.0, 1.3), thickness=0.09,
                    spread=0.9, ribs=9, nu=18, nv=9, seed=4550 + i + v)
        _detail(coll, f"column_fan_{i}", bm, "nm_coral_live",
                mask=(0.9, 0.25, 0.35, 0.05),
                rot=T(math.cos(a) * rng.uniform(2.4, 4.2), math.sin(a) * rng.uniform(2.4, 4.2),
                      rng.uniform(6.0, 22.0)) @ Matrix.Rotation(a, 4, "Z"))
    coral_details(coll, 4.5, 4700 + v, branches=0, blades=5, brains=2,
                  z_max=10.0, y_span=4.5)
    return obj


def tunnel(v: int = 0):
    length = 6.0
    parts = [CL.tunnel_shell(length, 4.2 + 0.2 * v, 1.55, segs=30, rings=12,
                             bend=0.35 * v, seed=1500 + v)]
    rng = random.Random(1500 + v)
    for i in range(5):
        a = TAU * i / 5 + rng.uniform(-0.3, 0.3)
        y = rng.uniform(-length * 0.42, length * 0.42)
        parts.append(CL.ellipsoid(rng.uniform(0.45, 0.9), rng.uniform(0.8, 1.4), rng.uniform(0.45, 0.9),
                                  center=(math.cos(a) * 4.0, y, 1.55 + math.sin(a) * 3.4),
                                  wobble=0.35, seed=1510 + i))
    bm = L.join_bmeshes([(p, Matrix.Identity(4)) for p in parts])
    name = f"coral_tunnel_shell_{'abc'[v]}"
    obj = L.object_from_bmesh(name, bm, L.asset_collection(name), "nm_coral_live")
    CL.coral_detail(obj, 1600 + v, 5.0, amp=0.018, ridge=0.010, micro=0.005)
    L.decimate(obj, 12000)
    L.shade(obj, 40.0)
    # origin уже на полу полости (z=0); не recenter по min z.
    CL.bake_coral_mask(obj, seed=1600 + v, rays=5, ao_dist=1.2, flat_wet=0.4)
    L.uv_box(obj, 1.0)
    return obj


ASSETS = {
    "wall_tall_a": lambda: wall_tall(0),
    "wall_tall_b": lambda: wall_tall(1),
    "wall_tall_c": lambda: wall_tall(2),
    "wall_low_a": lambda: wall_low(0),
    "wall_low_b": lambda: wall_low(1),
    "wall_low_c": lambda: wall_low(2),
    "mass_a": lambda: mass(0),
    "mass_b": lambda: mass(1),
    "mass_c": lambda: mass(2),
    "mass_d": lambda: mass(3),
    "mass_e": lambda: mass(4),
    "blade_a": lambda: blade_asset(0),
    "blade_b": lambda: blade_asset(1),
    "blade_c": lambda: blade_asset(2),
    "blade_d": lambda: blade_asset(3),
    "blade_hero": blade_hero,
    "ledge_a": lambda: ledge(0),
    "ledge_b": lambda: ledge(1),
    "ledge_c": lambda: ledge(2),
    "ledge_d": lambda: ledge(3),
    "ramp_a": lambda: ramp(0),
    "ramp_b": lambda: ramp(1),
    "ramp_c": lambda: ramp(2),
    "arch_a": lambda: arch(0),
    "arch_b": lambda: arch(1),
    "arch_c": lambda: arch(2),
    "tunnel_a": lambda: tunnel(0),
    "tunnel_b": lambda: tunnel(1),
    "tunnel_c": lambda: tunnel(2),
    "bone_rib_a": lambda: rib(0),
    "bone_rib_b": lambda: rib(1),
    "bone_rib_c": lambda: rib(2),
    "bone_vertebra_a": lambda: vertebra(0),
    "bone_vertebra_b": lambda: vertebra(1),
    "bone_vertebra_c": lambda: vertebra(2),
    "bone_pile_a": lambda: bone_pile(0),
    "bone_pile_b": lambda: bone_pile(1),
    "bone_pile_c": lambda: bone_pile(2),
    "bone_shell_a": lambda: bone_shell(0),
    "bone_shell_b": lambda: bone_shell(1),
    "bone_shell_c": lambda: bone_shell(2),
    "ground_patch_a": lambda: ground_patch(0),
    "ground_patch_b": lambda: ground_patch(1),
    "ground_patch_c": lambda: ground_patch(2),
    "ground_patch_d": lambda: ground_patch(3),
    "ground_patch_large_a": lambda: ground_patch(0, large=True),
    "ground_patch_large_b": lambda: ground_patch(1, large=True),
    "mud_pool_a": lambda: mud_pool(0),
    "mud_pool_b": lambda: mud_pool(1),
    "mud_pool_c": lambda: mud_pool(2),
    "mud_bank_a": lambda: mud_bank(0),
    "mud_bank_b": lambda: mud_bank(1),
    "campfire_a": lambda: campfire(0),
    "bedroll_a": lambda: bedroll(0),
    "bedroll_b": lambda: bedroll(1),
    "bedroll_c": lambda: bedroll(2),
    "windbreak_a": lambda: windbreak(0),
    "windbreak_b": lambda: windbreak(1),
    "coral_pillar_camp": lambda: pillar(0),
    "coral_spire_west": lambda: pillar(1),
}


def normalize_name(name: str) -> str:
    return name.strip().lower()


def selected_names() -> list[str]:
    names = []
    for arg in sys.argv:
        if arg.startswith("--only="):
            names = [normalize_name(n) for n in arg.split("=", 1)[1].split(",") if n.strip()]
    return names


def setup_scene():
    L.clear_data()
    L.register_materials(CM.MATERIALS, CM.TEXSETS)
    L.setup_render(res=(1280, 720), samples=28, sun_elev=24.0, sun_az=-38.0,
                   sun_power=3.6, sky=(0.24, 0.26, 0.29), sky_strength=1.0)
    scene = bpy.context.scene
    scene.view_settings.exposure = 0.35
    sun = bpy.data.lights.get("PreviewSun")
    if sun is not None:
        sun.color = (0.78, 0.84, 0.95)
    try:
        scene.render.engine = "BLENDER_EEVEE"
        scene.eevee.taa_render_samples = 32
    except Exception:
        pass
    L.preview_collection()
    L.ground(size=50.0, z=-0.02, snow=False)
    for name, spec in CM.MATERIALS.items():
        CL.preview_material(name, spec, CM.TEXSETS)


def render_preview(names: list[str], out_path: Path):
    objs = []
    for name in names:
        coll = bpy.data.collections.get(name)
        if coll is not None:
            objs.append(coll)
    if not objs:
        return
    if len(objs) == 1:
        # Оригинал уже стоит в начале координат; ставим манекен рядом.
        target = [o for o in objs[0].all_objects if o.type == "MESH"]
        CL_man = L.mannequin(location=(max(2.0, 0.6 * max(1.0, objs[0].objects[0].dimensions.x)), 0, 0))
        target.append(CL_man)
        L.frame_camera(target, direction=(-1.0, -1.45, 0.52), lens=48.0, margin=1.12)
    else:
        placed, _ = L.lineup(objs, spacing=1.4, axis="X", start=0.0)
        L.mannequin(location=(0, max(2.0, 0.0), 0))
        L.frame_camera(placed, direction=(-1.0, -1.5, 0.55), lens=45.0, margin=1.15)
    L.render(out_path)
    if len(objs) == 1:
        # Крупный план: проверка пор/нормалей/мокроты, а не только силуэта.
        cam_data = bpy.data.cameras.get("CloseCam") or bpy.data.cameras.new("CloseCam")
        cam = bpy.data.objects.get("CloseCam") or bpy.data.objects.new("CloseCam", cam_data)
        if cam.name not in bpy.context.scene.collection.objects:
            bpy.context.scene.collection.objects.link(cam)
        cam_data.lens = 55.0
        cam.location = (1.2, -7.5, 4.8)
        target = Vector((0.0, 0.0, 5.2))
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        bpy.context.scene.camera = cam
        L.render(out_path.with_name(out_path.stem + "_close.jpg"))


def merge_collection(coll):
    """Склеить визуальные меши ассета в один объект с несколькими слотами материалов."""
    objs = [o for o in coll.objects if o.type == "MESH"]
    if len(objs) < 2:
        return objs[0] if objs else None
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    merged = bpy.context.view_layer.objects.active
    merged.name = coll.name
    return merged


def main():
    args = sys.argv
    names = selected_names()
    if "--list" in args:
        print("\n".join(sorted(ASSETS)))
        return
    if not names:
        names = sorted(ASSETS)
    unknown = [n for n in names if n not in ASSETS]
    if unknown:
        raise SystemExit(f"unknown assets: {unknown}\nknown: {sorted(ASSETS)}")
    setup_scene()
    built = []
    for name in names:
        print("BUILD", name)
        obj = ASSETS[name]()
        coll = obj.users_collection[0]
        merge_collection(coll)
        built.append(coll.name)
        if "--no-export" not in args:
            L.export_collection(coll, OUT / f"{coll.name}.glb")
    L.set_assets_visible(True)
    test = None
    for i, a in enumerate(args):
        if a.startswith("--test="):
            test = a.split("=", 1)[1]
        elif a == "--test" and i + 1 < len(args):
            test = args[i + 1]
    if test:
        path = Path(test)
        if not path.is_absolute():
            path = L.ROOT / path
        render_preview(built, path)
    L.save_blend(L.SOURCE_DIR / "coral_kit.blend")
    print("DONE", len(built), "assets")


if __name__ == "__main__":
    main()

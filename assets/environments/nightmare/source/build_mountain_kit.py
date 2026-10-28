"""Партия 1 — горный набор Первого Кошмара: скалы, кромки обрыва, старая дорога, валуны,
осыпь, снежные надувы, дальние вершины.

Запуск из корня проекта (Blender 5.1, в фоне):
    blender -b --factory-startup --python assets/environments/nightmare/source/build_mountain_kit.py -- [опции]

Опции:
    --only boulders,cliffs,...  собрать только эти группы (по умолчанию — все)
    --test <файл.jpg>           быстрый крупный план собранного, без экспорта и .blend
    --no-export                 не писать .glb
Результат: `source/mountain_kit.blend`, `mountain/*.glb`, превью в `docs/art/previews/nightmare/`.

Канон и арт-решения по каждому ассету — `docs/art/location_asset_matrix.md`.
Координаты: вперёд по дороге +Y Blender (−Z Godot); скальная стена справа (+X),
обрыв слева (−X) — как в гл. 2 («справа отвесная скала, слева бездна»). Зеркальная
раскладка получается поворотом модуля на 180° вокруг вертикали.
"""

import math
import random
import sys
import time
from pathlib import Path

SRC = Path(__file__).resolve().parent
if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))

import importlib  # noqa: E402

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import nm_lib as L  # noqa: E402

importlib.reload(L)

OUT_DIR = L.NM_DIR / "mountain"
I = Matrix.Identity(4)


def rot(deg, axis):
    return Matrix.Rotation(math.radians(deg), 4, axis)


# --------------------------------------------------------------------------------------
# Валуны (C. природное окружение) — шесть разных силуэтов, не масштабные копии
# --------------------------------------------------------------------------------------
def _boulder_finish(obj, seed, ao=1.2, conv=True):
    L.bake_masks(obj, seed=seed, rays=24, ao_dist=ao)
    L.finalize(obj, sharp_deg=52)
    if conv:
        L.collision_convex(obj, max_verts=48)
    return obj


def boulder_rounded():
    """Окатанный выветренный валун: мало сколов, сглаженные рёбра."""
    name, seed = "boulder_rounded_a", 101
    coll = L.asset_collection(name)
    parts = [(L.hull_chunk(seed, (2.1, 1.7, 1.35), npts=56, cuts=3, cut_depth=(0.7, 0.9)), I)]
    obj = L.rock_object(name, parts, coll, voxel=0.035, smooth_iter=6, seed=seed, size=1.6,
                        detail=dict(large=0.07, medium=0.016, fine=0.004, crack_depth=0.012),
                        base_z=0.18, sink=0.12, target_tris=2200)
    return [_boulder_finish(obj, seed)]


def boulder_angular():
    """Свежий угловатый обломок камнепада: много плоскостей раскола, острые рёбра."""
    name, seed = "boulder_angular_a", 202
    coll = L.asset_collection(name)
    parts = [(L.hull_chunk(seed, (1.6, 1.3, 1.1), npts=40, cuts=9, cut_depth=(0.5, 0.8)), rot(14, "Y"))]
    obj = L.rock_object(name, parts, coll, voxel=0.025, smooth_iter=1, seed=seed, size=1.2,
                        detail=dict(large=0.025, medium=0.01, fine=0.004, crack_depth=0.0),
                        base_z=0.12, sink=0.08, target_tris=1800, sharp=40)
    return [_boulder_finish(obj, seed)]


def boulder_slab():
    """Плитчатый валун: слоистая плита, отколовшаяся от стены вдоль напластования."""
    name, seed = "boulder_slab_a", 303
    coll = L.asset_collection(name)
    parts = [(L.hull_chunk(seed, (2.7, 1.9, 0.75), npts=60, cuts=6, cut_depth=(0.6, 0.88)), rot(6, "X"))]
    obj = L.rock_object(name, parts, coll, voxel=0.03, smooth_iter=2, seed=seed, size=1.4,
                        detail=dict(large=0.04, medium=0.018, fine=0.005, crack_depth=0.02,
                                    strata=(1.0, 1.0, 5.0)),
                        base_z=0.08, sink=0.1, target_tris=2200)
    return [_boulder_finish(obj, seed)]


def boulder_shard():
    """Вертикальный обломок-зуб, наклонённый и вросший в снег."""
    name, seed = "boulder_shard_a", 404
    coll = L.asset_collection(name)
    parts = [(L.hull_chunk(seed, (1.0, 0.85, 2.7), npts=48, cuts=7, cut_depth=(0.55, 0.85)), rot(11, "Y") @ rot(-6, "X"))]
    obj = L.rock_object(name, parts, coll, voxel=0.03, smooth_iter=2, seed=seed, size=1.0,
                        detail=dict(large=0.04, medium=0.016, fine=0.005, crack_depth=0.015),
                        base_z=0.25, sink=0.22, target_tris=2000)
    return [_boulder_finish(obj, seed, ao=1.0)]


def boulder_split():
    """Валун, расколотый морозом надвое: две половины с плоскостью свежего раскола."""
    name, seed = "boulder_split_a", 505
    coll = L.asset_collection(name)
    base = L.hull_chunk(seed, (2.0, 1.6, 1.4), npts=56, cuts=4, cut_depth=(0.65, 0.9))
    halves = []
    plane_n = Vector((0.93, 0.3, 0.05)).normalized()
    for side, keep in ((-1, True), (1, False)):
        bm = base.copy()
        geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
        res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, 0), plane_no=plane_n,
                                     clear_outer=keep, clear_inner=not keep)
        L._hull(bm)
        shift = plane_n * (0.11 * side)
        tilt = rot(-4 * side, "Y")
        halves.append((bm, Matrix.Translation(shift) @ tilt))
    base.free()
    obj = L.rock_object(name, halves, coll, voxel=0.025, smooth_iter=3, seed=seed, size=1.5,
                        detail=dict(large=0.05, medium=0.014, fine=0.004, crack_depth=0.01),
                        base_z=0.15, sink=0.12, target_tris=2600)
    L.bake_masks(obj, seed=seed, rays=24, ao_dist=1.2)
    L.finalize(obj, sharp_deg=45)
    # Две выпуклые коллизии — по половине: проход между ними не нужен, но форма честнее.
    L.collision_convex(obj, max_verts=56)
    return [obj]


def rock_outcrop():
    """Низкий выход коренной породы из-под снега: несколько сросшихся глыб, почти вровень с землёй."""
    name, seed = "rock_outcrop_a", 606
    coll = L.asset_collection(name)
    r = random.Random(seed)
    parts = []
    for i, (x, y, s) in enumerate(((0.0, 0.0, 1.0), (1.3, 0.5, 0.75), (-1.1, 0.4, 0.7), (0.4, -0.9, 0.6))):
        bm = L.hull_chunk(seed + i, (2.2 * s, 1.7 * s, 1.5 * s), npts=44, cuts=6)
        parts.append((bm, Matrix.Translation((x, y, -0.15 * (1 - s))) @ rot(r.uniform(-25, 25), "Z") @ rot(r.uniform(-8, 8), "X")))
    obj = L.rock_object(name, parts, coll, voxel=0.04, smooth_iter=3, seed=seed, size=2.0,
                        detail=dict(large=0.04, medium=0.016, fine=0.004, crack_depth=0.02,
                                    strata=(1.0, 1.0, 3.5)),
                        base_z=0.2, sink=0.3, target_tris=3200)
    L.bake_masks(obj, seed=seed, rays=24, ao_dist=1.5)
    L.finalize(obj, sharp_deg=50)
    L.collision_trimesh(obj, target_tris=220)
    return [obj]


# --------------------------------------------------------------------------------------
# Скальные стены (B. модульные элементы): ROCK_A / ROCK_B / ROCK_C брифа тропы
# --------------------------------------------------------------------------------------
def _blocks(seed, count, length, height, out=(-0.9, -0.3), size=((1.8, 2.4), (1.3, 2.6), (2.2, 4.8)),
            z_range=(-0.3, 0.6)):
    """Крупные блоки-контрфорсы на лице стены: ломают плоскость, дают глубокие тени."""
    r = random.Random(seed)
    parts = []
    for i in range(count):
        d = (r.uniform(*size[0]), r.uniform(*size[1]), r.uniform(*size[2]))
        bm = L.hull_chunk(seed + 70 + i, d, npts=14, cuts=5, cut_depth=(0.8, 0.96))
        m = (Matrix.Translation((r.uniform(*out) + d[0] * 0.3, r.uniform(0.5, length - 0.5),
                                 r.uniform(z_range[0], height * z_range[1]) + d[2] / 2))
             @ rot(r.uniform(-12, 12), "Z") @ rot(r.uniform(-5, 5), "Y"))
        parts.append((bm, m))
    return parts


def _wall_finish(obj, seed, ao=3.0, tris_col=600):
    L.bake_masks(obj, seed=seed, rays=20, ao_dist=ao, base_dark=1.2)
    L.finalize(obj, sharp_deg=55, uv_tile=4.0)
    L.collision_trimesh(obj, target_tris=tris_col)
    return obj


def _rock_mass(name, seed, parts, coll, tris, voxel=0.06, back=None):
    obj = L.rock_object(name, parts, coll, voxel=voxel, smooth_iter=1, seed=seed, size=3.0,
                        detail=dict(large=0.012, medium=0.01, fine=0.004, crack_depth=0.012,
                                    strata=(1.0, 1.0, 0.5), crack_scale=1.2),
                        target_tris=tris * 3, sink=0.0)
    zmin = min(v.co.z for v in obj.data.vertices)
    obj.data.transform(Matrix.Translation((0, 0, -0.6 - zmin)))
    L.decimate(obj, tris)
    return obj


def _end_blocks(seed, length, height, depth, overlap=0.4):
    """Рваные торцы: глыбы на концах модуля, чтобы начало и конец ряда не были срезом.
    Внутри ряда они уходят в соседний модуль (нахлёст 0,8 м)."""
    r = random.Random(seed + 900)
    parts = []
    for y_end, sgn in ((-overlap, -1), (length + overlap, 1)):
        z = -0.6
        while z < height - 1.0:
            h = r.uniform(1.6, 3.2)
            d = (depth * r.uniform(0.6, 0.85), r.uniform(1.0, 1.6), h * 1.2)
            bm = L.hull_chunk(r.randrange(1 << 30), d, npts=14, cuts=5, cut_depth=(0.8, 0.96))
            parts.append((bm, Matrix.Translation((d[0] / 2 + r.uniform(-0.2, 0.4), y_end + sgn * r.uniform(0.0, 0.35),
                                                  z + h / 2)) @ rot(r.uniform(-10, 10), "Z")))
            z += h * r.uniform(0.75, 0.95)
    return parts


def _wall(name, seed, length=6.0, height=12.0, depth=4.0, tris=9000, blocks=3, sheet=None, extra_parts=()):
    coll = L.asset_collection(name)
    sheet = dict(sheet or {})
    parts = [(L.facet_sheet(seed, length + 0.8, height, depth, **sheet), I)]
    parts += _blocks(seed, blocks, length, height)
    parts += _end_blocks(seed, length, height, depth)
    parts += list(extra_parts)
    return _rock_mass(name, seed, parts, coll, tris), coll


def rock_wall_a():
    """ROCK_A: длинная стена 6 м по дороге, ~12 м высотой: крупные грани, полки под снег."""
    obj, _ = _wall("rock_wall_a", 1001, sheet=dict(cell=(2.8, 1.5), relief=0.7, tilt=0.35, macro=0.9))
    return [_wall_finish(obj, 1001)]


def rock_wall_b():
    """ROCK_A, вариант: тонкие пласты с сильным падением, ниже, больше вертикальных трещин."""
    obj, _ = _wall("rock_wall_b", 1002, height=10.0, blocks=2,
                   sheet=dict(cell=(2.4, 0.6), relief=0.4, tilt=0.6, joints=0.5, macro=0.9))
    return [_wall_finish(obj, 1002)]


def rock_overhang_b():
    """ROCK_B: выступ-«зуб» с навесом над тропой: сужает проход и прячет поворот."""
    name, seed = "rock_overhang_b", 1101
    coll = L.asset_collection(name)
    r = random.Random(seed)
    parts = [(L.facet_sheet(seed, 4.8, 10.0, 3.4, cell=(1.5, 1.1), relief=0.5, tilt=0.45), I)]
    # Выступающий массив: глыбы, всё дальше выдвинутые к дороге с высотой — навес на 3–5 м.
    for i, (z, h, out) in enumerate(((0.0, 2.6, -0.5), (2.3, 2.2, -1.2), (4.0, 2.2, -1.9), (5.8, 2.6, -1.4))):
        bm = L.hull_chunk(seed + 10 + i, (2.8, 2.6, h * 1.25), npts=34, cuts=7, cut_depth=(0.75, 0.95))
        parts.append((bm, Matrix.Translation((1.3 + out, 2.2 + r.uniform(-0.3, 0.3), z + h / 2))
                      @ rot(r.uniform(-8, 8), "Z")))
    obj = _rock_mass(name, seed, parts, coll, 8000)
    return [_wall_finish(obj, seed)]


def rock_wall_broken_c():
    """ROCK_C: обрушенный участок стены — вогнутый шрам отрыва и глыбы у основания."""
    name, seed = "rock_wall_broken_c", 1201
    coll = L.asset_collection(name)
    r = random.Random(seed)

    def scar(y, z):
        # Ниша отрыва: эллипс по лицу, вглубь до 1,3 м.
        t = ((y - 2.5) / 1.6) ** 2 + ((z - 3.0) / 2.4) ** 2
        return 1.3 * max(0.0, 1.0 - t) ** 0.6

    parts = [(L.facet_sheet(seed, 5.8, 7.5, 3.6, cell=(1.2, 0.8), relief=0.45, tilt=0.5, extra=scar), I)]
    for i in range(7):
        s = r.uniform(0.5, 1.3)
        bm = L.hull_chunk(seed + 50 + i, (s * 1.3, s * 1.1, s * 0.9), npts=30, cuts=8, cut_depth=(0.55, 0.85))
        parts.append((bm, Matrix.Translation((r.uniform(-1.0, 0.4), r.uniform(0.8, 4.2), s * 0.25 - 0.55))
                      @ rot(r.uniform(0, 360), "Z") @ rot(r.uniform(-25, 25), "X")))
    obj = _rock_mass(name, seed, parts, coll, 7000, voxel=0.05)
    return [_wall_finish(obj, seed, ao=2.5)]


# --------------------------------------------------------------------------------------
# Старая дорога (B. модульные элементы): TRAIL_ICE брифа тропы — 4 × 2,5 м
# --------------------------------------------------------------------------------------
ROAD_L, ROAD_HW, END_BAND = 4.0, 1.25, 0.8


def _road_sites(seed, min_d=0.5):
    """Центры плит: общие полосы на концах модуля одинаковы у всех вариантов — швы совпадают."""
    start = L.poisson_2d(random.Random(7001), -ROAD_HW, ROAD_HW, 0.0, END_BAND, min_d)
    end = L.poisson_2d(random.Random(7002), -ROAD_HW, ROAD_HW, ROAD_L - END_BAND, ROAD_L, min_d)
    r = random.Random(seed)
    mid = []
    for _ in range(4000):
        p = Vector((r.uniform(-ROAD_HW, ROAD_HW), r.uniform(END_BAND, ROAD_L - END_BAND)))
        if all((p - q).length >= min_d for q in start + end + mid):
            mid.append(p)
    ghosts = [p - Vector((0, ROAD_L)) for p in end] + [p + Vector((0, ROAD_L)) for p in start]
    return start + mid + end, ghosts


def _periodic(x, y, scale, seed):
    """Шум, периодичный по Y с периодом модуля: поверхность стыкуется с соседом."""
    a = 2 * math.pi * y / ROAD_L
    rad = ROAD_L / (2 * math.pi) * scale
    return L.noise.noise(Vector((x * scale + seed * 3.7, math.cos(a) * rad, math.sin(a) * rad)))


def _road(name, seed, ice=False, cracked=0.0, step=None, missing=0.08, break_y=None):
    """Модуль дороги. break_y — дорога обрывается на этой отметке (провал после камнепада, гл. 9):
    дальше плит нет, часть плит у излома свисает, под изломом — грань скалы до −4 м."""
    coll = L.asset_collection(name)
    r = random.Random(seed)
    end_y = ROAD_L if break_y is None else break_y

    def jag(x):
        return 0.0 if break_y is None else 0.35 * L.noise.noise(Vector((x * 0.9, seed * 0.1, 3.0)))

    def lift(y):
        if not step:
            return 0.0
        y0, h = step
        t = min(1.0, max(0.0, (y - y0 + 0.15) / 0.3))
        return h * t * t * (3 - 2 * t)

    sites, ghosts = _road_sites(seed, min_d=0.52)
    cells = L.voronoi_cells(sites, ghosts, (-ROAD_HW - 0.05, -1.0, ROAD_HW + 0.05, ROAD_L + 1.0))
    bm = bmesh.new()
    for site, poly in zip(sites, cells):
        if len(poly) < 3 or abs(L._poly_area(poly)) < 0.02:
            continue
        if r.random() < missing and END_BAND < site.y < ROAD_L - END_BAND:
            continue  # выпавшая плита — виден утоптанный снег
        c = sum(poly, Vector((0, 0))) / len(poly)
        hang = 0.0
        if break_y is not None:
            over = c.y - (break_y + jag(c.x))
            if over > 0.45 or (over > 0.0 and r.random() < 0.5):
                continue
            hang = max(0.0, over + 0.25)  # плиты у излома осели и наклонились в провал
        worn = max(0.0, 1.0 - abs(c.x) / 0.9)  # центр полосы стёрт ногами
        top = r.uniform(-0.012, 0.03) - 0.012 * worn - 0.35 * hang
        if r.random() < 0.1:
            top -= 0.045  # просевшая плита
        top += lift(c.y)
        tilt = (r.uniform(-0.03, 0.03) * (1 - worn * 0.6), r.uniform(-0.03, 0.03) * (1 - worn * 0.6) - 0.8 * hang)
        base_poly = L.chamfer_poly(L.shrink_poly(poly, r.uniform(0.012, 0.022)), r.uniform(0.015, 0.035))
        pieces = [base_poly]
        if cracked and r.random() < cracked:
            # Трещина: плита раскололась по линии через центр, половины чуть смещены.
            ang = r.uniform(0, math.pi)
            n = Vector((math.cos(ang), math.sin(ang)))
            a = L._clip(base_poly, c - n * 0.01, c + n * 0.01)
            b = L._clip(base_poly, c + n * 0.01, c - n * 0.01)
            pieces = [p for p in (a, b) if len(p) >= 3]
        for k, piece in enumerate(pieces):
            ph = r.uniform(0, 100)
            L.slab_from_poly(bm, piece, top - 0.012 * k, -0.24, bevel=r.uniform(0.014, 0.03), tilt=tilt,
                             center=c, dome=r.uniform(0.004, 0.014) * (1 + worn),
                             jitter=lambda p, ph=ph: 0.006 * L.noise.noise(Vector((p.x * 6, p.y * 6, ph))))
    stones = L.object_from_bmesh(name + "_stones", bm, coll, "nm_stone_worked")
    # Утоптанный снег между плитами: сток к краям, тот же периодический шум по Y.
    base = L.grid_surface(name + "_base", coll, -ROAD_HW - 0.1, ROAD_HW + 0.1, 0.0, end_y - 0.35, 26, 40,
                          lambda x, y: -0.03 + 0.012 * _periodic(x, y, 1.6, seed) - 0.02 * (abs(x) / ROAD_HW) ** 2
                          + lift(y), "nm_snow", z_bottom=-0.5)
    # Рыхлый снег у стены (справа, +X): вал, закрывающий стык с основанием скалы.
    berm = L.grid_surface(name + "_berm", coll, 0.7, ROAD_HW + 0.25, 0.0, end_y - 0.4, 8, 40,
                          lambda x, y: -0.04 + lift(y) + (0.12 + 0.1 * _periodic(x, y, 0.9, seed + 5))
                          * max(0.0, (x - 0.7) / (ROAD_HW + 0.25 - 0.7)) ** 1.6, "nm_snow", z_bottom=-0.3)
    # Наносы снега поверх плит: больше у стены, реже на утоптанной середине.
    sbm = bmesh.new()
    for k in range(r.randint(4, 6)):
        cx = r.choice((r.uniform(0.2, 1.1), r.uniform(-1.1, -0.4), r.uniform(-0.3, 0.9)))
        cy = r.uniform(0.5, end_y - 0.6)
        L.snow_patch(sbm, cx, cy, r.uniform(0.25, 0.6), r.uniform(0.35, 0.9), r.uniform(0.03, 0.07),
                     z0=0.0, seed=seed + k, angle=r.uniform(-0.6, 0.6), z_fn=lambda x, y: lift(y))
    patches = L.object_from_bmesh(name + "_snowpatch", sbm, coll, "nm_snow")
    parts = [stones, base, berm, patches]
    occl = [base, berm]
    if break_y is not None:
        # Грань излома: скальная «подошва» дороги, обращённая в провал (+Y), с осыпающимся краем.
        # Лист от −4 до 0 (height у facet_sheet — отметка верха). Лицо уходит под дорогу
        # с глубиной (подрезка: нижние пласты обрушились первыми).
        sheet = L.facet_sheet(seed + 7, ROAD_HW * 2 + 1.4, 0.0, 3.2, cell=(0.9, 0.7), relief=0.3, tilt=0.5,
                              top_var=0.05, macro=0.25, joints=0.3, z0=-4.0, back_x=3.2,
                              extra=lambda y, z: -jag(y - ROAD_HW - 0.3) * 0.8 + 0.3 * max(0.0, -z - 0.3))
        # Поворот −90° вокруг Z: ось листа Y → мировая X, лицо (−X листа) → +Y (в провал).
        sheet.transform(Matrix.Translation((-(ROAD_HW + 0.3), end_y + 0.05, -0.04)) @ rot(-90, "Z"))
        # Клин книзу: боковые грани сходятся, излом не выглядит прямоугольной тумбой.
        for sx in (-1, 1):
            n = Vector((sx, 0.0, -0.3)).normalized()
            res = bmesh.ops.bisect_plane(sheet, geom=list(sheet.verts) + list(sheet.edges) + list(sheet.faces),
                                         plane_co=(sx * (ROAD_HW + 0.35), 0, 0), plane_no=n, clear_outer=True)
            edges = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
            if edges:
                bmesh.ops.holes_fill(sheet, edges=edges, sides=0)
        m = Matrix.Identity(4)
        rock = L.rock_object(name + "_fracture", [(sheet, m)], coll, voxel=0.04, smooth_iter=1, seed=seed,
                             size=1.2, detail=dict(large=0.015, medium=0.012, fine=0.004, crack_depth=0.012),
                             target_tris=5000, sink=0.0)
        zmax = max(v.co.z for v in rock.data.vertices)
        rock.data.transform(Matrix.Translation((0, 0, -0.06 - zmax)))
        L.bake_masks(rock, seed=seed + 3, rays=12, ao_dist=0.8, ground=False, base_dark=0.0, extra_occluders=[stones])
        occl.append(rock)
        parts.append(rock)
    if ice:
        ibm = bmesh.new()
        for k in range(3):
            cx, cy = r.uniform(-0.2, 0.9), r.uniform(0.6, ROAD_L - 0.6)
            rx, ry = r.uniform(0.35, 0.7), r.uniform(0.5, 1.1)
            poly = []
            for i in range(18):
                a = i * 2 * math.pi / 18
                w = 1 + 0.25 * L.noise.noise(Vector((k, a, 0)))
                poly.append(Vector((cx + rx * math.cos(a) * w, cy + ry * math.sin(a) * w)))
            poly = [Vector((min(ROAD_HW - 0.05, p.x), p.y)) for p in poly]
            L.slab_from_poly(ibm, poly, 0.012 + lift(cy), -0.02 + lift(cy), bevel=0.01)
        ice_obj = L.object_from_bmesh(name + "_ice", ibm, coll, "nm_ice")
        parts.append(ice_obj)

    def trodden(co):
        return 0.82 + 0.18 * min(1.0, abs(co.x) / 1.0)

    def snow_aff(co):
        return min(1.0, max(0.12, (abs(co.x) - 0.45) / 0.6))

    L.bake_masks(stones, seed=seed, rays=14, ao_dist=0.35, ground=False, extra_occluders=occl,
                 snow_fn=snow_aff, dirt_fn=lambda co: 0.9 + 0.1 * min(1.0, abs(co.x)), base_dark=0.0)
    for o in parts[1:]:
        if o.name.endswith("_fracture"):
            continue
        L.bake_masks(o, seed=seed + 1, rays=10, ao_dist=0.3, ground=False, extra_occluders=[stones],
                     dirt_fn=trodden, base_dark=0.0, tint_var=0.04)
    obj = L.merge_objects(name, parts, coll)
    L.finalize(obj, sharp_deg=40, uv_tile=2.0)
    if step:
        y0, h = step
        L.collision_profile(coll, name, [0.0, y0 - 0.2, y0 + 0.2, ROAD_L], [0.0, 0.0, h, h], ROAD_HW * 2 + 0.1)
    else:
        L.collision_box(coll, name, (0, end_y / 2, -0.2), (ROAD_HW * 2 + 0.1, end_y, 0.4))
    return [obj]


def camp_platform_a():
    """Площадка стоянки 8 × 12 м (CANON гл. 2–3: «небольшая расчищенная площадка, где дорога
    расширяется»; «где мощёная дорога заканчивается и начинаются острые камни» — там Bloodbane).
    Мостовая в середине, к краям плиты редеют и сменяются острыми обломками в снегу.
    Начало — центр короткой стороны со стороны прихода (y = 0), площадка тянется по +Y."""
    name, seed = "camp_platform_a", 2201
    coll = L.asset_collection(name)
    r = random.Random(seed)
    hw, ln = 4.0, 12.0
    sites = L.poisson_2d(r, -hw, hw, 0.0, ln, 0.55, tries=9000)
    cells = L.voronoi_cells(sites, [], (-hw, 0.0, hw, ln))
    off = Vector((seed * 0.1, seed * 0.2, 0.0))

    def paving(p):
        edge = min(hw - abs(p.x), p.y, ln - p.y)
        return edge + 0.9 * L.noise.noise(Vector((p.x * 0.35, p.y * 0.35, 0.0)) + off)

    bm = bmesh.new()
    rough = []
    for site, poly in zip(sites, cells):
        if len(poly) < 3 or abs(L._poly_area(poly)) < 0.02:
            continue
        c = sum(poly, Vector((0, 0))) / len(poly)
        if paving(c) < 0.7 or r.random() < 0.06:
            if paving(c) < 0.5 and r.random() < 0.85:
                rough.append(c)
            continue
        worn = max(0.0, 1.0 - abs(c.x) / 2.5)
        top = r.uniform(-0.015, 0.025) - 0.01 * worn - (0.04 if r.random() < 0.1 else 0.0)
        tilt = (r.uniform(-0.035, 0.035), r.uniform(-0.035, 0.035))
        poly2 = L.chamfer_poly(L.shrink_poly(poly, r.uniform(0.012, 0.024)), r.uniform(0.015, 0.035))
        ph = r.uniform(0, 100)
        L.slab_from_poly(bm, poly2, top, -0.24, bevel=r.uniform(0.014, 0.03), tilt=tilt, center=c,
                         dome=r.uniform(0.004, 0.012), jitter=lambda p, ph=ph: 0.006 * L.noise.noise(Vector((p.x * 6, p.y * 6, ph))))
    stones = L.object_from_bmesh(name + "_stones", bm, coll, "nm_stone_worked")
    base = L.grid_surface(name + "_base", coll, -hw - 0.3, hw + 0.3, -0.2, ln + 0.2, 40, 60,
                          lambda x, y: -0.03 + 0.03 * L.noise.noise(Vector((x * 0.5, y * 0.5, 1.0)) + off)
                          - 0.05 * max(0.0, abs(x) - hw + 0.4), "nm_snow", z_bottom=-0.5)
    parts = []
    for k, c in enumerate(rough):
        s = r.uniform(0.2, 0.55)
        rb = L.hull_chunk(seed + 100 + k, (s * 1.3, s, s * 1.1), npts=12, cuts=7, cut_depth=(0.45, 0.8))
        parts.append((rb, Matrix.Translation((c.x, c.y, s * 0.2 - 0.05)) @ rot(r.uniform(0, 360), "Z") @ rot(r.uniform(-25, 25), "X")))
    rocks = L.rock_object(name + "_rocks", parts, coll, voxel=0.02, smooth_iter=0, seed=seed, size=0.3,
                          detail=dict(large=0.03, medium=0.012, fine=0.004, crack_depth=0.0), target_tris=6000, sink=0.0)
    zmin = min(v.co.z for v in rocks.data.vertices)
    rocks.data.transform(Matrix.Translation((0, 0, -0.15 - zmin)))
    sbm = bmesh.new()
    for k in range(9):
        L.snow_patch(sbm, r.uniform(-3.5, 3.5), r.uniform(0.5, ln - 0.5), r.uniform(0.4, 1.1), r.uniform(0.5, 1.4),
                     r.uniform(0.04, 0.09), z0=0.0, seed=seed + k, angle=r.uniform(0, 3))
    patches = L.object_from_bmesh(name + "_snowpatch", sbm, coll, "nm_snow")
    parts_o = [stones, base, rocks, patches]
    L.bake_masks(stones, seed=seed, rays=12, ao_dist=0.35, ground=False, extra_occluders=[base, rocks], base_dark=0.0,
                 snow_fn=lambda co: min(1.0, max(0.15, (abs(co.x) - 1.5) / 2.0)))
    L.bake_masks(rocks, seed=seed + 1, rays=12, ao_dist=0.4, ground=False, extra_occluders=[base, stones], base_dark=0.15)
    for o in (base, patches):
        L.bake_masks(o, seed=seed + 2, rays=8, ao_dist=0.3, ground=False, extra_occluders=[stones, rocks], base_dark=0.0,
                     tint_var=0.04, dirt_fn=lambda co: 0.85 + 0.15 * min(1.0, abs(co.x) / 3.0))
    obj = L.merge_objects(name, parts_o, coll)
    L.finalize(obj, sharp_deg=40, uv_tile=2.0)
    L.collision_box(coll, name, (0, ln / 2, -0.2), (hw * 2, ln, 0.4))
    return [obj]


def road_old_01():
    """Старая мостовая: плиты разного размера, утоптанная полоса посередине, снег у стены."""
    return _road("road_old_01", 2101)


def road_old_02_ice():
    """Трещиноватые плиты и ледяная корка (зона «Лёд под снегом» брифа тропы)."""
    return _road("road_old_02_ice", 2102, ice=True, cracked=0.35, missing=0.12)


def road_old_03_step():
    """Уступ +0,2 м посередине модуля (подъём тропы); конец модуля на высоте +0,2."""
    return _road("road_old_03_step", 2103, step=(2.0, 0.2), cracked=0.15)


# --------------------------------------------------------------------------------------
# Кромка обрыва (B. модульные элементы): CLIFF_A / CLIFF_B брифа тропы — 5 м по дороге
# --------------------------------------------------------------------------------------
EDGE_L = 5.0


def _edge(name, seed, collapsed=False, teeth=0, cornice=0.28):
    """Кромка слева от дороги (−X): лицо обрыва из граней раскола смотрит в пропасть,
    верх на −0,05 м под полотном, снежный карниз нависает над краем.
    Нижняя часть обрыва не моделируется глубже 8 м — дальше туман/метель (бриф, §8)."""
    coll = L.asset_collection(name)
    r = random.Random(seed)

    def lip_shift(y):
        s = 0.22 * L.noise.noise(Vector((y * 0.55, seed * 0.13, 0.5)))
        if collapsed:
            s += 0.85 * max(0.0, 1.0 - ((y - 2.5) / 1.5) ** 2) ** 0.7
        return s

    sheet = L.facet_sheet(seed, EDGE_L + 0.8, 7.95, 1.1, cell=(1.3, 1.0), relief=0.35, tilt=0.5,
                          top_var=0.04, macro=0.35, joints=0.3, z0=-8.0, back_x=1.15,
                          extra=lambda y, z: lip_shift(y))
    parts = [(sheet, Matrix.Translation((-2.0, 0, 0)))]
    for k in range(teeth):
        h = r.uniform(0.35, 0.7)
        bm = L.hull_chunk(seed + 40 + k, (0.7, r.uniform(0.6, 1.1), h * 2), npts=16, cuts=5, cut_depth=(0.75, 0.95))
        y = r.uniform(0.6, EDGE_L - 0.6)
        parts.append((bm, Matrix.Translation((-2.0 + lip_shift(y) + 0.25, y, -0.05)) @ rot(r.uniform(-15, 15), "Z")))
    if collapsed:
        # Обломки кромки на изломе.
        for k in range(4):
            s = r.uniform(0.3, 0.6)
            bm = L.hull_chunk(seed + 60 + k, (s * 1.4, s * 1.2, s), npts=16, cuts=6, cut_depth=(0.6, 0.9))
            y = r.uniform(1.6, 3.4)
            parts.append((bm, Matrix.Translation((-2.0 + lip_shift(y) + r.uniform(0.2, 0.5), y, -0.12))
                          @ rot(r.uniform(0, 360), "Z") @ rot(r.uniform(-20, 20), "X")))
    rock = L.rock_object(name + "_rock", parts, coll, voxel=0.045, smooth_iter=1, seed=seed, size=1.5,
                         detail=dict(large=0.015, medium=0.012, fine=0.004, crack_depth=0.012,
                                     strata=(1.0, 1.0, 0.5)),
                         target_tris=6500, sink=0.0)
    zmax = max(v.co.z for v in rock.data.vertices if v.co.x > -1.6)
    rock.data.transform(Matrix.Translation((0, 0, -0.05 - zmax)))  # верх под полотном
    # Снежный карниз: сечение-«капля» с навесом над кромкой, толщина и вынос шумят по Y.
    ys = [-0.3 + (EDGE_L + 0.6) * i / 60 for i in range(61)]

    def profile(y):
        lx = -2.0 + lip_shift(y) - 0.05
        n = L.noise.noise(Vector((y * 0.9, seed * 0.2, 2.0)))
        over = max(0.05, cornice * (1.0 + 0.6 * n))
        th = 0.16 + 0.07 * n
        return [(-0.95, -0.03), (-1.45, 0.05 + 0.02 * n), (lx + 0.35, th), (lx + 0.02, th * 0.75),
                (lx - over, 0.0), (lx - over * 0.55, -th * 0.9), (lx + 0.25, -0.14), (-1.45, -0.09)]

    sbm = L.sweep(bmesh.new(), profile, ys)
    snow = L.object_from_bmesh(name + "_cornice", sbm, coll, "nm_snow")
    L.smooth(snow, 0.5, 2)
    L.bake_masks(rock, seed=seed, rays=16, ao_dist=1.2, ground=False, base_dark=0.0, extra_occluders=[snow])
    L.bake_masks(snow, seed=seed + 1, rays=12, ao_dist=0.6, ground=False, base_dark=0.0, extra_occluders=[rock],
                 tint_var=0.03)
    obj = L.merge_objects(name, [rock, snow], coll)
    L.finalize(obj, sharp_deg=50, uv_tile=3.0)
    L.collision_trimesh(obj, target_tris=500)
    return [obj]


def cliff_edge_a1():
    """CLIFF_A: непрерывная кромка с ровным карнизом."""
    return _edge("cliff_edge_a1", 3101)


def cliff_edge_a2():
    """CLIFF_A, вариант: рваная кромка с каменными зубьями и неровным навесом."""
    return _edge("cliff_edge_a2", 3102, teeth=3, cornice=0.38)


def cliff_edge_collapsed_b():
    """CLIFF_B: обрушенный участок — кромка отступила к дороге, обломки на изломе."""
    return _edge("cliff_edge_collapsed_b", 3201, collapsed=True, cornice=0.18)


# --------------------------------------------------------------------------------------
# Снежные надувы (C. природное окружение): форма объясняет ветер — пологий хвост,
# крутой подветренный срыв (бриф перевала, §4). Ветер условно вдоль +Y.
# --------------------------------------------------------------------------------------
def _smooth01(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def _drift(name, seed, sx, sy, height_fn, nx, ny, collide=True):
    coll = L.asset_collection(name)
    off = Vector((seed * 0.37, seed * 0.11, 0.0))

    def h(x, y):
        base = height_fn(x / sx, y / sy)
        rip = 0.035 * L.noise.noise(Vector((x * 1.8, y * 0.7, 0.0)) + off) * min(1.0, base * 4)
        return max(-0.02, base + rip) - 0.02

    obj = L.grid_surface(name, coll, -sx, sx, -sy, sy, nx, ny, h, "nm_snow", z_bottom=-0.25)
    L.smooth(obj, 0.4, 1)
    L.bake_masks(obj, seed=seed, rays=12, ao_dist=0.8, base_dark=0.0, tint_var=0.04)
    L.finalize(obj, sharp_deg=70, uv_tile=2.0)
    if collide:
        L.collision_convex(obj, max_verts=40)
    return [obj]


def snow_drift_low_a():
    """Длинный низкий надув с ветровым хвостом (3 × 1,2 м, до 0,45 м)."""
    def f(u, v):
        t = (u + 1) / 2
        along = t ** 0.7 * (1 - _smooth01((t - 0.78) / 0.22))
        return 0.45 * along * max(0.0, 1 - v * v) ** 1.4
    return _drift("snow_drift_low_a", 4101, 1.5, 0.6, f, 40, 18)


def snow_drift_wall_b():
    """Высокий надув у подножия стены (4 × 2 м, до 1,4 м): плоский тыл ставится к скале (+X)."""
    def f(u, v):
        t = (u + 1) / 2
        along = 1 - abs(v) ** 3
        return 1.4 * t ** 1.8 * along * (0.85 + 0.15 * math.sin(v * 5.0))
    return _drift("snow_drift_wall_b", 4102, 1.0, 2.0, f, 22, 44)


def snow_drift_crest_c():
    """Надув с гребнем и срывом (2,6 м): подветренная сторона крутая, как за уступом."""
    def f(u, v):
        t = (u + 1) / 2
        rise = t ** 1.2
        drop = 1 - _smooth01((t - 0.82) / 0.14)
        return 0.75 * rise * drop * max(0.0, 1 - v * v) ** 0.9
    return _drift("snow_drift_crest_c", 4103, 1.3, 0.9, f, 36, 24)


def snow_drift_small_d():
    """Малый нанос у основания предметов и камней (1,2 × 0,8 м), без коллизии."""
    def f(u, v):
        rr = u * u + v * v
        return 0.28 * max(0.0, 1 - rr) ** 1.5 * (1 + 0.3 * u)
    return _drift("snow_drift_small_d", 4104, 0.6, 0.4, f, 20, 14, collide=False)


# --------------------------------------------------------------------------------------
# Осыпь: свежие осколки камнепада (CANON гл. 4, 9: камнепад, разрушенная дорога)
# --------------------------------------------------------------------------------------
def scree_pile_a():
    """Конус осыпи у подножия стены (2,4 × 1,6 м): ядро-насыпь, крупные глыбы скатились к краю
    (как у настоящей осыпи), мелочь — выше по склону. Тыл (+X) ставится к стене."""
    name, seed = "scree_pile_a", 5101
    coll = L.asset_collection(name)
    r = random.Random(seed)
    core = L.hull_chunk(seed, (1.3, 1.9, 0.7), npts=40, cuts=3, cut_depth=(0.8, 0.95))
    parts = [(core, Matrix.Translation((0.8, 0.0, -0.2)))]
    for i in range(44):
        rr = r.random() ** 0.6
        a = r.uniform(-math.pi * 0.55, math.pi * 0.55)
        s = 0.14 + 0.36 * rr * r.uniform(0.6, 1.0)
        x, y = 0.8 - rr * 1.5 * math.cos(a), rr * 1.3 * math.sin(a)
        z = 0.55 * (1 - rr) ** 1.3
        bm = L.hull_chunk(seed + i, (s * 1.3, s, s * 0.8), npts=14, cuts=6, cut_depth=(0.55, 0.9))
        parts.append((bm, Matrix.Translation((x, y, z)) @ rot(r.uniform(0, 360), "Z") @ rot(r.uniform(-30, 30), "X")))
    obj = L.rock_object(name, parts, coll, voxel=0.02, smooth_iter=0, seed=seed, size=0.4,
                        detail=dict(large=0.03, medium=0.015, fine=0.006, crack_depth=0.0),
                        base_z=0.05, target_tris=3200, sink=0.05)
    L.bake_masks(obj, seed=seed, rays=16, ao_dist=0.5, base_dark=0.3)
    L.finalize(obj, sharp_deg=40, uv_tile=1.0)
    L.collision_convex(obj, max_verts=32)
    return [obj]


def rock_fragments_set():
    """Набор из 8 отдельных обломков 0,1–0,45 м (разные формы) для ручной расстановки.
    Каждый — свой узел с началом у основания; в .glb стоят в ряд по X через 0,6 м."""
    name, seed = "rock_fragments_set", 5201
    coll = L.asset_collection(name)
    r = random.Random(seed)
    objs = []
    for i in range(8):
        s = r.uniform(0.12, 0.45)
        dims = (s * r.uniform(0.9, 1.6), s * r.uniform(0.8, 1.2), s * r.uniform(0.5, 1.0))
        bm = L.hull_chunk(seed + i, dims, npts=r.choice((12, 18, 30)), cuts=r.randint(4, 8), cut_depth=(0.55, 0.9))
        piece = L.rock_object(f"rock_fragment_{i + 1:02d}", [(bm, rot(r.uniform(0, 360), "Z"))], coll,
                              voxel=max(0.008, s / 30), smooth_iter=r.choice((0, 1, 3)), seed=seed + i,
                              size=s, detail=dict(large=0.03, medium=0.012, fine=0.005, crack_depth=0.0),
                              target_tris=400, sink=0.02)
        L.bake_masks(piece, seed=seed + i, rays=12, ao_dist=0.25, base_dark=0.1)
        L.finalize(piece, sharp_deg=42, uv_tile=1.0)
        piece.location.x = i * 0.6
        objs.append(piece)
    return objs


# --------------------------------------------------------------------------------------
# Дальний план: одинокая Чёрная гора и цепь пиков (CANON гл. 2: «одинокая зазубренная
# гора, превосходящая соседние пики»; на склоне — остатки старой дороги)
# --------------------------------------------------------------------------------------
def _heightfield(name, coll, size_x, size_y, nx, ny, hfn, target_tris, z_bottom=-20.0):
    obj = L.grid_surface(name, coll, -size_x / 2, size_x / 2, -size_y / 2, size_y / 2, nx, ny, hfn, "nm_rock",
                         z_bottom=z_bottom)
    L.decimate(obj, target_tris)
    return obj


def black_mountain_far():
    """Чёрная гора для видения B14 и дальнего плана: ~1,3 км высотой, зазубренная вершина,
    по южному склону вьётся полка старой дороги (CANON: «остатки старой дороги»)."""
    name, seed = "black_mountain_far", 6101
    coll = L.asset_collection(name)
    R, H = 1700.0, 1100.0
    off = Vector((11.0, 7.0, 3.0))
    # Путь: полтора витка спирали от подножия к плечу вершины.
    path = []
    for i in range(400):
        t = i / 399
        ang = math.radians(-120) + t * 2 * math.pi * 1.4
        rad = R * (0.78 - 0.6 * t)
        path.append((Vector((math.cos(ang) * rad, math.sin(ang) * rad)), t))

    def base_h(x, y):
        rr = math.hypot(x, y) / R
        cone = max(0.0, 1 - rr) ** 1.15
        p = Vector((x, y, 0)) / 420.0 + off
        ridge = L.noise.ridged_multi_fractal(p, 0.9, 2.1, 6, 1.0, 2.0) / 2.2
        jag = 0.35 * L.noise.ridged_multi_fractal(p * 3.0 + off, 0.8, 2.0, 4, 1.0, 2.0) / 2.2
        summit = 0.45 * math.exp(-(rr / 0.24) ** 2)  # отдельный рог вершины
        return H * (cone * (0.55 + 0.45 * ridge + jag * cone) + summit * (0.8 + 0.4 * ridge))

    def h(x, y):
        z = base_h(x, y)
        q = Vector((x, y))
        best = min(((q - pp).length, t) for pp, t in path[::2])
        if best[0] < 45.0:
            # Полка дороги: срезаем склон до уровня, слегка ниже рельефа.
            zz = base_h(*(path[int(best[1] * 399)][0])) - 12.0
            w = 1 - _smooth01((best[0] - 18.0) / 27.0)
            z = z * (1 - w) + min(z, zz) * w
        return z

    obj = _heightfield(name, coll, R * 2.1, R * 2.1, 220, 220, h, 40000, z_bottom=-40.0)
    L.bake_masks(obj, seed=seed, rays=8, ao_dist=250.0, ground=False, base_dark=0.0, tint_var=0.12,
                 snow_noise=0.5, snow_scale=0.004)
    L.finalize(obj, sharp_deg=60, uv_tile=50.0)
    return [obj]


def mountain_range_far():
    """Дуга более низких зубчатых пиков (3 км, 400–800 м) — горизонт за перевалом."""
    name, seed = "mountain_range_far", 6201
    coll = L.asset_collection(name)
    off = Vector((3.0, 19.0, 5.0))

    def h(x, y):
        along = (x + 1500) / 3000
        ridge_line = 650 * (0.6 + 0.4 * L.noise.noise(Vector((along * 4.0, 1.0, 2.0)) + off))
        depth = max(0.0, 1 - abs(y) / 520.0) ** 1.3
        p = Vector((x, y, 0)) / 300.0 + off
        rid = L.noise.ridged_multi_fractal(p, 0.85, 2.1, 6, 1.0, 2.0) / 2.2
        return ridge_line * depth * (0.45 + 0.55 * rid)

    obj = _heightfield(name, coll, 3000.0, 1100.0, 220, 80, h, 24000, z_bottom=-30.0)
    L.bake_masks(obj, seed=seed, rays=8, ao_dist=200.0, ground=False, base_dark=0.0, tint_var=0.12,
                 snow_noise=0.5, snow_scale=0.005)
    L.finalize(obj, sharp_deg=60, uv_tile=50.0)
    return [obj]


GROUPS = {
    "boulders": [boulder_rounded, boulder_angular, boulder_slab, boulder_shard, boulder_split, rock_outcrop],
    "cliffs": [rock_wall_a, rock_wall_b, rock_overhang_b, rock_wall_broken_c],
    "road": [road_old_01, road_old_02_ice, road_old_03_step],
    "camp": [camp_platform_a],
    "edges": [cliff_edge_a1, cliff_edge_a2, cliff_edge_collapsed_b],
    "drifts": [snow_drift_low_a, snow_drift_wall_b, snow_drift_crest_c, snow_drift_small_d],
    "scree": [scree_pile_a, rock_fragments_set],
    "peaks": [black_mountain_far, mountain_range_far],
}


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opts = {"only": list(GROUPS), "test": None, "export": True}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--only":
            opts["only"] = argv[i + 1].split(",")
            i += 1
        elif a == "--test":
            opts["test"] = argv[i + 1]
            i += 1
        elif a == "--no-export":
            opts["export"] = False
        i += 1
    return opts


def _inst(coll, loc, rot_z=0.0, tag=""):
    inst = bpy.data.objects.new(f"inst_{tag}{coll.name}", None)
    inst.instance_type = "COLLECTION"
    inst.instance_collection = coll
    L.preview_collection().objects.link(inst)
    inst.location = loc
    inst.rotation_euler = (0, 0, math.radians(rot_z))
    return inst


def layout(group, colls, ox):
    """Раскладка группы для превью в .blend и на рендере. Возвращает (объекты, ракурсы).

    Ракурс — (имя, направление камеры | None, явная камера (loc, rot, lens) | None)."""
    objs = []
    views = []
    if group == "cliffs":
        y = 0.0
        for c in colls:
            objs.append(_inst(c, (ox, y, 0)))
            y += 6.0 - 0.0
        objs.append(L.mannequin(location=(ox - 1.2, 3.0, 0), name=f"ScaleRef_{group}"))
        views = [("", (-1.0, -0.55, 0.28), None),
                 ("_eye", None, ((ox - 1.5, 1.5, 1.6), (86, 0, -20), 24))]
    elif group in ("road", "edges"):
        step = ROAD_L if group == "road" else EDGE_L
        for i, c in enumerate(colls + colls[:1]):
            objs.append(_inst(c, (ox, i * step, 0), tag=f"{i}_"))
    elif group == "peaks":
        x = ox
        for c in colls:
            objs.append(_inst(c, (x + 1800, 0, 0)))
            x += 4200
        views = [("", (-0.2, -1.0, 0.18), None)]
    else:
        x = ox
        for c in colls:
            pts = [p for o in c.all_objects if o.type == "MESH" and not o.hide_render for p in L.world_points(o)]
            x0 = min(p.x for p in pts)
            x1 = max(p.x for p in pts)
            objs.append(_inst(c, (x - x0, 0, 0)))
            x += (x1 - x0) + 0.8
        objs.append(L.mannequin(location=(x + 0.3, 0.4, 0), name=f"ScaleRef_{group}"))
        views = [("", (-0.35, -1.0, 0.42), None)]
    return objs, views


def road_edge_layout(colls_road, colls_edge, ox):
    objs = []
    for i, c in enumerate(colls_road + colls_road[:1]):
        objs.append(_inst(c, (ox, i * ROAD_L, 0), tag=f"{i}_"))
    for i, c in enumerate(colls_edge + colls_edge[:1]):
        objs.append(_inst(c, (ox, i * EDGE_L, 0), tag=f"{i}_"))
    objs.append(L.mannequin(location=(ox - 0.6, 7.0, 0.0), name="ScaleRef_road"))
    views = [("", (-1.0, -0.6, 0.55), None), ("_eye", None, ((ox - 0.6, -1.2, 1.6), (76, 0, 14), 24))]
    return objs, views


def diorama(by_name, ox):
    """Сборка отрезка перевала из модулей: дорога, стена справа, кромка слева, валуны, надувы.
    Проверяет масштаб, стыки и совместную читаемость — не игровая сцена."""
    objs = []
    road = ["road_old_01", "road_old_02_ice", "road_old_03_step", "road_old_01"]
    z = 0.0
    for i, n in enumerate(road):
        objs.append(_inst(by_name[n], (ox, i * ROAD_L, z), tag=f"d{i}_"))
        if n.endswith("step"):
            z += 0.2
    walls = ["rock_wall_a", "rock_overhang_b", "rock_wall_b"]
    for i, n in enumerate(walls):
        objs.append(_inst(by_name[n], (ox + 1.3, i * 5.4, 0.0), tag=f"d{i}_"))
    edges = ["cliff_edge_a1", "cliff_edge_collapsed_b", "cliff_edge_a2", "cliff_edge_a1"]
    for i, n in enumerate(edges):
        objs.append(_inst(by_name[n], (ox, i * EDGE_L, 0.0), tag=f"d{i}_"))
    props = [("snow_drift_wall_b", (ox + 0.9, 3.2, 0.0), 0), ("scree_pile_a", (ox + 0.7, 9.6, 0.15), 0),
             ("boulder_angular_a", (ox + 0.2, 12.5, 0.2), 30), ("snow_drift_low_a", (ox - 0.6, 6.0, 0.0), 10),
             ("boulder_split_a", (ox + 1.0, 14.8, 0.2), -20)]
    for n, loc, rz in props:
        objs.append(_inst(by_name[n], loc, rz, tag="d_"))
    objs.append(L.mannequin(location=(ox - 0.2, 6.5, 0.0), name="ScaleRef_diorama"))
    views = [("", (-1.0, -0.9, 0.7), None), ("_eye", None, ((ox - 0.3, -2.0, 1.6), (84, 0, -6), 24))]
    return objs, views


def render_views(objs, views, out_base, all_preview):
    for o in all_preview:
        o.hide_render = o not in objs and o.type in ("EMPTY", "MESH") and o.name != "PreviewGround"
    for suffix, direction, explicit in views:
        if explicit:
            loc, rot_deg, lens = explicit
            cam = bpy.data.objects.get("PreviewCam") or L.frame_camera(objs, lens=lens)
            cam.data.lens = lens
            cam.location = loc
            cam.rotation_euler = tuple(math.radians(v) for v in rot_deg)
            bpy.context.scene.camera = cam
        else:
            L.frame_camera([o for o in objs if not o.name.startswith("ScaleRef")] or objs,
                           direction=direction, lens=50 if "eye" not in suffix else 24, margin=1.04)
        L.render(str(out_base) + suffix + ".jpg")


def main():
    opts = parse_args()
    t0 = time.time()
    L.clear_data()
    built = {}
    for group in opts["only"]:
        built[group] = []
        for fn in GROUPS[group]:
            objs = fn()
            coll = objs[0].users_collection[0]
            built[group].append(coll)
            print(f"BUILT {coll.name}: tris={sum(L.tri_count(o) for o in objs)} t={time.time() - t0:.1f}s")
    if opts["export"] and not opts["test"]:
        for colls in built.values():
            for coll in colls:
                L.export_collection(coll, OUT_DIR / f"{coll.name}.glb")
    # Превью: оригиналы в ASSETS (исключены из слоя), в PREVIEW — экземпляры по группам.
    L.set_assets_visible(False)
    gnd = L.ground(size=400.0, z=0.0)
    L.setup_render(res=(1600, 900), samples=48 if opts["test"] else 96)
    out_dir = Path(opts["test"]).parent if opts["test"] else L.PREVIEW_DIR
    prefix = Path(opts["test"]).stem + "_" if opts["test"] else "mountain_"
    jobs = []
    ox = 0.0
    if "road" in built and "edges" in built:
        jobs.append(("road_edges",) + road_edge_layout(built["road"], built["edges"], ox))
        ox += 40.0
    for group, colls in built.items():
        if group in ("road", "edges") and "road" in built and "edges" in built:
            continue
        if group == "peaks":
            continue
        objs, views = layout(group, colls, ox)
        if not views:
            views = [("", (-1.0, -0.6, 0.55), None)]
        jobs.append((group, objs, views))
        ox += 60.0
    by_name = {c.name: c for colls in built.values() for c in colls}
    needed = {"road_old_01", "rock_wall_a", "cliff_edge_a1", "snow_drift_wall_b", "scree_pile_a", "boulder_split_a"}
    if needed <= set(by_name):
        jobs.append(("pass_diorama",) + diorama(by_name, ox))
        ox += 40.0
    if "peaks" in built:
        jobs.append(("peaks",) + layout("peaks", built["peaks"], ox + 2000.0))
    all_preview = list(L.preview_collection().objects)
    for name, objs, views in jobs:
        gnd.hide_render = name == "peaks"
        gnd.location.z = -9.0 if name in ("road_edges", "edges", "road", "pass_diorama") else 0.0
        pts = [p for o in objs for p in L.world_points(o)]
        gnd.location.x = (min(p.x for p in pts) + max(p.x for p in pts)) / 2
        gnd.location.y = (min(p.y for p in pts) + max(p.y for p in pts)) / 2
        if name == "peaks":
            L.setup_render(res=(1600, 900), samples=48 if opts["test"] else 96, sun_elev=18.0, sun_az=-60.0)
        render_views(objs, views, out_dir / f"{prefix}{name}", all_preview)
    for o in all_preview:
        o.hide_render = False
    if not opts["test"]:
        L.save_blend(SRC / "mountain_kit.blend")
    print("DONE", time.time() - t0)


if __name__ == "__main__":
    main()

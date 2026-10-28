"""Партия 3 — храм на вершине Чёрной горы (S12–S13): колонны, стены, антаблемент с фризом,
фронтон, портал и разбитые ворота, ступени, пол, обломки крыши, алтарь.

Запуск из корня проекта (Blender 5.1, в фоне):
    blender -b --factory-startup --python assets/environments/nightmare/source/build_temple_kit.py -- [опции]
Опции: --only <группы>, --test <файл.jpg>, --no-export. Результат: `source/temple_kit.blend`,
`temple/*.glb`, превью `docs/art/previews/nightmare/temple_*.jpg`.

CANON (гл. 14, 1801; docs/story/canon_shadow_shrine.md): колоссальные колонны и стены из чёрного
мрамора; изысканные рельефы на фронтоне и широком фризе; трещины; часть крыши обрушена; высокие
ворота разбиты «рукой гиганта»; в зале груды обломков под снегом; алтарь — цельный кусок чёрного
мрамора, широкий как кровать, сухой и чистый.
ART-DIRECTION: ордер (гранёные каннелюры, тяжёлая капитель без завитков), крупная тёсаная кладка
с плотными швами, мотивы рельефов (вложенные прямоугольники, разомкнутые кольца, вертикальные борозды,
безликие вытянутые фигуры — docs/art/ancient_ruins_architecture_style.md §4), размеры — бриф святилища
(STAGING). Чашу, руны на алтаре, статую бога не делаем.
Оси: вход — со стороны −Y, дальний торец — +Y, вверх +Z. Начало — у основания по центру.
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
import nm_props as P  # noqa: E402

importlib.reload(P)

T, rot, I = P.T, P.rot, P.I
OUT_DIR = L.NM_DIR / "temple"
M = "nm_marble_black"


# --------------------------------------------------------------------------------------
# Геометрия: лофт сечений, каннелюры, тесаный блок, рельефное поле
# --------------------------------------------------------------------------------------
def loft(levels, cap_bottom=True, cap_top=True):
    """levels — список (z, [(x, y), ...]) с одинаковым числом точек; замкнутые кольца."""
    bm = bmesh.new()
    rings = [[bm.verts.new((x, y, z)) for x, y in pts] for z, pts in levels]
    n = len(rings[0])
    for a, b in zip(rings, rings[1:]):
        for k in range(n):
            bm.faces.new((a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]))
    if cap_bottom:
        bm.faces.new(list(reversed(rings[0])))
    if cap_top:
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return bm


def fluted(radius, flutes=16, depth=0.05, per=4):
    pts = []
    n = flutes * per
    for i in range(n):
        th = 2 * math.pi * i / n
        r = radius - depth * (0.5 - 0.5 * math.cos(flutes * th)) ** 0.9
        pts.append((r * math.cos(th), r * math.sin(th)))
    return pts


def circle(radius, n):
    return [(radius * math.cos(2 * math.pi * i / n), radius * math.sin(2 * math.pi * i / n)) for i in range(n)]


def block(sx, sy, sz, chamfer=0.03):
    """Тёсаный блок с фаской по рёбрам (шов между блоками читается тенью)."""
    return P.board(sx, sy, sz, bevel=chamfer)


def chip_corners(bm, seed, count=2, size=0.12):
    """Сколы углов: срез плоскостью у случайных вершин рамки блока."""
    r = random.Random(seed)
    lo = Vector((min(v.co.x for v in bm.verts), min(v.co.y for v in bm.verts), min(v.co.z for v in bm.verts)))
    hi = Vector((max(v.co.x for v in bm.verts), max(v.co.y for v in bm.verts), max(v.co.z for v in bm.verts)))
    for _ in range(count):
        corner = Vector((r.choice((lo.x, hi.x)), r.choice((lo.y, hi.y)), r.choice((lo.z, hi.z))))
        center = (lo + hi) / 2
        n = (corner - center).normalized()
        n = (n + Vector((r.uniform(-0.3, 0.3), r.uniform(-0.3, 0.3), r.uniform(-0.3, 0.3)))).normalized()
        co = corner - n * size * r.uniform(0.6, 1.4)
        geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
        res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=n, clear_outer=True)
        cut = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
        if cut:
            bmesh.ops.holes_fill(bm, edges=cut, sides=0)
    return bm


def relief_field(w, h, depth, height_fn, res=0.02, base=0.06):
    """Рельефная панель w × h (плоскость XZ, лицом к −Y): высота лица = depth * height_fn(u, v),
    u, v ∈ [0, 1]. Толщина плиты base; тыл плоский."""
    nx, nz = max(2, int(w / res)), max(2, int(h / res))
    bm = bmesh.new()
    front = [[bm.verts.new((-w / 2 + w * i / nx, -depth * height_fn(i / nx, j / nz), h * j / nz))
              for j in range(nz + 1)] for i in range(nx + 1)]
    for i in range(nx):
        for j in range(nz):
            bm.faces.new((front[i][j], front[i + 1][j], front[i + 1][j + 1], front[i][j + 1]))
    ring = [front[i][0] for i in range(nx + 1)] + [front[nx][j] for j in range(1, nz + 1)] + \
           [front[i][nz] for i in range(nx - 1, -1, -1)] + [front[0][j] for j in range(nz - 1, 0, -1)]
    back = [bm.verts.new((v.co.x, base, v.co.z)) for v in ring]
    n = len(ring)
    for k in range(n):
        bm.faces.new((ring[k], ring[(k + 1) % n], back[(k + 1) % n], back[k]))
    bm.faces.new(list(reversed(back)))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return bm


# Мотивы рельефа (ART-DIRECTION, стиль руин §4.2): функции u, v → высота 0..1.
def _band(d, w):
    return max(0.0, 1.0 - abs(d) / w)


def motif_nested(u, v):
    """Вложенные прямоугольники, уходящие внутрь, и пустой центр."""
    du, dv = abs(u - 0.5), abs(v - 0.5)
    d = max(du / 0.5, dv / 0.5)
    h = 0.0
    for k, s in enumerate((0.9, 0.7, 0.5)):
        h = max(h, _band(d - s, 0.035) * (1.0 - 0.15 * k))
    return h


def motif_ring_open(u, v):
    """Разомкнутое кольцо с вертикальными бороздами-счётом по сторонам."""
    du, dv = u - 0.5, (v - 0.5) * 1.2
    rr = math.hypot(du, dv)
    ang = math.atan2(dv, du)
    ring = _band(rr - 0.28, 0.035) * (0.0 if -0.5 < ang < 0.2 else 1.0)
    grooves = 0.0
    for x0 in (0.08, 0.12, 0.16, 0.84, 0.88, 0.92):
        grooves = max(grooves, _band(u - x0, 0.008) * (1.0 if 0.2 < v < 0.8 else 0.0))
    return max(ring, grooves * 0.8)


def motif_chevrons(u, v):
    """Нисходящие клинья — направление «внутрь и вниз»."""
    h = 0.0
    for k in range(4):
        y0 = 0.8 - k * 0.18
        h = max(h, _band(v - (y0 - abs(u - 0.5) * 0.6), 0.03) * (1.0 if 0.1 < u < 0.9 else 0.0))
    return h


def motif_figure(u, v, lean=0.0):
    """Безликая вытянутая фигура (стиль руин §4.3): голова — гладкий овал без черт, руки —
    длинные борозды вдоль тела. Низкий рельеф с мягким краем."""
    x = u - 0.5 - lean * (v - 0.5)

    def blob(d, w):
        return max(0.0, min(1.0, 1.0 - d / w))

    head = blob(math.hypot(x / 0.09, (v - 0.86) / 0.07) - 1.0, 0.25)
    body_w = 0.17 * (1.0 - 0.35 * max(0.0, (0.72 - v)) / 0.72)
    body = blob((abs(x) - body_w) / 0.02, 1.0) if 0.08 < v < 0.76 else 0.0
    arms = 0.0
    for sx in (-1, 1):
        arms = max(arms, 0.6 * _band(x - sx * (body_w + 0.035), 0.012) * (1.0 if 0.3 < v < 0.72 else 0.0))
    groove = 0.6 * _band(x, 0.006) * (1.0 if 0.1 < v < 0.4 else 0.0)  # разделение ног
    return max(head * 0.9, body, arms) - groove * body


def damage(fn, seed, amount=0.35, scale=6.0):
    """Стёртость и выбоины: рельеф местами исчезает под сколом (стиль руин §4.1)."""
    off = Vector((seed * 1.7, seed * 0.3, 0.0))

    def wrapped(u, v):
        n = L.noise.noise(Vector((u * scale, v * scale, 0.0)) + off)
        keep = 1.0 if n > -amount else max(0.0, 1.0 + (n + amount) * 6)
        return fn(u, v) * keep
    return wrapped


# --------------------------------------------------------------------------------------
# Колонны
# --------------------------------------------------------------------------------------
COL_H, COL_R0, COL_R1, DRUM = 8.2, 0.85, 0.74, 2.05


def column_parts(asm, shaft_top=COL_H, capital=True, seed=0, misalign=0.012):
    """Колонна: квадратный плинт, база-валик, ствол из барабанов с энтазисом и 16 гранёными
    каннелюрами, капитель (эхин + абака). Ствол от z = 0,8 (над базой)."""
    r = random.Random(seed)
    z0 = 0.8
    asm.add(block(2.3, 2.3, 0.45, 0.04), M, T(0, 0, 0.225))
    base = P.lathe([(1.0, 0.45), (1.02, 0.52), (0.98, 0.6), (0.9, 0.66), (0.92, 0.72), (0.88, 0.8)], segs=48,
                   close_bottom=True, close_top=True)
    asm.add(base, M)
    z = z0
    k = 0
    while z < z0 + shaft_top - 0.01:
        h = min(DRUM, z0 + shaft_top - z)
        levels = []
        steps = max(2, int(h / 0.4))
        for i in range(steps + 1):
            zz = z + h * i / steps
            t = (zz - z0) / COL_H
            rad = COL_R0 + (COL_R1 - COL_R0) * t + 0.03 * math.sin(math.pi * t)
            joint = 0.012 if i in (0, steps) else 0.0
            levels.append((zz - z, fluted(rad - joint, 16, 0.055)))
        drum = loft(levels)
        uv = drum.loops.layers.uv.verify()
        for f in drum.faces:
            for loop in f.loops:
                c = loop.vert.co
                loop[uv].uv = (math.atan2(c.y, c.x) * COL_R0, c.z)
        asm.add(drum, M, T(r.uniform(-misalign, misalign), r.uniform(-misalign, misalign), z) @ rot(r.uniform(-1.5, 1.5), "Z"))
        z += h
        k += 1
    if capital:
        zc = z0 + shaft_top
        ech = P.lathe([(COL_R1 - 0.01, 0.0), (COL_R1 + 0.05, 0.12), (COL_R1 + 0.22, 0.3), (COL_R1 + 0.32, 0.42),
                       (COL_R1 + 0.32, 0.45)], segs=48)
        asm.add(ech, M, T(0, 0, zc))
        asm.add(block(2.15, 2.15, 0.5, 0.035), M, T(0, 0, zc + 0.45 + 0.25))
    return asm


def _solidify_damage(name, asm_objs, coll, seed, cut=None, crack=None, voxel=0.03, tris=7000):
    """Повреждение колонны: слить детали вокселями, отбить верх по рваной плоскости, трещина, сколы."""
    obj = L.merge_objects(name, asm_objs, coll)
    obj.data.materials.clear()
    obj.data.materials.append(L.material(M))
    L.voxel_remesh(obj, voxel)
    r = random.Random(seed)
    if cut is not None:
        zc, tilt = cut
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        n = Vector((math.sin(math.radians(tilt)), 0.15, 1.0)).normalized()
        geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
        res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, zc), plane_no=n, clear_outer=True)
        edges = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
        if edges:
            bmesh.ops.holes_fill(bm, edges=edges, sides=0)
        bm.to_mesh(obj.data)
        bm.free()
        L.voxel_remesh(obj, voxel)  # плотная сетка на изломе для рваного рельефа
        off = Vector((seed * 0.7, seed * 1.3, 0.0))

        def frac(co, nrm):
            d = (co - Vector((0, 0, zc))).dot(n)
            if d > -0.35:
                w = max(0.0, 1.0 - abs(d) / 0.35)
                return -0.18 * w * (0.5 + 0.5 * L.noise.noise(co * 2.5 + off)) - 0.06 * w * abs(L.noise.noise(co * 9 + off))
            return 0.0

        L.displace(obj, frac)
    if crack is not None:
        a0, depth = crack
        off = Vector((seed, 0.0, 0.0))

        def crk(co, nrm):
            ang = math.atan2(co.y, co.x) - a0 - 0.15 * L.noise.noise(Vector((co.z * 0.4, 0, 0)) + off)
            ang = (ang + math.pi) % (2 * math.pi) - math.pi
            d = abs(ang) * math.hypot(co.x, co.y)
            return -depth * max(0.0, 1.0 - d / 0.05) if co.z > 0.8 else 0.0

        L.displace(obj, crk)
    L.rock_detail(obj, seed, 1.0, large=0.004, medium=0.004, fine=0.0015, crack_depth=0.004)
    L.decimate(obj, tris)
    return obj


def _finish(obj, seed, ao=1.5, ground=True, sharp=40, col="convex", col_tris=300):
    L.bake_masks(obj, seed=seed, rays=16, ao_dist=ao, ground=ground, base_dark=0.6, tint_var=0.05)
    L.finalize(obj, sharp_deg=sharp, uv_tile=3.0)
    if col == "convex":
        L.collision_convex(obj, max_verts=48)
    elif col == "trimesh":
        L.collision_trimesh(obj, target_tris=col_tris)
    return obj


def column_intact():
    """Целая колонна ~10 м (SHS-07): ствол из 4 барабанов, капитель и абака."""
    name = "column_intact"
    coll = L.asset_collection(name)
    asm = P.Assembly(name, coll)
    column_parts(asm, seed=8101)
    obj = L.merge_objects(name, asm.build(), coll)
    return [_finish(obj, 8101, ao=1.2)]


def column_broken_a():
    """Колонна, обломанная на ~6,5 м по рваной наклонной плоскости, с продольной трещиной (SHS-08)."""
    name = "column_broken_a"
    coll = L.asset_collection(name)
    asm = P.Assembly(name, coll)
    column_parts(asm, shaft_top=6.6, capital=False, seed=8102)
    obj = _solidify_damage(name, asm.build(), coll, 8102, cut=(6.6, 14.0), crack=(0.6, 0.06))
    return [_finish(obj, 8102, ao=1.2)]


def column_broken_b():
    """Низкий обрубок колонны ~3 м с глубоким изломом и сколами базы (SHS-08)."""
    name = "column_broken_b"
    coll = L.asset_collection(name)
    asm = P.Assembly(name, coll)
    column_parts(asm, shaft_top=2.6, capital=False, seed=8103)
    obj = _solidify_damage(name, asm.build(), coll, 8103, cut=(3.0, -22.0), crack=(2.4, 0.05), tris=5000)
    return [_finish(obj, 8103, ao=1.2)]


def column_fallen():
    """Упавшая колонна: три барабана раскатились, капитель лежит на боку (SHS-09)."""
    name = "column_fallen"
    coll = L.asset_collection(name)
    r = random.Random(8104)
    asm = P.Assembly(name, coll)
    placements = [(0.0, 0.0, 12), (2.3, 0.4, 8), (4.9, -0.2, -15)]
    for k, (x, y, rz) in enumerate(placements):
        levels = [(0.0, fluted(0.8 - 0.012, 16, 0.055))] + [(0.4 * i, fluted(0.8, 16, 0.055)) for i in range(1, 5)] + \
                 [(2.0, fluted(0.8 - 0.012, 16, 0.055))]
        drum = loft(levels)
        asm.add(drum, M, T(x, y, 0.78) @ rot(rz, "Z") @ rot(90, "Y") @ rot(r.uniform(0, 30), "Z") @ T(0, 0, -1.0))
    ech = P.lathe([(0.73, 0.0), (0.78, 0.12), (0.95, 0.3), (1.05, 0.42), (1.05, 0.45)], segs=40)
    asm.add(ech, M, T(7.3, 0.6, 1.07) @ rot(70, "X") @ rot(20, "Y"))
    asm.add(block(2.15, 2.15, 0.5, 0.035), M, T(7.6, 1.6, 1.0) @ rot(72, "X") @ rot(20, "Y"))
    obj = _solidify_damage(name, asm.build(), coll, 8104, voxel=0.03, tris=9000)
    zmin = min(v.co.z for v in obj.data.vertices)
    obj.data.transform(T(-3.6, 0, -zmin - 0.08))
    return [_finish(obj, 8104, ao=1.0, col="trimesh", col_tris=300)]


# --------------------------------------------------------------------------------------
# Стены: крупная тёсаная кладка из чёрного мрамора
# --------------------------------------------------------------------------------------
def wall_courses(asm, length, height, thick, seed, ruin=0.0, missing=0.0, crack_blocks=0):
    """Ряды блоков 1,25–1,65 м высотой, длина блоков 2,2–3,8 м, перевязка швов; нижний ряд —
    цоколь шире на 0,15 м. ruin — доля высоты, где верх стены разрушен (рваная кромка)."""
    r = random.Random(seed)
    z = 0.0
    row = 0
    ruin_line = lambda y: height * (1 - ruin * (0.5 + 0.5 * L.noise.noise(Vector((y * 0.35, seed * 0.1, 0)))))  # noqa: E731
    while z < height - 0.2:
        h = r.uniform(1.25, 1.65) if row else 0.9
        y = -length / 2 - (r.uniform(0.3, 1.2) if row % 2 else 0.0)
        while y < length / 2:
            ln = r.uniform(2.2, 3.8)
            y1 = min(length / 2, y + ln)
            cy = (y + y1) / 2
            if ruin and z + h > ruin_line(cy):
                y = y1
                continue
            if missing and row > 0 and r.random() < missing:
                y = y1
                continue
            t = thick + (0.3 if row == 0 else 0.0)
            bm = block(t + r.uniform(-0.02, 0.02), (y1 - max(y, -length / 2)) - 0.01, h - 0.01, 0.022)
            if r.random() < 0.35:
                chip_corners(bm, seed + row * 31 + int(cy * 10), count=r.randint(1, 2), size=0.18)
            asm.add(bm, M, T(r.uniform(-0.015, 0.015), cy, z + h / 2) @ rot(r.uniform(-0.25, 0.25), "Z"))
            y = y1
        z += h
        row += 1
    return asm


def _wall(name, seed, length=6.0, height=10.0, thick=1.4, **kw):
    coll = L.asset_collection(name)
    asm = P.Assembly(name, coll)
    wall_courses(asm, length, height, thick, seed, **kw)
    obj = L.merge_objects(name, asm.build(), coll)
    return obj


def wall_block_intact():
    """Модуль стены 6 × 10 м, толщина 1,4 м: крупные блоки с плотными швами (CANON: стены из
    чёрного мрамора; кладка — ART-DIRECTION). Ставится встык по оси Y."""
    obj = _wall("wall_block_intact", 8201)
    return [_finish(obj, 8201, ao=1.5, sharp=35, col="trimesh", col_tris=200)]


def wall_block_ruined():
    """Модуль стены с обрушенным верхом, выпавшими блоками и сколами (CANON: трещины, руины)."""
    obj = _wall("wall_block_ruined", 8202, ruin=0.55, missing=0.06)
    return [_finish(obj, 8202, ao=1.5, sharp=35, col="trimesh", col_tris=250)]


# --------------------------------------------------------------------------------------
# Ступени, пол, алтарь
# --------------------------------------------------------------------------------------
def stairs_a():
    """Монументальная лестница перед входом (SHS-02): 10 м шириной, 6 ступеней по 0,22 м,
    проступь 0,5 м; ступени из длинных блоков, кромки стёрты к середине, часть блоков сдвинута."""
    name = "stairs_a"
    coll = L.asset_collection(name)
    r = random.Random(8301)
    asm = P.Assembly(name, coll)
    width, rise, run, steps = 10.0, 0.22, 0.5, 6
    for k in range(steps):
        z = k * rise
        y0 = k * run
        depth = (steps - k) * run + 0.3
        x = -width / 2
        while x < width / 2:
            ln = r.uniform(1.6, 2.8)
            x1 = min(width / 2, x + ln)
            bm = block(x1 - x - 0.012, depth, rise - 0.004, 0.03)
            # Стёртая кромка к середине (ходили по центру): кромку срезаем и скругляем.
            for v in bm.verts:
                if v.co.y < -depth / 2 + 0.06 and v.co.z > 0:
                    wear = 0.03 * max(0.0, 1.0 - abs((x + x1) / 2 + v.co.x) / 3.0)
                    v.co.z -= wear
                    v.co.y += wear
            if r.random() < 0.3:
                chip_corners(bm, 8301 + k * 13 + int(x * 7), count=1, size=0.12)
            shift = (r.uniform(-0.03, 0.03), r.uniform(-0.04, 0.04), r.uniform(-0.02, 0.015)) if r.random() < 0.35 else (0, 0, 0)
            asm.add(bm, M, T((x + x1) / 2 + shift[0], y0 + depth / 2 + shift[1], z + rise / 2 + shift[2])
                    @ rot(r.uniform(-0.4, 0.4), "Z"))
            x = x1
    obj = L.merge_objects(name, asm.build(), coll)
    obj = _finish(obj, 8301, ao=0.8, sharp=35, col=None)
    ys = [0.0]
    zs = [0.0]
    for k in range(steps):
        ys.append(k * run + 0.02)
        zs.append((k + 1) * rise)
    L.collision_profile(coll, name, [0.0, steps * run, steps * run + 0.3], [0.0, steps * rise, steps * rise], width)
    return [obj]


def floor_a():
    """Модуль пола зала 4 × 4 м (SHS-10): ряды плит разной ширины, швы совпадают на краях модуля."""
    return _floor("floor_a", 8401, cracked=0.1, sunk=0.05)


def floor_b():
    """Модуль пола с треснувшими, просевшими и выбитыми плитами (SHS-11)."""
    return _floor("floor_b", 8402, cracked=0.45, sunk=0.25, missing=0.08)


def _floor(name, seed, cracked=0.0, sunk=0.0, missing=0.0):
    coll = L.asset_collection(name)
    r = random.Random(seed)
    asm = P.Assembly(name, coll)
    y = 0.0
    while y < 4.0 - 0.01:
        d = min(r.choice((0.8, 1.0, 1.2)), 4.0 - y)
        x = -2.0
        while x < 2.0 - 0.01:
            w = min(r.uniform(1.0, 2.0), 2.0 - x)
            if missing and r.random() < missing:
                x += w
                continue
            top = r.uniform(-0.008, 0.004) - (r.uniform(0.02, 0.06) if r.random() < sunk else 0.0)
            pieces = [(w, d, 0.0, 0.0)]
            if r.random() < cracked:
                cut = r.uniform(0.3, 0.7)
                pieces = [(w * cut - 0.006, d, -w * (1 - cut) / 2 - 0.003, 0.0), (w * (1 - cut) - 0.006, d, w * cut / 2 + 0.003, -0.01)]
            for pw, pd, dx, dz in pieces:
                bm = block(pw - 0.01, pd - 0.01, 0.3, 0.012)
                asm.add(bm, M, T(x + w / 2 + dx, y + d / 2, top + dz - 0.15) @ rot(r.uniform(-0.6, 0.6), "X") @ rot(r.uniform(-0.6, 0.6), "Y"))
            x += w
        y += d
    under = L.grid_surface(name + "_under", coll, -2.0, 2.0, 0.0, 4.0, 4, 4, lambda xx, yy: -0.05, "nm_snow", z_bottom=-0.32)
    obj = L.merge_objects(name, asm.build() + [under], coll)
    L.bake_masks(obj, seed=seed, rays=10, ao_dist=0.3, ground=False, base_dark=0.0, tint_var=0.05)
    L.finalize(obj, sharp_deg=35, uv_tile=3.0)
    L.collision_box(coll, name, Vector((0, 2.0, -0.15)), (4.0, 4.0, 0.3))
    return [obj]


def altar_black_marble():
    """Алтарь (SHS-16, герой-объект): цельный блок чёрного мрамора 2,4 × 1,2 × 0,9 м, «широкий как
    кровать», верх ровный и чистый, по низу вырезан цокольный уступ того же блока, на передней грани —
    неглубокая гладкая рамка без символа; старые сколы только на рёбрах. Снег не ложится (nm_marble_altar)."""
    name = "altar_black_marble"
    coll = L.asset_collection(name)
    lw, dp, h = 2.4, 1.2, 0.9
    levels = []
    for z, inset in ((0.0, 0.0), (0.12, 0.0), (0.12, 0.05), (0.16, 0.05), (0.16, 0.025), (h - 0.03, 0.04), (h, 0.06)):
        hw, hd = lw / 2 - inset, dp / 2 - inset
        levels.append((z, [(-hw, -hd), (hw, -hd), (hw, hd), (-hw, hd)]))
    bm = loft(levels)
    # Рамка на передней грани (−Y): неглубокая выборка 1,5 см — вложенный прямоугольник без изображения.
    panel = relief_field(1.7, 0.5, 0.015, lambda u, v: -motif_nested(u, v) * 0.6, res=0.012, base=0.02)
    tmp = bpy.data.meshes.new("_alt")
    bm.to_mesh(tmp)
    bm.free()
    obj = L.object_from_bmesh(name, bmesh.new(), coll, "nm_marble_altar")
    obj.data = tmp
    obj.data.materials.append(L.material("nm_marble_altar"))
    pobj = L.object_from_bmesh(name + "_panel", panel, coll, "nm_marble_altar")
    pobj.data.transform(T(0, -dp / 2 + 0.025 + 0.004, 0.28))
    merged = L.merge_objects(name, [obj, pobj], coll)
    L.voxel_remesh(merged, 0.006)
    # Старые сколы по рёбрам (не трогают верхнюю плоскость): мягкие выбоины вдоль кромок.
    off = Vector((3.3, 1.1, 0.0))

    def edge_wear(co, nrm):
        near_edge = (abs(abs(co.x) - (lw / 2 - 0.05)) < 0.06 or abs(abs(co.y) - (dp / 2 - 0.05)) < 0.06)
        if near_edge and co.z < h - 0.02:
            n = L.noise.noise(co * 7 + off)
            return -0.025 * max(0.0, n - 0.2)
        return 0.0

    L.displace(merged, edge_wear)
    L.decimate(merged, 4000)
    L.bake_masks(merged, seed=8501, rays=16, ao_dist=0.5, base_dark=0.3, tint_var=0.03)
    L.finalize(merged, sharp_deg=30, uv_tile=3.0)
    L.collision_box(coll, name, Vector((0, 0, h / 2)), (lw, dp, h))
    return [merged]


# --------------------------------------------------------------------------------------
# Антаблемент, фронтон, рельефы (CANON: «изысканные рельефы на фронтоне и широком фризе»)
# --------------------------------------------------------------------------------------
FRIEZE_MOTIFS = [motif_nested, motif_ring_open, motif_chevrons, lambda u, v: motif_figure(u, v, 0.05),
                 motif_nested, lambda u, v: motif_figure(u, v, -0.04)]


def entablature_a():
    """Отрезок антаблемента 6 м на капители колонн: архитрав, широкий фриз — квадратные панели
    рельефа (ART-DIRECTION: мотивы стиля руин, безликие фигуры) между пучками вертикальных борозд,
    карниз с выносом. Высота 2,9 м; низ — на уровне верха абаки (z = 0)."""
    name, seed = "entablature_a", 8601
    coll = L.asset_collection(name)
    asm = P.Assembly(name, coll)
    ln, dp = 6.0, 2.0
    for x0 in (-3.0, 0.0):
        asm.add(block(3.0 - 0.012, dp, 1.05, 0.03), M, T(x0 + 1.5, 0, 0.525))
    # Фриз: чередование панелей рельефа 1,2 × 1,2 и вертикальных пучков борозд.
    x = -ln / 2
    k = 0
    while x < ln / 2 - 0.01:
        if k % 2 == 0:
            w = 0.6
            fn = lambda u, v: max(_band(u - 0.25, 0.06), _band(u - 0.5, 0.06), _band(u - 0.75, 0.06)) * (0.0 if v > 0.92 else 1.0)  # noqa: E731
        else:
            w = 1.2
            fn = damage(FRIEZE_MOTIFS[(k // 2) % len(FRIEZE_MOTIFS)], seed + k, amount=0.45)
        panel = relief_field(w - 0.01, 1.2, 0.05, fn, res=0.02, base=dp - 0.1)
        asm.add(panel, M, T(x + w / 2, -dp / 2 + 0.05, 1.05))
        x += w
        k += 1
    asm.add(block(ln + 0.02, dp + 0.5, 0.42, 0.04), M, T(0, -0.0, 1.05 + 1.2 + 0.21))
    asm.add(block(ln + 0.02, dp + 0.2, 0.2, 0.03), M, T(0, 0.0, 1.05 + 1.2 + 0.52))
    objs = asm.build()
    obj = L.merge_objects(name, objs, coll)
    L.decimate(obj, 9000)
    return [_finish(obj, seed, ao=1.0, ground=False, sharp=35, col="trimesh", col_tris=120)]


def pediment_fragment():
    """Уцелевшая половина фронтона (CANON: «стигийский фронтон с рельефами»): треугольное поле
    с двумя безликими фигурами в низком рельефе, наклонный карниз; вторая половина отколота."""
    name, seed = "pediment_fragment", 8602
    coll = L.asset_collection(name)
    asm = P.Assembly(name, coll)
    span, h = 14.0, 3.2

    def tympanum(u, v):
        # Треугольное поле: вне треугольника — фон; фигуры — у центра и у края, уменьшаются к углу.
        x = (u - 0.5) * span
        top = h * (1 - abs(x) / (span / 2)) - 0.25
        z = v * h
        if z > top:
            return 0.0
        fig = 0.0
        for cx, sc in ((-1.6, 1.0), (-4.2, 0.6)):
            fu = (x - cx) / (2.2 * sc) + 0.5
            fv = z / (2.6 * sc)
            if 0 < fu < 1 and 0 < fv < 1:
                fig = max(fig, motif_figure(fu, fv, 0.03))
        frame = _band(top - z - 0.12, 0.05)
        return max(fig, frame)

    field = relief_field(span, h, 0.2, damage(tympanum, seed, 0.25, 3.0), res=0.05, base=1.0)
    for sx in (-1, 1):
        nrm = Vector((sx * h, 0.0, span / 2)).normalized()
        geom = list(field.verts) + list(field.edges) + list(field.faces)
        res = bmesh.ops.bisect_plane(field, geom=geom, plane_co=(0, 0, h), plane_no=nrm, clear_outer=True)
        edges = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
        if edges:
            bmesh.ops.holes_fill(field, edges=edges, sides=0)
    asm.add(field, M, T(0, 0, 0))
    ang = math.degrees(math.atan2(h, span / 2))
    for sx in (-1, 1):
        asm.add(block(span / 2 / math.cos(math.radians(ang)) + 0.6, 1.6, 0.45, 0.04), M,
                T(sx * span / 4, 0.3, h / 2 + 0.25) @ rot(sx * ang, "Y"))
    asm.add(block(span + 0.6, 1.7, 0.45, 0.04), M, T(0, 0.3, -0.22))
    obj = L.merge_objects(name, asm.build(), coll)
    obj = _solidify_damage(name, [obj], coll, seed, voxel=0.035, tris=12000)
    # Отколотая правая половина: убираем всё за рваной линией излома.
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    n = Vector((1.0, 0.0, 0.35)).normalized()
    geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
    res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(1.2, 0, 0), plane_no=n, clear_outer=True)
    edges = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
    if edges:
        bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bm.to_mesh(obj.data)
    bm.free()
    L.voxel_remesh(obj, 0.04)
    off = Vector((2.2, 0.4, 0.0))
    L.displace(obj, lambda co, nr: -0.15 * max(0.0, 1 - abs((co - Vector((1.2, 0, 0))).dot(n)) / 0.3)
               * (0.5 + 0.5 * L.noise.noise(co * 2.0 + off)))
    L.decimate(obj, 9000)
    return [_finish(obj, seed, ao=1.2, ground=False, sharp=40, col="trimesh", col_tris=200)]


def relief_panel_figure():
    """Стенная панель 2 × 2,6 м с безликой фигурой (стиль руин §4.3) — редкий акцент у входа/алтаря."""
    name, seed = "relief_panel_figure", 8603
    coll = L.asset_collection(name)
    asm = P.Assembly(name, coll)
    fn = damage(lambda u, v: max(motif_figure((u - 0.1) / 0.8, (v - 0.05) / 0.9) if 0.1 < u < 0.9 and v > 0.05 else 0.0,
                                 _band(max(abs(u - 0.5) / 0.5, abs(v - 0.5) / 0.5) - 0.94, 0.03)), seed, 0.5, 4.0)
    asm.add(relief_field(2.0, 2.6, 0.06, fn, res=0.02, base=0.5), M)
    obj = L.merge_objects(name, asm.build(), coll)
    L.decimate(obj, 5000)
    return [_finish(obj, seed, ao=0.6, ground=False, sharp=40, col=None)]


def relief_panel_geometric():
    """Стенная панель 2 × 2 м: вложенные прямоугольники, разомкнутое кольцо, клинья — система знаков
    без перевода (стиль руин §4.2; не канонические символы)."""
    name, seed = "relief_panel_geometric", 8604
    coll = L.asset_collection(name)
    asm = P.Assembly(name, coll)

    def fn(u, v):
        if v > 0.5:
            return motif_ring_open(u, (v - 0.5) * 2)
        return max(motif_chevrons(u, v * 2), motif_nested(u, v * 2) * 0.6)

    asm.add(relief_field(2.0, 2.0, 0.05, damage(fn, seed, 0.4, 5.0), res=0.02, base=0.5), M)
    obj = L.merge_objects(name, asm.build(), coll)
    L.decimate(obj, 5000)
    return [_finish(obj, seed, ao=0.6, ground=False, sharp=40, col=None)]


# --------------------------------------------------------------------------------------
# Портал, разбитые ворота, обломки крыши
# --------------------------------------------------------------------------------------
def portal_frame():
    """Портал входа (SHS-05): два монолитных косяка 8 м с полосой вложенных рамок, перемычка 9,4 м
    с трещиной и просевшим концом, порог. Проём 6 × 8 м — Горный Король проходит, не протискиваясь."""
    name, seed = "portal_frame", 8701
    coll = L.asset_collection(name)
    asm = P.Assembly(name, coll)
    for sx in (-1, 1):
        asm.add(block(1.7, 1.6, 8.0, 0.04), M, T(sx * 3.85, 0, 4.0))
        band = relief_field(1.0, 6.4, 0.03, damage(lambda u, v: motif_nested(u, (v * 6) % 1.0), seed + sx, 0.4, 3.0),
                            res=0.03, base=0.2)
        asm.add(band, M, T(sx * 3.85, -0.8 - 0.005, 0.8))
    lintel = block(9.4, 1.8, 1.7, 0.05)
    asm.add(lintel, M, T(0, 0, 8.85) @ rot(1.2, "Y"))
    asm.add(block(7.6, 2.2, 0.3, 0.03), M, T(0, 0, 0.15))
    obj = L.merge_objects(name, asm.build(), coll)
    obj = _solidify_damage(name, [obj], coll, seed, crack=None, voxel=0.04, tris=9000)
    # Трещина перемычки: клиновидная выборка через всю высоту у правой трети.
    off = Vector((seed, 0.0, 0.0))
    L.displace(obj, lambda co, nr: -0.12 * max(0.0, 1 - abs(co.x - 1.6 - 0.25 * (co.z - 8.0) - 0.08 * L.noise.noise(co * 3 + off)) / 0.08)
               if co.z > 7.9 else 0.0)
    L.decimate(obj, 8000)
    return [_finish(obj, seed, ao=1.5, sharp=40, col="trimesh", col_tris=200)]


def gate_broken():
    """Разбитые высокие ворота (CANON: «как будто разбиты рукой великана»; материал не назван —
    ART-DIRECTION: каменные створки 3 × 7,5 м с резными филёнками). Одна створка стоит обломком
    у косяка, вторая расколота на крупные куски, лежащие внутрь зала."""
    name, seed = "gate_broken", 8702
    coll = L.asset_collection(name)
    r = random.Random(seed)
    asm = P.Assembly(name, coll)
    leaf_w, leaf_h, th = 3.0, 7.5, 0.35

    def leaf_relief(u, v):
        return max(_band(max(abs(u - 0.5) / 0.42, abs((v % 0.333) * 3 - 0.5) / 0.42) - 1.0, 0.05), 0.0)

    # Обломок левой створки: нижние ~2,6 м, верх отбит по рваной диагонали.
    stand = relief_field(leaf_w, 2.9, 0.04, leaf_relief, res=0.05, base=th)
    asm.add(stand, M, T(-leaf_w / 2 - 0.02, 0.4, 0.3) @ rot(-8, "Z"))
    # Куски правой створки: ячейки Вороного на плоскости створки → плиты, лежащие веером.
    sites = L.poisson_2d(r, 0.0, leaf_w, 0.0, leaf_h, 1.3)
    cells = L.voronoi_cells(sites, [], (0.0, 0.0, leaf_w, leaf_h))
    for k, (site, poly) in enumerate(zip(sites, cells)):
        if len(poly) < 3 or r.random() < 0.15:
            continue
        bm = bmesh.new()
        L.slab_from_poly(bm, [p - site for p in L.shrink_poly(poly, 0.02)], th / 2, -th / 2, bevel=0.03)
        P._uv_along(bm, 0)
        lie = T(r.uniform(-3.2, -0.6), r.uniform(1.2, 5.5), th / 2 + 0.02) @ rot(r.uniform(0, 360), "Z") @ rot(r.uniform(-8, 8), "X")
        asm.add(bm, M, lie)
    obj = L.merge_objects(name, asm.build(), coll)
    obj = _solidify_damage(name, [obj], coll, seed, voxel=0.03, tris=9000)
    return [_finish(obj, seed, ao=1.0, sharp=40, col="trimesh", col_tris=250)]


def roof_rubble_a():
    """Обломки крыши (SHS-12, CANON гл. 1801: груды обломков под снегом): переломленная каменная
    балка-плита 5 м, крупные куски плит и щебень с наносом снега."""
    name, seed = "roof_rubble_a", 8801
    coll = L.asset_collection(name)
    r = random.Random(seed)
    asm = P.Assembly(name, coll)
    for k, (x, y, rz, tilt, ln) in enumerate(((0.0, 0.0, 10, 8, 2.6), (2.4, 0.6, -18, -14, 2.2))):
        bm = block(ln, 1.0, 0.7, 0.04)
        chip_corners(bm, seed + k, count=3, size=0.25)
        asm.add(bm, M, T(x, y, 0.4 + 0.25 * k) @ rot(rz, "Z") @ rot(tilt, "Y"))
    for k in range(9):
        s = r.uniform(0.25, 0.7)
        bm = L.hull_chunk(seed + 10 + k, (s * 1.6, s * 1.2, s * 0.6), npts=14, cuts=6)
        asm.add(bm, M, T(r.uniform(-1.5, 3.5), r.uniform(-1.2, 1.6), s * 0.2) @ rot(r.uniform(0, 360), "Z"))
    objs = asm.build()
    sbm = bmesh.new()
    L.snow_patch(sbm, 1.0, 0.2, 2.2, 1.4, 0.35, z0=-0.02, seed=seed)
    L.snow_patch(sbm, -0.6, -0.4, 1.0, 0.8, 0.2, z0=-0.02, seed=seed + 1)
    objs.append(L.object_from_bmesh(name + "_snow", sbm, coll, "nm_snow"))
    obj = L.merge_objects(name, objs, coll)
    return [_finish(obj, seed, ao=1.0, sharp=40, col="trimesh", col_tris=200)]


def roof_slab_a():
    """Каменная плита перекрытия 6 × 2,4 × 0,6 м с трещиной и отбитым краем: из таких собирается
    уцелевшая часть крыши; пропуски между плитами — проломы для лунного света (CANON)."""
    name, seed = "roof_slab_a", 8802
    coll = L.asset_collection(name)
    asm = P.Assembly(name, coll)
    bm = block(2.4, 6.0, 0.6, 0.04)
    chip_corners(bm, seed, count=3, size=0.35)
    asm.add(bm, M, T(0, 0, 0.3))
    obj = L.merge_objects(name, asm.build(), coll)
    obj = _solidify_damage(name, [obj], coll, seed, voxel=0.035, tris=3000)
    off = Vector((seed, 0, 0))
    L.displace(obj, lambda co, nr: -0.05 * max(0.0, 1 - abs(co.y - 0.8 - 0.4 * co.x - 0.1 * L.noise.noise(co * 2 + off)) / 0.05))
    return [_finish(obj, seed, ao=0.8, ground=False, sharp=40, col="convex")]


GROUPS = {
    "columns": [column_intact, column_broken_a, column_broken_b, column_fallen],
    "walls": [wall_block_intact, wall_block_ruined],
    "ground": [stairs_a, floor_a, floor_b],
    "altar": [altar_black_marble],
    "facade": [entablature_a, pediment_fragment, relief_panel_figure, relief_panel_geometric],
    "entrance": [portal_frame, gate_broken, roof_rubble_a, roof_slab_a],
}

VIEW = {"walls": (-1.0, -0.45, 0.35), "facade": (-0.3, -1.0, 0.3), "entrance": (-0.35, -1.0, 0.5)}


def _inst(c, loc, rz=0.0, tag=""):
    inst = bpy.data.objects.new(f"inst_{tag}{c.name}", None)
    inst.instance_type = "COLLECTION"
    inst.instance_collection = c
    L.preview_collection().objects.link(inst)
    inst.location = loc
    inst.rotation_euler = (0, 0, math.radians(rz))
    return inst


def hall_diorama(by, ox):
    """Сборка зала из модулей для превью (не игровая сцена): вход с −Y по лестнице, зал 17 × 26 м,
    два ряда колонн, стены, частично уцелевшая крыша с проломами, алтарь в дальнем конце."""
    objs = []
    z0 = 6 * 0.22  # верх лестницы = пол зала
    add = lambda n, loc, rz=0.0, tag="": objs.append(_inst(by[n], (ox + loc[0], loc[1], loc[2]), rz, tag))  # noqa: E731
    # Портик: пол y ∈ [−4, 0], шесть колонн на y = −3, лестница до y = −4.
    add("stairs_a", (0, -7.3, 0))
    for i, x in enumerate((-6.0, -2.0, 2.0, 6.0)):
        add("floor_a", (x, -4.0, z0), 0, f"pf{i}_")
    for k, x in enumerate((-8.75, -5.25, -1.75, 1.75, 5.25, 8.75)):
        add("column_broken_a" if k == 4 else "column_intact", (x, -3.0, z0), 0, f"pc{k}_")
    for k, x in enumerate((-6.0, 0.0)):
        add("entablature_a", (x, -3.0, z0 + 9.95), 0, f"pe{k}_")
    for i, x in enumerate((-6.0, -2.0, 2.0, 6.0)):
        for j in range(7):
            add("floor_b" if (i + j) % 3 == 0 else "floor_a", (x, j * 4.0, z0), 0, f"f{i}{j}_")
    add("portal_frame", (0, 0.0, z0))
    add("gate_broken", (-1.5, 0.6, z0), 0)
    for k, y in enumerate((3.0, 8.0, 13.0, 18.0, 23.0)):
        for sx in (-1, 1):
            name = "column_intact"
            if (k, sx) in ((1, 1), (3, -1)):
                name = "column_broken_a"
            if (k, sx) == (2, 1):
                name = "column_broken_b"
            add(name, (sx * 5.0, y, z0), 0, f"c{k}{sx}_")
    add("column_fallen", (4.2, 13.5, z0), 75, "cf_")
    for k, y in enumerate((3.0, 9.0, 15.0, 21.0)):
        for sx in (-1, 1):
            add("wall_block_ruined" if (k + (sx > 0)) % 3 == 0 else "wall_block_intact", (sx * 8.7, y, z0), 0, f"w{k}{sx}_")
            if not ((k, sx) in ((1, 1), (2, 1))):
                add("entablature_a", (sx * 5.0, y, z0 + 9.95), 90, f"e{k}{sx}_")
    for k, x in enumerate((-6.0, 0.0, 6.0)):
        add("wall_block_intact", (x, 26.6, z0), 90, f"wb{k}_")
    for k, x in enumerate((-5.6, 5.6)):
        add("wall_block_ruined" if k else "wall_block_intact", (x, -0.2, z0), 90, f"wf{k}_")
    add("pediment_fragment", (-0.5, -3.3, z0 + 9.95 + 2.9), 0)
    roof_z = z0 + 9.95 + 2.9
    for k, y in enumerate((1.3, 3.7, 10.9, 13.3, 20.5)):
        add("roof_slab_a", (0.0, y, roof_z), 90, f"rn{k}_")
    for sx in (-1, 1):
        for k, y in enumerate((3.0, 15.0) if sx < 0 else (9.0, 21.0)):
            add("roof_slab_a", (sx * 6.9, y, roof_z), 0, f"rs{k}{sx}_")
    for k, (x, y) in enumerate(((-1.5, 8.0), (2.4, 15.5), (-3.9, 19.5))):
        add("roof_rubble_a", (x, y, z0), 30 * k, f"rr{k}_")
    add("relief_panel_figure", (-7.95, 23.5, z0 + 1.0), 90, "pf_")
    add("relief_panel_geometric", (7.95, 23.5, z0 + 1.0), -90, "pg_")
    add("altar_black_marble", (0.0, 23.6, z0), 0)
    man = L.mannequin(location=(ox + 0.8, 20.5, z0), name="ScaleRef_hall")
    objs.append(man)
    return objs


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = argv[argv.index("--only") + 1].split(",") if "--only" in argv else list(GROUPS)
    test = argv[argv.index("--test") + 1] if "--test" in argv else None
    export = "--no-export" not in argv and not test
    t0 = time.time()
    L.clear_data()
    built = {}
    for g in only:
        built[g] = []
        for fn in GROUPS[g]:
            objs = fn()
            coll = objs[0].users_collection[0]
            built[g].append(coll)
            tris = sum(L.tri_count(o) for o in coll.all_objects if o.type == "MESH" and not o.name.endswith("colonly"))
            print(f"BUILT {coll.name}: tris={tris} t={time.time() - t0:.1f}s")
    if export:
        for colls in built.values():
            for coll in colls:
                L.export_collection(coll, OUT_DIR / f"{coll.name}.glb")
    L.set_assets_visible(False)
    gnd = L.ground(size=200.0)
    L.setup_render(res=(1600, 900), samples=48 if test else 128, sun_elev=24.0, sun_az=-40.0)
    out_dir = Path(test).parent if test else L.PREVIEW_DIR
    prefix = (Path(test).stem + "_") if test else "temple_"
    ox = 0.0
    jobs = []
    for g, colls in built.items():
        insts = []
        x = ox
        for c in colls:
            pts = [p for o in c.all_objects if o.type == "MESH" and not o.hide_render for p in L.world_points(o)]
            x0, x1 = min(p.x for p in pts), max(p.x for p in pts)
            inst = bpy.data.objects.new("inst_" + c.name, None)
            inst.instance_type = "COLLECTION"
            inst.instance_collection = c
            L.preview_collection().objects.link(inst)
            inst.location = (x - x0, 0, 0)
            insts.append(inst)
            x += (x1 - x0) + 1.0
        man = L.mannequin(location=(x + 0.3, -0.5, 0), name=f"ScaleRef_{g}")
        jobs.append((g, insts, man))
        ox = x + 30
    allp = list(L.preview_collection().objects)
    for g, insts, man in jobs:
        for o in allp:
            o.hide_render = o not in insts and o is not man and o.type in ("EMPTY", "MESH") and o is not gnd
        pts = [p for o in insts for p in L.world_points(o)]
        gnd.location.x = (min(p.x for p in pts) + max(p.x for p in pts)) / 2
        gnd.location.z = -0.33 if g == "ground" else 0.0
        L.frame_camera(insts + [man], direction=VIEW.get(g, (-0.45, -1.0, 0.45)), lens=45, margin=1.06)
        L.render(str(out_dir / f"{prefix}{g}.jpg"))
        if g == "altar":
            L.frame_camera(insts, direction=(-0.6, -1.0, 0.55), lens=60, margin=1.2)
            L.render(str(out_dir / f"{prefix}{g}_close.jpg"))
    by = {c.name: c for colls in built.values() for c in colls}
    if {"stairs_a", "column_intact", "altar_black_marble", "portal_frame", "roof_slab_a", "entablature_a"} <= set(by):
        hall = hall_diorama(by, ox + 40.0)
        allp = list(L.preview_collection().objects)
        for o in allp:
            o.hide_render = o not in hall and o.type in ("EMPTY", "MESH") and o is not gnd
        gnd.location = (ox + 40.0, 10.0, 0.0)
        gnd.scale = (1.0, 1.0, 1.0)
        # Ночь: холодный лунный свет сверху сквозь проломы, тёмное небо (бриф святилища §7).
        sun = bpy.data.lights["PreviewSun"]
        sun.color = (0.72, 0.82, 1.0)
        sun.energy = 2.6
        sun.angle = math.radians(0.6)
        bpy.data.objects["PreviewSun"].rotation_euler = (math.radians(22), math.radians(-8), math.radians(-30))
        bg = next(n for n in bpy.context.scene.world.node_tree.nodes if n.type == "BACKGROUND")
        bg.inputs["Color"].default_value = (0.012, 0.016, 0.026, 1.0)
        bg.inputs["Strength"].default_value = 1.0
        cam = L.frame_camera(hall, direction=(-0.75, -1.0, 0.32), lens=30, margin=1.05)
        L.render(str(out_dir / f"{prefix}hall_exterior.jpg"))
        cam.data.lens = 22
        cam.location = (ox + 40.0 + 0.9, 13.0, 1.32 + 1.65)
        cam.rotation_euler = (math.radians(83), 0, math.radians(3))
        L.render(str(out_dir / f"{prefix}hall_interior.jpg"))
    for o in allp:
        o.hide_render = False
    if export:
        L.save_blend(SRC / "temple_kit.blend")
    print("DONE", time.time() - t0)


main()

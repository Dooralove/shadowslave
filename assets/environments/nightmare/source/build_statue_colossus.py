"""Колосс безголового рыцаря Забытого берега / Чёрного моря.

Канон (гл. 30–32): гигантский рыцарь ~200 м; голова отсутствует; круглая каменная
площадка ~12 м в диаметре — срез шеи; на нагруднике семь звёзд; меч опущен остриём вниз;
вокруг чёрная вода. Платформа — место, где Санни пережидает прилив.

Сборка:
    blender -b --factory-startup --python assets/environments/nightmare/source/build_statue_colossus.py
Результат:
    assets/environments/nightmare/statue/statue_knight_colossus.glb
    assets/environments/nightmare/source/statue_colossus.blend
    docs/art/previews/forgotten_shore/statue_*.jpg
"""

from __future__ import annotations

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
import nm_coral_lib as CL  # noqa: E402
import nm_statue_materials as SM  # noqa: E402

OUT = L.NM_DIR / "statue"
PREV = L.ROOT / "docs" / "art" / "previews" / "forgotten_shore"
T = lambda x, y, z: Matrix.Translation((x, y, z))
TAU = 2.0 * math.pi

DARK = "nm_statue_dark"
PALE = "nm_statue_pale"
BRONZE = "nm_statue_bronze"
STAR = "nm_statue_star"
CRACK = "nm_statue_crack"


# ---------------------------------------------------------------------------
# Базовые детали
# ---------------------------------------------------------------------------
def add_box(coll, name, size, pos, mat=DARK, bevel=0.18, rot=(0, 0, 0)):
    bm = P.board(*size, bevel=bevel)
    bm.transform(T(*pos) @ Matrix.Rotation(rot[2], 4, "Z") @
                 Matrix.Rotation(rot[1], 4, "Y") @ Matrix.Rotation(rot[0], 4, "X"))
    return L.object_from_bmesh(name, bm, coll, mat)


def add_sphere(coll, name, r, pos, scale=(1, 1, 1), mat=DARK, segs=24, rings=12, wobble=0.02, seed=0):
    bm = CL.ellipsoid(r * scale[0], r * scale[1], r * scale[2], center=pos,
                      wobble=wobble, seed=seed, segs=segs, rings=rings)
    return L.object_from_bmesh(name, bm, coll, mat)


def add_ring_wall(coll, name, r_in, r_out, z0, heights, mat=DARK, segs=72):
    bm = bmesh.new()
    inner_b, outer_b, inner_t, outer_t = [], [], [], []
    for i in range(segs):
        a = TAU * i / segs
        h = heights[i]
        wob = 1.0 + 0.025 * math.sin(5 * a + 1.7) + 0.012 * math.sin(11 * a)
        inner_b.append(bm.verts.new((math.cos(a) * r_in * wob, math.sin(a) * r_in * wob, z0)))
        outer_b.append(bm.verts.new((math.cos(a) * r_out * wob, math.sin(a) * r_out * wob, z0)))
        inner_t.append(bm.verts.new((math.cos(a) * r_in * wob, math.sin(a) * r_in * wob, z0 + h)))
        outer_t.append(bm.verts.new((math.cos(a) * r_out * wob, math.sin(a) * r_out * wob, z0 + h)))
    for i in range(segs):
        j = (i + 1) % segs
        if heights[i] <= 0.0 or heights[j] <= 0.0:
            continue
        bm.faces.new((inner_b[i], inner_b[j], outer_b[j], outer_b[i]))
        bm.faces.new((outer_t[i], outer_t[j], inner_t[j], inner_t[i]))
        bm.faces.new((inner_t[i], inner_t[j], inner_b[j], inner_b[i]))
        bm.faces.new((outer_b[i], outer_b[j], outer_t[j], outer_t[i]))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    obj = L.object_from_bmesh(name, bm, coll, mat)
    L.shade(obj, 34.0)
    return obj


def add_disc(coll, name, radius, thickness, z=0.0, segs=64, mat=DARK, seed=0):
    rng = random.Random(seed)
    bm = bmesh.new()
    top = []
    for i in range(segs):
        a = TAU * i / segs
        rr = radius * (1.0 + 0.035 * math.sin(3 * a + seed) + 0.018 * math.sin(7 * a + 2.1))
        top.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, z)))
    top_face = bm.faces.new(top)
    bot = []
    for i in range(segs):
        a = TAU * i / segs
        rr = radius * (1.0 + 0.025 * math.sin(4 * a + 1.3))
        bot.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, z - thickness)))
    bm.faces.new(list(reversed(bot)))
    for i in range(segs):
        bm.faces.new((top[i], top[(i + 1) % segs], bot[(i + 1) % segs], bot[i]))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    # Лёгкий наклон/скол кромки: срезаем несколько углов.
    for _ in range(3):
        i = rng.randrange(segs)
        v = top[i]
        v.co.z -= rng.uniform(0.08, 0.35)
    obj = L.object_from_bmesh(name, bm, coll, mat)
    L.shade(obj, 35.0)
    return obj


def add_loft(coll, name, rings, mat=DARK, cap_bottom=True, cap_top=True):
    bm = CL.ring_loft(rings, cap_bottom=cap_bottom, cap_top=cap_top)
    obj = L.object_from_bmesh(name, bm, coll, mat)
    L.shade(obj, 38.0)
    return obj


def add_star(coll, name, outer, inner, thickness, pos, mat=STAR):
    bm = bmesh.new()
    top = []
    bot = []
    pts = 5
    for i in range(pts * 2):
        a = math.pi * 0.5 + math.pi * i / pts
        rr = outer if i % 2 == 0 else inner
        top.append(bm.verts.new((math.cos(a) * rr, 0, math.sin(a) * rr)))
        bot.append(bm.verts.new((math.cos(a) * rr, -thickness, math.sin(a) * rr)))
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    for i in range(pts * 2):
        bm.faces.new((top[i], top[(i + 1) % (pts * 2)], bot[(i + 1) % (pts * 2)], bot[i]))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    if thickness > 0.2:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=min(0.12, thickness * 0.25),
                        segments=1, affect="EDGES")
    bm.transform(T(*pos))
    obj = L.object_from_bmesh(name, bm, coll, mat)
    L.shade(obj, 30.0)
    return obj


def add_rivet_row(coll, prefix, start, end, count, radius=0.16, mat=BRONZE):
    a = Vector(start)
    b = Vector(end)
    for i in range(count):
        t = i / max(count - 1, 1)
        p = a.lerp(b, t)
        add_sphere(coll, f"{prefix}_{i}", radius, p, segs=8, rings=5, mat=mat, wobble=0.0)


def add_crack(coll, name, points, radius=0.12, mat=CRACK):
    bm = P.tube([Vector(p) for p in points], radius, segs=6)
    obj = L.object_from_bmesh(name, bm, coll, mat)
    L.shade(obj, 30.0)
    return obj


def add_barnacles(coll, prefix, center, count, radius=0.35, seed=0):
    rng = random.Random(seed)
    for i in range(count):
        a = rng.uniform(0, TAU)
        r = radius * rng.uniform(0.3, 1.2)
        p = (center[0] + math.cos(a) * r, center[1] + math.sin(a) * r, center[2] + rng.uniform(-0.15, 0.15))
        add_sphere(coll, f"{prefix}_{i}", rng.uniform(0.07, 0.16) * radius * 3.0, p,
                   scale=(1.0, 0.65, 0.45), mat=PALE, segs=8, rings=5, wobble=0.2, seed=seed + i)


# ---------------------------------------------------------------------------
# Шея, платформа, воротник
# ---------------------------------------------------------------------------
def add_fracture_ring(coll, name, r_in, r_out, z_top, depth, mat_a=PALE, mat_b=DARK, segs=48, seed=0):
    rng = random.Random(seed)
    bm = bmesh.new()
    for i in range(segs):
        a = TAU * i / segs
        if i in (0, 1, 23, 24):
            continue
        rr_i = r_in * (1.0 + 0.015 * math.sin(5 * a + seed))
        rr_o = r_out * (1.0 + 0.025 * math.sin(7 * a + 2.0) + rng.uniform(-0.02, 0.02))
        z = z_top - rng.uniform(0.0, 0.28)
        inner_t = bm.verts.new((math.cos(a) * rr_i, math.sin(a) * rr_i, z))
        outer_t = bm.verts.new((math.cos(a) * rr_o, math.sin(a) * rr_o, z_top - rng.uniform(0.05, 0.22)))
        a2 = TAU * (i + 1) / segs
        rr_i2 = r_in * (1.0 + 0.015 * math.sin(5 * a2 + seed))
        rr_o2 = r_out * (1.0 + 0.025 * math.sin(7 * a2 + 2.0))
        z2 = z_top - rng.uniform(0.0, 0.28)
        inner_t2 = bm.verts.new((math.cos(a2) * rr_i2, math.sin(a2) * rr_i2, z2))
        outer_t2 = bm.verts.new((math.cos(a2) * rr_o2, math.sin(a2) * rr_o2, z_top - rng.uniform(0.05, 0.22)))
        inner_b = bm.verts.new((math.cos(a) * rr_i, math.sin(a) * rr_i, z_top - depth))
        inner_b2 = bm.verts.new((math.cos(a2) * rr_i2, math.sin(a2) * rr_i2, z_top - depth))
        outer_b = bm.verts.new((math.cos(a) * rr_o, math.sin(a) * rr_o, z_top - depth))
        outer_b2 = bm.verts.new((math.cos(a2) * rr_o2, math.sin(a2) * rr_o2, z_top - depth))
        bm.faces.new((inner_t, outer_t, outer_t2, inner_t2))
        bm.faces.new((inner_t2, outer_t2, outer_b2, inner_b2))
        bm.faces.new((inner_b2, outer_b2, outer_b, inner_b))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    obj = L.object_from_bmesh(name, bm, coll, mat_a)
    obj.data.materials.append(bpy.data.materials[mat_b])
    # Часть граней — тёмный скол.
    for p in obj.data.polygons:
        if (p.index * 7 + seed) % 5 == 0:
            p.material_index = 1
    L.shade(obj, 30.0)
    return obj


def build_body(coll):
    parts = [
        CL.ellipsoid(30, 22, 32, center=(0, 0, -40), wobble=0.03, seed=301, segs=40, rings=24),
        CL.ellipsoid(24, 20, 22, center=(0, 0, -62), wobble=0.03, seed=302, segs=36, rings=20),
        CL.ellipsoid(20, 18, 14, center=(0, 0, -76), wobble=0.03, seed=303, segs=32, rings=18),
    ]
    for sx in (-1, 1):
        parts.append(CL.ellipsoid(16, 14, 14, center=(sx * 32, 0, -21), wobble=0.03, seed=305 + sx,
                                  segs=28, rings=16))
        parts.append(CL.ellipsoid(9, 8, 16, center=(sx * 36, 0, -37), wobble=0.03, seed=307 + sx,
                                  segs=24, rings=14))
    # ???-???????: ????????? ????? ? ????????.
    rings = []
    for i, (z, r) in enumerate(((-2.0, 6.4), (-5.0, 7.3), (-8.0, 8.6), (-11.0, 9.8))):
        ring = []
        for k in range(28):
            a = TAU * k / 28
            rr = r * (1.0 + 0.02 * math.sin(5 * a + i))
            ring.append((math.cos(a) * rr, math.sin(a) * rr, z))
        rings.append(ring)
    parts.append(CL.ring_loft(rings))
    bm = L.join_bmeshes([(p, Matrix.Identity(4)) for p in parts])
    obj = L.object_from_bmesh("StatueBody", bm, coll, DARK)
    L.voxel_remesh(obj, 0.55)
    L.smooth(obj, 0.5, 2)
    L.rock_detail(obj, 9, 50.0, large=0.018, medium=0.008, fine=0.003, crack_depth=0.008)
    L.decimate(obj, 26000)
    L.shade(obj, 42.0)
    return obj


def build_neck(coll):
    add_disc(coll, "NeckPlatform", 5.6, 2.4, 0.0, segs=72, mat=DARK, seed=10)
    add_fracture_ring(coll, "NeckFracture", 5.55, 6.12, 0.04, 1.5, PALE, DARK, 56, 17)
    # Площадка-срез: плоская, с бороздами. Верх не трогаем — по нему ходит игрок.
    for i in range(7):
        a = TAU * i / 7
        bm = P.board(4.6, 0.022, 0.006, bevel=0.002)
        bm.transform(T(math.cos(a) * 2.3, math.sin(a) * 2.3, 0.006) @ Matrix.Rotation(a, 4, "Z"))
        obj = L.object_from_bmesh(f"NeckGrooveRadial{i}", bm, coll, DARK)
    for j, r in enumerate((2.7, 4.7)):
        path = [Vector((math.cos(TAU * i / 48) * r, math.sin(TAU * i / 48) * r, 0.006)) for i in range(48)]
        bm = P.tube(path, 0.012, segs=6, closed=True)
        obj = L.object_from_bmesh(f"NeckGrooveRing{j}", bm, coll, DARK)
        L.shade(obj, 30.0)

    # Обломанная кромка: плиты по кругу, часть наклонена/утоплена.
    rng = random.Random(11)
    heights = []
    for i in range(72):
        if i in range(0, 5) or i in range(33, 38):
            heights.append(0.0)
        else:
            heights.append(rng.uniform(0.12, 0.34))
    for i in range(9):
        a = rng.uniform(0, TAU)
        r = rng.uniform(5.2, 6.4)
        add_sphere(coll, f"NeckRimStone{i}", rng.uniform(0.18, 0.42),
                   (math.cos(a) * r, math.sin(a) * r, -0.18),
                   scale=(1.2, 0.9, 0.55), mat=DARK if i % 3 else PALE,
                   segs=10, rings=6, wobble=0.35, seed=30 + i)

    # Падение/срез шеи: ступенчатый конус вниз.
    rings = []
    for i, (z, r) in enumerate(((-2.4, 6.0), (-4.2, 6.9), (-6.2, 7.8), (-8.0, 8.45), (-9.8, 8.8))):
        ring = []
        for k in range(36):
            a = TAU * k / 36
            rr = r * (1.0 + 0.025 * math.sin(5 * a + i * 1.7) + 0.012 * math.sin(9 * a))
            ring.append((math.cos(a) * rr, math.sin(a) * rr, z))
        rings.append(ring)
    add_loft(coll, "NeckBase", rings, DARK)

    # Обломки головы/шлема на площадке: намёк, а не второй череп.
    rng = random.Random(12)
    for i in range(5):
        a = rng.uniform(0, TAU)
        r = rng.uniform(2.8, 5.2)
        p = (math.cos(a) * r, math.sin(a) * r, 0.35)
        if i == 0:
            add_sphere(coll, "FallenHelm", 1.6, p, scale=(1.4, 1.0, 0.55), mat=PALE,
                       segs=18, rings=9, wobble=0.18, seed=13)
            add_box(coll, "FallenVisor", (2.4, 0.45, 0.65), (p[0], p[1] + 0.5, 0.42), BRONZE,
                    bevel=0.08, rot=(0.2, 0, a))
        else:
            add_box(coll, f"FallenChunk{i}", (rng.uniform(1.1, 2.3), rng.uniform(0.6, 1.2),
                                               rng.uniform(0.4, 0.9)), p, DARK if i % 2 else PALE,
                    bevel=0.12, rot=(rng.uniform(-0.3, 0.3), rng.uniform(-0.2, 0.2), a))

    # Морская живность у кромки: мелкие известковые наросты, не коралловый кит.
    for i in range(8):
        a = TAU * i / 8
        add_barnacles(coll, f"NeckBarnacle{i}", (math.cos(a) * 5.55, math.sin(a) * 5.55, -0.35),
                      5, 0.32, seed=100 + i)

    # Трещины на шейном конусе.
    add_crack(coll, "NeckCrackA", [(0.0, 8.6, -4.5), (0.35, 8.3, -6.0), (0.1, 8.0, -7.5)], 0.14)
    add_crack(coll, "NeckCrackB", [(-7.8, 1.8, -5.2), (-7.5, 2.4, -6.8), (-7.2, 2.1, -8.4)], 0.12)


# ---------------------------------------------------------------------------
# Грудная клетка, звёзды, плечи
# ---------------------------------------------------------------------------
def rrect(w, d, c):
    return [(-w / 2 + c, -d / 2), (w / 2 - c, -d / 2), (w / 2, -d / 2 + c), (w / 2, d / 2 - c),
            (w / 2 - c, d / 2), (-w / 2 + c, d / 2), (-w / 2, d / 2 - c), (-w / 2, -d / 2 + c)]


def add_plate_xz(coll, name, points, y, depth, mat=DARK, bevel=0.2):
    bm = bmesh.new()
    front = [bm.verts.new((x, y, z)) for x, z in points]
    back = [bm.verts.new((x, y - depth, z)) for x, z in points]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(points)
    for i in range(n):
        bm.faces.new((front[i], front[(i + 1) % n], back[(i + 1) % n], back[i]))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    if bevel:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect="EDGES")
    obj = L.object_from_bmesh(name, bm, coll, mat)
    L.shade(obj, 35.0)
    return obj


def add_curved_plate(coll, name, x0, x1, z0, z1, nx, nz, y_edge, bulge, depth, mat=DARK):
    bm = bmesh.new()
    front = []
    for j in range(nz + 1):
        z = z0 + (z1 - z0) * j / nz
        row = []
        for i in range(nx + 1):
            x = x0 + (x1 - x0) * i / nx
            u = (x - (x0 + x1) * 0.5) / max(abs(x1 - x0) * 0.5, 1e-3)
            v = (z - (z0 + z1) * 0.5) / max(abs(z1 - z0) * 0.5, 1e-3)
            y = y_edge + bulge * max(0.0, 1.0 - u * u - v * v)
            row.append(bm.verts.new((x, y, z)))
        front.append(row)
    back = [[bm.verts.new((v.co.x, v.co.y - depth, v.co.z)) for v in row] for row in front]
    for j in range(nz):
        for i in range(nx):
            bm.faces.new((front[j][i], front[j][i + 1], front[j + 1][i + 1], front[j + 1][i]))
            bm.faces.new((back[j + 1][i], back[j + 1][i + 1], back[j][i + 1], back[j][i]))
    for i in range(nx):
        bm.faces.new((front[0][i], back[0][i], back[0][i + 1], front[0][i + 1]))
        bm.faces.new((front[nz][i + 1], back[nz][i + 1], back[nz][i], front[nz][i]))
    for j in range(nz):
        bm.faces.new((front[j][0], front[j + 1][0], back[j + 1][0], back[j][0]))
        bm.faces.new((front[j + 1][nx], front[j][nx], back[j][nx], back[j + 1][nx]))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    obj = L.object_from_bmesh(name, bm, coll, mat)
    L.shade(obj, 35.0)
    return obj


def build_chest(coll):
    # ?????????????? ????: ??????? ? ?????, ????? ? ?????. ?? ????.
    levels = [(-10.0, 46, 30, 4), (-18.0, 60, 40, 6), (-34.0, 58, 40, 6),
              (-50.0, 48, 34, 5), (-62.0, 38, 28, 4), (-70.0, 32, 24, 3)]
    # ????????/???? ??? ????????? ???.
    # ?????????: ????????? ????? ? ??????????? ?????? ? ??????? ???????.
    # ?????????? ?????? ???? ?????: ????????? ??????? ?????? ? ?????? ????????? ??????????.
    # ??????? ???? ? ?????.
    # ????? ? ????.
    add_box(coll, "Belt", (44, 30, 6), (0, 0, -80), DARK, bevel=0.5)
    add_box(coll, "BeltEdge", (42, 31, 0.6), (0, 0, -77.0), BRONZE, bevel=0.08)

    # ???? ?????: ??????????? ? ????? ??????; ?????????? ?? ??????????? ???????.
    def chest_surface(x, z):
        return 22.0 * math.sqrt(max(0.02, 1.0 - (x / 30.0) ** 2 - ((z + 40.0) / 32.0) ** 2))

    # ??????????? ?????????: ????????? ?????????? ?????, ? ??????? ? V-???????? ?????.
    nx, nz = 18, 16
    z0, z1 = -12.0, -56.0
    front = []
    back = []
    for j in range(nz + 1):
        t = j / nz
        z = z0 + (z1 - z0) * t
        w = 27.0 - 9.0 * t
        row_f, row_b = [], []
        for i in range(nx + 1):
            x = -w + 2.0 * w * i / nx
            y = chest_surface(x, z) + 0.35
            row_f.append(Vector((x, y, z)))
            row_b.append(Vector((x, y - 1.3, z)))
        front.append(row_f)
        back.append(row_b)
    bm = bmesh.new()
    fv = [[bm.verts.new(v) for v in row] for row in front]
    bv = [[bm.verts.new(v) for v in row] for row in back]
    for j in range(nz):
        for i in range(nx):
            bm.faces.new((fv[j][i], fv[j][i + 1], fv[j + 1][i + 1], fv[j + 1][i]))
            bm.faces.new((bv[j + 1][i], bv[j + 1][i + 1], bv[j][i + 1], bv[j][i]))
    for i in range(nx):
        bm.faces.new((fv[0][i], bv[0][i], bv[0][i + 1], fv[0][i + 1]))
        bm.faces.new((fv[nz][i + 1], bv[nz][i + 1], bv[nz][i], fv[nz][i]))
    for j in range(nz):
        bm.faces.new((fv[j][0], fv[j + 1][0], bv[j + 1][0], bv[j][0]))
        bm.faces.new((fv[j + 1][nx], fv[j][nx], bv[j][nx], bv[j + 1][nx]))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.16, segments=1, affect="EDGES")
    obj = L.object_from_bmesh("Breastplate", bm, coll, DARK)
    L.shade(obj, 35.0)
    # ??????? ?????? ?? ???????.
    rim = []
    rim += [front[0][i] + Vector((0, 0.12, 0)) for i in range(nx + 1)]
    rim += [front[j][nx] + Vector((0, 0.12, 0)) for j in range(1, nz + 1)]
    rim += [front[nz][i] + Vector((0, 0.12, 0)) for i in range(nx - 1, -1, -1)]
    rim += [front[j][0] + Vector((0, 0.12, 0)) for j in range(nz - 1, 0, -1)]
    bm = P.tube(rim, 0.22, segs=6, closed=True)
    obj = L.object_from_bmesh("BreastplateRim", bm, coll, PALE)
    L.shade(obj, 30.0)

    def chest_y(x, z):
        return chest_surface(x, z) + 1.0

    star_z = -33.0
    add_sphere(coll, "StarRecessCenter", 4.4, (0, chest_y(0, star_z) + 0.15, star_z),
               scale=(1.0, 0.045, 1.0), mat=CRACK, segs=24, rings=10, wobble=0.0)
    add_star(coll, "StarCenter", 4.4, 1.85, 0.8, (0, chest_y(0, star_z) + 0.60, star_z))
    for i in range(6):
        a = -math.pi * 0.5 + TAU * i / 6
        x, z = math.cos(a) * 12.2, star_z + math.sin(a) * 12.2
        add_sphere(coll, f"StarRecess{i}", 3.0, (x, chest_y(x, z) + 0.15, z), scale=(1.0, 0.045, 1.0),
                   mat=CRACK, segs=20, rings=8, wobble=0.0)
        add_star(coll, f"Star{i}", 3.0, 1.25, 0.7, (x, chest_y(x, z) + 0.60, z))

    add_rivet_row(coll, "ChestRivetTop", (-24, 22.7, -13.0), (24, 22.7, -13.0), 11, 0.14)
    add_rivet_row(coll, "ChestRivetBottom", (-17, 22.7, -53.8), (17, 22.7, -53.8), 11, 0.14)


def add_ellipse_ring(coll, name, cx, cy, z, rx, ry, tube=0.12, mat=PALE, segs=48):
    path = [Vector((cx + math.cos(TAU * i / segs) * rx,
                    cy + math.sin(TAU * i / segs) * ry, z)) for i in range(segs)]
    bm = P.tube(path, tube, segs=6, closed=True)
    obj = L.object_from_bmesh(name, bm, coll, mat)
    L.shade(obj, 34.0)
    return obj


def build_shoulders(coll):
    for side in (-1, 1):
        sx = side
        # ??????????? ???????? ???????? ?? ?????.
        add_sphere(coll, f"PauldronCap{sx}", 1.0, (sx * 34.0, 0, -18.0),
                   scale=(17.0, 13.5, 5.0), mat=DARK, segs=36, rings=16, wobble=0.02, seed=20 + sx)
        add_ellipse_ring(coll, f"PauldronRim{sx}", sx * 34.0, 0, -22.6, 17.2, 13.7, 0.18, PALE)
        # ????? ? ????? ????????; ?????? ????????? ??????? ? ???????, ??? ?????????.
        path = [Vector((sx * 32.0, -13 + 26 * i / 16, -16.0 + 7.0 * math.sin(math.pi * i / 16)))
                for i in range(17)]
        bm = P.tube(path, 0.30, segs=7)
        obj = L.object_from_bmesh(f"ShoulderRidge{sx}", bm, coll, PALE)
        L.shade(obj, 30.0)
        add_crack(coll, f"ShoulderCrack{sx}", [(sx * 28, -14, -18), (sx * 33, -15, -25), (sx * 30, -14, -32)], 0.14)


def build_arms(coll):
    # Правая рука свободно опущена.
    path_r = [Vector((34, 0, -26)), Vector((41, 2, -40)), Vector((43, 4, -56)), Vector((42, 6, -78))]
    bm = P.tube(path_r, 9.0, segs=16, radius_fn=lambda t: 0.95 - 0.32 * t)
    obj = L.object_from_bmesh("ArmEast", bm, coll, DARK)
    L.shade(obj, 40.0)
    add_sphere(coll, "ElbowEast", 8.8, (43, 4, -56), scale=(1.0, 0.9, 1.0), mat=DARK, seed=40)
    add_sphere(coll, "HandEast", 6.2, (42, 7, -84), scale=(0.8, 1.1, 1.2), mat=DARK, seed=41)
    for i in range(4):
        add_box(coll, f"FingerEast{i}", (2.2, 3.0, 6.2), (38.0 + i * 2.7, 7.5, -89.0),
                DARK, bevel=0.15, rot=(0.2, 0, 0))
    add_box(coll, "ThumbEast", (2.8, 3.0, 5.0), (47.0, 5.5, -86.0), DARK, bevel=0.15, rot=(0, 0.3, 0))

    # Левая рука ведёт к рукояти меча.
    path_l = [Vector((-34, 0, -26)), Vector((-41, 5, -40)), Vector((-42, 16, -52)), Vector((-38, 30, -59))]
    bm = P.tube(path_l, 9.0, segs=16, radius_fn=lambda t: 0.95 - 0.32 * t)
    obj = L.object_from_bmesh("ArmWest", bm, coll, DARK)
    L.shade(obj, 40.0)
    add_sphere(coll, "ElbowWest", 8.8, (-42, 16, -52), scale=(1.0, 0.9, 1.0), mat=DARK, seed=42)
    # Кисть на рукояти.
    add_sphere(coll, "HandWest", 6.2, (-38, 30, -59), scale=(0.8, 1.1, 1.2), mat=DARK, seed=43)
    for i in range(4):
        add_box(coll, f"FingerWest{i}", (2.2, 3.0, 6.2), (-43.0 + i * 2.7, 30.5, -59.0),
                DARK, bevel=0.15, rot=(0.2, 0, 0))
    add_box(coll, "ThumbWest", (2.8, 3.0, 5.0), (-34.0, 28.5, -57.0), DARK, bevel=0.15, rot=(0, -0.3, 0))

    # Наручи/наплечные обручи.


# ---------------------------------------------------------------------------
# Меч
# ---------------------------------------------------------------------------
def build_sword(coll):
    sx, sy = -38.0, 30.0
    add_sphere(coll, "SwordPommel", 3.1, (sx, sy, -47.5), scale=(1, 0.9, 1), mat=DARK, seed=50)
    bm = P.cylinder(1.8, 10.0, segs=16, axis="Z")
    bm.transform(T(sx, sy, -54.0))
    obj = L.object_from_bmesh("SwordGrip", bm, coll, BRONZE)
    L.shade(obj, 38.0)
    for z in (-50.0, -54.0, -58.0):
        add_box(coll, f"GripRing{int(z)}", (4.2, 4.2, 0.5), (sx, sy, z), PALE, bevel=0.1)
    add_box(coll, "SwordGuard", (50, 6.5, 4.0), (sx, sy, -61.5), DARK, bevel=0.35)
    add_box(coll, "SwordGuardEdge", (48, 1.0, 4.2), (sx, sy, -60.0), PALE, bevel=0.1)
    add_box(coll, "SwordGuardTipW", (2.5, 3.0, 4.4), (sx - 25.0, sy, -61.5), BRONZE, bevel=0.2)
    add_box(coll, "SwordGuardTipE", (2.5, 3.0, 4.4), (sx + 25.0, sy, -61.5), BRONZE, bevel=0.2)

    # Клинок: прямоугольное сечение с фаской, сужение к острию.
    add_plate_xz(coll, "SwordBlade", [(sx - 6.5, -63), (sx + 6.5, -63), (sx + 5.2, -148), (sx, -160), (sx - 5.2, -148)],
                 sy + 2.4, 4.8, PALE, bevel=0.22)
    add_plate_xz(coll, "BladeRidge", [(sx - 1.0, -66), (sx + 1.0, -66), (sx + 0.7, -146), (sx, -154), (sx - 0.7, -146)],
                 sy + 2.65, 0.35, DARK, bevel=0.05)
    # Дол/ребро и кромки.
    add_box(coll, "BladeFuller", (2.2, 0.22, 82), (sx, sy + 2.3, -107), CRACK, bevel=0.04)
    add_box(coll, "BladeEdgeW", (0.34, 4.0, 90), (sx - 5.6, sy, -108), BRONZE, bevel=0.03)
    add_box(coll, "BladeEdgeE", (0.34, 4.0, 90), (sx + 5.6, sy, -108), BRONZE, bevel=0.03)
    # Сколы на кромке.
    for i, z in enumerate((-78, -101, -128)):
        add_box(coll, f"BladeChip{i}", (0.95, 3.2, 1.6), (sx - 4.2, sy, z), DARK,
                bevel=0.08, rot=(0.3, 0, 0.2))

    # Трещина по клинку.
    add_crack(coll, "BladeCrack", [(sx - 1.0, sy + 1.35, -82), (sx - 0.4, sy + 1.35, -96),
                                   (sx - 1.2, sy + 1.35, -111)], 0.07)


# ---------------------------------------------------------------------------
# Нижнее тело и постамент
# ---------------------------------------------------------------------------
def build_lower(coll):
    add_box(coll, "Waist", (36, 26, 12), (0, 0, -78), DARK, bevel=0.6)
    add_box(coll, "Pelvis", (33, 24, 16), (0, 0, -89), DARK, bevel=0.6)
    add_box(coll, "PelvisBand", (35, 25, 1.2), (0, 0, -82.5), BRONZE, bevel=0.1)
    for sx in (-1, 1):
        add_box(coll, f"Tasset{sx}", (13, 22, 14), (sx * 17, 0, -96), DARK, bevel=0.4,
                rot=(0, sx * 0.08, 0))
        add_box(coll, f"TassetTrim{sx}", (12, 1.2, 0.8), (sx * 17, 9.6, -91), PALE, bevel=0.05)
        # Нога: два сегмента + колено + наголенник.
        rings = []
        for j, (z, rx, ry) in enumerate(((-102, 12.0, 13.0), (-122, 11.0, 12.0), (-142, 9.8, 10.8),
                                         (-166, 8.4, 9.4), (-180, 7.4, 8.2))):
            ring = []
            for k in range(18):
                a = TAU * k / 18
                ring.append((sx * 14 + math.cos(a) * rx, math.sin(a) * ry, z))
            rings.append(ring)
        add_loft(coll, f"Leg{sx}", rings, DARK)
        add_sphere(coll, f"Knee{sx}", 8.0, (sx * 14, 2.5, -124), scale=(1.0, 0.9, 0.9),
                   mat=DARK, segs=20, rings=10, wobble=0.02, seed=60 + sx)
        add_box(coll, f"KneePlate{sx}", (13, 2.4, 12), (sx * 14, 7.0, -124), PALE,
                bevel=0.35, rot=(0.15, 0, 0))
        add_box(coll, f"ThighPlate{sx}", (16, 2.4, 30), (sx * 14, 8.0, -112), PALE,
                bevel=0.45, rot=(-0.06, 0, 0))
        add_box(coll, f"ThighTrim{sx}", (12, 0.6, 0.7), (sx * 14, 9.3, -98), BRONZE, bevel=0.06)
        add_box(coll, f"Greave{sx}", (15, 2.6, 36), (sx * 14, 6.5, -155), DARK,
                bevel=0.45, rot=(-0.08, 0, 0))
        add_box(coll, f"GreaveRidge{sx}", (2.0, 0.8, 30), (sx * 14, 8.0, -155), PALE, bevel=0.1)
        add_box(coll, f"GreaveTrim{sx}", (9, 0.5, 0.6), (sx * 14, 6.7, -139), PALE, bevel=0.05)
        add_box(coll, f"Foot{sx}", (13, 19, 8), (sx * 14, 4, -185), DARK, bevel=0.5)
        add_box(coll, f"FootTrim{sx}", (12, 17, 0.7), (sx * 14, 4, -181.5), PALE, bevel=0.06)
        add_rivet_row(coll, f"LegRivet{sx}", (sx * 14 - 5, 8.2, -146), (sx * 14 + 5, 8.2, -146), 4, 0.13)

    # Постамент: три ступени, скол на западном углу.
    for i in range(5):
        x = -18 + i * 9.0
        add_box(coll, f"FauldFront{i}", (10.0, 3.2, 14.0), (x, 15.0, -88.0), DARK,
                bevel=0.35, rot=(0.05, 0.0, -0.04 * (i - 2)))
        add_box(coll, f"FauldFrontTrim{i}", (9.0, 0.5, 0.6), (x, 16.7, -81.5), PALE, bevel=0.05)
    for i in range(3):
        x = -12 + i * 12.0
        add_box(coll, f"FauldBack{i}", (10.0, 3.2, 12.0), (x, -15.0, -88.0), DARK,
                bevel=0.35, rot=(-0.05, 0.0, 0.03 * (i - 1)))

    add_box(coll, "PlinthTop", (36, 42, 5), (0, 0, -190), DARK, bevel=0.5)
    add_box(coll, "PlinthMid", (41, 47, 5), (0, 0, -195), DARK, bevel=0.5)
    add_box(coll, "PlinthBase", (47, 53, 5), (0, 0, -200), PALE, bevel=0.5)
    add_box(coll, "PlinthChip", (8, 9, 3), (-23, -24, -198), DARK, bevel=0.3, rot=(0.2, 0.3, 0.4))
    add_crack(coll, "PlinthCrack", [(-15, 22, -188), (-12, 22.5, -193), (-16, 22, -198)], 0.18)
    for i in range(8):
        a = TAU * i / 8
        add_barnacles(coll, f"PlinthBarnacle{i}", (math.cos(a) * 19, math.sin(a) * 21, -190),
                      4, 0.35, seed=200 + i)


# ---------------------------------------------------------------------------
# Маски и материал
# ---------------------------------------------------------------------------
def bake_statue_mask(obj, seed=0, rays=5, ao_dist=2.2):
    from mathutils.bvhtree import BVHTree
    rng = random.Random(seed)
    mesh = obj.data
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.transform(obj.matrix_world)
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    mw = obj.matrix_world
    nmat = mw.to_3x3().inverted().transposed()
    off = Vector((seed * 1.7, seed * 3.1, seed * 2.3))
    vals = []
    for v in mesh.vertices:
        co = mw @ v.co
        n = (nmat @ v.normal).normalized()
        origin = co + n * 0.02
        hits = 0
        for d in CL._hemisphere(rng, n, rays):
            if tree.ray_cast(origin, d, ao_dist)[0] is not None:
                hits += 1
        ao = 0.42 + 0.58 * (1.0 - hits / rays) ** 1.2
        salt = 0.25 + 0.75 * noise.noise(co * 0.10 + off)
        salt = max(0.0, min(1.0, salt))
        vals.append((ao, salt, 0.0, 0.0))
    attr = mesh.color_attributes.get(L.MASK_ATTR) or mesh.color_attributes.new(
        L.MASK_ATTR, "FLOAT_COLOR", "POINT")
    for i, val in enumerate(vals):
        attr.data[i].color = val
    L.set_active_mask(mesh)
    return obj


def preview_material(name, spec, texsets):
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    if spec["kind"] == "plain":
        bsdf.inputs["Base Color"].default_value = (*spec["color"], 1.0)
        bsdf.inputs["Roughness"].default_value = spec.get("rough", 0.8)
        bsdf.inputs["Metallic"].default_value = spec.get("metallic", 0.0)
        if "emission" in spec:
            bsdf.inputs["Emission Color"].default_value = (*spec["emission"], 1.0)
            bsdf.inputs["Emission Strength"].default_value = spec.get("emission_energy", 1.0)
        return mat
    base = texsets[spec["base"]]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1.0 / base["tile"],) * 3
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    alb = nt.nodes.new("ShaderNodeTexImage")
    alb.image = bpy.data.images.load(str(L.TEX_DIR / base["albedo"]), check_existing=True)
    alb.projection = "BOX"
    alb.projection_blend = 0.3
    nt.links.new(mp.outputs["Vector"], alb.inputs["Vector"])
    tint = nt.nodes.new("ShaderNodeMix")
    tint.data_type = "RGBA"
    tint.blend_type = "MULTIPLY"
    tint.inputs["Factor"].default_value = 1.0
    nt.links.new(alb.outputs["Color"], tint.inputs["A"])
    tint.inputs["B"].default_value = (*spec.get("tint", (1, 1, 1)), 1.0)
    nor = nt.nodes.new("ShaderNodeTexImage")
    nor.image = bpy.data.images.load(str(L.TEX_DIR / base["normal"]), check_existing=True)
    nor.image.colorspace_settings.name = "Non-Color"
    nor.projection = "BOX"
    nor.projection_blend = 0.3
    nt.links.new(mp.outputs["Vector"], nor.inputs["Vector"])
    arm = nt.nodes.new("ShaderNodeTexImage")
    arm.image = bpy.data.images.load(str(L.TEX_DIR / base["arm"]), check_existing=True)
    arm.image.colorspace_settings.name = "Non-Color"
    arm.projection = "BOX"
    arm.projection_blend = 0.3
    nt.links.new(mp.outputs["Vector"], arm.inputs["Vector"])
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(arm.outputs["Color"], sep.inputs["Color"])
    nrm = nt.nodes.new("ShaderNodeNormalMap")
    nrm.inputs["Strength"].default_value = spec.get("normal", 1.0)
    nt.links.new(nor.outputs["Color"], nrm.inputs["Color"])
    micro = nt.nodes.new("ShaderNodeTexNoise")
    micro.inputs["Scale"].default_value = 3.0
    micro.inputs["Detail"].default_value = 6.0
    nt.links.new(tc.outputs["Object"], micro.inputs["Vector"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.22
    bump.inputs["Distance"].default_value = 0.15
    nt.links.new(micro.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(nrm.outputs["Normal"], bump.inputs["Normal"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    att = nt.nodes.new("ShaderNodeAttribute")
    att.attribute_name = L.MASK_ATTR
    att.attribute_type = "GEOMETRY"
    sep_att = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(att.outputs["Color"], sep_att.inputs["Color"])
    ao = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(sep_att.outputs["Red"], ao.inputs["X"])
    nt.links.new(sep_att.outputs["Red"], ao.inputs["Y"])
    nt.links.new(sep_att.outputs["Red"], ao.inputs["Z"])
    mix_ao = nt.nodes.new("ShaderNodeMix")
    mix_ao.data_type = "RGBA"
    mix_ao.blend_type = "MULTIPLY"
    mix_ao.inputs["Factor"].default_value = 0.35
    nt.links.new(tint.outputs["Result"], mix_ao.inputs["A"])
    nt.links.new(ao.outputs["Vector"], mix_ao.inputs["B"])
    nt.links.new(mix_ao.outputs["Result"], bsdf.inputs["Base Color"])
    rough = nt.nodes.new("ShaderNodeMath")
    rough.operation = "MULTIPLY_ADD"
    rough.inputs[1].default_value = spec.get("rough_scale", 1.0)
    rough.inputs[2].default_value = spec.get("rough_offset", 0.0)
    nt.links.new(sep.outputs["Green"], rough.inputs[0])
    nt.links.new(rough.outputs[0], bsdf.inputs["Roughness"])
    bsdf.inputs["Metallic"].default_value = spec.get("metallic", 0.0)
    return mat


# ---------------------------------------------------------------------------
# Сборка
# ---------------------------------------------------------------------------
def build():
    L.clear_data()
    L.register_materials(SM.MATERIALS, SM.TEXSETS)
    for name, spec in SM.MATERIALS.items():
        preview_material(name, spec, SM.TEXSETS)
    coll = L.asset_collection("statue_knight_colossus")
    build_body(coll)
    build_neck(coll)
    build_chest(coll)
    build_shoulders(coll)
    build_arms(coll)
    build_sword(coll)
    build_lower(coll)
    # Склейка в один объект с несколькими слотами материалов.
    objs = [o for o in coll.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = "statue_knight_colossus"
    obj.data.validate(verbose=False, clean_customdata=False)
    L.shade(obj, 38.0)
    L.uv_box(obj, 1.0)
    bake_statue_mask(obj, seed=7, rays=5, ao_dist=2.2)
    L.export_collection(coll, OUT / "statue_knight_colossus.glb")
    L.save_blend(L.SOURCE_DIR / "statue_colossus.blend")
    return obj


def add_black_water(z=-72.0):
    bpy.ops.mesh.primitive_plane_add(size=2400, location=(0, 0, z))
    obj = bpy.context.object
    obj.name = "BlackSeaWater"
    mat = bpy.data.materials.new("preview_black_water")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (0.003, 0.006, 0.011, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.07
    bsdf.inputs["Metallic"].default_value = 0.0
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 0.08
    noise.inputs["Detail"].default_value = 5.0
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.18
    bump.inputs["Distance"].default_value = 0.25
    nt.links.new(noise.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    obj.data.materials.append(mat)
    return obj


def render_previews(obj):
    L.setup_render(res=(1400, 900), samples=24, sun_elev=18.0, sun_az=-40.0,
                   sun_power=4.2, sky=(0.34, 0.38, 0.44), sky_strength=1.15)
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE"
        scene.eevee.taa_render_samples = 32
    except Exception:
        pass
    scene.view_settings.exposure = 0.65
    sun = bpy.data.lights.get("PreviewSun")
    if sun:
        sun.color = (0.78, 0.84, 0.96)
    # ???????? ????????? ????: ?????? ?????? ? ??????.
    rim_data = bpy.data.lights.get("RimLight") or bpy.data.lights.new("RimLight", "SUN")
    rim_data.energy = 1.8
    rim_data.color = (0.55, 0.68, 0.92)
    rim_data.angle = math.radians(4.0)
    rim = bpy.data.objects.get("RimLight") or bpy.data.objects.new("RimLight", rim_data)
    if rim.name not in bpy.context.scene.collection.objects:
        bpy.context.scene.collection.objects.link(rim)
    rim.rotation_euler = (math.radians(65), 0.0, math.radians(140))
    L.ground(size=280.0, z=-200.5, snow=False)
    L.mannequin(location=(3.0, 0.0, 0.0))
    L.mannequin(location=(8.0, 10.0, -199.0))
    bpy.context.view_layer.update()
    full_data = bpy.data.cameras.get("StatueFullCam") or bpy.data.cameras.new("StatueFullCam")
    full = bpy.data.objects.get("StatueFullCam") or bpy.data.objects.new("StatueFullCam", full_data)
    if full.name not in bpy.context.scene.collection.objects:
        bpy.context.scene.collection.objects.link(full)
    full_data.lens = 52.0
    full_data.clip_end = 4000.0
    full.location = (160.0, 900.0, -80.0)
    full.rotation_euler = (Vector((0, 0, -80)) - full.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = full
    L.render(PREV / "statue_full.jpg")

    # Шея/платформа с манекеном.
    cam_data = bpy.data.cameras.get("StatueNeckCam") or bpy.data.cameras.new("StatueNeckCam")
    cam = bpy.data.objects.get("StatueNeckCam") or bpy.data.objects.new("StatueNeckCam", cam_data)
    if cam.name not in bpy.context.scene.collection.objects:
        bpy.context.scene.collection.objects.link(cam)
    cam_data.lens = 52.0
    cam.location = (8.0, 11.0, 5.5)
    cam.rotation_euler = (Vector((0, 0, -1.5)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    L.render(PREV / "statue_neck.jpg")

    # Грудь и семь звёзд.
    cam.location = (24.0, 58.0, -25.0)
    cam_data.lens = 50.0
    cam.rotation_euler = (Vector((0, 18, -34)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    L.render(PREV / "statue_chest.jpg")

    # Рука на мече.
    cam.location = (-8.0, 30.0, -45.0)
    cam_data.lens = 55.0
    cam.rotation_euler = (Vector((-30, 12, -60)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    L.render(PREV / "statue_sword_hand.jpg")

    # ?????? ????: ?????? ??????? ????? ??????? ??? ?????, ????????-??? ? ??????.
    ground = bpy.data.objects.get("PreviewGround")
    if ground:
        ground.hide_render = True
    water = add_black_water(-72.0)
    world = bpy.context.scene.world
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.10, 0.12, 0.16, 1.0)
    bg.inputs["Strength"].default_value = 0.75
    sun.energy = 8.0
    if rim_data:
        rim_data.energy = 3.6
    scene.view_settings.exposure = 1.10
    # ????????? ?????? ??????? ?????: ????????, ?????, ??? ? ????.
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, -55))
    dummy = bpy.context.object
    dummy.name = "StatueUpperFrame"
    dummy.scale = (110.0, 110.0, 125.0)
    dummy.hide_render = True
    bpy.context.view_layer.update()
    L.frame_camera([dummy], direction=(0.0, 1.0, 0.18), lens=50.0, margin=1.04,
                   target_offset=(0, 0, 0))
    L.render(PREV / "statue_black_sea.jpg")
    dummy.hide_render = True

    # ?????? ? ????????-??? ??????, ? ????? ? ?????? ????.
    cam = scene.camera
    cam_data = cam.data
    cam.location = (0.0, -8.0, 4.0)
    cam_data.lens = 50.0
    cam.rotation_euler = (Vector((0, 90, -18)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    L.render(PREV / "statue_tide.jpg")


if __name__ == "__main__":
    obj = build()
    if "--no-preview" not in sys.argv:
        render_previews(obj)
    print("DONE statue_knight_colossus")

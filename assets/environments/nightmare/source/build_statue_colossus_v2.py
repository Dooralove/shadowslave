"""Колосс безголового рыцаря, v2: более парадная и детальная каменная броня.

Канон: ~200 м; голова отсутствует; площадка-шея ~12 м; семь звёзд на нагруднике;
меч опущен остриём вниз; Чёрное море.

Оригин: центр верхней плоскости площадки, тело вниз по -Z (Blender).
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
# Мелочи
# ---------------------------------------------------------------------------
def add_obj(coll, name, bm, mat=DARK, smooth=38.0):
    obj = L.object_from_bmesh(name, bm, coll, mat)
    L.shade(obj, smooth)
    return obj


def xform(bm, pos=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    bm.transform(T(*pos) @ Matrix.Rotation(rot[2], 4, "Z") @
                 Matrix.Rotation(rot[1], 4, "Y") @ Matrix.Rotation(rot[0], 4, "X") @
                 Matrix.Diagonal((*scale, 1.0)))
    return bm


def box(coll, name, size, pos, mat=DARK, bevel=0.22, rot=(0, 0, 0)):
    bm = P.board(*size, bevel=bevel)
    xform(bm, pos, rot)
    return add_obj(coll, name, bm, mat)


def sphere(coll, name, radii, pos, mat=DARK, segs=32, rings=18, wobble=0.015, seed=0):
    bm = CL.ellipsoid(radii[0], radii[1], radii[2], center=pos, wobble=wobble, seed=seed,
                      segs=segs, rings=rings)
    return add_obj(coll, name, bm, mat, 42.0)


def tube(coll, name, path, radii, mat=DARK, segs=16, closed=False):
    bm = P.tube([Vector(p) for p in path], radii, segs=segs, closed=closed)
    return add_obj(coll, name, bm, mat, 42.0)


def loft(coll, name, rings, mat=DARK):
    bm = CL.ring_loft(rings)
    return add_obj(coll, name, bm, mat, 40.0)


def dome(coll, name, center, radii, cut_z, thickness, mat=DARK, segs=48, rings=18,
         rim_mat=PALE, rim=0.24):
    """?????-???????? ? ?????????? ?????, ??????? ??????? ? ??? ??????????? ???????."""
    cx, cy, cz = center
    rx, ry, rz = radii
    vmax = math.acos(max(-1.0, min(1.0, (cut_z - cz) / rz)))
    bm = bmesh.new()
    outer, inner = [], []
    for j in range(rings):
        th = vmax * (1.0 - (j + 1) / (rings + 1))
        rr, zz = math.sin(th), math.cos(th)
        ro, ri = [], []
        for i in range(segs):
            a = TAU * i / segs
            ro.append(bm.verts.new((cx + math.cos(a) * rr * rx,
                                    cy + math.sin(a) * rr * ry,
                                    cz + zz * rz)))
            ri.append(bm.verts.new((cx + math.cos(a) * rr * (rx - thickness),
                                    cy + math.sin(a) * rr * (ry - thickness),
                                    cz + zz * (rz - thickness))))
        outer.append(ro)
        inner.append(ri)
    top_o = bm.verts.new((cx, cy, cz + rz))
    top_i = bm.verts.new((cx, cy, cz + rz - thickness))
    for j in range(rings - 1):
        for i in range(segs):
            k = (i + 1) % segs
            bm.faces.new((outer[j][i], outer[j][k], outer[j + 1][k], outer[j + 1][i]))
            bm.faces.new((inner[j + 1][i], inner[j + 1][k], inner[j][k], inner[j][i]))
    # ??????? ?????.
    for i in range(segs):
        k = (i + 1) % segs
        bm.faces.new((outer[rings - 1][i], outer[rings - 1][k], top_o))
        bm.faces.new((top_i, inner[rings - 1][k], inner[rings - 1][i]))
    # ?????? ??????.
    for i in range(segs):
        k = (i + 1) % segs
        bm.faces.new((outer[0][k], outer[0][i], inner[0][i], inner[0][k]))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    obj = add_obj(coll, name, bm, mat, 34.0)
    if rim > 0:
        path = [Vector((cx + math.cos(TAU * i / segs) * (rx - thickness * 0.5),
                        cy + math.sin(TAU * i / segs) * (ry - thickness * 0.5),
                        cut_z)) for i in range(segs)]
        add_obj(coll, name + "Rim", P.tube(path, rim, segs=6, closed=True), rim_mat, 30.0)
    return obj


def star(coll, name, r_out, r_in, depth, pos, mat=STAR):
    bm = bmesh.new()
    top, bot = [], []
    n = 5
    for i in range(n * 2):
        a = math.pi * 0.5 + math.pi * i / n
        rr = r_out if i % 2 == 0 else r_in
        top.append(bm.verts.new((math.cos(a) * rr, 0, math.sin(a) * rr)))
        bot.append(bm.verts.new((math.cos(a) * rr, -depth, math.sin(a) * rr)))
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    for i in range(n * 2):
        k = (i + 1) % (n * 2)
        bm.faces.new((top[i], top[k], bot[k], bot[i]))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=min(0.10, depth * 0.3), segments=1, affect="EDGES")
    bm.transform(T(*pos))
    return add_obj(coll, name, bm, mat, 28.0)


def rivets(coll, prefix, start, end, count, radius=0.18, mat=BRONZE):
    a, b = Vector(start), Vector(end)
    for i in range(count):
        p = a.lerp(b, i / max(count - 1, 1))
        sphere(coll, f"{prefix}{i}", (radius, radius * 0.8, radius * 0.7), p, mat,
               segs=10, rings=6, wobble=0.0)


def crack(coll, name, points, radius=0.10, mat=CRACK):
    bm = P.tube([Vector(p) for p in points], radius, segs=6)
    return add_obj(coll, name, bm, mat, 30.0)


def border_ring(coll, name, path, radius=0.22, mat=PALE):
    bm = P.tube([Vector(p) for p in path], radius, segs=6, closed=True)
    return add_obj(coll, name, bm, mat, 30.0)


def curved_panel(coll, name, xs, zs, y_of, depth, mat=DARK, bevel=0.0):
    """Сетка XZ, передняя поверхность y_of(x,z), задняя на depth назад."""
    nx, nz = len(xs) - 1, len(zs) - 1
    bm = bmesh.new()
    fv, bv = [], []
    for z in zs:
        rf, rb = [], []
        for x in xs:
            y = y_of(x, z)
            rf.append(bm.verts.new((x, y, z)))
            rb.append(bm.verts.new((x, y - depth, z)))
        fv.append(rf)
        bv.append(rb)
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
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect="EDGES")
    return add_obj(coll, name, bm, mat, 38.0)


def curve_edge(coll, name, xs, z, y_of, mat=PALE, radius=0.20):
    path = [Vector((x, y_of(x, z) + 0.05, z)) for x in xs]
    return add_obj(coll, name, P.tube(path, radius, segs=6), mat, 30.0)


# ---------------------------------------------------------------------------
# ????
# ---------------------------------------------------------------------------
def torso_surface(x, z):
    """???????? ??????????? ??????? ?????; z ???? ?? ???."""
    u = x / 34.0
    v = (z + 38.0) / 32.0
    return 23.0 * math.sqrt(max(0.02, 1.0 - u * u - v * v))


def build_body(coll):
    parts = [
        CL.ellipsoid(34, 23, 32, center=(0, 0, -38), wobble=0.025, seed=101, segs=44, rings=26),
        CL.ellipsoid(23, 18, 19, center=(0, 0, -60), wobble=0.025, seed=102, segs=36, rings=20),
        CL.ellipsoid(20, 17, 14, center=(0, 0, -77), wobble=0.025, seed=103, segs=32, rings=18),
        CL.ellipsoid(8.5, 7.5, 10, center=(0, 0, -13), wobble=0.02, seed=104, segs=24, rings=14),
    ]
    for sx in (-1, 1):
        parts.append(CL.ellipsoid(14, 12, 10, center=(sx * 32, 0, -24), wobble=0.025,
                                  seed=110 + sx, segs=28, rings=16))
        parts.append(CL.ellipsoid(9, 8, 13, center=(sx * 38, 0, -38), wobble=0.02,
                                  seed=120 + sx, segs=24, rings=14))
    # ????: ???????, ???? ????????; ????? ????????.
    path_r = [Vector((34, 0, -24)), Vector((41, 2, -42)),
              Vector((44, 5, -62)), Vector((43, 7, -80))]
    parts.append(P.tube(path_r, 10.0, segs=18, radius_fn=lambda t: 1.0 - 0.30 * t))
    path_l = [Vector((-34, 0, -24)), Vector((-38, 10, -44)),
              Vector((-30, 20, -57)), Vector((-6, 24, -65))]
    parts.append(P.tube(path_l, 10.0, segs=18, radius_fn=lambda t: 1.0 - 0.30 * t))
    # ????; ??????.
    for sx in (-1, 1):
        rings = []
        for z, rx, ry in ((-88, 12.5, 13.5), (-105, 12.0, 13.0), (-124, 11.0, 12.0),
                          (-145, 9.8, 10.8), (-168, 8.8, 9.8), (-184, 8.0, 8.8)):
            ring = []
            for k in range(24):
                a = TAU * k / 24
                ring.append((sx * 18 + math.cos(a) * rx, math.sin(a) * ry, z))
            rings.append(ring)
        parts.append(CL.ring_loft(rings))
        parts.append(CL.ellipsoid(10.5, 13.5, 5.0, center=(sx * 18, 3, -190),
                                  wobble=0.02, seed=140 + sx, segs=24, rings=14))
    bm = L.join_bmeshes([(p, Matrix.Identity(4)) for p in parts])
    obj = add_obj(coll, "StatueBody", bm, DARK, 42.0)
    L.voxel_remesh(obj, 0.58)
    L.smooth(obj, 0.5, 2)
    L.rock_detail(obj, 7, 55.0, large=0.012, medium=0.006, fine=0.0025, crack_depth=0.007)
    L.decimate(obj, 32000)
    L.shade(obj, 42.0)
    return obj


# ---------------------------------------------------------------------------
# ????????-???
# ---------------------------------------------------------------------------
def build_platform(coll):
    segs, rings = 128, 16
    radius = 6.0
    depth = 2.2
    bm = bmesh.new()
    center_v = bm.verts.new((0, 0, 0))
    grid = []
    for j in range(1, rings + 1):
        r = radius * j / rings
        row = []
        for i in range(segs):
            a = TAU * i / segs
            # ?????? ????????? ? ?????????? ???????
            g = 0.0
            for rg in (2.45, 4.35):
                g = max(g, max(0.0, 1.0 - abs(r - rg) / 0.045))
            for k in range(8):
                da = abs((a - TAU * k / 8 + math.pi) % TAU - math.pi)
                g = max(g, max(0.0, 1.0 - da / 0.008))
            z = -0.022 * g
            # ?????? ?????????? ?????
            z += 0.006 * math.sin(a * 9 + r * 2.0)
            row.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)))
        grid.append(row)
    for i in range(segs):
        k = (i + 1) % segs
        bm.faces.new((center_v, grid[0][i], grid[0][k]))
    for j in range(rings - 1):
        for i in range(segs):
            k = (i + 1) % segs
            bm.faces.new((grid[j][i], grid[j][k], grid[j + 1][k], grid[j + 1][i]))
    # ???????? ? ???.
    bot = []
    for i in range(segs):
        a = TAU * i / segs
        bot.append(bm.verts.new((math.cos(a) * radius, math.sin(a) * radius, -depth)))
    for i in range(segs):
        k = (i + 1) % segs
        bm.faces.new((grid[-1][i], grid[-1][k], bot[k], bot[i]))
    bm.faces.new(list(reversed(bot)))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    add_obj(coll, "NeckPlatform", bm, DARK, 40.0)

    # ???????? ??????? ???? ?? ??????.
    rng = random.Random(22)
    for band, mat in ((0, PALE), (1, DARK)):
        bm = bmesh.new()
        for i in range(72):
            if i in (0, 1, 2, 37, 38):
                continue
            a0 = TAU * i / 72
            a1 = TAU * (i + 1) / 72
            ro0 = 5.95 + rng.uniform(-0.10, 0.13)
            ro1 = 5.95 + rng.uniform(-0.10, 0.13)
            ri = 5.35
            z0 = -rng.uniform(0.0, 0.16)
            z1 = -rng.uniform(0.0, 0.16)
            v = [bm.verts.new((math.cos(a0) * ri, math.sin(a0) * ri, z0)),
                 bm.verts.new((math.cos(a0) * ro0, math.sin(a0) * ro0, z0 - rng.uniform(0.4, 1.1))),
                 bm.verts.new((math.cos(a1) * ro1, math.sin(a1) * ro1, z1 - rng.uniform(0.4, 1.1))),
                 bm.verts.new((math.cos(a1) * ri, math.sin(a1) * ri, z1))]
            bm.faces.new(v)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        add_obj(coll, f"Fracture{band}", bm, mat, 26.0)

    # ?????? ???????? ?????? ?? ?????????.
    for j, (r, mat, rad) in enumerate(((4.95, DARK, 0.022), (4.72, PALE, 0.018),
                                       (2.55, DARK, 0.018))):
        path = [Vector((math.cos(TAU * i / 96) * r, math.sin(TAU * i / 96) * r, 0.018))
                for i in range(96)]
        add_obj(coll, f"PlatformInlay{j}", P.tube(path, rad, segs=5, closed=True), mat, 26.0)

    # ?????? ??????? ?????? ?????.
    path = [Vector((math.cos(TAU * i / 96) * 5.52, math.sin(TAU * i / 96) * 5.52, 0.035))
            for i in range(96)]
    add_obj(coll, "PlatformInlayRim", P.tube(path, 0.10, segs=5, closed=True), PALE, 26.0)
    # ?????? ???????, ?? ?????????? ??????.
    rng = random.Random(23)
    for i in range(6):
        a = rng.uniform(0, TAU)
        r = rng.uniform(2.5, 4.9)
        p = (math.cos(a) * r, math.sin(a) * r, 0.25)
        if i == 0:
            sphere(coll, "FallenHelm", (0.72, 0.55, 0.38), p, PALE, 18, 10, 0.16, 24)
            box(coll, "FallenVisor", (1.25, 0.30, 0.35), (p[0], p[1] + 0.5, 0.3), BRONZE,
                bevel=0.08, rot=(0.2, 0, a))
        else:
            box(coll, f"Debris{i}", (rng.uniform(0.32, 0.70), rng.uniform(0.22, 0.45),
                                      rng.uniform(0.16, 0.34)), p,
                DARK if i % 2 else PALE, bevel=0.10,
                rot=(rng.uniform(-0.4, 0.4), rng.uniform(-0.2, 0.2), a))

    # ?????? ??????? ?? ??????.
    for i in range(9):
        a = TAU * i / 9
        for j in range(4):
            aa = a + rng.uniform(-0.08, 0.08)
            rr = 5.45 + rng.uniform(-0.25, 0.25)
            sphere(coll, f"RimBarnacle{i}_{j}", (rng.uniform(0.06, 0.14),) * 3,
                   (math.cos(aa) * rr, math.sin(aa) * rr, -0.35), PALE, 8, 5, 0.2, 30 + i)


def build_neck(coll):
    rings = []
    for i, (z, r) in enumerate(((-2.2, 6.2), (-4.5, 6.9), (-7.0, 7.8), (-10.0, 8.8), (-13.0, 9.7))):
        ring = []
        for k in range(40):
            a = TAU * k / 40
            rr = r * (1.0 + 0.018 * math.sin(5 * a + i) + 0.01 * math.sin(9 * a))
            ring.append((math.cos(a) * rr, math.sin(a) * rr, z))
        rings.append(ring)
    loft(coll, "NeckStump", rings, DARK)
    # ???????????? ????????? ??????.
    for i in range(12):
        a = TAU * i / 12
        pts = []
        for z in (-3.0, -5.0, -7.5, -10.5, -13.0):
            rr = 6.4 + (-z - 2.2) * 0.31
            pts.append((math.cos(a) * (rr + 0.05), math.sin(a) * (rr + 0.05), z))
        add_obj(coll, f"NeckFlute{i}", P.tube([Vector(p) for p in pts], 0.10, segs=5), CRACK, 28.0)

    # ????????? ???????? ????????? ??? ?????????.
    rng = random.Random(31)
    for i in range(10):
        if i in (1, 4, 8):
            continue
        a = TAU * i / 10 + 0.12
        h = rng.uniform(2.8, 4.6)
        box(coll, f"BrokenCollar{i}", (4.2, 1.6, h),
            (math.cos(a) * 7.15, math.sin(a) * 7.15, -4.2), DARK,
            bevel=0.22, rot=(rng.uniform(-0.12, 0.12), 0, -a - math.pi * 0.5))
        box(coll, f"BrokenCollarEdge{i}", (4.0, 0.35, 0.7),
            (math.cos(a) * 7.55, math.sin(a) * 7.55, -2.1), PALE,
            bevel=0.05, rot=(0, 0, -a - math.pi * 0.5))
    # ??????: ??? ????? ?????? ?? ????????? ???.
    for j, (z, rr, rad) in enumerate(((-8.0, 9.0, 0.32), (-10.0, 9.8, 0.28), (-12.0, 10.5, 0.24))):
        path = [Vector((math.cos(TAU * i / 64) * rr, math.sin(TAU * i / 64) * rr, z))
                for i in range(64)]
        add_obj(coll, f"GorgetBand{j}", P.tube(path, rad, segs=7, closed=True), PALE if j == 0 else DARK, 30.0)

    # ??????? ?? ???.
    crack(coll, "NeckCrackA", [(0.2, 8.4, -5.0), (0.5, 8.0, -7.0), (0.1, 7.8, -9.0)], 0.12)
    crack(coll, "NeckCrackB", [(-7.7, 2.0, -6.0), (-7.3, 2.5, -8.2), (-7.8, 2.1, -10.0)], 0.10)



# ---------------------------------------------------------------------------
# ????? ?????
# ---------------------------------------------------------------------------
def oval_band(coll, name, center, rx, ry, z, height, thickness, mat=DARK):
    cx, cy = center
    segs = 64
    bm = bmesh.new()
    levels = (z - height / 2, z + height / 2)
    outer, inner = [], []
    for zz in levels:
        ro, ri = [], []
        for i in range(segs):
            a = TAU * i / segs
            ro.append(bm.verts.new((cx + math.cos(a) * rx, cy + math.sin(a) * ry, zz)))
            ri.append(bm.verts.new((cx + math.cos(a) * (rx - thickness),
                                    cy + math.sin(a) * (ry - thickness), zz)))
        outer.append(ro)
        inner.append(ri)
    for i in range(segs):
        k = (i + 1) % segs
        bm.faces.new((outer[0][i], outer[0][k], outer[1][k], outer[1][i]))
        bm.faces.new((inner[1][i], inner[1][k], inner[0][k], inner[0][i]))
        bm.faces.new((outer[1][i], outer[1][k], inner[1][k], inner[1][i]))
        bm.faces.new((inner[0][i], inner[0][k], outer[0][k], outer[0][i]))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return add_obj(coll, name, bm, mat, 34.0)


def chest_trim(coll, name, xs, z, mat=PALE):
    path = [Vector((x, torso_surface(x, z) + 1.05, z)) for x in xs]
    add_obj(coll, name, P.tube(path, 0.22, segs=6), mat, 30.0)


def curved_loft_plate(coll, name, zs, xmax_of, y_of, depth, mat=DARK, nx=12):
    bm = bmesh.new()
    fv, bv = [], []
    for z in zs:
        w = xmax_of(z)
        rf, rb = [], []
        for i in range(nx + 1):
            x = w * i / nx
            y = y_of(x, z)
            rf.append(bm.verts.new((x, y, z)))
            rb.append(bm.verts.new((x, y - depth, z)))
        fv.append(rf)
        bv.append(rb)
    for j in range(len(zs) - 1):
        for i in range(nx):
            bm.faces.new((fv[j][i], fv[j][i + 1], fv[j + 1][i + 1], fv[j + 1][i]))
            bm.faces.new((bv[j + 1][i], bv[j + 1][i + 1], bv[j][i + 1], bv[j][i]))
    for i in range(nx):
        bm.faces.new((fv[0][i], bv[0][i], bv[0][i + 1], fv[0][i + 1]))
        bm.faces.new((fv[-1][i + 1], bv[-1][i + 1], bv[-1][i], fv[-1][i]))
    for j in range(len(zs) - 1):
        bm.faces.new((fv[j][0], fv[j + 1][0], bv[j + 1][0], bv[j][0]))
        bm.faces.new((fv[j + 1][nx], fv[j][nx], bv[j][nx], bv[j + 1][nx]))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return add_obj(coll, name, bm, mat, 38.0)


def build_chest_armor(coll):
    # ??? ???????? ?????????? ? ??????????? ????; ?????? ???????? ? ?????.
    zs = [-13, -18, -23, -28, -33, -38, -43, -48, -53, -58]
    def w_of(z):
        return 30.0 - 8.0 * ((z + 13.0) / -45.0)
    for side in (-1, 1):
        curved_loft_plate(coll, f"Breastplate{side}", zs, w_of,
                          lambda x, z: torso_surface(x, z) + 0.45, 1.8, DARK, 12)
        # ???????? ?? X.
        obj = bpy.data.objects[f"Breastplate{side}"]
        for v in obj.data.vertices:
            v.co.x *= side
        bm2 = bmesh.new()
        bm2.from_mesh(obj.data)
        bmesh.ops.recalc_face_normals(bm2, faces=list(bm2.faces))
        bm2.to_mesh(obj.data)
        bm2.free()
        obj.data.update()
        outer = [Vector((side * w_of(z), torso_surface(w_of(z), z) + 0.55, z)) for z in zs]
        add_obj(coll, f"BreastplateEdge{side}", P.tube(outer, 0.22, segs=6), PALE, 30.0)
        # ??????? ? ?????? ?????? ? ?????? ???????.
        for tag, z in (("Top", -13.0), ("Bottom", -58.0)):
            w = w_of(z)
            xs = [side * (0.8 + (w - 0.8) * i / 12.0) for i in range(13)]
            chest_trim(coll, f"Breastplate{tag}{side}", xs, z)

    # ??????????? ????? (??? ???????, ????? ?? ????????? ??????).
    for z0, z1, tag in ((-58, -45, "Low"), (-24, -13, "High")):
        bm = bmesh.new()
        zs2 = [z0, (z0 + z1) / 2, z1]
        curved_panel(coll, f"ChestRidge{tag}", [-0.75, 0.0, 0.75], zs2,
                     lambda x, z: torso_surface(x, z) + 0.95, 0.8, PALE, 0.0)

    # ?????? ????? ?? ?????? ??????????.
    for z, tag in ((-13.0, "Top"), (-58.0, "Bottom")):
        for side in (-1, 1):
            w = w_of(z)
            for i in range(10):
                x = side * (0.9 + (w - 1.8) * i / 9.0)
                sphere(coll, f"ChestBead{tag}{side}{i}", (0.12, 0.10, 0.12),
                       (x, torso_surface(x, z) + 1.02, z), BRONZE, 8, 5, 0.0, i)

    # ?????? ?????? ?????? ?? ????? ??????????.
    for side in (-1, 1):
        for xo in (7.0, 14.0, 21.0):
            pts = [Vector((side * xo, torso_surface(side * xo, z) + 1.02, z))
                   for z in (-17, -23, -30, -38, -46, -53)]
            add_obj(coll, f"ChestFlute{side}{int(xo)}", P.tube(pts, 0.10, segs=5), PALE, 28.0)

    # ???? ??????????: ??????? ?????? + ?????? + ??????.
    def boss(name, x, z, r, outer):
        y = torso_surface(x, z) + 1.1
        bm = P.cylinder(r, 1.2, segs=32, axis="Y")
        bm.transform(T(x, y, z))
        add_obj(coll, name + "Boss", bm, DARK, 30.0)
        add_obj(coll, name + "BossTrim", P.tube(
            [Vector((x + math.cos(TAU * i / 40) * (r + 0.18), y + 0.62,
                     z + math.sin(TAU * i / 40) * (r + 0.18))) for i in range(40)],
            0.16, segs=6, closed=True), BRONZE, 30.0)
        star(coll, name + "Star", outer, outer * 0.44, 0.55, (x, y + 0.85, z))
        for i in range(6):
            a = TAU * i / 6
            sphere(coll, f"{name}Rivet{i}", (0.10, 0.08, 0.10),
                   (x + math.cos(a) * (r + 0.3), y + 0.66, z + math.sin(a) * (r + 0.3)),
                   PALE, 8, 5, 0.0, i)

    boss("StarCenter", 0.0, -33.0, 3.9, 3.2)
    for i in range(6):
        a = -math.pi * 0.5 + TAU * i / 6
        boss(f"Star{i}", math.cos(a) * 12.0, -33.0 + math.sin(a) * 12.0, 2.7, 2.15)

    # ????????????? ??????.
    for j in range(4):
        z = -60.0 - j * 4.2
        xs = [-18 + 36 * i / 14 for i in range(15)]
        curved_panel(coll, f"AbdomenLame{j}", xs, [z - 1.6, z + 1.6],
                     lambda x, zz: torso_surface(x, zz) + 0.55, 1.4, DARK, 0.0)
        chest_trim(coll, f"AbdomenTrim{j}", xs, z + 1.55, PALE)
        rivets(coll, f"AbdomenRivet{j}", (-12, torso_surface(-12, z) + 1.0, z),
               (12, torso_surface(12, z) + 1.0, z), 6, 0.11)

    # ??????? ????.
    for side in (-1, 1):
        xs = [side * (26 + 5 * i / 6) for i in range(7)]
        curved_panel(coll, f"SidePlate{side}", xs, [-20, -28, -36, -44],
                     lambda x, z: torso_surface(x, z) + 0.35, 1.4, DARK, 0.0)
        chest_trim(coll, f"SidePlateTrim{side}", xs, -20.0, PALE)

    # ???? ? ??????.
    oval_band(coll, "Belt", (0, 0), 23.0, 18.0, -75.0, 7.0, 2.0, DARK)
    oval_band(coll, "BeltEdge", (0, 0), 23.7, 18.7, -72.0, 1.2, 0.8, PALE)
    box(coll, "Buckle", (8.0, 3.0, 7.0), (0, 21.0, -75.0), PALE, 0.35)
    box(coll, "BuckleInner", (4.8, 1.0, 4.2), (0, 22.5, -75.0), CRACK, 0.20)
    for i in range(4):
        box(coll, f"BuckleBar{i}", (0.5, 0.6, 4.4), (-3.2 + i * 2.1, 22.9, -75.0), BRONZE, 0.05)

    rng = random.Random(88)
    # ????????/???????? ??????? ? ?????? ????? ? ?????????.
    xs = [-11.0, -5.5, 0.0, 5.5, 11.0]
    zs = [-79.0, -85.0, -92.0, -100.0, -108.0, -116.0, -124.0]
    bm = bmesh.new()
    fv, bv = [], []
    for jz, z in enumerate(zs):
        rowf, rowb = [], []
        for ix, x in enumerate(xs):
            # ?????? ???
            zz = z - (1.5 if jz == len(zs) - 1 and ix in (1, 4) else 0.0)
            if jz == len(zs) - 1 and ix in (0, 5):
                zz = z
            y = 24.0 + 0.06 * x * x + 0.08 * math.sin(ix * 1.7)
            rowf.append(bm.verts.new((x, y, zz)))
            rowb.append(bm.verts.new((x, y - 0.7, zz)))
        fv.append(rowf)
        bv.append(rowb)
    for j in range(len(zs) - 1):
        for i in range(len(xs) - 1):
            bm.faces.new((fv[j][i], fv[j][i + 1], fv[j + 1][i + 1], fv[j + 1][i]))
            bm.faces.new((bv[j + 1][i], bv[j + 1][i + 1], bv[j][i + 1], bv[j][i]))
    for i in range(len(xs) - 1):
        bm.faces.new((fv[0][i], bv[0][i], bv[0][i + 1], fv[0][i + 1]))
        bm.faces.new((fv[-1][i + 1], bv[-1][i + 1], bv[-1][i], fv[-1][i]))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    add_obj(coll, "Tabard", bm, DARK, 34.0)
    for xb in (xs[0], xs[-1]):
        add_obj(coll, f"TabardBorder{int(xb)}", P.tube(
            [Vector((xb, 24.5 + 0.06 * xb * xb, z)) for z in zs], 0.14, segs=5), PALE, 28.0)
    for i, x in enumerate(xs):
        add_obj(coll, f"TabardFold{i}", P.tube(
            [Vector((x, 24.4 + 0.06 * x * x, z)) for z in zs], 0.12, segs=5), PALE, 28.0)
    # ????? ? ????????.
    for i in range(9):
        x = -11 + i * 2.75
        box(coll, f"TabardFray{i}", (0.7, 0.35, rng.uniform(2.0, 5.0)),
            (x, 24.6, -123.0), DARK, 0.08, rot=(0, 0, rng.uniform(-0.08, 0.08)))

    # ??????: ???? ???????? ? ?????? ???????/?????? ????????.
    for i in range(5):
        x = -16 + i * 8.0
        curved_panel(coll, f"Fauld{i}", [x - 4.4, x, x + 4.4], [-78, -86, -94],
                     lambda xx, z: 20.0 + 0.02 * xx * xx - 0.05 * (z + 78), 1.6, DARK, 0.0)
        box(coll, f"FauldRim{i}", (8.4, 0.5, 0.6), (x, 23.0, -80.0), PALE, 0.05)
        rivets(coll, f"FauldRivet{i}", (x - 3.2, 24.0, -82.0), (x + 3.2, 24.0, -82.0), 3, 0.11)
    for i in range(4):
        a = math.pi * 0.25 + i * math.pi * 0.5
        x, y = math.cos(a) * 18.0, math.sin(a) * 17.0
        box(coll, f"FauldSide{i}", (7.0, 2.0, 16.0), (x, y, -86.0), DARK,
            bevel=0.35, rot=(0, 0, -a))
        box(coll, f"FauldSideTrim{i}", (6.0, 0.4, 0.6), (x, y + (2.0 if y > 0 else -2.0), -80.0),
            PALE, 0.05)


def build_pauldrons(coll):
    for side in (-1, 1):
        sx = side
        dome(coll, f"PauldronMain{sx}", (sx * 33, 0, -20), (16, 13, 7.0), -27, 1.0,
             DARK, 56, 20, PALE, 0.24)
        dome(coll, f"PauldronLameA{sx}", (sx * 34, 0, -27), (15, 12, 3.5), -30, 0.75,
             DARK, 52, 12, PALE, 0.20)
        dome(coll, f"PauldronLameB{sx}", (sx * 34.5, 0, -32), (13, 10, 2.5), -34, 0.65,
             DARK, 48, 10, PALE, 0.18)
        # ?????? ?? ??????.
        for off in (-8.0, 0.0, 8.0):
            pts = []
            for j in range(15):
                y = -13.0 + 26.0 * j / 14
                q = max(0.0, 1.0 - (off / 16.0) ** 2 - (y / 13.0) ** 2)
                z = -20.0 + 7.0 * math.sqrt(q)
                pts.append((sx * 35 + off, y, z + 0.4))
            add_obj(coll, f"PauldronRib{sx}{int(off)}", P.tube([Vector(p) for p in pts], 0.30, segs=6),
                    PALE, 30.0)
        # ???????? ?? ???????? ??????.
        rivets(coll, f"PauldronRivet{sx}", (sx * 33 - 10, 12.0, -25.0),
               (sx * 33 + 10, 12.0, -25.0), 6, 0.11)
        # ???????????: ?????? ???????.
        crack(coll, f"PauldronCrack{sx}", [(sx * 28, -12, -14), (sx * 34, -14, -22),
                                           (sx * 31, -13, -31)], 0.12)
        # ??????? ???????? ? ????????.
        dome(coll, f"Besagew{sx}", (sx * 28, 1, -24), (7, 6, 6), -29, 0.6,
             BRONZE, 32, 10, PALE, 0.14)



# ---------------------------------------------------------------------------
# ???? ? ??????
# ---------------------------------------------------------------------------
def hand(coll, name, wrist, side, grip=False):
    x, y, z = wrist
    palm = sphere(coll, name + "Palm", (5.2, 3.6, 5.8), (x, y, z - 5.0), DARK, 24, 14, 0.02, 50)
    # ??????: ??? ???????? ???????, ????? ?????? ?? ??? ??????????.
    for i in range(4):
        ox = (-3.0 + i * 2.0) if not grip else (-4.2 + i * 2.8)
        px = x + ox
        if grip:
            # ?????? ??????????? ??????? ??????? Y
            box(coll, f"{name}Finger{i}A", (1.7, 3.0, 5.2), (px, y - 1.0, z - 5.2),
                DARK, 0.25, rot=(0.45, 0, 0))
            box(coll, f"{name}Finger{i}B", (1.5, 2.4, 3.8), (px, y + 1.6, z - 8.0),
                DARK, 0.20, rot=(-0.6, 0, 0))
        else:
            box(coll, f"{name}Finger{i}A", (1.7, 2.8, 4.8), (px, y, z - 8.2),
                DARK, 0.22, rot=(0.12, 0, 0))
            box(coll, f"{name}Finger{i}B", (1.4, 2.2, 3.4), (px, y + 0.2, z - 11.0),
                DARK, 0.18, rot=(0.25, 0, 0))
        sphere(coll, f"{name}Knuckle{i}", (1.2, 1.1, 1.1), (px, y, z - 5.7), PALE, 10, 6, 0.0, 51)
    # ??????? ?????.
    box(coll, name + "Thumb", (2.2, 2.4, 5.2), (x - side * 4.3, y + 1.5, z - 5.0),
        DARK, 0.22, rot=(0.2, 0, side * 0.35))
    # ?????.
    oval_band(coll, name + "Cuff", (x, y), 6.2, 5.4, z + 0.5, 3.0, 1.2, PALE)


def build_arms(coll):
    for side in (-1, 1):
        sx = side
        # ??????-????? ?????? ????.
        if sx == 1:
            path = [(34, 0, -25), (41, 2, -43), (44, 5, -63), (43, 7, -81)]
            wrist = (43, 7, -82)
            grip = False
        else:
            path = [(-34, 0, -25), (-38, 10, -44), (-30, 20, -57), (-6, 24, -65)]
            wrist = (-6, 24, -65)
            grip = True
        add_obj(coll, f"Rerebrace{sx}", P.tube([Vector(p) for p in path[:2]], 11.8, segs=20,
                                               radius_fn=lambda t: 1.0 - 0.15 * t), DARK, 40.0)
        add_obj(coll, f"Vambrace{sx}", P.tube([Vector(p) for p in path[2:]], 9.6, segs=18,
                                              radius_fn=lambda t: 1.0 - 0.08 * t), DARK, 40.0)
        # ??????.
        for i, z in enumerate((-43, -60)):
            p0 = path[1] if i == 0 else path[2]
            oval_band(coll, f"ArmBand{sx}{i}", (p0[0], p0[1]), 10.0 if i == 0 else 8.0,
                      9.0 if i == 0 else 7.4, p0[2], 1.6, 0.8, PALE)
        # ?????????? ?????.
        dome(coll, f"Couter{sx}", (path[1][0], path[1][1], path[1][2]), (9.5, 8.5, 8.0),
             path[1][2] - 9.0, 0.9, DARK, 36, 12, PALE, 0.18)
        for i in range(3):
            box(coll, f"CouterFan{sx}{i}", (5.0, 1.0, 4.0),
                (path[1][0] + sx * 4, path[1][1] - 4.0 + i * 4.0, path[1][2] + 2.0),
                PALE if i == 1 else DARK, 0.18, rot=(0, -sx * 0.2, 0))
        # ??????? ???????? ?? ??????????.
        box(coll, f"VambracePlate{sx}", (4.0, 10.0, 16.0),
            (path[2][0] + sx * 5.8, path[2][1] + 2.0, path[2][2] - 3.0),
            DARK, 0.4, rot=(0, sx * 0.08, 0))
        box(coll, f"VambraceRidge{sx}", (1.2, 1.0, 15.0),
            (path[2][0] + sx * 6.0, path[2][1] + 6.8, path[2][2] - 3.0), PALE, 0.1)
        hand(coll, f"Hand{sx}", wrist, sx, grip)


# ---------------------------------------------------------------------------
# ????
# ---------------------------------------------------------------------------
def build_legs(coll):
    for side in (-1, 1):
        sx = side
        # ???????????.
        add_obj(coll, f"Cuisses{sx}", P.tube(
            [Vector((sx * 18, 0, -90)), Vector((sx * 18, 0, -112)), Vector((sx * 18, 0, -124))],
            13.5, segs=20, radius_fn=lambda t: 1.0 - 0.08 * t), DARK, 40.0)
        box(coll, f"ThighPlate{sx}", (14.0, 3.2, 30.0), (sx * 18, 9.8, -107),
            DARK, 0.6, rot=(-0.06, 0, 0))
        box(coll, f"ThighRidge{sx}", (2.0, 1.2, 26.0), (sx * 18, 11.7, -107), PALE, 0.12)
        rivets(coll, f"ThighRivet{sx}", (sx * 15 - 5, 11.8, -96),
               (sx * 15 + 5, 11.8, -96), 4, 0.14)
        # ??????.
        dome(coll, f"Poleyn{sx}", (sx * 18, 5, -126), (9.0, 8.0, 8.0), -132, 0.8,
             DARK, 36, 12, PALE, 0.18)
        box(coll, f"PoleynWing{sx}", (4.0, 2.0, 8.0), (sx * 26, 5, -126), PALE, 0.25,
            rot=(0, -sx * 0.2, 0))
        # ??????????.
        add_obj(coll, f"Greave{sx}", P.tube(
            [Vector((sx * 18, 0, -132)), Vector((sx * 18, 0, -154)), Vector((sx * 18, 0, -178))],
            10.5, segs=20, radius_fn=lambda t: 1.0 - 0.16 * t), DARK, 40.0)
        box(coll, f"GreavePlate{sx}", (13.0, 3.0, 38.0), (sx * 18, 7.8, -155),
            DARK, 0.55, rot=(-0.05, 0, 0))
        box(coll, f"GreaveRidge{sx}", (1.8, 1.0, 36.0), (sx * 18, 9.4, -155), PALE, 0.12)
        rivets(coll, f"GreaveRivet{sx}", (sx * 15 - 4.5, 9.5, -142),
               (sx * 15 + 4.5, 9.5, -142), 4, 0.13)
        # ???????: ??? ????.
        for i, (z, w, d) in enumerate(((-181, 16, 25), (-186, 14, 23), (-190, 11, 19))):
            box(coll, f"Sabaton{sx}{i}", (w, d, 4.0), (sx * 18, 3.0 + i * 1.5, z),
                DARK, 0.4, rot=(-0.08, 0, 0))
            box(coll, f"SabatonTrim{sx}{i}", (w - 1, 1.0, 0.6), (sx * 15, 3.0 + i * 1.5, z + 2.1),
                PALE, 0.05)

    for side in (-1, 1):
        for xo in (-3.5, 0.0, 3.5):
            pts = [Vector((side * 18 + xo, 9.0, z)) for z in (-140, -148, -156, -165, -173)]
            add_obj(coll, f"GreaveFlute{side}{int(xo*10)}", P.tube(pts, 0.09, segs=5), PALE, 28.0)
        for xo in (-3.0, 3.0):
            pts = [Vector((side * 18 + xo, 11.0, z)) for z in (-98, -106, -114, -120)]
            add_obj(coll, f"CuisseFlute{side}{int(xo)}", P.tube(pts, 0.09, segs=5), PALE, 28.0)

    # ?????????.
    box(coll, "PlinthTop", (38, 44, 5), (0, 0, -195), DARK, 0.6)
    box(coll, "PlinthMid", (44, 50, 4), (0, 0, -198.5), PALE, 0.6)
    box(coll, "PlinthBase", (50, 56, 4), (0, 0, -201.5), DARK, 0.6)
    crack(coll, "PlinthCrack", [(-15, 23, -193), (-12, 24, -198), (-16, 23, -201)], 0.16)



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


# ---------------------------------------------------------------------------
# ???
# ---------------------------------------------------------------------------
def build_sword(coll):
    x, y = 0.0, 27.0
    # ????????.
    sphere(coll, "SwordPommel", (3.4, 3.2, 3.4), (x, y, -53.0), PALE, 18, 12, 0.0, 70)
    for i in range(6):
        a = TAU * i / 6
        sphere(coll, f"PommelStud{i}", (0.8, 0.8, 0.8),
               (x + math.cos(a) * 3.0, y, -53.0 + math.sin(a) * 3.0), BRONZE, 8, 5, 0.0, i)
    # ???????.
    bm = P.cylinder(2.2, 13.0, segs=20, axis="Z")
    bm.transform(T(x, y, -60.0))
    add_obj(coll, "SwordGrip", bm, DARK, 36.0)
    for z in (-55.0, -58.0, -61.0, -64.0):
        path = [Vector((x + math.cos(TAU * i / 32) * 2.4, y + math.sin(TAU * i / 32) * 2.4, z))
                for i in range(32)]
        add_obj(coll, f"GripWrap{int(z)}", P.tube(path, 0.18, segs=6, closed=True), BRONZE, 28.0)
    # ??????????: ???? + ?????????? ?????.
    box(coll, "SwordGuard", (29.0, 5.2, 3.5), (x, y, -67.0), DARK, 0.45)
    for sxn in (-1, 1):
        path = [Vector((x + sxn * 10.0, y, -67.0)),
                Vector((x + sxn * 15.5, y, -67.0)),
                Vector((x + sxn * 18.5, y, -67.0))]
        bm = P.tube(path, 1.1, segs=8)
        add_obj(coll, f"Quillon{sxn}", bm, BRONZE, 30.0)
        sphere(coll, f"QuillonTip{sxn}", (1.8, 1.5, 1.8),
               (x + sxn * 19.0, y, -67.0), PALE, 12, 8, 0.0, 71 + sxn)
    box(coll, "RainGuard", (7.0, 2.0, 5.0), (x, y + 2.0, -69.5), PALE, 0.25)
    # ??????: ??????????? ??????? ? ??????.
    rings = []
    n = 18
    for i in range(n + 1):
        t = i / n
        z = -70.0 - 92.0 * t
        w = 16.0 * (1.0 - t) ** 0.65 + 0.30
        th = 5.2 * (1.0 - t) ** 0.55 + 0.22
        c = min(w, th) * 0.22
        rings.append([
            (x - w / 2 + c, y - th / 2, z), (x + w / 2 - c, y - th / 2, z),
            (x + w / 2, y - th / 2 + c, z), (x + w / 2, y + th / 2 - c, z),
            (x + w / 2 - c, y + th / 2, z), (x - w / 2 + c, y + th / 2, z),
            (x - w / 2, y + th / 2 - c, z), (x - w / 2, y - th / 2 + c, z),
        ])
    loft(coll, "SwordBlade", rings, PALE)
    # ??? ? ??????.
    box(coll, "BladeFuller", (1.3, 0.8, 82.0), (x, y + 1.8, -112.0), CRACK, 0.05)
    for sxn in (-1, 1):
        box(coll, f"BladeEdge{sxn}", (0.9, 3.8, 88.0),
            (x + sxn * 7.6, y, -113.0), BRONZE, 0.08)
    # ?????.
    for i, z in enumerate((-83, -105, -130, -145)):
        box(coll, f"BladeChip{i}", (1.2, 3.2, 2.0), (x - 5.4, y, z), DARK, 0.15,
            rot=(0.3, 0.2, 0.5))
    crack(coll, "BladeCrack", [(x - 1.0, y + 2.2, -88), (x - 0.4, y + 2.2, -108),
                               (x - 1.2, y + 2.2, -124)], 0.06)


# ---------------------------------------------------------------------------
# ?????? / ??????
# ---------------------------------------------------------------------------
def fuse_stone_mass(coll):
    """????????? ???? ? ???????? ????? ? ???? ????????????? ???????."""
    fuse_prefixes = (
        "StatueBody", "Breastplate", "PauldronMain", "PauldronLame", "Rerebrace",
        "Vambrace", "Couter", "Cuisses", "Poleyn", "Greave", "Sabaton", "Fauld",
        "Belt", "SidePlate", "AbdomenLame", "NeckStump", "NeckBase", "GorgetBand",
        "BrokenCollar", "Plinth", "ThighPlate", "PoleynWing",
    )
    exclude = ("Rim", "Edge", "Trim", "Rivet", "Star", "Crack", "Band", "Fracture",
               "Debris", "Fallen", "Hand", "Sword", "Blade", "Grip", "Pommel",
               "Quillon", "Guard", "Rain", "Buckle", "Boss", "Finger", "Thumb",
               "Knuckle", "NeckPlatform", "Barnacle")
    mass = []
    for o in list(coll.objects):
        if o.type != "MESH":
            continue
        n = o.name
        if any(n.startswith(p) for p in fuse_prefixes) and not any(e in n for e in exclude):
            mass.append(o)
    if len(mass) < 2:
        return None
    bpy.ops.object.select_all(action="DESELECT")
    for o in mass:
        o.select_set(True)
    bpy.context.view_layer.objects.active = mass[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = "StatueMass"
    L.voxel_remesh(obj, 0.42)
    L.smooth(obj, 0.7, 2)
    L.rock_detail(obj, 19, 62.0, large=0.014, medium=0.007, fine=0.0025, crack_depth=0.006)
    L.decimate(obj, 95000)
    obj.data.materials.clear()
    obj.data.materials.append(bpy.data.materials[DARK])
    for poly in obj.data.polygons:
        poly.material_index = 0
    L.shade(obj, 40.0)
    return obj


def build():
    L.clear_data()
    L.register_materials(SM.MATERIALS, SM.TEXSETS)
    for name, spec in SM.MATERIALS.items():
        preview_material(name, spec, SM.TEXSETS)
    coll = L.asset_collection("statue_knight_colossus")
    build_body(coll)
    build_platform(coll)
    build_neck(coll)
    build_chest_armor(coll)
    build_pauldrons(coll)
    build_arms(coll)
    build_legs(coll)
    build_sword(coll)
    fuse_stone_mass(coll)
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
    bake_statue_mask(obj, seed=13, rays=5, ao_dist=2.0)
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
    bsdf.inputs["Roughness"].default_value = 0.09
    bsdf.inputs["Metallic"].default_value = 0.15
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 0.10
    noise.inputs["Detail"].default_value = 5.0
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.16
    bump.inputs["Distance"].default_value = 0.25
    nt.links.new(noise.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    obj.data.materials.append(mat)
    return obj


def render_previews(obj):
    L.setup_render(res=(1600, 1000), samples=32, sun_elev=20.0, sun_az=-38.0,
                   sun_power=4.8, sky=(0.30, 0.34, 0.40), sky_strength=1.15)
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE"
        scene.eevee.taa_render_samples = 48
    except Exception:
        pass
    scene.view_settings.exposure = 0.65
    sun = bpy.data.lights.get("PreviewSun")
    if sun:
        sun.color = (0.76, 0.82, 0.96)
    # ???????? ?????????.
    rim_data = bpy.data.lights.get("RimLight") or bpy.data.lights.new("RimLight", "SUN")
    rim_data.energy = 2.0
    rim_data.color = (0.52, 0.64, 0.92)
    rim = bpy.data.objects.get("RimLight") or bpy.data.objects.new("RimLight", rim_data)
    if rim.name not in bpy.context.scene.collection.objects:
        bpy.context.scene.collection.objects.link(rim)
    rim.rotation_euler = (math.radians(62), 0, math.radians(145))
    L.ground(size=320.0, z=-203.5, snow=False)
    L.mannequin(location=(3.0, 0.0, 0.0))
    L.mannequin(location=(8.0, 10.0, -201.0))
    bpy.context.view_layer.update()

    cam_data = bpy.data.cameras.get("StatueFullCam") or bpy.data.cameras.new("StatueFullCam")
    cam = bpy.data.objects.get("StatueFullCam") or bpy.data.objects.new("StatueFullCam", cam_data)
    if cam.name not in bpy.context.scene.collection.objects:
        bpy.context.scene.collection.objects.link(cam)
    cam_data.lens = 50.0
    cam_data.clip_end = 4000.0
    cam.location = (240.0, 620.0, -120.0)
    cam.rotation_euler = (Vector((0, 0, -92)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    L.render(PREV / "statue_full.jpg")

    cam.location = (8.0, 11.0, 6.0)
    cam_data.lens = 52.0
    cam.rotation_euler = (Vector((0, 0, -1.5)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    L.render(PREV / "statue_neck.jpg")

    cam.location = (22.0, 62.0, -28.0)
    cam_data.lens = 50.0
    cam.rotation_euler = (Vector((0, 18, -36)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    L.render(PREV / "statue_chest.jpg")

    cam.location = (-3.0, 40.0, -50.0)
    cam_data.lens = 55.0
    cam.rotation_euler = (Vector((-41, 26, -66)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    L.render(PREV / "statue_sword_hand.jpg")

    # ?????? ????.
    ground = bpy.data.objects.get("PreviewGround")
    if ground:
        ground.hide_render = True
    water = add_black_water(-72.0)
    world = bpy.context.scene.world
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.045, 0.055, 0.075, 1.0)
    bg.inputs["Strength"].default_value = 0.8
    sun.energy = 5.0
    rim_data.energy = 2.4
    scene.view_settings.exposure = 0.8
    # ????????? ???, ?????, ??? ? ????, ? ?? ?????? ????.
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, -40))
    dummy = bpy.context.object
    dummy.name = "StatueUpperFrame"
    dummy.scale = (105.0, 105.0, 108.0)
    dummy.hide_render = True
    bpy.context.view_layer.update()
    L.frame_camera([dummy], direction=(0.0, 1.0, 0.18), lens=52.0, margin=1.03)
    L.render(PREV / "statue_black_sea.jpg")
    cam = scene.camera
    cam_data = cam.data
    cam.location = (0.0, -10.0, 4.0)
    cam_data.lens = 52.0
    cam.rotation_euler = (Vector((0, 40, -18)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    L.render(PREV / "statue_tide.jpg")


if __name__ == "__main__":
    obj = build()
    if "--no-preview" not in sys.argv:
        render_previews(obj)
    print("DONE statue_knight_colossus v2")

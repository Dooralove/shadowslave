"""Генераторы кита Моря Души (Blender 5.1, bmesh).

Все ассеты строятся в метрах, +Z вверх, лицо — в локальном −Y.
Origin большинства объектов — центр основания; плавающие сферы/кольца —
центр. Экспорт — GLB с внешними слотами `ss_*`; изображения не встраиваются.
"""

from __future__ import annotations

import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

SRC = Path(__file__).resolve().parent
NM_SRC = Path(__file__).resolve().parents[2] / "nightmare" / "source"
for p in (SRC, NM_SRC):
    if str(p) not in sys.path:
        sys.path.insert(0, str(p))

import nm_lib as L  # noqa: E402
import nm_props as P  # noqa: E402
import nm_coral_lib as CL  # noqa: E402
import ss_materials as SM  # noqa: E402

L.register_materials(SM.MATERIALS, SM.TEXSETS)

OUT = L.ROOT / "assets" / "environments" / "soul_sea" / "kit"
PREV = L.ROOT / "docs" / "art" / "previews" / "soul_sea"
TAU = 2.0 * math.pi


def T(x, y, z):
    return Matrix.Translation((x, y, z))


def rot(deg, axis="Z"):
    return Matrix.Rotation(math.radians(deg), 4, axis)


def lerp(a, b, t):
    return a + (b - a) * t


def _obj(name, bm, coll, mat):
    return L.object_from_bmesh(name, bm, coll, mat)


def _close_holes(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.edges.ensure_lookup_table()
    boundary = [e for e in bm.edges if e.is_boundary]
    if boundary:
        bmesh.ops.holes_fill(bm, edges=boundary, sides=0)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.0005)
    bm.to_mesh(obj.data)
    bm.free()


def _center_geometry(obj):
    pts = [v.co for v in obj.data.vertices]
    if not pts:
        return
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    obj.data.transform(Matrix.Translation(-(lo + hi) * 0.5))


def _finish(obj, mat_kind="plain", sharp=45.0, uv_tile=1.0, mask=True, seed=0):
    _close_holes(obj)
    obj.data.name = obj.name
    L.shade(obj, sharp)
    L.uv_box(obj, uv_tile)
    if mask:
        if mat_kind == "layered":
            L.bake_masks(obj, seed=seed, rays=6, ao_dist=1.2, ground=True, base_dark=0.35, tint_var=0.06)
        else:
            L.plain_masks(obj, (0.92, 0.82, 0.80, 1.0))
    obj.data.validate()
    return obj


def _merge(name, objs, coll):
    return L.merge_objects(name, objs, coll)


def _join_parts(name, parts, coll):
    """parts: [(bmesh, material_key)] -> один объект с несколькими слотами."""
    objs = []
    for i, (bm, mat) in enumerate(parts):
        objs.append(_obj(f"{name}_p{i}", bm, coll, mat))
    return _merge(name, objs, coll)


def _append_bm(obj, bm):
    me = bpy.data.meshes.new("_ss_tmp")
    bm.to_mesh(me)
    bm.free()
    bm2 = bmesh.new()
    bm2.from_mesh(obj.data)
    bm2.from_mesh(me)
    bm2.to_mesh(obj.data)
    bm2.free()
    bpy.data.meshes.remove(me)


def _voxel(name, parts, coll, mat, voxel, target, smooth=1, sink=0.0):
    bm = L.join_bmeshes([(p, Matrix.Identity(4)) for p in parts])
    obj = _obj(name, bm, coll, mat)
    L.voxel_remesh(obj, voxel)
    if smooth:
        L.smooth(obj, 0.5, smooth)
    L.decimate(obj, target)
    L.shade(obj, 48.0)
    CL.recenter_base(obj, sink=sink)
    return obj


def _tube(points, radius, segs=8, taper=None):
    path = [Vector(p) for p in points]
    return P.tube(path, radius, segs=segs, radius_fn=taper)


def _cone(radius, height, center, direction=(0, 0, 1), segs=8):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs,
                          radius1=radius, radius2=0.002, depth=height)
    bm.transform(T(0, 0, height * 0.5))
    d = Vector(direction).normalized()
    q = Vector((0, 0, 1)).rotation_difference(d)
    bm.transform(q.to_matrix().to_4x4())
    bm.transform(T(*center))
    return bm


def _ico(radius, center=(0, 0, 0), subdiv=1, scale=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    bm.transform(T(*center) @ Matrix.Diagonal((*scale, 1.0)))
    return bm


def _circle_path(radius, segments=64, gap=0.0, z=0.0):
    pts = []
    for i in range(segments + 1):
        a = TAU * (i / segments) * (1.0 - gap)
        pts.append(Vector((math.cos(a) * radius, math.sin(a) * radius, z)))
    return pts


# ---------------------------------------------------------------------------
# Помост, кромка, ступени, плинты
# ---------------------------------------------------------------------------

def dais_hero(seed=0):
    name = "ss_dais_hero"
    coll = L.asset_collection(name)
    rng = random.Random(seed)
    profile = [
        (0.02, 0.00), (3.65, 0.00), (3.78, 0.10), (3.56, 0.14),
        (3.50, 0.28), (3.24, 0.33), (3.18, 0.43), (2.98, 0.47),
        (2.94, 0.55), (2.70, 0.59), (2.62, 0.65), (0.02, 0.65),
    ]
    bm = P.lathe(profile, segs=88, close_top=True, close_bottom=True)
    for v in bm.verts:
        x, y, z = v.co
        r = math.hypot(x, y)
        if r < 0.08:
            continue
        a = math.atan2(y, x)
        n = noise.noise(Vector((math.cos(a) * 0.8, math.sin(a) * 0.8, z * 1.6))) * 0.03
        v.co.x += x / r * n
        v.co.y += y / r * n
        if z > 0.1:
            v.co.z += 0.008 * noise.noise(Vector((x * 0.9, y * 0.9, 3.1)))
    obj = _obj(name, bm, coll, "ss_obsidian")

    # Каналы к центру: четыре узких выреза, не «руны».
    for i in range(4):
        cutter = bmesh.new()
        bmesh.ops.create_cube(cutter, size=1.0)
        cutter.transform(T(0, 0, 0.61) @ Matrix.Diagonal((0.15, 6.0, 0.09, 1.0)) @ rot(45 + i * 90))
        cut_obj = _obj(f"_cut{i}", cutter, coll, "ss_obsidian")
        mod = obj.modifiers.new("cut", "BOOLEAN")
        mod.operation = "DIFFERENCE"
        mod.solver = "EXACT"
        mod.object = cut_obj
        L.apply_modifiers(obj)
        bpy.data.objects.remove(cut_obj)

    # Центральное гнездо под сферу Памяти.
    cutter = bmesh.new()
    bmesh.ops.create_cone(cutter, cap_ends=True, cap_tris=False, segments=40,
                          radius1=0.54, radius2=0.54, depth=0.20)
    cutter.transform(T(0, 0, 0.56))
    cut_obj = _obj("_socket", cutter, coll, "ss_obsidian")
    mod = obj.modifiers.new("socket", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.object = cut_obj
    L.apply_modifiers(obj)
    bpy.data.objects.remove(cut_obj)

    # Световые кольца-проекции на поверхности.
    rings = []
    for i, (r, thick, gap) in enumerate(((0.86, 0.020, 0.10), (1.46, 0.024, 0.06), (2.18, 0.028, 0.05))):
        pts = _circle_path(r, 88, gap=gap, z=0.665 + i * 0.002)
        rings.append(_tube(pts, thick, segs=6))
    ring_obj = _join_parts("_dais_rings", [(b, "ss_sigil") for b in rings], coll)
    obj = _merge(name, [obj, ring_obj], coll)

    # Массивная обломанная кромка: чанки, а не тонкие зубцы.
    teeth = []
    for i in range(10):
        a = TAU * i / 10.0 + rng.uniform(-0.04, 0.04)
        r = rng.uniform(3.15, 3.45)
        sx = rng.uniform(0.50, 0.95)
        sy = rng.uniform(0.32, 0.55)
        sz = rng.uniform(0.22, 0.46)
        chunk = P.board(sx, sy, sz, bevel=0.03, seed=seed + 50 + i)
        chunk.transform(T(math.cos(a) * r, math.sin(a) * r, 0.18 + sz * 0.5)
                        @ Matrix.Rotation(-a - math.pi * 0.5, 4, "Z")
                        @ Matrix.Rotation(rng.uniform(-0.12, 0.12), 4, "X"))
        teeth.append(chunk)
    # Пара высоких сколов для силуэта.
    for i in range(4):
        a = TAU * i / 4.0 + 0.35
        r = rng.uniform(2.95, 3.25)
        teeth.append(_cone(rng.uniform(0.10, 0.16), rng.uniform(0.22, 0.38),
                           (math.cos(a) * r, math.sin(a) * r, 0.52),
                           direction=(math.cos(a) * 0.35, math.sin(a) * 0.35, 1.0), segs=5))
    # Приподнятый обод вокруг гнезда.
    socket_ring = _tube(_circle_path(0.58, 56, gap=0.0, z=0.66), 0.045, segs=6)
    teeth.append(socket_ring)
    tooth_obj = _join_parts("_dais_teeth", [(b, "ss_obsidian") for b in teeth], coll)
    obj = _merge(name, [obj, tooth_obj], coll)

    return _finish(obj, "layered", sharp=38.0, uv_tile=2.0, seed=seed)


def dais_edge(v=0):
    name = f"ss_dais_edge_{'abc'[v]}"
    coll = L.asset_collection(name)
    rng = random.Random(100 + v)
    # Сегмент короче: 8–10 модулей должны собираться в кольцо ~19 м.
    a0 = math.radians(-28 + v * 3)
    a1 = math.radians(28 - v * 2)
    segs = 22
    bm = bmesh.new()
    rows = []
    for i in range(segs + 1):
        t = i / segs
        a = lerp(a0, a1, t)
        r_in = 2.50 + rng.uniform(-0.03, 0.03)
        r_mid = 2.95 + rng.uniform(-0.04, 0.04)
        r_out = 3.42 + rng.uniform(-0.10, 0.08)
        z_in = 0.22 + 0.10 * math.sin(t * math.pi) + rng.uniform(-0.03, 0.03)
        z_mid = 0.38 + 0.12 * math.sin(t * math.pi) + rng.uniform(-0.03, 0.03)
        z_out = 0.30 + 0.10 * math.sin(t * math.pi) + rng.uniform(-0.04, 0.04)
        row = [
            bm.verts.new((math.cos(a) * r_in, math.sin(a) * r_in, 0.0)),
            bm.verts.new((math.cos(a) * r_out, math.sin(a) * r_out, 0.0)),
            bm.verts.new((math.cos(a) * r_out, math.sin(a) * r_out, z_out)),
            bm.verts.new((math.cos(a) * r_mid, math.sin(a) * r_mid, z_mid)),
            bm.verts.new((math.cos(a) * r_in, math.sin(a) * r_in, z_in)),
        ]
        rows.append(row)
    for a, b in zip(rows, rows[1:]):
        for k in range(4):
            bm.faces.new((a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]))
    bm.faces.new(list(reversed(rows[0])))
    bm.faces.new(rows[-1])
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    obj = _obj(name, bm, coll, "ss_obsidian")

    # Крупные обломки на верхней поверхности.
    for i in range(4):
        t = rng.uniform(0.08, 0.92)
        a = lerp(a0, a1, t)
        r = rng.uniform(2.70, 3.25)
        sx = rng.uniform(0.28, 0.55)
        sy = rng.uniform(0.22, 0.38)
        sz = rng.uniform(0.10, 0.22)
        chunk = P.board(sx, sy, sz, bevel=0.025, seed=100 + v * 10 + i)
        chunk.transform(T(math.cos(a) * r, math.sin(a) * r, 0.42 + sz * 0.4)
                        @ Matrix.Rotation(-a - math.pi * 0.5, 4, "Z")
                        @ Matrix.Rotation(rng.uniform(-0.15, 0.15), 4, "X"))
        _append_bm(obj, chunk)
    # Пара сколов.
    for i in range(2):
        a = lerp(a0, a1, rng.uniform(0.15, 0.85))
        r = rng.uniform(2.85, 3.20)
        crack = _cone(rng.uniform(0.03, 0.07), rng.uniform(0.10, 0.20),
                      (math.cos(a) * r, math.sin(a) * r, 0.44),
                      direction=(math.cos(a) * 0.6, math.sin(a) * 0.6, 1.0), segs=4)
        _append_bm(obj, crack)
    CL.recenter_base(obj, sink=0.0)
    return _finish(obj, "layered", sharp=35.0, uv_tile=2.0, seed=100 + v)


def step(v=0):
    name = f"ss_step_{'ab'[v]}"
    coll = L.asset_collection(name)
    rng = random.Random(200 + v)
    bm = P.board(1.65 + v * 0.35, 0.62 + v * 0.12, 0.26, bevel=0.035, seed=200 + v, warp=0.01)
    bm.transform(T(0, 0, 0.13))
    # Сбитый передний край.
    for vv in bm.verts:
        if vv.co.y < -0.22 and vv.co.z > 0.18:
            vv.co.z -= 0.035 * (1 + math.sin(vv.co.x * 8.0))
    obj = _obj(name, bm, coll, "ss_obsidian")
    # Сколы и обломки на кромке.
    for i in range(5):
        x = rng.uniform(-0.65, 0.65)
        y = rng.uniform(-0.30, 0.30)
        sx = rng.uniform(0.10, 0.24)
        sy = rng.uniform(0.08, 0.18)
        sz = rng.uniform(0.04, 0.10)
        chip = P.board(sx, sy, sz, bevel=0.012, seed=210 + v * 10 + i)
        chip.transform(T(x, y, 0.27 + sz * 0.2) @ Matrix.Rotation(rng.uniform(-0.5, 0.5), 4, "Z"))
        _append_bm(obj, chip)
    return _finish(obj, "layered", sharp=32.0, uv_tile=1.5, seed=200 + v)


def plinth(v=0):
    name = f"ss_plinth_{'abc'[v]}"
    coll = L.asset_collection(name)
    h = (0.62, 0.88, 1.12)[v]
    r = (0.34, 0.42, 0.50)[v]
    profile = [
        (0.02, 0.0), (r * 1.08, 0.0), (r * 1.12, 0.05), (r * 0.92, 0.10),
        (r * 0.78, h * 0.72), (r * 0.92, h * 0.82), (r * 1.02, h * 0.88),
        (r * 0.86, h), (r * 0.52, h), (r * 0.46, h - 0.05), (0.02, h - 0.05),
    ]
    bm = P.lathe(profile, segs=32, close_top=True, close_bottom=True)
    for vv in bm.verts:
        if vv.co.z > 0.1:
            vv.co.x *= 1.0 + 0.018 * noise.noise(Vector((vv.co.x * 2, vv.co.y * 2, vv.co.z * 1.4)))
            vv.co.y *= 1.0 + 0.018 * noise.noise(Vector((vv.co.x * 2, vv.co.y * 2, vv.co.z * 1.4)))
    obj = _obj(name, bm, coll, "ss_obsidian")
    return _finish(obj, "layered", sharp=35.0, uv_tile=1.2, seed=300 + v)


# ---------------------------------------------------------------------------
# Скалы и обелиски
# ---------------------------------------------------------------------------

def shoal_rock(v=0):
    name = f"ss_shoal_rock_{'abcd'[v]}"
    coll = L.asset_collection(name)
    dims = ((2.8, 2.2, 1.35), (1.7, 1.3, 0.85), (3.6, 2.6, 1.7), (1.1, 0.9, 0.55))[v]
    parts = []
    for i in range(3 + v):
        chunk = L.hull_chunk(500 + v * 17 + i, dims,
                             npts=36 + v * 8, cuts=4 + v,
                             cut_depth=(0.45, 0.75), squash=0.55 + 0.15 * (i % 2))
        chunk.transform(T((i - 1) * dims[0] * 0.25, (i % 2 - 0.5) * dims[1] * 0.2, 0))
        parts.append(chunk)
    obj = L.rock_object(name, [(p, Matrix.Identity(4)) for p in parts], coll,
                        mat="ss_basalt", voxel=0.08, smooth_iter=2, seed=500 + v,
                        size=max(dims) * 0.55, target_tris=(2600, 2200, 3800, 1800)[v],
                        base_z=0.02, sink=0.03,
                        detail=dict(large=0.06, medium=0.022, fine=0.006,
                                    crack_depth=0.022, strata=(1.0, 1.0, 2.8)))
    CL.recenter_base(obj, sink=0.03)
    return _finish(obj, "layered", sharp=48.0, uv_tile=2.0, seed=500 + v)


def _shard_loft(height, base_r, top_r, sides, rings_n, seed, twist=0.25):
    rng = random.Random(seed)
    rings = []
    for j in range(rings_n):
        t = j / (rings_n - 1)
        r = lerp(base_r, top_r, t ** 0.78) * (1.0 + 0.08 * math.sin(t * 6.0 + seed))
        ring = []
        for i in range(sides):
            a = TAU * i / sides + twist * t + 0.10 * math.sin(i * 2.1 + seed)
            rr = r * (1.0 + 0.09 * noise.noise(Vector((math.cos(a) * 1.7, math.sin(a) * 1.7, t * 5.0))))
            z = height * t + 0.14 * math.sin(i * 1.7 + t * 5.0) * (1.0 - t)
            if t > 0.92:
                z += 0.12 * math.sin(i * 2.3 + seed)
            ring.append(Vector((math.cos(a) * rr, math.sin(a) * rr, z)))
        rings.append(ring)
    return CL.ring_loft(rings, cap_bottom=True, cap_top=True)


def obelisk(v=0, hero=False):
    name = "ss_obelisk_hero" if hero else f"ss_obelisk_{'abc'[v]}"
    coll = L.asset_collection(name)
    rng = random.Random(700 + v + (40 if hero else 0))
    height = (8.6, 6.2, 4.4)[v] if not hero else 14.5
    base_r = (1.50, 1.18, 0.86)[v] if not hero else 2.05
    top_r = (0.30, 0.24, 0.18)[v] if not hero else 0.42
    sides = (9, 8, 7)[v] if not hero else 13
    rings_n = (20, 16, 13)[v] if not hero else 40

    main = _shard_loft(height, base_r, top_r, sides, rings_n, 700 + v + (40 if hero else 0))
    parts = [(main, "ss_obsidian")]
    # Вторичные сколы у основания: не одинокий «шип».
    for i in range(2 + v):
        h = height * rng.uniform(0.20, 0.38)
        br = base_r * rng.uniform(0.30, 0.48)
        shard = _shard_loft(h, br, br * 0.18, sides - 1, 8, 750 + v * 13 + i, twist=0.15)
        a = TAU * rng.uniform(0.0, 1.0)
        rr = base_r * rng.uniform(0.55, 0.85)
        shard.transform(T(math.cos(a) * rr, math.sin(a) * rr, 0.0)
                        @ Matrix.Rotation(rng.uniform(-0.28, 0.28), 4, "X")
                        @ Matrix.Rotation(rng.uniform(-0.28, 0.28), 4, "Y")
                        @ Matrix.Rotation(a, 4, "Z"))
        parts.append((shard, "ss_obsidian"))

    if hero:
        # Крупные вторичные сколы: hero-обелиск должен читаться как разлом,
        # а не как одинокий гладкий шип.
        for i in range(3):
            h = height * rng.uniform(0.30, 0.52)
            br = base_r * rng.uniform(0.22, 0.34)
            shard = _shard_loft(h, br, br * 0.15, max(5, sides - 2), 12,
                                760 + i, twist=0.20)
            a = TAU * (i / 3.0 + rng.uniform(-0.10, 0.10))
            rr = base_r * rng.uniform(0.70, 0.95)
            shard.transform(T(math.cos(a) * rr, math.sin(a) * rr, 0.0)
                            @ Matrix.Rotation(rng.uniform(-0.25, 0.25), 4, "X")
                            @ Matrix.Rotation(rng.uniform(-0.25, 0.25), 4, "Y")
                            @ Matrix.Rotation(a, 4, "Z"))
            parts.append((shard, "ss_obsidian"))
        # Вертикальные рёбра-грани.
        for i in range(4):
            a = TAU * i / 4.0 + 0.20
            pts = []
            for k in range(12):
                t = k / 11.0
                z = height * (0.05 + 0.85 * t)
                r = lerp(base_r, top_r, (z / height) ** 0.78) * 1.015
                aa = a + 0.03 * math.sin(t * 10.0 + i)
                pts.append((math.cos(aa) * r, math.sin(aa) * r, z))
            parts.append((_tube(pts, 0.045, segs=5,
                                taper=lambda t: 1.0 - 0.6 * t), "ss_obsidian"))
        # Сломанная вершина: несколько зубцов вместо ровного среза.
        for i in range(5):
            a = TAU * i / 5.0
            parts.append((_cone(0.11, 0.55,
                                (math.cos(a) * top_r * 0.70,
                                 math.sin(a) * top_r * 0.70, height * 0.985),
                                direction=(math.cos(a) * 0.30,
                                           math.sin(a) * 0.30, 1.0), segs=5),
                          "ss_obsidian"))

    # Светящиеся трещины по граням.
    cracks = []
    for i in range(4 + v + (2 if hero else 0)):
        a = TAU * rng.uniform(0.0, 1.0)
        z0 = height * rng.uniform(0.10, 0.30)
        z1 = height * rng.uniform(0.55, 0.86)
        pts = []
        for k in range(9):
            t = k / 8.0
            z = lerp(z0, z1, t)
            r = lerp(base_r, top_r, (z / height) ** 0.78) * 1.02
            aa = a + 0.08 * math.sin(t * 8.0 + i)
            pts.append((math.cos(aa) * r, math.sin(aa) * r, z))
        cracks.append(_tube(pts, (0.018 if not hero else 0.026) * (0.8 + 0.4 * (i % 3)), segs=5))
    parts += [(b, "ss_sigil") for b in cracks]
    obj = _join_parts(name, parts, coll)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    L.cut_base(bm, 0.0)
    bm.to_mesh(obj.data)
    bm.free()
    return _finish(obj, "layered", sharp=26.0, uv_tile=2.0, seed=700 + v + (40 if hero else 0))


# ---------------------------------------------------------------------------
# Память, Эхо, орбиты, моты, нити
# ---------------------------------------------------------------------------

def memory_sphere_hero(seed=0):
    name = "ss_memory_sphere_hero"
    coll = L.asset_collection(name)
    bm = CL.ellipsoid(0.30, 0.30, 0.30, center=(0, 0, 0), segs=32, rings=20, wobble=0.035, seed=seed)
    obj = _obj(name, bm, coll, "ss_memory")
    # Внутреннее ядро и несколько орбитальных осколков.
    parts = []
    parts.append(CL.ellipsoid(0.16, 0.16, 0.16, center=(0, 0, 0), segs=16, rings=10, wobble=0.02, seed=seed + 1))
    for i in range(7):
        a = TAU * i / 7.0
        rr = 0.40 + 0.04 * math.sin(i * 1.7)
        z = 0.10 * math.sin(i * 2.3)
        parts.append(_ico(0.035 + 0.012 * (i % 3), (math.cos(a) * rr, math.sin(a) * rr, z),
                          subdiv=1, scale=(1.0, 0.7, 1.4)))
    detail = _join_parts("_memory_detail", [(b, "ss_memory") for b in parts], coll)
    # Каркас из трёх больших кругов: сфера читается как «заключённая» Память.
    cage = []
    for i in range(3):
        pts = _circle_path(0.335, 72, gap=0.015, z=0.0)
        bm_c = _tube(pts, 0.011, segs=5)
        if i == 1:
            bm_c.transform(Matrix.Rotation(math.radians(90), 4, "X"))
        elif i == 2:
            bm_c.transform(Matrix.Rotation(math.radians(90), 4, "Y"))
        cage.append(bm_c)
    cage_obj = _join_parts("_memory_cage", [(b, "ss_sigil") for b in cage], coll)
    obj = _merge(name, [obj, detail, cage_obj], coll)
    obj.data.name = name
    L.shade(obj, 60.0)
    L.uv_box(obj, 0.5)
    L.plain_masks(obj, (1.0, 1.0, 1.0, 1.0))
    return obj


def memory_sphere(v=0):
    name = f"ss_memory_sphere_{'abc'[v]}"
    coll = L.asset_collection(name)
    if v == 0:
        bm = CL.ellipsoid(0.18, 0.18, 0.18, segs=24, rings=16, wobble=0.02, seed=800)
    elif v == 1:
        bm = _ico(0.20, subdiv=2, scale=(1.0, 1.0, 1.0))
    else:
        bm = CL.ellipsoid(0.13, 0.13, 0.24, segs=20, rings=14, wobble=0.03, seed=802)
    obj = _obj(name, bm, coll, "ss_memory")
    obj.data.name = name
    L.shade(obj, 58.0)
    L.uv_box(obj, 0.5)
    L.plain_masks(obj, (1.0, 1.0, 1.0, 1.0))
    return obj


def memory_orbit_ring(v=0):
    name = f"ss_memory_orbit_ring_{'abc'[v]}"
    coll = L.asset_collection(name)
    r = (0.36, 0.46, 0.28)[v]
    gap = (0.10, 0.16, 0.06)[v]
    pts = _circle_path(r, 64, gap=gap, z=0.0)
    bm = _tube(pts, (0.012, 0.016, 0.009)[v], segs=6)
    obj = _obj(name, bm, coll, "ss_memory")
    obj.data.name = name
    L.shade(obj, 55.0)
    L.uv_box(obj, 0.5)
    L.plain_masks(obj, (1.0, 1.0, 1.0, 1.0))
    return obj


def memory_orbit_sigil(v=0):
    name = f"ss_memory_orbit_sigil_{'abc'[v]}"
    coll = L.asset_collection(name)
    parts = []
    radii = ((0.55, 0.95, 1.35), (0.70, 1.15, 1.60), (0.45, 0.85, 1.25))[v]
    for i, r in enumerate(radii):
        pts = _circle_path(r, 48, gap=0.035 + i * 0.01, z=0.006 * i)
        parts.append(_tube(pts, 0.012 + i * 0.003, segs=4))
    # Радиальные насечки, а не пентаграмма.
    for i in range(12):
        a = TAU * i / 12.0
        r0, r1 = radii[0], radii[-1]
        pts = [(math.cos(a) * r0, math.sin(a) * r0, 0.0),
               (math.cos(a) * r1, math.sin(a) * r1, 0.0)]
        parts.append(_tube(pts, 0.006, segs=3))
    obj = _join_parts(name, [(b, "ss_sigil") for b in parts], coll)
    obj.data.name = name
    L.shade(obj, 55.0)
    L.uv_box(obj, 0.5)
    L.plain_masks(obj, (1.0, 1.0, 1.0, 1.0))
    return obj


def memory_mote(v=0):
    name = f"ss_memory_mote_{'ab'[v]}"
    coll = L.asset_collection(name)
    if v == 0:
        bm = _ico(0.022, subdiv=1, scale=(1.0, 1.0, 1.0))
    else:
        bm = _ico(0.030, subdiv=1, scale=(0.7, 0.7, 1.5))
    obj = _obj(name, bm, coll, "ss_memory")
    obj.data.name = name
    L.shade(obj, 50.0)
    L.uv_box(obj, 0.2)
    L.plain_masks(obj, (1.0, 1.0, 1.0, 1.0))
    return obj


def memory_thread(v=0):
    name = f"ss_memory_thread_{'abc'[v]}"
    coll = L.asset_collection(name)
    rng = random.Random(900 + v)
    parts = []
    for i in range(2 + v):
        pts = []
        for k in range(12):
            t = k / 11.0
            a = t * (1.4 + 0.3 * v) + i * 1.7
            r = 0.18 + 0.30 * t
            pts.append((math.cos(a) * r + rng.uniform(-0.02, 0.02),
                        math.sin(a) * r + rng.uniform(-0.02, 0.02),
                        t * (0.55 + 0.25 * v) + 0.05 * math.sin(a * 3.0)))
        parts.append(_tube(pts, 0.008 + 0.003 * v, segs=4))
    obj = _join_parts(name, [(b, "ss_memory") for b in parts], coll)
    _center_geometry(obj)
    obj.data.name = name
    L.shade(obj, 55.0)
    L.uv_box(obj, 0.5)
    L.plain_masks(obj, (1.0, 1.0, 1.0, 1.0))
    return obj


def echo_sphere(v=0):
    name = f"ss_echo_sphere_{'abc'[v]}"
    coll = L.asset_collection(name)
    r = (0.52, 0.62, 0.44)[v]
    bm = CL.ellipsoid(r, r * (0.92 + 0.05 * v), r, segs=28, rings=18,
                      wobble=0.03, seed=1000 + v)
    obj = _obj(name, bm, coll, "ss_echo")
    parts = []
    for i in range(3):
        rr = r * (1.02 + 0.04 * i)
        pts = _circle_path(rr, 56, gap=0.06, z=(i - 1) * r * 0.32)
        parts.append(_tube(pts, 0.010 + 0.002 * i, segs=5))
    bands = _join_parts("_echo_bands", [(b, "ss_echo") for b in parts], coll)
    obj = _merge(name, [obj, bands], coll)
    obj.data.name = name
    L.shade(obj, 55.0)
    L.uv_box(obj, 0.5)
    L.plain_masks(obj, (1.0, 1.0, 1.0, 1.0))
    return obj


def mist_card(v=0):
    name = f"ss_mist_card_{'abc'[v]}"
    coll = L.asset_collection(name)
    rng = random.Random(2500 + v)
    width = (3.2, 4.6, 2.4)[v]
    height = (2.4, 3.4, 1.8)[v]
    nu, nv = 8, 6
    bm = bmesh.new()
    grid = []
    for j in range(nv + 1):
        t = j / nv
        row = []
        for i in range(nu + 1):
            u = i / nu
            x = (u - 0.5) * width * (0.85 + 0.15 * t)
            z = t * height
            y = 0.10 * math.sin(u * 5.0 + v) * (0.3 + 0.7 * t)
            if j == nv:
                z += rng.uniform(-0.12, 0.12) * height
            row.append(bm.verts.new((x, y, z)))
        grid.append(row)
    for j in range(nv):
        for i in range(nu):
            bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    # UV 0..1 нужны шейдеру мягкого края; box-развёртка здесь не подходит.
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        for loop in f.loops:
            co = loop.vert.co
            loop[uv].uv = (co.x / width + 0.5, co.z / height)
    obj = _obj(name, bm, coll, "ss_mist")
    obj.data.name = name
    L.shade(obj, 70.0)
    L.plain_masks(obj, (1.0, 1.0, 1.0, 1.0))
    return obj


def ripple_decal(v=0):
    name = f"ss_ripple_decal_{'abc'[v]}"
    coll = L.asset_collection(name)
    parts = []
    for i, r in enumerate(((0.55, 0.92, 1.30), (0.40, 0.78, 1.10), (0.65, 1.05, 1.55))[v]):
        pts = _circle_path(r, 36, gap=0.05 + i * 0.02, z=0.004 * i)
        parts.append(_tube(pts, 0.012 - i * 0.002, segs=3))
    obj = _join_parts(name, [(b, "ss_ripple") for b in parts], coll)
    obj.data.name = name
    L.shade(obj, 55.0)
    L.uv_box(obj, 0.5)
    L.plain_masks(obj, (1.0, 1.0, 1.0, 1.0))
    return obj


# ---------------------------------------------------------------------------
# Тени убитых существ
# ---------------------------------------------------------------------------

def _humanoid_parts(height=1.8, bulk=1.0, hunch=0.0, arm_pose=0, seed=0):
    """Базовое тело 1.8 м: эллипсоиды + трубчатые конечности.

    Лицо — в локальном −Y, спина — в +Y. Высота масштабируется целиком,
    поэтому proportions остаются читаемыми и для 7-метрового Короля.
    """
    S = height / 1.8
    b = bulk
    hy = hunch * S
    rng = random.Random(seed)
    parts = []

    # Таз, торс, грудь.
    parts.append(CL.ellipsoid(0.22 * S * b, 0.16 * S, 0.18 * S,
                              center=(0, 0, 0.94 * S), wobble=0.03, seed=seed + 1))
    parts.append(CL.ellipsoid(0.27 * S * b, 0.18 * S, 0.34 * S,
                              center=(0, -0.01 * S + hy * 0.5, 1.22 * S),
                              wobble=0.03, seed=seed + 2))
    parts.append(CL.ellipsoid(0.36 * S * b, 0.21 * S, 0.20 * S,
                              center=(0, -0.01 * S + hy, 1.45 * S),
                              wobble=0.03, seed=seed + 3))
    # Шея и голова.
    parts.append(_tube([(0, -0.01 * S + hy, 1.50 * S),
                        (0, -0.01 * S + hy, 1.60 * S)], 0.065 * S, segs=8))
    parts.append(CL.ellipsoid(0.11 * S, 0.12 * S, 0.14 * S,
                              center=(0, -0.02 * S + hy * 1.2, 1.68 * S),
                              wobble=0.02, seed=seed + 4))
    parts.append(CL.ellipsoid(0.115 * S, 0.125 * S, 0.06 * S,
                              center=(0, 0.01 * S + hy * 1.2, 1.77 * S),
                              wobble=0.04, seed=seed + 5))
    # Плечи.
    for side in (-1.0, 1.0):
        parts.append(CL.ellipsoid(0.16 * S * b, 0.16 * S, 0.14 * S,
                                  center=(0.32 * S * b * side, 0, 1.44 * S),
                                  wobble=0.03, seed=seed + 6 + int(side)))

    # Руки.
    for side in (-1.0, 1.0):
        sh = (0.34 * S * b * side, -0.01 * S, 1.44 * S)
        if arm_pose == 1 and side > 0:
            el = (0.48 * S * b, -0.12 * S, 1.28 * S)
            wr = (0.34 * S * b, -0.34 * S, 1.12 * S)
        elif arm_pose == 2:
            el = (0.50 * S * b * side, 0.02 * S, 1.20 * S)
            wr = (0.52 * S * b * side, 0.04 * S, 0.98 * S)
        else:
            el = (0.44 * S * b * side, 0.02 * S, 1.16 * S)
            wr = (0.46 * S * b * side, 0.04 * S, 0.92 * S)
        parts.append(_tube([sh, el, wr], 0.075 * S * b, segs=8,
                           taper=lambda t: 1.0 - 0.38 * t))
        parts.append(CL.ellipsoid(0.07 * S, 0.05 * S, 0.10 * S,
                                  center=wr, wobble=0.02, seed=seed + 10 + int(side)))

    # Ноги.
    for side in (-1.0, 1.0):
        hip = (0.12 * S * side, 0, 0.92 * S)
        knee = (0.13 * S * side, 0.02 * S, 0.50 * S)
        ankle = (0.13 * S * side, 0.0, 0.08 * S)
        parts.append(_tube([hip, knee, ankle], 0.12 * S * b, segs=8,
                           taper=lambda t: 1.0 - 0.45 * t))
        parts.append(CL.ellipsoid(0.09 * S, 0.16 * S, 0.06 * S,
                                  center=(0.13 * S * side, 0.08 * S, 0.04 * S),
                                  wobble=0.02, seed=seed + 20 + int(side)))

    # Короткий пояс-обмотка; основная «юбка» собирается из лоскутов после remesh.
    wrap = P.cylinder(0.29 * S * b, 0.13 * S, segs=18, radius2=0.26 * S * b)
    wrap.transform(T(0, 0, 0.95 * S))
    parts.append(wrap)
    return parts


def _wrist(arm_pose, side, S, b):
    if arm_pose == 1 and side > 0:
        return (0.34 * S * b, -0.34 * S, 1.12 * S)
    if arm_pose == 2:
        return (0.52 * S * b * side, 0.04 * S, 0.98 * S)
    return (0.46 * S * b * side, 0.04 * S, 0.92 * S)


def _cloth_panel(width_top, width_bottom, height, thickness=0.006, seed=0,
                 billow=0.05, notch=0.0):
    """Тонкое изогнутое полотнище с рваным низом (не «доска»)."""
    rng = random.Random(seed)
    nu, nv = 4, 7
    bm = bmesh.new()
    grid = []
    for j in range(nv + 1):
        t = j / nv
        z = -height * t
        w = lerp(width_top, width_bottom, t)
        row = []
        for i in range(nu + 1):
            u = i / nu
            x = (u - 0.5) * w
            y = billow * math.sin(math.pi * u) * (0.25 + 0.75 * t)
            y += 0.012 * math.sin(u * 9.0 + seed) * t
            zz = z
            if j == nv:
                zz += rng.uniform(-0.035, 0.035) * height
                if notch and abs(u - 0.5) < notch:
                    zz += height * 0.22
            row.append(bm.verts.new((x, y, zz)))
        grid.append(row)
    for j in range(nv):
        for i in range(nu):
            bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    if thickness > 0:
        bmesh.ops.solidify(bm, geom=list(bm.faces), thickness=thickness)
    return bm


def _humanoid_details(height=1.8, bulk=1.0, seed=0, slave=True, arm_pose=0):
    """Лохмотья, шрамы и пояс — добавляются после voxel-remesh."""
    S = height / 1.8
    rng = random.Random(seed)
    parts = []
    # Рваная «юбка»: тонкие изогнутые полотнища с прорехами, а не конус.
    for i in range(14):
        a = TAU * i / 14.0 + rng.uniform(-0.08, 0.08)
        # Прореха спереди, чтобы были видны ноги.
        da = (a + math.pi * 0.5) % TAU
        if min(da, TAU - da) < 0.30:
            continue
        h = rng.uniform(0.42, 0.78) * S
        w0 = rng.uniform(0.16, 0.24) * S
        w1 = w0 * rng.uniform(1.05, 1.35)
        flap = _cloth_panel(w0, w1, h, 0.006 * S, seed=seed + 30 + i,
                            billow=rng.uniform(0.03, 0.07) * S, notch=0.06)
        flap.transform(T(math.cos(a) * 0.27 * S * bulk, math.sin(a) * 0.27 * S * bulk, 0.98 * S)
                       @ Matrix.Rotation(a - math.pi * 0.5, 4, "Z")
                       @ Matrix.Rotation(rng.uniform(-0.10, 0.10), 4, "X"))
        parts.append(flap)
    # Второй, более короткий слой лохмотьев.
    for i in range(8):
        a = TAU * (i + 0.5) / 8.0
        h = rng.uniform(0.26, 0.44) * S
        w0 = rng.uniform(0.14, 0.22) * S
        flap = _cloth_panel(w0, w0 * 1.2, h, 0.005 * S, seed=seed + 45 + i,
                            billow=0.035 * S, notch=0.05)
        flap.transform(T(math.cos(a) * 0.25 * S * bulk, math.sin(a) * 0.25 * S * bulk, 0.99 * S)
                       @ Matrix.Rotation(a - math.pi * 0.5, 4, "Z")
                       @ Matrix.Rotation(0.12, 4, "X"))
        parts.append(flap)
    # Пояс с узлом и свисающими концами.
    belt = _tube(_circle_path(0.27 * S * bulk, 40, gap=0.0, z=0.93 * S), 0.018 * S, segs=5)
    parts.append(belt)
    parts.append(CL.ellipsoid(0.035 * S, 0.025 * S, 0.025 * S,
                              center=(0.0, -0.27 * S * bulk, 0.92 * S),
                              segs=8, rings=6, wobble=0.03, seed=seed + 60))
    for i in range(2):
        pts = [(0.02 * S * i, -0.27 * S * bulk, 0.92 * S),
               (0.06 * S * i, -0.30 * S * bulk, 0.76 * S),
               (0.04 * S * i, -0.31 * S * bulk, 0.62 * S)]
        parts.append(_tube(pts, 0.012 * S, segs=4))
    # Рваная накидка на плечах.
    for i in range(5):
        a = math.pi * (0.12 + 0.19 * i)
        w0 = rng.uniform(0.14, 0.22) * S
        flap = _cloth_panel(w0, w0 * 1.25, 0.36 * S, 0.006 * S,
                            seed=seed + 70 + i, billow=0.04 * S, notch=0.05)
        flap.transform(T(math.cos(a) * 0.33 * S * bulk, math.sin(a) * 0.33 * S * bulk, 1.42 * S)
                       @ Matrix.Rotation(a - math.pi * 0.5, 4, "Z")
                       @ Matrix.Rotation(0.24, 4, "X"))
        parts.append(flap)
    # Повязка на голове и жёсткие пряди вместо «шлема».
    band = _tube(_circle_path(0.115 * S, 24, gap=0.0, z=0.0), 0.018 * S, segs=4)
    band.transform(T(0.0, 0.0, 1.72 * S))
    parts.append(band)
    parts.append(CL.ellipsoid(0.120 * S, 0.130 * S, 0.070 * S,
                              center=(0.0, 0.015 * S, 1.79 * S),
                              segs=14, rings=8, wobble=0.10, seed=seed + 90))
    for i in range(2):
        strip = _cloth_panel(0.055 * S, 0.075 * S, 0.24 * S, 0.004 * S,
                             seed=seed + 91 + i, billow=0.02 * S, notch=0.04)
        strip.transform(T((-0.04 + 0.08 * i) * S, 0.10 * S, 1.72 * S)
                        @ Matrix.Rotation(0.10, 4, "X"))
        parts.append(strip)
    # Пальцы: три тонких трубки на каждой руке.
    for side in (-1.0, 1.0):
        wr = _wrist(arm_pose, side, S, bulk)
        for k in (-1.0, 0.0, 1.0):
            pts = [(wr[0], wr[1], wr[2]),
                   (wr[0] + 0.025 * S * side, wr[1] - 0.045 * S, wr[2] - 0.055 * S),
                   (wr[0] + 0.035 * S * side, wr[1] - 0.075 * S, wr[2] - 0.10 * S + 0.012 * S * k)]
            parts.append(_tube(pts, 0.008 * S, segs=4))
    if slave:
        # Шрамы на спине: снаружи тела, чтобы их ловил контровой свет.
        for i in range(8):
            z = (1.00 + i * 0.06) * S
            y = 0.205 * S + 0.012 * S * math.sin(i * 2.0)
            pts = []
            for k in range(7):
                x = lerp(-0.19 * S, 0.19 * S, k / 6.0)
                pts.append((x, y + 0.02 * S * math.sin(k * 1.7 + i), z + 0.015 * S * math.sin(k * 2.1)))
            parts.append(_tube(pts, 0.014 * S, segs=4))
        # Позвоночник и рёбра — читаемая «истощённая» спина.
        parts.append(_tube([(0.0, 0.205 * S, 1.00 * S), (0.0, 0.215 * S, 1.30 * S),
                            (0.0, 0.200 * S, 1.50 * S)], 0.022 * S, segs=4))
        for i in range(3):
            z = (1.14 + i * 0.10) * S
            for side in (-1.0, 1.0):
                pts = [(0.0, 0.205 * S, z),
                       (0.10 * S * side, 0.17 * S, z - 0.02 * S),
                       (0.21 * S * side, 0.06 * S, z - 0.05 * S)]
                parts.append(_tube(pts, 0.011 * S, segs=4))
        # Кандалы: шея, запястья, щиколотки.
        parts.append(_tube(_circle_path(0.135 * S, 24, gap=0.0, z=1.57 * S), 0.018 * S, segs=4))
        for side in (-1.0, 1.0):
            wr = _wrist(arm_pose, side, S, bulk)
            wrist_ring = _tube(_circle_path(0.075 * S, 20, gap=0.0, z=0.0), 0.014 * S, segs=4)
            wrist_ring.transform(T(wr[0], wr[1], wr[2]))
            parts.append(wrist_ring)
            ankle_ring = _tube(_circle_path(0.090 * S, 20, gap=0.0, z=0.0), 0.014 * S, segs=4)
            ankle_ring.transform(T(0.13 * S * side, 0.04 * S, 0.11 * S))
            parts.append(ankle_ring)
    return parts


def _humanoid(name, coll, height=1.8, bulk=1.0, hunch=0.0, arm_pose=0,
              seed=0, slave=True, target=3200, voxel=0.030, details=True):
    S = height / 1.8
    base = _voxel(name + "_base", _humanoid_parts(height, bulk, hunch, arm_pose, seed),
                  coll, "ss_shadow", voxel * S, target, smooth=1)
    if details:
        det = _join_parts(name + "_detail",
                          [(b, "ss_shadow") for b in _humanoid_details(height, bulk, seed, slave, arm_pose)],
                          coll)
        obj = _merge(name, [base, det], coll)
    else:
        obj = base
        obj.name = name
    return _finish(obj, "plain", sharp=48.0, uv_tile=1.0, mask=True, seed=seed)


def shade_slave(v=0):
    name = f"ss_shade_slave_{'abc'[v]}"
    coll = L.asset_collection(name)
    return _humanoid(name, coll, height=1.76 + v * 0.03, bulk=0.82 + v * 0.04,
                     hunch=(0.06 if v == 1 else 0.0), arm_pose=v,
                     seed=1100 + v * 13, slave=True, target=3000 + v * 300,
                     voxel=0.030, details=True)


def shade_slaver(v=0):
    name = f"ss_shade_slaver_{'ab'[v]}"
    coll = L.asset_collection(name)
    obj = _humanoid(name + "_body", coll, height=1.92, bulk=1.22, hunch=0.02,
                    arm_pose=1 + v, seed=1200 + v * 11, slave=False,
                    target=4200, voxel=0.034, details=True)
    # Кнут: рукоять у правой руки + длинная петля.
    S = 1.92 / 1.8
    b = 1.22
    wr = _wrist(1 + v, 1.0, S, b)
    parts = []
    grip_end = (wr[0] + 0.10 * S, wr[1] - 0.16 * S, wr[2] - 0.22 * S)
    grip = _tube([wr, (wr[0] + 0.05 * S, wr[1] - 0.08 * S, wr[2] - 0.10 * S), grip_end],
                 0.020 * S, segs=6)
    parts.append(grip)
    for i in range(2):
        pts = []
        for k in range(10):
            t = k / 9.0
            a = t * 2.4 + i * 1.7
            pts.append((grip_end[0] + 0.28 * S * t + 0.10 * S * math.sin(a),
                        grip_end[1] - 0.30 * S * t + 0.08 * S * math.cos(a),
                        grip_end[2] - 0.42 * S * t + 0.04 * S * math.sin(a * 1.3)))
        parts.append(_tube(pts, 0.010 * S, segs=4))
    whip = _join_parts("_whip", [(b, "ss_shadow") for b in parts], coll)
    obj = _merge(name, [obj, whip], coll)
    CL.recenter_base(obj, sink=0.0)
    return _finish(obj, "plain", sharp=46.0, uv_tile=1.0, mask=True, seed=1200 + v * 11)


def shade_mountain_king(seed=1300):
    name = "ss_shade_mountain_king"
    coll = L.asset_collection(name)
    H = 7.4
    S = H / 1.8
    b = 1.22
    body = _voxel(name + "_body",
                  _humanoid_parts(height=H, bulk=b, hunch=0.0, arm_pose=2, seed=seed),
                  coll, "ss_shadow", 0.09, 12000, smooth=1)
    parts = []
    # Два изогнутых рога-клыка.
    for side in (-1.0, 1.0):
        pts = [(0.38 * side, 0.02, H * 0.90),
               (0.78 * side, 0.02, H * 0.98),
               (1.18 * side, -0.02, H * 1.06)]
        parts.append(_tube(pts, 0.30, segs=7, taper=lambda t: 1.0 - 0.78 * t))
    # Корона из шипов.
    for i in range(8):
        a = TAU * i / 8.0
        parts.append(_cone(0.11, 0.72, (math.cos(a) * 0.30, math.sin(a) * 0.30, H * 0.90),
                           direction=(math.cos(a) * 0.30, math.sin(a) * 0.30, 1.0), segs=5))
    # Массивные наплечники с шипами.
    for side in (-1.0, 1.0):
        parts.append(CL.ellipsoid(1.15, 0.55, 0.72,
                                  center=(1.22 * side, 0.0, H * 0.77),
                                  segs=18, rings=10, wobble=0.04, seed=seed + 20 + int(side)))
        for i in range(4):
            a = -0.55 + i * 0.36
            parts.append(_cone(0.14, 0.85, (1.55 * side, a, H * 0.78),
                               direction=(0.75 * side, 0.0, 0.75), segs=5))
    # Нагрудная пластина, центральный гребень и пояс.
    parts.append(CL.ellipsoid(1.05, 0.30, 1.18,
                              center=(0, -0.92, H * 0.67),
                              segs=18, rings=10, wobble=0.03, seed=seed + 30))
    for i in range(3):
        z = H * (0.60 + i * 0.055)
        pts = [(-1.02, -1.06, z), (0.0, -1.16, z + 0.03), (1.02, -1.06, z)]
        parts.append(_tube(pts, 0.065, segs=5))
    parts.append(_tube([(0, -1.20, H * 0.74), (0, -1.24, H * 0.62), (0, -1.15, H * 0.50)],
                       0.10, segs=6, taper=lambda t: 1.0 - 0.4 * t))
    parts.append(_tube(_circle_path(1.12, 44, gap=0.0, z=H * 0.53), 0.10, segs=6))
    # Спина: хребет, лопатки и рёбра — чтобы силуэт не был гладким манекеном.
    for i in range(7):
        z = H * (0.34 + i * 0.075)
        parts.append(CL.ellipsoid(0.13, 0.09, 0.06,
                                  center=(0, 0.84, z), segs=10, rings=6,
                                  wobble=0.02, seed=seed + 70 + i))
        parts.append(_cone(0.045, 0.32, (0, 0.90, z),
                           direction=(0, 1.0, 0.12), segs=5))
    parts.append(_tube([(0, 0.86, H * 0.30), (0, 0.92, H * 0.55),
                        (0, 0.88, H * 0.86)], 0.055, segs=6))
    for side in (-1.0, 1.0):
        blade = P.board(1.15, 0.16, 1.35, bevel=0.045, seed=seed + 80 + int(side))
        blade.transform(T(0.82 * side, 0.55, H * 0.70)
                        @ Matrix.Rotation(0.35 * side, 4, "Z")
                        @ Matrix.Rotation(-0.18, 4, "X"))
        parts.append(blade)
        for i in range(3):
            z = H * (0.50 + i * 0.075)
            pts = [(0.18 * side, 0.78, z),
                   (0.55 * side, 0.66, z - 0.04),
                   (0.86 * side, 0.38, z - 0.10),
                   (1.00 * side, 0.02, z - 0.18)]
            parts.append(_tube(pts, 0.055, segs=5, taper=lambda t: 1.0 - 0.3 * t))
    back = P.board(1.65, 0.18, 2.00, bevel=0.065, seed=seed + 85)
    back.transform(T(0, 0.78, H * 0.66))
    parts.append(back)
    for i in range(4):
        z = H * (0.56 + i * 0.07)
        parts.append(_tube([(-0.75, 0.90, z), (0.0, 0.96, z + 0.02),
                            (0.75, 0.90, z)], 0.045, segs=5))
    # Воротник и маска.
    parts.append(_tube(_circle_path(0.47, 36, gap=0.0, z=H * 0.865), 0.075, segs=6))
    parts.append(_tube([(-0.18, -0.54, H * 0.925), (0.0, -0.58, H * 0.935),
                        (0.18, -0.54, H * 0.925)], 0.045, segs=6))
    # Коронный гребень.
    parts.append(_cone(0.13, 1.10, (0, 0, H * 0.94),
                       direction=(0, 0, 1), segs=6))
    for side in (-1.0, 1.0):
        parts.append(_cone(0.09, 0.82, (0.18 * side, 0, H * 0.93),
                           direction=(0.25 * side, 0, 1), segs=5))
    # Рваный плащ: только спина и бока, с большими прорехами.
    for i in range(10):
        a = 0.15 + (math.pi - 0.30) * i / 9.0
        h = 4.2 + 0.9 * math.sin(i * 1.7)
        w0 = 0.50 + 0.12 * (i % 3)
        flap = _cloth_panel(w0, w0 * 1.35, h, 0.035, seed=seed + 40 + i,
                            billow=0.42, notch=0.06)
        flap.transform(T(math.cos(a) * 1.32, math.sin(a) * 1.32, H * 0.78)
                       @ Matrix.Rotation(a - math.pi * 0.5, 4, "Z")
                       @ Matrix.Rotation(0.18, 4, "X"))
        parts.append(flap)
    # Второй слой плаща: широкие полотнища с крупными прорехами.
    for i in range(4):
        a = 0.35 + (math.pi - 0.70) * i / 3.0
        h = 5.05 + 0.55 * math.sin(i * 1.3)
        w0 = 0.95 + 0.10 * (i % 2)
        flap = _cloth_panel(w0, w0 * 1.45, h, 0.04, seed=seed + 110 + i,
                            billow=0.55, notch=0.10)
        flap.transform(T(math.cos(a) * 1.45, math.sin(a) * 1.45, H * 0.80)
                       @ Matrix.Rotation(a - math.pi * 0.5, 4, "Z")
                       @ Matrix.Rotation(0.22, 4, "X"))
        parts.append(flap)
    # Меховая накидка на плечах.
    for i in range(8):
        a = TAU * i / 8.0
        w0 = 0.32 + 0.05 * (i % 2)
        flap = _cloth_panel(w0, w0 * 1.4, 0.95, 0.03, seed=seed + 60 + i,
                            billow=0.10, notch=0.05)
        flap.transform(T(math.cos(a) * 1.05, math.sin(a) * 1.05, H * 0.80)
                       @ Matrix.Rotation(a - math.pi * 0.5, 4, "Z")
                       @ Matrix.Rotation(0.20, 4, "X"))
        parts.append(flap)
    # Передние рёбра, чтобы грудь не оставалась гладким пятном.
    for side in (-1.0, 1.0):
        for i in range(3):
            z = H * (0.44 + i * 0.075)
            pts = [(0.16 * side, -0.86, z),
                   (0.50 * side, -0.78, z - 0.03),
                   (0.86 * side, -0.44, z - 0.09)]
            parts.append(_tube(pts, 0.05, segs=5,
                               taper=lambda t: 1.0 - 0.25 * t))
    # Наручи и набедренные пластины.
    for side in (-1.0, 1.0):
        el = (0.50 * S * b * side, 0.02 * S, 1.20 * S)
        wr = _wrist(2, side, S, b)
        p0 = tuple(lerp(el[k], wr[k], 0.42) for k in range(3))
        p1 = tuple(lerp(el[k], wr[k], 0.82) for k in range(3))
        parts.append(_tube([p0, p1], 0.075 * S * b, segs=8,
                           taper=lambda t: 1.0 - 0.15 * t))
        for k in (-1.0, 0.0, 1.0):
            parts.append(_cone(0.04 * S, 0.26 * S,
                               (p1[0], p1[1] + 0.10 * k, p1[2]),
                               direction=(0.45 * side, 0.55, 0.15), segs=5))
        thigh = P.board(0.55, 0.12, 0.85, bevel=0.035, seed=seed + 100 + int(side))
        thigh.transform(T(0.13 * S * side, -0.15 * S, 0.62 * S)
                        @ Matrix.Rotation(0.12 * side, 4, "Z"))
        parts.append(thigh)
    # Когти на руках.
    for side in (-1.0, 1.0):
        wr = _wrist(2, side, S, b)
        for k in (-1.0, 0.0, 1.0):
            pts = [(wr[0], wr[1], wr[2]),
                   (wr[0] + 0.10 * side, wr[1] - 0.16, wr[2] - 0.20),
                   (wr[0] + 0.14 * side, wr[1] - 0.26, wr[2] - 0.38 + 0.04 * k)]
            parts.append(_tube(pts, 0.045, segs=5, taper=lambda t: 1.0 - 0.7 * t))
    detail = _join_parts("_king_detail", [(b, "ss_shadow") for b in parts], coll)
    obj = _merge(name, [body, detail], coll)
    CL.recenter_base(obj, sink=0.0)
    return _finish(obj, "plain", sharp=42.0, uv_tile=1.0, mask=True, seed=seed)


# ---------------------------------------------------------------------------
# Карапаксы
# ---------------------------------------------------------------------------

def _carapace_parts(scale=1.0, seed=0, centurion=False):
    """Панцирь, торс, ноги и клешни. Возвращает (shell_parts, body_parts, limb_parts)."""
    S = scale
    rng = random.Random(seed)
    shell = []
    body = []
    limbs = []
    shell.append(CL.ellipsoid(1.05 * S, 0.88 * S, 0.55 * S,
                              center=(0, 0.05 * S, 1.22 * S), wobble=0.06, seed=seed + 1))
    for i in range(3):
        shell.append(CL.ellipsoid((0.82 - i * 0.10) * S, (0.66 - i * 0.06) * S, 0.22 * S,
                                  center=(0, 0.10 * S + i * 0.06 * S, (1.38 + i * 0.15) * S),
                                  wobble=0.04, seed=seed + 2 + i))
    # Торс и голова.
    body.append(CL.ellipsoid(0.42 * S, 0.34 * S, 0.52 * S,
                             center=(0, -0.50 * S, 1.52 * S), wobble=0.04, seed=seed + 5))
    body.append(CL.ellipsoid(0.27 * S, 0.29 * S, 0.30 * S,
                             center=(0, -0.82 * S, 1.88 * S), wobble=0.03, seed=seed + 6))
    body.append(_tube([(0, -0.55 * S, 1.72 * S), (0, -0.72 * S, 1.80 * S)],
                      0.15 * S, segs=8))
    # Ноги: три пары, сегментные, вынесены наружу, чтобы читались.
    for side in (-1.0, 1.0):
        for i in range(3):
            y0 = (-0.40 + i * 0.40) * S
            hip = (1.00 * S * side, y0, 1.12 * S)
            knee = (1.72 * S * side, y0 + 0.06 * S, 0.68 * S)
            foot = (2.10 * S * side, y0 + 0.12 * S, 0.09 * S)
            limbs.append(_tube([hip, knee, foot], 0.17 * S, segs=8,
                               taper=lambda t: 1.0 - 0.55 * t))
            limbs.append(CL.ellipsoid(0.14 * S, 0.14 * S, 0.14 * S,
                                      center=knee, segs=10, rings=7, wobble=0.03,
                                      seed=seed + 30 + i + int(side)))
            # Два когтя на ступне.
            for k in (-1.0, 1.0):
                limbs.append(_cone(0.055 * S, 0.28 * S,
                                   (foot[0], foot[1] + k * 0.10 * S, foot[2] + 0.02 * S),
                                   direction=(0.55 * side, 0.15 * k, -0.75), segs=5))
    # Клешни: крупнее и с двумя «пальцами».
    for side in (-1.0, 1.0):
        sh = (0.42 * S * side, -0.58 * S, 1.62 * S)
        el = (0.88 * S * side, -1.02 * S, 1.38 * S)
        wr = (1.02 * S * side, -1.32 * S, 1.12 * S)
        limbs.append(_tube([sh, el, wr], 0.17 * S, segs=8,
                           taper=lambda t: 1.0 - 0.42 * t))
        limbs.append(CL.ellipsoid(0.15 * S, 0.15 * S, 0.15 * S,
                                  center=el, segs=10, rings=7, wobble=0.03,
                                  seed=seed + 50 + int(side)))
        # Верхняя и нижняя половины клешни.
        for off in (-0.14, 0.14):
            pts = [(wr[0], wr[1], wr[2] + off),
                   (wr[0] + 0.30 * S * side, wr[1] - 0.34 * S, wr[2] + off * 0.6),
                   (wr[0] + 0.40 * S * side, wr[1] - 0.62 * S, wr[2] + off * 0.25)]
            limbs.append(_tube(pts, 0.075 * S, segs=6,
                               taper=lambda t: 1.0 - 0.88 * t))
    # Шипы и гребень на панцире.
    for i in range(8):
        a = TAU * i / 8.0
        shell.append(_cone(0.075 * S, 0.42 * S,
                           (math.cos(a) * 0.55 * S, 0.05 * S + math.sin(a) * 0.45 * S, 1.66 * S),
                           direction=(math.cos(a) * 0.5, math.sin(a) * 0.5, 1.0), segs=5))
    shell.append(_tube([(0, -0.70 * S, 1.58 * S), (0, 0.10 * S, 1.70 * S), (0, 0.72 * S, 1.52 * S)],
                       0.055 * S, segs=6, taper=lambda t: 1.0 - 0.4 * t))
    if centurion:
        # Вторая пара рук и корона.
        for side in (-1.0, 1.0):
            sh = (0.30 * S * side, -0.48 * S, 1.72 * S)
            el = (0.58 * S * side, -0.82 * S, 1.58 * S)
            wr = (0.66 * S * side, -1.05 * S, 1.38 * S)
            limbs.append(_tube([sh, el, wr], 0.11 * S, segs=6,
                               taper=lambda t: 1.0 - 0.45 * t))
            limbs.append(_cone(0.06 * S, 0.45 * S, wr,
                               direction=(0.3 * side, -0.5, 0.8), segs=5))
        for i in range(5):
            a = -0.8 + i * 0.4
            limbs.append(_cone(0.08 * S, 0.55 * S,
                               (math.cos(a) * 0.22 * S, -0.82 * S + math.sin(a) * 0.12 * S, 2.08 * S),
                               direction=(math.cos(a) * 0.4, -0.2, 1.0), segs=5))
        # Сегментные рёбра, повторяющие купол панциря.
        for i in range(4):
            y = (-0.50 + i * 0.34) * S
            z = (1.56 + 0.035 * i) * S
            pts = [(-0.86 * S, y, z - 0.06 * S),
                   (-0.46 * S, y - 0.05 * S, z + 0.08 * S),
                   (0.0, y, z + 0.13 * S),
                   (0.46 * S, y - 0.05 * S, z + 0.08 * S),
                   (0.86 * S, y, z - 0.06 * S)]
            shell.append(_tube(pts, 0.07 * S, segs=6,
                               taper=lambda t: 1.0 - 0.2 * t))
        # Центральный гребень.
        for i in range(3):
            shell.append(_cone(0.10 * S, 0.55 * S,
                               (0, (-0.42 + i * 0.42) * S, (1.66 + 0.03 * i) * S),
                               direction=(0, 0.10, 1.0), segs=5))
        # Надбровье, мандибулы и гребень вместо плоской маски.
        limbs.append(_tube([(-0.20 * S, -1.02 * S, 1.96 * S),
                            (0.0, -1.08 * S, 2.00 * S),
                            (0.20 * S, -1.02 * S, 1.96 * S)], 0.055 * S, segs=5))
        for side in (-1.0, 1.0):
            limbs.append(_cone(0.06 * S, 0.52 * S,
                               (0.18 * S * side, -1.00 * S, 2.10 * S),
                               direction=(0.25 * side, -0.2, 1.0), segs=5))
            pts = [(0.12 * S * side, -0.96 * S, 1.84 * S),
                   (0.28 * S * side, -1.12 * S, 1.76 * S),
                   (0.34 * S * side, -1.20 * S, 1.64 * S)]
            limbs.append(_tube(pts, 0.05 * S, segs=5,
                               taper=lambda t: 1.0 - 0.55 * t))
        limbs.append(_tube([(0, -0.70 * S, 2.02 * S),
                            (0, -0.92 * S, 2.10 * S),
                            (0, -1.06 * S, 2.06 * S)], 0.06 * S, segs=5,
                           taper=lambda t: 1.0 - 0.45 * t))
        # Наплечники с шипами.
        for side in (-1.0, 1.0):
            sh = (0.42 * S * side, -0.58 * S, 1.62 * S)
            limbs.append(CL.ellipsoid(0.34 * S, 0.30 * S, 0.22 * S,
                                     center=(sh[0] + 0.12 * S * side,
                                             sh[1] + 0.02 * S, sh[2] + 0.12 * S),
                                     segs=14, rings=8, wobble=0.03,
                                     seed=seed + 220 + int(side)))
            for k in range(3):
                limbs.append(_cone(0.05 * S, 0.40 * S,
                                   (sh[0] + 0.16 * S * side,
                                    sh[1] + 0.02 * S, sh[2] + 0.16 * S),
                                   direction=(0.45 * side, 0.25 * (k - 1), 0.85), segs=5))
        # Наручи на клешнях и наколенники.
        for side in (-1.0, 1.0):
            el = (0.88 * S * side, -1.02 * S, 1.38 * S)
            wr = (1.02 * S * side, -1.32 * S, 1.12 * S)
            p0 = tuple(lerp(el[k], wr[k], 0.18) for k in range(3))
            p1 = tuple(lerp(el[k], wr[k], 0.72) for k in range(3))
            limbs.append(_tube([p0, p1], 0.15 * S, segs=8,
                               taper=lambda t: 1.0 - 0.2 * t))
            for k in (-1.0, 0.0, 1.0):
                limbs.append(_cone(0.045 * S, 0.34 * S,
                                   (p1[0], p1[1] + 0.08 * S * k, p1[2]),
                                   direction=(0.5 * side, -0.25, 0.75), segs=5))
        for side in (-1.0, 1.0):
            for i in range(3):
                y0 = (-0.40 + i * 0.40) * S
                knee = (1.72 * S * side, y0 + 0.06 * S, 0.68 * S)
                plate = P.board(0.30 * S, 0.10 * S, 0.26 * S,
                                bevel=0.02 * S, seed=seed + 230 + i + int(side))
                plate.transform(T(*knee) @ Matrix.Rotation(0.4 * side, 4, "Z"))
                limbs.append(plate)
        # Вертикальные рёбра на груди.
        for side in (-1.0, 1.0):
            pts = [(0.20 * S * side, -0.78 * S, 1.16 * S),
                   (0.26 * S * side, -0.86 * S, 1.38 * S),
                   (0.22 * S * side, -0.82 * S, 1.58 * S)]
            limbs.append(_tube(pts, 0.045 * S, segs=5,
                               taper=lambda t: 1.0 - 0.25 * t))
    return shell, body, limbs


def _carapace(name, coll, scale=1.0, seed=0, centurion=False, target=8000):
    shell_parts, body_parts, limbs = _carapace_parts(scale, seed, centurion)
    shell = _voxel(name + "_shell", shell_parts, coll, "ss_chitin",
                   0.075 * scale, int(target * 0.45), smooth=1)
    body = _voxel(name + "_body", body_parts, coll, "ss_shadow",
                  0.065 * scale, int(target * 0.35), smooth=1)
    limb_obj = _join_parts(name + "_limbs", [(b, "ss_chitin") for b in limbs], coll)
    obj = _merge(name, [shell, body, limb_obj], coll)
    CL.recenter_base(obj, sink=0.0)
    return _finish(obj, "plain", sharp=45.0, uv_tile=1.0, mask=True, seed=seed)


def shade_carapace_scavenger(v=0):
    name = f"ss_shade_carapace_scavenger_{'abc'[v]}"
    coll = L.asset_collection(name)
    scale = (1.0, 1.12, 0.88)[v]
    return _carapace(name, coll, scale=scale, seed=1400 + v * 17,
                     centurion=False, target=7200 + v * 700)


def shade_carapace_centurion(seed=1500):
    name = "ss_shade_carapace_centurion"
    coll = L.asset_collection(name)
    return _carapace(name, coll, scale=1.50, seed=seed, centurion=True, target=15000)


# ---------------------------------------------------------------------------
# Сколопендры, черви, цветок
# ---------------------------------------------------------------------------

def _centipede_path(v=0, segments=14):
    pts = []
    for i in range(segments):
        t = i / (segments - 1)
        if v == 0:
            x = lerp(-2.6, 2.6, t)
            y = 0.55 * math.sin(t * 3.2)
        else:
            a = t * 3.6
            x = 1.8 * math.cos(a) * (1.0 - 0.35 * t)
            y = 1.8 * math.sin(a) * (1.0 - 0.35 * t)
        z = 0.35 + 0.18 * math.sin(t * 4.0 + v)
        pts.append((x, y, z))
    return pts


def shade_centipede(v=0):
    name = f"ss_shade_centipede_{'ab'[v]}"
    coll = L.asset_collection(name)
    pts = _centipede_path(v)
    parts = []
    n = len(pts)
    for i, p in enumerate(pts):
        t = i / (n - 1)
        r = (0.30 - 0.16 * t) if v == 0 else (0.26 - 0.12 * t)
        parts.append(CL.ellipsoid(r, r * 0.9, r * 0.8, center=p,
                                  segs=14, rings=9, wobble=0.04, seed=1600 + i + v * 20))
        # Дорсальный шип.
        parts.append(_cone(0.045, 0.22, (p[0], p[1], p[2] + r * 0.65),
                           direction=(0.0, 0.0, 1.0), segs=4))
        # Ноги: две на сегмент, с коленом и ступнёй.
        for side in (-1.0, 1.0):
            base = (p[0], p[1] + side * r * 0.6, p[2] - 0.05)
            knee = (p[0] + side * 0.34, p[1] + side * (r + 0.24), p[2] - 0.20)
            foot = (p[0] + side * 0.58, p[1] + side * (r + 0.34), 0.02)
            parts.append(_tube([base, knee, foot], 0.065, segs=6,
                               taper=lambda tt: 1.0 - 0.55 * tt))
            parts.append(CL.ellipsoid(0.065, 0.065, 0.065, center=knee,
                                      segs=8, rings=6, wobble=0.03,
                                      seed=1700 + i * 3 + int(side)))
    # Голова и жвала.
    head = pts[-1]
    parts.append(CL.ellipsoid(0.40, 0.36, 0.30, center=(head[0] + 0.22, head[1], head[2] + 0.05),
                              segs=14, rings=9, wobble=0.03, seed=1700 + v))
    for side in (-1.0, 1.0):
        parts.append(_cone(0.075, 0.55, (head[0] + 0.48, head[1] + side * 0.18, head[2] - 0.02),
                           direction=(1.0, side * 0.35, -0.25), segs=5))
    obj = _join_parts(name, [(b, "ss_shadow") for b in parts], coll)
    CL.recenter_base(obj, sink=0.0)
    return _finish(obj, "plain", sharp=46.0, uv_tile=1.0, mask=True, seed=1600 + v * 20)


def shade_worm_knot(v=0):
    name = f"ss_shade_worm_knot_{'ab'[v]}"
    coll = L.asset_collection(name)
    rng = random.Random(1800 + v * 23)
    parts = []
    count = 9 + v * 3
    for i in range(count):
        a = TAU * i / count + rng.uniform(-0.2, 0.2)
        pts = []
        for k in range(9):
            t = k / 8.0
            r = (0.12 + 0.55 * t) * (0.8 + 0.4 * (i % 3))
            z = 0.15 + (0.55 + 0.55 * v) * t + 0.10 * math.sin(t * 6.0 + i)
            pts.append((math.cos(a) * r + 0.10 * math.sin(t * 5.0 + i),
                        math.sin(a) * r + 0.10 * math.cos(t * 4.0 + i), z))
        parts.append(_tube(pts, 0.075 + 0.02 * (i % 3), segs=6,
                           taper=lambda t: 0.8 + 0.5 * math.sin(math.pi * t)))
        parts.append(CL.ellipsoid(0.11, 0.10, 0.10,
                                  center=(pts[-1][0], pts[-1][1], pts[-1][2] + 0.06),
                                  segs=12, rings=8, wobble=0.04, seed=1900 + i))
    obj = _join_parts(name, [(b, "ss_shadow") for b in parts], coll)
    CL.recenter_base(obj, sink=0.0)
    return _finish(obj, "plain", sharp=45.0, uv_tile=1.0, mask=True, seed=1800 + v * 23)


def shade_blood_flower(v=0):
    name = f"ss_shade_blood_flower_{'ab'[v]}"
    coll = L.asset_collection(name)
    rng = random.Random(2000 + v * 19)
    parts = []
    # Стебель.
    stem = _tube([(0, 0, 0.0), (0.06, 0.03, 0.55), (0.0, -0.02, 1.10)],
                 0.075, segs=7, taper=lambda t: 1.0 - 0.35 * t)
    parts.append(stem)
    # Лепестки.
    for i in range(8):
        a = TAU * i / 8.0 + rng.uniform(-0.08, 0.08)
        h = 1.05 + 0.25 * (i % 3)
        w = 0.45 + 0.10 * (i % 2)
        petal = CL.blade(h, w, 0.06, curve=(0.35, 0.12), taper=0.18, ridge=0.16,
                         segs=10, rings=8, seed=2100 + i)
        petal.transform(T(0, 0, 1.02)
                        @ Matrix.Rotation(math.radians(58 + 6 * (i % 3)), 4, "X")
                        @ Matrix.Rotation(a, 4, "Z"))
        parts.append(petal)
    # Пасть: кольцо зубов.
    for i in range(12):
        a = TAU * i / 12.0
        parts.append(_cone(0.035, 0.22, (math.cos(a) * 0.20, math.sin(a) * 0.20, 1.28),
                           direction=(-math.cos(a) * 0.4, -math.sin(a) * 0.4, 1.0), segs=4))
    # Щупальца.
    for i in range(5):
        a = TAU * i / 5.0 + 0.4
        pts = []
        for k in range(8):
            t = k / 7.0
            r = 0.22 + 0.55 * t
            pts.append((math.cos(a + t * 0.8) * r, math.sin(a + t * 0.8) * r,
                        0.95 + 0.55 * t + 0.10 * math.sin(t * 5.0 + i)))
        parts.append(_tube(pts, 0.028, segs=5, taper=lambda t: 1.0 - 0.6 * t))
    obj = _join_parts(name, [(b, "ss_shadow") for b in parts], coll)
    CL.recenter_base(obj, sink=0.0)
    return _finish(obj, "plain", sharp=42.0, uv_tile=1.0, mask=True, seed=2000 + v * 19)


# ---------------------------------------------------------------------------
# Дальние ряды и колоссы
# ---------------------------------------------------------------------------

def shade_rank_far(v=0):
    name = f"ss_shade_rank_far_{'abc'[v]}"
    coll = L.asset_collection(name)
    height = (1.85, 2.35, 3.10)[v]
    bulk = (0.85, 1.35, 1.0)[v]
    obj = _humanoid(name, coll, height=height, bulk=bulk, hunch=(0.08 if v == 1 else 0.0),
                    arm_pose=(1 if v == 2 else 0), seed=2200 + v * 7, slave=False,
                    target=(1100, 1400, 1600)[v], voxel=0.055, details=False)
    if v == 2:
        # Копьё-силуэт.
        spear = _tube([(0.50, 0.02, 0.05), (0.58, 0.02, 3.4)], 0.035, segs=5,
                      taper=lambda t: 1.0 - 0.7 * t)
        spear_obj = _join_parts("_spear", [(spear, "ss_shadow")], coll)
        obj = _merge(name, [obj, spear_obj], coll)
        _finish(obj, "plain", sharp=45.0, uv_tile=1.0, mask=True, seed=2200 + v * 7)
    return obj


def shade_colossus_far(v=0):
    name = f"ss_shade_colossus_far_{'abc'[v]}"
    coll = L.asset_collection(name)
    height = (18.0, 24.0, 30.0)[v]
    bulk = (1.7, 2.4, 1.35)[v]
    obj = _humanoid(name, coll, height=height, bulk=bulk, hunch=(0.04 if v == 1 else 0.0),
                    arm_pose=2, seed=2300 + v * 9, slave=False,
                    target=(900, 1200, 1500)[v], voxel=0.22, details=False)
    # Рога/шипы для силуэта.
    parts = []
    if v == 0:
        for side in (-1.0, 1.0):
            parts.append(_cone(0.35, 2.2, (1.8 * side, 0.0, height * 0.92),
                               direction=(0.5 * side, 0.0, 1.0), segs=6))
        for i in range(4):
            a = -0.6 + i * 0.4
            parts.append(_cone(0.18, 1.2, (1.6, a * 1.4, height * 0.62),
                               direction=(0.7, a, 0.7), segs=5))
    elif v == 1:
        for i in range(6):
            a = TAU * i / 6.0
            parts.append(_cone(0.28, 1.8,
                               (math.cos(a) * 3.0, math.sin(a) * 3.0, height * 0.55),
                               direction=(math.cos(a) * 0.6, math.sin(a) * 0.6, 1.0), segs=5))
    else:
        spear = _tube([(3.2, 0.0, 0.0), (4.0, 0.0, height * 1.05)], 0.16, segs=5,
                      taper=lambda t: 1.0 - 0.8 * t)
        parts.append(spear)
        for i in range(4):
            a = TAU * i / 4.0
            parts.append(_cone(0.20, 1.0, (math.cos(a) * 0.5, math.sin(a) * 0.5, height * 0.95),
                               direction=(math.cos(a) * 0.4, math.sin(a) * 0.4, 1.0), segs=5))
    if parts:
        detail = _join_parts("_colossus_detail", [(b, "ss_shadow") for b in parts], coll)
        obj = _merge(name, [obj, detail], coll)
        _finish(obj, "plain", sharp=42.0, uv_tile=1.0, mask=True, seed=2300 + v * 9)
    return obj

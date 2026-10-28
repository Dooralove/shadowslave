"""Партия 2 — стоянка и марш каравана (S01–S06): повозка, груз, цепь и кандалы, костёр,
снаряжение стражи, хлеб, Bloodbane.

Запуск из корня проекта (Blender 5.1, в фоне):
    blender -b --factory-startup --python assets/environments/nightmare/source/build_caravan_kit.py -- [опции]
Опции — как у build_mountain_kit.py (--only <группы>, --test <файл.jpg>, --no-export).
Результат: `source/caravan_kit.blend`, `caravan/*.glb`, `flora/*.glb`, превью `docs/art/previews/nightmare/caravan_*.jpg`.

Канон (docs/research/first_nightmare/02_caravan_canon.md, docs/story/canon_first_nightmare_caravan.md):
тяжёлая повозка с едой, водой и грузом; её тянули четыре вола; главная цепь прочно прикреплена
к повозке; в лагере повозку ставят боком на верхнем конце площадки, под задние колёса — клинья;
железные кандалы с короткой цепью между ними, ключ; большой костёр в центре; фляги; копьё и
короткий меч Героя; кнут и сломанный меч ветерана; твёрдый заплесневелый хлеб; ярко-красные
ягоды Bloodbane растут из снега там, где кончается мостовая. Конструкция повозки, тент, вид
бочек, мешков и ящиков, форма куста — ART-DIRECTION (см. location_asset_matrix.md).
Оси: вперёд +Y (у повозки — дышло), вверх +Z; начало у основания, у повозки — центр колёсной базы.
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
from mathutils.bvhtree import BVHTree  # noqa: E402

import nm_lib as L  # noqa: E402

importlib.reload(L)
import nm_props as P  # noqa: E402

importlib.reload(P)

T, rot, I = P.T, P.rot, P.I
OUT = {"caravan": L.NM_DIR / "caravan", "flora": L.NM_DIR / "flora"}
FOLDER = {}


def _done(objs, folder="caravan"):
    FOLDER[objs[0].users_collection[0].name] = folder
    return objs


# --------------------------------------------------------------------------------------
# Колесо и повозка
# --------------------------------------------------------------------------------------
def wheel(asm, radius, spokes, m, seed=0, hub_len=0.34, broken=False):
    """Колесо со ступицей, спицами, ободом из косяков и железной шиной. Ось — X."""
    r = random.Random(seed)
    tire_w = 0.085
    asm.add(P.ring_rect(radius - 0.018, radius, tire_w, segs=40), "nm_iron", m)
    rim_in = radius - 0.1
    segs = 40 if not broken else 40
    felloe = P.ring_rect(rim_in, radius - 0.018, 0.078, segs=segs)
    if broken:
        # Сломанное колесо: половина обода, часть спиц.
        bmesh.ops.delete(felloe, geom=[v for v in felloe.verts if v.co.y < -0.05 * radius], context="VERTS")
    asm.add(felloe, "nm_wood", m)
    hub = P.lathe([(0.075, -hub_len / 2), (0.1, -hub_len / 2 + 0.03), (0.125, -0.04), (0.125, 0.04),
                   (0.1, hub_len / 2 - 0.03), (0.075, hub_len / 2)], segs=16)
    asm.add(hub, "nm_wood_dark", m @ rot(90, "Y"))
    for zz in (-hub_len / 2 + 0.02, hub_len / 2 - 0.02):
        asm.add(P.ring_rect(0.085, 0.1, 0.03, segs=16), "nm_iron", m @ T(zz, 0, 0))
    for k in range(spokes):
        a = 2 * math.pi * k / spokes + r.uniform(-0.01, 0.01)
        if broken and math.sin(a) < -0.05:
            continue
        ln = rim_in - 0.1 + 0.02
        sp = P.board(0.04, 0.055, ln, bevel=0.008)
        P.deform(sp, lambda c, ln=ln: Vector((c.x * (1.0 - 0.25 * (c.z / ln + 0.5)),
                                               c.y * (1.0 - 0.25 * (c.z / ln + 0.5)), c.z)))
        asm.add(sp, "nm_wood", m @ rot(math.degrees(a) - 90, "X") @ T(0, 0, 0.1 + ln / 2 - 0.01))
    return asm


def _cargo_parts(asm, r):
    """Груз: бочки воды у передка, мешки с едой, ящики (CANON: еда, вода, другой груз)."""
    for k, (x, y) in enumerate(((-0.42, 1.38), (0.0, 1.42), (0.42, 1.36))):
        barrel(asm, T(x, y, 0.985) @ rot(r.uniform(0, 360), "Z"), seed=11 + k)
    for k, (x, y, z, rz) in enumerate(((-0.35, 0.55, 0.985, 6), (0.33, 0.6, 0.985, -4), (0.0, 0.15, 1.18, 85),
                                      (-0.36, -0.25, 0.985, 2), (0.34, -0.3, 0.985, -7))):
        sack(asm, T(x, y, z) @ rot(rz, "Z"), seed=21 + k)
    crate(asm, T(0.0, -1.2, 0.985) @ rot(3, "Z"), seed=31)
    crate(asm, T(0.05, -1.25, 1.53) @ rot(-6, "Z"), seed=32, size=(0.7, 0.5, 0.42))


def _tarp(asm, cargo_objs, r):
    """Тент из грубого полотна, наброшенный на мешки и ящики задней части (ART-DIRECTION:
    защищает груз от снега). Высоты — лучом сверху по грузу, затем «провис» сглаживанием."""
    bm = bmesh.new()
    for o in cargo_objs:
        tmp = o.data.copy()
        tmp.transform(o.matrix_world)
        bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    nx, ny = 22, 20
    x0, x1, y0, y1 = -0.95, 0.95, -0.62, 0.92
    H = [[0.0] * (ny + 1) for _ in range(nx + 1)]
    for i in range(nx + 1):
        for j in range(ny + 1):
            x = x0 + (x1 - x0) * i / nx
            y = y0 + (y1 - y0) * j / ny
            hit = tree.ray_cast(Vector((x, y, 3.0)), Vector((0, 0, -1)), 5.0)[0]
            base = min(hit.z + 0.03, 1.5) if hit is not None else 1.0
            if abs(x) > 0.8:  # свисает за борт
                base = min(base, 1.48 - (abs(x) - 0.8) * 2.5)
            H[i][j] = base
    for _ in range(6):
        H2 = [row[:] for row in H]
        for i in range(1, nx):
            for j in range(1, ny):
                avg = (H[i - 1][j] + H[i + 1][j] + H[i][j - 1] + H[i][j + 1]) / 4
                H2[i][j] = max(H[i][j] - 0.02, 0.6 * H[i][j] + 0.4 * avg) if H[i][j] > avg else 0.5 * H[i][j] + 0.5 * avg
        H = H2
    sheet = bmesh.new()
    vs = [[sheet.verts.new((x0 + (x1 - x0) * i / nx, y0 + (y1 - y0) * j / ny,
                            H[i][j] + 0.008 * L.noise.noise(Vector((i * 0.7, j * 0.7, 0.3)))))
           for j in range(ny + 1)] for i in range(nx + 1)]
    for i in range(nx):
        for j in range(ny):
            sheet.faces.new((vs[i][j], vs[i + 1][j], vs[i + 1][j + 1], vs[i][j + 1]))
    bmesh.ops.solidify(sheet, geom=list(sheet.faces), thickness=0.006)
    uv = sheet.loops.layers.uv.verify()
    for f in sheet.faces:
        for loop in f.loops:
            loop[uv].uv = (loop.vert.co.x, loop.vert.co.y)
    asm.add(sheet, "nm_linen")
    # Обвязка тента верёвкой поперёк.
    for y in (-0.35, 0.35):
        j = int((y - y0) / (y1 - y0) * ny)
        path = [Vector((x0 + (x1 - x0) * i / nx, y, H[i][j] + 0.012)) for i in range(nx + 1)]
        asm.add(P.tube(path, 0.008, segs=5), "nm_rope")


def wagon_cargo():
    """Тяжёлая грузовая повозка (герой-объект): рама, настил, борта на стойках, передок с
    поворотным кругом и дышлом, 4 колеса (отдельные узлы для вращения), железные скобы,
    кольцо крепления главной цепи у заднего угла, груз под тентом."""
    name = "wagon_cargo"
    coll = L.asset_collection(name)
    r = random.Random(4001)
    body = P.Assembly(name + "_body", coll)
    a = body.add
    # Рама: продольные брусья (на них поперечный настил).
    for x in (-0.62, 0.62):
        a(P.board(0.12, 3.72, 0.14, bevel=0.01, seed=1, warp=0.004), "nm_wood_dark", T(x, -0.1, 0.88))
    # Настил: поперечные доски с неравными зазорами; одна задняя доска надломлена.
    y = -1.94
    k = 0
    while y < 1.72:
        w = r.uniform(0.16, 0.2)
        ln = 1.56 if not (k == 1) else 1.1
        bx = 0.0 if k != 1 else -0.23
        a(P.board(ln, w - 0.008, 0.035, bevel=0.005, seed=k, warp=0.006), "nm_wood",
          T(bx, y + w / 2, 0.9675 + r.uniform(-0.004, 0.004)) @ rot(r.uniform(-0.6, 0.6), "Z"))
        y += w
        k += 1
    # Борта: по две доски на сторону, на стойках в гнёздах брусьев.
    for sx in (-1, 1):
        for z in (1.1, 1.345):
            a(P.board(0.035, 3.7, 0.22, bevel=0.006, seed=int(z * 10) + sx, warp=0.006), "nm_wood",
              T(sx * 0.775, -0.11, z))
        for yy in (-1.85, -0.95, -0.05, 0.85, 1.65):
            a(P.board(0.06, 0.065, 0.66, bevel=0.008), "nm_wood_dark", T(sx * 0.82, yy, 1.17))
            a(P.board(0.012, 0.08, 0.1, bevel=0.002), "nm_iron", T(sx * 0.856, yy, 0.9))
    # Передний борт и задний откидной борт с железными полосами.
    for yy, two in ((1.76, True), (-1.98, True)):
        for z in (1.1, 1.345):
            a(P.board(1.5, 0.035, 0.22, bevel=0.006, seed=int(yy * 10)), "nm_wood", T(0, yy, z))
        for x in (-0.55, 0.55):
            a(P.board(0.05, 0.012, 0.5, bevel=0.002), "nm_iron", T(x, yy + (0.024 if yy > 0 else -0.024), 1.22))
    # Железные уголки на углах кузова.
    for sx in (-1, 1):
        for yy in (1.76, -1.98):
            a(P.board(0.1, 0.1, 0.012, bevel=0.002), "nm_iron", T(sx * 0.74, yy - 0.04 * (1 if yy > 0 else -1), 1.47))
    # Ходовая: задняя ось и подушка, передняя ось, поворотный круг, подушка, дрога.
    a(P.board(2.12, 0.15, 0.15, bevel=0.012), "nm_wood_dark", T(0, -1.15, 0.62))
    a(P.board(1.5, 0.13, 0.12, bevel=0.01), "nm_wood_dark", T(0, -1.15, 0.755))
    a(P.board(1.94, 0.13, 0.13, bevel=0.012), "nm_wood_dark", T(0, 1.2, 0.5))
    a(P.cylinder(0.3, 0.06, segs=20), "nm_wood_dark", T(0, 1.2, 0.6))
    a(P.cylinder(0.025, 0.36, segs=8), "nm_iron", T(0, 1.2, 0.66))
    a(P.board(1.56, 0.14, 0.16, bevel=0.012), "nm_wood_dark", T(0, 1.2, 0.71))
    a(P.board(0.1, 2.5, 0.1, bevel=0.01), "nm_wood_dark", T(0, 0.02, 0.6))
    for x, y_axle, z_axle, ln in ((-1, -1.15, 0.62, 0.42), (1, -1.15, 0.62, 0.42), (-1, 1.2, 0.5, 0.42), (1, 1.2, 0.5, 0.42)):
        a(P.cylinder(0.034, ln, segs=10, axis="X"), "nm_iron", T(x * 0.98, y_axle, z_axle))
    # Дышло: от переднего моста вперёд и вниз до земли, с подкосами и кольцом для ярма.
    pole = Vector((0, 4.05, 0.13)) - Vector((0, 1.2, 0.5))
    ang = math.degrees(math.atan2(pole.z, pole.y))
    a(P.board(0.1, pole.length, 0.11, bevel=0.012, seed=7, warp=0.01), "nm_wood",
      T(0, 1.2 + pole.y / 2, 0.5 + pole.z / 2) @ rot(ang, "X"))
    for sx in (-1, 1):
        brace = Vector((sx * -0.5, 1.0, 0.0))
        a(P.board(0.06, brace.length, 0.06, bevel=0.008), "nm_wood_dark",
          T(sx * 0.25, 1.7, 0.47) @ rot(math.degrees(math.atan2(-brace.x, brace.y)), "Z"))
    a(P.ring_rect(0.05, 0.068, 0.02, segs=16, axis="Y"), "nm_iron", T(0, 4.08, 0.16) @ rot(90, "Y"))
    # Кольцо главной цепи: проушина на заднем левом брусе + кольцо (CANON: цепь прочно прикреплена).
    a(P.board(0.03, 0.09, 0.12, bevel=0.004), "nm_iron", T(-0.69, -1.96, 0.88))
    ring = P.tube([Vector((0, 0.075 * math.cos(t * 2 * math.pi / 20), -0.075 * math.sin(t * 2 * math.pi / 20) - 0.075))
                   for t in range(20)], 0.014, segs=8, closed=True)
    a(ring, "nm_iron", T(-0.72, -2.0, 0.86) @ rot(12, "Y"))
    cargo = P.Assembly(name + "_cargo", coll)
    _cargo_parts(cargo, r)
    cargo_objs = cargo.build()
    tarp = P.Assembly(name + "_tarp", coll)
    _tarp(tarp, [o for o in cargo_objs if o.name.endswith("nm_linen")], r)
    parts = body.build() + cargo_objs + tarp.build()
    wheels = []
    for wn, x, y, z, rad, sp in (("wheel_rear_l", -0.98, -1.15, 0.62, 0.62, 12), ("wheel_rear_r", 0.98, -1.15, 0.62, 0.62, 12),
                                 ("wheel_front_l", -0.95, 1.2, 0.5, 0.5, 10), ("wheel_front_r", 0.95, 1.2, 0.5, 0.5, 10)):
        wa = P.Assembly(f"{name}_{wn}", coll)
        wheel(wa, rad, sp, I, seed=len(wheels) + 3)
        wobjs = wa.build()
        for o in wobjs:
            o.data.transform(T(x, y, z))
        wheels.append((wn, (x, y, z), wobjs))
    allparts = parts + [o for _, _, ws in wheels for o in ws]
    for i, o in enumerate(allparts):
        L.bake_masks(o, seed=40 + i, rays=14, ao_dist=0.45, base_dark=0.0, tint_var=0.05,
                     extra_occluders=[x for x in allparts if x is not o][:40])
    body_obj = L.merge_objects(name, parts, coll)
    L.shade(body_obj, 35)
    out = [body_obj]
    for wn, loc, ws in wheels:
        wobj = L.merge_objects(f"{name}_{wn}", ws, coll)
        wobj.data.transform(T(-loc[0], -loc[1], -loc[2]))
        wobj.location = loc  # начало — центр ступицы: в Godot колесо вращается вокруг своей оси X
        L.shade(wobj, 35)
        out.append(wobj)
    # Коллизия: кузов с грузом, ходовая, колёса, дышло.
    L.collision_box(coll, name + "_bed", Vector((0, -0.1, 1.3)), (1.72, 3.95, 0.7))
    L.collision_box(coll, name + "_chassis", Vector((0, 0.0, 0.62)), (1.6, 3.2, 0.36))
    for wn, (x, y, z), _ in wheels:
        rad = z
        L.collision_box(coll, f"{name}_{wn}", Vector((x, y, z)), (0.12, rad * 1.9, rad * 1.9))
    return _done(out)


def wheel_chock():
    """Клин под колесо (CANON: клинья под задними колёсами; Шифти и Учёный их убирают)."""
    name = "wheel_chock"
    coll = L.asset_collection(name)
    asm = P.Assembly(name, coll)
    bm = P.board(0.18, 0.34, 0.2, bevel=0.012)
    P.deform(bm, lambda c: Vector((c.x, c.y, (c.z + 0.1) * (0.35 + 0.65 * (c.y + 0.17) / 0.34) - 0.1)))
    asm.add(bm, "nm_wood", T(0, 0, 0.1))
    asm.add(P.tube([Vector((-0.07, -0.17, 0.06)), Vector((-0.04, -0.25, 0.03)), Vector((0.04, -0.25, 0.03)),
                    Vector((0.07, -0.17, 0.06))], 0.008, segs=5), "nm_rope")
    obj = P.finish_prop(asm.build(), seed=5, ao=0.2, merge_name=name, coll=coll)
    L.collision_box(coll, name, Vector((0, 0, 0.07)), (0.18, 0.34, 0.14))
    return _done([obj])


def wagon_debris_a():
    """Обломки у края площадки после падения повозки (CANON: «обломки у края», гл. 7–8):
    доски с рваными концами, обломок колеса, раскрытый мешок, клёпки бочки."""
    name = "wagon_debris_a"
    coll = L.asset_collection(name)
    r = random.Random(4101)
    asm = P.Assembly(name, coll)
    for k in range(7):
        ln = r.uniform(0.5, 1.4)
        bm = P.board(r.uniform(0.14, 0.2), ln, 0.035, bevel=0.005, seed=k, warp=0.01)
        # Рваный конец: смещаем вершины одного торца зубцами.
        for v in bm.verts:
            if v.co.y > ln / 2 - 0.01:
                v.co.y += r.uniform(-0.09, 0.03) + 0.04 * math.sin(v.co.x * 60)
        asm.add(bm, "nm_wood", T(r.uniform(-0.9, 0.9), r.uniform(-0.6, 0.6), 0.02 + k * 0.012)
                @ rot(r.uniform(0, 360), "Z") @ rot(r.uniform(-8, 8), "X"))
    wheel(asm, 0.62, 12, T(0.5, 0.3, 0.06) @ rot(90, "Y") @ rot(20, "X"), seed=9, broken=True)
    sack(asm, T(-0.6, 0.4, 0.0) @ rot(40, "Z"), seed=77, spilled=True)
    for k in range(5):
        st = _stave_mesh(0.74, 0.21, 0.26, 0.0, 2 * math.pi / 18 - 0.01)
        asm.add(st, "nm_wood", T(r.uniform(-1.0, 0.2), r.uniform(-0.8, 0.0), 0.05) @ rot(r.uniform(0, 360), "Z")
                @ rot(90, "X") @ rot(r.uniform(0, 360), "Z"))
    obj = P.finish_prop(asm.build(), seed=6, ao=0.3, merge_name=name, coll=coll)
    L.collision_box(coll, name, Vector((0, 0, 0.08)), (2.2, 1.6, 0.16))
    return _done([obj])


# --------------------------------------------------------------------------------------
# Груз: бочка, ящик, мешок
# --------------------------------------------------------------------------------------
def _stave_mesh(h, r_end, r_mid, a0, a1, thick=0.022, zsteps=10):
    """Клёпка бочки: изогнутая по профилю бочки доска от угла a0 до a1."""
    bm = bmesh.new()
    rows = []
    for i in range(zsteps + 1):
        z = h * i / zsteps
        rr = r_end + (r_mid - r_end) * math.sin(math.pi * z / h)
        row = []
        for a in (a0, (a0 + a1) / 2, a1):
            row.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), z)))
        for a in (a1, (a0 + a1) / 2, a0):
            row.append(bm.verts.new(((rr - thick) * math.cos(a), (rr - thick) * math.sin(a), z)))
        rows.append(row)
    n = 6
    for a_, b_ in zip(rows, rows[1:]):
        for k in range(n):
            bm.faces.new((a_[k], a_[(k + 1) % n], b_[(k + 1) % n], b_[k]))
    bm.faces.new(list(reversed(rows[0])))
    bm.faces.new(rows[-1])
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        for loop in f.loops:
            c = loop.vert.co
            loop[uv].uv = (math.atan2(c.y, c.x) * r_mid, c.z)
    return bm


def barrel(asm, m, seed=0, h=0.76, r_end=0.215, r_mid=0.265, staves=18, broken=False):
    """Бочка из клёпок с четырьмя железными обручами и врезанным днищем."""
    r = random.Random(seed)
    gap = 0.004
    span = 2 * math.pi / staves
    for k in range(staves):
        if broken and k in (2, 3, 4, 9):
            continue
        a0 = k * span + gap / r_mid
        a1 = (k + 1) * span - gap / r_mid
        st = _stave_mesh(h + r.uniform(-0.006, 0.006), r_end, r_mid, a0, a1)
        tilt = rot(r.uniform(-1.5, 1.5) if not broken else r.uniform(-6, 6), "Z")
        asm.add(st, "nm_wood", m @ tilt)
    for zz in ((0.07, 0.2, h - 0.2, h - 0.07) if not broken else (0.07, h - 0.2)):
        rr = r_end + (r_mid - r_end) * math.sin(math.pi * zz / h) + 0.002
        asm.add(P.ring_rect(rr - 0.004, rr + 0.004, 0.035, segs=36, axis="Z"), "nm_iron", m @ T(0, 0, zz))
    if not broken:
        asm.add(P.cylinder(r_end - 0.012, 0.025, segs=24), "nm_wood_dark", m @ T(0, 0, h - 0.04))
        asm.add(P.cylinder(0.025, 0.03, segs=10), "nm_wood_dark", m @ T(0.08, 0.04, h - 0.022))
    asm.add(P.cylinder(r_end - 0.012, 0.025, segs=24), "nm_wood_dark", m @ T(0, 0, 0.04))
    return asm


def crate(asm, m, seed=0, size=(0.86, 0.58, 0.52)):
    """Ящик из реек с угловыми брусками и крышкой из трёх досок."""
    r = random.Random(seed)
    sx, sy, sz = size
    for k in range(3):
        a = asm.add
        a(P.board(sx - 0.02, sy / 3 - 0.012, 0.022, bevel=0.003, seed=k), "nm_wood",
          m @ T(0, -sy / 3 + k * sy / 3, sz - 0.011) @ rot(r.uniform(-1, 1), "Z"))
        a(P.board(sx - 0.02, sy / 3 - 0.012, 0.022, bevel=0.003), "nm_wood", m @ T(0, -sy / 3 + k * sy / 3, 0.011))
    for side in (-1, 1):
        for k in range(3):
            z = 0.06 + k * (sz - 0.12) / 2
            asm.add(P.board(sx - 0.02, 0.02, 0.1, bevel=0.003, seed=k + 5), "nm_wood", m @ T(0, side * (sy / 2 - 0.01), z + 0.02))
            asm.add(P.board(0.02, sy - 0.06, 0.1, bevel=0.003, seed=k + 9), "nm_wood", m @ T(side * (sx / 2 - 0.01), 0, z + 0.02))
        for sy2 in (-1, 1):
            asm.add(P.board(0.045, 0.045, sz, bevel=0.005), "nm_wood_dark",
                    m @ T(side * (sx / 2 - 0.035), sy2 * (sy / 2 - 0.035), sz / 2))
    return asm


def sack(asm, m, seed=0, spilled=False):
    """Мешок с едой, лежащий: тело-«подушка», складки сходятся к перевязанной горловине,
    за перевязкой — вихор ткани. spilled — полупустой, осевший."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=28, v_segments=18, radius=1.0)
    ln, wd, ht = (0.4, 0.62, 0.26) if not spilled else (0.46, 0.72, 0.13)
    off = Vector((seed * 0.3, seed * 0.7, 0.1))

    def shape(c):
        sq = lambda v, e: math.copysign(abs(v) ** e, v)  # noqa: E731
        x, y, z = sq(c.x, 0.7) * wd / 2, c.y * ln, sq(c.z, 0.75) * ht
        if z < 0:
            z *= 0.3  # дно лежит плоско
        t = max(0.0, (c.y - 0.45) / 0.55)
        if t > 0:
            pinch = 1 - 0.85 * min(1.0, t / 0.6) + 0.45 * max(0.0, (t - 0.75) / 0.25)
            ang = math.atan2(c.z, c.x)
            fold = 1 + 0.12 * math.sin(ang * 9) * min(1.0, t * 1.5)
            x *= pinch * fold
            z = z * pinch * fold + 0.05 * t * ht / 0.26
            y += 0.06 * t
        n = L.noise.noise(Vector((c.x * 2.2, c.y * 2.2, c.z * 2.2)) + off)
        n2 = L.noise.noise(Vector((c.x * 6.0, c.y * 3.0, c.z * 6.0)) + off * 2)
        z += (0.022 * n + 0.008 * n2) * (1 if z > 0 else 0.2)
        x += 0.016 * n
        return Vector((x, y, z + ht * 0.3))

    P.deform(bm, shape)
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        for loop in f.loops:
            c = loop.vert.co
            loop[uv].uv = (c.x + c.z, c.y)
    asm.add(bm, "nm_linen", m)
    tie_y = ln * 0.84 + 0.035
    tie = [Vector((0.045 * math.cos(t), tie_y, 0.05 + ht * 0.3 + 0.03 * math.sin(t))) for t in
           [k * 2 * math.pi / 12 for k in range(12)]]
    asm.add(P.tube(tie, 0.007, segs=5, closed=True), "nm_rope", m)
    return asm


def barrel_water_a():
    name = "barrel_water_a"
    coll = L.asset_collection(name)
    asm = P.Assembly(name, coll)
    barrel(asm, I, seed=51)
    obj = P.finish_prop(asm.build(), seed=7, ao=0.25, merge_name=name, coll=coll)
    L.collision_convex(obj, max_verts=32)
    return _done([obj])


def barrel_broken_b():
    name = "barrel_broken_b"
    coll = L.asset_collection(name)
    asm = P.Assembly(name, coll)
    barrel(asm, T(0, 0, 0.26) @ rot(86, "X"), seed=52, broken=True)
    obj = P.finish_prop(asm.build(), seed=8, ao=0.25, merge_name=name, coll=coll)
    L.collision_convex(obj, max_verts=32)
    return _done([obj])


def crate_supplies_a():
    name = "crate_supplies_a"
    coll = L.asset_collection(name)
    asm = P.Assembly(name, coll)
    crate(asm, I, seed=61)
    obj = P.finish_prop(asm.build(), seed=9, ao=0.25, merge_name=name, coll=coll)
    L.collision_box(coll, name, Vector((0, 0, 0.26)), (0.86, 0.58, 0.52))
    return _done([obj])


def sack_grain_a():
    name = "sack_grain_a"
    coll = L.asset_collection(name)
    asm = P.Assembly(name, coll)
    sack(asm, I, seed=71)
    obj = P.finish_prop(asm.build(), seed=10, ao=0.2, merge_name=name, coll=coll)
    L.collision_convex(obj, max_verts=24)
    return _done([obj])


# --------------------------------------------------------------------------------------
# Цепь, кандалы, ключ
# --------------------------------------------------------------------------------------
LINK = (0.11, 0.066, 0.0095)  # «крупные звенья» (бриф тропы), кованое железо


def chain_main_taut():
    """Отрезок главной цепи 2 м, натянутый (марш)."""
    name = "chain_main_taut"
    coll = L.asset_collection(name)
    asm = P.Assembly(name, coll)
    P.chain_along(asm, lambda t: Vector((0, -1.0 + 2.0 * t, 0.9 + 0.04 * math.sin(math.pi * t))), 40, link=LINK, seed=1)
    obj = P.finish_prop(asm.build(), seed=11, ao=0.1, ground=False, merge_name=name, coll=coll, sharp=60)
    return _done([obj])


def chain_main_slack():
    """Отрезок главной цепи 3 м, провисший и лёгший на снег (стоянка, после разрыва)."""
    name = "chain_main_slack"
    coll = L.asset_collection(name)
    asm = P.Assembly(name, coll)

    def path(t):
        x = 0.35 * math.sin(t * math.pi * 1.5)
        y = -1.5 + 3.0 * t
        z = 0.035 + max(0.0, 0.5 * (1 - t * 4.0)) ** 2
        return Vector((x, y, z))

    P.chain_along(asm, path, 60, link=LINK, seed=2)
    obj = P.finish_prop(asm.build(), seed=12, ao=0.12, merge_name=name, coll=coll, sharp=60)
    return _done([obj])


def shackles_pair():
    """Кандалы: два железных браслета на шарнире с замковой проушиной, короткая цепь между
    ними (CANON: короткая цепь, годная как удавка) и звено к главной цепи."""
    name = "shackles_pair"
    coll = L.asset_collection(name)
    asm = P.Assembly(name, coll)
    for sx in (-1, 1):
        m = T(sx * 0.17, 0, 0.05) @ rot(90, "Y")
        asm.add(P.ring_rect(0.042, 0.054, 0.05, segs=24, axis="Z"), "nm_iron", m)
        asm.add(P.board(0.03, 0.03, 0.05, bevel=0.004), "nm_iron", m @ T(0, 0.058, 0))
        asm.add(P.board(0.026, 0.024, 0.04, bevel=0.004), "nm_iron", m @ T(0, -0.062, 0))
    P.chain_along(asm, lambda t: Vector((-0.11 + 0.22 * t, 0.0, 0.05 - 0.05 * math.sin(math.pi * t) + 0.01)), 4,
                  link=(0.07, 0.042, 0.007), seed=3)
    P.chain_along(asm, lambda t: Vector((0.0, 0.0 + 0.15 * t, 0.012)), 2, link=(0.08, 0.05, 0.008), seed=4)
    obj = P.finish_prop(asm.build(), seed=13, ao=0.08, merge_name=name, coll=coll, sharp=60)
    return _done([obj])


def shackle_key():
    """Ключ от кандалов (CANON: Герой бросает ключ Санни)."""
    name = "shackle_key"
    coll = L.asset_collection(name)
    asm = P.Assembly(name, coll)
    asm.add(P.cylinder(0.005, 0.1, segs=8, axis="Y"), "nm_iron", T(0, 0.02, 0.006))
    asm.add(P.ring_rect(0.011, 0.018, 0.006, segs=16, axis="Z"), "nm_iron", T(0, -0.045, 0.003))
    asm.add(P.board(0.004, 0.022, 0.018, bevel=0.001), "nm_iron", T(0.009, 0.06, 0.006))
    obj = P.finish_prop(asm.build(), seed=14, ao=0.03, merge_name=name, coll=coll, sharp=60)
    return _done([obj])


# --------------------------------------------------------------------------------------
# Костёр, дрова, фляга, хлеб
# --------------------------------------------------------------------------------------
def _log(asm, length, radius, m, mat="nm_bark", seed=0, charred_end=None):
    r = random.Random(seed)
    path = [Vector((0, -length / 2 + length * t, 0.012 * math.sin(t * 3 + seed))) for t in [i / 6 for i in range(7)]]
    asm.add(P.tube(path, radius, segs=9, radius_fn=lambda t: 1.0 - 0.15 * t + 0.05 * r.random()), mat, m)
    if charred_end is not None:
        asm.add(P.cylinder(radius * 0.97, 0.012, segs=9, axis="Y"), charred_end, m @ T(0, length / 2, 0))


def _log_between(asm, p0, p1, radius, mat, seed=0, glow=False):
    """Бревно от p0 к p1 с лёгким изгибом; glow — тлеющий торец у p1 (угли)."""
    r = random.Random(seed)
    d = p1 - p0
    side = d.cross(Vector((0, 0, 1))).normalized() * 0.015 * r.uniform(-1, 1)
    path = [p0.lerp(p1, t) + side * math.sin(math.pi * t) for t in [i / 6 for i in range(7)]]
    asm.add(P.tube(path, radius, segs=9, radius_fn=lambda t: 1.0 - 0.25 * t), mat)
    if glow:
        cap = P.cylinder(radius * 0.78, 0.014, segs=9)
        q = d.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
        asm.add(cap, "nm_ember", Matrix.Translation(p1) @ q)


def campfire_large():
    """Большой костёр в центре стоянки (CANON, гл. 2–3): каменное кольцо, прогоревшие брёвна
    шалашом, угли и зола. Пламя и дым — эффекты Godot, в меш не входят."""
    name = "campfire_large"
    coll = L.asset_collection(name)
    r = random.Random(4201)
    asm = P.Assembly(name, coll)
    for k in range(11):
        a = 2 * math.pi * k / 11 + r.uniform(-0.12, 0.12)
        s = r.uniform(0.2, 0.32)
        bm = L.hull_chunk(4300 + k, (s * 1.3, s, s * 0.75), npts=14, cuts=4)
        asm.add(bm, "nm_rock", T(0.8 * math.cos(a), 0.8 * math.sin(a), s * 0.22) @ rot(math.degrees(a), "Z"))
    ash = P.lathe([(0.0, 0.0), (0.72, 0.0), (0.6, 0.03), (0.3, 0.05), (0.0, 0.055)], segs=24, close_top=False)
    asm.add(ash, "nm_ash")
    # Угли: светящиеся куски вперемешку с обугленными (пламя — эффект в Godot).
    for k in range(26):
        s = r.uniform(0.035, 0.075)
        rr = 0.38 * math.sqrt(r.random())
        a = r.uniform(0, 2 * math.pi)
        mat = "nm_ember" if r.random() < 0.55 else "nm_charcoal"
        bm = L.hull_chunk(4400 + k, (s * 1.5, s, s * 0.7), npts=10, cuts=3)
        asm.add(bm, mat, T(rr * math.cos(a), rr * math.sin(a), 0.05 + 0.03 * (1 - rr / 0.4)) @ rot(r.uniform(0, 360), "Z"))
    # Прогоревшие брёвна лучами: внутренние концы приподняты над углями и тлеют, наружные
    # лежат на золе; два бревна ещё опираются друг на друга шалашом.
    for k in range(7):
        a = 2 * math.pi * k / 7 + r.uniform(-0.2, 0.2)
        inner = Vector((0.1 * math.cos(a), 0.1 * math.sin(a), r.uniform(0.14, 0.26)))
        outer = Vector((r.uniform(0.62, 0.8) * math.cos(a), r.uniform(0.62, 0.8) * math.sin(a), 0.06))
        if k in (2, 5):
            inner.z = 0.55
            outer *= 0.75
            outer.z = 0.05
        _log_between(asm, outer, inner, r.uniform(0.045, 0.065), "nm_charcoal", seed=k, glow=True)
    for k, (x, y, rz) in enumerate(((1.25, 0.3, 15), (1.3, -0.15, 5), (1.2, 0.05, -20))):
        _log(asm, r.uniform(0.8, 1.0), 0.06, T(x, y, 0.06 + 0.1 * (k == 2)) @ rot(rz, "Z"), seed=10 + k,
             charred_end="nm_wood")
    obj = P.finish_prop(asm.build(), seed=15, ao=0.35, merge_name=name, coll=coll)
    L.collision_box(coll, name, Vector((0, 0, 0.12)), (1.9, 1.9, 0.24))
    return _done([obj])


def firewood_bundle():
    """Вязанка дров (CANON: Учёный собирает топливо; Герой выбрасывает лишние дрова)."""
    name = "firewood_bundle"
    coll = L.asset_collection(name)
    r = random.Random(4501)
    asm = P.Assembly(name, coll)
    for k in range(9):
        a = r.uniform(0, 2 * math.pi)
        rr = 0.09 * math.sqrt(r.random())
        ln = r.uniform(0.75, 0.95)
        _log(asm, ln, r.uniform(0.028, 0.045), T(rr * math.cos(a), r.uniform(-0.05, 0.05), 0.1 + rr * math.sin(a))
             @ rot(r.uniform(-4, 4), "Z"), seed=k, charred_end="nm_wood")
    for y in (-0.25, 0.25):
        loop = [Vector((0.135 * math.cos(t), y, 0.1 + 0.125 * math.sin(t))) for t in [k * 2 * math.pi / 14 for k in range(14)]]
        asm.add(P.tube(loop, 0.008, segs=5, closed=True), "nm_rope")
    obj = P.finish_prop(asm.build(), seed=16, ao=0.15, merge_name=name, coll=coll)
    L.collision_box(coll, name, Vector((0, 0, 0.1)), (0.3, 1.0, 0.24))
    return _done([obj])


def water_flask():
    """Кожаная фляга солдата с деревянной пробкой и ремённой петлёй (CANON: фляги стражи)."""
    name = "water_flask"
    coll = L.asset_collection(name)
    asm = P.Assembly(name, coll)
    body = P.lathe([(0.0, 0.0), (0.085, 0.004), (0.11, 0.05), (0.112, 0.15), (0.09, 0.22), (0.035, 0.26),
                    (0.024, 0.275), (0.024, 0.3)], segs=20, close_top=True)
    P.deform(body, lambda c: Vector((c.x * 0.55, c.y, c.z)))
    asm.add(body, "nm_leather")
    asm.add(P.cylinder(0.02, 0.04, segs=10, radius2=0.017), "nm_wood_dark", T(0, 0, 0.31))
    strap = [Vector((0.0, 0.03 * math.cos(t) + 0.0, 0.28 + 0.12 * math.sin(t) * 0.6)) for t in
             [k * math.pi / 8 for k in range(9)]]
    asm.add(P.tube(strap, 0.006, segs=5), "nm_leather")
    obj = P.finish_prop(asm.build(), seed=17, ao=0.05, merge_name=name, coll=coll)
    return _done([obj])


def bread_stale():
    """Кусок твёрдого заплесневелого хлеба (CANON, гл. 2: паёк рабов)."""
    name = "bread_stale"
    coll = L.asset_collection(name)
    bm = L.hull_chunk(4601, (0.12, 0.09, 0.055), npts=40, cuts=2, cut_depth=(0.85, 0.95))
    obj = L.rock_object(name, [(bm, I)], coll, mat="nm_bread", voxel=0.004, smooth_iter=6, seed=4601, size=0.1,
                        detail=dict(large=0.04, medium=0.03, fine=0.01, crack_depth=0.0), target_tris=600, sink=0.0)
    L.bake_masks(obj, seed=4601, rays=10, ao_dist=0.05, base_dark=0.0, tint_var=0.0,
                 dirt_fn=lambda co: 0.55 if L.noise.noise(co * 60) > 0.35 else 1.0)  # пятна плесени
    L.shade(obj, 60)
    return _done([obj])


# --------------------------------------------------------------------------------------
# Снаряжение стражи
# --------------------------------------------------------------------------------------
def _blade(length, width, thick, tip=0.25, segs=12, break_at=None, seed=0):
    """Обоюдоострый клинок с ромбическим сечением; break_at — доля длины, где клинок сломан."""
    r = random.Random(seed)
    bm = bmesh.new()
    rows = []
    n = segs
    end = break_at if break_at else 1.0
    for i in range(n + 1):
        t = end * i / n
        w = width * (1 - 0.15 * t)
        if t > 1 - tip:
            w *= max(0.02, (1 - t) / tip) ** 0.8
        z = length * t
        jag = (r.uniform(-0.01, 0.01) if (break_at and i == n) else 0.0)
        rows.append([bm.verts.new((w / 2, 0, z + jag)), bm.verts.new((0, thick / 2, z)),
                     bm.verts.new((-w / 2, 0, z - jag)), bm.verts.new((0, -thick / 2, z))])
    for a, b in zip(rows, rows[1:]):
        for k in range(4):
            bm.faces.new((a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]))
    bm.faces.new(list(reversed(rows[0])))
    bm.faces.new(rows[-1])
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        for loop in f.loops:
            loop[uv].uv = (loop.vert.co.x * 4, loop.vert.co.z * 4)
    return bm


def _sword(asm, m, break_at=None, seed=0):
    asm.add(_blade(0.56, 0.048, 0.009, tip=0.18, break_at=break_at, seed=seed), "nm_iron", m @ T(0, 0, 0.13))
    asm.add(P.board(0.13, 0.026, 0.022, bevel=0.004), "nm_iron", m @ T(0, 0, 0.12))
    asm.add(P.cylinder(0.014, 0.11, segs=10), "nm_leather", m @ T(0, 0, 0.055))
    asm.add(P.lathe([(0.0, -0.03), (0.02, -0.025), (0.024, -0.012), (0.018, 0.0), (0.0, 0.002)], segs=12), "nm_iron", m)


def spear_soldier():
    """Копьё стражника (CANON: копьё Героя): древко ~2 м, листовидный наконечник на втулке."""
    name = "spear_soldier"
    coll = L.asset_collection(name)
    asm = P.Assembly(name, coll)
    m = T(0, 0, 0.022) @ rot(-90, "X")  # лежит на земле, остриём вперёд (+Y)
    asm.add(P.cylinder(0.016, 2.0, segs=10, radius2=0.015), "nm_wood", m @ T(0, 0, 1.0))
    asm.add(P.cylinder(0.019, 0.12, segs=10, radius2=0.016), "nm_iron", m @ T(0, 0, 2.03))
    asm.add(_blade(0.28, 0.055, 0.012, tip=0.45), "nm_iron", m @ T(0, 0, 2.08))
    asm.add(P.cylinder(0.018, 0.06, segs=10), "nm_iron", m @ T(0, 0, 0.0))
    obj = P.finish_prop(asm.build(), seed=18, ao=0.05, merge_name=name, coll=coll, sharp=40)
    return _done([obj])


def short_sword():
    """Короткий меч (CANON: у Героя; трофей Санни, брошенный на подъёме, гл. 9)."""
    name = "short_sword"
    coll = L.asset_collection(name)
    asm = P.Assembly(name, coll)
    _sword(asm, T(0, 0, 0.012) @ rot(-90, "X"))
    obj = P.finish_prop(asm.build(), seed=19, ao=0.04, merge_name=name, coll=coll, sharp=40)
    return _done([obj])


def sword_broken():
    """Сломанный меч ветерана (CANON, гл. 8: Санни перерезает им горло ветерану) + обломок клинка."""
    name = "sword_broken"
    coll = L.asset_collection(name)
    asm = P.Assembly(name, coll)
    _sword(asm, T(0, 0, 0.012) @ rot(-90, "X"), break_at=0.42, seed=3)
    tip = _blade(0.56, 0.048, 0.009, tip=0.18, seed=4)
    bmesh.ops.delete(tip, geom=[v for v in tip.verts if v.co.z < 0.56 * 0.45], context="VERTS")
    bmesh.ops.holes_fill(tip, edges=[e for e in tip.edges if e.is_boundary], sides=0)
    asm.add(tip, "nm_iron", T(0.12, 0.25, 0.006) @ rot(-90, "X") @ rot(25, "Y") @ T(0, 0, -0.26))
    obj = P.finish_prop(asm.build(), seed=20, ao=0.04, merge_name=name, coll=coll, sharp=40)
    return _done([obj])


def whip_coiled():
    """Свёрнутый кнут ветерана (CANON, гл. 2): деревянная рукоять в коже, плетёный ремень кольцами."""
    name = "whip_coiled"
    coll = L.asset_collection(name)
    asm = P.Assembly(name, coll)
    asm.add(P.cylinder(0.016, 0.34, segs=10, radius2=0.013, axis="X"), "nm_leather", T(-0.15, -0.16, 0.017))
    path = []
    for k in range(140):
        t = k / 139
        a = -math.pi / 2 + t * 2 * math.pi * 3.2
        rr = 0.16 - 0.03 * t
        path.append(Vector((rr * math.cos(a) + 0.03, rr * math.sin(a), 0.01 + 0.009 * (1 + math.sin(a * 0.5 + 1)) + 0.006 * t)))
    asm.add(P.tube([Vector((0.02, -0.16, 0.016))] + path, 0.008, segs=6, radius_fn=lambda t: 1.0 - 0.6 * t), "nm_leather")
    obj = P.finish_prop(asm.build(), seed=21, ao=0.05, merge_name=name, coll=coll, sharp=60)
    return _done([obj])


# --------------------------------------------------------------------------------------
# Bloodbane (flora/): CANON — ярко-красные ягоды растут из снега группами на границе
# мостовой и острых камней; форма куста не описана → ART-DIRECTION: низкий голый колючий
# кустарник с тёмными ветками, ягоды гроздьями, без листьев (высокогорная зима).
# --------------------------------------------------------------------------------------
def _branch(asm, base, direction, length, radius, depth, r, berries, berry_fn):
    pts = [base]
    d = direction.normalized()
    seg = length / 6
    p = base.copy()
    for i in range(6):
        d = (d + Vector((r.uniform(-0.35, 0.35), r.uniform(-0.35, 0.35), r.uniform(-0.1, 0.25)))).normalized()
        p = p + d * seg
        pts.append(p.copy())
    asm.add(P.tube(pts, radius, segs=5, radius_fn=lambda t: 1.0 - 0.8 * t), "nm_bark")
    if depth > 0:
        for _ in range(r.randint(2, 3)):
            i = r.randint(2, 5)
            nd = (pts[i + 1] - pts[i]).normalized() + Vector((r.uniform(-0.8, 0.8), r.uniform(-0.8, 0.8), r.uniform(0, 0.5)))
            _branch(asm, pts[i], nd, length * r.uniform(0.4, 0.6), radius * 0.55, depth - 1, r, berries, berry_fn)
    else:
        berry_fn(asm, pts[-1], r)


def _berries(asm, at, r):
    for _ in range(r.randint(3, 7)):
        bm = bmesh.new()
        rad = r.uniform(0.0055, 0.0085)
        bmesh.ops.create_uvsphere(bm, u_segments=6, v_segments=5, radius=rad)
        uv = bm.loops.layers.uv.verify()
        del uv
        off = Vector((r.uniform(-0.025, 0.025), r.uniform(-0.025, 0.025), r.uniform(-0.03, 0.005)))
        asm.add(bm, "nm_berry", T(*(at + off)))


def _bloodbane(name, seed, stems, height):
    coll = L.asset_collection(name)
    r = random.Random(seed)
    asm = P.Assembly(name, coll)
    for k in range(stems):
        a = 2 * math.pi * k / stems + r.uniform(-0.4, 0.4)
        d = Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, 1.0))
        _branch(asm, Vector((math.cos(a) * 0.03, math.sin(a) * 0.03, -0.02)), d, height * r.uniform(0.7, 1.0),
                0.009, 2, r, None, _berries)
    sbm = bmesh.new()
    L.snow_patch(sbm, 0.0, 0.0, 0.32, 0.26, 0.07, z0=-0.02, seed=seed)
    asm.add(sbm, "nm_snow")
    objs = asm.build()
    for o in objs:
        L.bake_masks(o, seed=seed, rays=10, ao_dist=0.15, base_dark=0.0, tint_var=0.03,
                     extra_occluders=[x for x in objs if x is not o])
    obj = L.merge_objects(name, objs, coll)
    L.shade(obj, 50)
    return _done([obj], "flora")


def bloodbane_bush_a():
    return _bloodbane("bloodbane_bush_a", 4701, 5, 0.4)


def bloodbane_bush_b():
    return _bloodbane("bloodbane_bush_b", 4702, 3, 0.28)


def bloodbane_bush_c():
    return _bloodbane("bloodbane_bush_c", 4703, 7, 0.5)


GROUPS = {
    "wagon": [wagon_cargo, wheel_chock, wagon_debris_a],
    "cargo": [barrel_water_a, barrel_broken_b, crate_supplies_a, sack_grain_a],
    "chains": [chain_main_taut, chain_main_slack, shackles_pair, shackle_key],
    "camp": [campfire_large, firewood_bundle, water_flask, bread_stale],
    "arms": [spear_soldier, short_sword, sword_broken, whip_coiled],
    "bloodbane": [bloodbane_bush_a, bloodbane_bush_b, bloodbane_bush_c],
}

CAMERA = {  # направление и объектив для превью группы
    "wagon": ((-1.0, -0.8, 0.5), 45), "cargo": ((-0.6, -1.0, 0.55), 50), "chains": ((-0.4, -1.0, 0.9), 60),
    "camp": ((-0.5, -1.0, 0.65), 50), "arms": ((-0.2, -1.0, 1.2), 50), "bloodbane": ((-0.5, -1.0, 0.45), 70),
}


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opts = {"only": list(GROUPS), "test": None, "export": True}
    i = 0
    while i < len(argv):
        if argv[i] == "--only":
            opts["only"] = argv[i + 1].split(",")
            i += 1
        elif argv[i] == "--test":
            opts["test"] = argv[i + 1]
            i += 1
        elif argv[i] == "--no-export":
            opts["export"] = False
        i += 1
    return opts


def _lineup(colls, ox, spacing=0.4):
    objs = []
    x = ox
    for c in colls:
        pts = [p for o in c.all_objects if o.type == "MESH" and not o.hide_render for p in L.world_points(o)]
        x0, x1 = min(p.x for p in pts), max(p.x for p in pts)
        inst = bpy.data.objects.new("inst_" + c.name, None)
        inst.instance_type = "COLLECTION"
        inst.instance_collection = c
        L.preview_collection().objects.link(inst)
        inst.location = (x - x0, 0, 0)
        objs.append(inst)
        x += (x1 - x0) + spacing
    return objs, x


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
            tris = sum(L.tri_count(o) for o in coll.all_objects if o.type == "MESH" and not o.name.endswith("colonly"))
            print(f"BUILT {coll.name}: tris={tris} t={time.time() - t0:.1f}s")
    if opts["export"] and not opts["test"]:
        for colls in built.values():
            for coll in colls:
                L.export_collection(coll, OUT[FOLDER.get(coll.name, "caravan")] / f"{coll.name}.glb")
    L.set_assets_visible(False)
    gnd = L.ground(size=60.0, z=0.0)
    L.setup_render(res=(1600, 900), samples=48 if opts["test"] else 128, sun_elev=26.0, sun_az=-40.0)
    out_dir = Path(opts["test"]).parent if opts["test"] else L.PREVIEW_DIR
    prefix = Path(opts["test"]).stem + "_" if opts["test"] else "caravan_"
    ox = 0.0
    jobs = []
    for group, colls in built.items():
        objs, x = _lineup(colls, ox, spacing=0.5 if group != "wagon" else 1.2)
        man = L.mannequin(location=(x + 0.3, 0.6, 0), name=f"ScaleRef_{group}")
        jobs.append((group, objs, man))
        ox = x + 30.0
    for o in L.preview_collection().objects:
        o.hide_render = False
    all_prev = list(L.preview_collection().objects)
    for group, objs, man in jobs:
        for o in all_prev:
            o.hide_render = o not in objs and o is not man and o.type in ("EMPTY", "MESH") and o is not gnd
        pts = [p for o in objs for p in L.world_points(o)]
        gnd.location.x = (min(p.x for p in pts) + max(p.x for p in pts)) / 2
        direction, lens = CAMERA[group]
        frame = objs + ([man] if group in ("wagon", "camp", "cargo") else [])
        L.frame_camera(frame, direction=direction, lens=lens, margin=1.06)
        L.render(str(out_dir / f"{prefix}{group}.jpg"))
        if group == "wagon" and not opts["test"] or group == "wagon":
            cam = bpy.data.objects["PreviewCam"]
            L.frame_camera([objs[0]], direction=(0.9, -0.5, 0.35), lens=35, margin=1.0)
            L.render(str(out_dir / f"{prefix}{group}_hero.jpg"))
    for o in all_prev:
        o.hide_render = False
    if not opts["test"]:
        L.save_blend(SRC / "caravan_kit.blend")
    print("DONE", time.time() - t0)


main()

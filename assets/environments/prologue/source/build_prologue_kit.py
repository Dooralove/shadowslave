"""Партия 5 — пролог: изолятор (L03), лобби участка (L02), искусственные деревья и фонарь парка (L01).

Запуск из корня проекта (Blender 5.1, в фоне):
    blender -b --factory-startup --python assets/environments/prologue/source/build_prologue_kit.py -- [опции]
Опции: --only <группы через запятую>, --test <файл.jpg> (превью без экспорта и сохранения .blend).
Результат: `source/prologue_kit.blend`, `cell/*.glb`, `lobby/*.glb`, `park/props/tree_*|lamp_*.glb`,
превью `docs/art/previews/prologue/*.jpg`.

Источники требований:
- изолятор — бриф `docs/design/level_brief_quarantine_cell.md` (габариты 3,6 × 4,4 × 2,45 м, оси §3:
  начало — центр пола, X — ширина, Y — длина, дверь на Y = −2,2, Z вверх; перечень M-01…M-20);
  канон гл. 1 (`docs/story/canon_research.md`, E5): толстые бронестены, массивная дверь-сейф, громоздкое
  кресло — «нечто среднее между больничной койкой и пыточным устройством»;
- лобби — канон гл. 1 (E4): армированные бронеплиты на стенах, плохо скрытые турельные гнёзда в потолке,
  терминал с кнопкой тревоги; габариты — по CSG `scenes/slice/locations/station_lobby.tscn`;
- парк — бриф S3 (`docs/production/s3_park_brief.md`): нарочито правильные искусственные деревья в кадках,
  холодная зелень, фонарь; места и размеры — блок-аут `park/source/build_park_blockout.py`.

Общий код — `nightmare/source/nm_lib.py`, `nm_props.py`; материалы — `pr_materials.py` (регистрируются в nm_lib).
Твёрдые поверхности: каждая деталь — свой объект с фаской (Bevel, harden normals), потом детали ассета
сливаются в один меш (join сохраняет нормали фасок). Стенные модули смотрят лицом в −Y, тело — в +Y.
"""

import importlib
import math
import random
import sys
import time
from pathlib import Path

SRC = Path(__file__).resolve().parent
ROOT = SRC.parents[3]
NM_SRC = ROOT / "assets" / "environments" / "nightmare" / "source"
for p in (str(SRC), str(NM_SRC)):
    if p not in sys.path:
        sys.path.insert(0, p)

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import nm_lib as L  # noqa: E402

importlib.reload(L)
import nm_props as P  # noqa: E402

importlib.reload(P)
import pr_materials as PM  # noqa: E402

importlib.reload(PM)

I = Matrix.Identity(4)
PR_DIR = ROOT / "assets" / "environments" / "prologue"
L.register_materials(PM.MATERIALS, PM.TEXSETS, PR_DIR / "materials" / "textures")
PARK_PROPS = ROOT / "assets" / "environments" / "park" / "props"
PREVIEW_DIR = ROOT / "docs" / "art" / "previews" / "prologue"

ROOM_W, ROOM_L, ROOM_H, WALL_T = 3.6, 4.4, 2.45, 0.25


def T(x, y, z):
    return Matrix.Translation((x, y, z))


def rot(deg, axis):
    return Matrix.Rotation(math.radians(deg), 4, axis)


def B(x0, x1, y0, y1, z0, z1, m=I):
    """Брусок по границам (в осях детали), затем матрица."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bm.transform(m @ T((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
                 @ Matrix.Diagonal((x1 - x0, y1 - y0, z1 - z0, 1.0)))
    return bm


def C(r, h, c=(0, 0, 0), axis="Z", segs=16, r2=None, m=I):
    bm = P.cylinder(r, h, segs, axis, radius2=r2)
    bm.transform(m @ T(*c))
    return bm


def join_bm(parts):
    return L.join_bmeshes([(bm, I) for bm in parts])


def bolts(points, axis="Y", r=0.012, h=0.006, segs=6, m=I):
    """Головки болтов (шестигранник) в точках; ось — нормаль поверхности."""
    return join_bm([C(r, h, p, axis, segs, m=m) for p in points])


def ribbon(pts, wdir, w, t):
    """Лента прямоугольного сечения по пути (ремни): wdir — направление ширины ленты."""
    bm = bmesh.new()
    wd = Vector(wdir).normalized()
    n = len(pts)
    rings = []
    for i, p in enumerate(pts):
        tan = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        nrm = tan.cross(wd).normalized()
        rings.append([bm.verts.new(p + wd * sx * w / 2 + nrm * sz * t / 2)
                      for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
    for a, b in zip(rings, rings[1:]):
        for k in range(4):
            bm.faces.new((a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return bm


def arc_shell(r, t, a0, a1, y0, y1, zc=0.0, segs=18):
    """Оболочка-дуга вокруг оси Y (полукожух): угол от +Z к +X, толщина t наружу."""
    bm = bmesh.new()
    angs = [math.radians(a0 + (a1 - a0) * i / segs) for i in range(segs + 1)]
    grid = {}
    for ri, rad in enumerate((r, r + t)):
        for yi, y in enumerate((y0, y1)):
            grid[ri, yi] = [bm.verts.new((rad * math.sin(a), y, zc + rad * math.cos(a))) for a in angs]
    for i in range(segs):
        bm.faces.new((grid[1, 0][i], grid[1, 0][i + 1], grid[1, 1][i + 1], grid[1, 1][i]))  # наружная
        bm.faces.new((grid[0, 1][i], grid[0, 1][i + 1], grid[0, 0][i + 1], grid[0, 0][i]))  # внутренняя
        bm.faces.new((grid[0, 0][i], grid[0, 0][i + 1], grid[1, 0][i + 1], grid[1, 0][i]))  # торец y0
        bm.faces.new((grid[1, 1][i], grid[1, 1][i + 1], grid[0, 1][i + 1], grid[0, 1][i]))  # торец y1
    for k in (0, segs):
        bm.faces.new((grid[0, 0][k], grid[1, 0][k], grid[1, 1][k], grid[0, 1][k]))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return bm


def screen_quad(w, h, m):
    """Плоскость экрана в XZ (лицом в −Y) с UV 0..1 — картинка интерфейса во всю площадь."""
    bm = bmesh.new()
    vs = [bm.verts.new((x * w / 2, 0.0, z * h / 2)) for x, z in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    f = bm.faces.new(vs)
    f.normal_update()
    if f.normal.y > 0:
        f.normal_flip()
    uv = bm.loops.layers.uv.verify()
    for loop in f.loops:
        c = loop.vert.co
        loop[uv].uv = (c.x / w + 0.5, c.z / h + 0.5)
    bm.transform(m)
    return bm


class HS:
    """Ассет твёрдых поверхностей: детали с фасками → один меш; отдельные узлы (индикаторы) — рядом."""

    def __init__(self, name, coll=None, mirror_y=False):
        self.name = name
        self.coll = coll or L.asset_collection(name)
        self.objs = []
        self.keep = []
        self.mirror_y = mirror_y  # зеркальный вариант по Y (дверь, открывающаяся в другую сторону)

    def add(self, bm, mat, bevel=0.0, segs=2, angle=35.0, uv=True, sharp=30.0, keep=None, flat=False):
        if self.mirror_y:
            bm.transform(Matrix.Scale(-1.0, 4, (0.0, 1.0, 0.0)))
            bmesh.ops.reverse_faces(bm, faces=list(bm.faces))
        obj = L.object_from_bmesh(keep or f"{self.name}_{len(self.objs)}", bm, self.coll, mat)
        if uv:
            L.uv_box(obj, 1.0)
        if flat:
            for poly in obj.data.polygons:
                poly.use_smooth = False
        elif bevel > 0:
            for poly in obj.data.polygons:
                poly.use_smooth = True
            mod = obj.modifiers.new("Bevel", "BEVEL")
            mod.width = bevel
            mod.segments = segs
            mod.limit_method = "ANGLE"
            mod.angle_limit = math.radians(angle)
            mod.harden_normals = True
            L.apply_modifiers(obj)
        else:
            L.shade(obj, sharp)
        (self.keep if keep else self.objs).append(obj)
        return obj

    def finish(self, ao=0.12, rays=14, ground=True, base_dark=0.12, seed=0):
        main = self.objs[0]
        if len(self.objs) > 1:
            with bpy.context.temp_override(active_object=main, selected_editable_objects=self.objs, object=main):
                bpy.ops.object.join()
        main.name = self.name
        main.data.name = self.name
        L.bake_masks(main, seed=seed, rays=rays, ao_dist=ao, ground=ground, base_dark=base_dark, tint_var=0.03,
                     extra_occluders=self.keep)
        for k in self.keep:
            L.plain_masks(k)
        main.data.validate(clean_customdata=False)
        return main


# ======================================================================================
# Изолятор (L03): модули помещения
# ======================================================================================
def _plate_bolts(x0, x1, z0, z1, y, inset=0.06, r=0.011):
    pts = [(x, y, z) for x in (x0 + inset, x1 - inset) for z in (z0 + inset, z1 - inset)]
    return bolts(pts, "Y", r=r, h=0.006)


def _wall_base(hs, half, lower_top=1.185, upper=(1.215, 2.33), upper_mat="pr_wall", opening=None):
    """Стенной модуль: несущая плита, цоколь, нижняя и верхняя бронепанели со швом, карниз, крепёж.
    opening = (x0, x1, z0, z1) — проём (окно): несущая плита собирается рамкой вокруг него."""
    if opening:
        ox0, ox1, oz0, oz1 = opening
        for b in (B(-half, half, 0.04, WALL_T, 0, oz0), B(-half, half, 0.04, WALL_T, oz1, ROOM_H),
                  B(-half, ox0, 0.04, WALL_T, oz0, oz1), B(ox1, half, 0.04, WALL_T, oz0, oz1)):
            hs.add(b, "pr_wall")
    else:
        hs.add(B(-half, half, 0.04, WALL_T, 0, ROOM_H), "pr_wall")
    hs.add(B(-half, half, 0.01, 0.04, 0, 0.10), "pr_steel_dark", bevel=0.004)
    hs.add(B(-half, half, 0.0, 0.04, 2.345, ROOM_H), "pr_steel_dark", bevel=0.004)
    e = half - 0.015
    hs.add(B(-e, e, -0.02, 0.04, 0.115, lower_top), "pr_wall", bevel=0.008)
    hs.add(B(-e, e, -0.02, 0.04, upper[0], upper[1]), upper_mat, bevel=0.008)
    hs.add(join_bm([_plate_bolts(-e, e, 0.115, lower_top, -0.023), _plate_bolts(-e, e, upper[0], upper[1], -0.023)]),
           "pr_steel_dark", flat=False, sharp=40)


def cell_wall_panel_a():
    """M-02: стенной модуль 1,1 × 2,45 м, толщина 0,25: две бронепанели со швом на 1,2 м, цоколь, карниз,
    утопленный крепёж. Лицо — y = 0 (в −Y), начало — низ лица по центру."""
    hs = HS("cell_wall_panel_a")
    _wall_base(hs, 0.55)
    obj = hs.finish(seed=1)
    L.collision_box(hs.coll, hs.name, (0, WALL_T / 2, ROOM_H / 2), (1.1, WALL_T, ROOM_H))
    return [obj]


def cell_wall_panel_b():
    """M-02 + M-16: модуль с сервисным коробом (кабельный ввод, крышка на винтах) и кабельной трассой к потолку."""
    hs = HS("cell_wall_panel_b")
    _wall_base(hs, 0.55)
    hs.add(B(-0.32, 0.08, -0.11, -0.02, 0.38, 0.86), "pr_steel_dark", bevel=0.008)
    hs.add(B(-0.30, 0.06, -0.118, -0.11, 0.40, 0.84), "pr_wall_alt", bevel=0.003)  # крышка
    hs.add(bolts([(x, -0.12, z) for x in (-0.28, 0.04) for z in (0.42, 0.82)], "Y", r=0.008, h=0.004),
           "pr_steel")
    hs.add(B(-0.10, 0.03, -0.122, -0.118, 0.76, 0.80), "pr_marking")
    hs.add(C(0.022, 2.33 - 0.86, (-0.24, -0.05, (0.86 + 2.33) / 2), "Z", 12), "pr_steel_dark", sharp=40)
    hs.add(join_bm([B(-0.27, -0.21, -0.08, -0.02, z, z + 0.04) for z in (1.3, 1.8, 2.22)]), "pr_steel", bevel=0.003)
    obj = hs.finish(seed=2)
    L.collision_box(hs.coll, hs.name, (0, WALL_T / 2, ROOM_H / 2), (1.1, WALL_T, ROOM_H))
    return [obj]


def cell_wall_panel_c():
    """M-02 вариант: заменённая верхняя панель чуть другого тона (бриф §6) и табличка номера сектора."""
    hs = HS("cell_wall_panel_c")
    _wall_base(hs, 0.55, upper_mat="pr_wall_alt")
    hs.add(B(0.12, 0.40, -0.027, -0.02, 1.58, 1.70), "pr_marking", bevel=0.002)
    hs.add(B(0.16, 0.36, -0.029, -0.027, 1.61, 1.67), "pr_rubber")
    obj = hs.finish(seed=3)
    L.collision_box(hs.coll, hs.name, (0, WALL_T / 2, ROOM_H / 2), (1.1, WALL_T, ROOM_H))
    return [obj]


def cell_wall_window():
    """M-08: модуль 1,4 м со смотровым стеклом 1,24 × 0,76 м (низ на 1,20 м) в тяжёлой раме, два слоя стекла
    с прижимным профилем. Стекло — отдельный материал (бриф Z3: дымчатое, отражает сильнее, чем пропускает)."""
    hs = HS("cell_wall_window")
    half, ox, z0, z1 = 0.7, 0.62, 1.20, 1.96
    _wall_base(hs, half, lower_top=1.12, upper=(2.06, 2.33), opening=(-ox, ox, z0, z1))
    fr = 0.07
    for b in (B(-ox - fr, -ox, -0.05, 0.06, z0 - fr, z1 + fr), B(ox, ox + fr, -0.05, 0.06, z0 - fr, z1 + fr),
              B(-ox, ox, -0.05, 0.06, z0 - fr, z0), B(-ox, ox, -0.05, 0.06, z1, z1 + fr)):
        hs.add(b, "pr_steel_dark", bevel=0.01)
    pf = 0.022
    for b in (B(-ox, -ox + pf, -0.01, 0.03, z0, z1), B(ox - pf, ox, -0.01, 0.03, z0, z1),
              B(-ox, ox, -0.01, 0.03, z0, z0 + pf), B(-ox, ox, -0.01, 0.03, z1 - pf, z1)):
        hs.add(b, "pr_steel", bevel=0.003)
    hs.add(bolts([(x, -0.053, z) for x in (-ox - 0.035, ox + 0.035) for z in (z0 + 0.05, (z0 + z1) / 2, z1 - 0.05)]
                 + [(x, -0.053, z) for x in (-0.31, 0.0, 0.31) for z in (z0 - 0.035, z1 + 0.035)],
                 "Y", r=0.012, h=0.006), "pr_steel")
    hs.add(B(-ox, ox, 0.03, 0.042, z0, z1), "pr_glass", flat=True)
    hs.add(B(-ox, ox, 0.16, 0.172, z0, z1), "pr_glass", flat=True)
    obj = hs.finish(seed=4)
    L.collision_box(hs.coll, hs.name, (0, WALL_T / 2, ROOM_H / 2), (1.4, WALL_T, ROOM_H))
    return [obj]


def cell_corner():
    """Угол бокса (бриф §9 P2: «узкая защитная накладка на углу стены»): заполняет квадрат 0,25 × 0,25 м за
    стыком стенных модулей и закрывает шов стальным уголком. Начало — внутренний угол; стены — по лицам
    x = 0 (тело в −X) и y = 0 (тело в +Y): левый дальний угол бокса, остальные — поворотом на 90°."""
    hs = HS("cell_corner")
    hs.add(B(-WALL_T, 0.0, 0.0, WALL_T, 0.0, ROOM_H), "pr_wall")
    hs.add(B(0.0, 0.07, -0.036, -0.02, 0.10, 2.345), "pr_steel_dark", bevel=0.003)
    hs.add(B(0.0, 0.016, -0.07, -0.02, 0.10, 2.345), "pr_steel_dark", bevel=0.003)
    hs.add(bolts([(0.045, -0.037, z) for z in (0.3, 1.2, 2.1)], "Y", r=0.007, h=0.004), "pr_steel")
    obj = hs.finish(ao=0.06, ground=True, seed=13)
    L.collision_box(hs.coll, hs.name, (-WALL_T / 2, WALL_T / 2, ROOM_H / 2), (WALL_T, WALL_T, ROOM_H))
    return [obj]


def cell_door_frame():
    """M-04 + M-19: силовой короб двери 1,4 м: портал проёма 1,12 × 2,22 м (выступает в бокс на 6 см),
    ответные гнёзда ригелей, порог, предупредительная лампа над дверью, наружная панель доступа."""
    hs = HS("cell_door_frame")
    ox, oh = 0.56, 2.22
    hs.add(B(-0.70, -ox, -0.06, WALL_T, 0, 2.32), "pr_steel_dark", bevel=0.012)
    hs.add(B(ox, 0.70, -0.06, WALL_T, 0, 2.32), "pr_steel_dark", bevel=0.012)
    hs.add(B(-0.70, 0.70, -0.06, WALL_T, oh, 2.32), "pr_steel_dark", bevel=0.012)
    hs.add(B(-0.70, 0.70, 0.0, WALL_T, 2.32, ROOM_H), "pr_wall", bevel=0.004)
    hs.add(B(-ox, ox, -0.06, WALL_T, 0, 0.012), "pr_steel", bevel=0.003)  # порог
    # Накладки-усилители по контуру портала (сторона бокса).
    hs.add(B(-0.69, -0.60, -0.075, -0.06, 0.05, 2.25), "pr_wall_alt", bevel=0.004)
    hs.add(B(0.60, 0.69, -0.075, -0.06, 0.05, 2.25), "pr_wall_alt", bevel=0.004)
    hs.add(bolts([(x, -0.078, z) for x in (-0.645, 0.645) for z in (0.15, 0.6, 1.1, 1.6, 2.1)], "Y", r=0.011),
           "pr_steel")
    # Гнёзда ригелей на стороне замка (совпадают с ригелями двери).
    for z in (0.45, 1.10, 1.75):
        hs.add(B(ox - 0.004, ox + 0.012, 0.05, 0.15, z - 0.05, z + 0.05), "pr_rubber")
    # Лампа над дверью: корпус, янтарный колпак, решётка.
    hs.add(B(-0.09, 0.09, -0.04, 0.0, 2.345, 2.425), "pr_steel_dark", bevel=0.006)
    hs.add(C(0.032, 0.05, (0, -0.065, 2.385), "Y", 16), "pr_lamp_warn", sharp=40)
    hs.add(P.ring_rect(0.034, 0.04, 0.012, 16, axis="Y"), "pr_steel", uv=True, sharp=40)
    hs.objs[-1].data.transform(T(0, -0.09, 2.385))
    # Наружная панель доступа (кодовый замок) на стороне коридора.
    hs.add(B(0.585, 0.685, WALL_T, WALL_T + 0.035, 1.22, 1.46), "pr_steel_dark", bevel=0.005)
    hs.add(screen_quad(0.07, 0.05, T(0.635, WALL_T + 0.036, 1.40) @ rot(180, "Z")), "pr_screen_cell", uv=False,
           flat=True)
    obj = hs.finish(seed=5)
    for nm, cx, sx in (("_l", -0.63, 0.14), ("_r", 0.63, 0.14)):
        L.collision_box(hs.coll, hs.name + nm, (cx, 0.095, 1.16), (sx, 0.31, 2.32))
    L.collision_box(hs.coll, hs.name + "_top", (0, 0.095, 2.335), (1.4, 0.31, 0.23))
    return [obj]


def vault_door():
    return _vault_door("vault_door")


def vault_door_inward():
    """Зеркальный вариант двери-сейфа для `containment_room.tscn`: сценарий открывает дверь внутрь бокса
    (`DoorPivot.rotation.y = −1,6`), поэтому наружный упор, штурвал и петли — со стороны бокса (как штурвал CSG-двери).
    Ось петель — начало; полотно в +X; сторона петель — −Y (в Godot при повороте 0 — +Z, внутрь бокса)."""
    return _vault_door("vault_door_inward", mirror=True)


def _vault_door(name, mirror=False):
    """M-05: дверь-сейф 1,10 × 2,20 × 0,19 м (канон гл. 1: «массивная дверь-сейф»): ступенчатый край
    с наружным упором, три ригеля на торце замка, крышка механизма с болтами и рёбра изнутри, штурвал
    и петли снаружи (дверь открывается в коридор). Начало — ось петель внизу; полотно в +X.
    В проёме `cell_door_frame`: ставить в (−0,555; 0,10; 0,01) относительно начала короба."""
    hs = HS(name, mirror_y=mirror)
    W, H = 1.10, 2.20
    hs.add(B(0.0, W, -0.07, 0.07, 0.0, H), "pr_wall", bevel=0.01)
    hs.add(B(-0.02, W + 0.04, 0.07, 0.12, -0.02, H + 0.04), "pr_wall", bevel=0.012)  # наружный упор
    # Изнутри: крышка механизма, рёбра, болты.
    hs.add(B(0.25, 0.85, -0.10, -0.07, 0.55, 1.75), "pr_wall_alt", bevel=0.01)
    hs.add(bolts([(x, -0.103, z) for x in (0.29, 0.81) for z in (0.6, 1.15, 1.7)], "Y", r=0.014, h=0.008),
           "pr_steel")
    for z in (0.28, 1.92):
        hs.add(B(0.08, W - 0.08, -0.095, -0.07, z, z + 0.08), "pr_wall", bevel=0.006)
    hs.add(bolts([(x, -0.098, z + 0.04) for x in (0.14, 0.55, 0.96) for z in (0.28, 1.92)], "Y", r=0.012),
           "pr_steel")
    # Ригели (выдвинуты — дверь заперта).
    for z in (0.45, 1.10, 1.75):
        hs.add(C(0.035, 0.09, (W + 0.04, 0.0, z), "X", 16), "pr_steel", sharp=40)
    # Уплотнитель по контуру наружного упора.
    hs.add(join_bm([B(-0.01, W + 0.03, 0.068, 0.074, -0.01, 0.01), B(-0.01, W + 0.03, 0.068, 0.074, H + 0.01, H + 0.03),
                    B(W + 0.01, W + 0.03, 0.068, 0.074, 0.0, H)]), "pr_rubber")
    # Снаружи: штурвал (обод, ступица, спицы) и петли.
    cx, cy, cz = 0.62, 0.12, 1.15
    hs.add(C(0.07, 0.08, (cx, cy + 0.04, cz), "Y", 20), "pr_steel_dark", bevel=0.006)
    rim = [Vector((cx + 0.23 * math.cos(a), cy + 0.12, cz + 0.23 * math.sin(a)))
           for a in (2 * math.pi * k / 32 for k in range(32))]
    hs.add(P.tube(rim, 0.02, segs=10, closed=True), "pr_steel", sharp=50)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        hs.add(P.tube([Vector((cx + 0.05 * math.cos(a), cy + 0.08, cz + 0.05 * math.sin(a))),
                       Vector((cx + 0.22 * math.cos(a), cy + 0.12, cz + 0.22 * math.sin(a)))], 0.014, segs=8),
               "pr_steel", sharp=50)
    for z in (0.35, 1.85):
        hs.add(C(0.06, 0.34, (-0.02, 0.17, z), "Z", 20), "pr_steel_dark", bevel=0.006)
        hs.add(B(-0.02, 0.18, 0.12, 0.15, z - 0.14, z + 0.14), "pr_steel_dark", bevel=0.005)
    obj = hs.finish(ground=False, seed=6)
    L.collision_box(hs.coll, hs.name, (W / 2, -0.025 if mirror else 0.025, H / 2), (W, 0.19, H))
    return [obj]


def cell_floor():
    """M-01 + M-18: пол 3,6 × 4,4 м — листы 0,9 × 0,88 м с узкими швами на тёмном основании; кабельный
    канал под стальной крышкой ведёт от двери к основанию кресла (x = −0,45, бриф §6 «Пол»)."""
    hs = HS("cell_floor")
    hs.add(B(-ROOM_W / 2, ROOM_W / 2, -ROOM_L / 2, ROOM_L / 2, -0.12, -0.02), "pr_steel_dark")
    xs = [-1.8, -0.9, 0.0, 0.9, 1.8]
    ys = [-2.2 + 0.88 * k for k in range(6)]
    plates = [B(x0 + 0.004, x1 - 0.004, y0 + 0.004, y1 - 0.004, -0.02, 0.0)
              for x0, x1 in zip(xs, xs[1:]) for y0, y1 in zip(ys, ys[1:])]
    for b in plates:
        hs.add(b, "pr_floor", bevel=0.003, segs=1)
    hs.add(B(-0.51, -0.39, -2.2, -0.70, -0.003, 0.003), "pr_steel", bevel=0.002, segs=1)
    hs.add(bolts([(x, y, 0.004) for x in (-0.49, -0.41) for y in (-2.1, -1.6, -1.1, -0.8)], "Z", r=0.006, h=0.003),
           "pr_steel_dark")
    obj = hs.finish(ao=0.06, ground=False, base_dark=0.0, seed=7)
    L.collision_box(hs.coll, hs.name, (0, 0, -0.06), (ROOM_W, ROOM_L, 0.12))
    return [obj]


def cell_ceiling():
    """M-03: потолок на 2,45 м — четыре плоские панели со швами, компактный короб коммуникаций вдоль
    правой стены (бриф §6: «максимум один короб»). Светильник — отдельный ассет `ceiling_light_cell`."""
    hs = HS("cell_ceiling")
    hs.add(B(-ROOM_W / 2, ROOM_W / 2, -ROOM_L / 2, ROOM_L / 2, ROOM_H + 0.02, ROOM_H + 0.12), "pr_steel_dark")
    for x0, x1 in ((-1.8, 0.0), (0.0, 1.8)):
        for y0, y1 in ((-2.2, 0.0), (0.0, 2.2)):
            hs.add(B(x0 + 0.005, x1 - 0.005, y0 + 0.005, y1 - 0.005, ROOM_H, ROOM_H + 0.02), "pr_wall", bevel=0.004)
    hs.add(B(1.50, 1.80, -2.2, 2.2, 2.27, ROOM_H), "pr_wall_alt", bevel=0.008)
    hs.add(join_bm([B(1.48, 1.80, y - 0.025, y + 0.025, 2.255, ROOM_H) for y in (-1.6, -0.5, 0.6, 1.7)]),
           "pr_steel_dark", bevel=0.004)
    obj = hs.finish(ao=0.08, ground=False, base_dark=0.0, seed=8)
    L.collision_box(hs.coll, hs.name, (0, 0, ROOM_H + 0.06), (ROOM_W, ROOM_L, 0.12))
    return [obj]


def _ceiling_light(name, length, width, depth=0.08):
    """M-10: накладной светильник: корпус, рассеиватель (отдельный узел `<имя>_diffuser`), торцевые крышки.
    Начало — центр верха (плоскость потолка), длинная ось — Y."""
    hs = HS(name)
    hs.add(B(-width / 2, width / 2, -length / 2, length / 2, -depth, 0.0), "pr_steel_dark", bevel=0.008)
    for s in (-1, 1):
        hs.add(B(-width / 2 - 0.004, width / 2 + 0.004, s * length / 2 - 0.03 * (1 + s) / 2 - 0.0 * s,
                 s * length / 2 + 0.03 * (1 - s) / 2, -depth - 0.006, 0.0), "pr_steel", bevel=0.004)
    hs.add(bolts([(0, s * (length / 2 - 0.06), -depth - 0.007) for s in (-1, 1)], "Z", r=0.006, h=0.003),
           "pr_steel_dark")
    hs.add(B(-width / 2 + 0.02, width / 2 - 0.02, -length / 2 + 0.035, length / 2 - 0.035, -depth - 0.004,
             -depth + 0.01), "pr_light", bevel=0.003, keep=name + "_diffuser")
    return hs.finish(ground=False, seed=9)


def ceiling_light_cell():
    """M-10 изолятора: 0,9 × 0,18 × 0,08 м (бриф §9)."""
    return [_ceiling_light("ceiling_light_cell", 0.9, 0.18)]


def vent_grille():
    """M-09: решётка 0,45 × 0,25 м: рамка, утопленные ламели под 35°, тёмная глубина без видимого канала,
    крепёж. Начало — центр лица на стене (лицо в −Y)."""
    hs = HS("vent_grille")
    w, h, f = 0.45, 0.25, 0.03
    for b in (B(-w / 2, w / 2, -0.02, 0.0, h / 2 - f, h / 2), B(-w / 2, w / 2, -0.02, 0.0, -h / 2, -h / 2 + f),
              B(-w / 2, -w / 2 + f, -0.02, 0.0, -h / 2, h / 2), B(w / 2 - f, w / 2, -0.02, 0.0, -h / 2, h / 2)):
        hs.add(b, "pr_steel_dark", bevel=0.004)
    box = B(-w / 2 + f, w / 2 - f, -0.005, 0.09, -h / 2 + f, h / 2 - f)
    bottom = [fc for fc in box.faces if fc.normal.y < -0.5]
    bmesh.ops.delete(box, geom=bottom, context="FACES")
    bmesh.ops.reverse_faces(box, faces=list(box.faces))  # видно изнутри
    hs.add(box, "pr_rubber", flat=True)
    for k in range(6):
        z = -h / 2 + f + 0.016 + k * 0.031
        hs.add(B(-w / 2 + f, w / 2 - f, -0.012, 0.012, -0.0025, 0.0025, m=T(0, 0.01, z) @ rot(35, "X")),
               "pr_steel_dark", bevel=0.0015, segs=1)
    hs.add(bolts([(x, -0.021, z) for x in (-w / 2 + 0.015, w / 2 - 0.015) for z in (-h / 2 + 0.015, h / 2 - 0.015)],
                 "Y", r=0.006, h=0.003), "pr_steel")
    return [hs.finish(ao=0.05, ground=False, base_dark=0.0, seed=10)]


def cell_terminal():
    """M-07: настенный терминал: корпус 0,56 × 0,50 × 0,12 м, экран 0,40 × 0,28 м (центр на 1,42 м),
    сервисная панель с кнопками и индикатором, трасса кабеля к полу. Начало — пол под терминалом у стены."""
    hs = HS("cell_terminal")
    hs.add(B(-0.28, 0.28, -0.12, 0.0, 1.15, 1.65), "pr_wall_alt", bevel=0.012)
    hs.add(B(-0.225, 0.225, -0.128, -0.118, 1.265, 1.575), "pr_rubber", bevel=0.004)  # рамка экрана
    hs.add(screen_quad(0.40, 0.28, T(0, -0.1295, 1.42)), "pr_screen_cell", uv=False, flat=True)
    hs.add(B(-0.25, 0.25, -0.17, -0.10, 1.12, 1.22, m=T(0, -0.13, 1.17) @ rot(-18, "X") @ T(0, 0.13, -1.17)),
           "pr_steel_dark", bevel=0.008)
    hs.add(join_bm([C(0.014, 0.012, (x, -0.185, 1.185), "Y", 16, m=T(0, -0.13, 1.17) @ rot(-18, "X") @ T(0, 0.13, -1.17))
                    for x in (-0.15, -0.09, -0.03)]), "pr_rubber", sharp=40)
    hs.add(C(0.006, 0.006, (0.16, -0.18, 1.19), "Y", 12), "pr_light", sharp=40, keep="cell_terminal_status")
    hs.add(C(0.018, 1.12, (0.22, -0.035, 0.56), "Z", 12), "pr_steel_dark", sharp=40)
    hs.add(join_bm([B(0.195, 0.245, -0.06, 0.0, z, z + 0.03) for z in (0.25, 0.75)]), "pr_steel", bevel=0.003)
    return [hs.finish(ground=True, seed=11)]


def cell_power_box():
    """Бриф §9 P2: небольшой настенный блок питания/контактор: корпус на винтах, дверца на петлях с замком,
    вентиляционные прорези, знак, индикатор, трасса к потолку. Начало — пол у стены (лицо в −Y), корпус 1,45–2,0 м."""
    hs = HS("cell_power_box")
    hs.add(B(-0.20, 0.20, -0.18, 0.0, 1.45, 2.0), "pr_wall_alt", bevel=0.01)
    hs.add(B(-0.185, 0.185, -0.186, -0.18, 1.465, 1.985), "pr_wall_alt", bevel=0.003)
    hs.add(join_bm([B(-0.198, -0.188, -0.19, -0.176, z - 0.04, z + 0.04) for z in (1.55, 1.9)]), "pr_steel_dark",
           bevel=0.002)
    hs.add(C(0.012, 0.012, (0.15, -0.192, 1.72), "Y", 16), "pr_steel", sharp=40)
    hs.add(join_bm([B(-0.12, 0.12, -0.187, -0.185, z, z + 0.008) for z in (1.52, 1.54, 1.56)]), "pr_rubber")
    hs.add(B(-0.06, 0.06, -0.189, -0.186, 1.82, 1.90), "pr_marking", bevel=0.002)
    hs.add(C(0.005, 0.006, (0.15, -0.19, 1.95), "Y", 12), "pr_light", sharp=40, keep="cell_power_box_status")
    hs.add(C(0.025, ROOM_H - 2.0, (0.08, -0.06, (2.0 + ROOM_H) / 2), "Z", 12), "pr_steel_dark", sharp=40)
    return [hs.finish(ground=False, seed=14)]


def cell_ceiling_hatch():
    """Бриф §9 P2: сервисный люк потолка 0,6 × 0,6 м: рама, крышка с четвертьоборотными замками, петля, полоса
    маркировки. Начало — плоскость потолка; всё ниже на 2–3 см (люк не ведёт в видимый проход)."""
    hs = HS("cell_ceiling_hatch")
    o, i = 0.33, 0.29
    for b in (B(-o, o, i, o, -0.022, 0.0), B(-o, o, -o, -i, -0.022, 0.0), B(-o, -i, -i, i, -0.022, 0.0),
              B(i, o, -i, i, -0.022, 0.0)):
        hs.add(b, "pr_steel_dark", bevel=0.004)
    hs.add(B(-i + 0.004, i - 0.004, -i + 0.004, i - 0.004, -0.014, 0.0), "pr_wall", bevel=0.003)
    hs.add(join_bm([C(0.015, 0.008, (x, y, -0.016), "Z", 16) for x in (-0.24, 0.24) for y in (-0.24, 0.24)]),
           "pr_steel", sharp=40)
    hs.add(B(-0.25, 0.25, i - 0.03, i - 0.01, -0.019, -0.014), "pr_steel_dark", bevel=0.002)
    hs.add(B(-0.2, 0.2, -0.06, -0.03, -0.016, -0.014), "pr_marking")
    return [hs.finish(ao=0.04, ground=False, base_dark=0.0, seed=15)]


def cell_camera():
    """Бриф §9 P2: незаметная купольная камера на потолке (14 см): основание, дымчатый купол, тёмный блок камеры,
    тусклый огонёк. Не центральный объект. Начало — плоскость потолка."""
    hs = HS("cell_camera")
    hs.add(C(0.07, 0.016, (0, 0, -0.008), "Z", 32), "pr_wall_alt", bevel=0.004)
    hs.add(B(-0.025, 0.025, -0.03, 0.02, -0.07, -0.02, m=rot(-30, "X")), "pr_rubber", bevel=0.006)
    hs.add(C(0.012, 0.01, (0, -0.03, -0.045), "Y", 16, m=rot(-30, "X")), "pr_glass", sharp=40)
    prof = [(0.056, -0.016)] + [(0.056 * math.cos(math.radians(a)), -0.016 - 0.056 * math.sin(math.radians(a)))
                                for a in range(15, 90, 15)] + [(0.002, -0.072)]
    hs.add(P.lathe(prof, segs=32, close_top=False), "pr_glass", sharp=60)
    hs.add(C(0.004, 0.004, (0.05, 0.0, -0.017), "Z", 10), "pr_sensor", sharp=40, keep="cell_camera_led")
    return [hs.finish(ao=0.03, ground=False, base_dark=0.0, seed=16)]


# ======================================================================================
# Кресло-фиксатор (M-06, M-11…M-15, M-17)
# ======================================================================================
def restraint_chair():
    """Громоздкое кресло — «нечто среднее между больничной койкой и пыточным устройством» (канон гл. 1).
    Бриф Z1: ~2,1 × 0,85 м, с полукожухом до 1,35 м; спина поднята на 30°; тяжёлое короткое основание с
    анкерной плитой; сегментированный подголовник; боковые упоры; ремни на запястьях и голенях; грудной
    пояс с двумя замками; открытый полукожух над головой; датчики; кабельный ввод; маркировка; один
    статусный индикатор. Индикатор Заклятия — отдельный узел `spell_indicator` на кронштейне кожуха.
    Начало — пол под центром сиденья; голова — в +Y. В боксе ставить в (−0,45; 0,20; 0)."""
    hs = HS("restraint_chair")
    seat_z, hinge_b, hinge_l = 0.53, 0.24, -0.24
    MB = T(0, hinge_b, seat_z) @ rot(30, "X")      # рама спинки: локальная Y — вдоль спинки
    ML = T(0, hinge_l, seat_z) @ rot(15, "X")      # рама подножки: локальная −Y — к ногам, вниз на 15°
    # --- Основание.
    hs.add(B(-0.31, 0.31, -0.60, 0.62, 0.0, 0.03), "pr_steel_dark", bevel=0.006)
    hs.add(bolts([(x, y, 0.03) for x in (-0.27, 0.27) for y in (-0.55, -0.2, 0.2, 0.57)], "Z", r=0.022, h=0.02),
           "pr_steel")
    hs.add(B(-0.22, 0.22, -0.42, 0.42, 0.03, 0.33), "pr_wall", bevel=0.03, segs=3)
    hs.add(B(0.219, 0.229, -0.26, 0.18, 0.08, 0.27), "pr_wall_alt", bevel=0.003)  # сервисная панель
    hs.add(bolts([(0.229, y, z) for y in (-0.24, 0.16) for z in (0.10, 0.25)], "X", r=0.007, h=0.004), "pr_steel")
    hs.add(B(-0.229, -0.219, -0.12, 0.12, 0.17, 0.23), "pr_marking", bevel=0.002)
    hs.add(B(-0.231, -0.229, -0.07, 0.07, 0.185, 0.215), "pr_rubber")
    hs.add(C(0.008, 0.006, (0.0, -0.424, 0.26), "Y", 12), "pr_light", sharp=40, keep="restraint_chair_status")
    hs.add(C(0.085, 0.13, (0, 0, 0.39), "Z", 24), "pr_steel", sharp=40)  # колонна подъёмника
    hs.add(C(0.11, 0.03, (0, 0, 0.345), "Z", 24), "pr_steel_dark", bevel=0.006)
    hs.add(B(-0.25, 0.25, -0.30, 0.30, 0.455, 0.50), "pr_steel_dark", bevel=0.008)  # ложемент сиденья
    # Кабельный ввод у основания → канал пола к двери.
    hs.add(B(-0.07, 0.07, -0.46, -0.42, 0.05, 0.16), "pr_steel_dark", bevel=0.006)
    cable = [Vector((0, -0.47, 0.1)), Vector((0, -0.53, 0.07)), Vector((0, -0.58, 0.03)), Vector((0, -0.64, 0.015)),
             Vector((0, -0.75, 0.012))]
    hs.add(P.tube(cable, 0.022, segs=10), "pr_rubber", sharp=60)
    # --- Рама: боковые трубы секций и оси шарниров.
    for s in (-1, 1):
        hs.add(B(s * 0.29 - 0.025, s * 0.29 + 0.025, -0.24, 0.24, 0.47, 0.52), "pr_steel_dark", bevel=0.006)
        hs.add(B(s * 0.29 - 0.025, s * 0.29 + 0.025, 0.0, 0.80, -0.06, -0.01, m=MB), "pr_steel_dark", bevel=0.006)
        hs.add(B(s * 0.27 - 0.022, s * 0.27 + 0.022, -0.76, 0.0, -0.06, -0.01, m=ML), "pr_steel_dark", bevel=0.006)
    for y in (hinge_b, hinge_l):
        hs.add(C(0.032, 0.68, (0, y, 0.495), "X", 20), "pr_steel", sharp=40)
    # Гидроцилиндр под спинкой.
    a, b = Vector((0, 0.30, 0.34)), MB @ Vector((0, 0.36, -0.06))
    mid = a.lerp(b, 0.55)
    hs.add(P.tube([a, mid], 0.032, segs=14), "pr_steel_dark", sharp=50)
    hs.add(P.tube([mid, b], 0.015, segs=12), "pr_steel", sharp=50)
    # --- Накладки (винил).
    hs.add(B(-0.31, 0.31, -0.235, 0.235, seat_z, seat_z + 0.09), "pr_vinyl", bevel=0.03, segs=3)
    hs.add(B(-0.29, 0.29, 0.02, 0.78, -0.01, 0.08, m=MB), "pr_vinyl", bevel=0.028, segs=3)
    for s in (-1, 1):  # боковые упоры спинки
        hs.add(B(s * 0.31 - 0.035, s * 0.31 + 0.035, 0.10, 0.62, 0.02, 0.15, m=MB), "pr_vinyl", bevel=0.025, segs=3)
    for k in range(3):  # сегментированный подголовник
        y0 = 0.80 + k * 0.105
        hs.add(B(-0.17, 0.17, y0, y0 + 0.095, -0.01, 0.10, m=MB), "pr_vinyl", bevel=0.03, segs=3)
    for s in (-1, 1):  # «уши» подголовника
        hs.add(B(s * 0.195 - 0.03, s * 0.195 + 0.03, 0.83, 1.08, 0.05, 0.19, m=MB @ T(s * 0.195, 0, 0.05)
                 @ rot(-s * 12, "Y") @ T(-s * 0.195, 0, -0.05)), "pr_vinyl", bevel=0.022, segs=3)
    hs.add(B(-0.27, 0.27, -0.75, -0.01, -0.01, 0.07, m=ML), "pr_vinyl", bevel=0.026, segs=3)
    hs.add(B(-0.24, 0.24, -0.80, -0.775, -0.05, 0.24, m=ML), "pr_steel_dark", bevel=0.008)  # упор для стоп
    # --- Подлокотники с манжетами.
    for s in (-1, 1):
        x = s * 0.40
        ma = T(x, 0.02, 0.715) @ rot(6, "X")
        hs.add(B(-0.06, 0.06, -0.26, 0.26, -0.03, 0.03, m=ma), "pr_vinyl", bevel=0.02, segs=3)
        hs.add(join_bm([B(x - 0.02, x + 0.02, y - 0.025, y + 0.025, 0.50, 0.69) for y in (-0.12, 0.16)]),
               "pr_steel_dark", bevel=0.005)
        xa, xb = sorted((s * 0.29, x - s * 0.02))
        hs.add(B(xa, xb, -0.15, 0.19, 0.49, 0.52), "pr_steel_dark", bevel=0.004)
        cuff = P.ring_rect(0.042, 0.058, 0.075, 24, axis="Y")
        cuff.transform(ma @ T(0, -0.13, 0.065))
        hs.add(cuff, "pr_vinyl", bevel=0.006, segs=2, angle=60)
        hs.add(B(-0.03, 0.03, -0.165, -0.095, 0.115, 0.14, m=ma), "pr_steel", bevel=0.005)
        hs.add(B(-0.055, 0.055, 0.08, 0.13, 0.03, 0.04, m=ma), "pr_rubber", bevel=0.003)  # датчик предплечья
        hs.add(C(0.016, 0.006, (0, 0.105, 0.044), "Z", 16, m=ma), "pr_steel", sharp=40)
    # --- Ремни: голени (две дуги) и грудной пояс с двумя замками.
    for yl in (-0.30, -0.60):
        pts = [ML @ Vector((x, yl, 0.08 + 0.11 * math.sqrt(max(0.0, 1 - (x / 0.30) ** 2))))
               for x in [-0.30 + 0.6 * i / 16 for i in range(17)]]
        hs.add(ribbon(pts, ML.to_3x3() @ Vector((0, 1, 0)), 0.06, 0.008), "pr_webbing", sharp=60)
        for s in (-1, 1):
            hs.add(B(s * 0.30 - 0.03, s * 0.30 + 0.03, yl - 0.04, yl + 0.04, 0.06, 0.10, m=ML), "pr_steel", bevel=0.005)
    pts = [MB @ Vector((x, 0.42, 0.08 + 0.17 * math.sqrt(max(0.0, 1 - (x / 0.34) ** 2))))
           for x in [-0.34 + 0.68 * i / 20 for i in range(21)]]
    hs.add(ribbon(pts, MB.to_3x3() @ Vector((0, 1, 0)), 0.075, 0.009), "pr_webbing", sharp=60)
    for s in (-1, 1):
        hs.add(B(s * 0.345 - 0.04, s * 0.345 + 0.04, 0.37, 0.47, 0.0, 0.11, m=MB), "pr_steel", bevel=0.008)
        hs.add(B(s * 0.345 - 0.012, s * 0.345 + 0.012, 0.40, 0.44, 0.11, 0.125, m=MB), "pr_rubber", bevel=0.003)
    # --- Полукожух над головой и плечами: открытая дуга, три ребра, кронштейны на осях.
    MH = MB @ T(0, 0, 0.13)
    hr = 0.32
    shell = arc_shell(hr, 0.022, -72, 72, 0.68, 1.10, zc=0.0, segs=24)
    shell.transform(MH)
    hs.add(shell, "pr_armor", bevel=0.005, angle=50)
    for y in (0.68, 0.89, 1.10):
        rib = arc_shell(hr + 0.015, 0.03, -76, 76, y - 0.02, y + 0.02, zc=0.0, segs=24)
        rib.transform(MH)
        hs.add(rib, "pr_steel_dark", bevel=0.004, angle=50)
    ex = hr * math.sin(math.radians(74))
    ez = hr * math.cos(math.radians(74))
    for s in (-1, 1):
        bx = s * (ex - 0.005)
        hs.add(B(bx - 0.02, bx + 0.02, 0.81, 0.97, -0.17, ez + 0.03, m=MH), "pr_steel_dark", bevel=0.006)
        hs.add(C(0.035, 0.03, (bx + s * 0.035, 0.89, ez - 0.02), "X", 20, m=MH), "pr_steel", sharp=40)
    # Индикатор Заклятия (M-17): корпус и рассеиватель на правом кронштейне — отдельный узел.
    hx = ex - 0.005 + 0.02
    hs.add(C(0.03, 0.03, (hx + 0.015, 0.89, -0.08), "X", 20, m=MH), "pr_steel_dark", bevel=0.004)
    hs.add(C(0.021, 0.012, (hx + 0.036, 0.89, -0.08), "X", 20, m=MH), "pr_indicator", sharp=40,
           keep="spell_indicator")
    # Датчики у висков с кабелями к ребру кожуха.
    for s in (-1, 1):
        p = Vector((s * 0.165, 0.95, 0.15))
        hs.add(C(0.02, 0.012, tuple(p), "X", 16, m=MB), "pr_rubber", sharp=40)
        hs.add(P.tube([MB @ (p + Vector((s * 0.008, 0, 0.01))), MB @ (p + Vector((s * 0.04, 0.0, 0.12))),
                       MH @ Vector((s * 0.18, 0.89, 0.26))], 0.004, segs=6), "pr_rubber", sharp=60)
    obj = hs.finish(ao=0.1, rays=16, ground=True, seed=12)
    L.collision_box(hs.coll, hs.name + "_base", (0, 0.0, 0.25), (0.62, 1.2, 0.5))
    L.collision_box(hs.coll, hs.name + "_bed", (0, 0.1, 0.62), (0.9, 2.1, 0.25))
    return [obj]


def restraint_chair_upright():
    return _chair_upright("restraint_chair_upright", straps=False)


def restraint_chair_upright_straps():
    """Ремни, манжеты и замки кресла `restraint_chair_upright` отдельной моделью: сценарий бокса показывает их в
    момент пристёгивания (`Chair/Restraints.visible`). Та же система координат, что у кресла."""
    return _chair_upright("restraint_chair_upright_straps", straps=True)


def _chair_upright(name, straps):
    """Вариант кресла-фиксатора под существующую позу сцены (`Sitting_Idle` модели Санни: таз на 0,525 м, голова
    опущена вперёд, руки на коленях, стопы на полу — замер костей в Godot). Те же язык и материалы, что у кресла брифа:
    анкерная плита, пьедестал, сиденье и спинка (80°) с боковыми упорами, сегментированный подголовник, подлокотники,
    манжеты на запястьях на коротких ремнях, грудной пояс с двумя замками, вертикальная подставка за голенями с
    ремнём и манжетами лодыжек, полукожух-козырёк над головой, индикатор Заклятия `spell_indicator`.
    Начало — пол под центром сиденья; лицом в −Y. В `containment_room` — (0; 0; 1,15), поворот 180°."""
    hs = HS(name)
    add = hs.add

    def strap(*a, **k):  # детали удержания — только в модели ремней
        if straps:
            add(*a, **k)

    def frame(*a, **k):  # всё остальное — только в модели кресла
        if not straps:
            add(*a, **k)

    st = 0.45  # верх сиденья
    frame(B(-0.31, 0.31, -0.05, 0.62, 0.0, 0.03), "pr_steel_dark", bevel=0.006)
    frame(bolts([(x, y, 0.03) for x in (-0.27, 0.27) for y in (0.0, 0.3, 0.57)], "Z", r=0.022, h=0.02), "pr_steel")
    frame(B(-0.22, 0.22, -0.08, 0.42, 0.03, 0.22), "pr_wall", bevel=0.03, segs=3)
    frame(B(0.219, 0.229, 0.0, 0.34, 0.06, 0.19), "pr_wall_alt", bevel=0.003)
    frame(bolts([(0.229, y, z) for y in (0.02, 0.32) for z in (0.08, 0.17)], "X", r=0.007, h=0.004), "pr_steel")
    frame(B(-0.229, -0.219, 0.05, 0.25, 0.10, 0.16), "pr_marking", bevel=0.002)
    frame(B(-0.231, -0.229, 0.09, 0.21, 0.115, 0.145), "pr_rubber")
    frame(C(0.008, 0.006, (0.0, -0.084, 0.17), "Y", 12), "pr_light", sharp=40, keep="restraint_chair_status")
    frame(C(0.085, 0.11, (0, 0.17, 0.275), "Z", 24), "pr_steel", sharp=40)
    frame(C(0.11, 0.03, (0, 0.17, 0.235), "Z", 24), "pr_steel_dark", bevel=0.006)
    frame(B(-0.25, 0.25, -0.22, 0.26, 0.33, 0.37), "pr_steel_dark", bevel=0.008)
    cable = [Vector((0, -0.09, 0.08)), Vector((0, -0.14, 0.04)), Vector((0, -0.2, 0.015)), Vector((0, -0.55, 0.012))]
    frame(P.tube(cable, 0.022, segs=10), "pr_rubber", sharp=60)
    # Сиденье, спинка, упоры, подголовник.
    frame(B(-0.30, 0.30, -0.24, 0.24, 0.37, st), "pr_vinyl", bevel=0.03, segs=3)
    MB = T(0, 0.27, 0.43) @ rot(80, "X")  # локальная Y — вверх по спинке, Z — к сидящему
    frame(B(-0.29, 0.29, 0.03, 0.80, -0.09, 0.0, m=MB), "pr_vinyl", bevel=0.028, segs=3)
    for s in (-1, 1):
        frame(B(s * 0.31 - 0.035, s * 0.31 + 0.035, 0.15, 0.62, -0.05, 0.07, m=MB), "pr_vinyl", bevel=0.025, segs=3)
        frame(B(s * 0.27 - 0.025, s * 0.27 + 0.025, 0.0, 0.84, -0.14, -0.09, m=MB), "pr_steel_dark", bevel=0.006)
    for k in range(3):
        y0 = 0.84 + k * 0.105
        frame(B(-0.17, 0.17, y0, y0 + 0.095, -0.10, 0.01, m=MB), "pr_vinyl", bevel=0.03, segs=3)
    frame(C(0.03, 0.62, (0, 0.27, 0.40), "X", 20), "pr_steel", sharp=40)
    a, b = Vector((0, 0.36, 0.22)), MB @ Vector((0, 0.30, -0.14))
    mid = a.lerp(b, 0.55)
    frame(P.tube([a, mid], 0.03, segs=14), "pr_steel_dark", sharp=50)
    frame(P.tube([mid, b], 0.014, segs=12), "pr_steel", sharp=50)
    # Подлокотники, датчики, манжеты запястий на коротких ремнях (руки в позе лежат на коленях).
    fdir = Vector((0.0, -0.19, -0.13)).normalized()
    for s in (-1, 1):
        x = s * 0.36
        frame(B(x - 0.06, x + 0.06, -0.20, 0.24, 0.57, 0.62), "pr_vinyl", bevel=0.02, segs=3)
        frame(join_bm([B(x - 0.02, x + 0.02, y - 0.025, y + 0.025, 0.37, 0.57) for y in (-0.10, 0.16)]),
               "pr_steel_dark", bevel=0.005)
        xa, xb = sorted((s * 0.25, s * 0.34))
        frame(B(xa, xb, -0.12, 0.18, 0.33, 0.36), "pr_steel_dark", bevel=0.004)
        frame(B(x - 0.045, x + 0.045, 0.06, 0.12, 0.62, 0.628), "pr_rubber", bevel=0.002)
        w = Vector((s * 0.155, -0.02, 0.585))
        rd = Vector((0, 1, 0)).rotation_difference(Vector((-s * 0.05, fdir.y, fdir.z)).normalized()).to_matrix().to_4x4()
        cuff = P.ring_rect(0.038, 0.052, 0.065, 24, axis="Y")
        cuff.transform(T(*w) @ rd)
        strap(cuff, "pr_vinyl", bevel=0.006, angle=60)
        strap(B(-0.022, 0.022, -0.03, 0.03, 0.05, 0.072, m=T(*w) @ rd), "pr_steel", bevel=0.004)
        strap(ribbon([w + Vector((s * 0.05, 0, 0)), Vector((s * 0.30, -0.02, 0.60))], (0, 1, 0), 0.04, 0.006),
               "pr_webbing", sharp=60)
    # Грудной пояс: полуэллипс перед грудью, замки на краях спинки.
    pts = [Vector((0.25 * math.sin(t), 0.32 - 0.34 * math.cos(t), 0.80))
           for t in [-math.pi / 2 + math.pi * i / 20 for i in range(21)]]
    strap(ribbon(pts, (0, 0, 1), 0.075, 0.009), "pr_webbing", sharp=60)
    for s in (-1, 1):
        strap(B(s * 0.27 - 0.035, s * 0.27 + 0.035, 0.30, 0.38, 0.76, 0.84), "pr_steel", bevel=0.006)
    # Подставка за голенями, ремень голеней, манжеты лодыжек.
    frame(B(-0.33, 0.33, -0.22, -0.14, 0.10, 0.36), "pr_vinyl", bevel=0.025, segs=3)
    frame(B(-0.25, 0.25, -0.22, -0.12, 0.33, 0.36), "pr_steel_dark", bevel=0.004)
    for s in (-1, 1):
        frame(B(s * 0.30 - 0.02, s * 0.30 + 0.02, -0.14, -0.12, 0.08, 0.36), "pr_steel_dark", bevel=0.004)
    pts = [Vector((0.34 * math.sin(t), -0.18 - 0.18 * math.cos(t), 0.24))
           for t in [-math.pi / 2 + math.pi * i / 16 for i in range(17)]]
    strap(ribbon(pts, (0, 0, 1), 0.06, 0.008), "pr_webbing", sharp=60)
    for s in (-1, 1):
        strap(B(s * 0.34 - 0.03, s * 0.34 + 0.03, -0.22, -0.14, 0.21, 0.27), "pr_steel", bevel=0.005)
        ank = P.ring_rect(0.045, 0.058, 0.05, 24, axis="Z")
        ank.transform(T(s * 0.23, -0.29, 0.09))
        strap(ank, "pr_vinyl", bevel=0.006, angle=60)
        strap(ribbon([Vector((s * 0.23, -0.235, 0.09)), Vector((s * 0.23, -0.17, 0.12))], (1, 0, 0), 0.035, 0.006),
               "pr_webbing", sharp=60)
    # Полукожух-козырёк над головой (ось — X), рёбра, кронштейны, индикатор Заклятия.
    MH = T(0, 0.16, 1.14) @ rot(90, "Z")
    shell = arc_shell(0.40, 0.022, -55, 45, -0.24, 0.24, zc=0.0, segs=24)
    shell.transform(MH)
    frame(shell, "pr_armor", bevel=0.005, angle=50)
    for y in (-0.22, 0.0, 0.22):
        rib = arc_shell(0.415, 0.03, -58, 48, y - 0.02, y + 0.02, zc=0.0, segs=24)
        rib.transform(MH)
        frame(rib, "pr_steel_dark", bevel=0.004, angle=50)
    for s in (-1, 1):
        frame(B(s * 0.26 - 0.02, s * 0.26 + 0.02, 0.32, 0.44, 0.88, 1.44), "pr_steel_dark", bevel=0.006)
        frame(C(0.03, 0.025, (s * 0.29, 0.38, 1.30), "X", 20), "pr_steel", sharp=40)
    frame(C(0.028, 0.03, (0.295, 0.36, 1.08), "X", 20), "pr_steel_dark", bevel=0.004)
    frame(C(0.02, 0.012, (0.316, 0.36, 1.08), "X", 20), "pr_indicator", sharp=40, keep="spell_indicator")
    obj = hs.finish(ao=0.1, rays=16, ground=not straps, seed=17)
    if not straps:
        L.collision_box(hs.coll, hs.name + "_base", (0, 0.17, 0.2), (0.62, 0.7, 0.4))
        L.collision_box(hs.coll, hs.name + "_seat", (0, 0.1, 0.62), (0.8, 0.8, 0.5))
    return [obj]


# ======================================================================================
# Фасад участка (L01, бриф S3.3): модули на лицо объёма блок-аута, вход, столбик → `park/props/`
# ======================================================================================
def _facade_panel(hs, x0, x1, zc, h=2.4):
    """Бронепанель фасада (намёк на бронеплиты лобби): фаска, болты по углам и серединам кромок."""
    hs.add(B(x0, x1, -0.12, 0.0, zc - h / 2, zc + h / 2), "station_panel", bevel=0.02, segs=1)
    pts = [(x, -0.123, z) for x in (x0 + 0.08, (x0 + x1) / 2, x1 - 0.08) for z in (zc - h / 2 + 0.08, zc + h / 2 - 0.08)]
    hs.add(bolts(pts, "Y", r=0.02, h=0.012), "dark_metal", bevel=0.002, angle=50)


def _facade_bay(name, width, slit):
    """Модуль фасада шириной width (по стене объёма, лицо в −Y, начало — низ лица по центру, от 0,9 м — над
    цоколем блок-аута до карниза на 10 м): три бронепанели по рядам блок-аута (центры 2,2 / 4,8 / 7,4 м),
    карниз; slit — узкое окно-щель 0,3 × 3,2 м в раме у правого края (бриф S3: «узкие окна»)."""
    hs = HS(name)
    half = width / 2
    px1 = half - 0.1 - (0.5 if slit else 0.0)
    for zc in (2.2, 4.8, 7.4):
        _facade_panel(hs, -half + 0.1, px1, zc)
    hs.add(B(-half, half, -0.25, 0.0, 9.6, 10.0), "dark_metal", bevel=0.015)
    hs.add(B(-half, half, -0.06, 0.0, 0.9, 1.0), "dark_metal", bevel=0.006)
    if slit:
        sx = half - 0.33
        for b in (B(sx - 0.2, sx - 0.15, -0.16, 0.0, 3.3, 6.7), B(sx + 0.15, sx + 0.2, -0.16, 0.0, 3.3, 6.7),
                  B(sx - 0.2, sx + 0.2, -0.16, 0.0, 3.3, 3.4), B(sx - 0.2, sx + 0.2, -0.16, 0.0, 6.6, 6.7)):
            hs.add(b, "dark_metal", bevel=0.008)
        hs.add(B(sx - 0.15, sx + 0.15, -0.06, -0.04, 3.4, 6.6), "station_glass", flat=True)
    return [hs.finish(ao=0.15, ground=False, base_dark=0.0, seed=41 + int(width * 10))]


def station_facade_bay():
    """Модуль фасада 2,5 м: три бронепанели и карниз."""
    return _facade_bay("station_facade_bay", 2.5, slit=False)


def station_facade_slit():
    """Узкий модуль фасада 1,25 м с окном-щелью."""
    return _facade_bay("station_facade_slit", 1.25, slit=True)


def station_entrance():
    """Вход участка (бриф S3: «освещённый вход»): портал 3,6 × 3,4 м, ниша, двустворчатая стеклянная дверь
    1,7 × 2,5 м в стальной раме, бронепанели ниши, козырёк 4,6 × 2,4 м с полосой холодного света, панель вызова.
    Начало — низ середины проёма на плоскости стены; улица — −Y. Табличка участка остаётся `Label3D` сцены."""
    hs = HS("station_entrance")
    for b in (B(-1.8, -1.2, -0.5, 0.0, 0.0, 3.4), B(1.2, 1.8, -0.5, 0.0, 0.0, 3.4), B(-1.2, 1.2, -0.5, 0.0, 2.7, 3.4)):
        hs.add(b, "dark_metal", bevel=0.03, segs=2)
    hs.add(B(-1.2, 1.2, -0.5, 0.0, 0.0, 0.02), "dark_metal", bevel=0.004)
    for s in (-1, 1):
        x0, x1 = sorted((s * 0.88, s * 1.2))
        hs.add(B(x0, x1, -0.12, 0.0, 0.02, 2.7), "station_panel", bevel=0.01, segs=1)
    hs.add(B(-0.88, 0.88, -0.10, 0.0, 2.52, 2.7), "station_panel", bevel=0.008, segs=1)
    for s in (-1, 1):  # створки: рама, стекло, ручка-штанга, нижний отбойник
        x0, x1 = sorted((s * 0.005, s * 0.85))
        for b in (B(x0, x1, -0.16, -0.10, 0.02, 0.12), B(x0, x1, -0.16, -0.10, 2.42, 2.52),
                  B(x0, x0 + 0.06, -0.16, -0.10, 0.12, 2.42), B(x1 - 0.06, x1, -0.16, -0.10, 0.12, 2.42)):
            hs.add(b, "dark_metal", bevel=0.004)
        hs.add(B(x0 + 0.06, x1 - 0.06, -0.135, -0.125, 0.12, 2.42), "station_glass", flat=True)
        hs.add(B(x0 + 0.06, x1 - 0.06, -0.165, -0.16, 0.12, 0.4), "station_panel", bevel=0.003)
        hx = s * 0.12
        hs.add(P.tube([Vector((hx, -0.16, 0.9)), Vector((hx, -0.22, 0.9)), Vector((hx, -0.22, 1.5)),
                       Vector((hx, -0.16, 1.5))], 0.014, segs=10), "dark_metal", sharp=50)
    hs.add(B(-2.3, 2.3, -2.4, 0.0, 3.42, 3.67), "dark_metal", bevel=0.02)
    hs.add(B(-1.9, 1.9, -2.1, -0.3, 3.40, 3.42), "entrance_light", flat=True, keep="station_entrance_light")
    for s in (-1, 1):
        hs.add(P.tube([Vector((s * 1.9, -2.2, 3.67)), Vector((s * 1.9, -0.02, 5.2))], 0.025, segs=10), "dark_metal",
               sharp=50)
    hs.add(B(1.3, 1.5, -0.535, -0.5, 1.15, 1.45), "dark_metal", bevel=0.005)
    hs.add(B(1.33, 1.47, -0.537, -0.535, 1.3, 1.42), "entrance_light", flat=True)
    obj = hs.finish(ao=0.2, ground=True, base_dark=0.0, seed=44)
    for nm, cx in (("_l", -1.5), ("_r", 1.5)):
        L.collision_box(hs.coll, hs.name + nm, (cx, -0.25, 1.7), (0.6, 0.5, 3.4))
    L.collision_box(hs.coll, hs.name + "_doors", (0, -0.13, 1.27), (2.4, 0.06, 2.5))
    return [obj]


def bollard_a():
    """Ограждающий столбик 0,9 м (блок-аут: радиус 0,12): основание, корпус, светлая полоса, скруглённый верх."""
    hs = HS("bollard_a")
    hs.add(C(0.15, 0.02, (0, 0, 0.01), "Z", 24), "dark_metal", bevel=0.004)
    hs.add(P.lathe([(0.11, 0.02), (0.11, 0.84), (0.09, 0.885), (0.05, 0.9), (0.002, 0.902)], segs=24),
           "dark_metal", sharp=50)
    hs.add(C(0.112, 0.04, (0, 0, 0.74), "Z", 24), "lamp_lens", sharp=50)
    obj = hs.finish(ao=0.1, ground=True, base_dark=0.0, seed=45)
    L.collision_box(hs.coll, hs.name, (0, 0, 0.45), (0.24, 0.24, 0.9))
    return [obj]


# ======================================================================================
# Лобби участка (L02)
# ======================================================================================
def _armor_bolts(half, z0, z1, y, step=0.42, inset=0.07):
    pts = []
    nx = max(2, round((2 * half - 2 * inset) / step) + 1)
    for i in range(nx):
        x = -half + inset + (2 * half - 2 * inset) * i / (nx - 1)
        pts += [(x, y, z0 + inset), (x, y, z1 - inset)]
    nz = max(2, round((z1 - z0 - 2 * inset) / step) + 1)
    for j in range(1, nz - 1):
        z = z0 + inset + (z1 - z0 - 2 * inset) * j / (nz - 1)
        pts += [(-half + inset, y, z), (half - inset, y, z)]
    return bolts(pts, "Y", r=0.022, h=0.014)


def armor_plate_a():
    """Бронеплита 2,6 × 3,2 × 0,12 м (канон гл. 1: «армированные бронеплиты»; размер — CSG лобби):
    толстая плита с крупной фаской на кронштейнах (зазор до стены), два ребра жёсткости, болты по контуру,
    табличка номера. Начало — пол у стены; лицо в −Y; плита от 0,3 до 3,5 м."""
    hs = HS("armor_plate_a")
    h0, h1, half = 0.30, 3.50, 1.30
    hs.add(B(-half + 0.01, half - 0.01, -0.12, -0.012, h0, h1), "pr_armor", bevel=0.022, segs=1)
    for z in (h0 + 0.1, h1 - 0.18):
        hs.add(join_bm([B(x - 0.08, x + 0.08, -0.012, 0.0, z, z + 0.08) for x in (-0.95, 0.95)]), "pr_steel_dark",
               bevel=0.004)
    for z in (1.30, 2.42):
        hs.add(B(-half + 0.08, half - 0.08, -0.15, -0.12, z, z + 0.12), "pr_armor", bevel=0.01, segs=1)
    hs.add(_armor_bolts(half - 0.01, h0, h1, -0.127), "pr_steel", bevel=0.003, angle=50)
    hs.add(B(0.72, 1.06, -0.128, -0.12, 3.18, 3.30), "pr_marking", bevel=0.002)
    hs.add(B(0.76, 1.02, -0.13, -0.128, 3.21, 3.27), "pr_rubber")
    obj = hs.finish(ground=True, seed=21)
    L.collision_box(hs.coll, hs.name, (0, -0.06, (h0 + h1) / 2), (2.6, 0.12, h1 - h0))
    return [obj]


def armor_plate_b():
    """Бронеплита 1,3 × 3,2 м (узкий вариант): вертикальное ребро сверху, смотровой люк на болтах с ручкой."""
    hs = HS("armor_plate_b")
    h0, h1, half = 0.30, 3.50, 0.65
    hs.add(B(-half + 0.01, half - 0.01, -0.12, -0.012, h0, h1), "pr_armor", bevel=0.022, segs=1)
    for z in (h0 + 0.1, h1 - 0.18):
        hs.add(B(-0.08, 0.08, -0.012, 0.0, z, z + 0.08), "pr_steel_dark", bevel=0.004)
    hs.add(B(-0.06, 0.06, -0.15, -0.12, 2.0, h1 - 0.12), "pr_armor", bevel=0.01, segs=1)
    hs.add(B(-0.36, 0.36, -0.145, -0.12, 0.85, 1.65), "pr_armor", bevel=0.012, segs=1)
    hs.add(bolts([(x, -0.148, z) for x in (-0.31, 0.31) for z in (0.9, 1.6)], "Y", r=0.018, h=0.01), "pr_steel",
           bevel=0.002, angle=50)
    handle = [Vector((-0.12, -0.145, 1.25)), Vector((-0.12, -0.19, 1.25)), Vector((0.12, -0.19, 1.25)),
              Vector((0.12, -0.145, 1.25))]
    hs.add(P.tube(handle, 0.012, segs=10), "pr_steel", sharp=50)
    hs.add(_armor_bolts(half - 0.01, h0, h1, -0.127), "pr_steel", bevel=0.003, angle=50)
    obj = hs.finish(ground=True, seed=22)
    L.collision_box(hs.coll, hs.name, (0, -0.06, (h0 + h1) / 2), (1.3, 0.12, h1 - h0))
    return [obj]


def turret_nest_a():
    """Потолочное турельное гнездо (канон гл. 1: «плохо скрытые турельные гнёзда в потолке»): рама в потолке,
    шторки раздвинуты не до конца, турель висит ниже потолка — поворотное основание, вилка, орудийный
    модуль со стволом и датчиком. Начало — плоскость потолка (z = 0), всё ниже; ствол смотрит в −Y."""
    hs = HS("turret_nest_a")
    for b in (B(-0.40, 0.40, 0.28, 0.40, -0.04, 0.0), B(-0.40, 0.40, -0.40, -0.28, -0.04, 0.0),
              B(-0.40, -0.28, -0.28, 0.28, -0.04, 0.0), B(0.28, 0.40, -0.28, 0.28, -0.04, 0.0)):
        hs.add(b, "pr_armor", bevel=0.006)
    hs.add(bolts([(x, y, -0.042) for x in (-0.34, 0.34) for y in (-0.34, 0.0, 0.34)] +
                 [(0.0, y, -0.042) for y in (-0.34, 0.34)], "Z", r=0.012, h=0.006), "pr_steel")
    box = B(-0.28, 0.28, -0.28, 0.28, -0.04, 0.32)
    bmesh.ops.delete(box, geom=[f for f in box.faces if f.normal.z < -0.5], context="FACES")
    bmesh.ops.reverse_faces(box, faces=list(box.faces))
    hs.add(box, "pr_rubber", flat=True)
    hs.add(B(-0.28, -0.04, -0.28, 0.28, -0.03, -0.012), "pr_armor", bevel=0.004)   # шторка закрыта
    hs.add(B(0.16, 0.44, -0.28, 0.28, -0.048, -0.032), "pr_armor", bevel=0.004)    # шторка съехала за раму
    hs.add(C(0.04, 0.26, (0.06, 0, 0.0), "Z", 16), "pr_steel", sharp=40)
    hs.add(C(0.13, 0.05, (0.06, 0, -0.12), "Z", 28), "pr_steel_dark", bevel=0.008)
    for s in (-1, 1):
        hs.add(B(0.06 + s * 0.10 - 0.012, 0.06 + s * 0.10 + 0.012, -0.05, 0.05, -0.30, -0.14), "pr_steel_dark",
               bevel=0.005)
    MG = T(0.06, 0.0, -0.25) @ rot(-25, "X")
    hs.add(B(-0.075, 0.075, -0.18, 0.16, -0.07, 0.07, m=MG), "pr_armor", bevel=0.025, segs=3)
    hs.add(C(0.03, 0.18, (0, 0, 0), "X", 20, m=MG), "pr_steel", sharp=40)  # ось вилки
    hs.add(C(0.02, 0.34, (0.0, -0.35, -0.01), "Y", 16, m=MG), "pr_steel_dark", sharp=40)
    hs.add(C(0.03, 0.07, (0.0, -0.50, -0.01), "Y", 16, m=MG), "pr_steel_dark", bevel=0.004)
    hs.add(C(0.026, 0.03, (0.045, -0.18, 0.04), "Y", 16, m=MG), "pr_steel_dark", bevel=0.003)
    hs.add(C(0.017, 0.01, (0.045, -0.198, 0.04), "Y", 16, m=MG), "pr_sensor", sharp=40, keep="turret_sensor")
    hs.add(P.tube([MG @ Vector((0, 0.16, 0.0)), MG @ Vector((0, 0.22, 0.05)), Vector((0.06, 0.12, -0.02)),
                   Vector((0.06, 0.10, 0.2))], 0.016, segs=8), "pr_rubber", sharp=60)
    return [hs.finish(ao=0.08, ground=False, base_dark=0.0, seed=23)]


def desk_counter():
    """Стойка дежурного 4,0 × 0,8 × 1,1 м (CSG лобби): бронированный фронт с накладками на болтах, тёмный
    кант снизу, ступенька для посетителя на 1,1 м, рабочая поверхность на 0,76 м, тумба с ящиками,
    боковины. Фронт смотрит в −Y (ко входу). Терминал — отдельный ассет `terminal_desk`."""
    hs = HS("desk_counter")
    hs.add(B(-2.0, 2.0, -0.40, -0.30, 0.08, 1.05), "pr_armor", bevel=0.015, segs=1)
    hs.add(B(-1.98, 1.98, -0.36, -0.30, 0.0, 0.08), "pr_rubber", bevel=0.004)
    for x0, x1 in ((-1.94, -0.68), (-0.62, 0.62), (0.68, 1.94)):
        hs.add(B(x0, x1, -0.415, -0.40, 0.16, 0.97), "pr_armor", bevel=0.008, segs=1)
        hs.add(bolts([(x, -0.418, z) for x in (x0 + 0.05, x1 - 0.05) for z in (0.21, 0.92)], "Y", r=0.013, h=0.007),
               "pr_steel")
    hs.add(B(-2.03, 2.03, -0.47, -0.18, 1.05, 1.10), "pr_counter", bevel=0.006)
    hs.add(B(-2.0, 2.0, -0.30, 0.40, 0.72, 0.76), "pr_counter", bevel=0.004)
    for s in (-1, 1):
        hs.add(B(s * 1.98 - 0.02, s * 1.98 + 0.02, -0.30, 0.40, 0.0, 0.72), "pr_armor", bevel=0.006)
    hs.add(B(1.30, 1.92, -0.26, 0.36, 0.0, 0.70), "pr_steel_dark", bevel=0.008)
    for k in range(3):
        z0 = 0.06 + k * 0.215
        hs.add(B(1.33, 1.89, 0.36, 0.375, z0, z0 + 0.195), "pr_steel_dark", bevel=0.004)
        hs.add(B(1.54, 1.68, 0.375, 0.395, z0 + 0.15, z0 + 0.17), "pr_steel", bevel=0.003)
    hs.add(P.ring_rect(0.025, 0.035, 0.01, 16, axis="Z"), "pr_rubber", sharp=40)
    hs.objs[-1].data.transform(T(-1.2, 0.30, 0.765))
    obj = hs.finish(ground=True, seed=24)
    L.collision_box(hs.coll, hs.name + "_front", (0, -0.325, 0.55), (4.06, 0.30, 1.10))
    L.collision_box(hs.coll, hs.name + "_desk", (0, 0.05, 0.38), (4.0, 0.70, 0.76))
    return [obj]


def terminal_desk():
    """Терминал дежурного с кнопкой тревоги (канон гл. 1: «терминал с кнопкой тревоги», Code Black):
    монитор на кронштейне, клавиатура, грибовидная красная кнопка под откинутой прозрачной крышкой на
    жёлтой плашке. Начало — поверхность стола; экран смотрит в −Y (к дежурному)."""
    hs = HS("terminal_desk")
    hs.add(B(-0.12, 0.12, 0.02, 0.20, 0.0, 0.015), "pr_steel_dark", bevel=0.004)
    hs.add(B(-0.025, 0.025, 0.11, 0.15, 0.015, 0.25), "pr_steel_dark", bevel=0.006)
    MM = T(0, 0.10, 0.37) @ rot(-10, "X")
    hs.add(B(-0.31, 0.31, -0.03, 0.03, -0.20, 0.20, m=MM), "pr_wall_alt", bevel=0.012)
    hs.add(B(-0.29, 0.29, -0.034, -0.03, -0.18, 0.18, m=MM), "pr_rubber", bevel=0.002)
    hs.add(screen_quad(0.55, 0.34, MM @ T(0, -0.035, 0)), "pr_screen_lobby", uv=False, flat=True)
    hs.add(B(-0.22, 0.22, -0.30, -0.15, 0.0, 0.022), "pr_rubber", bevel=0.005)
    hs.add(B(-0.2, 0.2, -0.285, -0.165, 0.022, 0.026), "pr_steel_dark")
    hs.add(B(0.30, 0.44, -0.30, -0.16, 0.0, 0.012), "pr_marking", bevel=0.002)
    hs.add(C(0.045, 0.04, (0.37, -0.23, 0.032), "Z", 24), "pr_steel_dark", bevel=0.004)
    hs.add(P.lathe([(0.002, 0.052), (0.032, 0.052), (0.034, 0.062), (0.028, 0.072), (0.002, 0.076)], segs=24),
           "pr_alarm", sharp=60)
    hs.objs[-1].data.transform(T(0.37, -0.23, 0.0))
    MC = T(0.37, -0.16, 0.06) @ rot(-70, "X")
    hs.add(B(-0.06, 0.06, -0.006, 0.0, 0.0, 0.11, m=MC), "pr_glass", flat=True)
    hs.add(C(0.006, 0.12, (0.0, -0.003, 0.0), "X", 10, m=MC), "pr_steel", sharp=40)
    hs.add(P.tube([Vector((0, 0.19, 0.01)), Vector((0, 0.26, 0.004)), Vector((0.05, 0.34, 0.004))], 0.008, segs=8),
           "pr_rubber", sharp=60)
    return [hs.finish(ao=0.06, ground=True, base_dark=0.0, seed=25)]


def door_station_entrance():
    """Входная дверь-шлюз лобби 1,6 × 2,4 м (ART-DIRECTION; проём — CSG лобби): тяжёлая рама, две сдвижные
    створки с узкими смотровыми щелями, направляющая, полоса сигнального света, считыватель изнутри.
    Начало — низ середины проёма на плоскости стены; сторона лобби — −Y."""
    hs = HS("door_station_entrance")
    hs.add(B(-1.05, -0.80, -0.10, 0.30, 0.0, 2.75), "pr_armor", bevel=0.015, segs=1)
    hs.add(B(0.80, 1.05, -0.10, 0.30, 0.0, 2.75), "pr_armor", bevel=0.015, segs=1)
    hs.add(B(-0.80, 0.80, -0.10, 0.30, 2.40, 2.75), "pr_armor", bevel=0.015, segs=1)
    hs.add(B(-0.80, 0.80, 0.04, 0.13, -0.006, 0.004), "pr_steel", bevel=0.002)
    for s in (-1, 1):
        x0, x1 = sorted((s * 0.004, s * 0.80))
        sx0, sx1 = (x0 + x1) / 2 - 0.05, (x0 + x1) / 2 + 0.05
        for b in (B(x0, sx0, 0.05, 0.12, 0.0, 2.40), B(sx1, x1, 0.05, 0.12, 0.0, 2.40),
                  B(sx0, sx1, 0.05, 0.12, 0.0, 1.20), B(sx0, sx1, 0.05, 0.12, 2.10, 2.40)):
            hs.add(b, "pr_steel_dark", bevel=0.004)
        hs.add(B(sx0, sx1, 0.08, 0.09, 1.20, 2.10), "pr_glass", flat=True)
        hs.add(B(x0 + 0.06, x1 - 0.06, 0.045, 0.05, 0.9, 1.0), "pr_marking", bevel=0.002)
    hs.add(B(-0.62, 0.62, -0.125, -0.10, 2.50, 2.53), "pr_lamp_warn", bevel=0.003, keep="door_status_strip")
    hs.add(B(1.12, 1.24, -0.03, 0.0, 1.10, 1.34), "pr_steel_dark", bevel=0.006)
    hs.add(screen_quad(0.08, 0.06, T(1.18, -0.031, 1.27)), "pr_screen_lobby", uv=False, flat=True)
    obj = hs.finish(ground=True, seed=26)
    for nm, cx in (("_l", -0.925), ("_r", 0.925)):
        L.collision_box(hs.coll, hs.name + nm, (cx, 0.10, 1.375), (0.25, 0.40, 2.75))
    L.collision_box(hs.coll, hs.name + "_top", (0, 0.10, 2.575), (1.6, 0.40, 0.35))
    L.collision_box(hs.coll, hs.name + "_leaves", (0, 0.085, 1.2), (1.6, 0.07, 2.4))
    return [obj]


def ceiling_light_lobby():
    """Линейный светильник лобби 2,4 × 0,4 м (панели CSG лобби) — тот же генератор, что у изолятора."""
    return [_ceiling_light("ceiling_light_lobby", 2.4, 0.40, depth=0.07)]


# ======================================================================================
# Парк (L01): искусственные деревья в кадках и фонарь — в `park/props/`, материалы парка
# ======================================================================================
def _planter(hs):
    """Кадка 1,3 × 1,3 × 0,5 м (блок-аут): светлый композит, теневой зазор цоколя, декоративная крошка."""
    hs.add(B(-0.62, 0.62, -0.62, 0.62, 0.0, 0.03), "dark_metal", bevel=0.004)
    w = 0.08
    for b in (B(-0.65, 0.65, -0.65, -0.65 + w, 0.03, 0.5), B(-0.65, 0.65, 0.65 - w, 0.65, 0.03, 0.5),
              B(-0.65, -0.65 + w, -0.65 + w, 0.65 - w, 0.03, 0.5), B(0.65 - w, 0.65, -0.65 + w, 0.65 - w, 0.03, 0.5)):
        hs.add(b, "composite_light", bevel=0.02, segs=3)
    hs.add(B(-0.57, 0.57, -0.57, 0.57, 0.03, 0.44), "composite_mid")
    hs.add(C(0.12, 0.05, (0, 0, 0.465), "Z", 16), "dark_metal", bevel=0.005)


def _trunk(hs, top):
    hs.add(C(0.08, top - 0.44, (0, 0, (0.44 + top) / 2), "Z", 12, r2=0.06), "composite_mid", sharp=50)


def tree_planter_a():
    """Искусственное дерево (вариант A): нарочито правильный многогранник кроны (икосаэдр, плоские грани)
    на прямом стволе с четырьмя распорками — «слишком правильная» холодная зелень (бриф S3)."""
    hs = HS("tree_planter_a")
    _planter(hs)
    _trunk(hs, 2.75)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        hs.add(P.tube([Vector((0, 0, 2.2)), Vector((0.55 * math.cos(a), 0.55 * math.sin(a), 2.6))], 0.018, segs=8),
               "dark_metal", sharp=50)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    bm.transform(T(0, 0, 3.1) @ Matrix.Diagonal((1.1, 1.1, 0.9, 1.0)))
    hs.add(bm, "foliage_plastic", flat=True)
    obj = hs.finish(ao=0.3, ground=True, seed=31)
    L.collision_box(hs.coll, hs.name, (0, 0, 0.25), (1.3, 1.3, 0.5))
    return [obj]


def tree_planter_b():
    """Вариант B: три ступенчатых «диска» кроны (двенадцатигранники) с просветами ствола между ярусами."""
    hs = HS("tree_planter_b")
    _planter(hs)
    _trunk(hs, 3.9)
    for r, z, h in ((1.15, 2.45, 0.42), (0.9, 3.0, 0.40), (0.6, 3.5, 0.38)):
        bm = P.cylinder(r, h, 12, "Z", radius2=r * 0.82)
        bm.transform(T(0, 0, z) @ rot(15, "Z"))
        hs.add(bm, "foliage_plastic", flat=True)
    obj = hs.finish(ao=0.3, ground=True, seed=32)
    L.collision_box(hs.coll, hs.name, (0, 0, 0.25), (1.3, 1.3, 0.5))
    return [obj]


def tree_planter_c():
    """Вариант C: высокая гранёная колонна-капсула (как стриженый кипарис) — вертикальный акцент."""
    hs = HS("tree_planter_c")
    _planter(hs)
    _trunk(hs, 2.1)
    prof = [(0.002, 1.85), (0.45, 1.95), (0.68, 2.2), (0.75, 2.6), (0.75, 3.7), (0.66, 4.1), (0.42, 4.4), (0.002, 4.5)]
    bm = P.lathe(prof, segs=10)
    hs.add(bm, "foliage_plastic", flat=True)
    obj = hs.finish(ao=0.3, ground=True, seed=33)
    L.collision_box(hs.coll, hs.name, (0, 0, 0.25), (1.3, 1.3, 0.5))
    return [obj]


def lamp_street_a():
    """Тонкий современный фонарь 5,5 м (блок-аут: столб + голова 1,0 м с выносом): фланец на болтах,
    сужающийся столб, плоская голова с рассеивателем (утром выключен). Голова — в −Y."""
    hs = HS("lamp_street_a")
    hs.add(C(0.16, 0.03, (0, 0, 0.015), "Z", 24), "dark_metal", bevel=0.005)
    hs.add(bolts([(0.11 * math.cos(a), 0.11 * math.sin(a), 0.03) for a in (0.785, 2.356, 3.927, 5.498)], "Z",
                 r=0.014, h=0.012), "dark_metal")
    hs.add(C(0.075, 5.42, (0, 0, 0.03 + 2.71), "Z", 16, r2=0.05), "dark_metal", sharp=50)
    hs.add(B(-0.09, 0.09, -0.97, 0.05, 5.41, 5.49), "dark_metal", bevel=0.012)
    hs.add(B(-0.07, 0.07, -0.92, -0.06, 5.404, 5.41), "lamp_lens", bevel=0.002)
    obj = hs.finish(ao=0.1, ground=True, base_dark=0.0, seed=34)
    L.collision_box(hs.coll, hs.name, (0, 0, 2.75), (0.16, 0.16, 5.5))
    return [obj]


GROUPS = {
    "cell": [cell_wall_panel_a, cell_wall_panel_b, cell_wall_panel_c, cell_wall_window, cell_corner, cell_door_frame,
             vault_door, vault_door_inward, cell_floor, cell_ceiling, ceiling_light_cell, vent_grille, cell_terminal, cell_power_box,
             cell_ceiling_hatch, cell_camera],
    "chair": [restraint_chair, restraint_chair_upright, restraint_chair_upright_straps],
    "lobby": [armor_plate_a, armor_plate_b, turret_nest_a, desk_counter, terminal_desk, door_station_entrance,
              ceiling_light_lobby],
    "park": [tree_planter_a, tree_planter_b, tree_planter_c, lamp_street_a],
    "facade": [station_facade_bay, station_facade_slit, station_entrance, bollard_a],
}
OUT = {"cell": PR_DIR / "cell", "chair": PR_DIR / "cell", "lobby": PR_DIR / "lobby", "park": PARK_PROPS,
       "facade": PARK_PROPS}


# ======================================================================================
# Превью
# ======================================================================================
def inst(coll, loc=(0, 0, 0), rz=0.0, name=None):
    o = bpy.data.objects.new(name or "inst_" + coll.name, None)
    o.instance_type = "COLLECTION"
    o.instance_collection = coll
    L.preview_collection().objects.link(o)
    o.location = loc
    o.rotation_euler = (0, 0, math.radians(rz))
    return o


def look_cam(loc, target, lens=24.0):
    cam = bpy.data.objects.get("PreviewCam")
    if cam is None:
        cam = bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
        L.preview_collection().objects.link(cam)
    cam.data.lens = lens
    cam.data.clip_start = 0.02
    cam.location = loc
    d = Vector(target) - Vector(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    return cam


def area_light(name, loc, size, energy, color, rot_x=0.0):
    data = bpy.data.lights.new(name, "AREA")
    data.shape = "RECTANGLE"
    data.size, data.size_y = size
    data.energy = energy
    data.color = color
    o = bpy.data.objects.new(name, data)
    L.preview_collection().objects.link(o)
    o.location = loc
    o.rotation_euler = (math.radians(rot_x), 0, 0)
    return o


def cell_room(by, ox):
    """Бокс 3,6 × 4,4 × 2,45 м из модулей (раскладка бриф §3): дверь на Y = −2,2, смотровое стекло на дальней
    стене (Y = +2,2), терминал — правая стена у входа, решётка — верх дальней стены у угла."""
    p = []
    o = Vector((ox, 0, 0))

    def put(name, loc, rz=0.0):
        if name in by:
            p.append(inst(by[name], o + Vector(loc), rz))

    put("cell_floor", (0, 0, 0))
    put("cell_ceiling", (0, 0, 0))
    put("cell_wall_panel_a", (-1.25, 2.2, 0))
    put("cell_wall_window", (0.0, 2.2, 0))
    put("cell_wall_panel_b", (1.25, 2.2, 0))
    # Боковые стены: лицо модуля (−Y) поворотом +90° смотрит в +X (левая), −90° — в −X (правая).
    for k, nm in enumerate(("cell_wall_panel_a", "cell_wall_panel_c", "cell_wall_panel_a", "cell_wall_panel_b")):
        put(nm, (-1.8, -1.65 + 1.1 * k, 0), 90)
    for k, nm in enumerate(("cell_wall_panel_c", "cell_wall_panel_a", "cell_wall_panel_c", "cell_wall_panel_a")):
        put(nm, (1.8, -1.65 + 1.1 * k, 0), -90)
    put("cell_wall_panel_a", (-1.25, -2.2, 0), 180)
    for loc, rz in (((-1.8, 2.2, 0), 0), ((1.8, 2.2, 0), -90), ((1.8, -2.2, 0), 180), ((-1.8, -2.2, 0), 90)):
        put("cell_corner", loc, rz)
    put("cell_door_frame", (0.0, -2.2, 0), 180)
    put("cell_wall_panel_c", (1.25, -2.2, 0), 180)
    put("vault_door", (0.555, -2.30, 0.01), 180)
    put("restraint_chair", (-0.45, 0.20, 0))
    put("cell_terminal", (1.78, -1.35, 0), -90)
    put("vent_grille", (1.25, 2.18, 2.16))
    put("ceiling_light_cell", (-0.45, 0.35, ROOM_H))
    put("cell_power_box", (-1.78, -1.1, 0), 90)
    put("cell_ceiling_hatch", (0.7, 1.4, ROOM_H))
    put("cell_camera", (-1.5, 1.9, ROOM_H), -135)
    return p


def lobby_corner(by, ox):
    """Угол лобби (CSG 12 × 12 × 4 м): северная стена с бронеплитами, стойка с терминалом, турель в углу
    потолка, светильники; пол, стены и потолок — простые плоскости только для превью."""
    p = []
    o = Vector((ox, 0, 0))

    def put(name, loc, rz=0.0):
        if name in by:
            p.append(inst(by[name], o + Vector(loc), rz))

    for k, (nm, x) in enumerate((("armor_plate_a", -4.3), ("armor_plate_b", -2.25), ("armor_plate_a", -0.2),
                                 ("armor_plate_a", 2.6))):
        put(nm, (x, 6.0, 0))
    put("desk_counter", (0, 3.0, 0))
    put("terminal_desk", (0.9, 3.15, 0.76), 180)
    put("turret_nest_a", (-5.4, 5.4, 4.0), 45)    # ствол (−Y модели) — к центру зала
    put("turret_nest_a", (5.4, 5.4, 4.0), -45)
    put("ceiling_light_lobby", (0, 2.0, 4.0), 90)
    put("ceiling_light_lobby", (0, -2.5, 4.0), 90)
    put("door_station_entrance", (0, -6.0, 0), 180)
    bm = B(-6, 6, -6, 6, -0.02, 0.0)
    for nm, b in (("PrevFloor", bm), ("PrevCeil", B(-6, 6, -6, 6, 4.0, 4.02)), ("PrevWallN", B(-6, 6, 6.0, 6.2, 0, 4)),
                  ("PrevWallW", B(-6.2, -6.0, -6, 6, 0, 4)), ("PrevWallE", B(6.0, 6.2, -6, 6, 0, 4)),
                  ("PrevWallS", B(-6, 6, -6.3, -6.1, 0, 4))):
        b.transform(T(ox, 0, 0))
        ob = L.object_from_bmesh(nm, b, L.preview_collection(), "pr_floor" if nm == "PrevFloor" else "pr_wall_alt")
        L.uv_box(ob, 1.0)
        L.plain_masks(ob)
        p.append(ob)
    return p


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = argv[argv.index("--only") + 1].split(",") if "--only" in argv else list(GROUPS)
    test = argv[argv.index("--test") + 1] if "--test" in argv else None
    t0 = time.time()
    L.clear_data()
    by, group_of = {}, {}
    for g in only:
        for fn in GROUPS[g]:
            coll = fn()[0].users_collection[0]
            by[coll.name] = coll
            group_of[coll.name] = g
            tris = sum(L.tri_count(o) for o in coll.all_objects if o.type == "MESH" and not o.name.endswith("colonly"))
            print(f"BUILT {coll.name}: tris={tris} t={time.time() - t0:.1f}s", flush=True)
    if not test:
        for name, coll in by.items():
            L.export_collection(coll, OUT[group_of[name]] / f"{name}.glb")
    L.set_assets_visible(False)
    out_dir = Path(test).parent if test else PREVIEW_DIR
    prefix = (Path(test).stem + "_") if test else "prologue_"
    scene = L.setup_render(res=(1600, 900), samples=64 if test else 160, sun_elev=30, sun_az=-40, sun_power=0.0,
                           sky=(0.02, 0.025, 0.03), sky_strength=0.3)
    sun = bpy.data.objects["PreviewSun"]
    jobs = []
    if {"cell", "chair"} & set(only):
        jobs.append(("cell", cell_room(by, 0.0)))
    if "lobby" in only:
        jobs.append(("lobby", lobby_corner(by, 60.0)))
    rows = {}
    for g in ("cell", "chair", "lobby", "park", "facade"):
        names = [n for n in by if group_of[n] == g]
        if names:
            colls = [by[n] for n in names]
            placed, end = L.lineup(colls, spacing=0.6, axis="X", start=200.0 + 60 * len(rows))
            for o in placed:
                o.location.y = 300.0
                bpy.context.view_layer.update()
                zmin = min(pt.z for pt in L.world_points(o))
                if zmin < -0.01:  # потолочные и настенные (начало — у потолка/на стене): поднять над землёй
                    o.location.z -= zmin
            man = L.mannequin(location=(end + 0.4, 300.0 - 0.6, 0), name=f"ScaleRef_{g}")
            rows[g] = placed + [man]
    allp = [o for o in L.preview_collection().objects if o.type in ("EMPTY", "MESH")]
    gnd = None

    def show(objs):
        keep = set(objs)
        for o in allp:
            o.hide_render = o not in keep

    for name, objs in jobs:
        show(objs)
        sun.hide_render = True
        if name == "cell":
            lights = [area_light("CellFixture", (-0.45, 0.35, ROOM_H - 0.1), (0.18, 0.9), 70.0, (0.82, 0.93, 0.95)),
                      area_light("CellFill", (0.6, -1.6, ROOM_H - 0.05), (0.6, 0.6), 8.0, (0.7, 0.75, 0.8))]
            # Старт от лица Санни (голова к дальней стене, взгляд вдоль тела к двери): светильник и потолок
            # вверху кадра, терминал — в боковом зрении (бриф §4).
            look_cam((-0.45, 0.98, 1.16), (-0.3, -1.6, 1.85), lens=24)
            L.render(str(out_dir / f"{prefix}cell_start.jpg"))
            look_cam((1.55, -2.05, 1.75), (-0.55, 0.9, 0.75), lens=17)
            L.render(str(out_dir / f"{prefix}cell_overview.jpg"))
            look_cam((0.5, 0.78, 1.22), (-0.09, 1.19, 1.02), lens=35)
            L.render(str(out_dir / f"{prefix}cell_indicator.jpg"))
            look_cam((-1.55, 1.95, 1.9), (0.2, -2.0, 1.0), lens=17)
            L.render(str(out_dir / f"{prefix}cell_door.jpg"))
            for lt in lights:
                bpy.data.objects.remove(lt)
        if name == "lobby":
            # Люминесцентные панели (как OmniLight CSG-лобби) + два «светильника» у углов с турелями.
            lights = [area_light(f"LobbyFix{k}", (60.0 + x, y, 3.9), (2.4, 0.4), 420.0, (0.9, 0.95, 1.0))
                      for k, (x, y) in enumerate(((0, 2.0), (0, -2.5), (-3.5, 4.2), (3.5, 4.2)))]
            look_cam((60.4, -4.6, 1.65), (59.8, 3.5, 1.5), lens=22)
            L.render(str(out_dir / f"{prefix}lobby_entrance.jpg"))
            look_cam((62.6, 2.6, 1.6), (65.3, 5.3, 3.75), lens=30)
            L.render(str(out_dir / f"{prefix}lobby_turret.jpg"))
            for lt in lights:
                bpy.data.objects.remove(lt)
    # Ряды ассетов: дневной свет, светлая подложка.
    gnd = L.ground(size=600.0, z=0.0)
    gnd.location = (300.0, 300.0, 0.0)
    L.setup_render(res=(1600, 900), samples=64 if test else 160, sun_elev=35.0, sun_az=-35.0, sun_power=3.0,
                   sky=(0.45, 0.5, 0.56), sky_strength=0.8)
    sun.hide_render = False
    for g, objs in rows.items():
        show(objs + [gnd])
        L.frame_camera([o for o in objs if not o.name.startswith("ScaleRef")] + [objs[-1]],
                       direction=(-0.55, -1.0, 0.5), lens=40, margin=1.05)
        L.render(str(out_dir / f"{prefix}assets_{g}.jpg"))
    for o in allp:
        o.hide_render = False
    if not test:
        L.save_blend(SRC / "prologue_kit.blend")
    print("DONE", round(time.time() - t0, 1))


if __name__ == "__main__":
    main()

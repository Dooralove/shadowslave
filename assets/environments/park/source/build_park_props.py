"""S3.2: герой-объекты парка — ржавая скамейка, урна, стаканчик кофе.

Запуск (Blender 5.1, в фоне):
    blender -b --factory-startup --python build_park_props.py -- <папка вывода>

Каждый объект — отдельный .glb с началом координат у основания (стаканчик — в центре, как
узел `Props/CoffeeCup`, который двигает сценарий). Координаты — как в Godot, перевод — `g2b`.
Скамейка смотрит в −Z, верх сиденья на 0,48 м (на нём стоит стаканчик).
UV не нужны: материалы скамейки и урны в Godot трипланарные (`materials/*.tres`).
Коллизия — суффикс `-colonly` (простые ящики), визуальные меши без коллизии.
"""

import math
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

MATERIALS = {
    # имя слота: цвет-заглушка (в Godot подменяется внешним материалом)
    "bench_metal": (0.2, 0.22, 0.2),
    "bin_body": (0.62, 0.63, 0.64),
    "bin_dark": (0.07, 0.075, 0.08),
    "cup_paper": (0.86, 0.83, 0.77),
    "cup_sleeve": (0.42, 0.29, 0.18),
    "cup_lid": (0.12, 0.09, 0.07),
}

BENCH_LENGTH = 1.7
FRAME_X = 0.78
SEAT_TOP = 0.48


def g2b(x, y, z):
    return Vector((x, -z, y))


def material(name):
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*MATERIALS[name], 1.0)
    return mat


def _object(name, bm, mat, bevel=0.0):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(material(mat))
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    if bevel > 0.0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
    for poly in mesh.polygons:
        poly.use_smooth = False
    return obj


def box(name, center, size, mat, bevel=0.0, pitch_deg=0.0, roll_deg=0.0):
    """Ящик в осях Godot; pitch — наклон вокруг X (положительный — верх назад, к +Z)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    sx, sy, sz = size
    rot = Matrix.Rotation(math.radians(pitch_deg), 4, "X") @ Matrix.Rotation(math.radians(roll_deg), 4, "Y")
    bmesh.ops.transform(bm, matrix=Matrix.Translation(g2b(*center)) @ rot @ Matrix.Diagonal((sx, sz, sy, 1.0)),
                        verts=bm.verts)
    return _object(name, bm, mat, bevel)


def beam(name, x, start, end, width, depth, mat, bevel=0.004):
    """Брусок профиля боковины в плоскости YZ: от точки start (y, z) к end (y, z)."""
    (y0, z0), (y1, z1) = start, end
    length = math.hypot(y1 - y0, z1 - z0)
    # Наклон оси бруска от вертикали Godot (+Y) к +Z.
    pitch = math.degrees(math.atan2(z1 - z0, y1 - y0))
    return box(name, (x, (y0 + y1) / 2, (z0 + z1) / 2), (width, length, depth), mat, bevel, pitch_deg=pitch)


def cylinder(name, base, radius, height, mat, segments=24, radius_top=None, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius,
                          radius2=radius if radius_top is None else radius_top, depth=height)
    x, y, z = base
    bmesh.ops.translate(bm, vec=g2b(x, y + height / 2, z), verts=bm.verts)
    return _object(name, bm, mat, bevel)


def bolt(name, center, axis, mat):
    """Головка болта: короткий цилиндр, ось "x" или "z" Godot."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=0.008, radius2=0.008, depth=0.006)
    rot = Matrix.Rotation(math.radians(90), 4, "Y") if axis == "x" else Matrix.Rotation(math.radians(90), 4, "X")
    bmesh.ops.transform(bm, matrix=Matrix.Translation(g2b(*center)) @ rot, verts=bm.verts)
    return _object(name, bm, mat)


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def export(path):
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, export_yup=True,
                              export_lights=False, export_cameras=False)
    tris = sum(len(p.vertices) - 2 for o in bpy.context.scene.objects if o.type == "MESH"
               for p in o.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.polygons)
    print("EXPORTED", path, "TRIS", tris)


def build_bench():
    """Старая стальная скамейка: две боковины из полосы, рейки сиденья и спинки, болты.

    Следы времени (ИНТЕРПРЕТАЦИЯ): одна рейка спинки чуть просела, на одном конце нет болта.
    Ржавчина и облезлая краска — в материале."""
    m = "bench_metal"
    for side, x in (("L", -FRAME_X), ("R", FRAME_X)):
        beam(f"FrontLeg{side}", x, (0.0, -0.21), (0.45, -0.18), 0.045, 0.04, m)
        beam(f"RearLeg{side}", x, (0.0, 0.25), (0.44, 0.15), 0.045, 0.04, m)
        beam(f"SeatBearer{side}", x, (0.455, -0.24), (0.43, 0.20), 0.045, 0.035, m)
        beam(f"BackPost{side}", x, (0.43, 0.17), (0.90, 0.31), 0.045, 0.035, m)
        beam(f"ArmPost{side}", x, (0.45, -0.20), (0.66, -0.19), 0.04, 0.035, m)
        box(f"Armrest{side}", (x, 0.67, 0.0), (0.06, 0.03, 0.46), m, bevel=0.008)
        box(f"FootFront{side}", (x, 0.01, -0.21), (0.07, 0.02, 0.08), m, bevel=0.004)
        box(f"FootRear{side}", (x, 0.01, 0.25), (0.07, 0.02, 0.08), m, bevel=0.004)
    box("Stretcher", (0.0, 0.14, 0.03), (FRAME_X * 2, 0.03, 0.03), m, bevel=0.004)

    # Рейки сиденья: верх 0.48 м, лёгкий наклон назад вслед за опорой.
    for i in range(5):
        z = -0.19 + i * 0.088
        y = SEAT_TOP - 0.0125 - (z + 0.19) * 0.055
        box(f"SeatSlat{i}", (0.0, y, z), (BENCH_LENGTH, 0.025, 0.07), m, bevel=0.005)
        for side, x in (("L", -FRAME_X), ("R", FRAME_X)):
            if not (i == 3 and side == "R"):
                bolt(f"SeatBolt{i}{side}", (x, y + 0.014, z), "y", m)
    # Рейки спинки по линии стоек; средняя чуть просела в центре (наклон по длине).
    for i in range(3):
        t = 0.25 + i * 0.3
        y = 0.43 + (0.90 - 0.43) * t
        z = 0.17 + (0.31 - 0.17) * t - 0.03
        roll = 0.6 if i == 1 else 0.0
        box(f"BackSlat{i}", (0.0, y, z), (BENCH_LENGTH, 0.085, 0.022), m, bevel=0.005,
            pitch_deg=math.degrees(math.atan2(0.14, 0.47)), roll_deg=roll)
    # Коллизия: сиденье и спинка (сидя физика Санни выключена, но прохожие и камера упираются).
    box("SeatCollision-colonly", (0.0, 0.24, 0.0), (BENCH_LENGTH + 0.1, 0.48, 0.5), m)
    box("BackCollision-colonly", (0.0, 0.68, 0.24), (BENCH_LENGTH + 0.1, 0.42, 0.1), m)


def build_bin():
    """Новая «умная» урна: композитный корпус, тёмная щель приёма, крышка. Верх 0.85 м."""
    cylinder("Plinth", (0, 0.0, 0), 0.22, 0.04, "bin_dark", segments=32)
    cylinder("Body", (0, 0.04, 0), 0.25, 0.58, "bin_body", segments=40, bevel=0.01)
    cylinder("Slot", (0, 0.62, 0), 0.232, 0.1, "bin_dark", segments=40)
    cylinder("Collar", (0, 0.72, 0), 0.25, 0.08, "bin_body", segments=40, bevel=0.008)
    cylinder("Lid", (0, 0.80, 0), 0.255, 0.035, "bin_dark", segments=40, radius_top=0.24, bevel=0.006)
    cylinder("LidCap", (0, 0.835, 0), 0.12, 0.015, "bin_body", segments=32)
    cylinder("BinCollision-colonly", (0, 0.0, 0), 0.26, 0.85, "bin_body", segments=12)


def build_cup():
    """Бумажный стаканчик с крышкой и манжетой: начало координат в центре, высота 0.12 м."""
    cylinder("Cup", (0, -0.06, 0), 0.032, 0.105, "cup_paper", segments=24, radius_top=0.042)
    cylinder("Sleeve", (0, -0.025, 0), 0.0355, 0.045, "cup_sleeve", segments=24, radius_top=0.0395)
    cylinder("Lid", (0, 0.045, 0), 0.044, 0.008, "cup_lid", segments=24)
    cylinder("LidTop", (0, 0.053, 0), 0.04, 0.007, "cup_lid", segments=24, radius_top=0.036)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = argv[0] if argv else "."
    for name, build in (("bench", build_bench), ("bin", build_bin), ("cup", build_cup)):
        clear()
        build()
        export(f"{out}/{name}.glb")


main()

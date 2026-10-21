"""S3.1: блок-аут парка у участка (E3) — тональные объёмы в реальном масштабе.

Запуск (Blender 5.1, в фоне):
    blender -b --factory-startup --python build_park_blockout.py -- <out.glb>

Координаты в скрипте — как в Godot (X вправо, Y вверх, −Z к участку), в Blender
переводятся функцией `g2b`. Игровые точки `park_street.tscn` не двигаются: скамейка
в (0, 0, 4) смотрит на участок, урна в (2.2, 0, 3.2), дверь участка на z = −19, пол на y = 0.
Скамейка, урна и стаканчик — отдельные модели `build_park_props.py` (S3.2).
Пол и все поверхности ходьбы — на одной высоте, бордюры только визуальные.

Суффикс имени `-col` — Godot создаёт статическое тело с коллизией по мешу,
`-colonly` — только коллизия. План и решения — `docs/production/s3_park_brief.md`.
"""

import math
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

SEED = 7

# Цвета — тональный блок-аут: роли материалов различимы, текстур нет (S3.2+).
MATERIALS = {
    # имя: (цвет, шероховатость, металличность, эмиссия)
    "paving_park": ((0.44, 0.45, 0.46), 0.75, 0.0, 0.0),
    "paving_old": ((0.24, 0.23, 0.22), 0.9, 0.0, 0.0),
    "sidewalk": ((0.38, 0.39, 0.41), 0.8, 0.0, 0.0),
    "curb": ((0.30, 0.31, 0.33), 0.7, 0.0, 0.0),
    "asphalt": ((0.065, 0.07, 0.075), 0.85, 0.0, 0.0),
    "marking": ((0.82, 0.83, 0.83), 0.6, 0.0, 0.0),
    "lawn": ((0.13, 0.25, 0.20), 0.55, 0.0, 0.0),
    "foliage": ((0.10, 0.22, 0.17), 0.4, 0.0, 0.0),
    "composite_light": ((0.56, 0.57, 0.58), 0.45, 0.0, 0.0),
    "composite_mid": ((0.46, 0.48, 0.51), 0.5, 0.0, 0.0),
    "station": ((0.075, 0.08, 0.09), 0.6, 0.3, 0.0),
    "station_panel": ((0.11, 0.115, 0.125), 0.5, 0.45, 0.0),
    "glass": ((0.10, 0.13, 0.17), 0.08, 0.7, 0.0),
    "dark_metal": ((0.08, 0.085, 0.09), 0.4, 0.8, 0.0),
    "tram": ((0.82, 0.84, 0.86), 0.25, 0.2, 0.0),
    "screen": ((0.55, 0.68, 0.80), 0.4, 0.0, 2.5),
    "entrance_light": ((0.70, 0.82, 1.0), 0.4, 0.0, 4.0),
    "far": ((0.50, 0.53, 0.58), 0.9, 0.0, 0.0),
}

PARK_HALF_X = 9.5


def g2b(x, y, z):
    return Vector((x, -z, y))


def material(name):
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    color, roughness, metallic, emission = MATERIALS[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission > 0.0:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def collection(name):
    coll = bpy.data.collections.get(name)
    if coll is None:
        coll = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(coll)
    return coll


def _object(name, mesh, mat, coll, bevel=0.0):
    obj = bpy.data.objects.new(name, mesh)
    mesh.materials.append(material(mat))
    collection(coll).objects.link(obj)
    if bevel > 0.0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        mod.limit_method = "ANGLE"
    return obj


def box(name, center, size, mat, coll, bevel=0.0, yaw_deg=0.0, pitch_deg=0.0):
    """Ящик: центр и размер в осях Godot; yaw — поворот вокруг вертикали, pitch — наклон вокруг X."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    sx, sy, sz = size
    scale = Matrix.Diagonal((sx, sz, sy, 1.0))
    rot = Matrix.Rotation(math.radians(yaw_deg), 4, "Z") @ Matrix.Rotation(math.radians(-pitch_deg), 4, "X")
    bmesh.ops.transform(bm, matrix=Matrix.Translation(g2b(*center)) @ rot @ scale, verts=bm.verts)
    bm.to_mesh(mesh)
    bm.free()
    return _object(name, mesh, mat, coll, bevel)


def slab(name, x0, x1, z0, z1, top, thickness, mat, coll, bevel=0.0):
    """Плита по границам X и Z (оси Godot) с верхом на высоте top."""
    return box(name, ((x0 + x1) / 2, top - thickness / 2, (z0 + z1) / 2),
               (x1 - x0, thickness, z1 - z0), mat, coll, bevel)


def strip(name, start, end, width, top, mat, coll):
    """Полоса дорожки от точки start к end (x, z) шириной width."""
    (x0, z0), (x1, z1) = start, end
    length = math.hypot(x1 - x0, z1 - z0)
    yaw = math.degrees(math.atan2(x1 - x0, -(z1 - z0)))
    # В Blender поворот вокруг Z против часовой; ось −Z Godot — это +Y Blender.
    return box(name, ((x0 + x1) / 2, top - 0.01, (z0 + z1) / 2), (width, 0.02, length), mat, coll, yaw_deg=-yaw)


def cylinder(name, base, radius, height, mat, coll, segments=16, radius_top=None):
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius,
                          radius2=radius if radius_top is None else radius_top, depth=height)
    x, y, z = base
    bmesh.ops.translate(bm, vec=g2b(x, y + height / 2, z), verts=bm.verts)
    bm.to_mesh(mesh)
    bm.free()
    return _object(name, mesh, mat, coll)


def crown(name, center, radii, mat, coll):
    """Крона искусственного дерева: нарочито правильный многогранник."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    rx, ry, rz = radii
    bmesh.ops.transform(bm, matrix=Matrix.Translation(g2b(*center)) @ Matrix.Diagonal((rx, rz, ry, 1.0)), verts=bm.verts)
    bm.to_mesh(mesh)
    bm.free()
    return _object(name, mesh, mat, coll)


# --- Части локации ----------------------------------------------------------------

def build_ground():
    c = "Ground"
    # Невидимая коллизия пола на y = 0 под всей играбельной зоной.
    slab("Floor-colonly", -60, 60, -40, 30, 0.0, 1.0, "curb", c)
    # Улица вдоль X уходит далеко в дымку в обе стороны.
    slab("NearSidewalk", -140, 140, -7.6, -5.0, 0.0, 0.2, "sidewalk", c)
    slab("CurbNear", -140, 140, -7.8, -7.6, 0.012, 0.2, "curb", c)
    slab("Street", -140, 140, -15.4, -7.8, -0.004, 0.2, "asphalt", c)
    slab("CurbFar", -140, 140, -15.6, -15.4, 0.012, 0.2, "curb", c)
    slab("FarSidewalk", -140, 140, -19.6, -15.6, 0.0, 0.2, "sidewalk", c)
    # Разметка: осевая и пешеходный переход напротив двери участка (x = 0).
    for i in range(-30, 31):
        x = i * 4.5
        if abs(x) > 3.0:
            slab(f"LaneMark{i + 30:02d}", x - 1.1, x + 1.1, -11.68, -11.52, 0.003, 0.01, "marking", c)
    for i in range(7):
        z = -8.4 - i * 1.0
        slab(f"Zebra{i}", -2.0, 2.0, z - 0.25, z + 0.25, 0.003, 0.01, "marking", c)


def build_park():
    c = "Park"
    slab("Lawn", -PARK_HALF_X, PARK_HALF_X, -5.0, 8.6, 0.0, 0.2, "lawn", c)
    # Поперечная дорожка — по ней идёт прохожий A (z = 1).
    slab("PathCross", -PARK_HALF_X, PARK_HALF_X, 0.2, 1.8, 0.008, 0.02, "paving_park", c)
    # Карман скамейки: старая тёмная плитка в стороне от потока.
    slab("PocketOld", -1.7, 3.1, 1.8, 5.3, 0.01, 0.02, "paving_old", c)
    # Две дорожки сходятся к переходу — ведущие линии на участок.
    strip("PathWest", (-7.0, 1.0), (-0.6, -5.0), 1.6, 0.008, "paving_park", c)
    strip("PathEast", (5.0, 1.0), (0.6, -5.0), 1.6, 0.008, "paving_park", c)
    slab("PathMouth", -2.0, 2.0, -5.0, -3.6, 0.009, 0.02, "paving_park", c)

    # Задняя клумба-стенка и боковые бортики вместо забора.
    slab("BackWall-col", -PARK_HALF_X, PARK_HALF_X, 7.2, 8.6, 0.55, 0.6, "composite_light", c, bevel=0.02)
    slab("BackShrubs", -PARK_HALF_X + 0.3, PARK_HALF_X - 0.3, 7.4, 8.4, 1.05, 0.5, "foliage", c, bevel=0.08)
    for side, sign in (("West", -1), ("East", 1)):
        x0, x1 = sorted((sign * (PARK_HALF_X - 0.6), sign * PARK_HALF_X))
        slab(f"SideWall{side}-col", x0, x1, -4.6, 7.2, 0.45, 0.5, "composite_light", c, bevel=0.02)
    # Кромка газона вдоль тротуара.
    slab("LawnEdge", -PARK_HALF_X, PARK_HALF_X, -5.15, -5.0, 0.02, 0.05, "composite_mid", c)

    # Искусственные деревья в кадках (холодный зелёный, однотонные правильные кроны).
    trees = [(-6.2, 4.8, 1.0), (5.9, 5.6, 1.1), (-4.0, 6.2, 0.8), (-6.6, -2.6, 1.05), (6.8, -2.2, 0.95)]
    for i, (x, z, s) in enumerate(trees):
        slab(f"Planter{i}-col", x - 0.65, x + 0.65, z - 0.65, z + 0.65, 0.5, 0.5, "composite_light", c, bevel=0.03)
        cylinder(f"Trunk{i}", (x, 0.5, z), 0.08, 2.1 * s, "composite_mid", c, segments=8)
        crown(f"Crown{i}", (x, 0.5 + 2.6 * s, z), (1.1 * s, 0.9 * s, 1.1 * s), "foliage", c)

    # Фонари у тротуара; утром выключены.
    for i, (x, z) in enumerate([(-6.5, -7.25), (6.5, -7.25), (-10.0, -15.95), (13.0, -15.95)]):
        cylinder(f"LampPole{i}-col", (x, 0.0, z), 0.06, 5.5, "dark_metal", c, segments=10)
        box(f"LampHead{i}", (x, 5.45, z + (0.45 if z < -10 else -0.45)), (0.18, 0.08, 1.0), "dark_metal", c)


def build_station():
    c = "Station"
    front = -19.0
    # Тяжёлый закрытый объём, смещён вправо от двери: слева открывается глубина улицы.
    slab("StationMain-col", -5.5, 15.0, -30.0, front, 10.0, 10.0, "station", c, bevel=0.05)
    slab("StationTower-col", 6.5, 15.0, -30.0, -21.0, 18.0, 8.0, "station", c, bevel=0.05)
    slab("StationPlinth", -5.6, 15.1, front - 0.2, front + 0.1, 0.9, 0.9, "dark_metal", c)
    # Бронепанели фасада — сетка выступающих плит (намёк на бронеплиты лобби, ИНТЕРПРЕТАЦИЯ).
    for col in range(8):
        x = -4.3 + col * 2.5
        if -1.8 < x < 1.8:
            continue
        for row in range(3):
            y = 2.2 + row * 2.6
            box(f"ArmorPanel{col}{row}", (x, y, front + 0.06), (2.3, 2.4, 0.12), "station_panel", c, bevel=0.02)
    # Узкие окна-щели.
    for i, x in enumerate([-3.0, 3.1, 5.6, 8.1, 10.6, 13.1]):
        box(f"SlitWindow{i}", (x, 5.0, front + 0.13), (0.3, 3.2, 0.04), "glass", c)
    # Вход: портал, козырёк, дверь и световая полоса.
    box("EntranceFrame", (0.0, 1.7, front + 0.25), (3.6, 3.4, 0.5), "dark_metal", c, bevel=0.03)
    box("EntranceRecess", (0.0, 1.35, front + 0.36), (2.4, 2.7, 0.3), "station", c)
    box("Door", (0.0, 1.25, front + 0.52), (1.7, 2.5, 0.06), "glass", c)
    box("Canopy", (0.0, 3.55, front + 1.2), (4.6, 0.25, 2.4), "dark_metal", c, bevel=0.02)
    box("EntranceLightStrip", (0.0, 3.4, front + 1.2), (3.8, 0.04, 1.8), "entrance_light", c)
    # Ограждающие столбики вдоль тротуара (проход к двери свободен).
    for i in range(14):
        x = -8.0 + i * 1.6
        if abs(x) < 2.6:
            continue
        cylinder(f"Bollard{i:02d}-col", (x, 0.0, -16.15), 0.12, 0.9, "dark_metal", c, segments=12)


def build_backdrop():
    c = "Backdrop"
    # За скамейкой: стеклянный цоколь жилой башни с экраном-пейзажем (SECONDARY).
    slab("PodiumGlass-col", -34.0, 34.0, 9.6, 17.0, 7.5, 7.5, "glass", c)
    for i in range(23):
        x = -33.0 + i * 3.0
        box(f"PodiumFin{i:02d}", (x, 3.75, 9.55), (0.35, 7.5, 0.3), "composite_light", c)
    slab("PodiumCornice", -34.2, 34.2, 9.3, 17.0, 8.3, 0.8, "composite_light", c, bevel=0.03)
    box("ScreenFrame", (-3.0, 4.3, 9.42), (8.6, 5.1, 0.12), "dark_metal", c)
    box("Screen", (-3.0, 4.3, 9.34), (8.0, 4.5, 0.04), "screen", c)
    # Башни над цоколем и мост между ними. Солнце с юго-востока, поэтому высокое — только
    # на западе: тени башен уходят на северо-запад мимо парка, скамейку закрывает тень цоколя.
    slab("TowerSouthWest", -30.0, -6.0, 18.0, 34.0, 82.0, 74.0, "composite_light", c)
    slab("TowerSouthWestGlass", -29.0, -7.0, 17.6, 18.2, 80.0, 70.0, "glass", c)
    slab("TowerWest", -56.0, -38.0, 14.0, 30.0, 58.0, 50.0, "glass", c)
    slab("SkyBridge", -38.0, -30.0, 22.0, 25.5, 44.0, 3.0, "composite_light", c)

    # Площадки по сторонам парка (видимый пол вокруг).
    slab("PlazaWest", -60.0, -PARK_HALF_X, -5.0, 9.6, 0.0, 0.2, "sidewalk", c)
    slab("PlazaEast", PARK_HALF_X, 60.0, -5.0, 9.6, 0.0, 0.2, "sidewalk", c)
    # Кварталы по сторонам парка: запад высокий, восток — низкий павильон (не затеняет парк).
    slab("BlockWest", -34.0, -13.0, -4.0, 9.0, 18.0, 18.0, "composite_light", c)
    slab("BlockWestGlass", -33.0, -13.5, -4.4, -3.8, 16.0, 12.0, "glass", c)
    slab("PavilionEast", 16.0, 36.0, -3.0, 9.0, 8.0, 8.0, "glass", c)
    slab("PavilionEastRoof", 15.6, 36.4, -3.4, 9.4, 8.5, 0.5, "composite_light", c)
    # Северная сторона улицы: слева разрыв (переулок в дымку), справа плотная застройка.
    slab("BlockNorthWest", -40.0, -12.0, -40.0, -22.0, 22.0, 22.0, "composite_light", c)
    slab("BlockNorthWestGlass", -39.0, -13.0, -22.4, -21.8, 20.0, 14.0, "glass", c)
    slab("BlockNorthEast", 16.0, 44.0, -40.0, -20.0, 28.0, 28.0, "glass", c)

    rng = random.Random(SEED)
    # Ряды вдоль улицы за пределами кадра парка.
    for side, z0, z1 in (("N", -44.0, -21.0), ("S", -4.0, 12.0)):
        for direction in (-1, 1):
            x = 36.0 if side == "S" else 46.0
            i = 0
            while x < 140.0:
                width = rng.uniform(14.0, 24.0)
                height = rng.uniform(16.0, 42.0)
                setback = rng.uniform(0.0, 3.0)
                x0, x1 = sorted((direction * x, direction * (x + width)))
                zz0, zz1 = (z0 - setback, z1 - setback) if side == "N" else (z0 + setback, z1 + setback)
                mat = "glass" if rng.random() < 0.45 else "composite_light"
                slab(f"Row{side}{'W' if direction < 0 else 'E'}{i:02d}", x0, x1, zz0, zz1, height, height, mat, c)
                x += width + rng.uniform(0.5, 3.0)
                i += 1


def build_tram():
    c = "Tram"
    # Эстакада магнитного трамвая над улицей (SECONDARY): горизонталь среднего плана.
    z = -11.6
    slab("Guideway", -160.0, 160.0, z - 1.3, z + 1.3, 9.4, 1.2, "composite_light", c, bevel=0.05)
    slab("GuidewayRail", -160.0, 160.0, z - 0.35, z + 0.35, 9.7, 0.3, "dark_metal", c)
    for i, x in enumerate(range(-150, 151, 34)):
        if abs(x) < 12:
            continue
        box(f"Pylon{i:02d}", (x, 4.1, z), (1.3, 8.2, 1.6), "composite_mid", c, bevel=0.05)
        box(f"PylonCap{i:02d}", (x, 8.5, z), (1.6, 0.6, 3.2), "composite_mid", c, bevel=0.05)
    # Состав стоит частично в кадре.
    box("TramBody", (-19.0, 11.1, z), (14.0, 2.6, 2.7), "tram", c, bevel=0.35)
    box("TramWindows", (-19.0, 11.4, z), (12.6, 0.8, 2.75), "glass", c)


def build_far():
    c = "Far"
    rng = random.Random(SEED + 1)
    # Дальний план: башни 80–300 м, растворяются в дымке.
    for i in range(26):
        angle = rng.uniform(-math.pi, math.pi)
        dist = rng.uniform(110.0, 320.0)
        x, z = math.sin(angle) * dist, -math.cos(angle) * dist
        w = rng.uniform(18.0, 42.0)
        d = rng.uniform(18.0, 42.0)
        h = rng.uniform(70.0, 260.0)
        slab(f"FarTower{i:02d}", x - w / 2, x + w / 2, z - d / 2, z + d / 2, h, h, "far", c)
        if rng.random() < 0.3:
            slab(f"FarTowerCap{i:02d}", x - w / 3, x + w / 3, z - d / 3, z + d / 3, h + 18.0, 18.0, "far", c)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = argv[0] if argv else "park_blockout.glb"
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build_ground()
    build_park()
    build_station()
    build_backdrop()
    build_tram()
    build_far()
    tris = 0
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            tris += sum(len(p.vertices) - 2 for p in obj.evaluated_get(depsgraph).data.polygons)
    print(f"OBJECTS {len(bpy.context.scene.objects)} TRIS {tris}")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_apply=True,
                              export_yup=True, export_lights=False, export_cameras=False)
    print("EXPORTED", out)


main()

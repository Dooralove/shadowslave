"""P2 real-world kit: park facades/street furniture + lobby/cell dressing.

Outputs GLBs into assets/environments/park/p2/ and prologue/p2/.
Blender 5.1, procedural hierarchy, no external models. Run:
  blender -b --python assets/environments/park/source/build_p2_kit.py
"""
from __future__ import annotations

import math
import os

import bpy
import bmesh
from mathutils import Vector


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
PARK_OUT = os.path.join(ROOT, "assets", "environments", "park", "p2")
PROLOGUE_OUT = os.path.join(ROOT, "assets", "environments", "prologue", "p2")


def mat(name, color, metallic=0.0, roughness=0.7, alpha=1.0, emission=None, emission_strength=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, alpha)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Alpha"].default_value = alpha
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    if alpha < 1.0:
        m.surface_render_method = "DITHERED"
    return m


def cube(name, center, size, material, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = Vector((size[0], size[1], size[2]))
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(35)
        mod.harden_normals = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.materials.append(material)
    return obj


def cylinder(name, center, radius, depth, material, axis="Z", segments=16, bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=segments, radius=radius, depth=depth, location=center)
    obj = bpy.context.object
    obj.name = name
    if axis == "X":
        obj.rotation_euler[1] = math.radians(90)
    elif axis == "Y":
        obj.rotation_euler[0] = math.radians(90)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if bevel:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.materials.append(material)
    return obj


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def export_objects(objects, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=False,
        export_morph=False,
        export_yup=True,
        export_texcoords=True,
        export_normals=True,
    )
    print("BUILT", path, "objects", len(objects))


# ---------------------------------------------------------------------------
# shared materials
# ---------------------------------------------------------------------------

def materials():
    return {
        "concrete": mat("p2_concrete", (0.48, 0.49, 0.51), 0.0, 0.82),
        "concrete_dark": mat("p2_concrete_dark", (0.24, 0.25, 0.27), 0.05, 0.75),
        "stone": mat("p2_stone", (0.37, 0.38, 0.40), 0.0, 0.88),
        "glass": mat("p2_glass", (0.035, 0.055, 0.075), 0.76, 0.06),
        "glass_clear": mat("p2_glass_clear", (0.22, 0.31, 0.38), 0.3, 0.07, 0.26),
        "metal": mat("p2_metal", (0.12, 0.13, 0.14), 0.82, 0.34),
        "metal_light": mat("p2_metal_light", (0.40, 0.42, 0.44), 0.65, 0.32),
        "wood": mat("p2_wood", (0.27, 0.18, 0.11), 0.0, 0.8),
        "lit": mat("p2_lit", (0.75, 0.70, 0.52), 0.0, 0.55, 1.0, (1.0, 0.72, 0.38), 2.0),
        "sign": mat("p2_sign", (0.025, 0.035, 0.045), 0.3, 0.42),
        "alarm": mat("p2_alarm", (0.22, 0.012, 0.006), 0.0, 0.4, 1.0, (0.6, 0.005, 0.002), 1.2),
        "rubber": mat("p2_rubber", (0.06, 0.065, 0.07), 0.0, 0.92),
    }


M = materials()


# ---------------------------------------------------------------------------
# park
# ---------------------------------------------------------------------------

def station_entrance():
    objs = []
    objs.append(cube("back", (0, 0.35, 2.6), (4.4, 0.7, 5.2), M["concrete"], 0.025))
    objs.append(cube("left_pier", (-2.0, -0.25, 2.6), (0.45, 1.0, 5.2), M["concrete_dark"], 0.02))
    objs.append(cube("right_pier", (2.0, -0.25, 2.6), (0.45, 1.0, 5.2), M["concrete_dark"], 0.02))
    objs.append(cube("lintel", (0, -0.22, 4.8), (4.5, 1.1, 0.45), M["concrete_dark"], 0.02))
    objs.append(cube("door_recess", (0, -0.62, 1.55), (2.35, 0.12, 2.8), M["glass"]))
    objs.append(cube("lobby_light", (0, -0.70, 1.6), (2.0, 0.02, 2.3), M["lit"]))
    for x in (-1.5, -0.75, 0.0, 0.75, 1.5):
        objs.append(cube("door_mullion_%s" % x, (x, -0.68, 1.55), (0.045, 0.08, 2.8), M["metal"], 0.006))
    objs.append(cube("door_header", (0, -0.69, 3.0), (2.45, 0.10, 0.10), M["metal"], 0.01))
    for side, x in (("l", -1.65), ("r", 1.65)):
        objs.append(cube("side_window_%s" % side, (x, -0.58, 2.1), (0.9, 0.06, 1.7), M["glass"]))
        objs.append(cube("side_light_%s" % side, (x, -0.63, 2.1), (0.65, 0.015, 1.35), M["lit"]))
    objs.append(cube("canopy", (0, -1.0, 3.75), (5.1, 1.9, 0.24), M["concrete_dark"], 0.025))
    objs.append(cube("canopy_light", (0, -1.55, 3.62), (4.5, 0.10, 0.04), M["lit"]))
    objs.append(cube("sign_frame", (0, -0.72, 4.35), (4.2, 0.08, 0.55), M["sign"], 0.012))
    objs.append(cube("sign_light", (0, -0.78, 4.35), (3.7, 0.02, 0.38), M["lit"]))
    for x in (-2.05, 2.05):
        objs.append(cube("step_%s" % x, (x, -0.75, 0.12), (0.7, 1.5, 0.24), M["stone"], 0.015))
    return objs


def facade_balcony():
    objs = []
    objs.append(cube("body", (0, 0.30, 9.0), (6.0, 0.60, 18.0), M["concrete"], 0.025))
    objs.append(cube("ground_dark", (0, -0.035, 1.55), (5.2, 0.08, 2.9), M["glass"]))
    objs.append(cube("ground_frame_top", (0, -0.10, 3.12), (5.8, 0.24, 0.22), M["concrete_dark"], 0.02))
    objs.append(cube("canopy", (0, -0.72, 3.45), (5.9, 1.25, 0.22), M["concrete_dark"], 0.025))
    for x in (-2.55, -0.85, 0.85, 2.55):
        objs.append(cube("mullion_%s" % x, (x, -0.12, 1.55), (0.10, 0.16, 2.9), M["metal"], 0.012))
    objs.append(cube("sign", (0, -0.11, 3.75), (4.2, 0.08, 0.72), M["sign"], 0.015))
    objs.append(cube("sign_light", (0, -0.17, 3.75), (3.7, 0.02, 0.55), M["lit"]))

    for floor in range(4):
        z = 4.9 + floor * 3.15
        objs.append(cube("floor_band_%d" % floor, (0, -0.14, z - 1.22), (6.1, 0.36, 0.20), M["concrete_dark"], 0.015))
        for side, x in (("l", -1.55), ("r", 1.55)):
            objs.append(cube("window_%d_%s" % (floor, side), (x, -0.10, z), (2.3, 0.08, 2.05), M["glass"]))
            if (floor + (0 if side == "l" else 1)) % 3 == 0:
                objs.append(cube("window_lit_%d_%s" % (floor, side), (x, -0.16, z), (2.0, 0.02, 1.75), M["lit"]))
            objs.append(cube("win_frame_%d_%s_t" % (floor, side), (x, -0.15, z + 1.08), (2.55, 0.16, 0.12), M["concrete_dark"], 0.012))
            objs.append(cube("win_frame_%d_%s_b" % (floor, side), (x, -0.15, z - 1.08), (2.55, 0.16, 0.12), M["concrete_dark"], 0.012))
            objs.append(cube("win_mullion_%d_%s" % (floor, side), (x, -0.15, z), (0.07, 0.12, 2.05), M["metal"]))
        if floor in (1, 3):
            objs.append(cube("balcony_%d" % floor, (0, -0.95, z - 1.12), (3.9, 1.35, 0.18), M["concrete_dark"], 0.02))
            objs.append(cube("balcony_rail_%d" % floor, (0, -1.58, z - 0.36), (3.8, 0.06, 0.06), M["metal"], 0.01))
            for x in (-1.8, -1.2, -0.6, 0.0, 0.6, 1.2, 1.8):
                objs.append(cube("balcony_bar_%d_%s" % (floor, x), (x, -1.58, z - 0.72), (0.035, 0.035, 0.68), M["metal"]))
            objs.append(cube("balcony_glass_%d" % floor, (0, -1.54, z - 0.77), (3.7, 0.025, 0.56), M["glass_clear"]))
    objs.append(cube("cornice_mid", (0, -0.42, 3.95), (6.25, 0.85, 0.25), M["concrete_dark"], 0.025))
    objs.append(cube("cornice_top", (0, -0.52, 18.15), (6.5, 1.0, 0.38), M["concrete_dark"], 0.03))
    objs.append(cube("roof", (0, 0.30, 18.0), (6.0, 0.60, 0.45), M["concrete"]))
    for x in (-2.85, 2.85):
        objs.append(cube("fin_%s" % x, (x, -0.45, 10.8), (0.18, 0.65, 15.0), M["concrete_dark"], 0.015))
    return objs


def facade_glass():
    objs = []
    objs.append(cube("body", (0, 0.30, 10.0), (6.0, 0.60, 20.0), M["concrete"], 0.02))
    objs.append(cube("ground_dark", (0, -0.045, 1.7), (5.4, 0.06, 3.25), M["glass"]))
    objs.append(cube("canopy", (0, -0.70, 3.55), (5.9, 1.15, 0.20), M["metal"], 0.02))
    for f in range(6):
        z = 4.5 + f * 2.75
        objs.append(cube("band_%d" % f, (0, -0.14, z - 1.20), (6.1, 0.32, 0.12), M["metal"]))
        objs.append(cube("curtain_%d" % f, (0, -0.12, z), (5.4, 0.06, 2.35), M["glass"]))
        for x in (-2.25, -1.35, -0.45, 0.45, 1.35, 2.25):
            objs.append(cube("mullion_%d_%s" % (f, x), (x, -0.16, z), (0.06, 0.12, 2.35), M["metal"]))
        if f % 3 == 1:
            objs.append(cube("lit_%d" % f, (0, -0.18, z), (5.0, 0.015, 1.95), M["lit"]))
    objs.append(cube("cornice", (0, -0.35, 20.2), (6.5, 0.9, 0.35), M["metal"], 0.02))
    return objs


def facade_stone():
    objs = []
    objs.append(cube("body", (0, 0.30, 8.5), (6.0, 0.70, 17.0), M["stone"], 0.025))
    objs.append(cube("base", (0, -0.06, 0.65), (6.2, 0.85, 1.3), M["concrete_dark"], 0.025))
    objs.append(cube("door", (0, -0.41, 2.0), (2.0, 0.08, 2.7), M["glass"]))
    objs.append(cube("canopy", (0, -0.68, 3.5), (4.0, 1.1, 0.20), M["metal"], 0.02))
    for f in range(4):
        z = 4.6 + f * 3.0
        objs.append(cube("band_%d" % f, (0, -0.44, z - 1.15), (6.2, 0.28, 0.22), M["concrete_dark"], 0.02))
        for x in (-1.7, 0.0, 1.7):
            objs.append(cube("win_%d_%s" % (f, x), (x, -0.40, z), (1.1, 0.06, 1.55), M["glass"]))
            objs.append(cube("sill_%d_%s" % (f, x), (x, -0.50, z - 0.85), (1.35, 0.3, 0.12), M["concrete_dark"], 0.01))
        if f in (1, 2):
            objs.append(cube("balcony_%d" % f, (0, -0.95, z - 1.08), (3.4, 1.2, 0.16), M["stone"], 0.02))
            objs.append(cube("rail_%d" % f, (0, -1.52, z - 0.55), (3.3, 0.06, 0.06), M["metal"]))
            for x in (-1.5, -0.75, 0, 0.75, 1.5):
                objs.append(cube("rail_bar_%d_%s" % (f, x), (x, -1.52, z - 0.82), (0.035, 0.035, 0.48), M["metal"]))
    objs.append(cube("cornice", (0, -0.45, 17.25), (6.4, 1.0, 0.35), M["concrete_dark"], 0.025))
    return objs


def bus_shelter():
    objs = []
    objs.append(cube("roof", (0, 0, 2.55), (3.8, 1.9, 0.14), M["metal"], 0.02))
    objs.append(cube("roof_glass", (0, 0, 2.64), (3.2, 1.4, 0.03), M["glass_clear"]))
    for x in (-1.75, 1.75):
        for y in (-0.8, 0.8):
            objs.append(cube("post_%s_%s" % (x, y), (x, y, 1.25), (0.08, 0.08, 2.5), M["metal"], 0.01))
    objs.append(cube("back_glass", (0, 0.86, 1.45), (3.4, 0.035, 2.1), M["glass_clear"]))
    objs.append(cube("side_glass_l", (-1.76, 0, 1.45), (0.035, 1.55, 2.1), M["glass_clear"]))
    objs.append(cube("side_glass_r", (1.76, 0, 1.45), (0.035, 1.55, 2.1), M["glass_clear"]))
    objs.append(cube("bench_seat", (0, 0.45, 0.55), (2.6, 0.38, 0.09), M["wood"], 0.02))
    for x in (-1.05, 1.05):
        objs.append(cube("bench_leg_%s" % x, (x, 0.45, 0.27), (0.08, 0.30, 0.55), M["metal"]))
    objs.append(cube("ad_frame", (-1.15, -0.55, 1.6), (0.9, 0.10, 1.8), M["metal"], 0.02))
    objs.append(cube("ad_light", (-1.15, -0.62, 1.6), (0.72, 0.025, 1.5), M["lit"]))
    objs.append(cube("route_sign", (1.1, -0.86, 2.2), (0.7, 0.08, 0.42), M["sign"], 0.01))
    return objs


# ---------------------------------------------------------------------------
# prologue dressing
# ---------------------------------------------------------------------------

def lobby_counter():
    objs = []
    objs.append(cube("body", (0, 0, 0.53), (4.2, 1.05, 1.06), M["concrete_dark"], 0.035))
    objs.append(cube("top", (0, -0.03, 1.10), (4.5, 1.22, 0.10), M["stone"], 0.025))
    objs.append(cube("front_inset", (0, -0.55, 0.56), (3.8, 0.06, 0.78), M["metal"], 0.01))
    objs.append(cube("service_panel", (0, -0.60, 0.30), (1.2, 0.03, 0.20), M["metal_light"], 0.005))
    objs.append(cube("screen_recess", (0.9, -0.56, 1.28), (0.55, 0.04, 0.30), M["sign"], 0.01))
    objs.append(cube("screen", (0.9, -0.585, 1.28), (0.43, 0.012, 0.22), M["lit"]))
    for x in (-1.9, 1.9):
        objs.append(cube("side_%s" % x, (x, 0, 0.54), (0.08, 1.08, 1.05), M["metal"], 0.01))
    return objs


def lobby_locker():
    objs = []
    objs.append(cube("body", (0, 0, 1.05), (0.95, 0.45, 2.1), M["metal"], 0.025))
    for x in (-0.235, 0.235):
        objs.append(cube("door_%s" % x, (x, -0.235, 1.05), (0.43, 0.025, 1.95), M["concrete_dark"], 0.008))
        objs.append(cube("handle_%s" % x, (x, -0.26, 1.05), (0.025, 0.035, 0.16), M["metal_light"]))
        for z in (0.55, 0.9, 1.55):
            objs.append(cube("vent_%s_%s" % (x, z), (x, -0.25, z), (0.28, 0.012, 0.025), M["metal_light"]))
    return objs


def lobby_chair():
    objs = []
    for x in (-0.82, 0.0, 0.82):
        objs.append(cube("seat_%s" % x, (x, 0, 0.48), (0.72, 0.58, 0.10), M["rubber"], 0.02))
        objs.append(cube("back_%s" % x, (x, 0.25, 0.78), (0.72, 0.08, 0.42), M["rubber"], 0.02))
    objs.append(cube("frame", (0, 0, 0.36), (2.3, 0.55, 0.08), M["metal"], 0.01))
    for x in (-1.05, 1.05):
        objs.append(cube("leg_%s" % x, (x, 0, 0.18), (0.06, 0.48, 0.36), M["metal"], 0.01))
    return objs


def lobby_duct():
    objs = []
    objs.append(cube("duct", (0, 0, 0), (4.0, 0.42, 0.34), M["metal"], 0.02))
    for x in (-1.9, -0.95, 0, 0.95, 1.9):
        objs.append(cube("flange_%s" % x, (x, 0, 0), (0.06, 0.52, 0.44), M["metal_light"], 0.01))
    return objs


def lobby_vent():
    objs = []
    objs.append(cube("frame", (0, 0, 0), (0.85, 0.075, 0.48), M["metal"], 0.015))
    objs.append(cube("back", (0, 0.035, 0), (0.72, 0.02, 0.36), M["concrete_dark"]))
    for i in range(6):
        z = -0.16 + i * 0.064
        objs.append(cube("slat_%d" % i, (0, -0.045, z), (0.70, 0.025, 0.026), M["metal_light"], 0.004))
    return objs


def alarm_beacon():
    objs = []
    objs.append(cylinder("base", (0, 0, 0.05), 0.12, 0.10, M["metal"], "Z", 20, 0.01))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10, radius=1.0, location=(0, 0, 0.19))
    dome = bpy.context.object
    dome.name = "dome"
    dome.scale = (0.14, 0.14, 0.10)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    dome.data.materials.append(M["alarm"])
    objs.append(dome)
    return objs


def cell_drain():
    objs = []
    objs.append(cube("frame", (0, 0, 0.015), (0.62, 0.62, 0.03), M["metal"], 0.01))
    for i in range(8):
        y = -0.24 + i * 0.068
        objs.append(cube("slat_%d" % i, (0, y, 0.033), (0.50, 0.025, 0.018), M["metal_light"], 0.003))
    return objs


def cell_pipe():
    objs = []
    objs.append(cylinder("pipe", (0, 0, 1.0), 0.045, 2.0, M["metal"], "Z", 12, 0.008))
    for z in (0.35, 1.65):
        objs.append(cube("bracket_%s" % z, (0, 0.07, z), (0.16, 0.08, 0.06), M["metal_light"], 0.005))
    objs.append(cylinder("elbow", (0, 0.15, 2.0), 0.045, 0.30, M["metal"], "Y", 12, 0.008))
    return objs


def cell_window_glass():
    objs = []
    objs.append(cube("glass", (0, 0, 0), (1.38, 0.03, 0.78), M["glass_clear"], 0.005))
    objs.append(cube("frame_t", (0, 0, 0.42), (1.5, 0.07, 0.06), M["metal"], 0.005))
    objs.append(cube("frame_b", (0, 0, -0.42), (1.5, 0.07, 0.06), M["metal"], 0.005))
    for x in (-0.74, 0.74):
        objs.append(cube("frame_%s" % x, (x, 0, 0), (0.06, 0.07, 0.86), M["metal"], 0.005))
    return objs


def build_all():
    global M
    reset()
    M = materials()
    export_objects(facade_balcony(), os.path.join(PARK_OUT, "facade_p2_balcony.glb"))
    reset()
    M = materials()
    export_objects(facade_glass(), os.path.join(PARK_OUT, "facade_p2_glass.glb"))
    reset()
    M = materials()
    export_objects(facade_stone(), os.path.join(PARK_OUT, "facade_p2_stone.glb"))
    reset()
    M = materials()
    export_objects(bus_shelter(), os.path.join(PARK_OUT, "bus_shelter_p2.glb"))
    reset()
    M = materials()
    export_objects(station_entrance(), os.path.join(PARK_OUT, "station_entrance_p2.glb"))

    reset()
    M = materials()
    export_objects(lobby_counter(), os.path.join(PROLOGUE_OUT, "lobby_counter_p2.glb"))
    reset()
    M = materials()
    export_objects(lobby_locker(), os.path.join(PROLOGUE_OUT, "lobby_locker_p2.glb"))
    reset()
    M = materials()
    export_objects(lobby_chair(), os.path.join(PROLOGUE_OUT, "lobby_chair_p2.glb"))
    reset()
    M = materials()
    export_objects(lobby_duct(), os.path.join(PROLOGUE_OUT, "lobby_duct_p2.glb"))
    reset()
    M = materials()
    export_objects(lobby_vent(), os.path.join(PROLOGUE_OUT, "lobby_vent_p2.glb"))
    reset()
    M = materials()
    export_objects(alarm_beacon(), os.path.join(PROLOGUE_OUT, "alarm_beacon_p2.glb"))

    reset()
    M = materials()
    export_objects(cell_drain(), os.path.join(PROLOGUE_OUT, "cell_drain_p2.glb"))
    reset()
    M = materials()
    export_objects(cell_pipe(), os.path.join(PROLOGUE_OUT, "cell_pipe_p2.glb"))
    reset()
    M = materials()
    export_objects(cell_window_glass(), os.path.join(PROLOGUE_OUT, "cell_window_glass_p2.glb"))


if __name__ == "__main__":
    build_all()

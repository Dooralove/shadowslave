"""Post-process P1 cast: authored gear, palette, ragged slave kit, hoods.

The MPFB body, skeleton and textures stay intact.  Only LOD0 is edited; LOD1/LOD2
are regenerated from the edited LOD0.  This keeps the existing 53-bone rig,
heights and UAL animation compatibility.

Run (normal Blender startup, MPFB not required after import):
  blender -b --python assets/characters/p1/source/upgrade_cast_gear.py -- <out_dir> hero_auro veteran
"""
from __future__ import annotations

import math
import os
import random
import sys

import bpy
import bmesh
from mathutils import Vector, Euler, Matrix

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)
sys.path.insert(0, os.path.join(_HERE, "..", "..", "sunny_realistic_poc", "source"))
import build_main_cast as mc  # noqa: E402
import build_sunny_poc as sunny  # noqa: E402

ROOT = os.path.abspath(os.path.join(_HERE, "..", "..", "..", ".."))
MODELS = os.path.join(ROOT, "assets", "characters", "p1", "models")


def load(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(MODELS, name + ".glb"))
    rig = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name != "Icosphere"]
    # Drop old LOD copies; we regenerate them after editing LOD0.
    for o in list(meshes):
        if "_LOD1" in o.name or "_LOD2" in o.name:
            bpy.data.objects.remove(o, do_unlink=True)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name != "Icosphere"]
    return rig, meshes


def find(meshes, tag):
    return next((o for o in meshes if tag in o.name), None)


def head_pos(rig):
    return mc._bone_head(rig, "Head")


def bind_weighted(obj, rig, weight_fn, bone_names=("Hips", "Spine", "Chest", "UpperChest")):
    mc.apply_transform(obj)
    obj.parent = rig
    obj.matrix_parent_inverse = rig.matrix_world.inverted()
    groups = {b: obj.vertex_groups.new(name=b) for b in bone_names}
    for v in obj.data.vertices:
        weights = weight_fn(v.co)
        total = sum(w for _, w in weights)
        if total <= 0:
            weights = [(bone_names[-1], 1.0)]
            total = 1.0
        for bone_name, w in weights:
            if w > 0 and bone_name in groups:
                groups[bone_name].add([v.index], w / total, "REPLACE")
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    return obj


def add_cape(rig, name, mat, top_z, bottom_z, width, back_y, rows=7, cols=9, wave=0.02):
    verts = []
    faces = []
    for r in range(rows):
        t = r / (rows - 1)
        z = top_z + (bottom_z - top_z) * t
        w = width * (0.72 + 0.28 * t)
        for c in range(cols):
            u = c / (cols - 1)
            x = (u - 0.5) * 2.0 * w
            y = back_y - math.sin(u * math.pi) * wave * (0.3 + t)
            verts.append((x, y, z))
    for r in range(rows - 1):
        for c in range(cols - 1):
            i = r * cols + c
            faces.append((i, i + 1, i + cols + 1, i + cols))
    # Tatter the hem before the mesh is built.
    rng = random.Random(hash(name) & 0xffff)
    verts = [list(v) for v in verts]
    for i in range((rows - 1) * cols, rows * cols):
        verts[i][2] += rng.uniform(-0.06, 0.03)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for poly in mesh.polygons:
        poly.use_smooth = True
    mc.add_solidify(obj, 0.008)
    bind_weighted(obj, rig, lambda co: [
        ("UpperChest", max(0.0, min(1.0, (co.z - (top_z - 0.55)) / 0.55))),
        ("Chest", max(0.0, 1.0 - abs(co.z - (top_z + bottom_z) * 0.5) / 0.75)),
        ("Hips", max(0.0, min(1.0, (top_z - co.z) / max(0.2, top_z - bottom_z)))),
    ])
    return obj


def add_tunic_skirt(rig, name, mat, top_z, bottom_z, top_r, bottom_r, segments=18):
    verts = []
    faces = []
    rng = random.Random(hash(name) & 0xffff)
    for i in range(segments):
        a = math.tau * i / segments
        verts.append((math.cos(a) * top_r, math.sin(a) * top_r, top_z))
    for i in range(segments):
        a = math.tau * i / segments
        rr = bottom_r * rng.uniform(0.92, 1.10)
        verts.append((math.cos(a) * rr, math.sin(a) * rr, bottom_z + rng.uniform(-0.07, 0.02)))
    for i in range(segments):
        j = (i + 1) % segments
        faces.append((i, j, segments + j, segments + i))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for poly in mesh.polygons:
        poly.use_smooth = True
    mc.add_solidify(obj, 0.009)
    bind_weighted(obj, rig, lambda co: [("Hips", 1.0)], ("Hips",))
    return obj


def add_rope_belt(rig, z, radius, mat, name="rope_belt"):
    obj = mc.add_ring(name, (0, 0, z), radius, 0.012, mat, rotation=(0, 0, 0))
    mc.bind_rigid(obj, rig, "Hips")
    return obj


def add_pauldron(rig, side, center, mat):
    sx = -1 if side == "L" else 1
    obj = mc.add_sphere("pauldron_" + side, center, (0.13, 0.10, 0.075), mat, segments=16, rings=8)
    mc.bind_rigid(obj, rig, "LeftShoulder" if side == "L" else "RightShoulder")
    obj2 = mc.add_sphere("pauldron_plate_" + side, (center[0] + sx * 0.03, center[1], center[2] - 0.05),
                         (0.10, 0.08, 0.035), mat, segments=12, rings=6)
    mc.bind_rigid(obj2, rig, "LeftShoulder" if side == "L" else "RightShoulder")


def add_bracer(rig, side, start, end, mat):
    obj = mc.add_cone_between("bracer_" + side, start, end, 0.065, 0.05, mat, segments=10)
    mc.bind_rigid(obj, rig, "LeftLowerArm" if side == "L" else "RightLowerArm")


def add_spear_on_back(rig, start, end, wood, iron):
    shaft = mc.add_cone_between("spear_shaft", start, end, 0.016, 0.012, wood, segments=8)
    mc.bind_rigid(shaft, rig, "UpperChest")
    tip = mc.add_cone_between("spear_tip", end, tuple(Vector(end) + (Vector(end) - Vector(start)).normalized() * 0.16),
                              0.026, 0.002, iron, segments=8)
    mc.bind_rigid(tip, rig, "UpperChest")


def add_sword_at_hip(rig, side, center, mat_metal, mat_leather):
    sx = -1 if side == "L" else 1
    scabbard = mc.add_box("sword_scabbard", (center[0] + sx * 0.03, center[1], center[2] - 0.20),
                          (0.045, 0.035, 0.52), mat_leather, 0.008)
    mc.bind_rigid(scabbard, rig, "Hips")
    hilt = mc.add_cylinder("sword_hilt", (center[0] + sx * 0.03, center[1], center[2] + 0.10),
                           0.017, 0.10, mat_leather, segments=8)
    mc.bind_rigid(hilt, rig, "Hips")
    guard = mc.add_box("sword_guard", (center[0] + sx * 0.03, center[1], center[2] + 0.04),
                       (0.10, 0.025, 0.02), mat_metal, 0.004)
    mc.bind_rigid(guard, rig, "Hips")


def add_whip_at_hip(rig, side, center, mat):
    sx = -1 if side == "L" else 1
    for i in range(3):
        obj = mc.add_ring("whip_coil_%d" % i, (center[0] + sx * 0.04, center[1], center[2] - 0.03 * i),
                          0.055 - i * 0.006, 0.007, mat, rotation=(math.radians(90), 0, 0))
        mc.bind_rigid(obj, rig, "Hips")
    handle = mc.add_cylinder("whip_handle", (center[0] + sx * 0.04, center[1], center[2] + 0.06),
                             0.016, 0.16, mat, segments=8)
    mc.bind_rigid(handle, rig, "Hips")


def add_fur_mantle(rig, mat, z=1.30):
    centers = []
    for i in range(320):
        a = math.tau * i / 320.0
        rx = 0.25
        ry = 0.15
        c = (math.cos(a) * rx, math.sin(a) * ry, z + math.sin(a * 3.0) * 0.015)
        centers.append(c)
    obj = mc.add_tuft_cloud("fur_mantle", mat, centers, (0, 0, -0.65), 0.085, 0.022, seed=771, segments=4)
    mc.bind_rigid(obj, rig, "UpperChest")
    # A low base torus keeps the collar readable between tufts.
    base = mc.add_ring("fur_mantle_base", (0, 0, z), 0.235, 0.040, mat, rotation=(0, 0, 0))
    mc.bind_rigid(base, rig, "UpperChest")


def add_beard(rig, head, mat):
    mc.add_sphere("beard_main", (head.x, head.y - 0.075, head.z - 0.085), (0.075, 0.045, 0.095),
                  mat, segments=14, rings=8)
    mc.bind_rigid(bpy.context.object, rig, "Head")
    mc.add_sphere("beard_chin", (head.x, head.y - 0.095, head.z - 0.145), (0.045, 0.035, 0.055),
                  mat, segments=12, rings=6)
    mc.bind_rigid(bpy.context.object, rig, "Head")


def add_hood(rig, mat, neck, chest):
    # Small rolled collar plus a lowered hood flap on the upper back.
    collar = mc.add_ring("hood_collar", (neck.x, neck.y, neck.z - 0.03), 0.085, 0.018, mat, rotation=(0, 0, 0))
    mc.bind_rigid(collar, rig, "Neck")
    add_cape(rig, "hood_flap", mat, neck.z - 0.02, chest.z - 0.18, 0.16, 0.13, rows=4, cols=5, wave=0.012)


def replace_hair(target_rig, target_meshes, donor_name, donor_tag, old_tag):
    """Copy a short hair cap from another MPFB character and fit it to this head."""
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(MODELS, donor_name + ".glb"))
    donor_objs = [o for o in bpy.context.scene.objects if o not in before]
    donor_rig = next(o for o in donor_objs if o.type == "ARMATURE")
    donor_hair = next(o for o in donor_objs if o.type == "MESH" and donor_tag in o.name and "_LOD" not in o.name)
    target_m = target_rig.matrix_world @ target_rig.data.bones["Head"].matrix_local
    donor_m = donor_rig.matrix_world @ donor_rig.data.bones["Head"].matrix_local
    fit = target_m @ donor_m.inverted()
    old = find(target_meshes, old_tag)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    hair = donor_hair.copy()
    hair.data = donor_hair.data.copy()
    hair.name = "hair_short"
    hair.data.name = "hair_short"
    bpy.context.scene.collection.objects.link(hair)
    hair.parent = None
    hair.matrix_world = fit @ donor_hair.matrix_world
    for mod in list(hair.modifiers):
        hair.modifiers.remove(mod)
    hair.vertex_groups.clear()
    mc.bind_rigid(hair, target_rig, "Head")
    for o in donor_objs:
        bpy.data.objects.remove(o, do_unlink=True)
    return hair


def trim_cuirass_sleeves(obj, x_limit=0.21, z_min=1.15):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    mw = obj.matrix_world
    drop = []
    for f in bm.faces:
        c = mw @ f.calc_center_median()
        if abs(c.x) > x_limit and c.z > z_min:
            drop.append(f)
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()


def add_cuirass_details(rig, front_y, top_z, bottom_z, leather, metal):
    # Central placket/stitch line and rivets make the vest read as a leather cuirass.
    h = top_z - bottom_z
    placket = mc.add_box("cuirass_placket", (0, front_y - 0.012, (top_z + bottom_z) * 0.5),
                         (0.035, 0.025, h * 0.78), leather, 0.006)
    mc.bind_rigid(placket, rig, "Chest")
    for i in range(4):
        z = bottom_z + h * (0.22 + i * 0.18)
        for sx in (-1, 1):
            rivet = mc.add_sphere("cuirass_rivet_%d_%d" % (i, sx), (sx * 0.135, front_y - 0.022, z),
                                  (0.018, 0.012, 0.018), metal, segments=8, rings=4)
            mc.bind_rigid(rivet, rig, "Chest")
    collar = mc.add_ring("cuirass_collar", (0, -0.01, top_z - 0.02), 0.086, 0.016, leather,
                         rotation=(0, 0, 0))
    mc.bind_rigid(collar, rig, "Chest")
    buckle = mc.add_box("belt_buckle", (0, front_y - 0.02, bottom_z - 0.02),
                        (0.075, 0.03, 0.06), metal, 0.008)
    mc.bind_rigid(buckle, rig, "Hips")


def add_chest_strap(rig, start, end, mat, buckle_mat=None):
    strap = mc.add_cone_between("chest_strap", start, end, 0.028, 0.028, mat, segments=6)
    mc.bind_rigid(strap, rig, "Chest")
    if buckle_mat is not None:
        mid = (Vector(start) + Vector(end)) * 0.5
        buckle = mc.add_box("chest_buckle", (mid.x, mid.y - 0.025, mid.z), (0.055, 0.025, 0.055),
                            buckle_mat, 0.006)
        mc.bind_rigid(buckle, rig, "Chest")


def add_scarf(rig, mat, neck, chest):
    collar = mc.add_ring("scarf_collar", (neck.x, neck.y, neck.z - 0.03), 0.105, 0.026, mat, rotation=(0, 0, 0))
    mc.bind_rigid(collar, rig, "Neck")
    strip = mc.add_box("scarf_strip", (chest.x - 0.06, chest.y - 0.12, chest.z - 0.12),
                       (0.10, 0.025, 0.34), mat, 0.006)
    mc.bind_rigid(strip, rig, "Chest")


def join_by_material(rig, meshes):
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name != "Icosphere"]
    groups = {}
    for o in meshes:
        if o.parent != rig or not any(m.type == "ARMATURE" for m in o.modifiers):
            continue
        if len(o.data.materials) != 1:
            continue
        key = o.data.materials[0].name
        groups.setdefault(key, []).append(o)
    for key, objs in groups.items():
        if len(objs) <= 1:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.object.join()
        obj = bpy.context.object
        obj.name = "mat_" + key.replace(".", "_")
        obj.data.name = obj.name
    return [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name != "Icosphere"]


def delete_objects(meshes, tags):
    for o in list(meshes):
        if any(t in o.name for t in tags):
            bpy.data.objects.remove(o, do_unlink=True)
    return [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name != "Icosphere"]


def regen_lods(rig, meshes):
    for o in list(meshes):
        if "_LOD1" in o.name or "_LOD2" in o.name:
            bpy.data.objects.remove(o, do_unlink=True)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name != "Icosphere"]
    lod1 = mc._make_lod(meshes, 0.52, ["eyebrow", "eyelashes", "glasses"], "_LOD1")
    lod2 = mc._make_lod(meshes, 0.24, ["eyebrow", "eyelashes", "glasses", "radio", "badge"], "_LOD2")
    return meshes + lod1 + lod2


def export(rig, meshes, name, out_dir):
    path = os.path.join(out_dir, name + "_v2.glb")
    os.makedirs(out_dir, exist_ok=True)
    mc._export(rig, meshes, path)
    return path


def build_hero(out_dir):
    rig, meshes = load("hero_auro")
    head = head_pos(rig)
    replace_hair(rig, meshes, "mass_male", "short02", "culturalibre_hair_01")
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name != "Icosphere"]
    cuirass = find(meshes, "hero_cuirass")
    if cuirass:
        sunny.recolor(cuirass, 0.85, 1.05, (0.70, 0.47, 0.28))
        trim_cuirass_sleeves(cuirass)
    leather = mc.material("hero_leather", (0.20, 0.12, 0.06), 0.70)
    iron = mc.material("hero_iron", (0.30, 0.30, 0.31), 0.42, 0.75)
    add_cuirass_details(rig, -0.16, 1.50, 0.93, leather, iron)
    for side, sx in (("L", -1), ("R", 1)):
        add_pauldron(rig, side, (sx * 0.18, -0.01, 1.35), leather)
        add_bracer(rig, side, (sx * 0.34, -0.02, 1.16), (sx * 0.45, -0.18, 1.05), leather)
    add_chest_strap(rig, (0.15, -0.10, 1.46), (-0.16, -0.10, 0.94), leather, iron)
    add_rope_belt(rig, 0.93, 0.165, leather)
    add_spear_on_back(rig, (0.11, 0.12, 0.76), (-0.08, 0.15, 1.86),
                      mc.material("hero_spear_wood", (0.16, 0.10, 0.06), 0.85), iron)
    add_chest_strap(rig, (0.16, 0.10, 1.36), (-0.16, 0.10, 1.13), leather, None)
    add_sword_at_hip(rig, "L", (-0.18, 0.0, 0.85), iron, leather)
    meshes = join_by_material(rig, meshes)
    meshes = regen_lods(rig, meshes)
    return export(rig, meshes, "hero_auro", out_dir)


def build_veteran(out_dir):
    rig, meshes = load("veteran")
    head = head_pos(rig)
    hair = find(meshes, "veteran.short04")
    if hair:
        sunny.recolor(hair, 0.0, 2.0, (0.85, 0.85, 0.84))
    cuirass = find(meshes, "veteran_cuirass")
    if cuirass:
        sunny.recolor(cuirass, 0.70, 0.85, (0.56, 0.38, 0.24))
        trim_cuirass_sleeves(cuirass)
    fur = mc.material("veteran_fur", (0.075, 0.060, 0.045), 1.0)
    leather = mc.material("veteran_leather", (0.16, 0.10, 0.05), 0.72)
    iron = mc.material("veteran_iron", (0.25, 0.25, 0.26), 0.45, 0.7)
    add_cuirass_details(rig, -0.17, 1.48, 0.92, leather, iron)
    add_fur_mantle(rig, fur, 1.30)
    add_rope_belt(rig, 0.92, 0.17, leather)
    add_whip_at_hip(rig, "R", (0.19, 0.02, 0.85), leather)
    add_sword_at_hip(rig, "L", (-0.18, 0.0, 0.84), iron, leather)
    meshes = join_by_material(rig, meshes)
    meshes = regen_lods(rig, meshes)
    return export(rig, meshes, "veteran", out_dir)


def build_shifty(out_dir):
    rig, meshes = load("shifty")
    head = head_pos(rig)
    tunic = find(meshes, "elvs_crude_t-shirt_male")
    if tunic:
        burlap = mc.material("shifty_burlap", (0.16, 0.12, 0.085), 0.97)
        tunic.data.materials.clear()
        tunic.data.materials.append(burlap)
    shoes = find(meshes, "shoes03")
    if shoes:
        shoes.data.materials.clear()
        shoes.data.materials.append(mc.material("shifty_shoes", (0.10, 0.075, 0.055), 0.88))
    burlap = mc.material("shifty_burlap_skirt", (0.14, 0.105, 0.075), 0.98)
    rope = mc.material("shifty_rope", (0.24, 0.19, 0.12), 0.95)
    add_tunic_skirt(rig, "shifty_tunic_skirt", burlap, 0.96, 0.62, 0.18, 0.225)
    add_rope_belt(rig, 0.93, 0.17, rope)
    meshes = join_by_material(rig, meshes)
    meshes = regen_lods(rig, meshes)
    return export(rig, meshes, "shifty", out_dir)


def build_mass_slave(out_dir):
    rig, meshes = load("mass_slave")
    tunic = find(meshes, "elvs_crude_t-shirt_male")
    if tunic:
        burlap = mc.material("slave_burlap", (0.16, 0.12, 0.085), 0.97)
        tunic.data.materials.clear()
        tunic.data.materials.append(burlap)
    meshes = delete_objects(meshes, ["shoes03", "shoes05", "shoes06"])
    burlap = mc.material("slave_burlap_skirt", (0.14, 0.105, 0.075), 0.98)
    rope = mc.material("slave_rope", (0.24, 0.19, 0.12), 0.95)
    add_tunic_skirt(rig, "mass_slave_tunic_skirt", burlap, 0.96, 0.62, 0.18, 0.225)
    add_rope_belt(rig, 0.93, 0.17, rope)
    meshes = join_by_material(rig, meshes)
    meshes = regen_lods(rig, meshes)
    return export(rig, meshes, "mass_slave", out_dir)


def build_mass_soldier(out_dir):
    rig, meshes = load("mass_soldier")
    head = head_pos(rig)
    leather = mc.material("soldier_leather", (0.14, 0.09, 0.055), 0.72)
    iron = mc.material("soldier_iron", (0.28, 0.28, 0.29), 0.45, 0.7)
    cuirass = mc.add_leather_cuirass(rig, meshes, "soldier_cuirass", (0.20, 0.12, 0.06), 0.24, 0.87, 1.52, 0.025)
    if cuirass:
        trim_cuirass_sleeves(cuirass)
    add_cuirass_details(rig, -0.16, 1.48, 0.92, leather, iron)
    for side, sx in (("L", -1), ("R", 1)):
        add_pauldron(rig, side, (sx * 0.19, -0.01, 1.34), leather)
        add_bracer(rig, side, (sx * 0.34, -0.02, 1.15), (sx * 0.45, -0.18, 1.04), leather)
    add_rope_belt(rig, 0.92, 0.17, leather)
    add_spear_on_back(rig, (0.12, 0.18, 0.76), (-0.10, 0.23, 1.84),
                      mc.material("soldier_spear_wood", (0.15, 0.09, 0.05), 0.85), iron)
    add_sword_at_hip(rig, "L", (-0.18, 0.0, 0.84), iron, leather)
    meshes = join_by_material(rig, meshes)
    meshes = regen_lods(rig, meshes)
    return export(rig, meshes, "mass_soldier", out_dir)


def build_scholar(out_dir):
    rig, meshes = load("scholar")
    cloth = mc.material("scholar_cloak", (0.10, 0.10, 0.11), 0.95)
    add_cape(rig, "scholar_cloak", cloth, 1.48, 0.58, 0.30, 0.12)
    add_rope_belt(rig, 0.93, 0.17, mc.material("scholar_rope", (0.22, 0.19, 0.15), 0.95))
    meshes = regen_lods(rig, meshes)
    return export(rig, meshes, "scholar", out_dir)


def build_sunny(out_dir, nightmare=False):
    name = "sunny_nightmare" if nightmare else "sunny_real"
    rig, meshes = load(name)
    head = head_pos(rig)
    cloth = mc.material("sunny_hood", (0.20, 0.19, 0.18) if not nightmare else (0.28, 0.23, 0.17), 0.96)
    add_hood(rig, cloth, mc._bone_head(rig, "Neck"), mc._bone_head(rig, "Chest"))
    meshes = regen_lods(rig, meshes)
    return export(rig, meshes, name, out_dir)


CHARACTERS = {
    "hero_auro": build_hero,
    "veteran": build_veteran,
    "shifty": build_shifty,
    "mass_slave": build_mass_slave,
    "mass_soldier": build_mass_soldier,
    "scholar": build_scholar,
    "sunny_real": lambda out: build_sunny(out, False),
    "sunny_nightmare": lambda out: build_sunny(out, True),
}


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:]
    out = os.path.abspath(args[0])
    names = args[1:] or list(CHARACTERS.keys())
    for name in names:
        print("UPGRADE", name, CHARACTERS[name](out))

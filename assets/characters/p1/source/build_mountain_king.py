"""P1 hero asset: Mountain King (Tyrant).

Run:
  blender -b --python assets/characters/p1/source/build_mountain_king.py -- <output.glb>

Canon: >=4 m, hunched, two stumpy legs, four arms (two long clawed, two short
human-fingered), five milky eyes, a maw of razor teeth, yellowish-grey ragged fur.
The model is built as rigid skinned parts around one armature, with 3 LOD layers
inside one GLB.  Clips: Idle, Walk, Telegraph, Attack, Death.
"""
from __future__ import annotations

import math
import os
import random
import sys

import bpy
import bmesh
from mathutils import Vector, Euler

OUT = ""


def mat(name, color, roughness=0.85, metallic=0.0, emission=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 1.2
    return m


def mesh_obj(name, bm, material):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    if material:
        mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    for p in mesh.polygons:
        p.use_smooth = True
    return obj


def sphere(name, center, scale, material, seg=18, rings=10, rough=0.0, seed=0):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    rng = random.Random(seed)
    for v in bm.verts:
        p = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2]))
        if rough:
            p += v.co.normalized() * rng.uniform(-rough, rough)
        v.co = p + Vector(center)
    return mesh_obj(name, bm, material)


def cone_between(name, start, end, r1, r2, material, seg=8, caps=True):
    start, end = Vector(start), Vector(end)
    d = end - start
    length = d.length
    if length < 1e-6:
        return None
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=seg,
                          radius1=r1, radius2=r2, depth=length)
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix()
    mid = (start + end) * 0.5
    for v in bm.verts:
        v.co = rot @ v.co + mid
    return mesh_obj(name, bm, material)


def join_objects(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    return obj


def apply_modifier(obj, mod):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)


def remesh(obj, voxel, smooth=True):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new("Remesh", "REMESH")
    mod.mode = "VOXEL"
    mod.voxel_size = voxel
    mod.use_smooth_shade = smooth
    bpy.ops.object.modifier_apply(modifier=mod.name)
    # A light smooth to remove voxel stair-steps while keeping the lumpy silhouette.
    mod = obj.modifiers.new("Smooth", "SMOOTH")
    mod.factor = 0.35
    mod.iterations = 2
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def make_armature():
    arm_data = bpy.data.armatures.new("MountainKingRig")
    arm = bpy.data.objects.new("MountainKingRig", arm_data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones

    def bone(name, head, tail, parent=None, connect=False):
        b = eb.new(name)
        b.head = Vector(head)
        b.tail = Vector(tail)
        b.use_connect = connect
        if parent:
            b.parent = eb[parent]
        return b

    bone("Root", (0, 0, 0), (0, 0, 0.35))
    bone("Hips", (0, 0, 1.05), (0, 0, 1.55), "Root")
    bone("Spine", (0, 0, 1.55), (0, 0, 2.25), "Hips", True)
    bone("Chest", (0, 0, 2.25), (0, 0, 3.05), "Spine", True)
    bone("Neck", (0, 0.1, 3.05), (0, 0.22, 3.55), "Chest")
    bone("Head", (0, 0.22, 3.55), (0, 0.48, 4.10), "Neck", True)
    bone("Jaw", (0, 0.36, 3.58), (0, 0.78, 3.34), "Head")

    for side, sx in (("L", -1), ("R", 1)):
        bone("Thigh" + side, (sx * 0.78, 0, 1.12), (sx * 0.86, 0.02, 0.66), "Hips")
        bone("Shin" + side, (sx * 0.86, 0.02, 0.66), (sx * 0.88, 0.18, 0.22), "Thigh" + side, True)
        bone("Foot" + side, (sx * 0.88, 0.18, 0.22), (sx * 0.88, 0.58, 0.10), "Shin" + side, True)
        bone("LongUpper" + side, (sx * 1.05, 0.05, 3.00), (sx * 1.38, 0.22, 2.10), "Chest")
        bone("LongFore" + side, (sx * 1.38, 0.22, 2.10), (sx * 1.55, 0.48, 1.12), "LongUpper" + side, True)
        bone("LongHand" + side, (sx * 1.55, 0.48, 1.12), (sx * 1.60, 0.80, 0.65), "LongFore" + side, True)
        bone("ShortUpper" + side, (sx * 0.55, 0.65, 2.75), (sx * 0.95, 1.15, 2.15), "Chest")
        bone("ShortFore" + side, (sx * 0.95, 1.15, 2.15), (sx * 1.10, 1.45, 1.65), "ShortUpper" + side, True)
        bone("ShortHand" + side, (sx * 1.10, 1.45, 1.65), (sx * 1.15, 1.62, 1.45), "ShortFore" + side, True)

    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def bind_rigid(obj, rig, bone_name):
    obj.parent = rig
    obj.matrix_parent_inverse = rig.matrix_world.inverted()
    vg = obj.vertex_groups.new(name=bone_name)
    vg.add(range(len(obj.data.vertices)), 1.0, "REPLACE")
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    return obj


def bind_weighted(obj, rig):
    obj.parent = rig
    obj.matrix_parent_inverse = rig.matrix_world.inverted()
    groups = {}
    for name in ("Hips", "Spine", "Chest", "Neck"):
        groups[name] = obj.vertex_groups.new(name=name)
    for v in obj.data.vertices:
        z = (obj.matrix_world @ v.co).z
        if z <= 1.35:
            pairs = [("Hips", 1.0)]
        elif z <= 1.95:
            t = (z - 1.35) / 0.60
            pairs = [("Hips", 1.0 - t), ("Spine", t)]
        elif z <= 2.55:
            t = (z - 1.95) / 0.60
            pairs = [("Spine", 1.0 - t), ("Chest", t)]
        elif z <= 3.30:
            t = (z - 2.55) / 0.75
            pairs = [("Chest", 1.0 - t * 0.4), ("Neck", t * 0.4)]
        else:
            pairs = [("Neck", 1.0)]
        for name, w in pairs:
            if w > 0:
                groups[name].add([v.index], w, "REPLACE")
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    return obj


def fur_cloud(name, material, points, seed, seg=4):
    rng = random.Random(seed)
    bm = bmesh.new()
    for center, outward in points:
        c = Vector(center)
        d = Vector(outward) + Vector((rng.uniform(-0.4, 0.4), rng.uniform(-0.35, 0.35),
                                       rng.uniform(-0.15, 0.35)))
        if d.length < 1e-4:
            d = Vector((0, 0, 1))
        d.normalize()
        length = rng.uniform(0.13, 0.38)
        radius = rng.uniform(0.030, 0.075)
        ret = bmesh.ops.create_cone(bm, cap_ends=False, cap_tris=False, segments=seg,
                                    radius1=radius, radius2=0.005, depth=length)
        base = c
        rot = Vector((0, 0, 1)).rotation_difference(d).to_matrix()
        for v in ret["verts"]:
            v.co = rot @ v.co + base + d * (length * 0.5)
    return mesh_obj(name, bm, material)


def make_fur_points(body_bounds, count, seed):
    rng = random.Random(seed)
    xmin, xmax, ymin, ymax, zmin, zmax = body_bounds
    points = []
    for _ in range(count):
        z = rng.uniform(zmin + 0.2, zmax - 0.1)
        a = rng.uniform(0, math.tau)
        # Body is roughly elliptical in XY; use outward direction.
        dx = math.cos(a)
        dy = math.sin(a) * 0.8
        x = (xmin + xmax) * 0.5 + dx * (xmax - xmin) * 0.46
        y = (ymin + ymax) * 0.5 + dy * (ymax - ymin) * 0.46
        points.append(((x, y, z), (dx, dy, rng.uniform(-0.15, 0.45))))
    return points


def make_fur_points_from_mesh(obj, count, seed, zmin=1.10, zmax=3.40):
    """Sample actual remeshed body vertices; guarantees tufts sit on the surface."""
    rng = random.Random(seed)
    candidates = [v for v in obj.data.vertices if zmin <= v.co.z <= zmax]
    if not candidates:
        candidates = list(obj.data.vertices)
    points = []
    for _ in range(count):
        v = rng.choice(candidates)
        n = v.normal.normalized() if v.normal.length > 0.01 else Vector((0, 0, 1))
        p = obj.matrix_world @ v.co
        n_world = (obj.matrix_world.to_3x3() @ n).normalized()
        points.append((p, n_world))
    return points



def make_tooth(name, base, tip, material):
    return cone_between(name, base, tip, 0.035, 0.004, material, seg=5)


def build_lod0(rig, parts):
    """Returns lists of (object, bone) for LOD0; parts already bound."""
    return parts


def decimate_copy(obj, ratio, suffix):
    dup = obj.copy()
    dup.data = obj.data.copy()
    dup.name = obj.name + suffix
    bpy.context.collection.objects.link(dup)
    mod = dup.modifiers.new("LOD_Decimate", "DECIMATE")
    mod.ratio = ratio
    mod.use_collapse_triangulate = True
    bpy.ops.object.select_all(action="DESELECT")
    dup.select_set(True)
    bpy.context.view_layer.objects.active = dup
    bpy.ops.object.modifier_move_to_index(modifier=mod.name, index=0)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return dup


def key_pose(rig, action, frame, bone, rot=None, loc=None):
    pb = rig.pose.bones[bone]
    pb.rotation_mode = "XYZ"
    if rot is not None:
        pb.rotation_euler = Euler(rot, "XYZ")
        pb.keyframe_insert("rotation_euler", frame=frame)
    if loc is not None:
        pb.location = Vector(loc)
        pb.keyframe_insert("location", frame=frame)


def new_action(rig, name):
    if rig.animation_data is None:
        rig.animation_data_create()
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data.action = act
    return act


def build_animations(rig):
    actions = []

    # Idle: breathing, head sway, jaw and four arms.
    act = new_action(rig, "Idle")
    act.frame_start = 1
    act.frame_end = 60
    for f, t in ((1, 0), (30, 1), (60, 0)):
        key_pose(rig, act, f, "Chest", rot=(0.012 * (1 if t else -1), 0, 0))
        key_pose(rig, act, f, "Head", rot=(0.02 * (1 if t else -1), 0.03 * (1 if t else -1), 0))
        key_pose(rig, act, f, "Jaw", rot=(0.03 * t, 0, 0))
        key_pose(rig, act, f, "LongUpperL", rot=(0.03 * t, 0, -0.02 * t))
        key_pose(rig, act, f, "LongUpperR", rot=(0.03 * t, 0, 0.02 * t))
        key_pose(rig, act, f, "ShortUpperL", rot=(-0.03 * t, 0, 0))
        key_pose(rig, act, f, "ShortUpperR", rot=(-0.03 * t, 0, 0))
    actions.append(act)

    # Walk: short stumpy legs + heavy body bob.
    act = new_action(rig, "Walk")
    act.frame_start = 1
    act.frame_end = 32
    for f, t in ((1, 0), (8, 1), (16, 0), (24, -1), (32, 0)):
        key_pose(rig, act, f, "Hips", rot=(0, 0.04 * t, 0), loc=(0, 0, 0.02 * abs(t)))
        key_pose(rig, act, f, "ThighL", rot=(0.35 * t, 0, 0))
        key_pose(rig, act, f, "ThighR", rot=(-0.35 * t, 0, 0))
        key_pose(rig, act, f, "ShinL", rot=(-0.25 * abs(t), 0, 0))
        key_pose(rig, act, f, "ShinR", rot=(0.25 * abs(t), 0, 0))
        key_pose(rig, act, f, "LongUpperL", rot=(-0.22 * t, 0, 0))
        key_pose(rig, act, f, "LongUpperR", rot=(0.22 * t, 0, 0))
        key_pose(rig, act, f, "ShortUpperL", rot=(0.18 * t, 0, 0))
        key_pose(rig, act, f, "ShortUpperR", rot=(-0.18 * t, 0, 0))
        key_pose(rig, act, f, "Chest", rot=(-0.08, 0, 0.03 * t))
    actions.append(act)

    # Telegraph: rear up, jaw open, arms spread.
    act = new_action(rig, "Telegraph")
    act.frame_start = 1
    act.frame_end = 24
    for f, t in ((1, 0), (12, 1), (24, 0.4)):
        key_pose(rig, act, f, "Spine", rot=(-0.28 * t, 0, 0))
        key_pose(rig, act, f, "Chest", rot=(-0.22 * t, 0, 0))
        key_pose(rig, act, f, "Head", rot=(0.25 * t, 0, 0))
        key_pose(rig, act, f, "Jaw", rot=(0.65 * t, 0, 0))
        key_pose(rig, act, f, "LongUpperL", rot=(0.25 * t, 0, -0.55 * t))
        key_pose(rig, act, f, "LongUpperR", rot=(0.25 * t, 0, 0.55 * t))
        key_pose(rig, act, f, "LongForeL", rot=(-0.45 * t, 0, 0))
        key_pose(rig, act, f, "LongForeR", rot=(-0.45 * t, 0, 0))
        key_pose(rig, act, f, "ShortUpperL", rot=(-0.45 * t, 0, -0.3 * t))
        key_pose(rig, act, f, "ShortUpperR", rot=(-0.45 * t, 0, 0.3 * t))
    actions.append(act)

    # Attack: four-arm downward swipe.
    act = new_action(rig, "Attack")
    act.frame_start = 1
    act.frame_end = 20
    for f, t in ((1, 0), (7, 1), (14, -0.7), (20, 0)):
        key_pose(rig, act, f, "Spine", rot=(0.35 * t, 0, 0))
        key_pose(rig, act, f, "Chest", rot=(0.25 * t, 0, 0))
        key_pose(rig, act, f, "LongUpperL", rot=(-0.75 * t, 0, -0.2 * t))
        key_pose(rig, act, f, "LongUpperR", rot=(-0.75 * t, 0, 0.2 * t))
        key_pose(rig, act, f, "LongForeL", rot=(0.55 * t, 0, 0))
        key_pose(rig, act, f, "LongForeR", rot=(0.55 * t, 0, 0))
        key_pose(rig, act, f, "ShortUpperL", rot=(0.55 * t, 0, 0))
        key_pose(rig, act, f, "ShortUpperR", rot=(0.55 * t, 0, 0))
    actions.append(act)

    # Death: stagger and fall.
    act = new_action(rig, "Death")
    act.frame_start = 1
    act.frame_end = 44
    for f, t in ((1, 0), (18, 0.6), (34, 1.0), (44, 1.0)):
        key_pose(rig, act, f, "Root", rot=(0.55 * t, 0, 0.35 * t))
        key_pose(rig, act, f, "Spine", rot=(0.35 * t, 0, 0))
        key_pose(rig, act, f, "Head", rot=(0.4 * t, 0, 0))
        key_pose(rig, act, f, "Jaw", rot=(0.5 * t, 0, 0))
        key_pose(rig, act, f, "LongUpperL", rot=(-0.6 * t, 0, 0))
        key_pose(rig, act, f, "LongUpperR", rot=(-0.6 * t, 0, 0))
    actions.append(act)
    rig.animation_data.action = actions[0]
    return actions


def export_glb(rig, meshes, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_anim_single_armature=True,
        export_morph=False,
        export_skins=True,
        export_yup=True,
    )


def main(out_path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    random.seed(20261101)

    fur_light = mat("MK_fur_light", (0.46, 0.40, 0.29), 0.98)
    fur_dark = mat("MK_fur_dark", (0.20, 0.17, 0.12), 0.99)
    skin = mat("MK_skin", (0.095, 0.085, 0.070), 0.92)
    bone = mat("MK_bone", (0.62, 0.59, 0.48), 0.72)
    eye = mat("MK_eye", (0.90, 0.90, 0.82), 0.22, 0.0, emission=(0.45, 0.46, 0.40))
    mouth = mat("MK_mouth", (0.025, 0.018, 0.014), 0.72)

    rig = make_armature()
    parts = []

    # Body: overlapping masses, remeshed into one lumpy hunched torso.
    masses = [
        sphere("mk_hip", (0, 0, 1.18), (1.02, 0.76, 0.62), skin, 18, 10, 0.04, 1),
        sphere("mk_belly", (0, 0.10, 1.78), (0.98, 0.82, 0.78), skin, 18, 10, 0.04, 2),
        sphere("mk_chest", (0, 0.02, 2.52), (1.16, 0.92, 0.82), skin, 18, 10, 0.05, 3),
        sphere("mk_hump", (0, -0.12, 3.10), (1.02, 0.86, 0.66), skin, 18, 10, 0.05, 4),
        sphere("mk_shoulder", (0, 0.0, 3.00), (1.45, 0.86, 0.42), skin, 18, 10, 0.03, 5),
    ]
    body = join_objects(masses, "MK_Body")
    remesh(body, 0.09)
    body.data.materials.clear()
    body.data.materials.append(skin)
    bind_weighted(body, rig)
    parts.append(body)

    # Head + maw.
    head_parts = [
        sphere("mk_skull", (0, 0.36, 3.86), (0.56, 0.58, 0.46), skin, 18, 10, 0.03, 10),
        sphere("mk_muzzle", (0, 0.78, 3.58), (0.45, 0.44, 0.30), skin, 16, 9, 0.025, 11),
    ]
    head = join_objects(head_parts, "MK_Head")
    remesh(head, 0.055)
    head.data.materials.clear()
    head.data.materials.append(skin)
    bind_rigid(head, rig, "Head")
    parts.append(head)

    jaw = sphere("MK_Jaw", (0, 0.82, 3.40), (0.42, 0.38, 0.16), skin, 14, 8, 0.02, 12)
    bind_rigid(jaw, rig, "Jaw")
    parts.append(jaw)
    mouth_in = sphere("MK_MouthInner", (0, 1.06, 3.48), (0.31, 0.06, 0.16), mouth, 12, 6, 0.0, 13)
    bind_rigid(mouth_in, rig, "Jaw")
    parts.append(mouth_in)

    # Bony horn stubs (user art brief; canon silhouette is otherwise unchanged).
    for side, sx in (("L", -1), ("R", 1)):
        horn = cone_between("MK_Horn_" + side, (sx * 0.28, 0.40, 4.10), (sx * 0.48, 0.54, 4.52),
                            0.085, 0.008, bone, 8)
        bind_rigid(horn, rig, "Head")
        parts.append(horn)

    # Five milky eyes across the brow, each in a dark socket.
    for i, x in enumerate((-0.44, -0.22, 0.0, 0.22, 0.44)):
        socket = sphere("MK_EyeSocket_%d" % i, (x, 1.00, 3.87), (0.115, 0.06, 0.11), mouth, 10, 6, 0.0, 20 + i)
        bind_rigid(socket, rig, "Head")
        parts.append(socket)
        e = sphere("MK_Eye_%d" % i, (x, 1.055, 3.87), (0.083, 0.055, 0.083), eye, 10, 6, 0.0, 30 + i)
        bind_rigid(e, rig, "Head")
        parts.append(e)

    # Open maw: a dark patch on the muzzle with two visible tooth rows.
    patch = sphere("MK_MouthPatch", (0, 1.105, 3.47), (0.33, 0.04, 0.17), mouth, 14, 8, 0.0, 40)
    bind_rigid(patch, rig, "Head")
    parts.append(patch)
    for i in range(18):
        a = (i / 17.0 - 0.5) * math.pi * 0.9
        x = math.sin(a) * 0.36
        y = 1.13 + math.cos(a) * 0.18
        base = (x, y, 3.55)
        tip = (x, y + 0.01, 3.40 if i % 2 == 0 else 3.68)
        t = make_tooth("MK_Tooth_U_%d" % i, base, tip, bone)
        bind_rigid(t, rig, "Head")
        parts.append(t)
    for i in range(12):
        a = (i / 11.0 - 0.5) * math.pi * 0.8
        x = math.sin(a) * 0.30
        y = 1.11 + math.cos(a) * 0.15
        base = (x, y, 3.38)
        tip = (x, y + 0.01, 3.55)
        t = make_tooth("MK_Tooth_L_%d" % i, base, tip, bone)
        bind_rigid(t, rig, "Jaw")
        parts.append(t)

    # Legs: short, thick, stumpy.
    for side, sx in (("L", -1), ("R", 1)):
        thigh = cone_between("MK_Thigh_" + side, (sx * 0.78, 0, 1.14), (sx * 0.86, 0.02, 0.66),
                             0.40, 0.32, skin, 10)
        bind_rigid(thigh, rig, "Thigh" + side)
        parts.append(thigh)
        shin = cone_between("MK_Shin_" + side, (sx * 0.86, 0.02, 0.68), (sx * 0.88, 0.18, 0.22),
                            0.30, 0.22, skin, 10)
        bind_rigid(shin, rig, "Shin" + side)
        parts.append(shin)
        foot = sphere("MK_Foot_" + side, (sx * 0.88, 0.38, 0.13), (0.30, 0.44, 0.13), skin, 14, 8, 0.02, 30)
        bind_rigid(foot, rig, "Foot" + side)
        parts.append(foot)

    # Long arms: two, with sword-length bone claws.
    for side, sx in (("L", -1), ("R", 1)):
        upper = cone_between("MK_LongUpper_" + side, (sx * 1.05, 0.05, 3.0), (sx * 1.38, 0.22, 2.10),
                             0.30, 0.20, skin, 10)
        bind_rigid(upper, rig, "LongUpper" + side)
        parts.append(upper)
        fore = cone_between("MK_LongFore_" + side, (sx * 1.38, 0.22, 2.12), (sx * 1.55, 0.48, 1.12),
                            0.20, 0.14, skin, 10)
        bind_rigid(fore, rig, "LongFore" + side)
        parts.append(fore)
        hand = sphere("MK_LongHand_" + side, (sx * 1.60, 0.55, 1.02), (0.20, 0.22, 0.16), skin, 12, 7, 0.02, 40)
        bind_rigid(hand, rig, "LongHand" + side)
        parts.append(hand)
        for j in range(3):
            a = (j - 1) * 0.28
            base = (sx * 1.60 + sx * a * 0.25, 0.62, 0.95)
            tip = (sx * 1.60 + sx * a * 0.55, 0.92, 0.30)
            claw = cone_between("MK_Claw_%s_%d" % (side, j), base, tip, 0.075, 0.004, bone, 7)
            bind_rigid(claw, rig, "LongHand" + side)
            parts.append(claw)

    # Short arms: two, with almost-human fingers.
    for side, sx in (("L", -1), ("R", 1)):
        upper = cone_between("MK_ShortUpper_" + side, (sx * 0.55, 0.65, 2.75), (sx * 0.95, 1.15, 2.15),
                             0.22, 0.16, skin, 10)
        bind_rigid(upper, rig, "ShortUpper" + side)
        parts.append(upper)
        fore = cone_between("MK_ShortFore_" + side, (sx * 0.95, 1.15, 2.16), (sx * 1.10, 1.45, 1.65),
                            0.15, 0.12, skin, 10)
        bind_rigid(fore, rig, "ShortFore" + side)
        parts.append(fore)
        hand = sphere("MK_ShortHand_" + side, (sx * 1.12, 1.50, 1.57), (0.14, 0.16, 0.11), skin, 12, 7, 0.0, 50)
        bind_rigid(hand, rig, "ShortHand" + side)
        parts.append(hand)
        for j in range(4):
            a = (j - 1.5) * 0.16
            base = (sx * 1.12 + a, 1.58, 1.49)
            tip = (sx * 1.12 + a * 1.6, 1.72, 1.31)
            finger = cone_between("MK_Finger_%s_%d" % (side, j), base, tip, 0.045, 0.012, skin, 6)
            bind_rigid(finger, rig, "ShortHand" + side)
            parts.append(finger)

    # Fur cloud sampled from the actual remeshed torso; two tints.
    fur_a = fur_cloud("MK_FurLight", fur_light, make_fur_points_from_mesh(body, 1200, 101), 101)
    bind_weighted(fur_a, rig)
    parts.append(fur_a)
    fur_b = fur_cloud("MK_FurDark", fur_dark, make_fur_points_from_mesh(body, 900, 202), 202)
    bind_weighted(fur_b, rig)
    parts.append(fur_b)

    # LOD1/LOD2: decimate all meshes; fewer fur tufts via decimation.
    lod1 = []
    lod2 = []
    for obj in parts:
        if obj.name.startswith("MK_Fur"):
            lod1.append(decimate_copy(obj, 0.35, "_LOD1"))
            continue
        lod1.append(decimate_copy(obj, 0.52, "_LOD1"))
        lod2.append(decimate_copy(obj, 0.22, "_LOD2"))
    parts.extend(lod1)
    parts.extend(lod2)

    build_animations(rig)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    export_glb(rig, parts, out_path)

    deps = bpy.context.evaluated_depsgraph_get()
    total = 0
    for obj in parts:
        ev = obj.evaluated_get(deps)
        me = ev.to_mesh()
        me.calc_loop_triangles()
        total += len(me.loop_triangles)
        ev.to_mesh_clear()
    zs = [(body.matrix_world @ v.co).z for v in body.data.vertices]
    print("BUILT_MOUNTAIN_KING", "TRIS", total, "BODY_HEIGHT", round(max(zs) - min(zs), 3), "OUT", out_path)


if __name__ == "__main__":
    out = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
    main(out)

"""Canonical Carapace Scavenger: procedural crab-like enemy with a 32-bone rig
and five clips (Idle, Walk, Telegraph, Attack, Death).

Output: assets/characters/enemies/carapace/carapace_scavenger.glb
Run: blender -b --factory-startup --python build_carapace_scavenger.py
"""
import bpy
import bmesh
import math
import os
import random
from mathutils import Vector, Euler

ROOT = r"C:\Users\user\Desktop\shadowslave"
OUT = os.path.join(ROOT, r"assets\characters\enemies\carapace\carapace_scavenger.glb")


def mat(name, color, roughness=0.7, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return m


def mesh_obj(name, bm, material):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if material:
        me.materials.append(material)
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    for p in me.polygons:
        p.use_smooth = True
    return obj


def sphere(name, center, scale, material, seg=16, rings=8, rough=0.0, seed=0):
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
    if d.length < 1e-6:
        return None
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=seg,
                          radius1=r1, radius2=r2, depth=d.length)
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix()
    mid = (start + end) * 0.5
    for v in bm.verts:
        v.co = rot @ v.co + mid
    return mesh_obj(name, bm, material)


def torus(name, center, major, minor, material, seg=24, sides=6):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                     major_segments=seg, minor_segments=sides,
                                     location=center)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.clear()
    obj.data.materials.append(material)
    return obj


def bind_rigid(obj, rig, bone_name):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.parent = rig
    obj.matrix_parent_inverse = rig.matrix_world.inverted()
    vg = obj.vertex_groups.new(name=bone_name)
    vg.add(range(len(obj.data.vertices)), 1.0, "REPLACE")
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    return obj


def make_armature():
    arm_data = bpy.data.armatures.new("CarapaceRig")
    rig = bpy.data.objects.new("CarapaceRig", arm_data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
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

    bone("Root", (0, 0, 0), (0, 0, 0.25))
    bone("Body", (0, 0, 0.45), (0, 0, 0.9), "Root")
    bone("Head", (0, 0.72, 0.63), (0, 1.02, 0.63), "Body")
    for side, sx in (("L", -1), ("R", 1)):
        bone("Mandible" + side, (sx * 0.14, 0.98, 0.56), (sx * 0.22, 1.22, 0.45), "Head")
        bone("ClawUpper" + side, (sx * 0.82, 0.35, 0.66), (sx * 1.16, 0.58, 0.52), "Body")
        bone("ClawFore" + side, (sx * 1.16, 0.58, 0.52), (sx * 1.34, 0.88, 0.44), "ClawUpper" + side, True)
        bone("Claw" + side, (sx * 1.34, 0.88, 0.44), (sx * 1.44, 1.16, 0.36), "ClawFore" + side, True)
        bone("ClawTip" + side, (sx * 1.44, 1.16, 0.36), (sx * 1.56, 1.38, 0.30), "Claw" + side, True)
    for pair, py in (("F", 0.34), ("M", 0.02), ("R", -0.32)):
        for side, sx in (("L", -1), ("R", 1)):
            hip = (sx * 0.58, py, 0.47)
            knee = (sx * (0.98 if pair != "M" else 1.06), py + 0.04, 0.26)
            foot = (sx * (1.18 if pair != "M" else 1.28), py + 0.08, 0.04)
            tip = (sx * (1.30 if pair != "M" else 1.40), py + 0.10, 0.0)
            bone("LegUpper" + pair + side, hip, knee, "Body")
            bone("LegLower" + pair + side, knee, foot, "LegUpper" + pair + side, True)
            bone("LegFoot" + pair + side, foot, tip, "LegLower" + pair + side, True)

    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


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

    act = new_action(rig, "Idle")
    act.frame_start = 1
    act.frame_end = 48
    for f, t in ((1, 0), (24, 1), (48, 0)):
        key_pose(rig, act, f, "Body", rot=(0.015 * t, 0, 0), loc=(0, 0, 0.012 * t))
        key_pose(rig, act, f, "Head", rot=(0.03 * t, 0.02 * t, 0))
        for side in ("L", "R"):
            key_pose(rig, act, f, "ClawUpper" + side, rot=(0.02 * t, 0, 0.03 * t))
            key_pose(rig, act, f, "ClawTip" + side, rot=(0, 0.18 * t if side == "L" else -0.18 * t, 0))
        for pair in ("F", "M", "R"):
            for side in ("L", "R"):
                key_pose(rig, act, f, "LegUpper" + pair + side, rot=(0.03 * t, 0, 0))
    actions.append(act)

    act = new_action(rig, "Walk")
    act.frame_start = 1
    act.frame_end = 32
    for f, t in ((1, 0), (8, 1), (16, 0), (24, -1), (32, 0)):
        key_pose(rig, act, f, "Body", rot=(0, 0.05 * t, 0), loc=(0.02 * t, 0, 0.02 * abs(t)))
        key_pose(rig, act, f, "Head", rot=(-0.04 * t, 0, 0))
        for side, sign in (("L", -1), ("R", 1)):
            key_pose(rig, act, f, "ClawUpper" + side, rot=(-0.18 * t * sign, 0, 0.06 * t))
            key_pose(rig, act, f, "ClawFore" + side, rot=(0.20 * t * sign, 0, 0))
        for pi, pair in enumerate(("F", "M", "R")):
            phase = 1 if (pi + (0 if pair == "F" else 1)) % 2 == 0 else -1
            for side, sign in (("L", -1), ("R", 1)):
                key_pose(rig, act, f, "LegUpper" + pair + side, rot=(0.0, 0.28 * t * phase * sign, 0.0))
                key_pose(rig, act, f, "LegLower" + pair + side, rot=(0.0, -0.18 * t * phase * sign, 0.0))
    actions.append(act)

    act = new_action(rig, "Telegraph")
    act.frame_start = 1
    act.frame_end = 24
    for f, t in ((1, 0), (12, 1), (24, 0.6)):
        key_pose(rig, act, f, "Body", rot=(-0.16 * t, 0, 0), loc=(0, 0, 0.06 * t))
        key_pose(rig, act, f, "Head", rot=(0.18 * t, 0, 0))
        for side, sign in (("L", -1), ("R", 1)):
            key_pose(rig, act, f, "ClawUpper" + side, rot=(0.20 * t, 0, sign * 0.45 * t))
            key_pose(rig, act, f, "ClawFore" + side, rot=(-0.35 * t, 0, 0))
            key_pose(rig, act, f, "ClawTip" + side, rot=(0, sign * 0.35 * t, 0))
    actions.append(act)

    act = new_action(rig, "Attack")
    act.frame_start = 1
    act.frame_end = 20
    for f, t in ((1, 0), (7, 1), (13, -0.8), (20, 0)):
        key_pose(rig, act, f, "Body", rot=(0.16 * t, 0, 0), loc=(0, 0.08 * t, 0))
        key_pose(rig, act, f, "Head", rot=(-0.12 * t, 0, 0))
        for side, sign in (("L", -1), ("R", 1)):
            key_pose(rig, act, f, "ClawUpper" + side, rot=(-0.65 * t, 0, -sign * 0.25 * t))
            key_pose(rig, act, f, "ClawFore" + side, rot=(0.80 * t, 0, 0))
            key_pose(rig, act, f, "ClawTip" + side, rot=(0, -sign * 0.38 * t, 0))
    actions.append(act)

    act = new_action(rig, "Death")
    act.frame_start = 1
    act.frame_end = 36
    for f, t in ((1, 0), (12, 0.5), (24, 1.0), (36, 1.0)):
        key_pose(rig, act, f, "Body", rot=(0.55 * t, 0.35 * t, 0.25 * t), loc=(0, 0, -0.12 * t))
        key_pose(rig, act, f, "Head", rot=(0.35 * t, 0, 0))
        for side, sign in (("L", -1), ("R", 1)):
            key_pose(rig, act, f, "ClawUpper" + side, rot=(-0.5 * t, 0, 0))
            key_pose(rig, act, f, "ClawFore" + side, rot=(0.4 * t, 0, 0))
        for pair in ("F", "M", "R"):
            for side, sign in (("L", -1), ("R", 1)):
                key_pose(rig, act, f, "LegUpper" + pair + side, rot=(0, 0, sign * 0.5 * t))
                key_pose(rig, act, f, "LegLower" + pair + side, rot=(0, 0, sign * 0.7 * t))
    actions.append(act)

    rig.animation_data.action = actions[0]
    return actions


def join_by_material(meshes):
    groups = {}
    for o in meshes:
        if len(o.data.materials) != 1:
            continue
        groups.setdefault(o.data.materials[0].name, []).append(o)
    for key, objs in groups.items():
        if len(objs) <= 1:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.object.join()
        obj = bpy.context.object
        obj.name = "Carapace_" + key.replace(".", "_")
        obj.data.name = obj.name
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def make_lod(source, name, ratio):
    bpy.ops.object.select_all(action="DESELECT")
    source.select_set(True)
    bpy.context.view_layer.objects.active = source
    bpy.ops.object.duplicate()
    obj = bpy.context.object
    obj.name = name
    obj.data.name = name
    mod = obj.modifiers.new("LOD_Decimate", "DECIMATE")
    mod.ratio = ratio
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_move_to_index(modifier=mod.name, index=0)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    random.seed(20261102)
    chitin = mat("Carapace_Chitin", (0.075, 0.012, 0.018), 0.48, 0.12)
    plate = mat("Carapace_Plate", (0.115, 0.020, 0.028), 0.42, 0.10)
    dark = mat("Carapace_Dark", (0.045, 0.010, 0.014), 0.62)
    bone = mat("Carapace_Bone", (0.58, 0.51, 0.37), 0.68)
    maw = mat("Carapace_Maw", (0.12, 0.012, 0.014), 0.52)

    rig = make_armature()
    parts = []

    # Body shell and underbelly.
    body = sphere("CSP_Shell", (0, 0, 0.72), (1.04, 0.86, 0.36), chitin, 20, 12, 0.025, 1)
    bind_rigid(body, rig, "Body"); parts.append(body)
    belly = sphere("CSP_Belly", (0, 0.02, 0.48), (0.92, 0.76, 0.24), dark, 18, 10, 0.02, 2)
    bind_rigid(belly, rig, "Body"); parts.append(belly)
    # Segmented plates.
    for i, y in enumerate((-0.28, 0.0, 0.28, 0.5)):
        p = sphere("CSP_Plate_%d" % i, (0, y, 0.93 - abs(y) * 0.10),
                   (0.88 - i * 0.05, 0.24, 0.10), plate, 16, 8, 0.015, 10 + i)
        bind_rigid(p, rig, "Body"); parts.append(p)
    # Rim and central ridge.
    rim = torus("CSP_Rim", (0, 0, 0.60), 1.0, 0.055, dark, 28, 6)
    bind_rigid(rim, rig, "Body"); parts.append(rim)
    ridge = sphere("CSP_Ridge", (0, 0.05, 1.00), (0.12, 0.72, 0.06), plate, 12, 8, 0.01, 4)
    bind_rigid(ridge, rig, "Body"); parts.append(ridge)
    # Bone spikes on the shell and around the rim.
    for i, (x, y, z) in enumerate(((-0.55, -0.15, 0.92), (0.55, -0.15, 0.92),
                                    (-0.62, 0.18, 0.94), (0.62, 0.18, 0.94),
                                    (-0.30, 0.42, 0.92), (0.30, 0.42, 0.92))):
        s = cone_between("CSP_Spike_%d" % i, (x, y, z), (x * 1.18, y * 1.15, z + 0.22),
                         0.075, 0.008, bone, 6)
        if s:
            bind_rigid(s, rig, "Body"); parts.append(s)
    for i, a in enumerate((0.0, 0.65, 1.30, 1.95, 2.60, 3.25, 3.90, 4.55, 5.20, 5.85)):
        x = math.cos(a) * 1.02
        y = math.sin(a) * 0.84
        s = cone_between("CSP_RimSpike_%d" % i, (x, y, 0.62), (x * 1.14, y * 1.14, 0.52),
                         0.055, 0.004, bone, 5)
        if s:
            bind_rigid(s, rig, "Body"); parts.append(s)
    # Barnacle-like nodules for a less plastic shell.
    for i, (x, y) in enumerate(((-0.72, 0.22), (0.64, -0.20), (-0.38, -0.42), (0.42, 0.34))):
        n = sphere("CSP_Nodule_%d" % i, (x, y, 0.98), (0.09, 0.08, 0.055), dark, 10, 6, 0.01, 70 + i)
        bind_rigid(n, rig, "Body"); parts.append(n)

    # Head, maw and mandibles.
    head = sphere("CSP_Head", (0, 0.92, 0.66), (0.34, 0.30, 0.22), chitin, 18, 10, 0.015, 20)
    bind_rigid(head, rig, "Head"); parts.append(head)
    maw_obj = sphere("CSP_Maw", (0, 1.14, 0.56), (0.19, 0.09, 0.09), maw, 12, 8, 0.0, 21)
    bind_rigid(maw_obj, rig, "Head"); parts.append(maw_obj)
    for side, sx in (("L", -1), ("R", 1)):
        mand = cone_between("CSP_Mandible_" + side, (sx * 0.15, 1.02, 0.56),
                            (sx * 0.25, 1.28, 0.44), 0.045, 0.006, bone, 6)
        bind_rigid(mand, rig, "Mandible" + side); parts.append(mand)
        # Small sensory bumps (no eyes, canon silhouette).
        for j in range(2):
            bump = sphere("CSP_Sensor_%s_%d" % (side, j), (sx * (0.16 + j * 0.07), 1.02, 0.74),
                          (0.035, 0.03, 0.03), dark, 8, 6, 0.0, 30 + j)
            bind_rigid(bump, rig, "Head"); parts.append(bump)
        horn = cone_between("CSP_HeadHorn_" + side, (sx * 0.18, 0.94, 0.78),
                            (sx * 0.30, 1.02, 0.98), 0.055, 0.004, bone, 6)
        if horn:
            bind_rigid(horn, rig, "Head"); parts.append(horn)
    crest = sphere("CSP_HeadCrest", (0, 0.92, 0.84), (0.22, 0.18, 0.07), plate, 14, 8, 0.01, 80)
    bind_rigid(crest, rig, "Head"); parts.append(crest)

    # Claws: upper/forearm, base, upper pincer, lower pincer.
    for side, sx in (("L", -1), ("R", 1)):
        upper = cone_between("CSP_ClawUpper_" + side, (sx * 0.82, 0.35, 0.66),
                             (sx * 1.16, 0.58, 0.52), 0.18, 0.13, chitin, 8)
        bind_rigid(upper, rig, "ClawUpper" + side); parts.append(upper)
        fore = cone_between("CSP_ClawFore_" + side, (sx * 1.16, 0.58, 0.52),
                            (sx * 1.34, 0.88, 0.44), 0.14, 0.10, chitin, 8)
        bind_rigid(fore, rig, "ClawFore" + side); parts.append(fore)
        base = sphere("CSP_ClawBase_" + side, (sx * 1.38, 0.99, 0.40), (0.16, 0.18, 0.11),
                      plate, 14, 8, 0.012, 40)
        bind_rigid(base, rig, "Claw" + side); parts.append(base)
        # Curved upper jaw of the pincer.
        up1 = cone_between("CSP_PincerUp1_" + side, (sx * 1.38, 1.04, 0.47),
                           (sx * 1.52, 1.28, 0.47), 0.10, 0.060, bone, 7)
        bind_rigid(up1, rig, "Claw" + side); parts.append(up1)
        up2 = cone_between("CSP_PincerUp2_" + side, (sx * 1.52, 1.28, 0.47),
                           (sx * 1.58, 1.48, 0.37), 0.060, 0.004, bone, 6)
        bind_rigid(up2, rig, "Claw" + side); parts.append(up2)
        # Separated lower jaw; it closes on ClawTip.
        low1 = cone_between("CSP_PincerLow1_" + side, (sx * 1.38, 1.04, 0.31),
                            (sx * 1.49, 1.26, 0.27), 0.080, 0.045, bone, 6)
        bind_rigid(low1, rig, "ClawTip" + side); parts.append(low1)
        low2 = cone_between("CSP_PincerLow2_" + side, (sx * 1.49, 1.26, 0.27),
                            (sx * 1.55, 1.42, 0.21), 0.045, 0.004, bone, 5)
        bind_rigid(low2, rig, "ClawTip" + side); parts.append(low2)
        # Serrations on the inner edges.
        for j in range(3):
            t = cone_between("CSP_ToothUp_%s_%d" % (side, j),
                             (sx * (1.44 + j * 0.035), 1.12 + j * 0.09, 0.44),
                             (sx * (1.44 + j * 0.035), 1.13 + j * 0.09, 0.36),
                             0.028, 0.003, bone, 5)
            if t:
                bind_rigid(t, rig, "Claw" + side); parts.append(t)
            t2 = cone_between("CSP_ToothLow_%s_%d" % (side, j),
                              (sx * (1.43 + j * 0.030), 1.12 + j * 0.09, 0.34),
                              (sx * (1.43 + j * 0.030), 1.13 + j * 0.09, 0.40),
                              0.022, 0.003, bone, 5)
            if t2:
                bind_rigid(t2, rig, "ClawTip" + side); parts.append(t2)

    # Six segmented legs.
    for pair, py in (("F", 0.34), ("M", 0.02), ("R", -0.32)):
        for side, sx in (("L", -1), ("R", 1)):
            knee_x = 0.98 if pair != "M" else 1.06
            foot_x = 1.18 if pair != "M" else 1.28
            tip_x = 1.30 if pair != "M" else 1.40
            up = cone_between("CSP_LegUpper_%s%s" % (pair, side), (sx * 0.58, py, 0.47),
                              (sx * knee_x, py + 0.04, 0.26), 0.105, 0.075, chitin, 8)
            bind_rigid(up, rig, "LegUpper" + pair + side); parts.append(up)
            low = cone_between("CSP_LegLower_%s%s" % (pair, side), (sx * knee_x, py + 0.04, 0.26),
                               (sx * foot_x, py + 0.08, 0.04), 0.075, 0.045, chitin, 8)
            bind_rigid(low, rig, "LegLower" + pair + side); parts.append(low)
            foot = cone_between("CSP_LegFoot_%s%s" % (pair, side), (sx * foot_x, py + 0.08, 0.04),
                                (sx * tip_x, py + 0.10, 0.0), 0.055, 0.004, bone, 6)
            bind_rigid(foot, rig, "LegFoot" + pair + side); parts.append(foot)
            # Joint cap and a small bone spur.
            cap = sphere("CSP_Knee_%s%s" % (pair, side), (sx * knee_x, py + 0.04, 0.27),
                         (0.075, 0.075, 0.065), plate, 10, 6, 0.0, 50)
            bind_rigid(cap, rig, "LegLower" + pair + side); parts.append(cap)
            spur = cone_between("CSP_LegSpur_%s%s" % (pair, side),
                                (sx * knee_x, py + 0.04, 0.30),
                                (sx * (knee_x + 0.08), py + 0.04, 0.44),
                                0.038, 0.004, bone, 5)
            if spur:
                bind_rigid(spur, rig, "LegLower" + pair + side); parts.append(spur)

    # Join rigid parts by material to keep draw calls sane.
    parts = join_by_material(parts)
    # LODs.
    lod1 = [make_lod(o, o.name + "_LOD1", 0.46) for o in parts]
    lod2 = [make_lod(o, o.name + "_LOD2", 0.18) for o in parts]
    all_meshes = parts + lod1 + lod2

    build_animations(rig)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in all_meshes:
        o.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=OUT,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_anim_single_armature=True,
        export_skins=True,
        export_yup=True,
    )

    total = 0
    for o in all_meshes:
        o.data.calc_loop_triangles()
        total += len(o.data.loop_triangles)
    print("CARAPACE_BUILT", "tris_total", total,
          "lod0", sum(len(o.data.loop_triangles) for o in parts),
          "lod1", sum(len(o.data.loop_triangles) for o in lod1),
          "lod2", sum(len(o.data.loop_triangles) for o in lod2),
          "bones", len(rig.data.bones), "actions", [a.name for a in bpy.data.actions],
          "out", OUT, "size", os.path.getsize(OUT))


if __name__ == "__main__":
    main()

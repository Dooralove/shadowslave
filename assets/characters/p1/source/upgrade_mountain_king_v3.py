"""Mountain King p3: readable short arms, stronger face, neck mane.

Input:  assets/characters/p1/models/mountain_king_p2.glb
Output: assets/characters/p1/models/mountain_king_p3.glb

Keeps the 25-bone rig and the five clips. LOD1/LOD2 are regenerated from the
edited LOD0. The short arms are pulled out of the fur and the face gets brow,
cheek, muzzle and jaw masses, plus a dark mane around the back of the head.
"""
import bpy
import bmesh
import math
import os
import random
from mathutils import Vector, Euler

ROOT = r"C:\Users\user\Desktop\shadowslave"
SRC = os.path.join(ROOT, r"assets\characters\p1\models\mountain_king_p2.glb")
OUT = os.path.join(ROOT, r"assets\characters\p1\models\mountain_king_p3.glb")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
scene = bpy.context.scene
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
lod0 = bpy.data.objects.get('MK_LOD0')
if lod0 is None:
    raise RuntimeError("MK_LOD0 not found")

# Clear the old LOD copies; we rebuild them after editing LOD0.
for name in ("MK_LOD1", "MK_LOD2", "Icosphere"):
    obj = bpy.data.objects.get(name)
    if obj:
        bpy.data.objects.remove(obj, do_unlink=True)

skin = bpy.data.materials.get("MK_skin")
bone = bpy.data.materials.get("MK_bone")
mouth = bpy.data.materials.get("MK_mouth")
fur_dark = bpy.data.materials.get("MK_fur_dark")


def mesh_obj(name, bm, mat):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if mat:
        me.materials.append(mat)
    obj = bpy.data.objects.new(name, me)
    scene.collection.objects.link(obj)
    for p in me.polygons:
        p.use_smooth = True
    return obj


def sphere(name, center, scale, mat, seg=16, rings=8):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2])) + Vector(center)
    return mesh_obj(name, bm, mat)


def cone(name, start, end, r1, r2, mat, seg=6):
    start, end = Vector(start), Vector(end)
    d = end - start
    if d.length < 1e-6:
        return None
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, cap_tris=False, segments=seg,
                          radius1=r1, radius2=r2, depth=d.length)
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix()
    mid = (start + end) * 0.5
    for v in bm.verts:
        v.co = rot @ v.co + mid
    return mesh_obj(name, bm, mat)


def bind_rigid(obj, bone_name):
    bpy.ops.object.select_all(action='DESELECT')
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


def smoothstep(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


# --- pull the short arms forward/outward so they clear the fur --------------------------
group_index = {g.name: g.index for g in lod0.vertex_groups}
short_names = {
    "L": ["ShortUpperL", "ShortForeL", "ShortHandL"],
    "R": ["ShortUpperR", "ShortForeR", "ShortHandR"],
}
for v in lod0.data.vertices:
    weights = {}
    for g in v.groups:
        name = lod0.vertex_groups[g.group].name
        if name.startswith("Short"):
            weights[name] = g.weight
    if not weights:
        continue
    side = "L" if sum(w for n, w in weights.items() if n.endswith("L")) >= sum(w for n, w in weights.items() if n.endswith("R")) else "R"
    sign = -1.0 if side == "L" else 1.0
    wu = max([weights.get("ShortUpper" + side, 0.0), 0.0])
    wf = max([weights.get("ShortFore" + side, 0.0), 0.0])
    wh = max([weights.get("ShortHand" + side, 0.0), 0.0])
    f = smoothstep(max(wu, wf, wh))
    dx = sign * (0.08 * wu + 0.15 * wf + 0.24 * wh)
    dy = 0.10 * wu + 0.17 * wf + 0.24 * wh
    dz = 0.01 * wu - 0.02 * wf - 0.05 * wh
    v.co += Vector((dx, dy, dz)) * f

# --- face masses -----------------------------------------------------------------------
face_parts = []
face_parts.append(bind_rigid(sphere("MK_BrowL", (-0.27, 0.96, 4.01), (0.21, 0.10, 0.075), skin), "Head"))
face_parts.append(bind_rigid(sphere("MK_BrowR", (0.27, 0.96, 4.01), (0.21, 0.10, 0.075), skin), "Head"))
face_parts.append(bind_rigid(sphere("MK_BrowMid", (0.0, 0.99, 4.03), (0.18, 0.09, 0.06), skin), "Head"))
face_parts.append(bind_rigid(sphere("MK_CheekL", (-0.41, 0.96, 3.67), (0.14, 0.11, 0.14), skin), "Head"))
face_parts.append(bind_rigid(sphere("MK_CheekR", (0.41, 0.96, 3.67), (0.14, 0.11, 0.14), skin), "Head"))
face_parts.append(bind_rigid(sphere("MK_MuzzleBridge", (0.0, 1.00, 3.73), (0.15, 0.10, 0.11), skin), "Head"))
face_parts.append(bind_rigid(sphere("MK_UpperLip", (0.0, 1.10, 3.58), (0.30, 0.035, 0.045), mouth), "Head"))
face_parts.append(bind_rigid(sphere("MK_LowerLip", (0.0, 1.10, 3.37), (0.28, 0.035, 0.040), mouth), "Head"))
face_parts.append(bind_rigid(sphere("MK_Chin", (0.0, 0.98, 3.27), (0.30, 0.16, 0.11), skin), "Jaw"))
face_parts.append(bind_rigid(sphere("MK_JawCornerL", (-0.27, 1.01, 3.36), (0.09, 0.08, 0.08), skin), "Jaw"))
face_parts.append(bind_rigid(sphere("MK_JawCornerR", (0.27, 1.01, 3.36), (0.09, 0.08, 0.08), skin), "Jaw"))
# A pair of short bone tusks at the mouth corners; canon already has a mouth full of teeth.
for side, sx in (("L", -1), ("R", 1)):
    t = cone("MK_Tusk_" + side, (sx * 0.28, 1.12, 3.44), (sx * 0.34, 1.24, 3.28), 0.035, 0.004, bone, 6)
    if t:
        face_parts.append(bind_rigid(t, "Jaw"))

# --- dark mane around the back/sides of the head ---------------------------------------
verts = []
faces = []
rng = random.Random(404)
for i in range(180):
    a = math.tau * i / 180.0
    rx, ry = 0.42, 0.30
    x = math.cos(a) * rx
    y = 0.06 + math.sin(a) * ry
    # Keep the face (+Y) clear; mane on back and sides.
    if y > 0.20:
        continue
    z = 3.44 + rng.uniform(-0.12, 0.12)
    base = Vector((x, y, z))
    direction = Vector((math.cos(a), math.sin(a), rng.uniform(-0.65, -0.25)))
    direction.normalize()
    length = rng.uniform(0.10, 0.20)
    radius = rng.uniform(0.022, 0.040)
    side = direction.cross(Vector((0, 0, 1)))
    if side.length < 1e-4:
        side = direction.cross(Vector((0, 1, 0)))
    side.normalize()
    up = side.cross(direction).normalized()
    p1 = base + direction * (length * 0.55) + Vector((0, 0, -0.03))
    p2 = base + direction * length + Vector((0, 0, -0.06))
    r0 = []
    r1 = []
    for k in range(4):
        ang = math.tau * k / 4.0 + math.pi / 4.0
        r0.append(base + side * (math.cos(ang) * radius) + up * (math.sin(ang) * radius))
        r1.append(p1 + side * (math.cos(ang) * radius * 0.5) + up * (math.sin(ang) * radius * 0.5))
    start = len(verts)
    verts.extend(r0 + r1 + [p2])
    for k in range(4):
        j = (k + 1) % 4
        faces.append((start + k, start + j, start + 4 + j, start + 4 + k))
        faces.append((start + 4 + k, start + 4 + j, start + 8))
mane = bpy.data.meshes.new("MK_Mane")
mane.from_pydata(verts, [], faces)
mane.materials.append(fur_dark)
mane_obj = bpy.data.objects.new("MK_Mane", mane)
scene.collection.objects.link(mane_obj)
for p in mane.polygons:
    p.use_smooth = True
bind_rigid(mane_obj, "Head")

# --- merge face + mane into LOD0 -------------------------------------------------------
bpy.ops.object.select_all(action='DESELECT')
lod0.select_set(True)
for o in face_parts + [mane_obj]:
    o.select_set(True)
bpy.context.view_layer.objects.active = lod0
bpy.ops.object.join()
lod0 = bpy.context.object
lod0.name = "MK_LOD0"
lod0.data.name = "MK_LOD0"

# --- rebuild LOD1/LOD2 ----------------------------------------------------------------
def make_lod(source, name, ratio):
    bpy.ops.object.select_all(action='DESELECT')
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

lod1 = make_lod(lod0, "MK_LOD1", 0.46)
lod2 = make_lod(lod0, "MK_LOD2", 0.18)

# --- export ----------------------------------------------------------------------------
bpy.ops.object.select_all(action='DESELECT')
for o in (lod0, lod1, lod2, rig):
    o.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(
    filepath=OUT,
    export_format='GLB',
    use_selection=True,
    export_apply=True,
    export_animations=True,
    export_animation_mode='ACTIONS',
    export_anim_single_armature=True,
    export_skins=True,
    export_yup=True,
)

tris = 0
for o in (lod0, lod1, lod2):
    o.data.calc_loop_triangles()
    tris += len(o.data.loop_triangles)
print("MK_P3_DONE", "tris", tris, "lod0", len(lod0.data.loop_triangles),
      "lod1", len(lod1.data.loop_triangles), "lod2", len(lod2.data.loop_triangles),
      "actions", [a.name for a in bpy.data.actions], "out", OUT, "size", os.path.getsize(OUT))

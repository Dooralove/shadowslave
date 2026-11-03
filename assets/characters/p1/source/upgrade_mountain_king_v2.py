"""Mountain King visual upgrade pass: matted fur tufts + merged LOD meshes.

Input:  assets/characters/p1/models/mountain_king_p1.glb
Output: assets/characters/p1/models/mountain_king_p2.glb

The armature, bone names and five clips stay untouched. Only the fur is rebuilt
as curved tufts and all rigid parts are joined into three LOD meshes so the GLB
does not ship 242 separate MeshInstance3D nodes.
"""
import bpy
import bmesh
import math
import os
import random
import sys
from mathutils import Vector

ROOT = r"C:\Users\user\Desktop\shadowslave"
SRC = os.path.join(ROOT, r"assets\characters\p1\models\mountain_king_p1.glb")
OUT = os.path.join(ROOT, r"assets\characters\p1\models\mountain_king_p2.glb")
PREVIEW = r"C:\Users\user\AppData\Local\Temp\opencode\enemy_audit\mountain_king_p2.png"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
scene = bpy.context.scene

meshes = [o for o in scene.objects if o.type == 'MESH' and o.name != 'Icosphere']
arm = next(o for o in scene.objects if o.type == 'ARMATURE')
body = next(o for o in meshes if o.name == 'MK_Body')

# --- remove old fur and old LOD copies -------------------------------------------------
def is_lod(o, level):
    return f"_LOD{level}" in o.name

old_fur = [o for o in meshes if o.name.startswith('MK_Fur')]
old_lods = [o for o in meshes if is_lod(o, 1) or is_lod(o, 2)]
for o in {o.name: o for o in old_fur + old_lods}.values():
    bpy.data.objects.remove(o, do_unlink=True)
meshes = [o for o in scene.objects if o.type == 'MESH' and o.name != 'Icosphere']

# --- generate curved matted fur tufts --------------------------------------------------
world_m = body.matrix_world
normal_m = world_m.to_3x3()
candidates = []
for v in body.data.vertices:
    p = world_m @ v.co
    if 1.05 <= p.z <= 3.50:
        n = (normal_m @ v.normal).normalized()
        # Prefer back/shoulders; keep some front fur but not a curtain over the face.
        w = 1.0
        if p.y > 0.30:
            w *= 0.25
        if p.z > 2.55:
            w *= 1.35
        candidates.append((v, p, n, w))

rng = random.Random(20261102)

def make_tufts(name, material, count, seed):
    rng = random.Random(seed)
    verts = []
    faces = []
    groups = []
    for _ in range(count):
        v, base, n, _w = rng.choices(candidates, weights=[c[3] for c in candidates], k=1)[0]
        # Drape the tuft down and slightly sideways; this reads as matted pelt, not quills.
        d = (n + Vector((0, 0, -0.75)) + Vector((rng.uniform(-0.28, 0.28),
                                                   rng.uniform(-0.22, 0.22),
                                                   rng.uniform(-0.10, 0.15)))).normalized()
        length = rng.uniform(0.20, 0.42)
        radius = rng.uniform(0.045, 0.085)
        droop = rng.uniform(0.06, 0.18)
        side = d.cross(Vector((0, 0, 1)))
        if side.length < 1e-3:
            side = d.cross(Vector((0, 1, 0)))
        side.normalize()
        up = side.cross(d).normalized()
        base = base + n * 0.005
        p1 = base + d * (length * 0.55) + Vector((0, 0, -droop * 0.45))
        p2 = base + d * length + Vector((0, 0, -droop))
        ring0 = []
        ring1 = []
        for i in range(4):
            a = math.tau * i / 4.0 + math.pi / 4.0
            ring0.append(base + side * (math.cos(a) * radius) + up * (math.sin(a) * radius))
            ring1.append(p1 + side * (math.cos(a) * radius * 0.48) + up * (math.sin(a) * radius * 0.48))
        start = len(verts)
        verts.extend(ring0 + ring1 + [p2])
        # 4 quads + 4 tip triangles
        for i in range(4):
            j = (i + 1) % 4
            faces.append((start + i, start + j, start + 4 + j, start + 4 + i))
        for i in range(4):
            j = (i + 1) % 4
            faces.append((start + 4 + i, start + 4 + j, start + 8))
        # copy the sampled body vertex weights to all nine tuft vertices
        weights = [(body.vertex_groups[g.group].name, g.weight) for g in v.groups if g.weight > 0.0]
        if not weights:
            weights = [("Spine", 1.0)]
        for _i in range(9):
            groups.append(weights)
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.materials.append(material)
    me.update()
    obj = bpy.data.objects.new(name, me)
    scene.collection.objects.link(obj)
    for gname in {g[0] for weights in groups for g in weights}:
        obj.vertex_groups.new(name=gname)
    for vi, weights in enumerate(groups):
        for gname, w in weights:
            obj.vertex_groups[gname].add([vi], w, 'REPLACE')
    obj.parent = arm
    obj.matrix_parent_inverse = arm.matrix_world.inverted()
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    for p in me.polygons:
        p.use_smooth = True
    return obj

fur_light = bpy.data.materials.get("MK_fur_light")
fur_dark = bpy.data.materials.get("MK_fur_dark")
light = make_tufts("MK_FurLight", fur_light, 1300, 101)
dark = make_tufts("MK_FurDark", fur_dark, 900, 202)

# --- join everything into 3 LOD meshes -------------------------------------------------
all_meshes = [o for o in scene.objects if o.type == 'MESH' and o.name != 'Icosphere']
def join_group(objects, name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    obj.data.name = name
    return obj

lod0 = join_group(all_meshes, "MK_LOD0")
# Duplicate LOD0 into LOD1/LOD2 and decimate while preserving skin weights.
def duplicate_lod(source, name, ratio):
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

lod1 = duplicate_lod(lod0, "MK_LOD1", 0.46)
lod2 = duplicate_lod(lod0, "MK_LOD2", 0.18)

# --- render preview --------------------------------------------------------------------
# Hide importer helper; use a neutral studio setup around the LOD0.
for o in scene.objects:
    if o.name == 'Icosphere':
        o.hide_render = True
        o.hide_set(True)
bpy.context.scene.frame_set(10)
mn = Vector((1e9, 1e9, 1e9)); mx = Vector((-1e9, -1e9, -1e9))
for o in [lod0]:
    for c in o.bound_box:
        p = o.matrix_world @ Vector(c)
        for i in range(3):
            mn[i] = min(mn[i], p[i]); mx[i] = max(mx[i], p[i])
center = (mn + mx) / 2
dims = mx - mn
maxdim = max(dims)
bpy.ops.mesh.primitive_plane_add(size=maxdim * 6, location=(center.x, center.y, mn.z - 0.01))
ground = bpy.context.object
gm = bpy.data.materials.new("AuditGround"); gm.use_nodes = True
gb = next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
gb.inputs["Base Color"].default_value = (0.02, 0.025, 0.03, 1); gb.inputs["Roughness"].default_value = 0.85
ground.data.materials.append(gm)
cam_data = bpy.data.cameras.new("AuditCam"); cam_data.lens = 52
cam = bpy.data.objects.new("AuditCam", cam_data); scene.collection.objects.link(cam)
cam.location = center + Vector((1.45, -2.1, 0.55)).normalized() * maxdim * 3.2 + Vector((0, 0, maxdim * 0.10))
cam.rotation_euler = (center - cam.location).to_track_quat('-Z', 'Y').to_euler()
scene.camera = cam
def area(name, loc, energy, size, color):
    d = bpy.data.lights.new(name, 'AREA'); d.energy = energy; d.size = size; d.color = color
    o = bpy.data.objects.new(name, d); scene.collection.objects.link(o); o.location = loc
    o.rotation_euler = (center - o.location).to_track_quat('-Z', 'Y').to_euler()
area("AuditKey", center + Vector((1.8, -2.2, 2.4)) * maxdim, 1000, maxdim * 1.7, (1.0, 0.9, 0.8))
area("AuditFill", center + Vector((-2.4, -1.2, 1.0)) * maxdim, 400, maxdim * 1.9, (0.5, 0.65, 1.0))
area("AuditRim", center + Vector((-0.6, 2.6, 1.8)) * maxdim, 700, maxdim * 1.3, (0.62, 0.8, 1.0))
world = bpy.data.worlds.new("AuditWorld"); world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
bg.inputs[0].default_value = (0.012, 0.016, 0.024, 1); bg.inputs[1].default_value = 0.25
scene.world = world
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 800; scene.render.resolution_y = 800
scene.render.image_settings.file_format = 'PNG'
scene.render.filepath = PREVIEW
bpy.ops.render.render(write_still=True)

# --- export ----------------------------------------------------------------------------
bpy.ops.object.select_all(action='DESELECT')
for o in [lod0, lod1, lod2, arm]:
    o.select_set(True)
bpy.context.view_layer.objects.active = arm
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
for o in [lod0, lod1, lod2]:
    me = o.data
    me.calc_loop_triangles()
    tris += len(me.loop_triangles)
print("MK_P2_DONE", "tris_total", tris, "lod0", len(lod0.data.loop_triangles),
      "lod1", len(lod1.data.loop_triangles), "lod2", len(lod2.data.loop_triangles),
      "materials", [m.name for m in lod0.data.materials], "out", OUT, "size", os.path.getsize(OUT))

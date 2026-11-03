"""Add a ragged sleeveless slave tunic + rope belt over the dressed nightmare
body. The sweater remains underneath as a coarse undershirt; the new tunic
changes the outer silhouette without a full garment retopo.
"""
import bpy, os, math
from mathutils import Vector

ROOT = r"C:\Users\user\Desktop\shadowslave"
SRC = os.path.join(ROOT, r"incoming_models\P0_characters\sunny_nightmare_v2_rigged_dressed.glb")
OUT = os.path.join(ROOT, r"incoming_models\P0_characters\sunny_nightmare_v2_rigged_tunic.glb")
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
body = next(o for o in bpy.context.scene.objects if o.type == 'MESH' and not o.name.startswith('Icosphere'))
print('BONES', [b.name for b in rig.data.bones])

# Tunic sections: (z, radius_x, radius_y)
rings = [
    (0.58, 0.19, 0.115),
    (0.48, 0.21, 0.13),
    (0.34, 0.205, 0.13),
    (0.16, 0.19, 0.125),
    (-0.02, 0.19, 0.13),
    (-0.18, 0.22, 0.15),
    (-0.30, 0.265, 0.18),
]
sides = 18
verts = []; faces = []
for ri, (z, rx, ry) in enumerate(rings):
    zoff = 0.0
    if ri == len(rings) - 1:
        zoff = -0.035
    start = len(verts)
    for s in range(sides):
        a = 2 * math.pi * s / sides
        # Ragged bottom hem: alternate length and radius.
        ragged = 0.0
        if ri == len(rings) - 1 and s % 3 == 0:
            ragged = -0.055
        verts.append((math.cos(a) * rx, math.sin(a) * ry, z + zoff + ragged))
    if ri > 0:
        prev = start - sides
        for s in range(sides):
            n = (s + 1) % sides
            faces.append((prev + s, prev + n, start + n, start + s))
# Open tube (no caps); the body closes the interior.
tunic_mesh = bpy.data.meshes.new('TunicMesh')
tunic_mesh.from_pydata(verts, [], faces); tunic_mesh.update()
tunic = bpy.data.objects.new('Tunic', tunic_mesh)
bpy.context.scene.collection.objects.link(tunic)
tm = bpy.data.materials.new('NightmareTunicOuter'); tm.use_nodes = True
tb = next(n for n in tm.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
tb.inputs['Base Color'].default_value = (0.155, 0.095, 0.060, 1)
tb.inputs['Roughness'].default_value = 0.96
tunic_mesh.materials.append(tm)

# Rope belt.
bpy.ops.mesh.primitive_torus_add(major_radius=0.205, minor_radius=0.018,
                                 major_segments=24, minor_segments=6,
                                 location=(0, 0, 0.07))
belt = bpy.context.object; belt.name = 'RopeBelt'
bm = bpy.data.materials.new('RopeBeltMat'); bm.use_nodes = True
bb = next(n for n in bm.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
bb.inputs['Base Color'].default_value = (0.12, 0.08, 0.045, 1)
bb.inputs['Roughness'].default_value = 0.95
belt.data.materials.append(bm)

# Rigid band weights by height on the tunic; belt to Hips.
for o in (tunic, belt):
    for vg in list(o.vertex_groups):
        o.vertex_groups.remove(vg)
groups = {n: tunic.vertex_groups.new(name=n) for n in ('Hips', 'Spine', 'Spine1')}
for v in tunic_mesh.vertices:
    z = v.co.z
    if z > 0.34:
        groups['Spine1'].add([v.index], 1.0, 'REPLACE')
    elif z > 0.08:
        groups['Spine'].add([v.index], 1.0, 'REPLACE')
    else:
        groups['Hips'].add([v.index], 1.0, 'REPLACE')
h = belt.vertex_groups.new(name='Hips'); h.add(list(range(len(belt.data.vertices))), 1.0, 'REPLACE')

# Join both into the body and export with the existing rig/actions.
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True); tunic.select_set(True); belt.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True); rig.select_set(True); bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(
    filepath=OUT, export_format='GLB', use_selection=True,
    export_animations=True, export_animation_mode='ACTIONS',
    export_anim_single_armature=True, export_skins=True, export_yup=True,
    export_apply=False,
)
print('WROTE', OUT, os.path.getsize(OUT), [m.name for m in body.data.materials])

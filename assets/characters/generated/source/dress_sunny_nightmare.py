"""Dress the image-to-3D Sunny nightmare v2 in slave colours.

The scan is one mesh with 148 islands. Head/hands keep the original skin/hair
texture; torso and sleeves become coarse brown cloth; legs become dark wool;
shoes become dirty leather. This is a placeholder outfit pass, not a retopo.
"""
import bpy, bmesh, os, sys
from mathutils import Vector

ROOT = r"C:\Users\user\Desktop\shadowslave"
SRC = os.path.join(ROOT, r"incoming_models\P0_characters\sunny_nightmare_v2_dressed_rigged.glb")
OUT = os.path.join(ROOT, r"incoming_models\P0_characters\sunny_nightmare_v2_rigged_dressed.glb")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
obj = next(o for o in bpy.context.scene.objects if o.type == 'MESH' and not o.name.startswith('Icosphere'))
me = obj.data
# Original material stays as slot 0 for skin/head/hands.
orig = me.materials[0] if me.materials else None

def add_mat(name, color, roughness=0.95):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs['Base Color'].default_value = (*color, 1.0)
    b.inputs['Roughness'].default_value = roughness
    me.materials.append(m)
    return len(me.materials) - 1

tunic = add_mat('NightmareTunic', (0.16, 0.10, 0.065))
trouser = add_mat('NightmareTrousers', (0.10, 0.09, 0.08))
shoe = add_mat('NightmareShoes', (0.12, 0.085, 0.06))

# Connected components.
bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
seen = set(); comps = []
for v in bm.verts:
    if v.index in seen: continue
    stack=[v]; seen.add(v.index); vs=[]
    while stack:
        cur=stack.pop(); vs.append(cur)
        for e in cur.link_edges:
            n=e.other_vert(cur)
            if n.index not in seen:
                seen.add(n.index); stack.append(n)
    comps.append(vs)
# Map vertex -> component; classify by component centroid.
vcomp = {}
for ci, comp in enumerate(comps):
    for v in comp:
        vcomp[v.index] = ci
centroids = []
for comp in comps:
    pts=[obj.matrix_world@v.co for v in comp]
    centroids.append(sum(pts, Vector())/len(pts))
print('COMPONENTS', len(comps))
for poly in me.polygons:
    ci = vcomp.get(poly.vertices[0])
    if ci is None:
        continue
    z = centroids[ci].z
    if z > 0.68:
        poly.material_index = 0
    elif z < -0.72:
        poly.material_index = shoe
    elif z < 0.0:
        poly.material_index = trouser
    else:
        poly.material_index = tunic
bm.free()
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); rig.select_set(True); bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(
    filepath=OUT, export_format='GLB', use_selection=True,
    export_apply=False, export_animations=True, export_animation_mode='ACTIONS',
    export_anim_single_armature=True, export_skins=True, export_yup=True,
)
print('WROTE', OUT, os.path.getsize(OUT), [m.name for m in me.materials])

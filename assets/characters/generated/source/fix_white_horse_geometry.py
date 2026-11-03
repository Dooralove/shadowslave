"""Geometry half of the white-horse cleanup.

- remove the flat photogrammetry tail (large islands 5-7)
- add a tapered tail weighted to Hips
- save body/muzzle UV point masks for the external texture pass
- export a rigged geometry GLB with the original diffuse map
"""
import bpy, bmesh, os, math
import numpy as np
from mathutils import Vector

ROOT = r"C:\Users\user\Desktop\shadowslave"
SRC = os.path.join(ROOT, r"incoming_models\P0_characters\white_horse_v2_rigged.glb")
OUT = os.path.join(ROOT, r"incoming_models\P0_characters\white_horse_v3_geom.glb")
POINT_DIR = os.path.join(ROOT, r"incoming_models\concepts\white_horse")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
obj = next(o for o in bpy.context.scene.objects if o.type == 'MESH' and not o.name.startswith('Icosphere'))
me = obj.data

# Save UV points before changing topology.
uv = me.uv_layers.active.data
body_tris = []; muzzle_tris = []; protect_tris = []

def tri_uv(poly):
    pts = []
    for li in poly.loop_indices:
        u, v = uv[li].uv
        pts.append((float(u % 1.0), float(v % 1.0)))
    if len(pts) == 3:
        return [pts]
    out = []
    for i in range(1, len(pts) - 1):
        out.append([pts[0], pts[i], pts[i + 1]])
    return out

for poly in me.polygons:
    c = obj.matrix_world @ poly.center
    if c.z > -0.04 and c.y > -0.55 and c.y < 0.62:
        body_tris.extend(tri_uv(poly))
    if c.y < -0.52 and -0.14 < c.z < 0.30:
        muzzle_tris.extend(tri_uv(poly))
    if c.y < -0.45 or c.z < -0.58:
        protect_tris.extend(tri_uv(poly))
os.makedirs(POINT_DIR, exist_ok=True)
np.save(os.path.join(POINT_DIR, 'body_uv_tris.npy'), np.array(body_tris, dtype=np.float32))
np.save(os.path.join(POINT_DIR, 'muzzle_uv_tris.npy'), np.array(muzzle_tris, dtype=np.float32))
np.save(os.path.join(POINT_DIR, 'protect_uv_tris.npy'), np.array(protect_tris, dtype=np.float32))
print('UV_TRIS', len(body_tris), len(muzzle_tris), len(protect_tris))

# Connected components, sorted by vertex count.
bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
seen = set(); comps = []
for v in bm.verts:
    if v.index in seen:
        continue
    stack = [v]; seen.add(v.index); vs = []
    while stack:
        cur = stack.pop(); vs.append(cur)
        for e in cur.link_edges:
            n = e.other_vert(cur)
            if n.index not in seen:
                seen.add(n.index); stack.append(n)
    comps.append(vs)
comps.sort(key=len, reverse=True)
tail_indices = set()
for idx in (5, 6, 7):
    if idx < len(comps):
        tail_indices.update(v.index for v in comps[idx])
# Remaining flat tail sheet islands are central and extend past the rump.
for comp in comps[8:]:
    pts_w = [obj.matrix_world @ v.co for v in comp]
    max_y = max(p.y for p in pts_w)
    cen = sum(pts_w, Vector()) / len(pts_w)
    if max_y > 0.90 and abs(cen.x) < 0.14 and max(p.z for p in pts_w) < 0.65:
        tail_indices.update(v.index for v in comp)
print('COMPONENTS', len(comps), 'REMOVE_TAIL', len(tail_indices))
del_verts = [v for v in bm.verts if v.index in tail_indices]
bmesh.ops.delete(bm, geom=del_verts, context='VERTS')
# Catch the remaining scan-tail fragments: they sit behind the rump and are
# not part of the four legs.
extra = []
for v in bm.verts:
    p = obj.matrix_world @ v.co
    if p.y > 0.78 and p.z < 0.55 and abs(p.x) < 0.35:
        extra.append(v)
bmesh.ops.delete(bm, geom=extra, context='VERTS')
print('EXTRA_TAIL_VERTS', len(extra))
bm.to_mesh(me); bm.free()

# New tapered tail from the rump.
pts = [
    Vector((0.00, 0.62, 0.48)), Vector((0.01, 0.80, 0.35)),
    Vector((0.02, 0.96, 0.12)), Vector((0.03, 1.07, -0.18)),
    Vector((0.04, 1.13, -0.50)),
]
radii = [0.080, 0.070, 0.052, 0.032, 0.010]
sides = 12
verts = []; faces = []
for i, (p, r) in enumerate(zip(pts, radii)):
    tangent = ((pts[i + 1] - p) if i < len(pts) - 1 else (p - pts[i - 1])).normalized()
    ax = Vector((1, 0, 0))
    ay = tangent.cross(ax)
    if ay.length < 1e-4:
        ay = tangent.cross(Vector((0, 1, 0)))
    ay.normalize(); ax = ay.cross(tangent).normalized()
    start = len(verts)
    # Flattened hair mass, wider across X than in depth.
    for s in range(sides):
        a = 2 * math.pi * s / sides
        verts.append(p + ax * (math.cos(a) * r * 1.45) + ay * (math.sin(a) * r * 0.55))
    if i > 0:
        prev = start - sides
        for s in range(sides):
            n = (s + 1) % sides
            faces.append((prev + s, prev + n, start + n, start + s))
faces.append(tuple(range(sides - 1, -1, -1)))
last = (len(pts) - 1) * sides
faces.append(tuple(last + s for s in range(sides)))
tail_mesh = bpy.data.meshes.new('TailMesh'); tail_mesh.from_pydata([tuple(v) for v in verts], [], faces); tail_mesh.update()
tail_obj = bpy.data.objects.new('Tail', tail_mesh); bpy.context.scene.collection.objects.link(tail_obj)
tail_mat = bpy.data.materials.new('TailCoat'); tail_mat.use_nodes = True
tb = next(n for n in tail_mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
tb.inputs['Base Color'].default_value = (0.82, 0.80, 0.75, 1); tb.inputs['Roughness'].default_value = 0.88
tail_mesh.materials.append(tail_mat)
vg = tail_obj.vertex_groups.new(name='Hips'); vg.add(list(range(len(tail_mesh.vertices))), 1.0, 'REPLACE')
bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); tail_obj.select_set(True)
bpy.context.view_layer.objects.active = obj; bpy.ops.object.join()
print('AFTER_JOIN', len(obj.data.vertices), len(obj.data.materials))

bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(
    filepath=OUT, export_format='GLB', use_selection=True,
    export_animations=True, export_animation_mode='ACTIONS',
    export_anim_single_armature=True, export_skins=True, export_yup=True,
    export_apply=False,
)
print('WROTE', OUT, os.path.getsize(OUT))

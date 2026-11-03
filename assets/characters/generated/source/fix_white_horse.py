"""Clean the generated white horse: remove the flat scan tail, rebuild a
tapered tail, whiten the body spots and inpaint the halter/muzzle band.

Input/output are GLB files with the native LeanHooved quadruped rig.
The script intentionally keeps the original skeleton and action set.
"""
import bpy, bmesh, os, sys, math
import numpy as np
import cv2
from mathutils import Vector

ROOT = r"C:\Users\user\Desktop\shadowslave"
SRC = os.path.join(ROOT, r"incoming_models\P0_characters\white_horse_v2_rigged.glb")
OUT = os.path.join(ROOT, r"incoming_models\P0_characters\white_horse_v3_fixed.glb")
TEX_OUT = os.path.join(ROOT, r"incoming_models\concepts\white_horse\white_horse_v3_diffuse.png")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
obj = next(o for o in bpy.context.scene.objects if o.type == 'MESH' and not o.name.startswith('Icosphere'))
me = obj.data
print('MESH', obj.name, len(me.vertices), 'BONES', len(rig.data.bones))
print('GROUPS', len(obj.vertex_groups), [g.name for g in obj.vertex_groups][:10])

# --- identify connected components, sorted by size -------------------------
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
print('COMPONENTS', len(comps))
for i in range(min(10, len(comps))):
    mn = Vector((1e9, 1e9, 1e9)); mx = Vector((-1e9, -1e9, -1e9))
    for v in comps[i]:
        p = obj.matrix_world @ v.co
        for k in range(3): mn[k] = min(mn[k], p[k]); mx[k] = max(mx[k], p[k])
    print('COMP', i, len(comps[i]), [round(x, 3) for x in mn], [round(x, 3) for x in mx])

# Tail is the flat sheet made of the three large islands 5, 6, 7 (0-based,
# sorted by vertex count).  Remove them; the hind-leg islands remain.
tail_indices = set()
for idx in (5, 6, 7):
    if idx < len(comps):
        for v in comps[idx]:
            tail_indices.add(v.index)
print('REMOVE_TAIL_VERTS', len(tail_indices))
bm.free()

# Remove tail geometry using bmesh.
bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
del_verts = [v for v in bm.verts if v.index in tail_indices]
bmesh.ops.delete(bm, geom=del_verts, context='VERTS')
bm.to_mesh(me); bm.free()
print('AFTER_TAIL', len(me.vertices), len(me.polygons))

# --- rebuild a tapered tail -------------------------------------------------
# Base at the rump; points flow back and down. Coordinates from the horse scan.
pts = [
    Vector((0.00, 0.61, 0.50)),
    Vector((0.01, 0.78, 0.44)),
    Vector((0.02, 0.93, 0.25)),
    Vector((0.03, 1.04, -0.05)),
    Vector((0.04, 1.11, -0.38)),
    Vector((0.045, 1.14, -0.68)),
    Vector((0.04, 1.13, -0.88)),
]
radii = [0.115, 0.105, 0.090, 0.075, 0.058, 0.040, 0.018]
sides = 10
verts = []; faces = []
for i, (p, r) in enumerate(zip(pts, radii)):
    if i < len(pts) - 1:
        tangent = (pts[i + 1] - p).normalized()
    else:
        tangent = (p - pts[i - 1]).normalized()
    # Frame: keep one axis roughly world X, the other perpendicular.
    ax = Vector((1, 0, 0))
    ay = tangent.cross(ax)
    if ay.length < 1e-4:
        ay = tangent.cross(Vector((0, 1, 0)))
    ay.normalize()
    ax = ay.cross(tangent).normalized()
    start = len(verts)
    for s in range(sides):
        a = 2 * math.pi * s / sides
        verts.append(p + ax * (math.cos(a) * r) + ay * (math.sin(a) * r))
    if i > 0:
        prev = start - sides
        for s in range(sides):
            n = (s + 1) % sides
            faces.append((prev + s, prev + n, start + n, start + s))
# caps
faces.append(tuple(range(sides - 1, -1, -1)))
last = (len(pts) - 1) * sides
faces.append(tuple(last + s for s in range(sides)))
tail_mesh = bpy.data.meshes.new('TailMesh')
tail_mesh.from_pydata([tuple(v) for v in verts], [], faces)
tail_mesh.update()
tail_obj = bpy.data.objects.new('Tail', tail_mesh)
bpy.context.scene.collection.objects.link(tail_obj)
# Soft white-grey tail material.
tail_mat = bpy.data.materials.new('TailCoat')
tail_mat.use_nodes = True
tb = next(n for n in tail_mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
tb.inputs['Base Color'].default_value = (0.82, 0.80, 0.75, 1)
tb.inputs['Roughness'].default_value = 0.88
tail_mesh.materials.append(tail_mat)
# Weight the new tail entirely to Hips so the native quadruped actions move it.
vg = tail_obj.vertex_groups.new(name='Hips')
vg.add(list(range(len(tail_mesh.vertices))), 1.0, 'REPLACE')
# Join into the horse mesh, keeping the armature modifier from the horse.
bpy.ops.object.select_all(action='DESELECT')
obj.select_set(True); tail_obj.select_set(True)
bpy.context.view_layer.objects.active = obj
bpy.ops.object.join()
print('AFTER_JOIN', len(obj.data.vertices), len(obj.data.materials))

# --- clean the diffuse texture ---------------------------------------------
img = bpy.data.images.get('texture_diffuse')
if img is None:
    for im in bpy.data.images:
        if 'diffuse' in im.name.lower():
            img = im; break
print('IMAGE', img.name if img else None, img.size[:] if img else None)
if img is not None:
    w, h = img.size[:]
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    rgb = np.clip(px[..., :3] * 255.0, 0, 255).astype(np.uint8)
    bgr = cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)

    # Build UV masks from 3D regions. Body: torso/neck/rump, not legs/head/tail.
    uv = me.uv_layers.active.data
    body_pts = []; muzzle_pts = []
    for poly in me.polygons:
        c = obj.matrix_world @ poly.center
        if c.z > -0.04 and c.y > -0.55 and c.y < 0.62:
            for li in poly.loop_indices:
                u, v = uv[li].uv
                body_pts.append((u % 1.0, v % 1.0))
        if c.y < -0.52 and -0.14 < c.z < 0.30:
            for li in poly.loop_indices:
                u, v = uv[li].uv
                muzzle_pts.append((u % 1.0, v % 1.0))
    def raster(points, dilate=7):
        m = np.zeros((h, w), np.uint8)
        for u, v in points:
            x = int(u * (w - 1)); y = int((1.0 - v) * (h - 1))
            if 0 <= x < w and 0 <= y < h:
                m[y, x] = 255
        k = np.ones((dilate, dilate), np.uint8)
        m = cv2.dilate(m, k, iterations=1)
        m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, k)
        return m
    body_mask = raster(body_pts, 9)
    muzzle_mask = raster(muzzle_pts, 11)
    print('MASK_COVERAGE', round(float((body_mask > 0).mean()), 4), round(float((muzzle_mask > 0).mean()), 4))

    # Spots are small dark islands on the coat. Median filtering inside the body
    # mask removes them without touching eyes, hooves or the mane.
    median = cv2.medianBlur(bgr, 5)
    m3 = (body_mask > 0)[..., None]
    bgr = np.where(m3, median, bgr)
    # The halter/muzzle band is inpainted from the surrounding coat.
    bgr = cv2.inpaint(bgr, muzzle_mask, 7, cv2.INPAINT_TELEA)
    # Very dark isolated specks on the body: replace with local median.
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    dark = ((gray < 95) & (body_mask > 0)).astype(np.uint8) * 255
    n, labels, stats, _ = cv2.connectedComponentsWithStats(dark, 8)
    spot_mask = np.zeros((h, w), np.uint8)
    for i in range(1, n):
        if stats[i, cv2.CC_STAT_AREA] < 1800:
            spot_mask[labels == i] = 255
    bgr = cv2.inpaint(bgr, spot_mask, 5, cv2.INPAINT_TELEA)

    rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
    px[..., :3] = rgb
    img.pixels = px.ravel()
    img.pack()
    os.makedirs(os.path.dirname(TEX_OUT), exist_ok=True)
    cv2.imwrite(TEX_OUT, cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB))
    print('WROTE_TEXTURE', TEX_OUT)

# --- export -----------------------------------------------------------------
bpy.ops.object.select_all(action='DESELECT')
obj.select_set(True); rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(
    filepath=OUT, export_format='GLB', use_selection=True,
    export_animations=True, export_animation_mode='ACTIONS',
    export_anim_single_armature=True, export_skins=True, export_yup=True,
    export_apply=False,
)
print('WROTE', OUT, os.path.getsize(OUT))

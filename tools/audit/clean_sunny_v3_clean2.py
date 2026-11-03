"""Clean the generated Sunny v3 GLB:
- remove the fused sword blade (loose components 36-45 in the z-sorted list);
- make the root-motion walk/landroll clips in-place by removing Hips forward drift;
- export a new GLB with the armature and all 10 clips.

Run:
  blender --background --factory-startup --python tools/audit/clean_sunny_v3.py
"""
import bpy
import bmesh
import os

SRC = r"C:\Users\user\Desktop\shadowslave\assets\characters\generated\sunny_real_v3\sunny_real_v3.glb"
DST = r"C:\Users\user\Desktop\shadowslave\assets\characters\generated\sunny_real_v3\sunny_real_v3_clean2.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)

mesh = bpy.data.objects.get("model")
if mesh is None:
    mesh = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]

# Remove the fused sword blade: components in the low-left region, sorted by min z.
bm = bmesh.new()
bm.from_mesh(mesh.data)
bm.verts.ensure_lookup_table()
seen = set()
comps = []
for v in bm.verts:
    if v.index in seen:
        continue
    stack = [v]
    comp = []
    seen.add(v.index)
    while stack:
        cur = stack.pop()
        comp.append(cur.index)
        for e in cur.link_edges:
            other = e.other_vert(cur)
            if other.index not in seen:
                seen.add(other.index)
                stack.append(other)
    comps.append(comp)
comps.sort(key=lambda c: min(bm.verts[j].co.z for j in c), reverse=True)
to_delete = []
for idx in range(36, 46):
    if idx < len(comps):
        to_delete.extend(comps[idx])
print("SWORD_VERTS_DELETED", len(to_delete))
bmesh.ops.delete(bm, geom=[bm.verts[i] for i in to_delete], context='VERTS')
bm.to_mesh(mesh.data)
bm.free()
mesh.data.update()

# Remove Hips forward drift from root-motion clips. idx 2 is the forward axis
# in the imported armature's Hips local space (walk: 0 -> 6.96 m over 4.13 s).
ROOT_MOTION_CLIPS = {"HumanRelaxedWalkLoopF", "HumanLandrollR"}
for action in bpy.data.actions:
    if action.name not in ROOT_MOTION_CLIPS:
        continue
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    if "Hips" not in fc.data_path or "location" not in fc.data_path or fc.array_index != 2:
                        continue
                    points = fc.keyframe_points
                    if len(points) < 2:
                        continue
                    first = points[0].co[1]
                    last = points[-1].co[1]
                    drift = last - first
                    start = points[0].co[0]
                    end = points[-1].co[0]
                    span = max(end - start, 0.0001)
                    for kp in points:
                        t = (kp.co[0] - start) / span
                        kp.co[1] -= drift * t
                        kp.handle_left[1] -= drift * t
                        kp.handle_right[1] -= drift * t
                    fc.update()
                    print("ROOT_MOTION_FIXED", action.name, "drift", drift)

# Export the armature + skinned mesh (exclude the stray Icosphere).
for mat in bpy.data.materials:
    mat.use_backface_culling = True
for obj in bpy.context.scene.objects:
    obj.select_set(obj.type in {'ARMATURE', 'MESH'} and obj.name != "Icosphere")
armature = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
bpy.context.view_layer.objects.active = armature
bpy.ops.export_scene.gltf(
    filepath=DST,
    export_format='GLB',
    use_selection=True,
    export_animations=True,
    export_animation_mode='ACTIONS',
    export_skins=True,
    export_yup=True,
    export_apply=False,
    export_tangents=True,
)
print("EXPORTED", DST, os.path.getsize(DST))

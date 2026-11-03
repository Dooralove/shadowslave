"""Rigid-island weight cleanup for the Centurion.

The generated armour is a set of hard plates plus body islands. Automatic weights
stretch plates across bones. Assign each connected island rigidly to its nearest
deform bone; this preserves the plate silhouette during animation.
"""
import bpy
import os
from mathutils import Vector

ROOT = r"C:\Users\user\Desktop\shadowslave"
SRC = os.path.join(ROOT, r"incoming_models\P1_monsters\carapace_centurion_gen_image_anim.glb")
OUT = os.path.join(ROOT, r"incoming_models\P1_monsters\carapace_centurion_gen_image_rigid.glb")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
rig = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
obj = next(o for o in bpy.context.scene.objects if o.type == "MESH" and o.name != "Icosphere")
me = obj.data
print("VERTS", len(me.vertices), "BONES", len(rig.data.bones))

# Bone segments in world space.
segments = []
for b in rig.data.bones:
    if not b.use_deform:
        continue
    a = rig.matrix_world @ b.head_local
    c = rig.matrix_world @ b.tail_local
    segments.append((b.name, a, c))


def dist_to_segment(p, a, c):
    ab = c - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length


# Connected components.
adj = [[] for _ in me.vertices]
for e in me.edges:
    a, b = e.vertices
    adj[a].append(b); adj[b].append(a)
seen = [False] * len(me.vertices)
islands = []
for i in range(len(me.vertices)):
    if seen[i]:
        continue
    stack = [i]; seen[i] = True; comp = []
    while stack:
        v = stack.pop(); comp.append(v)
        for n in adj[v]:
            if not seen[n]:
                seen[n] = True; stack.append(n)
    islands.append(comp)
print("ISLANDS", len(islands))

# Remove old groups and create one per deform bone used.
obj.vertex_groups.clear()
groups = {}
for name, _, _ in segments:
    groups[name] = obj.vertex_groups.new(name=name)

for comp in islands:
    pts = [obj.matrix_world @ me.vertices[i].co for i in comp]
    center = sum(pts, Vector()) / len(pts)
    best = min(segments, key=lambda s: dist_to_segment(center, s[1], s[2]))
    groups[best[0]].add(comp, 1.0, "REPLACE")

print("RIGIDIFIED", len(islands))
bpy.ops.object.select_all(action="DESELECT")
obj.select_set(True); rig.select_set(True); bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(
    filepath=OUT, export_format="GLB", use_selection=True, export_apply=True,
    export_animations=True, export_animation_mode="ACTIONS",
    export_anim_single_armature=True, export_skins=True, export_yup=True,
)
print("WROTE", OUT, os.path.getsize(OUT))

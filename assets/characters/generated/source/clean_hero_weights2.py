"""Clean automatic skin weights on the generated Hero.

The CLI's human rig is usable, but arms-down generation makes the tunic/belt
vertices close to the hands. Whole cloth islands receive partial hand weights
and stretch during walk/attack. Remove hand/finger weights from islands whose
center is away from the actual hand bones; keep real hand/finger islands intact.
"""
import bpy
import os
from mathutils import Vector

ROOT = r"C:\Users\user\Desktop\shadowslave"
SRC = os.path.join(ROOT, r"incoming_models\P0_characters\hero_auro_v3_rigged.glb")
OUT = os.path.join(ROOT, r"incoming_models\P0_characters\hero_auro_v3_rigged_clean2.glb")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
rig = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
mesh_obj = next(o for o in bpy.context.scene.objects if o.type == "MESH" and o.name != "Icosphere")
mesh = mesh_obj.data

hand_group_indices = {g.index for g in mesh_obj.vertex_groups
                      if g.name.startswith("LeftHand") or g.name.startswith("RightHand")}
hand_centers = []
for name in ("LeftHand", "RightHand"):
    b = rig.data.bones.get(name)
    if b:
        hand_centers.append(rig.matrix_world @ ((b.head_local + b.tail_local) * 0.5))
print("HAND_CENTERS", [tuple(round(v, 3) for v in p) for p in hand_centers])

# Connected components (islands) by mesh edges.
adj = [[] for _ in mesh.vertices]
for e in mesh.edges:
    a, b = e.vertices
    adj[a].append(b)
    adj[b].append(a)
seen = [False] * len(mesh.vertices)
islands = []
for i in range(len(mesh.vertices)):
    if seen[i]:
        continue
    stack = [i]
    seen[i] = True
    comp = []
    while stack:
        v = stack.pop()
        comp.append(v)
        for n in adj[v]:
            if not seen[n]:
                seen[n] = True
                stack.append(n)
    islands.append(comp)
print("ISLANDS", len(islands))


def ensure_group(name):
    g = mesh_obj.vertex_groups.get(name)
    if g is None:
        g = mesh_obj.vertex_groups.new(name=name)
    return g

hips = ensure_group("Hips")
spine1 = ensure_group("Spine1")

cleaned_islands = 0
cleaned_verts = 0
for comp in islands:
    center = sum((mesh_obj.matrix_world @ mesh.vertices[i].co for i in comp), Vector()) / len(comp)
    nearest_hand = min((center - c).length for c in hand_centers)
    if nearest_hand <= 0.16:
        # Actual hand / finger island: preserve.
        continue
    has_hand = False
    for i in comp:
        for g in mesh.vertices[i].groups:
            if g.group in hand_group_indices:
                has_hand = True
                break
        if has_hand:
            break
    if not has_hand:
        continue
    for i in comp:
        v = mesh.vertices[i]
        remaining = [(g.group, g.weight) for g in v.groups if g.group not in hand_group_indices]
        for g in list(v.groups):
            if g.group in hand_group_indices:
                mesh_obj.vertex_groups[g.group].remove([i])
                cleaned_verts += 1
        if not remaining:
            target = spine1 if v.co.z > 0.0 else hips
            target.add([i], 1.0, "REPLACE")
        else:
            total = sum(w for _, w in remaining)
            if total > 0:
                for gi, w in remaining:
                    mesh_obj.vertex_groups[gi].add([i], w / total, "REPLACE")
    cleaned_islands += 1

print("CLEANED_ISLANDS", cleaned_islands, "CLEANED_VERTS", cleaned_verts)

bpy.ops.object.select_all(action="DESELECT")
mesh_obj.select_set(True)
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
print("WROTE", OUT, os.path.getsize(OUT))

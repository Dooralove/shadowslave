"""Clean automatic skin weights on the generated Hero.

The CLI's human rig is usable, but arms-down generation makes the tunic/belt
vertices close to the hands. Those vertices receive hand weights and stretch
during walk/attack. Reassign only cloth vertices that are far from the hand
bones; actual fingers/hand geometry is preserved.
"""
import bpy
import os
from mathutils import Vector

ROOT = r"C:\Users\user\Desktop\shadowslave"
SRC = os.path.join(ROOT, r"incoming_models\P0_characters\hero_auro_v3_rigged.glb")
OUT = os.path.join(ROOT, r"incoming_models\P0_characters\hero_auro_v3_rigged_clean.glb")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
rig = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
mesh_obj = next(o for o in bpy.context.scene.objects if o.type == "MESH" and o.name != "Icosphere")
mesh = mesh_obj.data

# Hand/finger group names; all of them can steal cloth.
hand_group_names = [g.name for g in mesh_obj.vertex_groups
                    if g.name.startswith("LeftHand") or g.name.startswith("RightHand")]
hand_group_indices = {g.index for g in mesh_obj.vertex_groups
                      if g.name in hand_group_names}
print("HAND_GROUPS", hand_group_names)

# World-space hand bone centers.
hand_centers = []
for name in ("LeftHand", "RightHand"):
    b = rig.data.bones.get(name)
    if b:
        p = rig.matrix_world @ ((b.head_local + b.tail_local) * 0.5)
        hand_centers.append(p)
print("HAND_CENTERS", [tuple(round(v, 3) for v in p) for p in hand_centers])


def ensure_group(name):
    g = mesh_obj.vertex_groups.get(name)
    if g is None:
        g = mesh_obj.vertex_groups.new(name=name)
    return g


hips = ensure_group("Hips")
spine1 = ensure_group("Spine1")

# Build a fast per-vertex group list.
changed = 0
for v in mesh.vertices:
    hand_w = 0.0
    other = []
    for g in v.groups:
        if g.group in hand_group_indices:
            hand_w += g.weight
        else:
            other.append((g.group, g.weight))
    if hand_w <= 0.02:
        continue
    world = mesh_obj.matrix_world @ v.co
    nearest = min((world - c).length for c in hand_centers)
    # Preserve actual hand/fingers and wrist-adjacent cloth.
    if nearest < 0.20:
        continue
    # Remove hand/finger weights from this vertex.
    for g in list(v.groups):
        if g.group in hand_group_indices:
            mesh_obj.vertex_groups[g.group].remove([v.index])
    # If no other weights remain, bind the cloth to the torso.
    if not other:
        target = spine1 if v.co.z > 0.0 else hips
        target.add([v.index], 1.0, "REPLACE")
    else:
        total = sum(w for _, w in other)
        if total > 0:
            for gi, w in other:
                mesh_obj.vertex_groups[gi].add([v.index], w / total, "REPLACE")
    changed += 1

print("CLEANED_VERTICES", changed)

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

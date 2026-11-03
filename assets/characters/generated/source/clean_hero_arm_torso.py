"""Remove arm weights from torso/cloth vertices on the generated Hero.

The long belt/cord artefact is caused by vertices that carry both a torso group
and a hand/forearm group. Keep the torso weights, drop the arm/hand weights.
"""
import bpy
import os

ROOT = r"C:\Users\user\Desktop\shadowslave"
SRC = os.path.join(ROOT, r"incoming_models\P0_characters\hero_auro_v3_rigged.glb")
OUT = os.path.join(ROOT, r"incoming_models\P0_characters\hero_auro_v3_rigged_clean6.glb")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
rig = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
obj = next(o for o in bpy.context.scene.objects if o.type == "MESH" and o.name != "Icosphere")
me = obj.data
gname = {g.index: g.name for g in obj.vertex_groups}
hand_arm = ("LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand")
torso = ("Hips", "Spine")
hips = obj.vertex_groups.get("Hips") or obj.vertex_groups.new(name="Hips")
spine1 = obj.vertex_groups.get("Spine1") or obj.vertex_groups.new(name="Spine1")

cleaned = 0
for v in me.vertices:
    names = [(g.group, g.weight, gname.get(g.group, "")) for g in v.groups]
    has_arm = any(n.startswith(hand_arm) and w > 0.02 for _, w, n in names)
    has_torso = any(n.startswith(torso) and w > 0.02 for _, w, n in names)
    if not (has_arm and has_torso):
        continue
    keep = [(gi, w) for gi, w, n in names if n.startswith(torso) and w > 0.02]
    for gi, w, n in names:
        if n.startswith(hand_arm):
            obj.vertex_groups[gi].remove([v.index])
    if keep:
        total = sum(w for _, w in keep)
        for gi, w in keep:
            obj.vertex_groups[gi].add([v.index], w / total, "REPLACE")
    else:
        target = spine1 if v.co.z > 0.0 else hips
        target.add([v.index], 1.0, "REPLACE")
    cleaned += 1

print("ARM_TORSO_CLEANED", cleaned)
bpy.ops.object.select_all(action="DESELECT")
obj.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(
    filepath=OUT, export_format="GLB", use_selection=True, export_apply=True,
    export_animations=True, export_animation_mode="ACTIONS",
    export_anim_single_armature=True, export_skins=True, export_yup=True,
)
print("WROTE", OUT, os.path.getsize(OUT))

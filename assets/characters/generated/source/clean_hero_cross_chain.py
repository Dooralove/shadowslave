"""Remove cross-chain bad weights on the generated Hero.

Some cloth vertices received both LeftHand and LeftUpLeg weights (and similar
arm+leg combinations). They stretch between the hand and leg. Reassign any
vertex that has both a leg-chain and an arm-chain group to Hips, preserving
existing torso weights when present.
"""
import bpy
import os

ROOT = r"C:\Users\user\Desktop\shadowslave"
SRC = os.path.join(ROOT, r"incoming_models\P0_characters\hero_auro_v3_rigged.glb")
OUT = os.path.join(ROOT, r"incoming_models\P0_characters\hero_auro_v3_rigged_clean5.glb")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
rig = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
obj = next(o for o in bpy.context.scene.objects if o.type == "MESH" and o.name != "Icosphere")
me = obj.data
gname = {g.index: g.name for g in obj.vertex_groups}

leg_prefixes = ("LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToe", "RightUpLeg", "RightLeg", "RightFoot", "RightToe")
arm_prefixes = ("LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand")
hips = obj.vertex_groups.get("Hips") or obj.vertex_groups.new(name="Hips")

cleaned = 0
for v in me.vertices:
    names = [(g.group, g.weight, gname.get(g.group, "")) for g in v.groups]
    has_leg = any(n.startswith(leg_prefixes) and w > 0.05 for _, w, n in names)
    has_arm = any(n.startswith(arm_prefixes) and w > 0.05 for _, w, n in names)
    if not (has_leg and has_arm):
        continue
    # Keep torso groups, drop leg+arm cross-chain groups.
    torso = [(gi, w) for gi, w, n in names
             if n.startswith(("Hips", "Spine")) and w > 0.05]
    for gi, w, n in names:
        if n.startswith(leg_prefixes) or n.startswith(arm_prefixes):
            obj.vertex_groups[gi].remove([v.index])
    if torso:
        total = sum(w for _, w in torso)
        for gi, w in torso:
            obj.vertex_groups[gi].add([v.index], w / total, "REPLACE")
    else:
        hips.add([v.index], 1.0, "REPLACE")
    cleaned += 1

print("CROSS_CHAIN_CLEANED", cleaned)

bpy.ops.object.select_all(action="DESELECT")
obj.select_set(True)
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

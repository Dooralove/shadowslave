"""Retarget UAL Sword_Attack onto the generated v3 52-bone skeleton.

This is an alpha combat clip, not production animation: it copies local bone
rotations by humanoid name from the UAL rig to the v3 rig and bakes them into
a standalone AnimationLibrary GLB.  Visual validation happens in Godot.

Run:
  blender -b --factory-startup --python build_v3_sword_attack.py
"""
from __future__ import annotations

import os

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
UAL = os.path.join(ROOT, "assets", "characters", "sunny_realistic_poc", "animations", "ual_standard.glb")
V3 = os.path.join(ROOT, "assets", "characters", "generated", "sunny_real_v3", "sunny_real_v3_clean2.glb")
OUT = os.path.join(ROOT, "assets", "characters", "equipment", "animations")

# UAL deform bone -> v3 Mixamo-style bone.
BONES = {
    "DEF-shoulder.L": "LeftShoulder",
    "DEF-upper_arm.L": "LeftArm",
    "DEF-forearm.L": "LeftForeArm",
    "DEF-hand.L": "LeftHand",
    "DEF-shoulder.R": "RightShoulder",
    "DEF-upper_arm.R": "RightArm",
    "DEF-forearm.R": "RightForeArm",
    "DEF-hand.R": "RightHand",
}
for side, prefix in (("L", "Left"), ("R", "Right")):
    for finger, v3name in (
        ("index", "Index"),
        ("middle", "Middle"),
        ("ring", "Ring"),
        ("pinky", "Pinky"),
    ):
        for seg in (1, 2, 3):
            BONES[f"DEF-f_{finger}.0{seg}.{side}"] = f"{prefix}Hand{v3name}{seg}"
    for seg, v3name in ((1, "Thumb1"), (2, "Thumb2"), (3, "Thumb3")):
        BONES[f"DEF-thumb.0{seg}.{side}"] = f"{prefix}Hand{v3name}"


def import_glb(path: str) -> bpy.types.Object:
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.context.scene.objects if o not in before and o.type == "ARMATURE"]
    if not new:
        raise RuntimeError("no new armature in " + path)
    return new[0]


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    source = import_glb(UAL)
    source.animation_data_create()
    action = bpy.data.actions.get("Sword_Attack")
    if action is None:
        raise RuntimeError("Sword_Attack action not found")
    source.animation_data.action = action

    target = import_glb(V3)
    target.animation_data_create()
    baked = bpy.data.actions.new("Sword_Attack")
    target.animation_data.action = baked
    for pose_bone in target.pose.bones:
        pose_bone.rotation_mode = "QUATERNION"

    scene = bpy.context.scene
    scene.render.fps = 24
    start = int(action.frame_range[0])
    end = int(action.frame_range[1])
    for frame in range(start, end + 1):
        scene.frame_set(frame)
        for source_name, target_name in BONES.items():
            # Keep the left arm out of the alpha clip: the source guard pose
            # otherwise crosses the face and reads as a block, not a swing.
            if "Left" in target_name:
                continue
            source_bone = source.pose.bones.get(source_name)
            target_bone = target.pose.bones.get(target_name)
            if source_bone is None or target_bone is None:
                continue
            target_bone.rotation_quaternion = source_bone.rotation_quaternion.copy()
            target_bone.keyframe_insert(data_path="rotation_quaternion", frame=frame)

    baked.use_fake_user = True
    baked.frame_range = (start, end)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "sunny_v3_sword_attack.glb")
    bpy.ops.object.select_all(action="DESELECT")
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_animation_mode="ACTIVE_ACTIONS",
        export_skins=True,
        export_apply=False,
        export_yup=True,
    )
    print("EXPORTED", path)


if __name__ == "__main__":
    main()

"""Author safe native clips for the four-arm Mountain King custom rig.

The previous pass applied human preset clips to a 60-bone ape with extra arms.
The death preset rotated the hips/arms far enough to shred the fur weights.
These clips use only small, explicit rotations on the base skeleton and the
extra arm chains, so the silhouette survives.

Run:
  blender -b --factory-startup --python assets/characters/generated/source/animate_mountain_king.py
"""
import bpy
import os
from mathutils import Euler, Vector

ROOT = r"C:\Users\user\Desktop\shadowslave"
SRC = os.path.join(ROOT, r"incoming_models\P0_characters\mountain_king_gen_image_rigged.glb")
OUT = os.path.join(ROOT, r"incoming_models\P0_characters\mountain_king_gen_image_anim_v2.glb")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
rig = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH" and o.name != "Icosphere")
print("BONES", len(rig.data.bones))


def key(action, frame, bone, rot=None, loc=None):
    pb = rig.pose.bones.get(bone)
    if pb is None:
        return
    pb.rotation_mode = "XYZ"
    if rot is not None:
        pb.rotation_euler = Euler(rot, "XYZ")
        pb.keyframe_insert("rotation_euler", frame=frame)
    if loc is not None:
        pb.location = Vector(loc)
        pb.keyframe_insert("location", frame=frame)


def new_action(name, end):
    if rig.animation_data is None:
        rig.animation_data_create()
    a = bpy.data.actions.new(name)
    a.use_fake_user = True
    a.frame_start = 1
    a.frame_end = end
    rig.animation_data.action = a
    return a


def build():
    a = new_action("Idle", 72)
    for f, t in ((1, 0.0), (24, 1.0), (48, -0.6), (72, 0.0)):
        key(a, f, "Hips", rot=(0.012 * t, 0, 0), loc=(0, 0, 0.008 * t))
        key(a, f, "Spine1", rot=(0.012 * t, 0, 0))
        key(a, f, "Neck", rot=(-0.010 * t, 0, 0))
        key(a, f, "Head", rot=(0.020 * t, 0.025 * t, 0))
        for side, sign in (("Left", 1), ("Right", -1)):
            key(a, f, side + "Arm", rot=(0.018 * t, 0, sign * 0.020 * t))
            key(a, f, side + "ForeArm", rot=(0.012 * t, 0, 0))
            key(a, f, side + "ExtraShoulder1", rot=(0.020 * t, 0, sign * 0.025 * t))
            key(a, f, side + "ExtraArm1", rot=(-0.018 * t, 0, sign * 0.020 * t))

    a = new_action("Walk", 48)
    for f, t in ((1, 0.0), (12, 1.0), (24, 0.0), (36, -1.0), (48, 0.0)):
        key(a, f, "Hips", rot=(0, 0.030 * t, 0), loc=(0.012 * t, 0, 0.008 * abs(t)))
        key(a, f, "Spine1", rot=(0, -0.020 * t, 0))
        key(a, f, "Head", rot=(0.012 * t, -0.025 * t, 0))
        for side, sign in (("Left", 1), ("Right", -1)):
            key(a, f, side + "UpLeg", rot=(0.22 * sign * t, 0, 0))
            key(a, f, side + "Leg", rot=(-0.14 * sign * t, 0, 0))
            key(a, f, side + "Foot", rot=(0.08 * sign * t, 0, 0))
            key(a, f, side + "Arm", rot=(-0.10 * sign * t, 0, sign * 0.02 * t))
            key(a, f, side + "ExtraShoulder1", rot=(0.08 * sign * t, 0, 0))
            key(a, f, side + "ExtraArm1", rot=(-0.10 * sign * t, 0, 0))

    a = new_action("Telegraph", 36)
    for f, t in ((1, 0.0), (18, 1.0), (36, 0.6)):
        key(a, f, "Hips", rot=(-0.08 * t, 0, 0), loc=(0, 0, 0.025 * t))
        key(a, f, "Spine1", rot=(0.08 * t, 0, 0))
        key(a, f, "Head", rot=(-0.06 * t, 0, 0))
        for side, sign in (("Left", 1), ("Right", -1)):
            key(a, f, side + "Shoulder", rot=(0.10 * t, 0, sign * 0.08 * t))
            key(a, f, side + "Arm", rot=(-0.20 * t, 0, 0))
            key(a, f, side + "ForeArm", rot=(0.12 * t, 0, 0))
            key(a, f, side + "ExtraShoulder1", rot=(0.16 * t, 0, sign * 0.10 * t))
            key(a, f, side + "ExtraArm1", rot=(-0.18 * t, 0, 0))

    a = new_action("Attack", 32)
    for f, t in ((1, 0.0), (10, 1.0), (18, -0.8), (32, 0.0)):
        key(a, f, "Hips", rot=(0.09 * t, 0, 0), loc=(0, 0.025 * t, 0))
        key(a, f, "Spine1", rot=(-0.07 * t, 0, 0))
        for side, sign in (("Left", 1), ("Right", -1)):
            key(a, f, side + "Arm", rot=(0.32 * t, 0, -sign * 0.08 * t))
            key(a, f, side + "ForeArm", rot=(0.18 * t, 0, 0))
            key(a, f, side + "ExtraArm1", rot=(0.28 * t, 0, 0))
            key(a, f, side + "ExtraForeArm1", rot=(0.14 * t, 0, 0))

    a = new_action("Hit", 24)
    for f, t in ((1, 0.0), (7, 1.0), (16, -0.5), (24, 0.0)):
        key(a, f, "Hips", rot=(-0.05 * t, 0.04 * t, 0), loc=(0, 0, -0.015 * t))
        key(a, f, "Spine1", rot=(0.06 * t, 0, 0))
        key(a, f, "Head", rot=(-0.08 * t, 0, 0.04 * t))

    a = new_action("Death", 72)
    for f, t in ((1, 0.0), (20, 0.5), (48, 1.0), (72, 1.0)):
        key(a, f, "Hips", rot=(0.22 * t, 0, 0.08 * t), loc=(0, 0, -0.04 * t))
        key(a, f, "Spine1", rot=(0.14 * t, 0, 0))
        key(a, f, "Spine2", rot=(0.10 * t, 0, 0))
        key(a, f, "Neck", rot=(0.10 * t, 0, 0))
        key(a, f, "Head", rot=(0.14 * t, 0.10 * t, 0))
        for side, sign in (("Left", 1), ("Right", -1)):
            key(a, f, side + "UpLeg", rot=(0.10 * t, 0, sign * 0.10 * t))
            key(a, f, side + "Leg", rot=(0.16 * t, 0, 0))
            key(a, f, side + "Arm", rot=(0.16 * t, 0, sign * 0.06 * t))
            key(a, f, side + "ExtraArm1", rot=(0.12 * t, 0, 0))

    rig.animation_data.action = bpy.data.actions.get("Idle")


build()
bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
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
print("WROTE", OUT, os.path.getsize(OUT), [a.name for a in bpy.data.actions])

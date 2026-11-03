"""Author five clips for the image-to-3D Carapace Centurion custom rig."""
import bpy
import os
import math
from mathutils import Euler, Vector

ROOT = r"C:\Users\user\Desktop\shadowslave"
SRC = os.path.join(ROOT, r"incoming_models\P1_monsters\carapace_centurion_gen_image_custom_rigged.glb")
OUT = os.path.join(ROOT, r"incoming_models\P1_monsters\carapace_centurion_gen_image_anim.glb")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
rig = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH" and o.name != "Icosphere")
print("BONES", len(rig.data.bones), [b.name for b in rig.data.bones])


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


def new_action(name):
    if rig.animation_data is None:
        rig.animation_data_create()
    a = bpy.data.actions.new(name)
    a.use_fake_user = True
    rig.animation_data.action = a
    return a


def build():
    a = new_action("Idle"); a.frame_start = 1; a.frame_end = 48
    for f, t in ((1, 0), (24, 1), (48, 0)):
        key(a, f, "Hips", loc=(0, 0, 0.015 * t))
        key(a, f, "Spine1", rot=(0.015 * t, 0, 0))
        key(a, f, "Head", rot=(0.02 * t, 0, 0))
        for side, sign in (("Left", 1), ("Right", -1)):
            key(a, f, side + "Arm", rot=(0.02 * t, 0, sign * 0.02 * t))
            key(a, f, side + "Scythe", rot=(0.02 * t, 0, 0))
    a = new_action("Walk"); a.frame_start = 1; a.frame_end = 32
    for f, t in ((1, 0), (8, 1), (16, 0), (24, -1), (32, 0)):
        key(a, f, "Hips", rot=(0, 0.04 * t, 0), loc=(0.015 * t, 0, 0.01 * abs(t)))
        for side, sign in (("Left", 1), ("Right", -1)):
            key(a, f, side + "UpLeg", rot=(0.18 * sign * t, 0, 0))
            key(a, f, side + "Leg", rot=(-0.12 * sign * t, 0, 0))
            key(a, f, side + "Foot", rot=(0.06 * sign * t, 0, 0))
            key(a, f, side + "Arm", rot=(-0.10 * sign * t, 0, 0))
            key(a, f, side + "Scythe", rot=(0.05 * sign * t, 0, 0))
    a = new_action("Telegraph"); a.frame_start = 1; a.frame_end = 24
    for f, t in ((1, 0), (12, 1), (24, 0.7)):
        key(a, f, "Hips", rot=(-0.10 * t, 0, 0), loc=(0, 0, 0.04 * t))
        key(a, f, "Spine1", rot=(0.10 * t, 0, 0))
        for side, sign in (("Left", 1), ("Right", -1)):
            key(a, f, side + "Shoulder", rot=(0.10 * t, 0, sign * 0.10 * t))
            key(a, f, side + "Arm", rot=(-0.28 * t, 0, 0))
            key(a, f, side + "Scythe", rot=(0.18 * t, 0, sign * 0.12 * t))
    a = new_action("Attack"); a.frame_start = 1; a.frame_end = 20
    for f, t in ((1, 0), (7, 1), (13, -0.8), (20, 0)):
        key(a, f, "Hips", rot=(0.12 * t, 0, 0), loc=(0, 0.04 * t, 0))
        key(a, f, "Spine1", rot=(-0.08 * t, 0, 0))
        for side, sign in (("Left", 1), ("Right", -1)):
            key(a, f, side + "Arm", rot=(0.36 * t, 0, -sign * 0.10 * t))
            key(a, f, side + "ForeArm", rot=(0.22 * t, 0, 0))
            key(a, f, side + "Scythe", rot=(-0.30 * t, 0, sign * 0.10 * t))
    a = new_action("Death"); a.frame_start = 1; a.frame_end = 36
    for f, t in ((1, 0), (12, 0.5), (24, 1.0), (36, 1.0)):
        key(a, f, "Hips", rot=(0.40 * t, 0.16 * t, 0.18 * t), loc=(0, 0, -0.12 * t))
        key(a, f, "Spine1", rot=(0.20 * t, 0, 0))
        for side, sign in (("Left", 1), ("Right", -1)):
            key(a, f, side + "UpLeg", rot=(0.08 * t, 0, sign * 0.20 * t))
            key(a, f, side + "Leg", rot=(0.22 * t, 0, sign * 0.10 * t))
            key(a, f, side + "Arm", rot=(0.18 * t, 0, sign * 0.12 * t))
    rig.animation_data.action = bpy.data.actions.get("Idle")


build()
bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(
    filepath=OUT, export_format="GLB", use_selection=True, export_apply=True,
    export_animations=True, export_animation_mode="ACTIONS",
    export_anim_single_armature=True, export_skins=True, export_yup=True,
)
print("WROTE", OUT, os.path.getsize(OUT), [a.name for a in bpy.data.actions])

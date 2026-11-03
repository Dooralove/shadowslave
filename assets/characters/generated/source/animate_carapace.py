"""Author five gameplay clips for the image-to-3D Carapace Scavenger.

The custom 38-bone rig has Shell/Spine/Neck/Head, two pincer chains and eight
leg chains (four pairs).  This script keeps the motion modest so the existing
weights are not pushed into extreme poses.
"""
import bpy
import os
import math
from mathutils import Euler, Vector

ROOT = r"C:\Users\user\Desktop\shadowslave"
SRC = os.path.join(ROOT, r"incoming_models\P1_monsters\carapace_scavenger_gen_image_rigged.glb")
OUT = os.path.join(ROOT, r"incoming_models\P1_monsters\carapace_scavenger_gen_image_anim.glb")

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


def leg_phase(pair, side, t):
    # Alternating tripod-like phases around the eight legs.
    idx = (pair - 1) * 2 + (0 if side == "Left" else 1)
    return math.sin((t + idx * 0.33) * math.tau)


def build():
    # Idle
    a = new_action("Idle"); a.frame_start = 1; a.frame_end = 48
    for f, t in ((1, 0), (24, 1), (48, 0)):
        key(a, f, "Shell", rot=(0.015 * t, 0, 0), loc=(0, 0, 0.012 * t))
        key(a, f, "Spine2", rot=(0.01 * t, 0, 0))
        for side in ("Left", "Right"):
            key(a, f, side + "Pincer", rot=(0, 0.10 * t if side == "Left" else -0.10 * t, 0))
        for pair in range(1, 5):
            for side in ("Left", "Right"):
                key(a, f, f"{side}Leg{pair}Hip", rot=(0.03 * t, 0, 0))
    # Walk
    a = new_action("Walk"); a.frame_start = 1; a.frame_end = 32
    for f, t in ((1, 0), (8, 1), (16, 0), (24, -1), (32, 0)):
        key(a, f, "Shell", rot=(0, 0.04 * t, 0), loc=(0.015 * t, 0, 0.015 * abs(t)))
        for pair in range(1, 5):
            for side, sign in (("Left", 1), ("Right", -1)):
                p = leg_phase(pair, side, (f - 1) / 8.0)
                hip = f"{side}Leg{pair}Hip"; knee = f"{side}Leg{pair}Knee"; foot = f"{side}Leg{pair}Foot"
                key(a, f, hip, rot=(0.18 * sign * p, 0, 0.04 * sign))
                key(a, f, knee, rot=(-0.12 * sign * p, 0, 0))
                key(a, f, foot, rot=(0.08 * sign * p, 0, 0))
        for side in ("Left", "Right"):
            key(a, f, side + "Pincer", rot=(0, 0.06 * t if side == "Left" else -0.06 * t, 0))
    # Telegraph
    a = new_action("Telegraph"); a.frame_start = 1; a.frame_end = 24
    for f, t in ((1, 0), (12, 1), (24, 0.7)):
        key(a, f, "Shell", rot=(-0.14 * t, 0, 0), loc=(0, 0, 0.05 * t))
        key(a, f, "Spine1", rot=(0.10 * t, 0, 0))
        for side, sign in (("Left", 1), ("Right", -1)):
            key(a, f, side + "Shoulder", rot=(0.12 * t, 0, sign * 0.12 * t))
            key(a, f, side + "Arm", rot=(-0.10 * t, 0, 0))
            key(a, f, side + "Pincer", rot=(0, sign * 0.30 * t, 0))
    # Attack
    a = new_action("Attack"); a.frame_start = 1; a.frame_end = 20
    for f, t in ((1, 0), (7, 1), (13, -0.8), (20, 0)):
        key(a, f, "Shell", rot=(0.14 * t, 0, 0), loc=(0, 0.06 * t, 0))
        key(a, f, "Spine1", rot=(-0.08 * t, 0, 0))
        for side, sign in (("Left", 1), ("Right", -1)):
            key(a, f, side + "Shoulder", rot=(-0.40 * t, 0, -sign * 0.10 * t))
            key(a, f, side + "Arm", rot=(0.50 * t, 0, 0))
            key(a, f, side + "Pincer", rot=(0, -sign * 0.25 * t, 0))
    # Death
    a = new_action("Death"); a.frame_start = 1; a.frame_end = 36
    for f, t in ((1, 0), (12, 0.5), (24, 1.0), (36, 1.0)):
        key(a, f, "Shell", rot=(0.42 * t, 0.18 * t, 0.20 * t), loc=(0, 0, -0.12 * t))
        key(a, f, "Spine1", rot=(0.20 * t, 0, 0))
        for pair in range(1, 5):
            for side, sign in (("Left", 1), ("Right", -1)):
                key(a, f, f"{side}Leg{pair}Hip", rot=(0.10 * t, 0, sign * 0.25 * t))
                key(a, f, f"{side}Leg{pair}Knee", rot=(0.20 * t, 0, sign * 0.15 * t))
        for side, sign in (("Left", 1), ("Right", -1)):
            key(a, f, side + "Pincer", rot=(0.18 * t, 0, sign * 0.10 * t))
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
print("WROTE", OUT, os.path.getsize(OUT), "ACTIONS", [a.name for a in bpy.data.actions])

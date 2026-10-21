"""Спокойная поза покоя «уставший худой подросток» на скелете Quaternius UAL (Blender 5.1, без доп. аддонов).

UAL Standard не содержит спокойного Idle: `Idle_Loop` — боевая стойка (ноги шире плеч, кулаки).
Скрипт берёт скелет из `animations/ual_standard.glb`, строит позу от T-позы покоя направлениями костей
и экспортирует отдельный клип `Idle_Relaxed_Loop` в `animations/sunny_idle_relaxed.glb`.
Исходный `ual_standard.glb` не изменяется.

Запуск: blender -b --factory-startup --python build_idle_relaxed.py -- <ual_standard.glb> <выход.glb> [превью.png]
"""
import math
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

## Отладка конвейера: экспортировать рядом нетронутый UAL Idle_Loop, чтобы сверить импорт с оригиналом.
CALIBRATION = "--calibrate" in sys.argv
FPS = 24
LOOP_FRAMES = 72  # 3 с — один спокойный вдох-выдох

# Персонаж смотрит вдоль −Y, вверх +Z, его левая сторона — +X.
## Сутулость: лёгкое скругление верха спины; шея чуть назад, взгляд вниз даёт наклон головы, а не шеи.
## Замер на модели Санни в Godot: голова на ~2 см дальше вперёд, чем в T-позе UAL (см. docs/DECISIONS.md, S2.1).
SPINE_BEND_DEG = {"DEF-spine.001": 1.0, "DEF-spine.002": 1.5, "DEF-spine.003": 2.5, "DEF-neck": -4.0, "DEF-head": 7.0}
SHOULDER_FORWARD_DEG = 8.0
SHOULDER_DROP_DEG = 5.0
ARM_DIRECTIONS = {
    # Плечо почти вертикально и чуть от корпуса, предплечье с мягким сгибом вперёд.
    "DEF-upper_arm": Vector((0.11, -0.05, -1.0)),
    "DEF-forearm": Vector((0.07, -0.20, -1.0)),
    "DEF-hand": Vector((0.03, -0.10, -1.0)),
}
FINGER_CURL_DEG = {"01": 14.0, "02": 24.0, "03": 18.0}
THUMB_CURL_DEG = 8.0
KNEE_BEND_DEG = 3.0
BREATH_CHEST_DEG = 1.2
BREATH_SHOULDER_DEG = 1.0


def rotate_about_head(arm, pb, axis, angle_deg):
    """Поворот кости вокруг её головы в пространстве арматуры (дети следуют)."""
    rot = Matrix.Rotation(math.radians(angle_deg), 4, Vector(axis).normalized())
    head = pb.matrix.to_translation()
    pb.matrix = Matrix.Translation(head) @ rot @ Matrix.Translation(-head) @ pb.matrix
    bpy.context.view_layer.update()


def aim(pb, direction):
    current = pb.matrix.col[1].xyz.normalized()
    q = current.rotation_difference(direction.normalized())
    head = pb.matrix.to_translation()
    pb.matrix = Matrix.Translation(head) @ q.to_matrix().to_4x4() @ Matrix.Translation(-head) @ pb.matrix
    bpy.context.view_layer.update()


def curl(arm, pb, angle_deg):
    """Сгиб пальца к ладони: знак выбирается так, чтобы кончик шёл к ладони (в T-позе ладонь смотрит в −Z)."""
    z_local = arm.data.bones[pb.name].matrix_local.to_3x3().col[2]
    sign = 1.0 if z_local.z < 0 else -1.0
    pb.rotation_quaternion = Quaternion((1, 0, 0), math.radians(angle_deg * sign)) @ pb.rotation_quaternion


def build_pose(arm, breath=0.0):
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()
    pose = arm.pose.bones

    for name, deg in SPINE_BEND_DEG.items():
        extra = -BREATH_CHEST_DEG * breath if name == "DEF-spine.003" else 0.0
        rotate_about_head(arm, pose[name], (1, 0, 0), deg + extra)

    for side, sx in (("L", 1.0), ("R", -1.0)):
        shoulder = pose[f"DEF-shoulder.{side}"]
        rotate_about_head(arm, shoulder, (0, 0, 1), -SHOULDER_FORWARD_DEG * sx)
        rotate_about_head(arm, shoulder, (0, 1, 0), (SHOULDER_DROP_DEG - BREATH_SHOULDER_DEG * breath) * sx)
        for bone, direction in ARM_DIRECTIONS.items():
            aim(pose[f"{bone}.{side}"], Vector((direction.x * sx, direction.y, direction.z)))
        for finger in ("f_index", "f_middle", "f_ring", "f_pinky"):
            for seg, deg in FINGER_CURL_DEG.items():
                curl(arm, pose[f"DEF-{finger}.{seg}.{side}"], deg)
        for seg in ("01", "02", "03"):
            curl(arm, pose[f"DEF-thumb.{seg}.{side}"], THUMB_CURL_DEG)
        # Колени чуть мягче прямых; стопа возвращается в исходное направление и стоит ровно.
        rotate_about_head(arm, pose[f"DEF-thigh.{side}"], (1, 0, 0), -KNEE_BEND_DEG * 0.5)
        rotate_about_head(arm, pose[f"DEF-shin.{side}"], (1, 0, 0), KNEE_BEND_DEG)
        aim(pose[f"DEF-foot.{side}"], arm.data.bones[f"DEF-foot.{side}"].matrix_local.col[1].xyz)
    bpy.context.view_layer.update()


def key_all(arm, frame):
    for pb in arm.pose.bones:
        pb.keyframe_insert("location", frame=frame)
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        pb.keyframe_insert("scale", frame=frame)


def main(src, out, preview=None):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    if arm.animation_data:
        arm.animation_data.action = None
    for action in list(bpy.data.actions):
        if CALIBRATION and action.name == "Idle_Loop":
            action.name = "Calib_UAL_Idle"
            action.use_fake_user = True
            continue
        bpy.data.actions.remove(action)
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.frame_start, scene.frame_end = 0, LOOP_FRAMES

    for frame, breath in ((0, 0.0), (LOOP_FRAMES // 2, 1.0), (LOOP_FRAMES, 0.0)):
        build_pose(arm, breath)
        key_all(arm, frame)
    action = arm.animation_data.action
    action.name = "Idle_Relaxed_Loop"
    print("ACTION", action.name, action.frame_range[:])

    if preview:
        scene.frame_set(0)
        render_preview(preview)

    bpy.ops.export_scene.gltf(
        filepath=out, export_format="GLB", export_animations=True, export_animation_mode="ACTIONS",
        export_skins=True, export_morph=False, export_yup=True,
    )
    print("EXPORTED", out)


def render_preview(path):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 900, 700
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.2, 0.21, 0.23, 1)
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (0.9, 0.0, 0.5)
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 50
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.frame_set(0)
    for suffix, location in (("", (0.0, -5.2, 1.0)), ("_side", (5.2, 0.0, 1.0))):
        cam.location = Vector(location)
        cam.rotation_euler = (Vector((0, 0, 0.9)) - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = path.replace(".png", suffix + ".png")
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    args = [a for a in sys.argv[sys.argv.index("--") + 1:] if not a.startswith("--")]
    main(args[0], args[1], args[2] if len(args) > 2 else None)

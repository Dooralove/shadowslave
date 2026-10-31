"""Конвертация лошади из CC0-набора Quaternius «Farm Animals» (FBX) в GLB с чистыми именами клипов.

Запуск:
    blender -b --python convert_horse.py -- <Horse.fbx> <horse.glb>
Исходник: https://opengameart.org/content/lowpoly-animated-farm-animal-pack
"""
import sys

import bpy

src, out = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)
# «Armature|Armature|Walk» -> «Walk».
for action in bpy.data.actions:
    action.name = action.name.split("|")[-1]
    action.use_fake_user = True
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animations=True,
                          export_animation_mode="ACTIONS", export_skins=True, export_yup=True)
print("ACTIONS", [a.name for a in bpy.data.actions])

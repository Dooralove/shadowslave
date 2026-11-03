"""Create LOD1/LOD2 for the corpse-larva and export one GLB."""

import bpy
import os
from mathutils import Vector

ROOT = r"C:\Users\user\Desktop\shadowslave"
SRC = os.path.join(ROOT, r"assets\characters\enemies\larva\larva_corpse.glb")
OUT = os.path.join(ROOT, r"assets\characters\enemies\larva\larva_corpse_lod.glb")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
scene = bpy.context.scene
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
mesh = next(o for o in scene.objects if o.type == 'MESH' and o.name != 'Icosphere')
mesh.name = "LarvaBody"
mesh.data.name = "LarvaBody"


def make_lod(source, name, ratio):
    dup = source.copy()
    dup.data = source.data.copy()
    dup.name = name
    dup.data.name = name
    bpy.context.collection.objects.link(dup)
    mod = dup.modifiers.new("LOD_Decimate", "DECIMATE")
    mod.ratio = ratio
    mod.use_collapse_triangulate = True
    bpy.ops.object.select_all(action='DESELECT')
    dup.select_set(True)
    bpy.context.view_layer.objects.active = dup
    bpy.ops.object.modifier_move_to_index(modifier=mod.name, index=0)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return dup


lod1 = make_lod(mesh, "LarvaBody_LOD1", 0.50)
lod2 = make_lod(mesh, "LarvaBody_LOD2", 0.22)

# Hide the importer helper and export only the armature + three LOD meshes.
for o in scene.objects:
    if o.name == "Icosphere":
        bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.object.select_all(action='DESELECT')
for o in (mesh, lod1, lod2, rig):
    o.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(
    filepath=OUT,
    export_format='GLB',
    use_selection=True,
    export_apply=True,
    export_animations=True,
    export_animation_mode='ACTIONS',
    export_anim_single_armature=True,
    export_skins=True,
    export_yup=True,
)

tris = []
for o in (mesh, lod1, lod2):
    o.data.calc_loop_triangles()
    tris.append(len(o.data.loop_triangles))
print("LARVA_LOD_DONE", "tris", tris, "bones", len(rig.data.bones),
      "actions", [a.name for a in bpy.data.actions], "out", OUT, "size", os.path.getsize(OUT))

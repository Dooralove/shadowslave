import bpy, os
from pathlib import Path
ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / "assets" / "environments" / "nightmare" / "statue"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUT / "statue_knight_colossus.glb"))
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
if not meshes:
    raise RuntimeError("no mesh")
# Join if exported as multiple parts.
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
obj.name = "statue_lod_source"
print("SRC", len(obj.data.vertices), len(obj.data.polygons), obj.dimensions[:])
mat = bpy.data.materials.get("lod_stone")
if not mat:
    mat = bpy.data.materials.new("lod_stone")
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (0.24, 0.22, 0.18, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.9
    bsdf.inputs["Metallic"].default_value = 0.0
for ratio, name in ((0.35, "lod1"), (0.10, "lod2")):
    dup = obj.copy()
    dup.data = obj.data.copy()
    bpy.context.collection.objects.link(dup)
    bpy.ops.object.select_all(action='DESELECT')
    dup.select_set(True)
    bpy.context.view_layer.objects.active = dup
    mod = dup.modifiers.new("dec", "DECIMATE")
    mod.ratio = ratio
    bpy.ops.object.modifier_apply(modifier=mod.name)
    dup.data.materials.clear()
    dup.data.materials.append(mat)
    dup.name = "statue_knight_colossus_" + name
    bpy.ops.export_scene.gltf(filepath=str(OUT / (dup.name + ".glb")), export_format="GLB",
                              use_selection=True, export_apply=True, export_yup=True,
                              export_image_format="AUTO")
    print("LOD", name, len(dup.data.polygons), "tris", sum(len(p.vertices)-2 for p in dup.data.polygons))
    bpy.data.objects.remove(dup, do_unlink=True)
print("DONE")

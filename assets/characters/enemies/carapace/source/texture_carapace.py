"""Optimize and texture the Carapace Scavenger.

- Recalculate outward normals.
- Unwrap LOD0 meshes and rebuild LOD1/LOD2 from the textured LOD0.
- Add shared PBR maps (base color per material, normal + ORM).
- Switch opaque materials to single-sided and export tangents.

Run with background Blender:
  blender -b --factory-startup --python assets/characters/enemies/carapace/source/texture_carapace.py
"""
import bpy
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "..", ".."))
MODEL = os.path.join(ROOT, "assets", "characters", "enemies", "carapace", "carapace_scavenger.glb")
OUT = os.path.join(ROOT, "assets", "characters", "enemies", "carapace", "carapace_scavenger_v2.glb")
TEX = os.path.join(ROOT, "assets", "characters", "enemies", "carapace", "textures")

BASE_MAPS = {
    "Carapace_Chitin": "carapace_base_chitin.png",
    "Carapace_Plate": "carapace_base_plate.png",
    "Carapace_Bone": "carapace_base_bone.png",
    "Carapace_Dark": "carapace_base_dark.png",
    "Carapace_Maw": "carapace_base_maw.png",
}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=MODEL)
scene = bpy.context.scene
rig = next(o for o in scene.objects if o.type == "ARMATURE")

# Drop old LOD copies and the importer's custom bone-shape helper; they will be
# rebuilt from the improved LOD0. The Icosphere is not part of the creature.
for o in list(scene.objects):
    if o.type == "MESH" and ("_LOD1" in o.name or "_LOD2" in o.name or o.name == "Icosphere"):
        bpy.data.objects.remove(o, do_unlink=True)

lod0 = [o for o in scene.objects if o.type == "MESH" and "_LOD" not in o.name and o.name != "Icosphere"]
print("LOD0", [o.name for o in lod0])


def recalc_normals(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def unwrap(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.1519, island_margin=0.015, area_weight=0.0,
                             correct_aspect=True, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def image_node(nodes, path, color_space):
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(path, check_existing=True)
    tex.image.colorspace_settings.name = color_space
    tex.interpolation = "Linear"
    tex.extension = "REPEAT"
    return tex


def setup_material(mat):
    if mat is None or not mat.use_nodes:
        return
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    for n in list(nodes):
        if n.type in {"TEX_IMAGE", "NORMAL_MAP", "SEPARATE_COLOR"}:
            nodes.remove(n)
    bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        return
    # Clear old links into the channels we replace.
    for name in ("Base Color", "Normal", "Roughness", "Metallic"):
        for link in list(bsdf.inputs[name].links):
            links.remove(link)

    base_name = BASE_MAPS.get(mat.name)
    if base_name:
        base = image_node(nodes, os.path.join(TEX, base_name), "sRGB")
        links.new(base.outputs["Color"], bsdf.inputs["Base Color"])
    normal = image_node(nodes, os.path.join(TEX, "carapace_normal.png"), "Non-Color")
    nm = nodes.new("ShaderNodeNormalMap")
    nm.inputs["Strength"].default_value = 0.75
    links.new(normal.outputs["Color"], nm.inputs["Color"])
    links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    orm = image_node(nodes, os.path.join(TEX, "carapace_orm.png"), "Non-Color")
    sep = nodes.new("ShaderNodeSeparateColor")
    links.new(orm.outputs["Color"], sep.inputs["Color"])
    links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    # Keep the material name and make opaque closed surfaces single-sided.
    mat.use_backface_culling = True
    mat.blend_method = "OPAQUE"
    print("MAT", mat.name, "base", base_name, "single_sided", mat.use_backface_culling)


for obj in lod0:
    recalc_normals(obj)
    unwrap(obj)

for mat in bpy.data.materials:
    setup_material(mat)

# Rebuild LODs from the improved, textured LOD0.
def make_lod(source, name, ratio):
    dup = source.copy()
    dup.data = source.data.copy()
    dup.name = name
    dup.data.name = name
    bpy.context.collection.objects.link(dup)
    mod = dup.modifiers.new("LOD_Decimate", "DECIMATE")
    mod.ratio = ratio
    mod.use_collapse_triangulate = True
    bpy.ops.object.select_all(action="DESELECT")
    dup.select_set(True)
    bpy.context.view_layer.objects.active = dup
    bpy.ops.object.modifier_move_to_index(modifier=mod.name, index=0)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return dup

lod1 = [make_lod(o, o.name + "_LOD1", 0.46) for o in lod0]
lod2 = [make_lod(o, o.name + "_LOD2", 0.18) for o in lod0]
all_meshes = lod0 + lod1 + lod2

bpy.ops.object.select_all(action="DESELECT")
for o in all_meshes:
    o.select_set(True)
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
    export_tangents=True,
    export_yup=True,
    export_image_format="AUTO",
)

tris = {}
for o in all_meshes:
    o.data.calc_loop_triangles()
    tris[o.name] = len(o.data.loop_triangles)
print("CARAPACE_V2_DONE", "out", OUT, "size", os.path.getsize(OUT), "tris", tris,
      "materials", [m.name for m in bpy.data.materials],
      "images", [(i.name, i.size[:]) for i in bpy.data.images if i.size[0] > 0])

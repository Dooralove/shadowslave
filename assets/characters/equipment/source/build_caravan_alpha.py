"""Build the alpha full-body armour overlay for Sunny Nightmare v2.

The generated Nightmare body is not a naked base mesh: the exposed-skin
surface is only the head/neck area, while the tunic/trousers/shoes surfaces
also carry the limbs.  For the alpha we therefore duplicate those three
surfaces, inflate them slightly and recolour them as a full armour shell.
The original clothing is hidden while the shell is equipped; the shell has
the same skin weights, so it deforms with the body.

Run:
  blender -b --factory-startup --python build_caravan_alpha.py -- --preview
"""
from __future__ import annotations

import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
SOURCE = os.path.join(ROOT, "assets", "characters", "generated", "sunny_nightmare_v2", "sunny_nightmare_v2.glb")
OUT = os.path.join(ROOT, "assets", "characters", "equipment", "armor")
PREVIEW = os.path.join(os.environ.get("TEMP", ROOT), "equipment_alpha")
TEXTURES = os.path.join(ROOT, "assets", "environments", "nightmare", "materials", "textures")
LEATHER_DIFF = os.path.join(TEXTURES, "brown_leather_diff_1k.jpg")
LEATHER_NORMAL = os.path.join(TEXTURES, "brown_leather_nor_gl_1k.jpg")
METAL_DIFF = os.path.join(TEXTURES, "rust_coarse_01_diff_1k.jpg")
METAL_NORMAL = os.path.join(TEXTURES, "rust_coarse_01_nor_gl_1k.jpg")

PALETTES = {
    "caravan_alpha": {
        "leather": (0.16, 0.085, 0.045, 1.0),
        "leather_dark": (0.075, 0.045, 0.028, 1.0),
        "metal": (0.22, 0.20, 0.17, 1.0),
        "metal_metallic": 0.55,
        "metal_roughness": 0.52,
    },
    "coral_alpha": {
        "leather": (0.20, 0.055, 0.06, 1.0),
        "leather_dark": (0.10, 0.035, 0.045, 1.0),
        "metal": (0.42, 0.36, 0.28, 1.0),
        "metal_metallic": 0.35,
        "metal_roughness": 0.55,
    },
}


def clear_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_source() -> tuple[bpy.types.Object, bpy.types.Object]:
    bpy.ops.import_scene.gltf(filepath=SOURCE)
    armature = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    mesh = bpy.data.objects.get("model")
    for obj in list(bpy.context.scene.objects):
        if obj not in (armature, mesh):
            bpy.data.objects.remove(obj, do_unlink=True)
    return armature, mesh


def separate_by_material(mesh: bpy.types.Object) -> dict[str, bpy.types.Object]:
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.separate(type="MATERIAL")
    bpy.ops.object.mode_set(mode="OBJECT")
    parts: dict[str, bpy.types.Object] = {}
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH":
            continue
        material_name = obj.data.materials[0].name if obj.data.materials else ""
        parts[material_name] = obj
    return parts


def make_material(name: str, color: tuple[float, float, float, float], metallic: float, roughness: float,
                  diffuse_path: str | None = None, normal_path: str | None = None) -> bpy.types.Material:
    mat = bpy.data.materials.get(name)
    if mat is not None:
        bpy.data.materials.remove(mat)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = color
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if diffuse_path and os.path.exists(diffuse_path):
        image = bpy.data.images.load(diffuse_path, check_existing=True)
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = image
        tex.location = (-520, 180)
        mix = nodes.new("ShaderNodeMixRGB")
        mix.blend_type = "MULTIPLY"
        mix.inputs["Fac"].default_value = 1.0
        mix.inputs["Color1"].default_value = color
        mix.location = (-220, 160)
        links.new(tex.outputs["Color"], mix.inputs["Color2"])
        links.new(mix.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = color
    if normal_path and os.path.exists(normal_path):
        image = bpy.data.images.load(normal_path, check_existing=True)
        image.colorspace_settings.name = "Non-Color"
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = image
        tex.location = (-520, -160)
        normal = nodes.new("ShaderNodeNormalMap")
        normal.location = (-220, -160)
        links.new(tex.outputs["Color"], normal.inputs["Color"])
        links.new(normal.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def apply_modifier(obj: bpy.types.Object, modifier: bpy.types.Modifier) -> None:
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def duplicate_inflated(source: bpy.types.Object, name: str, material: bpy.types.Material, strength: float) -> bpy.types.Object:
    obj = source.copy()
    obj.data = source.data.copy()
    obj.name = name
    obj.data.name = name
    bpy.context.collection.objects.link(obj)
    obj.data.materials.clear()
    obj.data.materials.append(material)
    mod = obj.modifiers.new("inflate", "DISPLACE")
    mod.direction = "NORMAL"
    mod.mid_level = 0.0
    mod.strength = strength
    # Apply the shell inflation before the Armature modifier so the rest-pose
    # geometry is displaced rather than the posed result.
    obj.modifiers.move(len(obj.modifiers) - 1, 0)
    apply_modifier(obj, mod)
    return obj


def bind_rigid(obj: bpy.types.Object, armature: bpy.types.Object, bone_name: str) -> None:
    group = obj.vertex_groups.new(name=bone_name)
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = armature
    obj.parent = armature
    obj.matrix_parent_inverse = armature.matrix_world.inverted()


def bevel(obj: bpy.types.Object, width: float, segments: int = 2) -> None:
    mod = obj.modifiers.new("bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    apply_modifier(obj, mod)


def add_box(name: str, center: Vector, size: Vector, material: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.data.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.materials.append(material)
    return obj


def add_uv_sphere(name: str, center: Vector, scale: Vector, material: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=1.0, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.data.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.materials.append(material)
    return obj


def add_cylinder_between(name: str, a: Vector, b: Vector, radius: float, material: bpy.types.Material) -> bpy.types.Object:
    vec = b - a
    length = vec.length
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=radius, depth=length, location=(a + b) * 0.5)
    obj = bpy.context.object
    obj.name = name
    obj.data.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = vec.to_track_quat("Z", "Y")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.materials.append(material)
    return obj


def add_torus(name: str, center: Vector, major: float, minor: float, material: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major,
        minor_radius=minor,
        major_segments=24,
        minor_segments=8,
        location=center,
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.name = name
    obj.data.materials.append(material)
    return obj


def bone(armature: bpy.types.Object, name: str) -> bpy.types.Bone:
    return armature.data.bones[name]


def build_variant(variant: str, palette: dict) -> bpy.types.Object:
    clear_scene()
    armature, source_mesh = import_source()
    parts = separate_by_material(source_mesh)

    leather = make_material("eq_leather", palette["leather"], 0.0, 0.82,
                            LEATHER_DIFF, LEATHER_NORMAL)
    leather_dark = make_material("eq_leather_dark", palette["leather_dark"], 0.0, 0.88,
                                 LEATHER_DIFF, LEATHER_NORMAL)
    metal = make_material("eq_metal", palette["metal"], palette["metal_metallic"], palette["metal_roughness"],
                          METAL_DIFF, METAL_NORMAL)

    tunic = parts["NightmareTunic"]
    trousers = parts["NightmareTrousers"]
    shoes = parts["NightmareShoes"]

    shell_tunic = duplicate_inflated(tunic, "ArmorShell_Tunic", leather, 0.018)
    shell_trousers = duplicate_inflated(trousers, "ArmorShell_Trousers", leather_dark, 0.014)
    shell_shoes = duplicate_inflated(shoes, "ArmorShell_Shoes", leather_dark, 0.010)

    pieces: list[bpy.types.Object] = [shell_tunic, shell_trousers, shell_shoes]

    # Chest plate: a broad, slightly convex shell rather than a flat slab.
    chest_plate = add_uv_sphere("ChestPlate", Vector((0.0, -0.150, 0.37)),
                                Vector((0.185, 0.050, 0.160)), leather_dark)
    bind_rigid(chest_plate, armature, "Spine2")
    pieces.append(chest_plate)
    chest_boss = add_uv_sphere("ChestBoss", Vector((0.0, -0.193, 0.37)),
                               Vector((0.055, 0.020, 0.055)), metal)
    bind_rigid(chest_boss, armature, "Spine2")
    pieces.append(chest_boss)
    chest_band = add_box("ChestBand", Vector((0.0, -0.195, 0.295)), Vector((0.30, 0.030, 0.035)), metal)
    bevel(chest_band, 0.008, 2)
    bind_rigid(chest_band, armature, "Spine2")
    pieces.append(chest_band)

    # Back plate, same idea but thinner.
    back_plate = add_uv_sphere("BackPlate", Vector((0.0, 0.145, 0.38)),
                               Vector((0.195, 0.042, 0.165)), leather_dark)
    bind_rigid(back_plate, armature, "Spine2")
    pieces.append(back_plate)

    # Collar hides the shell/neck seam.
    collar = add_torus("Collar", Vector((0.0, 0.035, 0.515)), 0.105, 0.024, leather_dark)
    bind_rigid(collar, armature, "Spine2")
    pieces.append(collar)

    # Shoulder plates. Push them slightly past the shell so the silhouette reads.
    for side, bone_name in (("L", "LeftShoulder"), ("R", "RightShoulder")):
        shoulder = armature.data.bones[bone_name]
        center = shoulder.head_local.lerp(shoulder.tail_local, 0.72)
        outward = 1.0 if center.x >= 0.0 else -1.0
        center += Vector((outward * 0.025, -0.005, -0.005))
        pauldron = add_uv_sphere("Pauldron_" + side, center, Vector((0.145, 0.110, 0.085)), leather)
        bind_rigid(pauldron, armature, bone_name)
        pieces.append(pauldron)
        rim = add_uv_sphere("PauldronRim_" + side, center + Vector((outward * 0.015, -0.020, -0.045)),
                            Vector((0.115, 0.095, 0.042)), metal)
        bind_rigid(rim, armature, bone_name)
        pieces.append(rim)

    # Bracers.
    for side, fore_bone, hand_bone in (
        ("L", "LeftForeArm", "LeftHand"),
        ("R", "RightForeArm", "RightHand"),
    ):
        a = armature.data.bones[fore_bone].head_local
        b = armature.data.bones[fore_bone].tail_local
        mid = a.lerp(b, 0.65)
        vec = (b - a).normalized()
        brace = add_cylinder_between("Bracer_" + side, mid - vec * 0.07, mid + vec * 0.12, 0.058, metal)
        bind_rigid(brace, armature, fore_bone)
        pieces.append(brace)

    # Belt and tassets.
    hips_z = armature.data.bones["Hips"].head_local.z
    belt = add_torus("Belt", Vector((0.0, 0.0, hips_z + 0.02)), 0.155, 0.026, leather_dark)
    bind_rigid(belt, armature, "Hips")
    pieces.append(belt)
    for side, x in (("L", 0.10), ("R", -0.10)):
        tasset = add_box("Tasset_" + side, Vector((x, -0.14, hips_z - 0.09)), Vector((0.13, 0.05, 0.17)), leather)
        bevel(tasset, 0.012, 2)
        bind_rigid(tasset, armature, "Hips")
        pieces.append(tasset)

    # Knee/shin guards: simple plates over the lower legs.
    for side, leg_bone, foot_bone in (
        ("L", "LeftLeg", "LeftFoot"),
        ("R", "RightLeg", "RightFoot"),
    ):
        a = armature.data.bones[leg_bone].head_local
        b = armature.data.bones[leg_bone].tail_local
        mid = a.lerp(b, 0.55)
        vec = (b - a).normalized()
        guard = add_cylinder_between("ShinGuard_" + side, mid - vec * 0.10, mid + vec * 0.12, 0.072, metal)
        bind_rigid(guard, armature, leg_bone)
        pieces.append(guard)

    # Join the shell and the rigid plates into one skinned mesh.
    bpy.ops.object.select_all(action="DESELECT")
    for obj in pieces:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = shell_tunic
    bpy.ops.object.join()
    armor = bpy.context.object
    armor.name = "Armor_" + variant
    armor.data.name = armor.name
    if not any(mod.type == "ARMATURE" for mod in armor.modifiers):
        mod = armor.modifiers.new("Armature", "ARMATURE")
        mod.object = armature

    # The original body/clothing stays as the base.  The armour shell replaces
    # the three clothing surfaces while equipped.
    for obj in (tunic, trousers, shoes):
        obj.hide_render = True
        obj.hide_viewport = True

    return armor


def make_lod(armor: bpy.types.Object, suffix: str, ratio: float) -> bpy.types.Object:
    lod = armor.copy()
    lod.data = armor.data.copy()
    lod.name = armor.name + suffix
    lod.data.name = lod.name
    bpy.context.collection.objects.link(lod)
    mod = lod.modifiers.new("decimate", "DECIMATE")
    mod.ratio = ratio
    lod.modifiers.move(len(lod.modifiers) - 1, 0)
    apply_modifier(lod, mod)
    return lod


def export_variant(variant: str, armor: bpy.types.Object) -> str:
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, variant + ".glb")
    armature = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    lods = [
        make_lod(armor, "_LOD1", 0.50),
        make_lod(armor, "_LOD2", 0.25),
    ]
    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    armor.select_set(True)
    for lod in lods:
        lod.select_set(True)
    bpy.context.view_layer.objects.active = armor
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_animations=False,
        export_skins=True,
        export_apply=False,
        export_yup=True,
    )
    print("EXPORTED", path)
    return path


def render_preview(variant: str) -> None:
    os.makedirs(PREVIEW, exist_ok=True)
    for obj in bpy.context.scene.objects:
        if "_LOD1" in obj.name or "_LOD2" in obj.name:
            obj.hide_render = True
            obj.hide_viewport = True
    scene = bpy.context.scene
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("PreviewWorld") if scene.world is None else scene.world
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.018, 0.022, 0.028, 1.0)
        bg.inputs[1].default_value = 0.6

    bpy.ops.object.camera_add(location=(1.35, -4.2, 1.15))
    cam = bpy.context.object
    cam.data.lens = 55
    cam.rotation_euler = (math.radians(83), 0.0, math.radians(18))
    scene.camera = cam

    bpy.ops.object.light_add(type="AREA", location=(2.5, -3.0, 3.0))
    key = bpy.context.object
    key.data.energy = 450
    key.data.size = 3.0
    key.rotation_euler = (math.radians(45), 0.0, math.radians(35))

    bpy.ops.object.light_add(type="AREA", location=(-3.0, -1.0, 1.8))
    fill = bpy.context.object
    fill.data.energy = 180
    fill.data.size = 3.0
    fill.rotation_euler = (math.radians(70), 0.0, math.radians(-50))

    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        scene.render.engine = "BLENDER_WORKBENCH"

    path = os.path.join(PREVIEW, variant + "_preview.png")
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("PREVIEW", path)


def main() -> None:
    preview = "--preview" in sys.argv
    for variant, palette in PALETTES.items():
        armor = build_variant(variant, palette)
        export_variant(variant, armor)
        if preview:
            render_preview(variant)


if __name__ == "__main__":
    main()

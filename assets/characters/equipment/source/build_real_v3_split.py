"""Split generated Sunny real v3 into exposed-skin base and armour shell.

The generated GLB has no semantic body/clothing materials: it is one mesh with
one material and many disconnected islands.  This script classifies islands by
average diffuse colour and bounds, keeps skin/hair for the base body, and uses
the remaining clothing islands as the armour shell.  It is an alpha split, not
a clean production body: the armour is required to cover the missing torso and
limbs.

Run:
  blender -b --factory-startup --python build_real_v3_split.py -- --preview
"""
from __future__ import annotations

import os
import sys

import bpy
import bmesh
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
SOURCE = os.path.join(ROOT, "assets", "characters", "generated", "sunny_real_v3", "sunny_real_v3_clean2.glb")
OUT = os.path.join(ROOT, "assets", "characters", "equipment", "armor")
PREVIEW = os.path.join(os.environ.get("TEMP", ROOT), "equipment_real_v3")

sys.path.insert(0, HERE)
import build_caravan_alpha as base  # noqa: E402


def load_source() -> tuple[bpy.types.Object, bpy.types.Object, bpy.types.Image | None]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SOURCE)
    armature = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    mesh = bpy.data.objects.get("model")
    for obj in list(bpy.context.scene.objects):
        if obj not in (armature, mesh):
            bpy.data.objects.remove(obj, do_unlink=True)
    image = None
    for mat in mesh.data.materials:
        if mat and mat.use_nodes:
            for node in mat.node_tree.nodes:
                if node.type == "TEX_IMAGE" and node.image:
                    image = node.image
                    break
        if image:
            break
    return armature, mesh, image


def components(mesh: bpy.types.Mesh) -> list[list[int]]:
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.verts.ensure_lookup_table()
    seen: set[int] = set()
    result: list[list[int]] = []
    for vert in bm.verts:
        if vert.index in seen:
            continue
        stack = [vert]
        comp: list[int] = []
        seen.add(vert.index)
        while stack:
            cur = stack.pop()
            comp.append(cur.index)
            for edge in cur.link_edges:
                other = edge.other_vert(cur)
                if other.index not in seen:
                    seen.add(other.index)
                    stack.append(other)
        result.append(comp)
    bm.free()
    return result


def average_colour(mesh: bpy.types.Mesh, image: bpy.types.Image | None, comp: list[int]) -> tuple[float, float, float]:
    if image is None:
        return (0.5, 0.5, 0.5)
    uvs = mesh.uv_layers.active
    if uvs is None:
        return (0.5, 0.5, 0.5)
    pixels = image.pixels[:]
    width, height = image.size
    wanted = set(comp)
    samples: list[tuple[float, float, float]] = []
    for poly in mesh.polygons:
        if not all(v in wanted for v in poly.vertices):
            continue
        for loop_index in poly.loop_indices:
            uv = uvs.data[loop_index].uv
            x = int((uv.x % 1.0) * (width - 1))
            y = int((uv.y % 1.0) * (height - 1))
            index = (y * width + x) * 4
            samples.append((pixels[index], pixels[index + 1], pixels[index + 2]))
    if not samples:
        return (0.5, 0.5, 0.5)
    return tuple(sum(s[i] for s in samples) / len(samples) for i in range(3))


def classify(mesh_obj: bpy.types.Object, image: bpy.types.Image | None) -> tuple[set[int], set[int]]:
    mesh = mesh_obj.data
    skin: set[int] = set()
    for comp in components(mesh):
        pts = [mesh.vertices[i].co for i in comp]
        zmin = min(p.z for p in pts)
        zmax = max(p.z for p in pts)
        xcenter = sum(p.x for p in pts) / len(pts)
        zcenter = sum(p.z for p in pts) / len(pts)
        r, g, b = average_colour(mesh, image, comp)
        is_skin = r > 0.35 and g > 0.23 and (r - b) > 0.07 and zmax > 0.55
        is_hair = max(r, g, b) < 0.28 and zmax > 0.55
        is_hand = abs(xcenter) > 0.13 and -0.45 < zcenter < 0.20 and len(comp) < 1600
        if is_skin or is_hair or is_hand:
            skin.update(comp)
    clothing = set(range(len(mesh.vertices))) - skin
    return skin, clothing


def extract(mesh_obj: bpy.types.Object, keep: set[int], name: str) -> bpy.types.Object:
    obj = mesh_obj.copy()
    obj.data = mesh_obj.data.copy()
    obj.name = name
    obj.data.name = name
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    remove = [v for v in bm.verts if v.index not in keep]
    bmesh.ops.delete(bm, geom=remove, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return obj


def build_base(armature: bpy.types.Object, mesh_obj: bpy.types.Object,
               skin: set[int], clothing: set[int]) -> bpy.types.Object:
    # Keep the full silhouette: exposed skin/hair retains the authored texture,
    # while clothing islands become a neutral underlayer.  The armour then sits
    # on top, and removing it no longer leaves a floating head.
    skin_obj = extract(mesh_obj, skin, "SunnyRealV3BaseSkin")
    cloth_obj = extract(mesh_obj, clothing, "SunnyRealV3BaseUnderlayer")
    underlayer = base.make_material("eq_base_underlayer", (0.18, 0.14, 0.12, 1.0), 0.0, 0.92)
    cloth_obj.data.materials.clear()
    cloth_obj.data.materials.append(underlayer)
    bpy.ops.object.select_all(action="DESELECT")
    skin_obj.select_set(True)
    cloth_obj.select_set(True)
    bpy.context.view_layer.objects.active = skin_obj
    bpy.ops.object.join()
    base_obj = bpy.context.object
    base_obj.name = "SunnyRealV3Base"
    base_obj.data.name = base_obj.name
    base_obj.parent = armature
    base_obj.matrix_parent_inverse = armature.matrix_world.inverted()
    if not any(mod.type == "ARMATURE" for mod in base_obj.modifiers):
        mod = base_obj.modifiers.new("Armature", "ARMATURE")
        mod.object = armature
    return base_obj


def build_armor(armature: bpy.types.Object, mesh_obj: bpy.types.Object, clothing: set[int],
                palette: dict, variant: str) -> bpy.types.Object:
    armor = extract(mesh_obj, clothing, "Armor_%s_v3" % variant)
    armor.parent = armature
    armor.matrix_parent_inverse = armature.matrix_world.inverted()
    armor.data.materials.clear()
    leather = base.make_material("eq_leather", palette["leather"], 0.0, 0.82,
                                 base.LEATHER_DIFF, base.LEATHER_NORMAL)
    leather_dark = base.make_material("eq_leather_dark", palette["leather_dark"], 0.0, 0.88,
                                      base.LEATHER_DIFF, base.LEATHER_NORMAL)
    metal = base.make_material("eq_metal", palette["metal"], palette["metal_metallic"], palette["metal_roughness"],
                               base.METAL_DIFF, base.METAL_NORMAL)
    armor.data.materials.append(leather)
    mod = armor.modifiers.new("inflate", "DISPLACE")
    mod.direction = "NORMAL"
    mod.mid_level = 0.0
    mod.strength = 0.018
    armor.modifiers.move(len(armor.modifiers) - 1, 0)
    base.apply_modifier(armor, mod)

    pieces: list[bpy.types.Object] = [armor]
    chest = base.add_uv_sphere("ChestPlate", Vector((0.0, -0.150, 0.38)),
                               Vector((0.205, 0.055, 0.185)), leather_dark)
    base.bind_rigid(chest, armature, "Spine2")
    pieces.append(chest)
    boss = base.add_uv_sphere("ChestBoss", Vector((0.0, -0.195, 0.38)),
                              Vector((0.060, 0.022, 0.060)), metal)
    base.bind_rigid(boss, armature, "Spine2")
    pieces.append(boss)
    band = base.add_box("ChestBand", Vector((0.0, -0.197, 0.30)), Vector((0.31, 0.030, 0.035)), metal)
    base.bevel(band, 0.008, 2)
    base.bind_rigid(band, armature, "Spine2")
    pieces.append(band)

    for side, bone_name in (("L", "LeftShoulder"), ("R", "RightShoulder")):
        shoulder = armature.data.bones[bone_name]
        center = shoulder.head_local.lerp(shoulder.tail_local, 0.72)
        outward = 1.0 if center.x >= 0.0 else -1.0
        center += Vector((outward * 0.025, -0.005, -0.005))
        pauldron = base.add_uv_sphere("Pauldron_" + side, center, Vector((0.145, 0.110, 0.085)), leather)
        base.bind_rigid(pauldron, armature, bone_name)
        pieces.append(pauldron)
        rim = base.add_uv_sphere("PauldronRim_" + side, center + Vector((outward * 0.015, -0.020, -0.045)),
                                 Vector((0.115, 0.095, 0.042)), metal)
        base.bind_rigid(rim, armature, bone_name)
        pieces.append(rim)

    for side, fore_bone in (("L", "LeftForeArm"), ("R", "RightForeArm")):
        a = armature.data.bones[fore_bone].head_local
        b = armature.data.bones[fore_bone].tail_local
        mid = a.lerp(b, 0.65)
        vec = (b - a).normalized()
        brace = base.add_cylinder_between("Bracer_" + side, mid - vec * 0.07, mid + vec * 0.12, 0.058, metal)
        base.bind_rigid(brace, armature, fore_bone)
        pieces.append(brace)

    hips_z = armature.data.bones["Hips"].head_local.z
    belt = base.add_torus("Belt", Vector((0.0, 0.0, hips_z + 0.02)), 0.155, 0.026, leather_dark)
    base.bind_rigid(belt, armature, "Hips")
    pieces.append(belt)
    for side, x in (("L", 0.10), ("R", -0.10)):
        tasset = base.add_box("Tasset_" + side, Vector((x, -0.14, hips_z - 0.09)),
                              Vector((0.13, 0.05, 0.17)), leather)
        base.bevel(tasset, 0.012, 2)
        base.bind_rigid(tasset, armature, "Hips")
        pieces.append(tasset)

    for side, leg_bone in (("L", "LeftLeg"), ("R", "RightLeg")):
        a = armature.data.bones[leg_bone].head_local
        b = armature.data.bones[leg_bone].tail_local
        mid = a.lerp(b, 0.55)
        vec = (b - a).normalized()
        guard = base.add_cylinder_between("ShinGuard_" + side, mid - vec * 0.10, mid + vec * 0.12, 0.072, metal)
        base.bind_rigid(guard, armature, leg_bone)
        pieces.append(guard)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in pieces:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = armor
    bpy.ops.object.join()
    joined = bpy.context.object
    joined.name = "Armor_%s_v3" % variant
    joined.data.name = joined.name
    if not any(mod.type == "ARMATURE" for mod in joined.modifiers):
        mod = joined.modifiers.new("Armature", "ARMATURE")
        mod.object = armature
    return joined


def export_object(obj: bpy.types.Object, armature: bpy.types.Object, path: str, animations: bool) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_animations=animations,
        export_skins=True,
        export_apply=False,
        export_yup=True,
    )
    print("EXPORTED", path)


def main() -> None:
    preview = "--preview" in sys.argv
    for variant, palette in base.PALETTES.items():
        armature, mesh_obj, image = load_source()
        skin, clothing = classify(mesh_obj, image)
        print("SPLIT", variant, "skin", len(skin), "clothing", len(clothing))
        base_obj = build_base(armature, mesh_obj, skin, clothing)
        armor_obj = build_armor(armature, mesh_obj, clothing, palette, variant)
        os.makedirs(OUT, exist_ok=True)
        export_object(base_obj, armature, os.path.join(OUT, "sunny_real_v3_base.glb"), True)
        lods = [base.make_lod(armor_obj, "_LOD1", 0.50), base.make_lod(armor_obj, "_LOD2", 0.25)]
        bpy.ops.object.select_all(action="DESELECT")
        armature.select_set(True)
        armor_obj.select_set(True)
        for lod in lods:
            lod.select_set(True)
        bpy.context.view_layer.objects.active = armor_obj
        bpy.ops.export_scene.gltf(
            filepath=os.path.join(OUT, "caravan_alpha_v3.glb" if variant == "caravan_alpha" else "coral_alpha_v3.glb"),
            export_format="GLB", use_selection=True, export_animations=False,
            export_skins=True, export_apply=False, export_yup=True)
        # Remove objects before the next palette import.
        for obj in [base_obj, armor_obj] + lods:
            if obj and obj.name in bpy.data.objects:
                bpy.data.objects.remove(obj, do_unlink=True)
    if preview:
        print("PREVIEW: use Godot equipment_lab_v3.tscn for validation")


if __name__ == "__main__":
    main()

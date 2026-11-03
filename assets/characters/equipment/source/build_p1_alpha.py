"""P1 / UAL alpha armour shell for the 53-bone fallback Sunny.

This is the second rig-profile proof: the same full-set design is rebuilt on
the MPFB/UAL skeleton, with clothing parts hidden by node names instead of
surface indices.

Run:
  blender -b --factory-startup --python build_p1_alpha.py
"""
from __future__ import annotations

import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
SOURCE = os.path.join(ROOT, "assets", "characters", "p1", "models", "sunny_real.glb")
OUT = os.path.join(ROOT, "assets", "characters", "equipment", "armor")

sys.path.insert(0, HERE)
import build_caravan_alpha as base  # noqa: E402


def import_p1() -> tuple[bpy.types.Object, dict[str, bpy.types.Object]]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SOURCE)
    armature = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    parts: dict[str, bpy.types.Object] = {}
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH":
            continue
        if "_LOD1" in obj.name or "_LOD2" in obj.name or obj.name == "Icosphere":
            bpy.data.objects.remove(obj, do_unlink=True)
            continue
        parts[obj.name] = obj
    return armature, parts


def build(palette: dict, variant: str) -> bpy.types.Object:
    armature, parts = import_p1()
    leather = base.make_material("eq_leather", palette["leather"], 0.0, 0.82,
                                 base.LEATHER_DIFF, base.LEATHER_NORMAL)
    leather_dark = base.make_material("eq_leather_dark", palette["leather_dark"], 0.0, 0.88,
                                      base.LEATHER_DIFF, base.LEATHER_NORMAL)
    metal = base.make_material("eq_metal", palette["metal"], palette["metal_metallic"], palette["metal_roughness"],
                               base.METAL_DIFF, base.METAL_NORMAL)

    sweater = parts["sunny_real.toigo_fisherman_sweater"]
    pants = parts["sunny_real.toigo_wool_pants"]
    shoes = parts["sunny_real.shoes06"]

    pieces = [
        base.duplicate_inflated(sweater, "ArmorShell_Tunic", leather, 0.018),
        base.duplicate_inflated(pants, "ArmorShell_Trousers", leather_dark, 0.014),
        base.duplicate_inflated(shoes, "ArmorShell_Shoes", leather_dark, 0.010),
    ]

    chest = base.add_uv_sphere("ChestPlate", Vector((0.0, -0.155, 1.045)),
                               Vector((0.190, 0.052, 0.175)), leather_dark)
    base.bind_rigid(chest, armature, "Chest")
    pieces.append(chest)
    boss = base.add_uv_sphere("ChestBoss", Vector((0.0, -0.200, 1.045)),
                              Vector((0.055, 0.020, 0.055)), metal)
    base.bind_rigid(boss, armature, "Chest")
    pieces.append(boss)
    band = base.add_box("ChestBand", Vector((0.0, -0.202, 0.970)), Vector((0.31, 0.030, 0.035)), metal)
    base.bevel(band, 0.008, 2)
    base.bind_rigid(band, armature, "Chest")
    pieces.append(band)

    back = base.add_uv_sphere("BackPlate", Vector((0.0, 0.150, 1.055)),
                              Vector((0.180, 0.040, 0.160)), leather_dark)
    base.bind_rigid(back, armature, "Chest")
    pieces.append(back)

    collar = base.add_torus("Collar", Vector((0.0, 0.020, 1.405)), 0.105, 0.024, leather_dark)
    base.bind_rigid(collar, armature, "Neck")
    pieces.append(collar)

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

    for side, fore_bone in (("L", "LeftLowerArm"), ("R", "RightLowerArm")):
        a = armature.data.bones[fore_bone].head_local
        b = armature.data.bones[fore_bone].tail_local
        mid = a.lerp(b, 0.65)
        vec = (b - a).normalized()
        brace = base.add_cylinder_between("Bracer_" + side, mid - vec * 0.07, mid + vec * 0.12, 0.058, metal)
        base.bind_rigid(brace, armature, fore_bone)
        pieces.append(brace)

    hips_z = armature.data.bones["Hips"].head_local.z
    belt = base.add_torus("Belt", Vector((0.0, 0.0, hips_z + 0.015)), 0.155, 0.026, leather_dark)
    base.bind_rigid(belt, armature, "Hips")
    pieces.append(belt)
    for side, x in (("L", 0.10), ("R", -0.10)):
        tasset = base.add_box("Tasset_" + side, Vector((x, -0.145, hips_z - 0.090)),
                              Vector((0.13, 0.05, 0.17)), leather)
        base.bevel(tasset, 0.012, 2)
        base.bind_rigid(tasset, armature, "Hips")
        pieces.append(tasset)

    for side, leg_bone in (("L", "LeftLowerLeg"), ("R", "RightLowerLeg")):
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
    bpy.context.view_layer.objects.active = pieces[0]
    bpy.ops.object.join()
    armor = bpy.context.object
    armor.name = "Armor_%s_p1" % variant
    armor.data.name = armor.name
    if not any(mod.type == "ARMATURE" for mod in armor.modifiers):
        mod = armor.modifiers.new("Armature", "ARMATURE")
        mod.object = armature

    for obj in (sweater, pants, shoes):
        obj.hide_render = True
        obj.hide_viewport = True
    return armor


def export(armor: bpy.types.Object, variant: str) -> str:
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "%s_p1.glb" % variant)
    armature = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    lods = [
        base.make_lod(armor, "_LOD1", 0.50),
        base.make_lod(armor, "_LOD2", 0.25),
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


def main() -> None:
    for variant, palette in base.PALETTES.items():
        armor = build(palette, variant)
        export(armor, variant)


if __name__ == "__main__":
    main()

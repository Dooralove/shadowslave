"""Re-bind a generated armour mesh to the Sunny base skeleton.

Hyper3D rigs the armour on its own 52-bone human template.  That template has
different bone rest lengths from the generated Sunny body, so a simple Skin
remap compresses/shifts the armour.  This script transfers the body's skin
weights onto the armour and binds the armour to the *base* armature instead.

Run:
  blender -b --factory-startup --python rebind_generated_armor.py -- \
    --base assets/characters/generated/sunny_nightmare_v2/sunny_nightmare_v2.glb \
    --armor assets/characters/equipment/armor/scout_leather.glb \
    --output assets/characters/equipment/armor/scout_leather.glb
"""
from __future__ import annotations

import argparse
import os
import sys

import bpy


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True)
    parser.add_argument("--armor", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--limit-influences", type=int, default=4)
    return parser.parse_args(argv)


def largest_mesh(objects: list[bpy.types.Object]) -> bpy.types.Object:
    return max(objects, key=lambda obj: len(obj.data.vertices))


def import_scene(path: str) -> tuple[list[bpy.types.Object], list[bpy.types.Object]]:
    before_meshes = {obj for obj in bpy.context.scene.objects if obj.type == "MESH"}
    before_armatures = {obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"}
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj not in before_meshes]
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE" and obj not in before_armatures]
    return meshes, armatures


def clear_vertex_groups(mesh: bpy.types.Object) -> None:
    mesh.vertex_groups.clear()


def transfer_weights(base_mesh: bpy.types.Object, armor_mesh: bpy.types.Object) -> None:
    clear_vertex_groups(armor_mesh)
    for group in base_mesh.vertex_groups:
        armor_mesh.vertex_groups.new(name=group.name)
    modifier = armor_mesh.modifiers.new("WeightTransfer", "DATA_TRANSFER")
    modifier.object = base_mesh
    modifier.use_vert_data = True
    modifier.data_types_verts = {"VGROUP_WEIGHTS"}
    modifier.vert_mapping = "POLYINTERP_NEAREST"
    modifier.layers_vgroup_select_src = "ALL"
    modifier.layers_vgroup_select_dst = "NAME"
    modifier.mix_mode = "REPLACE"
    bpy.context.view_layer.objects.active = armor_mesh
    armor_mesh.select_set(True)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    # glTF supports four influences by default; normalise after limiting.
    bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
    try:
        bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    except RuntimeError as error:
        print("WEIGHT_LIMIT_SKIPPED", error)
    try:
        bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    except RuntimeError as error:
        print("WEIGHT_NORMALIZE_SKIPPED", error)
    bpy.ops.object.mode_set(mode="OBJECT")


def bind_to_base(armor_mesh: bpy.types.Object, base_armature: bpy.types.Object) -> None:
    for modifier in list(armor_mesh.modifiers):
        if modifier.type == "ARMATURE":
            armor_mesh.modifiers.remove(modifier)
    armor_mesh.parent = base_armature
    armor_mesh.matrix_parent_inverse = base_armature.matrix_world.inverted()
    modifier = armor_mesh.modifiers.new("Armature", "ARMATURE")
    modifier.object = base_armature


def export_armor(armor_mesh: bpy.types.Object, base_armature: bpy.types.Object, output: str) -> None:
    os.makedirs(os.path.dirname(output), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    armor_mesh.select_set(True)
    base_armature.select_set(True)
    bpy.context.view_layer.objects.active = armor_mesh
    bpy.ops.export_scene.gltf(
        filepath=output,
        export_format="GLB",
        use_selection=True,
        export_animations=False,
        export_skins=True,
        export_tangents=True,
        export_apply=False,
        export_yup=True,
        export_materials="EXPORT",
    )
    print("EXPORTED", output)


def main() -> None:
    args = parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)

    base_meshes, base_armatures = import_scene(args.base)
    if not base_meshes or not base_armatures:
        raise SystemExit("base scene has no mesh/armature")
    base_mesh = largest_mesh(base_meshes)
    base_armature = base_armatures[0]
    print("BASE", base_mesh.name, len(base_mesh.data.vertices), base_armature.name,
          "bones", len(base_armature.data.bones))

    armor_meshes, armor_armatures = import_scene(args.armor)
    if not armor_meshes:
        raise SystemExit("armor scene has no mesh")
    armor_mesh = largest_mesh(armor_meshes)
    print("ARMOR", armor_mesh.name, len(armor_mesh.data.vertices),
          "armatures", [a.name for a in armor_armatures])

    transfer_weights(base_mesh, armor_mesh)
    bind_to_base(armor_mesh, base_armature)

    # Remove everything that is not the final armour mesh or the base armature.
    for obj in list(bpy.context.scene.objects):
        if obj == armor_mesh or obj == base_armature:
            continue
        bpy.data.objects.remove(obj, do_unlink=True)

    print("BOUND", armor_mesh.name, "groups", len(armor_mesh.vertex_groups),
          "modifiers", [m.type for m in armor_mesh.modifiers])
    export_armor(armor_mesh, base_armature, args.output)


if __name__ == "__main__":
    main()

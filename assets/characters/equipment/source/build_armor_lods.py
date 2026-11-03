"""Build LOD1/LOD2 for a re-bound armour GLB.

The base mesh is kept as LOD0; two decimated copies are added with the same
armature and vertex groups.  The exporter writes all three skinned meshes into
one GLB, so EquipmentComponent can attach them once and drive
GeometryInstance3D.visibility_range_begin/end.

Run:
  blender -b --factory-startup --python build_armor_lods.py -- \
    --input assets/characters/equipment/armor/scout_leather.glb \
    --output "$env:TEMP/opencode/scout_lod.glb"
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
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--lod1-ratio", type=float, default=0.45)
    parser.add_argument("--lod2-ratio", type=float, default=0.18)
    return parser.parse_args(argv)


def largest_mesh() -> bpy.types.Object:
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise SystemExit("no mesh")
    return max(meshes, key=lambda obj: len(obj.data.vertices))


def duplicate_mesh(source: bpy.types.Object, name: str) -> bpy.types.Object:
    obj = source.copy()
    obj.data = source.data.copy()
    obj.name = name
    obj.data.name = name
    bpy.context.collection.objects.link(obj)
    return obj


def decimate(obj: bpy.types.Object, ratio: float) -> None:
    bpy.context.view_layer.objects.active = obj
    modifier = obj.modifiers.new("Decimate", "DECIMATE")
    modifier.decimate_type = "COLLAPSE"
    modifier.ratio = ratio
    modifier.use_collapse_triangulate = True
    # Decimate the rest mesh, before the Armature modifier.
    obj.modifiers.move(len(obj.modifiers) - 1, 0)
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def main() -> None:
    args = parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=args.input)
    base = largest_mesh()
    base.name = "model_LOD0"
    base.data.name = "model_LOD0"
    armature = next((obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"), None)
    if armature is None:
        raise SystemExit("no armature")

    lod1 = duplicate_mesh(base, "model_LOD1")
    lod2 = duplicate_mesh(base, "model_LOD2")
    decimate(lod1, args.lod1_ratio)
    decimate(lod2, args.lod2_ratio)

    for obj in (base, lod1, lod2):
        print("LOD", obj.name, "verts", len(obj.data.vertices),
              "tris", sum(len(poly.vertices) - 2 for poly in obj.data.polygons),
              "materials", len(obj.data.materials),
              "groups", len(obj.vertex_groups))

    bpy.ops.object.select_all(action="DESELECT")
    for obj in (base, lod1, lod2):
        obj.select_set(True)
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=args.output,
        export_format="GLB",
        use_selection=True,
        export_animations=False,
        export_skins=True,
        export_tangents=True,
        export_apply=False,
        export_yup=True,
        export_materials="EXPORT",
    )
    print("EXPORTED", args.output)


if __name__ == "__main__":
    main()

"""Rigidly weight the hood/helmet region of a re-bound armour to the Head bone.

Automatic body-to-armour weight transfer gives the hood/helmet a blend of neck,
chest and head weights, so it lags and clips when the head turns or the arms
guard.  This script selects vertices inside a sphere around the Head bone and
assigns them 100% to Head; the rest of the outfit keeps its transferred weights.

Run:
  blender -b --factory-startup --python fix_armor_head_weights.py -- \
    --input "$env:TEMP/opencode/scout_lod.glb" \
    --output "$env:TEMP/opencode/scout_lod_head.glb"
"""
from __future__ import annotations

import argparse
import os
import sys

import bpy
from mathutils import Vector


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--radius", type=float, default=0.26)
    parser.add_argument("--z-margin", type=float, default=0.16)
    return parser.parse_args(argv)


def main() -> None:
    args = parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=args.input)
    armature = next((obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"), None)
    if armature is None:
        raise SystemExit("no armature")
    head_bone = armature.data.bones.get("Head")
    if head_bone is None:
        raise SystemExit("no Head bone")
    center = (head_bone.head_local + head_bone.tail_local) * 0.5
    min_z = center.z - args.z_margin
    print("HEAD_CENTER", tuple(round(v, 4) for v in center), "min_z", round(min_z, 4),
          "radius", args.radius)

    meshes = [
        obj for obj in bpy.context.scene.objects
        if obj.type == "MESH" and not obj.name.lower().startswith("icosphere")
    ]
    for mesh_obj in meshes:
        mesh = mesh_obj.data
        head_group = mesh_obj.vertex_groups.get("Head")
        if head_group is None:
            head_group = mesh_obj.vertex_groups.new(name="Head")
        selected = 0
        for vertex in mesh.vertices:
            co = mesh_obj.matrix_world @ vertex.co
            if co.z < min_z:
                continue
            if (co - center).length > args.radius:
                continue
            for group_element in list(vertex.groups):
                if group_element.group != head_group.index:
                    mesh_obj.vertex_groups[group_element.group].remove([vertex.index])
            head_group.add([vertex.index], 1.0, "REPLACE")
            selected += 1
        print("HEAD_WEIGHTS", mesh_obj.name, "selected", selected, "of", len(mesh.vertices))

    bpy.ops.object.select_all(action="DESELECT")
    for mesh_obj in meshes:
        mesh_obj.select_set(True)
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

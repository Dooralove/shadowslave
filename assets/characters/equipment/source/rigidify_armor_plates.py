"""Rigidify metal plate islands of a generated armour mesh.

Automatic body-to-armour weight transfer gives large rigid plates a smooth mix
of arm/spine/neck weights, so they stretch and explode in extreme poses.  This
script finds connected plate islands, picks each island's dominant bone by
total transferred weight, and assigns the whole island 100% to that bone.
Cloth islands keep their smooth weights.

Run:
  blender -b --factory-startup --python rigidify_armor_plates.py -- \
    --input "$env:TEMP/opencode/heavy_split.glb" \
    --output "$env:TEMP/opencode/heavy_rigid.glb"
"""
from __future__ import annotations

import argparse
import os
import sys
from collections import defaultdict

import bpy


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--min-plate-fraction", type=float, default=0.5)
    parser.add_argument("--min-dominant-share", type=float, default=0.62)
    return parser.parse_args(argv)


def connected_components(mesh: bpy.types.Mesh) -> list[list[int]]:
    parent = list(range(len(mesh.vertices)))

    def find(a: int) -> int:
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    def union(a: int, b: int) -> None:
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra

    for edge in mesh.edges:
        union(edge.vertices[0], edge.vertices[1])
    groups: dict[int, list[int]] = defaultdict(list)
    for index in range(len(mesh.vertices)):
        groups[find(index)].append(index)
    return list(groups.values())


def plate_material_indices(mesh: bpy.types.Mesh) -> list[int]:
    indices = [
        index for index, material in enumerate(mesh.materials)
        if material is not None and "plate" in material.name.lower()
    ]
    if not indices and len(mesh.materials) == 1:
        # A fully metal set may have lost the unused cloth slot on export.
        indices = [0]
    return indices


def rigidify(mesh_obj: bpy.types.Object, min_fraction: float, min_dominant_share: float) -> None:
    mesh = mesh_obj.data
    plate_indices = plate_material_indices(mesh)
    if not plate_indices:
        print("NO_PLATE_MATERIAL", mesh_obj.name)
        return
    plate_vertices: set[int] = set()
    for polygon in mesh.polygons:
        if polygon.material_index in plate_indices:
            plate_vertices.update(polygon.vertices)
    components = connected_components(mesh)
    rigid_islands = 0
    rigid_vertices = 0
    skipped = 0
    for component in components:
        if not component:
            continue
        plate_count = sum(1 for index in component if index in plate_vertices)
        if plate_count / len(component) < min_fraction:
            continue
        totals: dict[int, float] = defaultdict(float)
        for index in component:
            for element in mesh.vertices[index].groups:
                totals[element.group] += element.weight
        if not totals:
            continue
        dominant = max(totals, key=totals.get)
        total_weight = sum(totals.values())
        dominant_share = totals[dominant] / total_weight if total_weight > 0.0 else 0.0
        if dominant_share < min_dominant_share:
            skipped += 1
            continue
        group = mesh_obj.vertex_groups[dominant]
        for index in component:
            for element in list(mesh.vertices[index].groups):
                if element.group != dominant:
                    mesh_obj.vertex_groups[element.group].remove([index])
            group.add([index], 1.0, "REPLACE")
        rigid_islands += 1
        rigid_vertices += len(component)
    print("RIGID", mesh_obj.name, "islands", rigid_islands, "vertices", rigid_vertices,
          "of", len(mesh.vertices), "skipped_shared", skipped,
          "plate_materials", plate_indices)


def main() -> None:
    args = parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=args.input)
    armature = next((obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"), None)
    if armature is None:
        raise SystemExit("no armature")
    meshes = [
        obj for obj in bpy.context.scene.objects
        if obj.type == "MESH" and not obj.name.lower().startswith("icosphere")
    ]
    for mesh_obj in meshes:
        rigidify(mesh_obj, args.min_plate_fraction, args.min_dominant_share)

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

"""Prepare a Hyper3D rigged armour GLB for the shared Sunny skeleton.

The generated armour is a hollow outfit on a blank mannequin.  The blank head
is a separate photogrammetry island inside the hood/helmet; it must be removed
so the character's own head remains visible.  Everything else (garment, gloves,
boots, armour plates) is kept.

Run:
  blender -b --factory-startup --python prepare_generated_armor.py -- \
    --input incoming_models/P2_equipment/scout_leather_rigged.glb \
    --output assets/characters/equipment/armor/scout_leather.glb \
    --delete-head
"""
from __future__ import annotations

import argparse
import os
import sys
from collections import defaultdict

import bpy
from mathutils import Vector


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--delete-head", action="store_true")
    parser.add_argument("--head-min-z", type=float, default=0.52)
    parser.add_argument("--head-max-z", type=float, default=0.99)
    parser.add_argument("--head-min-verts", type=int, default=300)
    parser.add_argument("--head-max-size", type=float, default=0.36)
    parser.add_argument("--preview", default="")
    return parser.parse_args(argv)


def import_glb(path: str) -> tuple[list[bpy.types.Object], bpy.types.Object | None]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    armatures = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    armature = armatures[0] if armatures else None
    return meshes, armature


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


def component_bounds(mesh: bpy.types.Mesh, verts: list[int]) -> tuple[Vector, Vector]:
    mn = Vector((1e9, 1e9, 1e9))
    mx = Vector((-1e9, -1e9, -1e9))
    for index in verts:
        co = mesh.vertices[index].co
        mn.x = min(mn.x, co.x)
        mn.y = min(mn.y, co.y)
        mn.z = min(mn.z, co.z)
        mx.x = max(mx.x, co.x)
        mx.y = max(mx.y, co.y)
        mx.z = max(mx.z, co.z)
    return mn, mx


def find_head_component(mesh: bpy.types.Mesh, args: argparse.Namespace) -> list[int] | None:
    best: list[int] | None = None
    best_score = 1e9
    target_size = Vector((0.16, 0.24, 0.30))
    target_center = Vector((0.0, -0.03, 0.75))
    for verts in connected_components(mesh):
        if len(verts) < args.head_min_verts:
            continue
        mn, mx = component_bounds(mesh, verts)
        center = (mn + mx) * 0.5
        size = mx - mn
        if not (args.head_min_z <= center.z <= args.head_max_z):
            continue
        if abs(center.x) > 0.12:
            continue
        if not (-0.08 <= center.y <= 0.12):
            continue
        if size.x > 0.55 or size.y > 0.55 or size.z > 0.55:
            continue
        if size.x > args.head_max_size or size.y > args.head_max_size or size.z > args.head_max_size:
            continue
        # The blank head is a closed ellipsoid inside the hood/helmet.  Pick the
        # island whose dimensions and centre are closest to a human head, not
        # the largest island (that is the outer hood).
        score = (size - target_size).length + (center - target_center).length
        if score < best_score:
            best_score = score
            best = verts
    return best


def delete_vertices(obj: bpy.types.Object, indices: list[int]) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.object.mode_set(mode="OBJECT")
    for index in indices:
        obj.data.vertices[index].select = True
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.delete(type="VERT")
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)


def export_glb(meshes: list[bpy.types.Object], armature: bpy.types.Object | None, output: str) -> None:
    os.makedirs(os.path.dirname(output), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    if armature is not None:
        armature.select_set(True)
        bpy.context.view_layer.objects.active = armature
    elif meshes:
        bpy.context.view_layer.objects.active = meshes[0]
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
    meshes, armature = import_glb(args.input)
    # Hyper3D rigging leaves a small Icosphere helper; it is not part of the outfit.
    meshes = [o for o in meshes if not o.name.lower().startswith("icosphere")]
    for obj in list(bpy.context.scene.objects):
        if obj.type == "MESH" and obj.name.lower().startswith("icosphere"):
            bpy.data.objects.remove(obj, do_unlink=True)
    print("IMPORTED meshes", [(o.name, len(o.data.vertices)) for o in meshes],
          "armature", armature.name if armature else None)
    for obj in meshes:
        if args.delete_head:
            head = find_head_component(obj.data, args)
            if head is None:
                print("HEAD_NOT_FOUND", obj.name)
                continue
            mn, mx = component_bounds(obj.data, head)
            print("HEAD_DELETE", obj.name, "verts", len(head),
                  "bbox", tuple(round(v, 3) for v in mn), tuple(round(v, 3) for v in mx))
            delete_vertices(obj, head)
        print("MESH_AFTER", obj.name, "verts", len(obj.data.vertices),
              "tris", sum(len(p.vertices) - 2 for p in obj.data.polygons))
    export_glb(meshes, armature, args.output)


if __name__ == "__main__":
    main()

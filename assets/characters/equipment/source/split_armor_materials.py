"""Split generated armour into cloth (double-sided) and plate (single-sided).

The Hyper3D outfit arrives as one mesh with one material.  Closed metal plates
do not need double-sided rendering, while hoods/cloaks/tabards do.  This script
classifies faces by the metallic channel of the glTF metallic-roughness map:
metal faces get a single-sided plate material, non-metal faces keep the
double-sided cloth material.

Run:
  blender -b --factory-startup --python split_armor_materials.py -- \
    --input assets/characters/equipment/armor/scout_leather.glb \
    --output "$env:TEMP/opencode/scout_split.glb"
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
    parser.add_argument("--metallic-threshold", type=float, default=0.35)
    return parser.parse_args(argv)


def largest_mesh() -> bpy.types.Object:
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise SystemExit("no mesh")
    return max(meshes, key=lambda obj: len(obj.data.vertices))


def find_metallic_image() -> bpy.types.Image | None:
    candidates = []
    for image in bpy.data.images:
        name = image.name.lower()
        if "metallic" in name or "roughness" in name:
            if image.size[0] > 0 and image.size[1] > 0:
                candidates.append(image)
    return candidates[0] if candidates else None


def sample_metallic(image: bpy.types.Image, uv: tuple[float, float]) -> float:
    width, height = image.size
    x = int((uv[0] % 1.0) * (width - 1))
    y = int((uv[1] % 1.0) * (height - 1))
    index = (y * width + x) * 4
    pixels = image.pixels
    if index + 2 >= len(pixels):
        return 0.0
    # glTF metallic-roughness: G = roughness, B = metallic.
    return float(pixels[index + 2])


def main() -> None:
    args = parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=args.input)
    mesh_obj = largest_mesh()
    mesh = mesh_obj.data
    if not mesh.materials:
        raise SystemExit("mesh has no material")
    if not mesh.uv_layers.active:
        raise SystemExit("mesh has no UV layer")
    image = find_metallic_image()
    if image is None:
        raise SystemExit("metallic-roughness image not found")

    cloth = mesh.materials[0]
    cloth.use_backface_culling = False
    plate = cloth.copy()
    plate.name = cloth.name + "_plate"
    plate.use_backface_culling = True
    mesh.materials.clear()
    mesh.materials.append(cloth)
    mesh.materials.append(plate)

    uv_layer = mesh.uv_layers.active
    plate_faces = 0
    cloth_faces = 0
    for polygon in mesh.polygons:
        u = 0.0
        v = 0.0
        for loop_index in polygon.loop_indices:
            uv = uv_layer.data[loop_index].uv
            u += uv.x
            v += uv.y
        count = max(len(polygon.loop_indices), 1)
        metallic = sample_metallic(image, (u / count, v / count))
        if metallic >= args.metallic_threshold:
            polygon.material_index = 1
            plate_faces += 1
        else:
            polygon.material_index = 0
            cloth_faces += 1

    print("SPLIT", mesh_obj.name, "plate_faces", plate_faces, "cloth_faces", cloth_faces,
          "threshold", args.metallic_threshold)

    armature = next((obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"), None)
    bpy.ops.object.select_all(action="DESELECT")
    mesh_obj.select_set(True)
    if armature is not None:
        armature.select_set(True)
        bpy.context.view_layer.objects.active = armature
    else:
        bpy.context.view_layer.objects.active = mesh_obj
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

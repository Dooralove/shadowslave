"""Render Hyper3D relief props to flat, transparent UI sprites.

Usage:
  blender --background --factory-startup --python tools/art/render_ui_props.py -- \
    --input incoming_models/P3_ui/hp_frame_raw.glb \
    --output assets/ui/vitals/source/hp_frame_raw.png \
    --width 2048 --height 816

The camera is orthographic and looks along -Y. The source models are authored
front-facing, so the render is a clean 2D UI sprite with alpha.
"""

import argparse
import math
import os
import sys

import bpy
from mathutils import Vector


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--width", type=int, default=2048)
    parser.add_argument("--height", type=int, default=816)
    parser.add_argument("--margin", type=float, default=1.06)
    parser.add_argument("--samples", type=int, default=64)
    parser.add_argument("--scale-x", type=float, default=1.0)
    return parser.parse_args(argv)


def main() -> None:
    args = parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))

    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh in {args.input}")

    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
    obj.location = (0.0, 0.0, 0.0)
    if args.scale_x != 1.0:
        obj.scale.x = args.scale_x

    for poly in obj.data.polygons:
        poly.use_smooth = True

    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    mins = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    maxs = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    size = maxs - mins
    center = (mins + maxs) * 0.5
    print("BOUNDS", tuple(round(v, 4) for v in size))

    world = bpy.data.worlds.new("UIWorld")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (0.03, 0.035, 0.04, 1.0)
    bg.inputs[1].default_value = 0.35

    def add_area(name: str, loc: tuple[float, float, float], energy: float, size_m: float, color: tuple[float, float, float]) -> None:
        data = bpy.data.lights.new(name, type="AREA")
        data.energy = energy
        data.shape = "DISK"
        data.size = size_m
        data.color = color
        light = bpy.data.objects.new(name, data)
        bpy.context.collection.objects.link(light)
        light.location = loc
        light.rotation_euler = (Vector((0, 0, 0)) - light.location).to_track_quat("-Z", "Y").to_euler()

    add_area("Key", (-2.4, -3.0, 2.6), 650.0, 3.0, (1.0, 0.91, 0.78))
    add_area("Fill", (2.8, -2.2, 1.2), 320.0, 3.0, (0.55, 0.72, 1.0))
    add_area("Rim", (0.4, 2.4, 2.2), 450.0, 2.2, (0.95, 0.55, 0.42))
    add_area("Bottom", (0.0, -1.0, -2.4), 180.0, 2.0, (0.55, 0.62, 0.72))

    cam_data = bpy.data.cameras.new("Camera")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("Camera", cam_data)
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    cam.location = (center.x, center.y - 5.0, center.z)
    cam.rotation_euler = (Vector(center) - cam.location).to_track_quat("-Z", "Y").to_euler()

    aspect = args.width / float(args.height)
    cam_data.ortho_scale = max(size.x * args.margin, size.z * args.margin * aspect)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = args.width
    scene.render.resolution_y = args.height
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 15
    scene.render.film_transparent = True
    scene.eevee.taa_render_samples = args.samples
    scene.view_settings.look = "AgX - Medium High Contrast"

    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    scene.render.filepath = os.path.abspath(args.output)
    bpy.ops.render.render(write_still=True)
    print("WROTE", scene.render.filepath)


if __name__ == "__main__":
    main()

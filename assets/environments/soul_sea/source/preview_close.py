"""Close-up preview of one Soul Sea asset from soul_sea_kit.blend.

Usage:
    blender -b assets/environments/soul_sea/source/soul_sea_kit.blend \
      --python assets/environments/soul_sea/source/preview_close.py -- ss_shade_slave_a
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

SRC = Path(__file__).resolve().parent
NM_SRC = Path(__file__).resolve().parents[2] / "nightmare" / "source"
for _p in (SRC, NM_SRC):
    if str(_p) not in sys.path:
        sys.path.insert(0, str(_p))

import nm_lib as L  # noqa: E402

OUT = L.ROOT / "docs" / "art" / "previews" / "soul_sea"


def _hide_existing():
    for coll in bpy.data.collections:
        if coll.name.startswith("PREVIEW"):
            coll.hide_render = True
            coll.hide_viewport = True
    for obj in bpy.context.scene.objects:
        if obj.type in {"LIGHT", "MESH"} and not obj.name.startswith("CLOSE_"):
            obj.hide_render = True
            obj.hide_viewport = True


def _mat(name, color, rough=0.6, metallic=0.0):
    mat = L._simple_mat(name, color, rough)
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Metallic"].default_value = metallic
    return mat


def main():
    args = sys.argv
    name = args[args.index("--") + 1] if "--" in args else "ss_shade_slave_a"
    coll = bpy.data.collections.get(name)
    if coll is None:
        raise SystemExit(f"collection not found: {name}")
    L.set_assets_visible(False)
    _hide_existing()

    close = bpy.data.collections.get("CLOSE") or bpy.data.collections.new("CLOSE")
    if close.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(close)
    for o in list(close.objects):
        bpy.data.objects.remove(o, do_unlink=True)

    # Copy asset meshes into CLOSE.
    asset_objs = []
    for src in coll.objects:
        if src.type != "MESH":
            continue
        dup = src.copy()
        dup.data = src.data
        dup.hide_render = False
        dup.hide_viewport = False
        close.objects.link(dup)
        asset_objs.append(dup)
    if not asset_objs:
        raise SystemExit("no meshes")

    # Ground and scale bar.
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=24.0)
    ground = L.object_from_bmesh("CLOSE_Ground", bm, close, None)
    ground.data.materials.append(_mat("CLOSE_ground", (0.055, 0.075, 0.095), 0.45, 0.15))
    ground.location.z = -0.015
    bar = bpy.data.meshes.new("CLOSE_bar_mesh")
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=12,
                          radius1=0.045, radius2=0.045, depth=1.75)
    bm.transform(Matrix.Translation((2.4, 0.0, 0.875)))
    bm.to_mesh(bar)
    bm.free()
    bar_obj = bpy.data.objects.new("CLOSE_ScaleBar", bar)
    close.objects.link(bar_obj)
    bar_obj.data.materials.append(_mat("CLOSE_scale", (0.28, 0.32, 0.38), 0.55))

    # Lights.
    def area(name, loc, rot, energy, color, size):
        data = bpy.data.lights.new(name, "AREA")
        data.energy = energy
        data.color = color
        data.shape = "DISK"
        data.size = size
        obj = bpy.data.objects.new(name, data)
        close.objects.link(obj)
        obj.location = loc
        obj.rotation_euler = rot
        return obj

    area("CLOSE_Key", (4.5, -6.0, 5.0), (math.radians(52), 0, math.radians(38)),
         900.0, (0.75, 0.85, 1.0), 5.0)
    area("CLOSE_Fill", (-4.0, -2.5, 3.0), (math.radians(65), 0, math.radians(-55)),
         280.0, (0.55, 0.68, 0.9), 4.0)
    area("CLOSE_Rim", (-2.5, 5.0, 4.5), (math.radians(60), 0, math.radians(-150)),
         700.0, (0.40, 0.58, 1.0), 4.0)
    # Warm accent for Memory.
    if "memory" in name or "echo" in name or "sigil" in name:
        data = bpy.data.lights.new("CLOSE_Warm", "POINT")
        data.energy = 180.0
        data.color = (1.0, 0.55, 0.25)
        data.shadow_soft_size = 0.5
        obj = bpy.data.objects.new("CLOSE_Warm", data)
        close.objects.link(obj)
        obj.location = (0.0, 1.5, 0.8)

    # Neutral-ish background.
    scene = bpy.context.scene
    world = scene.world
    if world is None:
        world = bpy.data.worlds.new("CLOSE_World")
        scene.world = world
    bg = next((n for n in world.node_tree.nodes if n.type == "BACKGROUND"), None)
    if bg is not None:
        bg.inputs["Color"].default_value = (0.020, 0.030, 0.050, 1.0)
        bg.inputs["Strength"].default_value = 0.8
    scene.view_settings.exposure = 1.1
    scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = 64

    direction = (-1.0, -1.45, 0.45)
    lens = 58.0
    if "mountain_king" in name or "colossus" in name:
        direction = (-1.0, -1.55, 0.38)
        lens = 52.0
    L.frame_camera(asset_objs, direction=direction, lens=lens, margin=1.05)
    OUT.mkdir(parents=True, exist_ok=True)
    L.render(OUT / f"close_{name}.jpg")


if __name__ == "__main__":
    main()

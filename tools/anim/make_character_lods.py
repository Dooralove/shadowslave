"""Create LOD1/LOD2 meshes for an existing skinned character GLB.

Usage:
  blender --background --python tools/anim/make_character_lods.py -- \
    --src assets/characters/.../model.glb --out assets/characters/.../model_lod.glb \
    --lod1 0.45 --lod2 0.16

The output keeps LOD0 unchanged and adds mesh copies named <mesh>_LOD1 and
<mesh>_LOD2. All copies share the source armature and animations, so Godot's
CharacterLodVisibility can switch them without a second skeleton/player.
"""

import argparse
import os
import sys

import bpy


def _args() -> argparse.Namespace:
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--src", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--lod1", type=float, default=0.45)
    parser.add_argument("--lod2", type=float, default=0.16)
    return parser.parse_args(raw)


def _tris(obj: bpy.types.Object) -> int:
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def _make_lod(source: bpy.types.Object, name: str, ratio: float) -> bpy.types.Object:
    dup = source.copy()
    dup.data = source.data.copy()
    dup.name = name
    dup.data.name = name
    bpy.context.collection.objects.link(dup)
    mod = dup.modifiers.new("LOD_Decimate", "DECIMATE")
    mod.ratio = ratio
    mod.use_collapse_triangulate = True
    bpy.ops.object.select_all(action="DESELECT")
    dup.select_set(True)
    bpy.context.view_layer.objects.active = dup
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return dup


def main() -> None:
    args = _args()
    src = os.path.abspath(args.src)
    out = os.path.abspath(args.out)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    scene = bpy.context.scene
    armatures = [o for o in scene.objects if o.type == "ARMATURE"]
    if len(armatures) != 1:
        raise RuntimeError(f"expected one armature, got {[o.name for o in armatures]}")
    rig = armatures[0]
    source_meshes = [o for o in scene.objects if o.type == "MESH"]
    # Image-to-3D exports contain an unused Icosphere helper.
    source_meshes = [o for o in source_meshes if "icosphere" not in o.name.lower()]
    if not source_meshes:
        raise RuntimeError("no source meshes")

    lod1: list[bpy.types.Object] = []
    lod2: list[bpy.types.Object] = []
    for mesh in source_meshes:
        lod1.append(_make_lod(mesh, f"{mesh.name}_LOD1", args.lod1))
        lod2.append(_make_lod(mesh, f"{mesh.name}_LOD2", args.lod2))

    for obj in scene.objects:
        if "icosphere" in obj.name.lower():
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in source_meshes + lod1 + lod2 + [rig]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=out,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_anim_single_armature=True,
        export_skins=True,
        export_yup=True,
        export_image_format="AUTO",
    )

    print(
        "LOD_DONE",
        "src", src,
        "out", out,
        "lod0", [_tris(o) for o in source_meshes],
        "lod1", [_tris(o) for o in lod1],
        "lod2", [_tris(o) for o in lod2],
        "bones", len(rig.data.bones),
        "actions", [a.name for a in bpy.data.actions],
        "size", os.path.getsize(out),
    )


if __name__ == "__main__":
    main()

"""Stealth cover prop kit — Hyper3D raw GLB post-processing (Blender 5.1).

Pilot batch for the pilgrim path stealth section. Takes the raw text-to-3D
outputs from `incoming_models/P2_environment/stealth_covers/`, normalises them
to the placeholder dimensions, sets a bottom-centre origin, decimates to a
boulder-class budget, assigns the `nm_rock` material slot and exports GLBs.

Run in a fresh background Blender:
    blender -b --factory-startup --python assets/environments/nightmare/source/build_stealth_covers.py -- [options]

Options:
    --raw-dir <path>   folder with cover_*_raw.glb (default: incoming_models/...)
    --no-export        build + .blend + previews only
    --no-preview       skip the preview render

Outputs:
    assets/environments/nightmare/path/stealth_cover_a.glb
    assets/environments/nightmare/path/stealth_cover_b.glb
    assets/environments/nightmare/path/stealth_cover_c.glb
    assets/environments/nightmare/source/stealth_covers.blend
    docs/art/previews/nightmare/stealth_covers.jpg
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

SRC = Path(__file__).resolve().parent
if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))

import nm_lib as L  # noqa: E402

ROOT = L.ROOT
DEFAULT_RAW = ROOT / "incoming_models" / "P2_environment" / "stealth_covers"
OUT_DIR = L.NM_DIR / "path"
PREVIEW = L.PREVIEW_DIR / "stealth_covers.jpg"
BLEND = SRC / "stealth_covers.blend"

# name, raw file, target dimensions in Blender metres (X width, Y length, Z height), triangle budget
SPECS = [
    ("stealth_cover_a", "cover_a_raw.glb", (1.2, 2.2, 1.4), 3200),
    ("stealth_cover_b", "cover_b_raw.glb", (1.2, 2.2, 1.4), 3200),
    ("stealth_cover_c", "cover_c_raw.glb", (1.0, 1.6, 1.2), 2600),
]


def import_join(path: Path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"no meshes in {path}")
    for o in meshes:
        world = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = world
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    return bpy.context.view_layer.objects.active


def clean_mesh(obj) -> None:
    """Merge Hyper3D seam duplicates and remove degenerate faces before decimation."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=bm.edges)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()


def fit_to_target(obj, target: tuple[float, float, float]) -> None:
    cur = obj.dimensions.copy()
    obj.scale = Vector((target[0] / cur.x, target[1] / cur.y, target[2] / cur.z))
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)


def origin_bottom_center(obj) -> None:
    bb = [Vector(c) for c in obj.bound_box]
    mn = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    mx = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    centre = (mn + mx) * 0.5
    obj.data.transform(Matrix.Translation((-centre.x, -centre.y, -mn.z)))
    obj.location = (0.0, 0.0, 0.0)


def build_one(name: str, raw: Path, target, budget: int):
    obj = import_join(raw)
    obj.name = name
    obj.data.name = name + "_mesh"
    clean_mesh(obj)
    fit_to_target(obj, target)
    origin_bottom_center(obj)
    L.decimate(obj, budget)
    L.uv_box(obj, 1.0)
    L.shade(obj, 38.0)
    obj.data.materials.clear()
    obj.data.materials.append(L.material("nm_rock"))
    coll = L.asset_collection(name)
    L.link(obj, coll)
    print(
        "BUILT", name,
        "tris", L.tri_count(obj),
        "dim", tuple(round(v, 3) for v in obj.dimensions),
        "origin", tuple(round(v, 3) for v in obj.location),
    )
    return obj, coll


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw-dir", default=str(DEFAULT_RAW))
    ap.add_argument("--no-export", action="store_true")
    ap.add_argument("--no-preview", action="store_true")
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args = ap.parse_args(argv)
    raw_dir = Path(args.raw_dir)
    if not raw_dir.is_absolute():
        raw_dir = ROOT / raw_dir

    missing = [raw for _, raw, _, _ in SPECS if not (raw_dir / raw).exists()]
    if missing:
        print("MISSING raw files:", ", ".join(missing))
        print("Put the Hyper3D raw GLBs into", raw_dir)
        return 2

    L.clear_data()
    L.setup_render(res=(1400, 800), samples=64)
    built = []
    for name, raw_name, target, budget in SPECS:
        obj, coll = build_one(name, raw_dir / raw_name, target, budget)
        built.append((obj, coll))

    if not args.no_export:
        for name, raw_name, target, budget in SPECS:
            coll = bpy.data.collections[name]
            L.export_collection(coll, OUT_DIR / f"{name}.glb")

    if not args.no_preview:
        placed, _ = L.lineup([c for _, c in built], spacing=1.0, axis="X", start=-2.0)
        mannequin = L.mannequin(location=(5.0, 0.0, 0.0), height=1.75)
        L.frame_camera(placed + [mannequin], direction=(-1.0, -1.6, 0.7), lens=42.0, margin=1.12)
        L.render(PREVIEW)

    bpy.data.orphans_purge(do_recursive=True)
    L.save_blend(BLEND)

    print("DONE")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

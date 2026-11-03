"""Процедурный набор мёртвых деревьев для среднего плана горных локаций.

Запуск:
    blender -b --factory-startup --python assets/environments/nightmare/source/build_dead_tree_kit.py

Экспортирует `assets/environments/nightmare/flora/dead_tree_a/b/c.glb`.
Новых внешних текстур нет: используется существующий `nm_bark.tres`.
"""
import math
import random
import sys
import time
from pathlib import Path

SRC = Path(__file__).resolve().parent
if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import nm_lib as L  # noqa: E402

OUT_DIR = L.NM_DIR / "flora"
VARIANT = {
    "dead_tree_a": dict(height=14.0, seed=7101, spread=0.34, forks=4),
    "dead_tree_b": dict(height=11.5, seed=7102, spread=0.42, forks=5),
    "dead_tree_c": dict(height=18.0, seed=7103, spread=0.28, forks=4),
}


def _add_segment(bm, start, end, radius0, radius1, sides=6):
    direction = end - start
    length = direction.length
    if length < 0.02:
        return
    before = set(bm.verts)
    result = bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=sides,
        radius1=max(radius0, 0.005), radius2=max(radius1, 0.003), depth=length,
    )
    verts = [v for v in result["verts"] if v not in before]
    quat = Vector((0.0, 0.0, 1.0)).rotation_difference(direction.normalized())
    mat = Matrix.Translation((start + end) * 0.5) @ quat.to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=mat, verts=verts)


def _branch(bm, rng, start, direction, length, radius, depth, spread):
    end = start + direction.normalized() * length
    _add_segment(bm, start, end, radius, radius * 0.62)
    if depth <= 0:
        return
    count = 2 if depth < 2 else rng.choice((2, 2, 3))
    for i in range(count):
        azimuth = rng.uniform(0.0, math.tau)
        cone = math.radians(rng.uniform(26.0, 54.0))
        side = Vector((math.cos(azimuth), math.sin(azimuth), 0.0))
        new_dir = (direction.normalized() * math.cos(cone) + side * math.sin(cone))
        # Ветви слегка тянутся вверх: силуэт читается как дерево, а не как куст.
        new_dir.z += rng.uniform(0.08, 0.28)
        new_dir.normalize()
        fork = start.lerp(end, rng.uniform(0.42, 0.82))
        _branch(bm, rng, fork, new_dir,
                length * rng.uniform(0.34, 0.58) * (1.0 - depth * 0.08),
                radius * rng.uniform(0.45, 0.68), depth - 1, spread)


def _build(name, spec):
    rng = random.Random(spec["seed"])
    height = spec["height"]
    bm = bmesh.new()
    # Корневой ствол: два слегка изломанных сегмента.
    base = Vector((0.0, 0.0, 0.0))
    knot = Vector((rng.uniform(-0.35, 0.35), rng.uniform(-0.35, 0.35), height * 0.42))
    top = knot + Vector((rng.uniform(-0.55, 0.55), rng.uniform(-0.55, 0.55), height * 0.22))
    _add_segment(bm, base, knot, height * 0.045, height * 0.033)
    _add_segment(bm, knot, top, height * 0.033, height * 0.018)
    # Нижние корни-рожки.
    for i in range(5):
        a = math.tau * i / 5.0 + rng.uniform(-0.25, 0.25)
        root_end = Vector((math.cos(a) * rng.uniform(1.0, 2.0),
                           math.sin(a) * rng.uniform(1.0, 2.0),
                           rng.uniform(-0.05, 0.35)))
        _add_segment(bm, base + Vector((0, 0, 0.2)), root_end, 0.18, 0.04)
    # Ветви верхней половины.
    for i in range(spec["forks"]):
        fork = top.lerp(base, rng.uniform(0.08, 0.72))
        a = math.tau * i / spec["forks"] + rng.uniform(-0.4, 0.4)
        outward = Vector((math.cos(a), math.sin(a), rng.uniform(0.12, 0.6))).normalized()
        _branch(bm, rng, fork, outward,
                height * rng.uniform(0.22, 0.36) * (1.0 - i * 0.08),
                height * 0.022 * rng.uniform(0.55, 0.9), 3, spec["spread"])
    # Верхушечные отростки.
    for i in range(3):
        _branch(bm, rng, top, Vector((rng.uniform(-0.7, 0.7),
                                      rng.uniform(-0.7, 0.7), 1.0)).normalized(),
                height * rng.uniform(0.12, 0.22), 0.075, 2, spec["spread"])
    coll = L.asset_collection(name)
    obj = L.object_from_bmesh(name, bm, coll, "nm_bark")
    L.finalize(obj, sharp_deg=54.0, uv_tile=1.4)
    # Тёмный ствол, чтобы силуэт не проваливался в снег.
    mesh = obj.data
    colors = mesh.color_attributes.get("Col")
    if colors is None:
        colors = mesh.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
    for i in range(len(colors.data)):
        colors.data[i].color = (0.34, 0.30, 0.27, 1.0)
    mesh.color_attributes.active_color = colors
    tris = L.tri_count(obj)
    print(f"BUILT {name}: tris={tris} height={height}")
    return coll


def main():
    t0 = time.time()
    L.clear_data()
    for name, spec in VARIANT.items():
        _build(name, spec)
    for name in VARIANT:
        L.export_collection(bpy.data.collections[name], OUT_DIR / f"{name}.glb")
    L.save_blend(SRC / "dead_tree_kit.blend")
    print("DONE", time.time() - t0)


if __name__ == "__main__":
    main()

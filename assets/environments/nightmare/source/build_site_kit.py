"""Партия 6 — ассеты под планировку стоянки каравана (`caravan_site.tscn`, S02–S06).

Запуск из корня проекта (Blender 5.1, в фоне):
    blender -b --factory-startup --python assets/environments/nightmare/source/build_site_kit.py -- [опции]
Опции: --only <группы через запятую>, --test <файл.jpg> (превью без экспорта и сохранения .blend).
Результат: `source/site_kit.blend`, `site/*.glb`, превью `docs/art/previews/nightmare/site_*.jpg`.

Зачем: площадка сцены 12 × 10 м поперёк дороги (стена на востоке, обрыв на западе, дорога с юга
на север), а `camp_platform_a` (партия 2) — 8 × 12 м вдоль дороги. Точки сценария (костёр,
повозка, Bloodbane, фляги, места NPC) двигать нельзя — грунт сделан под них.
- `camp_site_ground` — 12,4 × 10,4 м: мостовая по оси дороги (стык с `road_old_*` на обоих концах)
  и вокруг костра; к западной кромке и к подножию стены плиты редеют и сменяются острыми камнями
  в снегу (CANON гл. 3: «где мощёная дорога заканчивается и начинаются острые камни» — там Bloodbane).
- `bedroll_a` — подстилка солдата: войлок/шкура и скатка (ART-DIRECTION; в сцене были CSG-подстилки).
Оси: Blender (x, y, z) → Godot (x, z, −y); север сцены (−Z Godot) — +Y Blender.
"""

import importlib
import math
import random
import sys
import time
from pathlib import Path

SRC = Path(__file__).resolve().parent
if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import nm_lib as L  # noqa: E402

importlib.reload(L)
import nm_props as P  # noqa: E402

importlib.reload(P)

OUT_DIR = L.NM_DIR / "site"


def rot(deg, axis):
    return Matrix.Rotation(math.radians(deg), 4, axis)


def camp_site_ground():
    name, seed = "camp_site_ground", 6501
    coll = L.asset_collection(name)
    r = random.Random(seed)
    hx, hy = 6.2, 5.2
    road_hw = 1.6
    fire = Vector((0.6, 0.0))  # костёр сцены: Godot (0.6, 0.5) относительно центра площадки (0, 0.5)
    sites = L.poisson_2d(r, -hx, hx, -hy, hy, 0.55, tries=14000)
    cells = L.voronoi_cells(sites, [], (-hx, -hy, hx, hy))
    off = Vector((seed * 0.1, seed * 0.2, 0.0))

    def paved(p):
        """> 0.7 — плита, < 0.5 — острые камни, между — утоптанный снег."""
        band = 1.0 - max(0.0, abs(p.x) - road_hw) / 1.5  # ось дороги — мощёная насквозь
        camp = 1.3 - (p - fire).length / 4.2  # вокруг костра
        west = (p.x + hx) / 1.6  # к кромке обрыва — камни
        east = (hx - p.x) / 1.3  # к подножию стены — камни
        n = 0.35 * L.noise.noise(Vector((p.x * 0.4, p.y * 0.4, 0.0)) + off)
        interior = 0.74 + 1.3 * n  # старое мощение расширения: местами выбито, местами цело
        return min(max(band + n, camp + n, interior), west + 0.1, east + 0.2)

    def edge_zone(p):
        return min((p.x + hx) / 1.6, (hx - p.x) / 1.3) < 1.0

    bm = bmesh.new()
    rough = []
    for site, poly in zip(sites, cells):
        if len(poly) < 3 or abs(L._poly_area(poly)) < 0.02:
            continue
        c = sum(poly, Vector((0, 0))) / len(poly)
        pv = paved(c)
        if pv < 0.7 or r.random() < 0.05:
            if pv < 0.62 and edge_zone(c) and r.random() < 0.92:
                rough.append(c)
            continue
        worn = max(0.0, 1.0 - min(abs(c.x) / 1.4, (c - fire).length / 2.5))
        top = r.uniform(-0.015, 0.025) - 0.012 * worn - (0.04 if r.random() < 0.1 else 0.0)
        tilt = (r.uniform(-0.035, 0.035), r.uniform(-0.035, 0.035))
        poly2 = L.chamfer_poly(L.shrink_poly(poly, r.uniform(0.012, 0.024)), r.uniform(0.015, 0.035))
        ph = r.uniform(0, 100)
        L.slab_from_poly(bm, poly2, top, -0.24, bevel=r.uniform(0.014, 0.03), tilt=tilt, center=c,
                         dome=r.uniform(0.004, 0.012),
                         jitter=lambda p, ph=ph: 0.006 * L.noise.noise(Vector((p.x * 6, p.y * 6, ph))))
    stones = L.object_from_bmesh(name + "_stones", bm, coll, "nm_stone_worked")
    base = L.grid_surface(name + "_base", coll, -hx - 0.2, hx + 0.2, -hy - 0.2, hy + 0.2, 62, 52,
                          lambda x, y: -0.03 + 0.03 * L.noise.noise(Vector((x * 0.5, y * 0.5, 1.0)) + off)
                          + 0.06 * max(0.0, x - hx + 1.2), "nm_snow", z_bottom=-0.5)
    parts = []
    for k, c in enumerate(rough):
        s = r.uniform(0.2, 0.6)
        rb = L.hull_chunk(seed + 100 + k, (s * 1.3, s, s * 1.15), npts=12, cuts=7, cut_depth=(0.45, 0.8))
        parts.append((rb, Matrix.Translation((c.x, c.y, s * 0.22 - 0.05)) @ rot(r.uniform(0, 360), "Z")
                      @ rot(r.uniform(-25, 25), "X")))
    rocks = L.rock_object(name + "_rocks", parts, coll, voxel=0.02, smooth_iter=0, seed=seed, size=0.3,
                          detail=dict(large=0.03, medium=0.012, fine=0.004, crack_depth=0.0), target_tris=9000,
                          sink=0.0)
    zmin = min(v.co.z for v in rocks.data.vertices)
    rocks.data.transform(Matrix.Translation((0, 0, -0.15 - zmin)))
    sbm = bmesh.new()
    for k in range(12):
        x = r.choice((r.uniform(-5.6, -3.0), r.uniform(3.2, 5.6), r.uniform(-3.0, 3.0)))
        y = r.uniform(-hy + 0.5, hy - 0.5)
        if (Vector((x, y)) - fire).length < 1.8:
            continue  # у огня снег стаял
        L.snow_patch(sbm, x, y, r.uniform(0.4, 1.1), r.uniform(0.5, 1.4), r.uniform(0.04, 0.09), z0=0.0,
                     seed=seed + k, angle=r.uniform(0, 3))
    patches = L.object_from_bmesh(name + "_snowpatch", sbm, coll, "nm_snow")
    # Кострище: пятно золы и сажи на плитах (под моделью костра), без снега.
    L.bake_masks(stones, seed=seed, rays=12, ao_dist=0.35, ground=False, extra_occluders=[base, rocks],
                 base_dark=0.0,
                 snow_fn=lambda co: min(1.0, max(0.1, (abs(co.x) - 1.2) / 2.5))
                 * min(1.0, (Vector((co.x, co.y)) - fire).length / 2.2),
                 dirt_fn=lambda co: 0.6 + 0.4 * min(1.0, (Vector((co.x, co.y)) - fire).length / 1.6))
    L.bake_masks(rocks, seed=seed + 1, rays=12, ao_dist=0.4, ground=False, extra_occluders=[base, stones],
                 base_dark=0.15)
    for o in (base, patches):
        L.bake_masks(o, seed=seed + 2, rays=8, ao_dist=0.3, ground=False, extra_occluders=[stones, rocks],
                     base_dark=0.0, tint_var=0.04,
                     dirt_fn=lambda co: 0.8 + 0.2 * min(1.0, (Vector((co.x, co.y)) - fire).length / 3.0))
    obj = L.merge_objects(name, [stones, base, rocks, patches], coll)
    L.finalize(obj, sharp_deg=40, uv_tile=2.0)
    L.collision_box(coll, name, (0, 0, -0.2), (hx * 2, hy * 2, 0.4))
    return [obj]


def bedroll_a():
    """Подстилка солдата: войлок поверх шкуры, скатка в изголовье, ремень."""
    name = "bedroll_a"
    coll = L.asset_collection(name)
    asm = P.Assembly(name, coll)
    felt = P.board(0.66, 1.5, 0.035, bevel=0.012, seed=3, warp=0.02)
    P.deform(felt, lambda co: Vector((co.x, co.y, co.z + 0.012 * math.sin(co.y * 5.1) * math.cos(co.x * 4.0))))
    asm.add(felt, "nm_linen", P.T(0, 0, 0.02))
    hide = P.board(0.78, 1.62, 0.02, bevel=0.015, seed=5, warp=0.03)
    P.deform(hide, lambda co: Vector((co.x * (1.0 + 0.06 * math.sin(co.y * 3.0)), co.y, co.z)))
    asm.add(hide, "nm_leather", P.T(0.02, -0.03, 0.006))
    roll = P.cylinder(0.085, 0.6, segs=14, axis="X")
    asm.add(roll, "nm_linen", P.T(0, 0.66, 0.09))
    strap = P.tube([Vector((0.0, 0.66 + 0.095 * math.sin(t), 0.09 + 0.095 * math.cos(t)))
                    for t in [k * 2 * math.pi / 16 for k in range(16)]], 0.008, segs=5, closed=True)
    asm.add(strap, "nm_leather", P.T(0.16, 0.0, 0.0))
    obj = P.finish_prop(asm.build(), seed=21, ao=0.12, merge_name=name, coll=coll)
    return [obj]


GROUPS = {
    "ground": [camp_site_ground],
    "props": [bedroll_a],
}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = argv[argv.index("--only") + 1].split(",") if "--only" in argv else list(GROUPS)
    test = argv[argv.index("--test") + 1] if "--test" in argv else None
    t0 = time.time()
    L.clear_data()
    colls = []
    for g in only:
        for fn in GROUPS[g]:
            coll = fn()[0].users_collection[0]
            colls.append(coll)
            tris = sum(L.tri_count(o) for o in coll.all_objects
                       if o.type == "MESH" and not o.name.endswith("colonly"))
            print(f"BUILT {coll.name}: tris={tris} t={time.time() - t0:.1f}s", flush=True)
    if not test:
        for coll in colls:
            L.export_collection(coll, OUT_DIR / f"{coll.name}.glb")
    L.set_assets_visible(False)
    gnd = L.ground(size=80.0, z=-0.02)
    L.setup_render(res=(1600, 900), samples=48 if test else 96, sun_elev=24.0, sun_az=-50.0)
    out_dir = Path(test).parent if test else L.PREVIEW_DIR
    prefix = (Path(test).stem + "_") if test else "site_"
    insts, _ = L.lineup(colls, spacing=1.5, axis="X", start=0.0)
    bpy.context.view_layer.update()
    pts = [p for o in insts for p in L.world_points(o)]
    man = L.mannequin(location=(min(p.x for p in pts) + 6.6, min(p.y for p in pts) + 5.6, 0.0))
    for view, tag in (((-0.6, -1.0, 0.75), "overview"), ((-1.0, -0.2, 0.3), "eye")):
        L.frame_camera(insts + [man], direction=view, lens=40, margin=1.05)
        L.render(str(out_dir / f"{prefix}{tag}.jpg"))
    if not test:
        L.save_blend(SRC / "site_kit.blend")
    print("DONE", time.time() - t0)


if __name__ == "__main__":
    main()

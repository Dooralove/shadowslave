"""Партия 6 — фон и границы горных локаций: высокие скальные массивы и средние хребты.

Запуск из корня проекта (Blender 5.1, в фоне):
    blender -b --factory-startup --python assets/environments/nightmare/source/build_backdrop_kit.py -- [опции]
Опции: --only <группы через запятую>, --test <файл.jpg> (превью без экспорта и сохранения .blend).
Результат: `source/backdrop_kit.blend`, `backdrop/*.glb`, превью `docs/art/previews/nightmare/backdrop_*.jpg`.

Зачем (аудит сцен 2026-10-26): модули дороги и стен (12 м) заканчиваются в кадре — над стеной видно
пустое небо, под кромкой обрыва (−8 м) — пустота, за бездной — ничего. Канон (гл. 2): дорога на склоне
одинокой горы, справа отвесная скала, слева бездна; над лагерем — чёрная гора и луна.
- `cliff_face_tall_a/b` — массив 24 м по дороге и ~30 м высотой: продолжение стены над модулями
  `rock_wall_*` и лицо обрыва под `cliff_edge_*` (тот же поворот: лицо смотрит в −X). ART-DIRECTION.
- `ridge_mid_a/b` — средний план (300–800 м): зубчатые отроги по ту сторону бездны и плечи горы
  над стеной; низ уходит под облака. CANON-INFERRED («соседние пики»), форма — ART-DIRECTION.
Дальний план — существующие `black_mountain_far`, `mountain_range_far` (партия 1).
Оси: как в горном наборе — вдоль дороги +Y, лицо стены смотрит в −X, вверх +Z.
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

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import nm_lib as L  # noqa: E402

importlib.reload(L)

I = Matrix.Identity(4)
OUT_DIR = L.NM_DIR / "backdrop"


def rot(deg, axis):
    return Matrix.Rotation(math.radians(deg), 4, axis)


# --------------------------------------------------------------------------------------
# Высокие скальные массивы
# --------------------------------------------------------------------------------------
def _tall_face(name, seed, length=24.0, height=30.0, depth=7.0, sheet=None, buttresses=5, tris=9000):
    coll = L.asset_collection(name)
    r = random.Random(seed)
    sheet = dict(dict(cell=(4.2, 2.4), relief=1.5, tilt=0.5, res=0.28, top_var=3.5, macro=2.4, joints=0.7,
                      y0=-0.8, z0=-1.0), **(sheet or {}))
    parts = [(L.facet_sheet(seed, length + 1.6, height, depth, **sheet), I)]
    # Контрфорсы: крупные выступы ломают плоскость и дают глубокие вертикальные тени на расстоянии.
    for i in range(buttresses):
        d = (r.uniform(3.0, 5.0), r.uniform(3.0, 6.0), r.uniform(7.0, 13.0))
        bm = L.hull_chunk(seed + 70 + i, d, npts=18, cuts=6, cut_depth=(0.8, 0.95))
        y = (i + 0.5) * length / buttresses + r.uniform(-1.2, 1.2)
        z = r.uniform(-1.0, height * 0.55) + d[2] / 2
        parts.append((bm, Matrix.Translation((r.uniform(-1.6, -0.6) + d[0] * 0.3, y, z))
                      @ rot(r.uniform(-10, 10), "Z") @ rot(r.uniform(-4, 4), "Y")))
    # Рваные торцы и бугристый тыл: массив виден и сбоку (поворот дороги, отрог поперёк взгляда),
    # плоский срез листа читался бы коробкой.
    for y_end, sgn in ((-0.8, -1), (length + 0.8, 1)):
        z = -1.0
        while z < height - 2.0:
            h = r.uniform(4.0, 8.0)
            d = (depth * r.uniform(0.75, 1.05), r.uniform(2.5, 4.2), h * 1.25)
            bm = L.hull_chunk(r.randrange(1 << 30), d, npts=16, cuts=6, cut_depth=(0.78, 0.95))
            parts.append((bm, Matrix.Translation((d[0] / 2 + r.uniform(-1.2, 0.4), y_end + sgn * r.uniform(-0.4, 0.9),
                                                  z + h / 2)) @ rot(r.uniform(-12, 12), "Z")))
            z += h * r.uniform(0.7, 0.9)
    for i in range(6):
        d = (r.uniform(3.0, 5.0), r.uniform(4.0, 7.0), r.uniform(6.0, 12.0))
        bm = L.hull_chunk(seed + 200 + i, d, npts=16, cuts=5, cut_depth=(0.8, 0.95))
        parts.append((bm, Matrix.Translation((depth + r.uniform(-1.5, 0.5), (i + 0.5) * length / 6,
                                              r.uniform(0.0, height * 0.6) + d[2] / 2))))
    obj = L.rock_object(name, parts, coll, voxel=0.2, smooth_iter=1, seed=seed, size=6.0,
                        detail=dict(large=0.02, medium=0.014, fine=0.004, crack_depth=0.012,
                                    strata=(1.0, 1.0, 0.5), crack_scale=1.2),
                        target_tris=tris * 3, sink=0.0)
    L.decimate(obj, tris)
    L.bake_masks(obj, seed=seed, rays=16, ao_dist=6.0, ground=False, base_dark=0.0, snow_scale=0.35)
    L.finalize(obj, sharp_deg=55, uv_tile=8.0)
    L.collision_trimesh(obj, target_tris=400)
    return [obj]


def cliff_face_tall_a():
    """Массив 24 × ~30 м: крупные грани раскола, контрфорсы, полки под снег."""
    return _tall_face("cliff_face_tall_a", 6301)


def cliff_face_tall_b():
    """Вариант: тонкие пласты с падением, больше вертикальных трещин, ниже (~26 м)."""
    return _tall_face("cliff_face_tall_b", 6302, height=26.0, buttresses=4,
                      sheet=dict(cell=(5.0, 1.2), relief=1.0, tilt=0.65, joints=1.0, macro=2.0))


# --------------------------------------------------------------------------------------
# Средний план: зубчатые отроги
# --------------------------------------------------------------------------------------
def _ridge(name, seed, size_x=420.0, size_y=180.0, peak=150.0, horn=0.0, tris=12000):
    """Отрог: гребень вдоль X, крутой склон к зрителю (−Y), пологий тыл. Низ — до −60 м
    (уходит под слой облаков в сцене)."""
    coll = L.asset_collection(name)
    off = Vector((seed * 0.37 % 50, seed * 0.11 % 50, 4.0))

    def h(x, y):
        along = (x + size_x / 2) / size_x
        crest = peak * (0.55 + 0.45 * L.noise.noise(Vector((along * 3.0, 2.0, 1.0)) + off))
        if horn:
            crest += horn * math.exp(-((along - 0.62) / 0.09) ** 2)
        # Профиль поперёк: гребень на y = 0.15·size_y, перед — крутой, тыл — пологий.
        yc = y / size_y - 0.15
        prof = max(0.0, 1.0 - abs(yc) / (0.45 if yc < 0 else 0.75)) ** (1.5 if yc < 0 else 1.1)
        edge = min(1.0, 4.0 * min(along, 1.0 - along))  # торцы сходят в облака
        p = Vector((x, y, 0)) / 70.0 + off
        rid = L.noise.ridged_multi_fractal(p, 0.85, 2.1, 6, 1.0, 2.0) / 2.2
        jag = 0.25 * L.noise.ridged_multi_fractal(p * 3.0, 0.8, 2.0, 4, 1.0, 2.0) / 2.2
        # Вне гребня поверхность уходит к низу модели (−55 м): плоских «полей» по краям нет,
        # подножие целиком под слоем облаков сцены.
        k = prof * edge
        return crest * k * (0.5 + 0.5 * rid + jag) - 55.0 * (1.0 - k) ** 2

    obj = L.grid_surface(name, coll, -size_x / 2, size_x / 2, -size_y / 2, size_y / 2, 210, 90, h, "nm_rock",
                         z_bottom=-60.0)
    L.decimate(obj, tris)
    L.bake_masks(obj, seed=seed, rays=8, ao_dist=40.0, ground=False, base_dark=0.0, tint_var=0.12,
                 snow_noise=0.5, snow_scale=0.03)
    L.finalize(obj, sharp_deg=60, uv_tile=40.0)
    return [obj]


def ridge_mid_a():
    """Отрог 420 м с гребнем 80–150 м — по ту сторону бездны."""
    return _ridge("ridge_mid_a", 6401)


def ridge_mid_b():
    """Отрог с рогом-вершиной (+90 м) — плечо горы над стеной и за лагерем."""
    return _ridge("ridge_mid_b", 6402, size_x=360.0, peak=120.0, horn=90.0)


GROUPS = {
    "faces": [cliff_face_tall_a, cliff_face_tall_b],
    "ridges": [ridge_mid_a, ridge_mid_b],
}

# Превью: (кадр, ассеты, ось ряда, направление камеры).
SHOTS = [
    ("faces", ["cliff_face_tall_a", "cliff_face_tall_b"], "Y", (-1.0, -0.35, 0.25)),
    ("ridges", ["ridge_mid_a", "ridge_mid_b"], "X", (-0.25, -1.0, 0.32)),
]


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = argv[argv.index("--only") + 1].split(",") if "--only" in argv else list(GROUPS)
    test = argv[argv.index("--test") + 1] if "--test" in argv else None
    t0 = time.time()
    L.clear_data()
    by_name = {}
    for g in only:
        for fn in GROUPS[g]:
            coll = fn()[0].users_collection[0]
            by_name[coll.name] = coll
            tris = sum(L.tri_count(o) for o in coll.all_objects
                       if o.type == "MESH" and not o.name.endswith("colonly"))
            print(f"BUILT {coll.name}: tris={tris} t={time.time() - t0:.1f}s", flush=True)
    if not test:
        for coll in by_name.values():
            L.export_collection(coll, OUT_DIR / f"{coll.name}.glb")
    L.set_assets_visible(False)
    gnd = L.ground(size=2000.0, z=-0.02)
    L.setup_render(res=(1600, 900), samples=48 if test else 96, sun_elev=20.0, sun_az=-55.0)
    out_dir = Path(test).parent if test else L.PREVIEW_DIR
    prefix = (Path(test).stem + "_") if test else "backdrop_"
    jobs = []
    ox = 0.0
    for shot, names, axis, view in SHOTS:
        colls = [by_name[n] for n in names if n in by_name]
        if not colls:
            continue
        insts, _ = L.lineup(colls, spacing=4.0 if shot == "faces" else 40.0, axis=axis, start=0.0)
        for inst in insts:
            inst.location.x += ox
        bpy.context.view_layer.update()
        pts = [p for o in insts for p in L.world_points(o)]
        man = L.mannequin(location=(min(p.x for p in pts) - 1.5, min(p.y for p in pts) + 2.0, 0.0),
                          name=f"ScaleRef_{shot}")
        jobs.append((shot, insts, man, view))
        ox = max(p.x for p in pts) + 600.0
    allp = list(L.preview_collection().objects)
    for shot, insts, man, view in jobs:
        keep = set(insts) | {man, gnd}
        for o in allp:
            if o.type in ("EMPTY", "MESH"):
                o.hide_render = o not in keep
        pts = [p for o in insts for p in L.world_points(o)]
        gnd.location = ((min(p.x for p in pts) + max(p.x for p in pts)) / 2,
                        (min(p.y for p in pts) + max(p.y for p in pts)) / 2, -0.02)
        cam = L.frame_camera(insts + [man], direction=view, lens=40, margin=1.06)
        cam.data.clip_end = 5000.0
        L.render(str(out_dir / f"{prefix}{shot}.jpg"))
    for o in allp:
        o.hide_render = False
    if not test:
        L.save_blend(SRC / "backdrop_kit.blend")
    print("DONE", time.time() - t0)


if __name__ == "__main__":
    main()

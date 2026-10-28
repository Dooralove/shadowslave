"""Партия 6 — рельеф и укрытия под планировку тропы паломников (`pilgrim_path.tscn`, S07–S12).

Запуск из корня проекта (Blender 5.1, в фоне):
    blender -b --factory-startup --python assets/environments/nightmare/source/build_path_kit.py -- [опции]
Опции: --only <группы через запятую>, --test <файл.jpg> (превью без экспорта и сохранения .blend).
Результат: `source/path_kit.blend`, `path/*.glb`, превью `docs/art/previews/nightmare/path_*.jpg`.

Зачем (аудит 2026-10-26): точки сценария тропы (высоты площадок 0 / 1,6 / 3,4 / 3,8 / 4,1 м, места
NPC в алькове, у Героя, у ступеней) зашиты в код и тесты; модули партии 4 рассчитаны на ровную полку.
- `pp_switchback` — массив серпантина у провала: полотно дороги до излома, яма провала, рампа на восток,
  площадка с камнем для меча, рампа на запад, площадка над провалом, начало полки тропы. Верх площадок
  и рамп совпадает с отметками сцены (±3 см), между рампами — скальная ступень, к востоку — склон горы,
  к западу — обрыв. CANON (гл. 9): дорога уничтожена камнепадом, подъём по старой тропе; форма — ART-DIRECTION.
- `pp_summit` — плоская вершина под снегом ~30 × 26 м (CANON гл. 14: «обширная плоская скала»; размер —
  STAGING спецификации S12), края уходят в обрыв.
- `cave_crevice_wide` — вариант `cave_crevice` с проходимой щелью (у пола 1,15 м, кверху 0,85 м):
  капсула Санни (радиус 0,35 м) не проходила 0,7–0,9-метровую щель и застревала после побега из пещеры.
  Пещера, свод и «нет второго выхода» — как у оригинала (CANON гл. 12–13).
Оси: Blender (x, y, z) → Godot (x, z, −y). Функции высот записаны в координатах Godot.
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
import build_trail_kit as TK  # noqa: E402

importlib.reload(TK)

OUT_DIR = L.NM_DIR / "path"
T = TK.T
rot = TK.rot


def _smooth(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


class Region:
    """Проходимая площадка: прямоугольник в плоскости XZ Godot и функция высоты верха."""

    def __init__(self, x0, x1, z0, z1, h, rough=0.0):
        self.x0, self.x1, self.z0, self.z1 = min(x0, x1), max(x0, x1), min(z0, z1), max(z0, z1)
        self.h = h if callable(h) else (lambda x, z, v=h: v)
        self.rough = rough

    def dist(self, x, z):
        dx = max(self.x0 - x, 0.0, x - self.x1)
        dz = max(self.z0 - z, 0.0, z - self.z1)
        return math.hypot(dx, dz)

    def nearest(self, x, z):
        return min(max(x, self.x0), self.x1), min(max(z, self.z0), self.z1)


def _terrain(name, coll, xg0, xg1, zg0, zg1, res, regions, base, seed, tris, up_w=0.7, down_w=0.35,
             noise_amp=0.35, rock_amp=0.9):
    """Высотное поле: на площадках — их верх, у краёв — крутой переход к базовому склону `base`
    (выше — стена, ниже — обрыв), вне площадок — склон с шумом."""
    off = Vector((seed * 0.13, seed * 0.07, 2.0))

    def hg(x, z):
        best, bd = None, 1e9
        for r in regions:
            d = r.dist(x, z)
            if d < bd:
                best, bd = r, d
        nx, nz = best.nearest(x, z)
        top = best.h(nx, nz)
        b = base(x, z) + noise_amp * L.fbm(Vector((x * 0.35, z * 0.35, 0.0)) + off, 3)
        if bd <= 0.0:
            return top + best.rough * L.noise.noise(Vector((x * 1.7, z * 1.7, 5.0)) + off)
        if b >= top:
            k = _smooth(bd / up_w)
            return top + (b - top) * k
        k = _smooth(bd / down_w)
        return top + (b - top) * k

    nx = int((xg1 - xg0) / res)
    ny = int((zg1 - zg0) / res)
    # Blender: x = x, y = −z Godot.
    obj = L.grid_surface(name, coll, xg0, xg1, -zg1, -zg0, nx, ny, lambda x, y: hg(x, -y), "nm_rock",
                         z_bottom=-24.0)
    # Равномерная сетка (крутые стенки высотного поля иначе — одна вытянутая полоса) и скальный рельеф
    # только на крутом: ровные площадки остаются ровными.
    L.voxel_remesh(obj, 0.15)

    def rocky(co, n):
        steep = max(0.0, 1.0 - abs(n.z)) ** 0.8
        if steep < 0.02:
            return 0.0
        p = co * 0.45 + off
        rid = L.noise.ridged_multi_fractal(p, 0.9, 2.1, 4, 1.0, 2.0) / 2.2
        return steep * (rock_amp * (rid - 0.45) - 0.12 * L.crack(co * 0.6 + off, 0.12))

    L.displace(obj, rocky)
    L.decimate(obj, tris)
    TK._fix_folds(obj)
    return obj, hg


def _finish_terrain(obj, seed, walk_regions, col_tris, snow_noise=0.35, snow_scale=0.6):
    """Маски: снег на пологом (площадки — утоптанный снег, середина рамп — меньше снега)."""

    def snow(co):
        x, z = co.x, -co.y
        on = any(r.dist(x, z) < 0.05 for r in walk_regions)
        return 0.75 if on else 1.0

    L.bake_masks(obj, seed=seed, rays=14, ao_dist=2.5, ground=False, base_dark=0.0, snow_fn=snow, tint_var=0.08,
                 snow_noise=snow_noise, snow_scale=snow_scale)
    L.finalize(obj, sharp_deg=50, uv_tile=4.0)
    L.collision_trimesh(obj, target_tris=col_tris)
    return obj


def pp_switchback():
    name, seed = "pp_switchback", 7101
    coll = L.asset_collection(name)
    # Области не перекрываются: на стыках высоты совпадают (иначе ступень, в которую упирается капсула).
    regions = [
        Region(-2.6, 1.3, -4.2, -1.0, -0.3),  # под модулями дороги и излома (их полотно сверху)
        Region(1.3, 6.2, -6.0, -3.0, lambda x, z: 1.62 * (x - 1.3) / 4.9, rough=0.02),  # рампа на восток, от полотна
        Region(6.2, 8.2, -11.5, -3.0, 1.62, rough=0.02),  # площадка с камнем для меча
        Region(1.0, 6.2, -10.5, -7.5, lambda x, z: 3.4 - 1.78 * (x - 1.0) / 5.2, rough=0.02),  # рампа на запад
        # Площадка над провалом; к северу плавно поднимается на 0,4 м к полке тропы (без ступени).
        Region(-1.0, 3.0, -18.2, -10.5, lambda x, z: 3.4 + 0.4 * min(1.0, max(0.0, (-13.5 - z) / 4.7)), rough=0.02),
        Region(-0.5, 2.5, -21.0, -18.2, 3.55),  # под первым модулем полки тропы
        Region(-3.0, 0.0, -8.8, -4.4, -4.6, rough=0.25),  # дно провала (завал)
    ]

    def base(x, z):
        b = -6.0 + 0.7 * (x + 4.0) + 0.35 * (-z)
        if x < -1.5:
            b -= 3.0 * (-1.5 - x) ** 1.2  # к западу — обрыв в бездну
        return max(-24.0, min(b, 14.0))

    # Поле шире площадок: западный склон успевает уйти под облака, вертикальной «юбки» сетки не видно.
    obj, _ = _terrain(name, coll, -12.0, 10.5, -21.0, -0.5, 0.2, regions, base, seed, 18000)
    walk = regions[1:6]
    _finish_terrain(obj, seed, walk, 3500)
    return [obj]


def pp_summit():
    name, seed = "pp_summit", 7201
    coll = L.asset_collection(name)
    cx, cz = 1.0, -80.0
    rng = random.Random(seed)

    class Blob(Region):
        """Плато неправильной формы: эллипс с шумным краем."""

        def __init__(self):
            super().__init__(cx - 15, cx + 15, cz - 14, cz + 14, 4.05)

        def dist(self, x, z):
            a = math.atan2(z - cz, x - cx)
            r = 1.0 + 0.12 * math.sin(3 * a + 1.3) + 0.07 * math.sin(7 * a + 0.4)
            e = math.hypot((x - cx) / 15.0, (z - cz) / 13.0) / r
            return max(0.0, (e - 1.0) * 13.0)

        def nearest(self, x, z):
            return x, z

    blob = Blob()
    blob.h = lambda x, z: 4.05 + 0.06 * L.noise.noise(Vector((x * 0.3, z * 0.3, 1.0)))
    approach = Region(-0.6, 2.6, -67.0, -60.0, 4.05)

    def base(x, z):
        return -24.0

    # Край плато — крутой каменистый склон (до ~74°) на 12 м вниз, а не отвесный цилиндр.
    approach.z0, approach.z1 = -67.0, -64.0
    obj, _ = _terrain(name, coll, -27.0, 29.0, -107.0, -64.0, 0.35, [blob, approach], base, seed, 18000,
                      down_w=12.0, noise_amp=0.8)
    _finish_terrain(obj, seed, [], 3000, snow_noise=0.12, snow_scale=0.25)
    return [obj]


def cave_crevice_wide():
    """Как cave_crevice (партия 4), но щель шире (1,15 м у пола, сужение кверху до 0,85 м) и с меньшим
    зигзагом: капсула персонажа радиусом 0,35 м проходит её в обе стороны."""
    name, seed = "cave_crevice_wide", 2801
    coll = L.asset_collection(name)
    r = random.Random(seed)
    parts = [(L.facet_sheet(seed, 11.0, 7.0, 10.0, cell=(1.8, 1.1), relief=0.5, tilt=0.4, joints=0.4, z0=-0.6),
              TK.I)]
    for sy in (-1, 1):  # высокие камни, между которыми прячется вход
        parts.append((L.hull_chunk(seed + 5 + sy, (1.8, 1.6, 4.8), npts=16, cuts=6, cut_depth=(0.75, 0.95)),
                      T(-0.9, 5.0 + sy * 1.3, 1.8) @ rot(r.uniform(-8, 8), "Y")))
    path = [Vector((-1.9, 5.0)), Vector((-0.4, 5.0)), Vector((1.2, 5.25)), Vector((2.7, 4.85)), Vector((4.1, 5.15)),
            Vector((5.4, 5.05))]
    cavity = []
    for k in range(len(path) - 1):
        a, b = path[k], path[k + 1]
        ang = math.degrees(math.atan2(b.y - a.y, b.x - a.x))
        for t in (0.0, 0.5, 1.0):
            p = a.lerp(b, t)
            bm = TK._box_bm(1.0, 1.15, 2.7)
            for v in bm.verts:
                if v.co.z > 0:
                    v.co.y *= 0.74
            bm.transform(T(p.x, p.y, 1.3) @ rot(ang, "Z") @ rot(r.uniform(-3, 3), "X"))
            L.cut_base(bm, 0.0, "above")
            cavity.append((bm, TK.I))
    cavity.append(TK._cavity_chunk(seed + 20, (4.6, 5.2, 3.4), T(6.1, 5.0, 0.7)))
    obj = TK._rock(name, parts, coll, seed, 16000, voxel=0.05, cavity=cavity, size=2.0, origin=(-1.0, 5.0, 0))
    TK._check_void(obj, (7.1, 0.0, 1.0))
    TK._check_void(obj, (2.2, 0.0, 1.2))  # щель на середине
    return [TK._finish(obj, seed, ao=2.0, col_tris=4000)]


GROUPS = {
    "terrain": [pp_switchback, pp_summit],
    "cave": [cave_crevice_wide],
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
    L.setup_render(res=(1600, 900), samples=48 if test else 96, sun_elev=26.0, sun_az=-50.0)
    out_dir = Path(test).parent if test else L.PREVIEW_DIR
    prefix = (Path(test).stem + "_") if test else "path_"
    for coll in colls:
        inst = bpy.data.objects.new("PV_" + coll.name, None)
        inst.instance_type = "COLLECTION"
        inst.instance_collection = coll
        L.preview_collection().objects.link(inst)
        bpy.context.view_layer.update()
        others = [o for o in L.preview_collection().objects if o.name.startswith("PV_") and o is not inst]
        for o in others:
            o.hide_render = True
        inst.hide_render = False
        pts = L.world_points(inst)
        c = sum(pts, Vector()) / len(pts)
        man = L.mannequin(location=(c.x, c.y, max(p.z for p in pts) - 0.05 if coll.name != "cave_crevice_wide"
                                    else 0.0), name="ScaleRef_" + coll.name)
        L.frame_camera([inst, man], direction=(-0.7, -1.0, 0.8), lens=35, margin=1.05)
        L.render(str(out_dir / f"{prefix}{coll.name}.jpg"))
        man.hide_render = True
        inst.hide_render = True
    if not test:
        L.save_blend(SRC / "path_kit.blend")
    print("DONE", time.time() - t0)


if __name__ == "__main__":
    main()

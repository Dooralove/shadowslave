"""Партия 4 — разрушенная дорога, склон, старая тропа паломников, укрытия и лёд (S07–S12).

Запуск из корня проекта (Blender 5.1, в фоне):
    blender -b --factory-startup --python assets/environments/nightmare/source/build_trail_kit.py -- [опции]
Опции: --only <группы через запятую>, --test <файл.jpg> (превью без экспорта и сохранения .blend).
Результат: `source/trail_kit.blend`, `trail/*.glb`, превью `docs/art/previews/nightmare/trail_*.jpg`.

Канон (docs/research/first_nightmare/03_ascent_and_climax_canon.md, docs/story/canon_first_nightmare_caravan.md):
гл. 9 — целые участки дороги уничтожены камнепадом, склон «не почти вертикальная стена», но крутой;
старая тропа паломников выше дороги; гл. 10 — естественный альков в стене, «опасно расположенный»
за узким выступом, огонь скрыт скалами; гл. 12 — узкая щель за высокими камнями и маленькая скрытая
пещера без огня (не путать с альковом); гл. 11–14 — узкий каменный карниз тропы над обрывом.
Размеры (ширина тропы, альков 3 × 4 м, щель 0,6–1 м, пещера 3 × 4 м) — STAGING из того же документа.
Оси: вперёд по маршруту +Y, стена справа (+X), обрыв слева (−X), как в горном наборе.
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
from mathutils.bvhtree import BVHTree  # noqa: E402

import nm_lib as L  # noqa: E402

importlib.reload(L)
import build_mountain_kit as MK  # noqa: E402

importlib.reload(MK)

I = Matrix.Identity(4)
OUT_DIR = L.NM_DIR / "trail"
smooth01 = MK._smooth01


def T(x, y, z):
    return Matrix.Translation((x, y, z))


def rot(deg, axis):
    return Matrix.Rotation(math.radians(deg), 4, axis)


def _box_bm(sx, sy, sz):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bm.transform(Matrix.Diagonal((sx, sy, sz, 1.0)))
    return bm


def _carve(obj, cavity_parts, voxel=0.05):
    """Вычесть полость (куски, слитые вокселями и сглаженные) из уже слитого массива."""
    cav = L.object_from_bmesh("_cavity", L.join_bmeshes(cavity_parts), obj.users_collection[0])
    L.voxel_remesh(cav, voxel)
    L.smooth(cav, 0.5, 3)
    mod = obj.modifiers.new("Carve", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    solvers = [i.identifier for i in bpy.types.BooleanModifier.bl_rna.properties["solver"].enum_items]
    mod.solver = "MANIFOLD" if "MANIFOLD" in solvers else "EXACT"  # оба меша замкнуты вокселями
    mod.object = cav
    L.apply_modifiers(obj)
    if not obj.data.polygons:
        raise RuntimeError(f"{obj.name}: булево вычитание полости дало пустой меш")
    mesh = cav.data
    bpy.data.objects.remove(cav)
    bpy.data.meshes.remove(mesh)
    return obj


def _rock(name, parts, coll, seed, tris, voxel=0.05, cavity=None, size=2.0, origin=(0, 0, 0)):
    """Скальный массив из кусков (лист граней + глыбы): воксели, полость, выветривание."""
    obj = L.object_from_bmesh(name, L.join_bmeshes(parts), coll, "nm_rock")
    L.voxel_remesh(obj, voxel)
    L.smooth(obj, 0.5, 1)
    if cavity:
        _carve(obj, cavity, voxel)
        L.voxel_remesh(obj, voxel)
    L.rock_detail(obj, seed, size, large=0.012, medium=0.01, fine=0.004, crack_depth=0.012,
                  strata=(1.0, 1.0, 0.5), crack_scale=1.2)
    L.decimate(obj, tris)
    _fix_folds(obj)
    obj.data.transform(T(-origin[0], -origin[1], -origin[2]))
    return obj


def _fix_folds(obj, passes=3):
    """Сильное прореживание (×40) оставляет единичные вывернутые треугольники-«щепки» — в превью они
    светятся белым. Схлопываем у каждой её кратчайшее ребро."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    total = 0
    for _ in range(passes):
        bm.normal_update()
        bad = set()
        for f in bm.faces:
            nb = [g for e in f.edges for g in e.link_faces if g is not f]
            if nb and sum(f.normal.dot(g.normal) for g in nb) / len(nb) < -0.3:
                bad.add(min(f.edges, key=lambda e: e.calc_length()))
        if not bad:
            break
        total += len(bad)
        bmesh.ops.collapse(bm, edges=[e for e in bad if e.is_valid], uvs=False)
        bmesh.ops.dissolve_degenerate(bm, dist=1e-5, edges=list(bm.edges))
    bm.to_mesh(obj.data)
    bm.free()
    if total:
        print(f"FOLDS {obj.name}: collapsed {total}")


def _check_void(obj, p):
    """Полость на месте: из точки p луч вниз упирается в пол (z ≈ 0), вверх — в свод ниже 3 м."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    down = tree.ray_cast(Vector(p), Vector((0, 0, -1)), 10.0)[0]
    up = tree.ray_cast(Vector(p), Vector((0, 0, 1)), 10.0)[0]
    if down is None or up is None or down.z < -0.3 or up.z > 3.0:
        raise RuntimeError(f"{obj.name}: полость в {p} не найдена (пол {down}, свод {up})")
    print(f"VOID {obj.name}: floor {down.z:.2f} ceiling {up.z:.2f}")


def _wall_drift(coll, name, rock, x0, x1, y0, y1, floor_fn, seed, depth=0.22, reach=0.7, gap=None):
    """Снежный вал у подножия стены (+X): расстояние до стены — лучом по каждому ряду сетки,
    поэтому вал прижат к реальному рельефу лица, а не к прямой линии. gap(y) → 0..1 гасит вал
    (утоптанный вход)."""
    bm = bmesh.new()
    bm.from_mesh(rock.data)
    bm.transform(rock.matrix_world)
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    off = Vector((seed * 0.7, seed * 0.3, 0.0))
    wall = {}

    def wall_x(y):
        key = round(y, 4)
        if key not in wall:
            z = floor_fn(y) + 0.14
            hit = tree.ray_cast(Vector((x0 - 0.6, y, z)), Vector((1, 0, 0)), (x1 - x0) + 4.0)
            wall[key] = hit[0].x if hit[0] is not None else x1 + 2.0
        return wall[key]

    def h(x, y):
        d = wall_x(y) - x
        t = 1.0 - smooth01(d / reach)
        amp = depth * (0.7 + 0.3 * L.noise.noise(Vector((y * 0.9, 0.0, 1.0)) + off))
        if gap:
            amp *= gap(y)
        return floor_fn(y) - 0.03 + amp * t ** 1.4

    nx = max(4, int((x1 - x0) / 0.1))
    ny = max(4, int((y1 - y0) / 0.12))
    obj = L.grid_surface(name, coll, x0, x1, y0, y1, nx, ny, h, "nm_snow", z_bottom=-0.06)
    L.smooth(obj, 0.4, 1)
    return obj


def _finish(obj, seed, ao=2.0, snow_fn=None, col_tris=600, extra=()):
    """Маски (AO, снег) массива и валов, слияние, затенение, коллизия по прореженной копии."""
    L.bake_masks(obj, seed=seed, rays=18, ao_dist=ao, ground=False, base_dark=0.0, snow_fn=snow_fn,
                 extra_occluders=list(extra))
    for o in extra:
        L.bake_masks(o, seed=seed + 1, rays=10, ao_dist=0.6, ground=False, base_dark=0.0, tint_var=0.04,
                     extra_occluders=[obj])
    name, coll = obj.name, obj.users_collection[0]
    merged = L.merge_objects(name, [obj] + list(extra), coll) if extra else obj
    L.finalize(merged, sharp_deg=52, uv_tile=3.0)
    L.collision_trimesh(merged, target_tris=col_tris)
    return merged


# --------------------------------------------------------------------------------------
# Разрушенная дорога (L08)
# --------------------------------------------------------------------------------------
def road_old_broken_end():
    """Конец уцелевшей дороги перед провалом (CANON гл. 9): плиты обрываются по рваной линии,
    осевшие плиты у излома наклонены в провал, под изломом — скальная грань до −4 м.
    Стыкуется с road_old_* началом (y = 0); после y ≈ 2,6 м — пустота."""
    return MK._road("road_old_broken_end", 2301, cracked=0.4, missing=0.12, break_y=2.6)


# --------------------------------------------------------------------------------------
# Крутой склон (L08): CANON — «не почти вертикальная стена, но крутой уклон»
# --------------------------------------------------------------------------------------
def _slope(name, seed, angle, terrace=1.1, width=6.0, length=7.0, boulders=5):
    """Склон-модуль: уклон angle по +Y, ступенчатые полки (на них снег), ячейки-плиты
    коренной породы и вросшие глыбы. Концы сведены к плоскости уклона — модули стыкуются."""
    coll = L.asset_collection(name)
    r = random.Random(seed)
    k = math.tan(math.radians(angle))
    off = Vector((seed * 0.13, seed * 0.29, 0.0))
    cache = {}

    def cell(x, y):
        _, pts = L.noise.voronoi(Vector((x / 1.6, y / 1.1, 0.0)) + off, distance_metric="DISTANCE")
        key = (round(pts[0].x, 3), round(pts[0].y, 3))
        if key not in cache:
            rr = random.Random(hash(key) ^ seed)
            cache[key] = (rr.uniform(-0.22, 0.22), rr.uniform(-0.2, 0.2))
        return cache[key]

    def h(x, y):
        base = y * k
        # Пласты падают поперёк склона и волнятся: полки идут наискось, а не ступенями лестницы.
        t = (base + 0.2 * x) / terrace + 0.35 * L.fbm(Vector((x * 0.35, y * 0.15, 5.0)) + off, 2)
        step = terrace * (math.floor(t) + smooth01((t - math.floor(t) - 0.45) / 0.55)) - 0.2 * x             - 0.35 * terrace * L.fbm(Vector((x * 0.35, y * 0.15, 5.0)) + off, 2)
        z = 0.62 * base + 0.38 * step
        o, g = cell(x, y)
        z += o + g * 0.3 * x
        z += 0.25 * L.fbm(Vector((x * 0.3, y * 0.3, 2.0)) + off, 2)
        edge = smooth01(min(y, length - y) / 0.8)
        return base + (z - base) * edge

    nx, ny = int(width / 0.12), int(length / 0.12)
    bm = bmesh.new()
    top = [[bm.verts.new((-width / 2 + width * i / nx, length * j / ny, h(-width / 2 + width * i / nx, length * j / ny)))
            for j in range(ny + 1)] for i in range(nx + 1)]
    for i in range(nx):
        for j in range(ny):
            bm.faces.new((top[i][j], top[i + 1][j], top[i + 1][j + 1], top[i][j + 1]))
    ring = [top[i][0] for i in range(nx + 1)] + [top[nx][j] for j in range(1, ny + 1)] + \
           [top[i][ny] for i in range(nx - 1, -1, -1)] + [top[0][j] for j in range(ny - 1, 0, -1)]
    bot = [bm.verts.new((v.co.x, v.co.y, -1.5)) for v in ring]
    n = len(ring)
    for q in range(n):
        bm.faces.new((ring[q], bot[q], bot[(q + 1) % n], ring[(q + 1) % n]))
    bm.faces.new(bot)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    parts = [(bm, I)]
    for q in range(boulders):
        s = r.uniform(0.5, 1.2)
        y = r.uniform(1.0, length - 1.0)
        x = r.uniform(-width / 2 + 0.7, width / 2 - 0.7)
        parts.append((L.hull_chunk(seed + 30 + q, (s * 1.4, s, s * 0.8), npts=16, cuts=6),
                      T(x, y, h(x, y) + s * 0.12) @ rot(r.uniform(0, 360), "Z") @ rot(angle * 0.6, "X")))
    obj = _rock(name, parts, coll, seed, 9000, voxel=0.05, size=1.5)
    return [_finish(obj, seed, ao=1.5, col_tris=600)]


def slope_steep_a():
    """Крутой склон ~38° (6 × 7 м, подъём ~5,5 м): уступы-полки под снегом, вросшие глыбы."""
    return _slope("slope_steep_a", 2401, 38.0)


def slope_steep_b():
    """Склон ~30° с частыми уступами — проходимая линия подъёма (бриф: без паркура)."""
    return _slope("slope_steep_b", 2402, 30.0, terrace=0.75, boulders=7)


# --------------------------------------------------------------------------------------
# Старая тропа паломников (L10, L12) и узкий выступ (L09)
# --------------------------------------------------------------------------------------
def _trail(name, seed, length=6.0, width=1.8, steps=None, wall_h=4.5, overhang=0, wall_extra=None, extra_parts=(),
           col_tris=800):
    """Тропа на скальной полке (CANON-INFERRED): справа стена с гранями раскола, пол — полка
    с утоптанной серединой (снега меньше), слева — обрыв до −6 м. Концы с нахлёстом 0,4 м.
    steps = (n, rise) — ступени, высеченные в скале посередине модуля; wall_extra(y, z) — углубление
    лица стены (м, в +X); extra_parts — дополнительные куски массива (выступы, пол ниш)."""
    coll = L.asset_collection(name)
    r = random.Random(seed)
    hw = width / 2
    parts = [(L.facet_sheet(seed, length + 0.8, wall_h + 0.6, 2.5, cell=(1.3, 0.9), relief=0.22, tilt=0.25,
                            joints=0.25, macro=0.3, z0=-0.6, top_var=1.0, extra=wall_extra), T(hw, 0, 0)),
             (L.facet_sheet(seed + 1, length + 0.8, 0.0, width + 0.3, cell=(1.6, 1.1), relief=0.35, tilt=0.5,
                            joints=0.1, macro=0.3, z0=-6.0, top_var=0.03, back_x=width + 0.3), T(-hw - 0.1, 0, 0))]
    run = rise = 0.0
    if steps:
        n, rise = steps
        run = (length - 2.0) / n
        for q in range(n):
            y0 = 1.0 + q * run
            ly = length - y0 + 0.4
            parts.append((_box_bm(width + 0.25, ly, rise * (q + 1) + 0.6), T(0.05, y0 + ly / 2, rise * (q + 1) / 2 - 0.3)))
    for q in range(overhang):
        s = r.uniform(1.0, 1.6)
        parts.append((L.hull_chunk(seed + 70 + q, (s * 1.6, s * 1.4, s), npts=14, cuts=5),
                      T(hw + 0.3 - s * 0.5, r.uniform(1.0, length - 1.0), r.uniform(2.1, 2.8))))
    parts += list(extra_parts)
    obj = _rock(name, parts, coll, seed, 10000, voxel=0.05, size=1.5)

    def floor_z(y):
        if not steps or y <= 1.0:
            return 0.0
        return rise * max(0, min(steps[0], math.floor((y - 1.0) / run) + 1))

    def lane(co):  # утоптанная середина тропы — снега меньше
        return min(1.0, max(0.25, (abs(co.x) - 0.25) / 0.5))

    drift = _wall_drift(coll, name + "_drift", obj, -hw + 0.3, hw + 0.8, -0.4, length + 0.4, floor_z, seed,
                        depth=0.2 if width > 1.2 else 0.12, reach=0.55 if width > 1.2 else 0.35)
    return [_finish(obj, seed, ao=1.8, snow_fn=lane, col_tris=col_tris, extra=[drift])]


def trail_pilgrim_01():
    """Модуль старой тропы 6 м, ширина полки 1,8 м (STAGING 1,5–2 м)."""
    return _trail("trail_pilgrim_01", 2501)


def trail_pilgrim_02_steps():
    """Модуль тропы с пятью ступенями, высеченными в скале: подъём +1,1 м за модуль.
    Кроме треугольной коллизии — пандус по носкам ступеней (ходьба без подскоков)."""
    objs = _trail("trail_pilgrim_02_steps", 2502, steps=(5, 0.22))
    L.collision_profile(objs[0].users_collection[0], "trail_pilgrim_02_steps_ramp",
                        [0.0, 0.2, 4.2, 6.0], [0.0, 0.0, 1.1, 1.1], 1.5)
    return objs


def trail_pilgrim_03_spur():
    """Модуль тропы с каменным выступом-«плавником» (CANON гл. 12, E3.5: Герой утаскивает Учёного вниз по тропе и
    оставляет за скальным выступом): выступ из стены перекрывает две трети полки (проход 0,6 м у обрыва), за ним —
    вниз по тропе — карман в стене 1,5 × 1 м, не видный с тропы выше выступа. Тело не показывается: карман только
    прячет место. Тропа идёт в +Y (вверх по маршруту), карман — между y = 0,6 и 2,1."""
    seed = 2503
    r = random.Random(seed)

    def pocket(y, z):  # углубление лица стены за выступом, ниже 2,2 м, мягкие края
        wy = smooth01((y - 0.5) / 0.35) * (1 - smooth01((y - 1.9) / 0.35))
        wz = 1 - smooth01((z - 1.7) / 0.6)
        return 1.0 * wy * wz

    spur = []
    for k, (dx, y, z, sx, sy, sz) in enumerate(((0.45, 2.75, 1.0, 1.7, 1.05, 2.4), (0.6, 2.7, 2.5, 1.4, 0.95, 1.9),
                                                (0.85, 2.75, 3.6, 1.05, 0.85, 1.6))):
        spur.append((L.hull_chunk(seed + 80 + k, (sx, sy, sz), npts=18, cuts=6, cut_depth=(0.75, 0.95)),
                     T(dx, y, z) @ rot(r.uniform(-8, 8), "Z") @ rot(r.uniform(-5, 5), "X")))
    spur.append((_box_bm(1.4, 1.9, 0.6), T(1.55, 1.35, -0.3)))  # пол кармана
    return _trail("trail_pilgrim_03_spur", seed, wall_extra=pocket, extra_parts=spur, col_tris=1000)


def ledge_narrow():
    """Узкий выступ ~1 м над обрывом под нависающими глыбами (CANON гл. 10: альков «опасно
    расположен за узким выступом»). Ставится перед alcove_shelter."""
    return _trail("ledge_narrow", 2601, length=5.0, width=1.0, overhang=3)


# --------------------------------------------------------------------------------------
# Укрытия: альков (L09) и щель с пещерой (L11)
# --------------------------------------------------------------------------------------
def _cavity_chunk(seed, dims, m, z_floor=0.0):
    bm = L.hull_chunk(seed, dims, npts=40, cuts=4, cut_depth=(0.75, 0.95))
    bm.transform(m)
    L.cut_base(bm, z_floor, "above")
    return (bm, I)


def alcove_shelter():
    """Естественный альков (CANON гл. 10): ниша ~3 × 4 м, высотой 2–2,5 м, вход ~2 м с полки
    шириной ~1,3 м над обрывом; внутри места на четверых и костёр, огонь скрыт скалами,
    снаружи — вид вниз. Начало — середина входа на полке; ниша уходит в +X."""
    name, seed = "alcove_shelter", 2701
    coll = L.asset_collection(name)
    r = random.Random(seed)
    parts = [(L.facet_sheet(seed, 9.0, 6.5, 6.0, cell=(1.6, 1.0), relief=0.45, tilt=0.4, joints=0.35, z0=-0.6), I),
             (L.facet_sheet(seed + 1, 9.0, 0.0, 1.7, cell=(1.6, 1.1), relief=0.35, tilt=0.5, joints=0.1, z0=-6.0,
                            top_var=0.03,
                            back_x=1.7), T(-1.35, 0, 0))]
    # Глыбы-контрфорсы по бокам входа: прячут нишу и отсвет огня от взгляда вдоль стены.
    for k, (y, h) in enumerate(((1.4, 3.4), (6.9, 2.8), (7.9, 4.2))):
        d = (r.uniform(1.4, 1.9), r.uniform(1.2, 1.7), h)
        parts.append((L.hull_chunk(seed + 40 + k, d, npts=16, cuts=5, cut_depth=(0.8, 0.96)),
                      T(0.1, y, h / 2 - 0.3) @ rot(r.uniform(-12, 12), "Z")))
    cavity = [_cavity_chunk(seed + 10, (4.2, 5.0, 3.6), T(2.6, 4.1, 0.75)),
              _cavity_chunk(seed + 11, (3.0, 2.6, 3.2), T(0.2, 4.1, 0.6)),
              _cavity_chunk(seed + 12, (1.8, 2.6, 2.8), T(3.4, 5.4, 0.55))]
    obj = _rock(name, parts, coll, seed, 14000, voxel=0.05, cavity=cavity, size=2.0, origin=(0, 4.1, 0))
    _check_void(obj, (2.4, 0.0, 1.0))

    def gap(y):  # утоптанный вход без вала
        return smooth01((abs(y) - 0.7) / 0.6)

    drift = _wall_drift(coll, name + "_drift", obj, -0.9, 0.9, -4.3, 4.3, lambda y: 0.0, seed,
                        depth=0.24, reach=0.6, gap=gap)
    return [_finish(obj, seed, ao=2.0, col_tris=3000, extra=[drift])]


def cave_crevice():
    """Узкая щель за высокими камнями (0,7–0,9 м) ведёт в маленькую скрытую пещеру ~3 × 4 м,
    высотой ~2,1 м, без второго выхода (CANON гл. 12–13). Начало — устье щели на земле."""
    name, seed = "cave_crevice", 2801
    coll = L.asset_collection(name)
    r = random.Random(seed)
    parts = [(L.facet_sheet(seed, 11.0, 7.0, 10.0, cell=(1.8, 1.1), relief=0.5, tilt=0.4, joints=0.4, z0=-0.6), I)]
    for sy in (-1, 1):  # высокие камни, между которыми прячется вход
        parts.append((L.hull_chunk(seed + 5 + sy, (1.8, 1.6, 4.8), npts=16, cuts=6, cut_depth=(0.75, 0.95)),
                      T(-0.9, 5.0 + sy * 1.15, 1.8) @ rot(r.uniform(-8, 8), "Y")))
    # Щель должна входить в пещеру: замкнутая пустота заросла бы при повторной вокселизации.
    path = [Vector((-1.9, 5.0)), Vector((-0.4, 5.0)), Vector((1.2, 5.45)), Vector((2.7, 4.75)), Vector((4.1, 5.25)),
            Vector((5.4, 5.1))]
    cavity = []
    for k in range(len(path) - 1):
        a, b = path[k], path[k + 1]
        ang = math.degrees(math.atan2(b.y - a.y, b.x - a.x))
        for t in (0.0, 0.5, 1.0):
            p = a.lerp(b, t)
            bm = _box_bm(1.0, 0.9, 2.7)
            for v in bm.verts:  # сужение кверху — щель, а не коридор
                if v.co.z > 0:
                    v.co.y *= 0.6
            bm.transform(T(p.x, p.y, 1.3) @ rot(ang, "Z") @ rot(r.uniform(-4, 4), "X"))
            L.cut_base(bm, 0.0, "above")
            cavity.append((bm, I))
    cavity.append(_cavity_chunk(seed + 20, (4.6, 5.2, 3.4), T(6.1, 5.0, 0.7)))
    obj = _rock(name, parts, coll, seed, 16000, voxel=0.05, cavity=cavity, size=2.0, origin=(-1.0, 5.0, 0))
    _check_void(obj, (7.1, 0.0, 1.0))
    return [_finish(obj, seed, ao=2.0, col_tris=4000)]


# --------------------------------------------------------------------------------------
# Лёд (C): наплыв на стене и сосульки под уступом (бриф перевала §4; бриф тропы «ледяной наплыв»)
# --------------------------------------------------------------------------------------
def ice_flow_a():
    """Ледяной наплыв по стене ~1,5 × 2,4 м: из трещины наверху стекают жгуты-натёки, к низу
    они толще и расходятся веером, у основания — бугристый ледяной фартук. Тыл плоский (x = 0):
    ставится вплотную к скале, лицо в −X."""
    name, seed = "ice_flow_a", 2901
    coll = L.asset_collection(name)
    r = random.Random(seed)
    H = 2.4
    parts = []

    def blob(x, y, z, sx, sy, sz):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1.0)
        bm.transform(T(x, y, z) @ Matrix.Diagonal((sx, sy, sz, 1.0)))
        parts.append((bm, I))

    for k in range(8):  # жгуты: первый — от самого верха, остальные начинаются ниже
        y_top = r.uniform(-0.22, 0.22)
        y_bot = y_top * 2.4 + r.uniform(-0.15, 0.15)
        z_top = H if k == 0 else H * r.uniform(0.45, 0.95)
        phase, n = r.uniform(0, 6.3), int(z_top / 0.07)
        for q in range(n + 1):
            z = z_top * (1 - q / n)
            f = 1 - z / H
            y = y_top + (y_bot - y_top) * (1 - z / z_top) ** 1.5 + 0.03 * math.sin(z * 3.0 + phase)
            rad = (0.032 + 0.08 * f ** 1.5) * (1 + 0.25 * math.sin(z * 14.0 + phase)) * r.uniform(0.85, 1.15)
            blob(-rad * 0.3, y, z, rad * 0.9, rad, rad * 1.8)
    for k in range(7):  # фартук у основания
        blob(-r.uniform(0.05, 0.3), r.uniform(-0.6, 0.6), 0.0, r.uniform(0.18, 0.3), r.uniform(0.22, 0.38),
             r.uniform(0.06, 0.11))
    obj = L.object_from_bmesh(name, L.join_bmeshes(parts), coll, "nm_ice")
    L.voxel_remesh(obj, 0.018)
    L.smooth(obj, 0.5, 3)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    res = bmesh.ops.bisect_plane(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces),
                                 plane_co=(0, 0, 0), plane_no=(1, 0, 0), clear_outer=True)
    edges = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
    if edges:
        bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    L.cut_base(bm, 0.0, "above")
    bm.to_mesh(obj.data)
    bm.free()
    off = Vector((seed * 0.3, 0.0, 1.0))
    L.displace(obj, lambda co, n: 0.004 * L.noise.noise(co * 18.0 + off))
    L.decimate(obj, 5000)
    L.plain_masks(obj)
    L.finalize(obj, sharp_deg=80, uv_tile=1.0)
    return [obj]


def _icicle(bm, x, y, length, rad, rng):
    """Сосулька: кольца с наплывами (лёд нарастает волнами), острый кончик внизу, верх — z = 0."""
    segs, rings = 7, 8
    phase = rng.uniform(0, 6.28)
    lean = Vector((rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03)))
    loops = []
    for k in range(rings):
        t = k / rings
        rr = rad * (1 - t) ** 1.25 * (1 + 0.12 * math.sin(t * length * 32 + phase))
        c = Vector((x, y)) + lean * t * length
        loops.append([bm.verts.new((c.x + rr * math.cos(a), c.y + rr * math.sin(a), 0.03 - t * (length + 0.03)))
                      for a in (2 * math.pi * s / segs for s in range(segs))])
    tip_c = Vector((x, y)) + lean * length
    tip = bm.verts.new((tip_c.x, tip_c.y, -length))
    for k in range(rings - 1):
        for s in range(segs):
            a, b = loops[k][s], loops[k][(s + 1) % segs]
            bm.faces.new((a, loops[k + 1][s], loops[k + 1][(s + 1) % segs], b))
    for s in range(segs):
        bm.faces.new((loops[-1][s], tip, loops[-1][(s + 1) % segs]))
    bm.faces.new(list(reversed(loops[0])))


def icicles_b():
    """Гроздь сосулек 1,4 м под уступом/кромкой: ледяной гребень и 20 сосулек 0,1–0,9 м.
    Начало — верх гребня (крепится к нижней грани уступа)."""
    name, seed = "icicles_b", 2902
    coll = L.asset_collection(name)
    r = random.Random(seed)
    bm = bmesh.new()
    for k in range(20):
        y = -0.66 + 1.32 * (k + r.uniform(-0.35, 0.35)) / 19
        ln = r.uniform(0.1, 0.9) * (1 - 0.45 * abs(y) / 0.7)
        _icicle(bm, r.uniform(-0.04, 0.04), y, ln, r.uniform(0.02, 0.04) * (0.7 + ln), r)
    ridge = bmesh.new()
    bmesh.ops.create_uvsphere(ridge, u_segments=18, v_segments=8, radius=1.0)
    ridge.transform(Matrix.Diagonal((0.08, 0.76, 0.05, 1.0)))
    tmp = bpy.data.meshes.new("_r")
    ridge.to_mesh(tmp)
    ridge.free()
    bm.from_mesh(tmp)
    bpy.data.meshes.remove(tmp)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    obj = L.object_from_bmesh(name, bm, coll, "nm_ice")
    L.plain_masks(obj)
    L.finalize(obj, sharp_deg=70, uv_tile=1.0)
    return [obj]


GROUPS = {
    "road": [road_old_broken_end],
    "slopes": [slope_steep_a, slope_steep_b],
    "trail": [trail_pilgrim_01, trail_pilgrim_02_steps, trail_pilgrim_03_spur, ledge_narrow],
    "shelters": [alcove_shelter, cave_crevice],
    "ice": [ice_flow_a, icicles_b],
}

# Превью: (имя кадра, ассеты, ось ряда, высота подложки, направление камеры).
SHOTS = [
    ("road", ["road_old_broken_end"], "X", -4.4, (-0.85, 1.1, 0.7)),
    ("slopes", ["slope_steep_a", "slope_steep_b"], "X", -0.02, (-0.9, -1.0, 0.6)),
    ("trail", ["trail_pilgrim_01", "trail_pilgrim_02_steps", "trail_pilgrim_03_spur", "ledge_narrow"], "Y", -6.1,
     (-1.0, -0.55, 0.42)),
    ("alcove", ["alcove_shelter"], "X", -6.1, (-1.0, -0.35, 0.3)),
    ("cave", ["cave_crevice"], "X", -0.02, (-1.0, -0.5, 0.45)),
    ("ice", ["ice_flow_a", "icicles_b"], "Y", -0.02, (-1.0, -0.35, 0.12)),
]


def _preview_backing(inst_ice, inst_icicles):
    """Скала-подложка только для превью льда: стенка за наплывом и уступ над сосульками."""
    coll = L.preview_collection()
    out = []
    inst_icicles.location.z = 2.0
    for nm, m in (("PrevWall", T(inst_ice.location.x + 0.5, inst_ice.location.y, 1.4)
                   @ Matrix.Diagonal((1.0, 2.4, 2.8, 1))),
                  ("PrevLedge", T(inst_icicles.location.x + 0.1, inst_icicles.location.y, 2.25)
                   @ Matrix.Diagonal((1.2, 2.0, 0.5, 1)))):
        bm = _box_bm(1, 1, 1)
        bm.transform(m)
        o = L.object_from_bmesh(nm, bm, coll, "nm_rock")
        L.plain_masks(o, (0.8, 0.8, 0.8, 0.0))
        out.append(o)
    return out


def _inside_shot(inst, eye, look, lamp_at, color, energy, path):
    """Кадр изнутри укрытия (камера на высоте глаз, широкий объектив) с одним точечным светом."""
    cam = bpy.data.objects["PreviewCam"]
    cam.data.lens = 16
    b = inst.location
    cam.location = (b.x + eye[0], b.y + eye[1], b.z + eye[2])
    cam.rotation_euler = (math.radians(84), 0, math.atan2(look[1], look[0]) - math.pi / 2)
    bpy.context.scene.camera = cam
    lamp = bpy.data.lights.new("Inner", "POINT")
    lamp.energy = energy
    lamp.color = color
    lamp.shadow_soft_size = 0.3
    lo = bpy.data.objects.new("Inner", lamp)
    L.preview_collection().objects.link(lo)
    lo.location = (b.x + lamp_at[0], b.y + lamp_at[1], b.z + lamp_at[2])
    L.render(path)
    bpy.data.objects.remove(lo)
    bpy.data.lights.remove(lamp)


def _plan_shot(inst, center, size, lamps, path, cut_z=1.5):
    """План сверху с разрезом на высоте cut_z (отсечение камеры): проверка ширины щели, проходимости
    и размеров полости. Свет — точечные лампы внутри (крыша по-прежнему отбрасывает тень)."""
    data = bpy.data.cameras.get("PlanCam") or bpy.data.cameras.new("PlanCam")
    data.type = "ORTHO"
    data.ortho_scale = size
    cam = bpy.data.objects.get("PlanCam") or bpy.data.objects.new("PlanCam", data)
    if cam.name not in L.preview_collection().objects:
        L.preview_collection().objects.link(cam)
    b = inst.location
    cam.location = (b.x + center[0], b.y + center[1], b.z + 40.0)
    cam.rotation_euler = (0.0, 0.0, 0.0)
    data.clip_start = 40.0 - cut_z
    data.clip_end = 60.0
    bpy.context.scene.camera = cam
    added = []
    for x, y, z, energy in lamps:
        lamp = bpy.data.lights.new("PlanLamp", "POINT")
        lamp.energy = energy
        lamp.shadow_soft_size = 0.5
        lo = bpy.data.objects.new("PlanLamp", lamp)
        L.preview_collection().objects.link(lo)
        lo.location = (b.x + x, b.y + y, b.z + z)
        added.append((lo, lamp))
    L.render(path)
    for lo, lamp in added:
        bpy.data.objects.remove(lo)
        bpy.data.lights.remove(lamp)


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
    gnd = L.ground(size=400.0, z=0.0)
    L.setup_render(res=(1600, 900), samples=48 if test else 128, sun_elev=24.0, sun_az=-50.0)
    out_dir = Path(test).parent if test else L.PREVIEW_DIR
    prefix = (Path(test).stem + "_") if test else "trail_"
    jobs = []
    ox = 0.0
    for shot, names, axis, gz, view in SHOTS:
        colls = [by_name[n] for n in names if n in by_name]
        if not colls:
            continue
        insts, _ = L.lineup(colls, spacing=2.0 if axis == "X" else 1.5, axis=axis, start=0.0)
        for inst in insts:
            inst.location.x += ox
        extra = _preview_backing(insts[0], insts[1]) if shot == "ice" and len(insts) == 2 else []
        bpy.context.view_layer.update()
        pts = [p for o in insts for p in L.world_points(o)]
        # Манекен — на полу ассета (дорога, тропа, полка алькова) или рядом на земле.
        if gz < -1.0:
            loc = (insts[0].location.x - (0.6 if shot == "alcove" else 0.0), insts[0].location.y + 1.2, 0.0)
        else:
            loc = (min(p.x for p in pts) - 1.2, min(p.y for p in pts) + 0.8, 0.0)
        man = L.mannequin(location=loc, name=f"ScaleRef_{shot}")
        jobs.append((shot, insts, extra, man, gz, view))
        ox = max(p.x for p in pts) + 60.0
    allp = list(L.preview_collection().objects)
    for shot, insts, extra, man, gz, view in jobs:
        keep = set(insts) | set(extra) | {man, gnd}
        for o in allp:
            if o.type in ("EMPTY", "MESH"):
                o.hide_render = o not in keep
        pts = [p for o in insts for p in L.world_points(o)]
        gnd.location = ((min(p.x for p in pts) + max(p.x for p in pts)) / 2,
                        (min(p.y for p in pts) + max(p.y for p in pts)) / 2, gz)
        L.frame_camera(insts + extra + [man], direction=view, lens=40, margin=1.06)
        L.render(str(out_dir / f"{prefix}{shot}.jpg"))
        spur = next((o for o in insts if o.instance_collection.name == "trail_pilgrim_03_spur"), None)
        if shot == "trail" and spur is not None:
            # С тропы выше выступа (вид вниз по маршруту): карман за выступом не виден.
            b = spur.location
            cam = L.frame_camera([spur], direction=view, lens=40)
            cam.data.lens = 28
            cam.location = (b.x - 0.35, b.y + 5.4, b.z + 1.62)
            cam.rotation_euler = (Vector((b.x + 0.15, b.y + 1.2, b.z + 1.0)) - Vector(cam.location)).to_track_quat(
                "-Z", "Y").to_euler()
            L.render(str(out_dir / f"{prefix}spur_from_above.jpg"))
            _plan_shot(spur, (0.4, 2.8), 6.5, [(1.3, 1.35, 1.0, 60.0), (0.0, 3.0, 2.5, 80.0)],
                       str(out_dir / f"{prefix}spur_plan.jpg"), cut_z=1.5)
        if shot == "alcove":
            # Изнутри: тёплый отсвет костра у дальней стены, наружу — полка и провал.
            _inside_shot(insts[0], (3.6, 0.9, 1.35), (-1.0, -0.25), (2.6, -0.6, 0.45), (1.0, 0.55, 0.25), 120.0,
                         str(out_dir / f"{prefix}alcove_inside.jpg"))
            _plan_shot(insts[0], (1.6, 0.0), 9.0, [(2.4, 0.0, 1.2, 150.0), (0.0, 0.0, 1.2, 60.0)],
                       str(out_dir / f"{prefix}alcove_plan.jpg"))
        if shot == "cave":
            # Из пещеры к щели. Огня в пещере нет (канон); свет здесь — только чтобы видеть форму.
            _inside_shot(insts[0], (8.4, 0.5, 1.4), (-1.0, -0.15), (7.0, -0.6, 1.6), (0.75, 0.85, 1.0), 160.0,
                         str(out_dir / f"{prefix}cave_inside.jpg"))
            _plan_shot(insts[0], (3.4, 0.0), 11.0,
                       [(0.6, 0.0, 1.2, 40.0), (2.8, 0.3, 1.2, 40.0), (4.6, 0.0, 1.2, 40.0), (7.1, 0.0, 1.2, 150.0)],
                       str(out_dir / f"{prefix}cave_plan.jpg"))
    for o in allp:
        o.hide_render = False
    if not test:
        L.save_blend(SRC / "trail_kit.blend")
    print("DONE", time.time() - t0)


if __name__ == "__main__":
    main()

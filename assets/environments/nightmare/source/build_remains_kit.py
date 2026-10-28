"""Партия 2 (кости) — останки людей и чудовищ: видение горы (B14), обочины дороги (S01),
ступени и площадка перед храмом (S12, SHS-03/04).

Запуск из корня проекта (Blender 5.1, в фоне):
    blender -b --factory-startup --python assets/environments/nightmare/source/build_remains_kit.py -- [опции]
Опции — как у build_mountain_kit.py. Результат: `source/remains_kit.blend`, `remains/*.glb`,
превью `docs/art/previews/nightmare/remains_*.jpg`.

Канон: гл. 2 — снег отступает, открывая человеческие кости на старой дороге; гл. 14 — перед храмом
тысячи костей людей и чудовищ, убитых невидимыми стражами. Анатомия упрощена до читаемых форм
(череп, длинные кости, рёбра, позвонки, таз); вид костей чудовищ — ART-DIRECTION (виды не описаны).
Кость не белее снега (бриф тропы, §6) — материал `nm_bone`.
"""

import math
import random
import sys
import time
from pathlib import Path

SRC = Path(__file__).resolve().parent
if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))

import importlib  # noqa: E402

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import nm_lib as L  # noqa: E402

importlib.reload(L)
import nm_props as P  # noqa: E402

importlib.reload(P)

T, rot, I = P.T, P.rot, P.I
OUT_DIR = L.NM_DIR / "remains"


def _ellipsoid(c, r, segs=(16, 10)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs[0], v_segments=segs[1], radius=1.0)
    bm.transform(Matrix.Translation(c) @ Matrix.Diagonal((*r, 1.0)))
    return bm


def _solid(name, parts, coll, voxel, tris, cutters=(), smooth=2, mat="nm_bone", seed=0):
    """Слияние частей вокселями, вычитание полостей (глазницы и т. п.), сглаживание, прореживание."""
    bm = L.join_bmeshes(parts)
    obj = L.object_from_bmesh(name, bm, coll, mat)
    L.voxel_remesh(obj, voxel)
    for k, cbm in enumerate(cutters):
        cut = L.object_from_bmesh(f"_cut{k}", cbm, coll)
        mod = obj.modifiers.new(f"Cut{k}", "BOOLEAN")
        mod.operation = "DIFFERENCE"
        mod.solver = "EXACT"
        mod.object = cut
        L.apply_modifiers(obj)
        bpy.data.objects.remove(cut)
    if smooth:
        L.smooth(obj, 0.5, smooth)
    L.rock_detail(obj, seed, 0.2, large=0.01, medium=0.006, fine=0.003, crack_depth=0.0)
    L.decimate(obj, tris)
    return obj


# --------------------------------------------------------------------------------------
# Отдельные кости (каждая — функция, возвращает объект в локальных осях: длинная ось по Y)
# --------------------------------------------------------------------------------------
def skull(coll, name="skull", seed=0, jaw=True):
    """Череп: свод, лицевой отдел, скулы; глазницы и носовое отверстие вычитаются; челюсть —
    отдельная деталь рядом (у старых останков отпадает)."""
    parts = [(_ellipsoid((0, -0.012, 0.0), (0.072, 0.094, 0.078)), I),
             (_ellipsoid((0, 0.058, -0.03), (0.054, 0.05, 0.058)), I),
             (_ellipsoid((0.052, 0.048, -0.028), (0.018, 0.03, 0.016)), I),
             (_ellipsoid((-0.052, 0.048, -0.028), (0.018, 0.03, 0.016)), I),
             (_ellipsoid((0, 0.075, -0.07), (0.034, 0.024, 0.014)), I),
             (_ellipsoid((0, 0.088, -0.066), (0.033, 0.026, 0.02)), I)]
    # Верхний ряд зубов по дуге альвеолярного края.
    for k in range(10):
        a = math.pi * (0.12 + 0.76 * k / 9)
        tooth = P.cylinder(0.0045, 0.014, segs=6, radius2=0.0035)
        parts.append((tooth, T(0.028 * math.cos(a), 0.072 + 0.032 * math.sin(a), -0.084)))
    cutters = [_ellipsoid((sx * 0.026, 0.095, -0.012), (0.019, 0.03, 0.017), (12, 8)) for sx in (-1, 1)]
    cutters.append(_ellipsoid((0, 0.103, -0.042), (0.009, 0.03, 0.016), (10, 6)))
    cutters.append(_ellipsoid((0, -0.03, -0.085), (0.02, 0.022, 0.02), (10, 6)))  # большое затылочное
    obj = _solid(name, parts, coll, 0.0035, 1200, cutters, seed=seed)
    objs = [obj]
    if jaw:
        path = [Vector((0.045 * math.cos(a), 0.06 + 0.04 * math.sin(a), -0.07)) for a in
                [math.pi * (i / 10) for i in range(11)]]
        bm = P.tube(path, 0.009, segs=6, radius_fn=lambda t: 1.0 + 0.2 * math.sin(math.pi * t))
        for sx in (-1, 1):
            bm2 = _ellipsoid((sx * 0.045, 0.045, -0.05), (0.007, 0.015, 0.024), (8, 6))
            tmp = bpy.data.meshes.new("_j")
            bm2.to_mesh(tmp)
            bm2.free()
            bm.from_mesh(tmp)
            bpy.data.meshes.remove(tmp)
        jaw_obj = _solid(name + "_jaw", [(bm, I)], coll, 0.003, 500, seed=seed + 1)
        objs.append(jaw_obj)
    return objs


def long_bone(coll, name, length, r_shaft, r_end, seed=0, curve=0.02):
    """Длинная кость (бедро, голень, плечо): тонкий ствол, утолщённые суставные концы, изгиб."""
    half = length / 2
    path = [Vector((curve * math.sin(math.pi * t), -half + length * t, 0)) for t in [i / 10 for i in range(11)]]
    shaft = P.tube(path, r_shaft, segs=8, radius_fn=lambda t: 1.0 + 0.8 * (abs(t - 0.5) * 2) ** 4)
    parts = [(shaft, I),
             (_ellipsoid((0.0, half - r_end * 0.6, 0.0), (r_end * 1.25, r_end, r_end * 0.95)), I),
             (_ellipsoid((r_end * 0.6, half - r_end * 0.2, 0.0), (r_end * 0.8, r_end * 0.8, r_end * 0.8)), I),
             (_ellipsoid((0.0, -half + r_end * 0.6, 0.0), (r_end * 1.4, r_end * 0.9, r_end)), I),
             (_ellipsoid((r_end * 0.5, -half + r_end * 0.5, 0.0), (r_end * 0.7, r_end * 0.8, r_end * 0.8)), I)]
    return _solid(name, parts, coll, max(0.003, r_shaft / 3.5), 320, seed=seed)


def rib(coll, name, size=0.28, seed=0):
    """Ребро: плоская изогнутая дуга."""
    path = [Vector((size * 0.6 * math.sin(a), size * 0.6 * (1 - math.cos(a)) - size * 0.3, 0.012 * math.sin(a * 2)))
            for a in [math.pi * 0.85 * i / 14 for i in range(15)]]
    bm = P.tube(path, 0.009, segs=6, radius_fn=lambda t: 1.0 - 0.4 * t)
    bm.transform(Matrix.Diagonal((1.0, 1.0, 0.45, 1.0)))
    return _solid(name, [(bm, I)], coll, 0.0028, 170, smooth=1, seed=seed)


def vertebra(coll, name, scale=1.0, seed=0):
    """Позвонок: тело-цилиндр, дуга и три отростка."""
    s = scale
    parts = [(P.cylinder(0.022 * s, 0.026 * s, segs=12), T(0, 0, 0.013 * s)),
             (_ellipsoid((0, -0.03 * s, 0.015 * s), (0.016 * s, 0.014 * s, 0.01 * s), (10, 6)), I),
             (P.board(0.008 * s, 0.045 * s, 0.01 * s, bevel=0.002), T(0, -0.055 * s, 0.018 * s) @ rot(-20, "X")),
             (P.board(0.07 * s, 0.009 * s, 0.009 * s, bevel=0.002), T(0, -0.032 * s, 0.016 * s))]
    return _solid(name, parts, coll, 0.0025 * s, 200, smooth=1, seed=seed)


def pelvis(coll, name, seed=0):
    """Таз: две «крыла» подвздошных костей и кольцо, упрощённо."""
    parts = []
    for sx in (-1, 1):
        bm = _ellipsoid((sx * 0.08, 0.0, 0.05), (0.06, 0.016, 0.07), (14, 8))
        parts.append((bm, rot(sx * 25, "Z")))
    ring = P.tube([Vector((0.06 * math.cos(a), 0.02 + 0.045 * math.sin(a), -0.01)) for a in
                   [2 * math.pi * i / 14 for i in range(14)]], 0.013, segs=6, closed=True)
    parts.append((ring, I))
    return _solid(name, parts, coll, 0.0035, 450, seed=seed)


# --------------------------------------------------------------------------------------
# Скопления: кости раскладываются «как упали» на условную землю и частично заносятся снегом
# --------------------------------------------------------------------------------------
def _scatter(objs, r, radius, z=0.0):
    for o in objs:
        a = r.uniform(0, 2 * math.pi)
        rr = radius * math.sqrt(r.random())
        zmin = min(v.co.z for v in o.data.vertices)
        o.data.transform(Matrix.Translation((0, 0, -zmin)))
        tilt = r.uniform(55, 110) if o.name.endswith("skull") else r.uniform(-8, 8)
        if o.name.endswith("skull"):
            o.data.transform(rot(tilt, "X"))
            zmin = min(v.co.z for v in o.data.vertices)
            o.data.transform(Matrix.Translation((0, 0, -zmin)))
            tilt = 0.0
        m = T(rr * math.cos(a), rr * math.sin(a), z - r.uniform(0.0, 0.015)) @ rot(r.uniform(0, 360), "Z") @ rot(tilt, "X")
        o.data.transform(m)


def _skeleton_parts(coll, prefix, r):
    objs = []
    objs += skull(coll, f"{prefix}skull", seed=r.randrange(999))
    for k, (ln, rs, re) in enumerate(((0.45, 0.012, 0.024), (0.44, 0.012, 0.024), (0.37, 0.011, 0.02),
                                      (0.31, 0.01, 0.018), (0.25, 0.007, 0.012))):
        objs.append(long_bone(coll, f"{prefix}long{k}", ln, rs, re, seed=r.randrange(999)))
    for k in range(r.randint(5, 8)):
        objs.append(rib(coll, f"{prefix}rib{k}", r.uniform(0.22, 0.3), seed=r.randrange(999)))
    for k in range(r.randint(3, 5)):
        objs.append(vertebra(coll, f"{prefix}vert{k}", r.uniform(0.9, 1.1), seed=r.randrange(999)))
    if r.random() < 0.7:
        objs.append(pelvis(coll, f"{prefix}pelvis", seed=r.randrange(999)))
    return objs


def _finish_cluster(name, coll, objs, seed, snow=()):
    if snow:
        sbm = bmesh.new()
        for k, (cx, cy, rx, ry, th) in enumerate(snow):
            L.snow_patch(sbm, cx, cy, rx, ry, th, z0=-0.01, seed=seed + k)
        objs.append(L.object_from_bmesh(name + "_snow", sbm, coll, "nm_snow"))
    for i, o in enumerate(objs):
        L.bake_masks(o, seed=seed + i, rays=12, ao_dist=0.25, base_dark=0.15, tint_var=0.06,
                     extra_occluders=[x for x in objs if x is not o][:30])
    obj = L.merge_objects(name, objs, coll)
    L.finalize(obj, sharp_deg=55, uv_tile=1.0)
    return obj


def bones_scatter_a():
    """Один скелет, растащенный по снегу (обочина, старая дорога видения)."""
    name, seed = "bones_scatter_a", 7101
    coll = L.asset_collection(name)
    r = random.Random(seed)
    objs = _skeleton_parts(coll, "a_", r)
    _scatter(objs, r, 0.75)
    obj = _finish_cluster(name, coll, objs, seed, snow=[(0.3, 0.2, 0.45, 0.3, 0.05), (-0.4, -0.3, 0.35, 0.25, 0.04)])
    return [obj]


def bones_scatter_b():
    """Старые кости нескольких людей, частично ушедшие в снег (длинная полоса вдоль дороги)."""
    name, seed = "bones_scatter_b", 7102
    coll = L.asset_collection(name)
    r = random.Random(seed)
    objs = []
    for k in range(2):
        part = _skeleton_parts(coll, f"b{k}_", r)
        _scatter(part, r, 0.6)
        for o in part:
            o.data.transform(T(0, (k - 0.5) * 1.1, 0))
        objs += part
    obj = _finish_cluster(name, coll, objs, seed, snow=[(0.0, 0.5, 0.6, 0.4, 0.06), (0.2, -0.6, 0.5, 0.35, 0.07),
                                                         (-0.3, 0.0, 0.3, 0.5, 0.05)])
    return [obj]


def bones_pile_c():
    """Плотная груда костей у ступеней храма (SHS-03; канон гл. 14 — «тысячи костей»)."""
    name, seed = "bones_pile_c", 7103
    coll = L.asset_collection(name)
    r = random.Random(seed)
    objs = []
    for k in range(4):
        part = _skeleton_parts(coll, f"c{k}_", r)
        _scatter(part, r, 0.7, z=0.0)
        for o in part:
            o.data.transform(T(r.uniform(-0.35, 0.35), r.uniform(-0.35, 0.35), 0.06 * k))
        objs += part
    obj = _finish_cluster(name, coll, objs, seed, snow=[(0.5, 0.4, 0.5, 0.35, 0.07), (-0.6, -0.2, 0.4, 0.4, 0.06)])
    return [obj]


def bones_monster_a():
    """Кости чудовищ (SHS-04, ART-DIRECTION): исполинское ребро-дуга, позвонок с гребнем,
    обломок челюсти с рядами клыков — крупнее и неправильнее человеческих."""
    name, seed = "bones_monster_a", 7201
    coll = L.asset_collection(name)
    r = random.Random(seed)
    objs = []
    # Ребро-дуга, торчащее из снега.
    path = [Vector((0.9 * math.sin(a), 0.0, 1.5 * math.sin(a * 0.9) - 0.15)) for a in [math.pi * 0.95 * i / 20 for i in range(21)]]
    bm = P.tube(path, 0.075, segs=8, radius_fn=lambda t: 1.0 - 0.55 * t + 0.15 * math.sin(t * 20))
    bm.transform(Matrix.Diagonal((1.0, 0.6, 1.0, 1.0)))
    objs.append(_solid("m_rib", [(bm, T(-0.4, 0.4, 0))], coll, 0.02, 1200, seed=seed))
    # Позвонок с остистым гребнем.
    vparts = [(P.cylinder(0.24, 0.3, segs=14), T(0, 0, 0.15) @ rot(90, "X")),
              (P.board(0.08, 0.15, 0.6, bevel=0.02), T(0, 0.0, 0.55) @ rot(12, "X")),
              (P.board(0.9, 0.12, 0.1, bevel=0.02), T(0, 0.05, 0.25))]
    objs.append(_solid("m_vert", vparts, coll, 0.015, 1200, seed=seed + 1))
    objs[-1].data.transform(T(1.0, -0.6, -0.05) @ rot(25, "Z") @ rot(-15, "Y"))
    # Челюсть с клыками.
    jpath = [Vector((0.0, -0.45 + 0.9 * t, 0.08 * math.sin(math.pi * t))) for t in [i / 12 for i in range(13)]]
    jparts = [(P.tube(jpath, 0.09, segs=8, radius_fn=lambda t: 0.6 + 0.6 * t), I)]
    for k in range(9):
        t = (k + 0.5) / 9
        h = 0.14 + 0.09 * r.random()
        tooth = P.cylinder(0.03, h, segs=6, radius2=0.004)
        jparts.append((tooth, T(0.0, -0.4 + 0.8 * t, 0.12 + h / 2 * 0.8) @ rot(r.uniform(-15, 15), "Y")))
    objs.append(_solid("m_jaw", jparts, coll, 0.012, 1400, seed=seed + 2))
    objs[-1].data.transform(T(-0.9, -0.8, 0.0) @ rot(-30, "Z") @ rot(70, "Y"))
    obj = _finish_cluster(name, coll, objs, seed, snow=[(0.0, 0.0, 1.2, 0.8, 0.12), (1.0, -0.6, 0.5, 0.5, 0.1)])
    return [obj]


def skull_human():
    """Отдельный череп с челюстью (для ручной расстановки и MultiMesh)."""
    name = "skull_human"
    coll = L.asset_collection(name)
    objs = skull(coll, "skull_human_part", seed=7301)
    objs[1].data.transform(T(0.09, 0.05, 0.0) @ rot(25, "Z"))
    for o in objs:
        zmin = min(v.co.z for v in o.data.vertices)
        o.data.transform(T(0, 0, -zmin - 0.004))
    obj = _finish_cluster(name, coll, objs, 7301)
    return [obj]


GROUPS = {"remains": [skull_human, bones_scatter_a, bones_scatter_b, bones_pile_c, bones_monster_a]}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    test = argv[argv.index("--test") + 1] if "--test" in argv else None
    export = "--no-export" not in argv and not test
    t0 = time.time()
    L.clear_data()
    built = []
    for fn in GROUPS["remains"]:
        objs = fn()
        coll = objs[0].users_collection[0]
        built.append(coll)
        print(f"BUILT {coll.name}: tris={sum(L.tri_count(o) for o in coll.all_objects if o.type == 'MESH')} t={time.time() - t0:.1f}s")
    if export:
        for coll in built:
            L.export_collection(coll, OUT_DIR / f"{coll.name}.glb")
    L.set_assets_visible(False)
    L.ground(size=60.0)
    L.setup_render(res=(1600, 900), samples=48 if test else 128, sun_elev=24.0, sun_az=-40.0)
    x = 0.0
    insts = []
    for c in built:
        pts = [p for o in c.all_objects if o.type == "MESH" for p in L.world_points(o)]
        x0, x1 = min(p.x for p in pts), max(p.x for p in pts)
        inst = bpy.data.objects.new("inst_" + c.name, None)
        inst.instance_type = "COLLECTION"
        inst.instance_collection = c
        L.preview_collection().objects.link(inst)
        inst.location = (x - x0, 0, 0)
        insts.append(inst)
        x += (x1 - x0) + 0.5
    man = L.mannequin(location=(x + 0.3, 0.5, 0), name="ScaleRef_remains")
    out = Path(test).parent / (Path(test).stem + "_remains.jpg") if test else L.PREVIEW_DIR / "remains_bones.jpg"
    L.frame_camera(insts + [man], direction=(-0.3, -1.0, 0.6), lens=45, margin=1.05)
    L.render(str(out))
    L.frame_camera(insts[:2], direction=(-0.4, -1.0, 0.9), lens=60, margin=1.02)
    L.render(str(out).replace(".jpg", "_close.jpg"))
    L.frame_camera(insts[:1], direction=(0.5, 1.0, 0.45), lens=85, margin=1.15)
    L.render(str(out).replace(".jpg", "_skull.jpg"))
    if export:
        L.save_blend(SRC / "remains_kit.blend")
    print("DONE", time.time() - t0)


main()

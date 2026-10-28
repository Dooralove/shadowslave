"""Общая библиотека производства ассетов Первого Кошмара (Blender 5.1).

Используется скриптами `build_*.py` этой папки. Работает и в фоне
(`blender -b --python build_x.py`), и в живом Blender через MCP
(`import nm_lib; importlib.reload(nm_lib)`).

Соглашения (см. `docs/art/asset_production_standards.md`):
- 1 единица Blender = 1 м. Вперёд по маршруту — +Y Blender (= −Z Godot), вверх — +Z.
- Каждый ассет — своя коллекция внутри `ASSETS`; в .glb уходит только она.
- Визуальный меш + простая коллизия с суффиксом `-colonly` / `-convcolonly`.
- Материалы в .glb — только слоты с именами (`nm_*`) без картинок; в Godot слоты
  подменяются внешними `.tres` из `materials/` через `.import`.
- Цветовой атрибут `nm_mask` (float, линейный): RGB — грязь/AO-множитель альбедо,
  A — склонность к снегу (0 — снег не ложится: под навесами, на днище).
"""

import math
import random
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector, noise
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[4]
NM_DIR = ROOT / "assets" / "environments" / "nightmare"
SOURCE_DIR = NM_DIR / "source"
TEX_DIR = NM_DIR / "materials" / "textures"
PREVIEW_DIR = ROOT / "docs" / "art" / "previews" / "nightmare"

MASK_ATTR = "nm_mask"

# --------------------------------------------------------------------------------------
# Материалы (описание — nm_materials.py; здесь только ноды Blender для превью)
# --------------------------------------------------------------------------------------
import importlib  # noqa: E402

import nm_materials  # noqa: E402

importlib.reload(nm_materials)
MATERIALS = nm_materials.MATERIALS
TEXSETS = nm_materials.TEXSETS


def tex_path(name):
    """Файл текстуры: имя — в `TEX_DIR`; путь с «/» — от корня проекта (общие текстуры других наборов)."""
    return ROOT / name if "/" in name else TEX_DIR / name


def register_materials(materials, texsets, tex_dir=None):
    """Добавить материалы другого семейства ассетов (пролог, парк) к таблицам этого процесса.
    tex_dir — папка текстур семейства: короткие имена файлов переводятся в пути от корня проекта."""
    def full(name):
        return name if (tex_dir is None or "/" in name) else (Path(tex_dir) / name).relative_to(ROOT).as_posix()

    for key, spec in materials.items():
        spec = dict(spec)
        if "emission_texture" in spec:
            spec["emission_texture"] = full(spec["emission_texture"])
        MATERIALS[key] = spec
    for key, ts in texsets.items():
        TEXSETS[key] = {k: (full(v) if isinstance(v, str) else v) for k, v in ts.items()}


def _image(name, non_color):
    img = bpy.data.images.get(Path(name).name)
    if img is None:
        img = bpy.data.images.load(str(tex_path(name)), check_existing=True)
    img.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
    return img


def _node(nt, kind, x, y, **props):
    n = nt.nodes.new(kind)
    n.location = (x, y)
    for k, v in props.items():
        setattr(n, k, v)
    return n


def _math(nt, op, a, b, x, y):
    n = _node(nt, "ShaderNodeMath", x, y, operation=op)
    for i, val in enumerate((a, b)):
        if isinstance(val, (int, float)):
            n.inputs[i].default_value = val
        else:
            nt.links.new(val, n.inputs[i])
    return n.outputs["Value"]


def _mix(nt, dtype, fac, a, b, x, y, blend="MIX"):
    n = _node(nt, "ShaderNodeMix", x, y, data_type=dtype, blend_type=blend)
    for sock, val in (("Factor", fac), ("A", a), ("B", b)):
        if isinstance(val, (int, float)):
            n.inputs[sock].default_value = val
        elif isinstance(val, tuple):
            n.inputs[sock].default_value = (*val, 1.0) if len(val) == 3 else val
        else:
            nt.links.new(val, n.inputs[sock])
    return n.outputs["Result"]


def _layer(nt, texset, spec, uv, y):
    """Слой: (цвет, шероховатость, высота, нормаль-или-None). uv=False — BOX-проекция."""
    t = TEXSETS[texset]
    tc = nt.nodes.get("nm_texcoord") or _node(nt, "ShaderNodeTexCoord", -1500, 0)
    tc.name = "nm_texcoord"
    mp = _node(nt, "ShaderNodeMapping", -1250, y)
    s = 1.0 / t["tile"]
    mp.inputs["Scale"].default_value = (s, s, s)
    nt.links.new(tc.outputs["UV" if uv else "Object"], mp.inputs["Vector"])
    imgs = {}
    for i, (ch, nc) in enumerate((("albedo", False), ("arm", True), ("height", True), ("normal", True))):
        if (ch == "normal" and not uv) or ch not in t:
            continue
        n = _node(nt, "ShaderNodeTexImage", -1000, y - i * 280)
        n.image = _image(t[ch], nc)
        if not uv:
            n.projection = "BOX"
            n.projection_blend = 0.3
        nt.links.new(mp.outputs["Vector"], n.inputs["Vector"])
        imgs[ch] = n
    sep = _node(nt, "ShaderNodeSeparateColor", -700, y - 280)
    nt.links.new(imgs["arm"].outputs["Color"], sep.inputs["Color"])
    col = _mix(nt, "RGBA", 1.0, imgs["albedo"].outputs["Color"], tuple(spec.get("tint", (1, 1, 1))),
               -700, y, blend="MULTIPLY")
    rough = _math(nt, "MULTIPLY_ADD", sep.outputs["Green"], spec.get("rough_scale", 1.0), -500, y - 280)
    rough_node = rough.node
    rough_node.inputs[2].default_value = spec.get("rough_offset", 0.0)
    rough_node.use_clamp = True
    nrm = None
    if uv:
        nm = _node(nt, "ShaderNodeNormalMap", -500, y - 840)
        nm.inputs["Strength"].default_value = spec.get("normal", 1.0)
        nt.links.new(imgs["normal"].outputs["Color"], nm.inputs["Color"])
        nrm = nm.outputs["Normal"]
    height = imgs["height"].outputs["Color"] if "height" in imgs else 0.5  # без карты высот — только нормали
    return col, rough, height, nrm


def material(name):
    """Материал-слот с нодами для рендера в Blender. В .glb уходит только имя и цвет."""
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    spec = MATERIALS[name]
    uv = spec["kind"] == "uv"
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*spec["preview"], 1.0)
    if spec["kind"] == "plain":
        nt = mat.node_tree
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = (*spec["color"], 1.0)
        bsdf.inputs["Roughness"].default_value = spec.get("rough", 0.8)
        bsdf.inputs["Metallic"].default_value = spec.get("metallic", 0.0)
        if "emission" in spec:
            bsdf.inputs["Emission Color"].default_value = (*spec["emission"], 1.0)
            bsdf.inputs["Emission Strength"].default_value = spec.get("emission_energy", 1.0)
        if "emission_texture" in spec:  # экран: картинка интерфейса по UV
            img = _node(nt, "ShaderNodeTexImage", -400, -300)
            img.image = _image(spec["emission_texture"], False)
            nt.links.new(img.outputs["Color"], bsdf.inputs["Emission Color"])
        if "alpha" in spec:  # стекло
            bsdf.inputs["Alpha"].default_value = spec["alpha"]
            mat.surface_render_method = "BLENDED"
        return mat
    nt = mat.node_tree
    nt.nodes.clear()
    out = _node(nt, "ShaderNodeOutputMaterial", 900, 0)
    bsdf = _node(nt, "ShaderNodeBsdfPrincipled", 600, 0)
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    bsdf.inputs["Metallic"].default_value = spec.get("metallic", 0.0)
    color, rough, height, nrm = _layer(nt, spec["base"], spec, uv, 600)
    # Грязь/AO из атрибута вершин (в Godot: COLOR.rgb шейдера / vertex_color_use_as_albedo).
    attr = _node(nt, "ShaderNodeAttribute", -500, 1250, attribute_name=MASK_ATTR, attribute_type="GEOMETRY")
    if not uv:
        # Макровариация тона (как macro_noise шейдера Godot): ломает повтор тайла.
        tc = nt.nodes["nm_texcoord"]
        noise_n = _node(nt, "ShaderNodeTexNoise", -700, 1000)
        noise_n.inputs["Scale"].default_value = 1.0 / 8.0
        noise_n.inputs["Detail"].default_value = 3.0
        nt.links.new(tc.outputs["Object"], noise_n.inputs["Vector"])
        macro = _math(nt, "MULTIPLY_ADD", noise_n.outputs["Fac"], 0.6, -500, 1000)
        macro.node.inputs[2].default_value = 0.7
        macro = _mix(nt, "FLOAT", 0.25, 1.0, macro, -350, 1000)
        color = _mix(nt, "RGBA", 1.0, color, macro, -200, 900, blend="MULTIPLY")
        color = _mix(nt, "RGBA", 1.0, color, attr.outputs["Color"], -50, 900, blend="MULTIPLY")
        if spec.get("snow"):
            snow_spec = MATERIALS["nm_snow"]
            s_col, s_rough, s_h, _ = _layer(nt, snow_spec["base"], snow_spec, False, -700)
            geo = _node(nt, "ShaderNodeNewGeometry", -500, -1700)
            sepn = _node(nt, "ShaderNodeSeparateXYZ", -320, -1700)
            nt.links.new(geo.outputs["Normal"], sepn.inputs["Vector"])
            up = _math(nt, "MULTIPLY_ADD", noise_n.outputs["Fac"], 0.35, -150, -1700)
            nt.links.new(sepn.outputs["Z"], up.node.inputs[2])
            up = _math(nt, "SUBTRACT", up, 0.175, 0, -1700)
            thr = 1.0 - spec.get("coverage", 0.4)
            rng = _node(nt, "ShaderNodeMapRange", 150, -1700)
            rng.inputs["From Min"].default_value = thr - 0.12
            rng.inputs["From Max"].default_value = thr + 0.12
            rng.interpolation_type = "SMOOTHSTEP"
            nt.links.new(up, rng.inputs["Value"])
            fac = _math(nt, "MULTIPLY", rng.outputs["Result"], attr.outputs["Alpha"], 320, -1700)
            color = _mix(nt, "RGBA", fac, color, s_col, 380, 300)
            rough = _mix(nt, "FLOAT", fac, rough, s_rough, 380, 100)
            height = _mix(nt, "FLOAT", fac, height, s_h, 380, -100)
    else:
        color = _mix(nt, "RGBA", 1.0, color, attr.outputs["Color"], -50, 900, blend="MULTIPLY")
    bump = _node(nt, "ShaderNodeBump", 420, -300)
    bump.inputs["Strength"].default_value = 1.0
    bump.inputs["Distance"].default_value = spec.get("bump", 0.02)
    if isinstance(height, float):
        bump.inputs["Height"].default_value = height
    else:
        nt.links.new(height, bump.inputs["Height"])
    if nrm is not None:
        nt.links.new(nrm, bump.inputs["Normal"])
    nt.links.new(color, bsdf.inputs["Base Color"])
    nt.links.new(rough, bsdf.inputs["Roughness"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


# --------------------------------------------------------------------------------------
# Сцена и коллекции
# --------------------------------------------------------------------------------------
def clear_data():
    """Очистить файл, не сбрасывая настройки (в живом Blender сохраняется MCP-аддон)."""
    for coll in (bpy.data.objects, bpy.data.meshes, bpy.data.materials, bpy.data.images,
                 bpy.data.collections, bpy.data.cameras, bpy.data.lights, bpy.data.worlds,
                 bpy.data.textures, bpy.data.node_groups, bpy.data.curves):
        for item in list(coll):
            coll.remove(item)
    scene = bpy.context.scene
    scene.world = bpy.data.worlds.new("World")


def assets_root():
    root = bpy.data.collections.get("ASSETS")
    if root is None:
        root = bpy.data.collections.new("ASSETS")
        bpy.context.scene.collection.children.link(root)
    return root


def asset_collection(name):
    coll = bpy.data.collections.get(name)
    if coll is None:
        coll = bpy.data.collections.new(name)
        assets_root().children.link(coll)
    return coll


def link(obj, coll):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    coll.objects.link(obj)
    return obj


# --------------------------------------------------------------------------------------
# Меши
# --------------------------------------------------------------------------------------
def object_from_bmesh(name, bm, coll=None, mat=None):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    (coll or bpy.context.scene.collection).objects.link(obj)
    if mat:
        mesh.materials.append(material(mat))
    return obj


def apply_modifiers(obj):
    """Применить модификаторы через depsgraph (без операторов и контекста)."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    new = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=dg)
    old = obj.data
    obj.modifiers.clear()
    obj.data = new
    new.name = old.name
    if old.users == 0:
        bpy.data.meshes.remove(old)
    return obj


def voxel_remesh(obj, voxel):
    mod = obj.modifiers.new("Remesh", "REMESH")
    mod.mode = "VOXEL"
    mod.voxel_size = voxel
    mod.adaptivity = 0.0
    mod.use_smooth_shade = False
    return apply_modifiers(obj)


def decimate(obj, target_tris):
    tris = tri_count(obj)
    if tris <= target_tris:
        return obj
    mod = obj.modifiers.new("Decimate", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = target_tris / tris
    mod.use_collapse_triangulate = False
    return apply_modifiers(obj)


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def smooth(obj, factor=0.5, repeat=1, only_z=False):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    for _ in range(repeat):
        bmesh.ops.smooth_vert(bm, verts=bm.verts, factor=factor, use_axis_x=not only_z,
                              use_axis_y=not only_z, use_axis_z=True)
    bm.to_mesh(obj.data)
    bm.free()


def shade(obj, sharp_deg=48.0):
    """Гладкое затенение + острые рёбра по углу (сохраняются при экспорте в glTF)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    lim = math.radians(sharp_deg)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        e.smooth = not (e.is_manifold and e.calc_face_angle(0.0) > lim) and e.is_manifold
    bm.to_mesh(obj.data)
    bm.free()


def displace(obj, fn):
    """Сдвиг вершин по нормали: fn(co, normal) -> смещение, м.

    Координаты и нормали читаются и пишутся массивами: чтение v.normal после правки
    v.co заставляет Blender пересчитывать нормали всего меша на каждой вершине."""
    mesh = obj.data
    n = len(mesh.vertices)
    co = np.empty(n * 3, dtype=np.float32)
    nr = np.empty(n * 3, dtype=np.float32)
    mesh.vertices.foreach_get("co", co)
    mesh.vertex_normals.foreach_get("vector", nr)
    co = co.reshape(-1, 3)
    nr = nr.reshape(-1, 3)
    d = np.fromiter((fn(Vector(c), Vector(k)) for c, k in zip(co.tolist(), nr.tolist())),
                    dtype=np.float32, count=n)
    co += nr * d[:, None]
    mesh.vertices.foreach_set("co", co.ravel())
    mesh.update()


def fbm(p, octaves=4, lac=2.0, gain=0.5):
    amp, freq, total, norm = 1.0, 1.0, 0.0, 0.0
    for _ in range(octaves):
        total += amp * noise.noise(p * freq)
        norm += amp
        amp *= gain
        freq *= lac
    return total / norm


def crack(p, width=0.06):
    """0 вдали от трещин, 1 на границе ячеек Вороного (F2 − F1 мало)."""
    d, _ = noise.voronoi(p, distance_metric="DISTANCE")
    edge = d[1] - d[0]
    return max(0.0, 1.0 - edge / width)


# --------------------------------------------------------------------------------------
# Каменные формы
# --------------------------------------------------------------------------------------
def _hull(bm):
    """Выпуклая оболочка на месте: внутренние и лишние вершины удаляются."""
    res = bmesh.ops.convex_hull(bm, input=list(bm.verts))
    junk = {g for g in res["geom_interior"] + res["geom_unused"] if isinstance(g, bmesh.types.BMVert)}
    if junk:
        bmesh.ops.delete(bm, geom=list(junk), context="VERTS")
    return bm


def hull_chunk(seed, dims, npts=48, cuts=5, cut_depth=(0.55, 0.85), squash=None):
    """Выпуклый многогранник «откола»: облако точек в эллипсоиде + плоские сколы.

    dims — габариты (x, y, z), м. cuts — число плоскостей раскола: дают крупные грани,
    характерные для камня, а не для «мыльного» эллипсоида."""
    r = random.Random(seed)
    bm = bmesh.new()
    hx, hy, hz = dims[0] / 2, dims[1] / 2, dims[2] / 2
    for _ in range(npts):
        v = Vector((r.gauss(0, 1), r.gauss(0, 1), r.gauss(0, 1)))
        v.normalize()
        v *= r.uniform(0.82, 1.0)
        bm.verts.new((v.x * hx, v.y * hy, v.z * hz))
    _hull(bm)
    for _ in range(cuts):
        n = Vector((r.gauss(0, 1), r.gauss(0, 1), r.gauss(0, 1) * 0.8)).normalized()
        support = max(v.co.dot(n) for v in bm.verts)
        co = n * support * r.uniform(*cut_depth)
        bmesh.ops.bisect_plane(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces),
                               plane_co=co, plane_no=n, clear_outer=True)
        verts = list(bm.verts)
        bm2 = bmesh.new()
        for v in verts:
            bm2.verts.new(v.co)
        bm.free()
        bm = bm2
        _hull(bm)
    if squash:
        for v in bm.verts:
            v.co.z *= squash
    return bm


def facet_sheet(seed, length, height, depth, cell=(1.7, 0.95), relief=0.55, tilt=0.4, res=0.09,
                top_var=1.6, macro=0.7, joints=0.35, y0=-0.4, z0=-0.6, back_x=None, extra=None):
    """Скальный массив с лицом из плоских граней раскола.

    Лицо — сетка (y, z); x(y, z) — плоскость своей ячейки Вороного (смещение + наклон),
    ячейки вытянуты по напластованию (cell = размер по y, по z). На границах ячеек — уступы
    и полки (на них ложится снег). joints — доля вертикальных трещин-отдельностей.
    Тыл — плоскость x = back_x. Возвращает замкнутый bmesh. Лицо смотрит в −X.
    Внимание: height — отметка верха (z), а не высота над z0: лист идёт от z0 до height ± top_var."""
    r = random.Random(seed)
    off = Vector((r.uniform(0, 100), r.uniform(0, 100), r.uniform(0, 100)))
    cache = {}

    def cell_params(key):
        if key not in cache:
            rr = random.Random(hash(key) ^ seed)
            cache[key] = (rr.uniform(-relief, relief), rr.uniform(-tilt, tilt), rr.uniform(-tilt, tilt) * 0.6)
        return cache[key]

    def face_x(y, z):
        p = Vector((y / cell[0], z / cell[1], 0.0)) + off
        dist, pts = noise.voronoi(p, distance_metric="DISTANCE")
        c = pts[0]
        o, gy, gz = cell_params((round(c.x, 4), round(c.y, 4)))
        x = o + gy * (p.x - c.x) * cell[0] * 0.5 + gz * (p.y - c.y) * cell[1] * 0.5
        # Вертикальные трещины: узкие провалы по границам вытянутых по z ячеек.
        if joints:
            q = Vector((y / (cell[0] * 1.3), z / (cell[1] * 4.0), 7.0)) + off * 0.5
            d2, _ = noise.voronoi(q, distance_metric="DISTANCE")
            x += joints * max(0.0, 1.0 - (d2[1] - d2[0]) / 0.06)
        x += macro * fbm(Vector((y * 0.12, z * 0.1, 3.0)) + off, 2)
        if extra:
            x += extra(y, z)
        return x

    ny = max(2, int(round(length / res)))
    nz = max(2, int(round(height / res)))
    tops = [height + top_var * fbm(Vector((y * 0.25, 9.0, 1.0)) + off, 2) for y in
            [y0 + length * i / ny for i in range(ny + 1)]]
    xs = []
    for i in range(ny + 1):
        y = y0 + length * i / ny
        col = []
        for j in range(nz + 1):
            z = z0 + (tops[i] - z0) * j / nz
            col.append((face_x(y, z), y, z))
        xs.append(col)
    bx = back_x if back_x is not None else depth
    bm = bmesh.new()
    front = [[bm.verts.new(v) for v in col] for col in xs]
    back = [[bm.verts.new((bx, v[1], v[2])) for v in col] for col in xs]
    for i in range(ny):
        for j in range(nz):
            bm.faces.new((front[i][j], front[i][j + 1], front[i + 1][j + 1], front[i + 1][j]))
    # Замыкание: боковые, нижняя и верхняя полосы + плоский тыл одной гранью по контуру.
    for j in range(nz):
        bm.faces.new((front[0][j], back[0][j], back[0][j + 1], front[0][j + 1]))
        bm.faces.new((front[ny][j + 1], back[ny][j + 1], back[ny][j], front[ny][j]))
    for i in range(ny):
        bm.faces.new((front[i][0], front[i + 1][0], back[i + 1][0], back[i][0]))
        bm.faces.new((front[i + 1][nz], front[i][nz], back[i][nz], back[i + 1][nz]))
    inner = [back[i][j] for i in range(1, ny) for j in range(1, nz)]
    bmesh.ops.delete(bm, geom=inner, context="VERTS")
    ring = [back[i][0] for i in range(ny + 1)] + [back[ny][j] for j in range(1, nz + 1)] + \
           [back[i][nz] for i in range(ny - 1, -1, -1)] + [back[0][j] for j in range(nz - 1, 0, -1)]
    bm.faces.new(ring)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return bm


# --------------------------------------------------------------------------------------
# Мощение: ячейки Вороного на плоскости, плиты с фаской
# --------------------------------------------------------------------------------------
def poisson_2d(rng, x0, x1, y0, y1, min_d, tries=4000):
    pts = []
    for _ in range(tries):
        p = Vector((rng.uniform(x0, x1), rng.uniform(y0, y1)))
        if all((p - q).length >= min_d for q in pts):
            pts.append(p)
    return pts


def _clip(poly, a, b):
    """Оставить часть многоугольника, которая ближе к a, чем к b."""
    mid = (a + b) / 2
    n = b - a
    out = []
    for i, p in enumerate(poly):
        q = poly[(i + 1) % len(poly)]
        dp, dq = (p - mid).dot(n), (q - mid).dot(n)
        if dp <= 0:
            out.append(p)
        if dp * dq < 0:
            out.append(p + (q - p) * (dp / (dp - dq)))
    return out


def voronoi_cells(sites, neighbors, rect):
    """Ячейки для sites; neighbors — дополнительные (призрачные) соседи; rect — (x0, y0, x1, y1)."""
    x0, y0, x1, y1 = rect
    allp = list(sites) + list(neighbors)
    cells = []
    for a in sites:
        poly = [Vector((x0, y0)), Vector((x1, y0)), Vector((x1, y1)), Vector((x0, y1))]
        for b in allp:
            if b is a or (b - a).length < 1e-6:
                continue
            if (b - a).length > 3.0:
                continue
            poly = _clip(poly, a, b)
            if len(poly) < 3:
                break
        cells.append(poly)
    return cells


def _poly_area(poly):
    return 0.5 * sum(poly[i].x * poly[(i + 1) % len(poly)].y - poly[(i + 1) % len(poly)].x * poly[i].y
                     for i in range(len(poly)))


def shrink_poly(poly, gap):
    """Сжать выпуклый многоугольник на gap по нормалям рёбер (зазор между плитами)."""
    c = sum(poly, Vector((0, 0))) / len(poly)
    out = []
    n = len(poly)
    for i in range(n):
        p0, p1, p2 = poly[i - 1], poly[i], poly[(i + 1) % n]
        e0 = (p1 - p0).normalized()
        e1 = (p2 - p1).normalized()
        n0 = Vector((e0.y, -e0.x))
        n1 = Vector((e1.y, -e1.x))
        if (c - p1).dot(n0) < 0:
            n0, n1 = -n0, -n1
        bis = (n0 + n1)
        if bis.length < 1e-6:
            continue
        bis.normalize()
        cosang = max(0.3, bis.dot(n0))
        out.append(p1 + bis * (gap / cosang))
    return out


def chamfer_poly(poly, d):
    """Срезать углы на d: скруглённые, сбитые углы плит."""
    out = []
    n = len(poly)
    for i in range(n):
        p0, p1, p2 = poly[i - 1], poly[i], poly[(i + 1) % n]
        a, b = (p0 - p1), (p2 - p1)
        da = min(d, a.length * 0.3)
        db = min(d, b.length * 0.3)
        out.append(p1 + a.normalized() * da)
        out.append(p1 + b.normalized() * db)
    return out


def slab_from_poly(bm, poly, top, bottom, bevel=0.025, tilt=(0.0, 0.0), center=None, jitter=None, dome=0.0):
    """Призма-плита: верх с фаской bevel, наклон tilt (по x, по y — уклон на метр).

    dome — подъём центра верхней грани (стёртая выпуклость), jitter(p) — шум высоты кромки."""
    c = center if center is not None else sum(poly, Vector((0, 0))) / len(poly)
    inner = shrink_poly(poly, bevel)
    if len(inner) != len(poly):
        inner = poly

    def h(p, base):
        z = base + tilt[0] * (p.x - c.x) + tilt[1] * (p.y - c.y)
        if jitter:
            z += jitter(p)
        return z

    ring_bot = [bm.verts.new((p.x, p.y, bottom)) for p in poly]
    ring_mid = [bm.verts.new((p.x, p.y, h(p, top - bevel * 0.9))) for p in poly]
    ring_top = [bm.verts.new((p.x, p.y, h(p, top))) for p in inner]
    n = len(poly)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((ring_bot[i], ring_bot[j], ring_mid[j], ring_mid[i]))
        bm.faces.new((ring_mid[i], ring_mid[j], ring_top[j], ring_top[i]))
    top_face = bm.faces.new(ring_top)
    bm.faces.new(list(reversed(ring_bot)))
    if dome:
        res = bmesh.ops.poke(bm, faces=[top_face])
        for v in res["verts"]:
            v.co.z += dome
    return bm


def join_bmeshes(parts):
    """Склеить несколько bmesh (с матрицами) в один без слияния вершин."""
    out = bmesh.new()
    for bm, mat in parts:
        bm.transform(mat)
        tmp = bpy.data.meshes.new("_tmp")
        bm.to_mesh(tmp)
        bm.free()
        out.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    return out


def rock_detail(obj, seed, size, large=0.05, medium=0.018, fine=0.005, crack_depth=0.015,
                strata=(1.0, 1.0, 2.6), crack_scale=0.9):
    """Выветривание: крупные волны, средние неровности, трещины по ячейкам Вороного.

    Амплитуды — доли характерного размера `size`; strata растягивает шум по слоям породы."""
    off = Vector((seed * 13.17, seed * 7.31, seed * 3.77))
    sx, sy, sz = strata

    def fn(co, n):
        p = Vector((co.x * sx, co.y * sy, co.z * sz)) / size
        d = large * size * fbm(p * 1.3 + off, 3)
        d += medium * size * fbm(p * 4.0 + off * 1.7, 3)
        d += fine * size * noise.noise(p * 14.0 + off)
        d -= crack_depth * size * crack(p * crack_scale + off * 0.5, 0.12)
        return d

    displace(obj, fn)


def cut_base(bm, z, keep="above"):
    """Срезать плоскостью z (плоское основание/торец) и закрыть оболочкой разреза."""
    geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
    n = Vector((0, 0, -1)) if keep == "above" else Vector((0, 0, 1))
    res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, z), plane_no=n, clear_outer=True)
    cut_edges = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
    if cut_edges:
        bmesh.ops.holes_fill(bm, edges=cut_edges, sides=0)
    return bm


def rock_object(name, parts, coll, mat="nm_rock", voxel=0.04, smooth_iter=2, seed=0, size=1.0,
                detail=None, target_tris=2500, base_z=None, sink=0.1, sharp=50.0):
    """Камень из одного или нескольких выпуклых кусков: слияние вокселями, выветривание,
    прореживание, посадка в землю (низ на −sink).

    parts — список (bmesh, Matrix). detail — параметры rock_detail."""
    bm = join_bmeshes(parts)
    obj = object_from_bmesh(name, bm, coll, mat)
    voxel_remesh(obj, voxel)
    if smooth_iter:
        smooth(obj, 0.5, smooth_iter)
    rock_detail(obj, seed, size, **(detail or {}))
    if base_z is not None:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        zmin = min(v.co.z for v in bm.verts)
        cut_base(bm, zmin + base_z)
        bm.to_mesh(obj.data)
        bm.free()
    decimate(obj, target_tris)
    zmin = min(v.co.z for v in obj.data.vertices)
    obj.data.transform(Matrix.Translation((0, 0, -zmin - sink)))
    return obj


# --------------------------------------------------------------------------------------
# Маски: грязь/AO и склонность к снегу
# --------------------------------------------------------------------------------------
def _hemisphere(r, n, count):
    # Косинусное распределение вокруг нормали.
    t = n.orthogonal().normalized()
    b = n.cross(t)
    dirs = []
    for _ in range(count):
        u1, u2 = r.random(), r.random()
        rr = math.sqrt(u1)
        th = 2 * math.pi * u2
        x, y = rr * math.cos(th), rr * math.sin(th)
        z = math.sqrt(max(0.0, 1 - u1))
        dirs.append((t * x + b * y + n * z).normalized())
    return dirs


def bake_masks(obj, seed=0, rays=20, ao_dist=1.5, ground=True, ground_z=0.0, base_dark=0.6,
               tint_var=0.07, extra_occluders=(), snow_noise=0.35, snow_scale=1.2, snow_fn=None,
               dirt_fn=None):
    """Записать цветовой атрибут nm_mask.

    RGB: AO самозатенения (+ земля и соседние объекты), затемнение у основания
    («влажные/грязевые» нижние участки), лёгкая низкочастотная вариация тона.
    A: склонность к снегу — 0 под навесами (луч вверх упирается в камень), иначе
    шумовая 0.6–1.0, чтобы снег ложился пятнами, а не ровной коркой."""
    r = random.Random(seed)
    mesh = obj.data
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.transform(obj.matrix_world)
    for other in extra_occluders:
        tmp = bpy.data.meshes.new_from_object(other)
        tmp.transform(other.matrix_world)
        bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    mw = obj.matrix_world
    nmat = mw.to_3x3().inverted().transposed()
    off = Vector((seed * 3.1, seed * 1.7, seed * 2.3))
    values = []
    for v in mesh.vertices:
        co = mw @ v.co
        n = (nmat @ v.normal).normalized()
        origin = co + n * 0.01
        hits = 0
        for d in _hemisphere(r, n, rays):
            hit = tree.ray_cast(origin, d, ao_dist)
            if hit[0] is not None:
                hits += 1
            elif ground and d.z < 0:
                t = (ground_z - origin.z) / d.z
                if 0 < t < ao_dist:
                    hits += 1
        ao = 1.0 - hits / rays
        ao = 0.35 + 0.65 * ao ** 1.3
        h = co.z - ground_z
        base = 1.0 - 0.18 * max(0.0, 1.0 - h / base_dark) if base_dark > 0 else 1.0
        var = 1.0 + tint_var * noise.noise(co * 0.35 + off)
        warm = 0.03 * noise.noise(co * 0.21 + off * 2.0)
        if dirt_fn:
            base *= dirt_fn(co)
        rr = ao * base * var * (1.0 + warm)
        gg = ao * base * var
        bb = ao * base * var * (1.0 - warm)
        up_hit = tree.ray_cast(co + n * 0.02 + Vector((0, 0, 0.02)), Vector((0, 0, 1)), 25.0)[0]
        snow = 0.0 if up_hit is not None else 1.0
        if snow > 0:
            sn = noise.noise(co * snow_scale + off * 0.7)
            snow = min(1.0, max(0.0, 0.8 + snow_noise * sn))
            if snow_fn:
                snow *= snow_fn(co)
        values.append((rr, gg, bb, snow))
    attr = mesh.color_attributes.get(MASK_ATTR) or mesh.color_attributes.new(MASK_ATTR, "FLOAT_COLOR", "POINT")
    for i, val in enumerate(values):
        attr.data[i].color = val
    set_active_mask(mesh)
    return obj


def set_active_mask(mesh):
    """nm_mask — и активный, и «рендерный» цветовой атрибут: экспорт glTF (ACTIVE) берёт его."""
    attr = mesh.color_attributes.get(MASK_ATTR)
    mesh.color_attributes.active_color = attr
    mesh.color_attributes.render_color_index = mesh.color_attributes.find(MASK_ATTR)


def plain_masks(obj, value=(1.0, 1.0, 1.0, 1.0)):
    mesh = obj.data
    attr = mesh.color_attributes.get(MASK_ATTR) or mesh.color_attributes.new(MASK_ATTR, "FLOAT_COLOR", "POINT")
    for d in attr.data:
        d.color = value
    set_active_mask(mesh)
    return obj


# --------------------------------------------------------------------------------------
# UV, коллизия, экспорт
# --------------------------------------------------------------------------------------
def uv_box(obj, tile=1.0):
    """Кубическая проекция в метрах (1 UV = tile м): для лайтмапов и UV-материалов."""
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for loop in f.loops:
            c = loop.vert.co
            if ax == 0:
                loop[uv].uv = (c.y * math.copysign(1, n.x) / tile, c.z / tile)
            elif ax == 1:
                loop[uv].uv = (-c.x * math.copysign(1, n.y) / tile, c.z / tile)
            else:
                loop[uv].uv = (c.x / tile, c.y * math.copysign(1, n.z) / tile)
    bm.to_mesh(mesh)
    bm.free()


def collision_convex(obj, name=None, max_verts=64, shrink=0.0):
    """Выпуклая коллизия (суффикс -convcolonly): оболочка прореженных вершин."""
    r = random.Random(7)
    verts = [obj.matrix_world @ v.co for v in obj.data.vertices]
    if len(verts) > max_verts * 6:
        verts = r.sample(verts, max_verts * 6)
    bm = bmesh.new()
    for v in verts:
        bm.verts.new(v)
    _hull(bm)
    if len(bm.verts) > max_verts:
        bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(12), verts=list(bm.verts), edges=list(bm.edges))
    if shrink:
        c = sum((v.co for v in bm.verts), Vector()) / len(bm.verts)
        for v in bm.verts:
            v.co = c + (v.co - c) * (1 - shrink)
    col = object_from_bmesh((name or obj.name) + "-convcolonly", bm, obj.users_collection[0])
    col.display_type = "WIRE"
    col.hide_render = True
    return col


def collision_trimesh(obj, target_tris=400, name=None):
    """Треугольная коллизия (суффикс -colonly): сильно прореженная копия."""
    mesh = obj.data.copy()
    col = bpy.data.objects.new((name or obj.name) + "-colonly", mesh)
    obj.users_collection[0].objects.link(col)
    col.matrix_world = obj.matrix_world.copy()
    mesh.materials.clear()
    decimate(col, target_tris)
    for a in list(col.data.color_attributes):
        col.data.color_attributes.remove(a)
    col.display_type = "WIRE"
    col.hide_render = True
    return col


def merge_objects(name, objs, coll):
    """Слить объекты в один меш (слоты материалов объединяются, атрибут nm_mask сохраняется)."""
    mats = []
    bm = bmesh.new()
    for o in objs:
        start = len(bm.faces)
        m = o.data.copy()
        m.transform(o.matrix_world)
        bm.from_mesh(m)
        bm.faces.ensure_lookup_table()
        local = []
        for mt in o.data.materials:
            if mt not in mats:
                mats.append(mt)
            local.append(mats.index(mt))
        for f in bm.faces[start:]:
            f.material_index = local[f.material_index] if local else 0
        bpy.data.meshes.remove(m)
    for o in objs:
        mesh = o.data
        bpy.data.objects.remove(o)
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)
    obj = object_from_bmesh(name, bm, coll)
    for mt in mats:
        obj.data.materials.append(mt)
    attr = obj.data.color_attributes.get(MASK_ATTR)
    if attr:
        set_active_mask(obj.data)
    return obj


def grid_surface(name, coll, x0, x1, y0, y1, nx, ny, height, mat, z_bottom=-0.45):
    """Замкнутая «плита» с верхом-высотным полем height(x, y): снег, грунт, надувы."""
    bm = bmesh.new()
    top = [[bm.verts.new((x0 + (x1 - x0) * i / nx, y0 + (y1 - y0) * j / ny,
                          height(x0 + (x1 - x0) * i / nx, y0 + (y1 - y0) * j / ny)))
            for j in range(ny + 1)] for i in range(nx + 1)]
    for i in range(nx):
        for j in range(ny):
            bm.faces.new((top[i][j], top[i + 1][j], top[i + 1][j + 1], top[i][j + 1]))
    ring = [top[i][0] for i in range(nx + 1)] + [top[nx][j] for j in range(1, ny + 1)] + \
           [top[i][ny] for i in range(nx - 1, -1, -1)] + [top[0][j] for j in range(ny - 1, 0, -1)]
    bot = [bm.verts.new((v.co.x, v.co.y, z_bottom)) for v in ring]
    n = len(ring)
    for k in range(n):
        bm.faces.new((ring[k], bot[k], bot[(k + 1) % n], ring[(k + 1) % n]))
    bm.faces.new(bot)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return object_from_bmesh(name, bm, coll, mat)


def snow_patch(bm, cx, cy, rx, ry, thick, z0=0.0, seed=0, res=10, angle=0.0, z_fn=None):
    """Плоский нанос снега: диск-сетка с пологим краем, чуть шумный; лежит на z0 (+z_fn(x, y))."""
    ca, sa = math.cos(angle), math.sin(angle)
    rings = res
    segs = 20
    off = Vector((seed * 1.3, seed * 2.1, 0.5))
    verts = []
    for i in range(rings + 1):
        t = i / rings
        row = []
        for k in range(segs if i else 1):
            a = 2 * math.pi * k / segs
            wob = 1.0 + 0.28 * noise.noise(Vector((math.cos(a) * 1.5, math.sin(a) * 1.5, seed * 0.7)))
            lx, ly = rx * t * math.cos(a) * wob, ry * t * math.sin(a) * wob
            x, y = cx + lx * ca - ly * sa, cy + lx * sa + ly * ca
            h = thick * (1 - t ** 2.2) + 0.25 * thick * noise.noise(Vector((x * 4, y * 4, 0)) + off) * (1 - t)
            base = z0 + (z_fn(x, y) if z_fn else 0.0)
            row.append(bm.verts.new((x, y, base + max(-0.004, h) - 0.006)))
        verts.append(row)
    for k in range(segs):
        bm.faces.new((verts[0][0], verts[1][k], verts[1][(k + 1) % segs]))
    for i in range(1, rings):
        for k in range(segs):
            bm.faces.new((verts[i][k], verts[i + 1][k], verts[i + 1][(k + 1) % segs], verts[i][(k + 1) % segs]))
    return bm


def sweep(bm, profile_fn, ys, cap=True):
    """Протяжка сечения вдоль Y: profile_fn(y) -> [(x, z), ...] (одинаковое число точек, обход
    по часовой, если смотреть с −Y). Для карнизов, валов снега, бордюров."""
    rings = []
    for y in ys:
        rings.append([bm.verts.new((x, y, z)) for x, z in profile_fn(y)])
    n = len(rings[0])
    for a, b in zip(rings, rings[1:]):
        for k in range(n):
            bm.faces.new((a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]))
    if cap:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return bm


def collision_profile(coll, name, ys, zs, width, depth=0.4):
    """Проходимая коллизия по профилю высоты вдоль Y (пандус под уступом): -colonly."""
    bm = bmesh.new()
    hw = width / 2
    top_l = [bm.verts.new((-hw, y, z)) for y, z in zip(ys, zs)]
    top_r = [bm.verts.new((hw, y, z)) for y, z in zip(ys, zs)]
    bot_l = [bm.verts.new((-hw, y, z - depth)) for y, z in zip(ys, zs)]
    bot_r = [bm.verts.new((hw, y, z - depth)) for y, z in zip(ys, zs)]
    for i in range(len(ys) - 1):
        bm.faces.new((top_l[i], top_r[i], top_r[i + 1], top_l[i + 1]))
        bm.faces.new((bot_l[i + 1], bot_r[i + 1], bot_r[i], bot_l[i]))
        bm.faces.new((top_l[i + 1], bot_l[i + 1], bot_l[i], top_l[i]))
        bm.faces.new((top_r[i], bot_r[i], bot_r[i + 1], top_r[i + 1]))
    bm.faces.new((top_l[0], bot_l[0], bot_r[0], top_r[0]))
    bm.faces.new((top_r[-1], bot_r[-1], bot_l[-1], top_l[-1]))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    col = object_from_bmesh(name + "-colonly", bm, coll)
    col.display_type = "WIRE"
    col.hide_render = True
    return col


def collision_box(coll, name, center, size, rot_z=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    m = Matrix.Translation(center) @ Matrix.Rotation(rot_z, 4, "Z") @ Matrix.Diagonal((*size, 1.0))
    bm.transform(m)
    col = object_from_bmesh(name + "-colonly", bm, coll)
    col.display_type = "WIRE"
    col.hide_render = True
    return col


def finalize(obj, sharp_deg=48.0, uv_tile=2.0):
    shade(obj, sharp_deg)
    uv_box(obj, uv_tile)
    obj.data.validate()
    return obj


# --------------------------------------------------------------------------------------
# Превью: свет, камера, манекен масштаба
# --------------------------------------------------------------------------------------
def _simple_mat(name, color, rough=0.8):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    mat.diffuse_color = (*color, 1.0)
    return mat


def preview_collection():
    coll = bpy.data.collections.get("PREVIEW")
    if coll is None:
        coll = bpy.data.collections.new("PREVIEW")
        bpy.context.scene.collection.children.link(coll)
    return coll


def mannequin(location=(0, 0, 0), height=1.75, name="ScaleRef_1_75m"):
    """Манекен роста 1,75 м (капсула + голова) — эталон масштаба, в экспорт не входит."""
    coll = preview_collection()
    bm = bmesh.new()
    body_h = height * 0.83
    r = 0.17
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=8, radius=r)
    for v in bm.verts:
        if v.co.z > 0:
            v.co.z += body_h - 2 * r
    bm.transform(Matrix.Translation((0, 0, r)) @ Matrix.Diagonal((1.0, 0.75, 1.0, 1.0)))
    head = bmesh.new()
    bmesh.ops.create_uvsphere(head, u_segments=16, v_segments=8, radius=0.105)
    head.transform(Matrix.Translation((0, 0, height - 0.11)))
    tmp = bpy.data.meshes.new("_h")
    head.to_mesh(tmp)
    head.free()
    bm.from_mesh(tmp)
    bpy.data.meshes.remove(tmp)
    obj = object_from_bmesh(name, bm, coll)
    obj.data.materials.append(_simple_mat("preview_mannequin", (0.55, 0.45, 0.38), 0.6))
    for p in obj.data.polygons:
        p.use_smooth = True
    obj.location = location
    return obj


def ground(size=60.0, z=0.0, snow=True):
    """Подложка превью: ровный снег без рисунка (рисунок тайла отвлекает от формы ассетов)."""
    coll = preview_collection()
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=size / 2)
    bm.transform(Matrix.Translation((0, 0, z)))
    obj = object_from_bmesh("PreviewGround", bm, coll)
    mat = bpy.data.materials.get("preview_ground") or bpy.data.materials.new("preview_ground")
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    color = (0.6, 0.64, 0.68) if snow else (0.12, 0.13, 0.15)
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.9
    tex = nt.nodes.new("ShaderNodeTexNoise")
    tex.inputs["Scale"].default_value = 3.0
    tex.inputs["Detail"].default_value = 6.0
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.15
    nt.links.new(tex.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    obj.data.materials.append(mat)
    return obj


def setup_render(res=(1600, 900), samples=128, sun_elev=22.0, sun_az=-35.0, sun_power=3.2,
                 sky=(0.2, 0.24, 0.31), sky_strength=0.9, exposure=0.0):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    try:
        prefs.compute_device_type = "OPTIX"
        prefs.get_devices()
        for d in prefs.devices:
            d.use = d.type == "OPTIX"
        scene.cycles.device = "GPU"
    except Exception as exc:  # без GPU — на CPU
        print("GPU unavailable:", exc)
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.view_settings.exposure = exposure
    world = scene.world
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (*sky, 1.0)
    bg.inputs["Strength"].default_value = sky_strength
    coll = preview_collection()
    sun = bpy.data.lights.get("PreviewSun") or bpy.data.lights.new("PreviewSun", "SUN")
    sun.energy = sun_power
    sun.color = (1.0, 0.96, 0.92)
    sun.angle = math.radians(1.5)
    ob = bpy.data.objects.get("PreviewSun") or bpy.data.objects.new("PreviewSun", sun)
    if ob.name not in coll.objects:
        coll.objects.link(ob)
    ob.rotation_euler = (math.radians(90 - sun_elev), 0.0, math.radians(sun_az))
    return scene


def _mesh_box(obj):
    vs = [v.co for v in obj.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return [Vector((x, y, z)) for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]


def world_points(o):
    """Углы рамок меша в мировых координатах (по вершинам; для экземпляров коллекций — их содержимое)."""
    if o.instance_type == "COLLECTION" and o.instance_collection:
        pts = []
        for sub in o.instance_collection.all_objects:
            if sub.type == "MESH" and not sub.hide_render:
                pts += [o.matrix_world @ sub.matrix_world @ c for c in _mesh_box(sub)]
        return pts
    if o.type == "MESH":
        return [o.matrix_world @ c for c in _mesh_box(o)]
    return [o.matrix_world.translation.copy()]


def frame_camera(objects, direction=(-1.0, -1.25, 0.55), lens=40.0, margin=1.08, name="PreviewCam",
                 target_offset=(0, 0, 0)):
    """Камера с заданного направления, вписывающая все точки рамок объектов (поиск дистанции)."""
    bpy.context.view_layer.update()
    pts = []
    for o in objects:
        pts += world_points(o)
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    center = (lo + hi) / 2 + Vector(target_offset)
    cam_data = bpy.data.cameras.get(name) or bpy.data.cameras.new(name)
    cam_data.lens = lens
    cam_data.sensor_fit = "HORIZONTAL"
    cam_data.clip_end = 60000
    cam = bpy.data.objects.get(name) or bpy.data.objects.new(name, cam_data)
    if cam.name not in preview_collection().objects:
        preview_collection().objects.link(cam)
    scene = bpy.context.scene
    aspect = scene.render.resolution_x / scene.render.resolution_y
    tan_h = 18.0 / lens / margin
    tan_v = tan_h / aspect
    d = Vector(direction).normalized()
    rotq = (-d).to_track_quat("-Z", "Y")
    inv = rotq.to_matrix().inverted()

    def fits(dist):
        eye = center + d * dist
        for p in pts:
            q = inv @ (p - eye)
            if q.z >= -0.05:
                return False
            if abs(q.x) / -q.z > tan_h or abs(q.y) / -q.z > tan_v:
                return False
        return True

    lo_d, hi_d = 0.1, 10.0
    while not fits(hi_d):
        hi_d *= 2
    for _ in range(40):
        mid = (lo_d + hi_d) / 2
        if fits(mid):
            hi_d = mid
        else:
            lo_d = mid
    cam.location = center + d * hi_d
    cam.rotation_euler = rotq.to_euler()
    scene.camera = cam
    return cam


def render(path):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.image_settings.file_format = "JPEG" if path.suffix.lower() == ".jpg" else "PNG"
    if path.suffix.lower() == ".jpg":
        scene.render.image_settings.quality = 90
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    print("RENDERED", path)


def set_assets_visible(visible):
    """Коллекции ASSETS в превью: показывать оригиналы или только экземпляры."""
    lc = bpy.context.view_layer.layer_collection.children.get("ASSETS")
    if lc:
        lc.exclude = not visible


def lineup(collections, spacing=1.0, axis="X", start=0.0):
    """Расставить экземпляры коллекций в ряд по оси X или Y (оригиналы — в начале координат).

    spacing < 0 — перекрытие (модули стен встык с нахлёстом, как в уровне)."""
    coll = preview_collection()
    k = 0 if axis == "X" else 1
    x = start
    placed = []
    for c in collections:
        objs = [o for o in c.all_objects if o.type == "MESH" and not o.hide_render]
        xs = [(o.matrix_world @ b)[k] for o in objs for b in _mesh_box(o)]
        w0, w1 = min(xs), max(xs)
        inst = bpy.data.objects.new("inst_" + c.name, None)
        inst.instance_type = "COLLECTION"
        inst.instance_collection = c
        coll.objects.link(inst)
        loc = [0.0, 0.0, 0.0]
        loc[k] = x - w0
        inst.location = loc
        placed.append(inst)
        x += (w1 - w0) + spacing
    return placed, x


def save_blend(path):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0  # без .blend1: исходник пересобирается скриптом
    bpy.ops.wm.save_as_mainfile(filepath=str(path), relative_remap=True, compress=True)
    print("SAVED", path)


def export_collection(coll, path):
    """Экспорт одной коллекции ассета в .glb (без картинок: материалы подменит Godot)."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format="GLB", collection=coll.name, use_active_collection=False,
        use_selection=False, use_visible=False, export_apply=True, export_yup=True,
        export_image_format="NONE", export_vertex_color="ACTIVE", export_all_vertex_colors=False,
        export_normals=True, export_tangents=False, export_materials="EXPORT",
        export_lights=False, export_cameras=False, export_extras=False)
    tris = sum(tri_count(o) for o in coll.all_objects if o.type == "MESH"
               and not o.name.endswith(("-colonly", "-convcolonly")))
    print("EXPORTED", path.name, "TRIS", tris)
    return tris

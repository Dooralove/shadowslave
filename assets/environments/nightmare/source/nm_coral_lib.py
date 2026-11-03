"""Процедурная библиотека кораллового кита Забытого берега (Blender 5.1).

Соглашения:
- 1 unit = 1 м; +Z вверх, +Y — «вперёд» ассета.
- Каждый ассет — отдельная коллекция в ASSETS, origin — центр основания.
- Визуал: `nm_coral_live`, `nm_coral_dead`, `nm_coral_crust`, `nm_coral_ground`,
  `nm_mud_wet`, `nm_bone_aged` (слоты .glb; в Godot подменяются внешними .tres).
- `nm_mask` (COLOR_0): R — AO/грязь, G — кончик, B — мокрота, A — мёртвый коралл.
"""

from __future__ import annotations

import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

import nm_lib as L
import nm_props as P

TAU = 2.0 * math.pi


def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))


# ---------------------------------------------------------------------------
# Базовые формы
# ---------------------------------------------------------------------------
def ellipsoid(rx: float, ry: float, rz: float, center=(0, 0, 0), rot_z=0.0,
              segs=20, rings=12, wobble=0.0, seed=0) -> bmesh.types.BMesh:
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
    off = Vector((seed * 1.7, seed * 2.3, seed * 0.9))
    for v in bm.verts:
        p = v.co.copy()
        s = 1.0 + wobble * noise.noise(p * 1.8 + off)
        v.co = Vector((p.x * rx * s, p.y * ry * s, p.z * rz * s))
    bm.transform(Matrix.Translation(center) @ Matrix.Rotation(rot_z, 4, "Z"))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return bm


def ring_loft(rings, cap_bottom=True, cap_top=True) -> bmesh.types.BMesh:
    bm = bmesh.new()
    vr = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(vr[0])
    for a, b in zip(vr, vr[1:]):
        for k in range(n):
            bm.faces.new((a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]))
    if cap_bottom:
        bm.faces.new(list(reversed(vr[0])))
    if cap_top:
        bm.faces.new(vr[-1])
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return bm


def blade(height: float, width: float, thickness: float, curve=(0.12, 0.06),
          taper=0.62, ridge=0.10, segs=14, rings=12, seed=0) -> bmesh.types.BMesh:
    """Вертикальный плавник/лезвие: эллиптическое сечение, изгиб, рёбра, сужение к вершине."""
    rng = random.Random(seed)
    phase = rng.uniform(0, TAU)
    rows = []
    for j in range(rings + 1):
        t = j / rings
        z = height * t
        w = width * (1.0 - t) ** taper + 0.035
        th = thickness * (1.0 - 0.72 * t) + 0.025
        cx = curve[0] * height * t ** 1.65 + 0.025 * height * math.sin(t * 4.0 + phase) * t
        cy = curve[1] * height * t ** 1.8
        row = []
        for k in range(segs):
            a = TAU * k / segs
            rr = 1.0 + ridge * math.cos(3.0 * a + 1.7 * math.sin(t * 4.0 + phase))
            x = cx + w * math.cos(a) * rr
            y = cy + th * math.sin(a) * (1.0 + 0.16 * math.cos(2.0 * a))
            zz = z + 0.018 * height * math.sin(2.0 * a) * t * (1.0 - t)
            row.append((x, y, zz))
        rows.append(row)
    return ring_loft(rows)


def radial_patch(radius: float, rings=9, segs=40, height_fn=None, thickness=0.45,
                 edge_wobble=0.10, seed=0) -> bmesh.types.BMesh:
    """Круглая/овальная плита с рваным краем: радиальная сетка, верх и низ."""
    rng = random.Random(seed)
    phases = [rng.uniform(0, TAU) for _ in range(3)]
    bm = bmesh.new()
    top = []
    for i in range(rings + 1):
        t = i / rings
        row = []
        count = segs if i else 1
        for k in range(count):
            a = TAU * k / segs
            wob = 1.0 + edge_wobble * (0.55 * math.sin(3 * a + phases[0]) +
                                       0.30 * math.sin(7 * a + phases[1]) +
                                       0.15 * math.sin(11 * a + phases[2]))
            r = radius * t * wob
            x, y = r * math.cos(a), r * math.sin(a)
            h = height_fn(x, y, a, t) if height_fn else 0.0
            row.append(bm.verts.new((x, y, h)))
        top.append(row)
    for k in range(segs):
        bm.faces.new((top[0][0], top[1][k], top[1][(k + 1) % segs]))
    for i in range(1, rings):
        for k in range(segs):
            bm.faces.new((top[i][k], top[i + 1][k], top[i + 1][(k + 1) % segs], top[i][(k + 1) % segs]))
    # Борт и низ.
    rim = [top[rings][k] for k in range(segs)]
    bot = [bm.verts.new((v.co.x, v.co.y, v.co.z - thickness)) for v in rim]
    for k in range(segs):
        bm.faces.new((rim[k], bot[k], bot[(k + 1) % segs], rim[(k + 1) % segs]))
    bm.faces.new(list(reversed(bot)))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return bm


def wedge(length: float, width: float, height: float, thickness=0.45,
          nx=12, ny=10, edge_noise=0.06, seed=0) -> bmesh.types.BMesh:
    """Рампа с плоским наклонным верхом; шум только на бортах и низу."""
    rng = random.Random(seed)
    bm = bmesh.new()
    top = []
    for j in range(ny + 1):
        y = -length / 2 + length * j / ny
        row = []
        for i in range(nx + 1):
            x = -width / 2 + width * i / nx
            z = height * (j / ny)
            edge = min(i, nx - i, j, ny - j)
            if edge < 2:
                x += rng.uniform(-edge_noise, edge_noise) * (1.0 - edge / 2.0)
                z += rng.uniform(-edge_noise * 0.4, edge_noise * 0.4) * (1.0 - edge / 2.0) * (j / ny)
            row.append(bm.verts.new((x, y, z)))
        top.append(row)
    for j in range(ny):
        for i in range(nx):
            bm.faces.new((top[j][i], top[j][i + 1], top[j + 1][i + 1], top[j + 1][i]))
    # Борта и низ.
    ring = [top[0][i] for i in range(nx + 1)] + [top[j][nx] for j in range(1, ny + 1)] + \
           [top[ny][i] for i in range(nx - 1, -1, -1)] + [top[j][0] for j in range(ny - 1, 0, -1)]
    bot = [bm.verts.new((v.co.x, v.co.y, v.co.z - thickness)) for v in ring]
    for k in range(len(ring)):
        bm.faces.new((ring[k], bot[k], bot[(k + 1) % len(ring)], ring[(k + 1) % len(ring)]))
    bm.faces.new(list(reversed(bot)))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return bm


def arch(length_span: float, height: float, tube_r: float, depth: float,
         ribs=2, segs=12, path_segs=18, seed=0) -> list[bmesh.types.BMesh]:
    """Арка из 1–3 сросшихся рёбер; концы стоят на z=0."""
    rng = random.Random(seed)
    parts = []
    for r in range(ribs):
        y = (r - (ribs - 1) / 2) * depth
        path = []
        for i in range(path_segs + 1):
            a = math.pi * i / path_segs
            x = 0.5 * length_span * math.cos(a)
            z = height * math.sin(a)
            path.append(Vector((x, y + 0.08 * math.sin(a * 5 + seed), z)))
        rr = tube_r * (0.85 + 0.25 * rng.random())
        parts.append(P.tube(path, rr, segs=segs,
                            radius_fn=lambda t: 0.72 + 0.35 * math.sin(math.pi * t) ** 0.6))
    # Пятки у основания.
    for sx in (-1, 1):
        parts.append(ellipsoid(tube_r * 1.7, tube_r * 1.35, tube_r * 1.4,
                               center=(sx * length_span * 0.46, 0, tube_r * 0.8),
                               segs=16, rings=10, wobble=0.18, seed=seed + int(sx)))
    return parts


def tunnel_shell(length: float, r_out: float, r_in: float, segs=28, rings=12,
                 bend=0.0, seed=0) -> bmesh.types.BMesh:
    """Толстая труба-туннель с полостью; ось Y, полость круглая, origin — центр основания."""
    bm = bmesh.new()
    outer, inner = [], []
    for i in range(rings + 1):
        t = i / rings
        y = -length / 2 + length * t
        cx = bend * math.sin(math.pi * t)
        ro = r_out * (1.0 + 0.055 * math.sin(6 * math.pi * t + seed) + 0.035 * math.sin(13 * t + seed * 2))
        row_o, row_i = [], []
        for k in range(segs):
            a = TAU * k / segs
            # Лёгкая вертикальная ребристость снаружи; внутренняя поверхность гладкая.
            rr = ro * (1.0 + 0.035 * math.cos(7 * a + 0.6 * math.sin(t * 5 + seed)))
            row_o.append(bm.verts.new((cx + rr * math.cos(a), y, r_in + rr * math.sin(a))))
            row_i.append(bm.verts.new((cx + r_in * math.cos(a), y, r_in + r_in * math.sin(a))))
        outer.append(row_o)
        inner.append(row_i)
    for a, b in zip(outer, outer[1:]):
        for k in range(segs):
            bm.faces.new((a[k], a[(k + 1) % segs], b[(k + 1) % segs], b[k]))
    for a, b in zip(inner, inner[1:]):
        for k in range(segs):
            bm.faces.new((a[(k + 1) % segs], a[k], b[k], b[(k + 1) % segs]))
    # Торцы-кольца.
    for io, ii, rev in ((outer[0], inner[0], True), (outer[-1], inner[-1], False)):
        for k in range(segs):
            q = (io[k], io[(k + 1) % segs], ii[(k + 1) % segs], ii[k])
            bm.faces.new(q if rev else tuple(reversed(q)))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return bm


def fan(radius: float, height_scale: float, thickness=0.10, spread=1.0,
        ribs=9, nu=20, nv=10, seed=0) -> bmesh.types.BMesh:
    """Веер: вертикальная радиальная пластина с рёбрами; не «дерево»."""
    bm = bmesh.new()
    rows = []
    for j in range(nv + 1):
        t = j / nv
        r = 0.15 + (radius - 0.15) * t
        row = []
        for i in range(nu + 1):
            u = -spread + 2.0 * spread * i / nu
            x = r * math.sin(u)
            z = r * math.cos(u) * height_scale
            y = 0.06 * math.sin(u * ribs + seed) * r * t
            row.append(bm.verts.new((x, y, z)))
        rows.append(row)
    for j in range(nv):
        for i in range(nu):
            bm.faces.new((rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]))
    geom = list(bm.faces)
    bmesh.ops.solidify(bm, geom=geom, thickness=thickness)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return bm


def brain(radius: float, height_scale=0.55, segs=48, rings=24, seed=0) -> bmesh.types.BMesh:
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
    off = Vector((seed * 1.3, seed * 2.1, seed * 0.7))
    for v in bm.verts:
        p = v.co.copy()
        a = math.atan2(p.y, p.x)
        grooves = 1.0 + 0.045 * math.sin(7.0 * a + 5.0 * p.z + 1.2 * noise.noise(p * 2.0 + off))
        grooves += 0.025 * noise.noise(p * 5.0 + off)
        v.co = Vector((p.x * radius * grooves, p.y * radius * grooves, p.z * radius * height_scale * grooves))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return bm


# ---------------------------------------------------------------------------
# Детализация, слияние, маски
# ---------------------------------------------------------------------------
def coral_detail(obj, seed: int, size: float, amp=0.035, ridge=0.018, micro=0.008):
    off = Vector((seed * 1.7, seed * 3.1, seed * 2.3))

    def fn(co, n):
        p = co / max(size, 0.2)
        d = amp * size * L.fbm(p * 1.7 + off, 3)
        d += micro * size * L.fbm(p * 5.5 + off * 1.7, 2)
        # Вертикальные жёлоба/рёбра: сильнее на боковых поверхностях.
        side = 1.0 - abs(n.z)
        d += ridge * size * side * math.sin(co.x * 4.2 + co.y * 3.1 +
                                            2.0 * noise.noise(p * 2.0 + off))
        return d

    L.displace(obj, fn)


def recenter_base(obj, sink=0.02):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    zmin = min(v.co.z for v in bm.verts)
    xs = [v.co.x for v in bm.verts]
    ys = [v.co.y for v in bm.verts]
    cx, cy = (min(xs) + max(xs)) * 0.5, (min(ys) + max(ys)) * 0.5
    for v in bm.verts:
        v.co.x -= cx
        v.co.y -= cy
        v.co.z -= zmin + sink
    bm.to_mesh(obj.data)
    bm.free()


def clean_mesh(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.0008)
    bmesh.ops.dissolve_degenerate(bm, dist=0.0008, edges=list(bm.edges))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.validate(verbose=False, clean_customdata=False)
    obj.data.update()
    return obj


def fuse(name, parts, coll, mat, voxel=0.12, target_tris=8000, seed=0, size=2.0,
         smooth_iter=2, cut_z=None, sink=0.02, detail=True, mask=True,
         tip_start=0.55, flat_wet=None) -> bpy.types.Object:
    bm = L.join_bmeshes([(p, Matrix.Identity(4)) for p in parts])
    obj = L.object_from_bmesh(name, bm, coll, mat)
    L.voxel_remesh(obj, voxel)
    if smooth_iter:
        L.smooth(obj, 0.5, smooth_iter)
    if detail:
        coral_detail(obj, seed, size)
    L.decimate(obj, target_tris)
    clean_mesh(obj)
    if cut_z is not None:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        L.cut_base(bm, cut_z, keep="above")
        bm.to_mesh(obj.data)
        bm.free()
    recenter_base(obj, sink)
    L.shade(obj, 42.0)
    if mask:
        bake_coral_mask(obj, seed=seed, rays=6, ao_dist=1.1, tip_start=tip_start, flat_wet=flat_wet)
    return obj


def _hemisphere(rng: random.Random, n: Vector, count: int):
    t = n.orthogonal().normalized()
    b = n.cross(t)
    out = []
    for _ in range(count):
        u1, u2 = rng.random(), rng.random()
        rr = math.sqrt(u1)
        th = TAU * u2
        x, y = rr * math.cos(th), rr * math.sin(th)
        z = math.sqrt(max(0.0, 1.0 - u1))
        out.append((t * x + b * y + n * z).normalized())
    return out


def bake_coral_mask(obj, seed=0, rays=7, ao_dist=1.2, wet_strength=0.75,
                    dead_strength=0.45, tip_start=0.42, flat_wet=None):
    """COLOR: R AO/грязь, G кончик, B мокрота, A мёртвый коралл."""
    from mathutils.bvhtree import BVHTree
    rng = random.Random(seed)
    mesh = obj.data
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.transform(obj.matrix_world)
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    mw = obj.matrix_world
    nmat = mw.to_3x3().inverted().transposed()
    zs = [v.co.z for v in mesh.vertices]
    zmin, zmax = min(zs), max(zs)
    h = max(zmax - zmin, 0.1)
    off = Vector((seed * 3.1, seed * 1.7, seed * 2.3))
    vals = []
    for v in mesh.vertices:
        co = mw @ v.co
        n = (nmat @ v.normal).normalized()
        origin = co + n * 0.008
        hits = 0
        for d in _hemisphere(rng, n, rays):
            if tree.ray_cast(origin, d, ao_dist)[0] is not None:
                hits += 1
        ao = 1.0 - hits / rays
        ao = 0.42 + 0.58 * ao ** 1.15
        up = max(0.0, n.z)
        t = (co.z - zmin) / h
        tip_noise = 0.10 * noise.noise(co * 0.9 + off)
        tip = clamp((t - tip_start) / max(1.0 - tip_start, 1e-3) + tip_noise, 0.0, 1.0)
        tip *= 0.55 + 0.45 * up
        if flat_wet is None:
            wet = clamp(1.0 - (co.z - zmin) / (h * 0.62) + 0.12 * noise.noise(co * 0.7 + off), 0.0, 1.0)
        else:
            wet = flat_wet
        dead = clamp(0.5 + 0.9 * noise.noise(co * 0.45 + off * 2.0) - 0.55 * tip, 0.0, 1.0)
        vals.append((ao, tip * 0.9, wet * wet_strength, dead * dead_strength))
    attr = mesh.color_attributes.get(L.MASK_ATTR) or mesh.color_attributes.new(
        L.MASK_ATTR, "FLOAT_COLOR", "POINT")
    for i, val in enumerate(vals):
        attr.data[i].color = val
    L.set_active_mask(mesh)
    return obj


def bone_mask(obj, seed=0):
    L.plain_masks(obj, (1.0, 0.05, 0.18, 0.0))
    return obj


# ---------------------------------------------------------------------------
# Материалы для превью Blender
# ---------------------------------------------------------------------------
def _img(name):
    p = L.TEX_DIR / name
    if not p.exists():
        raise FileNotFoundError(p)
    img = bpy.data.images.get(name)
    if img is None:
        img = bpy.data.images.load(str(p), check_existing=True)
    return img


def preview_material(name: str, spec: dict, texsets: dict) -> bpy.types.Material:
    """Principled-приближение Godot-шейдера для превью: triplanar BOX, кончики, мокрота."""
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    bsdf.inputs["Metallic"].default_value = spec.get("metallic", 0.0)
    bsdf.inputs["IOR"].default_value = 1.42
    base = texsets[spec["base"]]
    # TexCoord -> Mapping -> BOX-текстуры.
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1.0 / base["tile"],) * 3
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    alb = nt.nodes.new("ShaderNodeTexImage")
    alb.image = _img(base["albedo"])
    alb.projection = "BOX"
    alb.projection_blend = 0.3
    nt.links.new(mp.outputs["Vector"], alb.inputs["Vector"])
    tint_mix = nt.nodes.new("ShaderNodeMix")
    tint_mix.data_type = "RGBA"
    tint_mix.blend_type = "MULTIPLY"
    tint_mix.inputs["Factor"].default_value = 1.0
    nt.links.new(alb.outputs["Color"], tint_mix.inputs["A"])
    tint_mix.inputs["B"].default_value = (*spec.get("tint", (1.0, 1.0, 1.0)), 1.0)
    nor = nt.nodes.new("ShaderNodeTexImage")
    nor.image = _img(base["normal"])
    nor.projection = "BOX"
    nor.projection_blend = 0.3
    nor.image.colorspace_settings.name = "Non-Color"
    nt.links.new(mp.outputs["Vector"], nor.inputs["Vector"])
    arm = nt.nodes.new("ShaderNodeTexImage")
    arm.image = _img(base["arm"])
    arm.projection = "BOX"
    arm.projection_blend = 0.3
    arm.image.colorspace_settings.name = "Non-Color"
    nt.links.new(mp.outputs["Vector"], arm.inputs["Vector"])
    nrm = nt.nodes.new("ShaderNodeNormalMap")
    nrm.inputs["Strength"].default_value = spec.get("normal", 1.0)
    nt.links.new(nor.outputs["Color"], nrm.inputs["Color"])
    micro = nt.nodes.new("ShaderNodeTexNoise")
    micro.inputs["Scale"].default_value = 9.0
    micro.inputs["Detail"].default_value = 8.0
    micro.inputs["Roughness"].default_value = 0.62
    nt.links.new(tc.outputs["Object"], micro.inputs["Vector"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.28
    bump.inputs["Distance"].default_value = 0.08
    nt.links.new(micro.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(nrm.outputs["Normal"], bump.inputs["Normal"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    # Roughness из ARM.G.
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(arm.outputs["Color"], sep.inputs["Color"])
    rough = nt.nodes.new("ShaderNodeMath")
    rough.operation = "MULTIPLY_ADD"
    rough.inputs[1].default_value = spec.get("rough_scale", 1.0)
    rough.inputs[2].default_value = spec.get("rough_offset", 0.0)
    nt.links.new(sep.outputs["Green"], rough.inputs[0])
    nt.links.new(rough.outputs[0], bsdf.inputs["Roughness"])
    # Базовый цвет: альбедо, слегка притемнённое AO из ARM.R.
    ao_mix = nt.nodes.new("ShaderNodeMix")
    ao_mix.data_type = "RGBA"
    ao_mix.blend_type = "MULTIPLY"
    ao_mix.inputs["Factor"].default_value = 0.35
    nt.links.new(tint_mix.outputs["Result"], ao_mix.inputs["A"])
    ao_sep = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(sep.outputs["Red"], ao_sep.inputs["X"])
    nt.links.new(sep.outputs["Red"], ao_sep.inputs["Y"])
    nt.links.new(sep.outputs["Red"], ao_sep.inputs["Z"])
    nt.links.new(ao_sep.outputs["Vector"], ao_mix.inputs["B"])
    color_out = ao_mix.outputs["Result"]
    # Вершинные каналы: G — кончик, A — мёртвый, B — мокрота.
    vc = nt.nodes.new("ShaderNodeAttribute")
    vc.attribute_name = L.MASK_ATTR
    vc.attribute_type = "GEOMETRY"
    vsep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(vc.outputs["Color"], vsep.inputs["Color"])
    if spec.get("tip_strength", 0) > 0:
        mix_tip = nt.nodes.new("ShaderNodeMix")
        mix_tip.data_type = "RGBA"
        mix_tip.blend_type = "MIX"
        nt.links.new(color_out, mix_tip.inputs["A"])
        mix_tip.inputs["B"].default_value = (*spec.get("tip_color", (0.47, 0.15, 0.13)), 1.0)
        tip_mul = nt.nodes.new("ShaderNodeMath")
        tip_mul.operation = "MULTIPLY"
        tip_mul.inputs[1].default_value = spec.get("tip_strength", 0)
        nt.links.new(vsep.outputs["Green"], tip_mul.inputs[0])
        nt.links.new(tip_mul.outputs[0], mix_tip.inputs["Factor"])
        color_out = mix_tip.outputs["Result"]
    if spec.get("dead_strength", 0) > 0:
        mix_dead = nt.nodes.new("ShaderNodeMix")
        mix_dead.data_type = "RGBA"
        mix_dead.blend_type = "MIX"
        nt.links.new(color_out, mix_dead.inputs["A"])
        mix_dead.inputs["B"].default_value = (*spec.get("dead_color", (0.15, 0.09, 0.08)), 1.0)
        dead_mul = nt.nodes.new("ShaderNodeMath")
        dead_mul.operation = "MULTIPLY"
        dead_mul.inputs[1].default_value = spec.get("dead_strength", 0)
        nt.links.new(vc.outputs["Alpha"], dead_mul.inputs[0])
        nt.links.new(dead_mul.outputs[0], mix_dead.inputs["Factor"])
        color_out = mix_dead.outputs["Result"]
    nt.links.new(color_out, bsdf.inputs["Base Color"])
    # Wetness: темнее и глаже.
    wet_math = nt.nodes.new("ShaderNodeMath")
    wet_math.operation = "MULTIPLY"
    wet_math.inputs[1].default_value = spec.get("wet_strength", 0.35)
    nt.links.new(vsep.outputs["Blue"], wet_math.inputs[0])
    wet_mix = nt.nodes.new("ShaderNodeMix")
    wet_mix.data_type = "RGBA"
    wet_mix.blend_type = "MIX"
    nt.links.new(wet_math.outputs[0], wet_mix.inputs["Factor"])
    nt.links.new(color_out, wet_mix.inputs["A"])
    wet_mix.inputs["B"].default_value = (0.08, 0.05, 0.05, 1.0)
    nt.links.new(wet_mix.outputs["Result"], bsdf.inputs["Base Color"])
    if spec.get("sss", 0) > 0:
        bsdf.inputs["Subsurface Weight"].default_value = spec["sss"]
        bsdf.inputs["Subsurface Radius"].default_value = (0.15, 0.05, 0.04)
    return mat

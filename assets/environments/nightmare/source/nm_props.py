"""Детали реквизита: доски, цилиндры, кольца, токарные тела, трубки по пути, звенья цепи.

Каждая функция возвращает `bmesh` с UV в метрах, построенный в локальных осях детали
(волокно дерева и рисунок ткани — вдоль длины: V по длинной оси), затем деталь ставится
матрицей. `Assembly` собирает детали по материалам в один объект со слотами `nm_*`.
"""

import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

import nm_lib as L

I = Matrix.Identity(4)


def rot(deg, axis):
    return Matrix.Rotation(math.radians(deg), 4, axis)


def T(x, y, z):
    return Matrix.Translation((x, y, z))


class Assembly:
    """Набор деталей → один объект; детали одного материала сливаются в одну поверхность."""

    def __init__(self, name, coll):
        self.name = name
        self.coll = coll
        self.parts = {}

    def add(self, bm, mat, m=I):
        bm.transform(m)
        self.parts.setdefault(mat, []).append(bm)
        return bm

    def build(self):
        objs = []
        for mat, bms in self.parts.items():
            out = bmesh.new()
            for bm in bms:
                tmp = bpy.data.meshes.new("_p")
                bm.to_mesh(tmp)
                bm.free()
                out.from_mesh(tmp)
                bpy.data.meshes.remove(tmp)
            objs.append(L.object_from_bmesh(f"{self.name}_{mat}", out, self.coll, mat))
        return objs


def _uv_along(bm, axis_len, tile=1.0):
    """UV по граням: проекция на две оси плоскости грани; длинная ось детали → V (волокно)."""
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        others = [i for i in range(3) if i != ax]
        if axis_len in others:
            v_ax = axis_len
            u_ax = others[0] if others[1] == axis_len else others[1]
        else:
            u_ax, v_ax = others
        for loop in f.loops:
            c = loop.vert.co
            loop[uv].uv = (c[u_ax] / tile, c[v_ax] / tile)
    return bm


def board(sx, sy, sz, bevel=0.006, seed=0, warp=0.0):
    """Брусок/доска с фаской. Волокно — вдоль самой длинной стороны. warp — лёгкое коробление."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bm.transform(Matrix.Diagonal((sx, sy, sz, 1.0)))
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=min(bevel, min(sx, sy, sz) * 0.3), segments=1,
                        profile=0.5, affect="EDGES")
    long_ax = max(range(3), key=lambda i: (sx, sy, sz)[i])
    if warp:
        r = random.Random(seed)
        k = r.uniform(-warp, warp)
        ln = (sx, sy, sz)[long_ax]
        for v in bm.verts:
            t = v.co[long_ax] / ln * 2
            v.co.z += k * (1 - t * t) if long_ax != 2 else 0.0
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return _uv_along(bm, long_ax)


def cylinder(radius, length, segs=12, axis="Z", radius2=None, cap=True):
    """Цилиндр (или усечённый конус) вдоль оси; UV: U — по окружности, V — вдоль оси."""
    bm = bmesh.new()
    r2 = radius if radius2 is None else radius2
    rings = []
    for k, (z, r) in enumerate(((-length / 2, radius), (length / 2, r2))):
        rings.append([bm.verts.new((r * math.cos(2 * math.pi * i / segs), r * math.sin(2 * math.pi * i / segs), z))
                      for i in range(segs)])
    side = []
    for i in range(segs):
        j = (i + 1) % segs
        side.append(bm.faces.new((rings[0][i], rings[0][j], rings[1][j], rings[1][i])))
    if cap:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[1])
    uv = bm.loops.layers.uv.verify()
    circ = 2 * math.pi * max(radius, r2)
    for f in bm.faces:
        for loop in f.loops:
            c = loop.vert.co
            if f in side:
                a = math.atan2(c.y, c.x) % (2 * math.pi)
                if a < 1e-4 and any(math.atan2(l.vert.co.y, l.vert.co.x) % (2 * math.pi) > math.pi for l in f.loops):
                    a = 2 * math.pi
                loop[uv].uv = (a / (2 * math.pi) * circ, c.z)
            else:
                loop[uv].uv = (c.x, c.y)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    if axis == "X":
        bm.transform(rot(90, "Y"))
    elif axis == "Y":
        bm.transform(rot(-90, "X"))
    return bm


def ring_rect(r_in, r_out, width, segs=32, axis="X"):
    """Плоское кольцо прямоугольного сечения (обод колеса, шина, обруч), ось — axis."""
    bm = bmesh.new()
    prof = [(r_in, -width / 2), (r_out, -width / 2), (r_out, width / 2), (r_in, width / 2)]
    rings = []
    for i in range(segs):
        a = 2 * math.pi * i / segs
        rings.append([bm.verts.new((r * math.cos(a), r * math.sin(a), z)) for r, z in prof])
    for i in range(segs):
        a, b = rings[i], rings[(i + 1) % segs]
        for k in range(4):
            bm.faces.new((a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        for loop in f.loops:
            c = loop.vert.co
            a = math.atan2(c.y, c.x)
            loop[uv].uv = (c.z + math.hypot(c.x, c.y), a * r_out)
    if axis == "X":
        bm.transform(rot(90, "Y"))
    elif axis == "Y":
        bm.transform(rot(-90, "X"))
    return bm


def lathe(profile, segs=24, close_top=True, close_bottom=True):
    """Тело вращения вокруг Z: profile — [(r, z), ...] снизу вверх."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        rings.append([bm.verts.new((r * math.cos(2 * math.pi * i / segs), r * math.sin(2 * math.pi * i / segs), z))
                      for i in range(segs)])
    for a, b in zip(rings, rings[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if close_bottom:
        bm.faces.new(list(reversed(rings[0])))
    if close_top:
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    uv = bm.loops.layers.uv.verify()
    rmax = max(r for r, _ in profile)
    for f in bm.faces:
        for loop in f.loops:
            c = loop.vert.co
            loop[uv].uv = ((math.atan2(c.y, c.x) % (2 * math.pi)) * rmax, c.z)
    return bm


def tube(path, radius, segs=8, radius_fn=None, closed=False, cap=True):
    """Трубка по пути (кости, рёбра, ветки, ремни): path — список Vector, радиус по t∈[0,1]."""
    bm = bmesh.new()
    n = len(path)
    rings = []
    prev_side = None
    for i, p in enumerate(path):
        t = i / (n - 1)
        if closed:
            tan = (path[(i + 1) % n] - path[i - 1]).normalized()
        else:
            tan = (path[min(i + 1, n - 1)] - path[max(i - 1, 0)]).normalized()
        side = prev_side if prev_side is not None else tan.orthogonal().normalized()
        side = (side - tan * side.dot(tan)).normalized()
        prev_side = side
        up = tan.cross(side).normalized()
        r = radius * (radius_fn(t) if radius_fn else 1.0)
        rings.append([bm.verts.new(p + (side * math.cos(2 * math.pi * k / segs) + up * math.sin(2 * math.pi * k / segs)) * r)
                      for k in range(segs)])
    pairs = list(zip(rings, rings[1:])) + ([(rings[-1], rings[0])] if closed else [])
    for a, b in pairs:
        for k in range(segs):
            bm.faces.new((a[k], a[(k + 1) % segs], b[(k + 1) % segs], b[k]))
    if cap and not closed:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    uv = bm.loops.layers.uv.verify()
    lengths = [0.0]
    for a, b in zip(path, path[1:]):
        lengths.append(lengths[-1] + (b - a).length)
    vidx = {}
    for i, ring in enumerate(rings):
        for k, v in enumerate(ring):
            vidx[v] = (k / segs * 2 * math.pi * radius, lengths[i])
    for f in bm.faces:
        for loop in f.loops:
            loop[uv].uv = vidx.get(loop.vert, (0.0, 0.0))
    return bm


def chain_link(length=0.11, width=0.065, wire=0.009, segs=6, path_segs=16):
    """Овальное звено (стадион), длинная ось — X, плоскость — XY."""
    straight = length - width
    rr = (width - wire * 2) / 2 + wire
    pts = []
    for i in range(path_segs):
        t = i / path_segs
        perim = 2 * straight + 2 * math.pi * rr
        d = t * perim
        if d < straight:
            pts.append(Vector((-straight / 2 + d, -rr, 0)))
        elif d < straight + math.pi * rr:
            a = (d - straight) / rr - math.pi / 2
            pts.append(Vector((straight / 2 + rr * math.cos(a), rr * math.sin(a), 0)))
        elif d < 2 * straight + math.pi * rr:
            dd = d - straight - math.pi * rr
            pts.append(Vector((straight / 2 - dd, rr, 0)))
        else:
            a = (d - 2 * straight - math.pi * rr) / rr + math.pi / 2
            pts.append(Vector((-straight / 2 + rr * math.cos(a), rr * math.sin(a), 0)))
    return tube(pts, wire, segs=segs, closed=True)


def chain_along(asm, path_fn, n_links, mat="nm_iron", link=(0.11, 0.065, 0.009), sag_twist=0.0, seed=0):
    """Цепь по кривой path_fn(t) → Vector: звенья через шаг, каждое следующее повёрнуто на 90°."""
    length, width, wire = link
    pitch = length - 2 * wire * 1.1
    r = random.Random(seed)
    # Перепараметризация по длине дуги.
    samples = [path_fn(i / 400) for i in range(401)]
    acc = [0.0]
    for a, b in zip(samples, samples[1:]):
        acc.append(acc[-1] + (b - a).length)
    total = acc[-1]

    def at(s):
        s = max(0.0, min(total, s))
        for i in range(1, len(acc)):
            if acc[i] >= s:
                t = (s - acc[i - 1]) / max(1e-9, acc[i] - acc[i - 1])
                return samples[i - 1].lerp(samples[i], t), (samples[i] - samples[i - 1]).normalized()
        return samples[-1], (samples[-1] - samples[-2]).normalized()

    for k in range(n_links):
        s = pitch * (k + 0.5)
        if s > total:
            break
        p, tan = at(s)
        q = tan.to_track_quat("X", "Z")
        twist = (90.0 if k % 2 else 0.0) + r.uniform(-8, 8) + sag_twist
        m = Matrix.Translation(p) @ q.to_matrix().to_4x4() @ rot(twist, "X")
        asm.add(chain_link(length, width, wire), mat, m)
    return asm


def deform(bm, fn):
    for v in bm.verts:
        v.co = fn(v.co.copy())
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return bm


def finish_prop(objs, seed=0, ao=0.4, ground=True, merge_name=None, coll=None, sharp=35.0, uv=False):
    """Маски AO для всех частей (с учётом соседних частей), слияние в один объект."""
    for i, o in enumerate(objs):
        others = [x for x in objs if x is not o]
        L.bake_masks(o, seed=seed + i, rays=16, ao_dist=ao, ground=ground, base_dark=0.0, tint_var=0.05,
                     extra_occluders=others)
    obj = L.merge_objects(merge_name, objs, coll) if merge_name else objs[0]
    L.shade(obj, sharp)
    obj.data.validate()
    return obj

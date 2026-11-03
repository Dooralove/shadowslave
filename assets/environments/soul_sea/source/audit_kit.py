"""Read-only Blender audit of the Soul Sea kit: bounds, origins, topology, slots."""
from __future__ import annotations

import bmesh
import bpy
from mathutils import Vector


def tris(me):
    return sum(max(0, len(p.vertices) - 2) for p in me.polygons)


def main():
    print("ASSET|MESH|TRIS|DIMS|ZMIN|ORIGIN_XY_OFFSET|MATS|UV|COLOR|NONMANIFOLD")
    for coll in sorted(bpy.data.collections, key=lambda c: c.name):
        if not coll.name.startswith("ss_"):
            continue
        for obj in sorted(coll.objects, key=lambda o: o.name):
            if obj.type != "MESH":
                continue
            me = obj.data
            pts = [obj.matrix_world @ v.co for v in me.vertices]
            if not pts:
                continue
            lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
            hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
            center = (lo + hi) * 0.5
            origin = obj.matrix_world.translation
            bm = bmesh.new()
            bm.from_mesh(me)
            nonman = sum(1 for e in bm.edges if not e.is_manifold)
            bm.free()
            mats = ",".join(m.name if m else "None" for m in me.materials)
            uvs = ",".join(u.name for u in me.uv_layers)
            cols = ",".join(c.name for c in me.color_attributes)
            print("%s|%s|%d|%.2fx%.2fx%.2f|%.3f|%.3f,%.3f|%s|%s|%s|%d" % (
                obj.name, me.name, tris(me), hi.x - lo.x, hi.y - lo.y, hi.z - lo.z,
                lo.z, origin.x - center.x, origin.y - center.y, mats, uvs, cols, nonman))


if __name__ == "__main__":
    main()

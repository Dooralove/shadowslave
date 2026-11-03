import bpy
import bmesh
import os

GLB = r"C:\Users\user\Desktop\shadowslave\assets\characters\generated\sunny_real_v3\sunny_real_v3.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)

mesh_objs = [o for o in bpy.context.scene.objects if o.type == 'MESH']
print("MESH_OBJECTS", [(o.name, len(o.data.vertices), len(o.data.polygons)) for o in mesh_objs])
for obj in mesh_objs:
    print("OBJECT", obj.name, "verts", len(obj.data.vertices), "polys", len(obj.data.polygons))
    # Connected components via bmesh
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    seen = set()
    comps = []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack = [v]
        comp = []
        seen.add(v.index)
        while stack:
            cur = stack.pop()
            comp.append(cur.index)
            for e in cur.link_edges:
                other = e.other_vert(cur)
                if other.index not in seen:
                    seen.add(other.index)
                    stack.append(other)
        comps.append(comp)
    print("COMPONENTS", len(comps))
    comps.sort(key=len, reverse=True)
    for i, comp in enumerate(comps[:20]):
        xs = [bm.verts[j].co.x for j in comp]
        ys = [bm.verts[j].co.y for j in comp]
        zs = [bm.verts[j].co.z for j in comp]
        print(f"  comp {i}: verts={len(comp)} x=({min(xs):.3f},{max(xs):.3f}) y=({min(ys):.3f},{max(ys):.3f}) z=({min(zs):.3f},{max(zs):.3f})")
    bm.free()

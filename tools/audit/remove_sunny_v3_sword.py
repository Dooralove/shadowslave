import bpy
import bmesh
import math
import os

GLB = r"C:\Users\user\Desktop\shadowslave\assets\characters\generated\sunny_real_v3\sunny_real_v3.glb"
OUT = r"C:\Users\user\AppData\Local\Temp\opencode\sunny_v3_sword"

os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)

obj = bpy.data.objects.get("model")
if obj is None:
    obj = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]

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
comps.sort(key=len, reverse=True)

# Print candidate thin/long components.
for i, comp in enumerate(comps[:25]):
    xs = [bm.verts[j].co.x for j in comp]
    ys = [bm.verts[j].co.y for j in comp]
    zs = [bm.verts[j].co.z for j in comp]
    dx, dy, dz = max(xs)-min(xs), max(ys)-min(ys), max(zs)-min(zs)
    if max(dx, dy, dz) > 0.4 and min(dx, dy) < 0.15:
        print(f"CANDIDATE {i}: verts={len(comp)} dims=({dx:.3f},{dy:.3f},{dz:.3f}) bbox=({min(xs):.3f},{max(xs):.3f};{min(ys):.3f},{max(ys):.3f};{min(zs):.3f},{max(zs):.3f})")

# Delete component 2 (blade) and component 14 (handle candidate) if they look like the sword.
to_delete = []
for idx in (2, 14):
    if idx < len(comps):
        to_delete.extend(comps[idx])
print("DELETING", len(to_delete), "verts")
bmesh.ops.delete(bm, geom=[bm.verts[i] for i in to_delete], context='VERTS')
bm.to_mesh(obj.data)
bm.free()
obj.data.update()

# Simple studio render.
scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 900
scene.render.resolution_y = 900
scene.render.film_transparent = False
scene.world = bpy.data.worlds.new("W")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.03, 0.035, 0.045, 1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = 1.0

# Camera front (-Y in Blender after glTF import, character faces +Y? use -Y).
cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
cam.location = (1.4, -4.6, 1.35)
cam.rotation_euler = (math.radians(80), 0, math.radians(17))
cam_data.lens = 55
scene.camera = cam

for loc, energy, color, size in [((-2.5, -3.0, 3.2), 900, (1.0, 0.92, 0.82), 3.0),
                                  ((2.8, -2.0, 2.0), 350, (0.48, 0.64, 1.0), 3.0),
                                  ((0.0, 2.5, 2.8), 500, (0.62, 0.72, 1.0), 3.0)]:
    light_data = bpy.data.lights.new("L", type='AREA')
    light_data.energy = energy
    light_data.color = color
    light_data.size = size
    light = bpy.data.objects.new("L", light_data)
    scene.collection.objects.link(light)
    light.location = loc
    direction = (0, 0, 1.0)
    import mathutils
    light.rotation_euler = (mathutils.Vector(direction) - mathutils.Vector(loc)).to_track_quat('-Z', 'Y').to_euler()

scene.render.filepath = os.path.join(OUT, "sword_removed.png")
bpy.ops.render.render(write_still=True)
print("RENDER", scene.render.filepath)

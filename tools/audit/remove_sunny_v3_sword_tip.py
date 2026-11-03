import bpy
import bmesh
import math
import os
import mathutils

GLB = r"C:\Users\user\Desktop\shadowslave\assets\characters\generated\sunny_real_v3\sunny_real_v3.glb"
OUT = r"C:\Users\user\AppData\Local\Temp\opencode\sunny_v3_sword_test"
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
obj = bpy.data.objects.get("model")
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
# Same order as the z-sorted listing.
comps.sort(key=lambda c: min(bm.verts[j].co.z for j in c), reverse=True)
to_delete = []
for idx in range(36, 46):
    if idx < len(comps):
        to_delete.extend(comps[idx])
print("DELETE_VERTS", len(to_delete))
bmesh.ops.delete(bm, geom=[bm.verts[i] for i in to_delete], context='VERTS')
bm.to_mesh(obj.data)
bm.free()
obj.data.update()

# Render with the original materials.
scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 900
scene.render.resolution_y = 900
scene.world = bpy.data.worlds.new("W")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.03, 0.035, 0.045, 1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
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
    light.rotation_euler = (mathutils.Vector((0, 0, 1.0)) - mathutils.Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
scene.render.filepath = os.path.join(OUT, "sword_tip_removed.png")
bpy.ops.render.render(write_still=True)
print("RENDER", scene.render.filepath)

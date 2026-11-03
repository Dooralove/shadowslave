import bpy
import bmesh
import math
import os
import random
import mathutils

GLB = r"C:\Users\user\Desktop\shadowslave\assets\characters\generated\sunny_real_v3\sunny_real_v3.glb"
OUT = r"C:\Users\user\AppData\Local\Temp\opencode\sunny_v3_parts_render"
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)

model = bpy.data.objects.get("model")
if model is None:
    model = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]

# Duplicate and separate loose parts.
bpy.context.view_layer.objects.active = model
model.select_set(True)
bpy.ops.object.duplicate()
dup = bpy.context.view_layer.objects.active
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.separate(type='LOOSE')
bpy.ops.object.mode_set(mode='OBJECT')
parts = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.name.startswith(dup.name)]
print("PARTS", len(parts))

# Sort by vertex count and print.
rows = []
for o in parts:
    bb = [o.matrix_world @ mathutils.Vector(c) for c in o.bound_box]
    xs = [v.x for v in bb]; ys = [v.y for v in bb]; zs = [v.z for v in bb]
    dims = (max(xs)-min(xs), max(ys)-min(ys), max(zs)-min(zs))
    center = ((max(xs)+min(xs))/2, (max(ys)+min(ys))/2, (max(zs)+min(zs))/2)
    rows.append((o, len(o.data.vertices), dims, center, (min(xs),max(xs),min(ys),max(ys),min(zs),max(zs))))
rows.sort(key=lambda r: r[1], reverse=True)
for i, (o, nv, dims, center, bb) in enumerate(rows[:40]):
    print(f"PART {i:02d} {o.name} verts={nv} dims=({dims[0]:.3f},{dims[1]:.3f},{dims[2]:.3f}) center=({center[0]:.3f},{center[1]:.3f},{center[2]:.3f}) bbox={bb}")

# Material: gray default, red for thin/long candidates near the right hand.
mat_gray = bpy.data.materials.new("gray")
mat_gray.use_nodes = True
mat_gray.node_tree.nodes["Principled BSDF"].inputs[0].default_value = (0.55, 0.55, 0.58, 1)
mat_red = bpy.data.materials.new("red")
mat_red.use_nodes = True
mat_red.node_tree.nodes["Principled BSDF"].inputs[0].default_value = (0.9, 0.05, 0.05, 1)

for i, (o, nv, dims, center, bb) in enumerate(rows):
    o.data.materials.clear()
    o.data.materials.append(mat_gray)
    # Long and thin: max dimension > 0.3, second/third < 0.12
    thin = max(dims) > 0.3 and sorted(dims)[1] < 0.12
    if thin:
        o.data.materials.clear()
        o.data.materials.append(mat_red)
        print("THIN_RED", i, o.name, dims, center)

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

scene.render.filepath = os.path.join(OUT, "parts.png")
bpy.ops.render.render(write_still=True)
print("RENDER", scene.render.filepath)

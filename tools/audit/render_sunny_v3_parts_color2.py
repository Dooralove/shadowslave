import bpy
import bmesh
import math
import os
import mathutils

GLB = r"C:\Users\user\Desktop\shadowslave\assets\characters\generated\sunny_real_v3\sunny_real_v3.glb"
OUT = r"C:\Users\user\AppData\Local\Temp\opencode\sunny_v3_parts_color"
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
print("COMPONENTS", len(comps))

vertex_color = {}
thin_ids = []
for i, comp in enumerate(comps):
    xs = [bm.verts[j].co.x for j in comp]
    ys = [bm.verts[j].co.y for j in comp]
    zs = [bm.verts[j].co.z for j in comp]
    dims = (max(xs)-min(xs), max(ys)-min(ys), max(zs)-min(zs))
    thin = i in list(range(36, 46))
    color = (0.9, 0.03, 0.03, 1.0) if thin else (0.55, 0.55, 0.58, 1.0)
    if thin:
        thin_ids.append(i)
        print(f"THIN {i}: verts={len(comp)} dims=({dims[0]:.3f},{dims[1]:.3f},{dims[2]:.3f}) "
              f"bbox=({min(xs):.3f},{max(xs):.3f};{min(ys):.3f},{max(ys):.3f};{min(zs):.3f},{max(zs):.3f})")
    for j in comp:
        vertex_color[j] = color
bm.free()

attr = obj.data.color_attributes.new(name="debug_color", type='BYTE_COLOR', domain='POINT')
for i, v in enumerate(obj.data.vertices):
    attr.data[i].color = vertex_color.get(i, (0.55, 0.55, 0.58, 1.0))

mat = bpy.data.materials.new("debug")
mat.use_nodes = True
nodes = mat.node_tree.nodes
bsdf = nodes["Principled BSDF"]
color_node = nodes.new("ShaderNodeVertexColor")
color_node.layer_name = "debug_color"
mat.node_tree.links.new(color_node.outputs["Color"], bsdf.inputs["Base Color"])
obj.data.materials.clear()
obj.data.materials.append(mat)

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

scene.render.filepath = os.path.join(OUT, "parts_36_45.png")
bpy.ops.render.render(write_still=True)
print("RENDER", scene.render.filepath)
print("THIN_IDS", thin_ids)

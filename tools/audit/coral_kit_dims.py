import bpy
import os
import glob

root = r"C:\Users\user\Desktop\shadowslave\assets\environments\nightmare\coral"
files = sorted(glob.glob(os.path.join(root, "*.glb")))
print("ASSET\tX\tY\tZ\tMINZ\tMAXZ\tTRIS")
for path in files:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        continue
    # world-space bounds
    mins = [1e9, 1e9, 1e9]
    maxs = [-1e9, -1e9, -1e9]
    tris = 0
    for o in meshes:
        for corner in o.bound_box:
            w = o.matrix_world @ __import__("mathutils").Vector(corner)
            for i in range(3):
                mins[i] = min(mins[i], w[i])
                maxs[i] = max(maxs[i], w[i])
        tris += sum(len(p.vertices) - 2 for p in o.data.polygons)
    name = os.path.basename(path).replace(".glb", "")
    print("%s\t%.3f\t%.3f\t%.3f\t%.3f\t%.3f\t%d" % (
        name, maxs[0]-mins[0], maxs[1]-mins[1], maxs[2]-mins[2], mins[2], maxs[2], tris))

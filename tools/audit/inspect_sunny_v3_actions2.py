import bpy

GLB = r"C:\Users\user\Desktop\shadowslave\assets\characters\generated\sunny_real_v3\sunny_real_v3.glb"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
for action in bpy.data.actions:
    print("ACTION", action.name, "frames", action.frame_range)
    try:
        layers = action.layers
    except Exception as e:
        print("  no layers", e)
        continue
    for layer in layers:
        for strip in layer.strips:
            print("  strip", strip.type, "channelbags", len(strip.channelbags))
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    if "Hips" in fc.data_path and "location" in fc.data_path:
                        vals = [kp.co[1] for kp in fc.keyframe_points]
                        print("    FC", fc.data_path, "idx", fc.array_index, "min", min(vals), "max", max(vals), "first", vals[0], "last", vals[-1])

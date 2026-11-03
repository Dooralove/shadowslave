import bpy

GLB = r"C:\Users\user\Desktop\shadowslave\assets\characters\generated\sunny_real_v3\sunny_real_v3.glb"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
print("OBJECTS", [(o.name, o.type) for o in bpy.context.scene.objects])
for arm in [o for o in bpy.context.scene.objects if o.type == 'ARMATURE']:
    print("ARMATURE", arm.name, "bones", len(arm.data.bones))
    print("ANIM_DATA", arm.animation_data, "action", arm.animation_data.action if arm.animation_data else None)
    if arm.animation_data and arm.animation_data.nla_tracks:
        for track in arm.animation_data.nla_tracks:
            for strip in track.strips:
                print("NLA", track.name, strip.name, strip.action.name if strip.action else None)
for action in bpy.data.actions:
    print("ACTION", action.name, "frames", action.frame_range)
    for fc in action.fcurves:
        if "Hips" in fc.data_path and "location" in fc.data_path:
            vals = [kp.co[1] for kp in fc.keyframe_points]
            print("  FC", fc.data_path, "idx", fc.array_index, "min", min(vals), "max", max(vals), "first", vals[0], "last", vals[-1])

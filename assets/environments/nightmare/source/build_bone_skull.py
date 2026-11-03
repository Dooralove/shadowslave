import bpy
import math

OUT = r"C:\Users\user\Desktop\shadowslave\assets\environments\nightmare\coral\bone_skull.glb"


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def add_sphere(loc, scale, segments=24, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1.0, location=loc)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.object.shade_smooth()
    return obj


def add_cube(loc, scale, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def add_cone(loc, radius, depth, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=radius, radius2=0.02, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.object
    bpy.ops.object.shade_smooth()
    return obj


def join(objects):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    return bpy.context.object


def bone_material():
    mat = bpy.data.materials.new("nm_bone_aged")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.72, 0.68, 0.60, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.82
    return mat


def dark_material():
    mat = bpy.data.materials.new("nm_skull_dark")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.008, 0.014, 0.022, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.35
    return mat


def main():
    clear()

    cranium = add_sphere((0, 0, 0), (1.30, 1.60, 1.10), 32, 16)
    snout = add_cube((0, -1.35, -0.38), (1.55, 1.40, 0.80), (math.radians(8), 0, 0))
    jaw = add_cube((0, -1.55, -1.08), (1.25, 1.20, 0.26), (math.radians(-10), 0, 0))
    brow = add_cube((0, -0.95, 0.55), (1.95, 0.55, 0.24), (math.radians(4), 0, 0))
    cheek_l = add_sphere((-0.90, -0.55, -0.22), (0.48, 0.85, 0.48))
    cheek_r = add_sphere((0.90, -0.55, -0.22), (0.48, 0.85, 0.48))

    teeth = []
    for i in range(6):
        x = -0.55 + i * 0.22
        teeth.append(add_cone((x, -1.95, -0.82), 0.10, 0.36, (math.radians(8), 0, 0)))
        teeth.append(add_cone((x, -1.95, -1.18), 0.08, 0.26, (math.radians(188), 0, 0)))

    bone = join([cranium, snout, jaw, brow, cheek_l, cheek_r] + teeth)
    bone.data.materials.append(bone_material())
    for poly in bone.data.polygons:
        poly.material_index = 0

    eye_l = add_sphere((-0.62, -1.10, 0.22), (0.38, 0.26, 0.38), 20, 10)
    eye_r = add_sphere((0.62, -1.10, 0.22), (0.38, 0.26, 0.38), 20, 10)
    nose = add_sphere((0, -1.95, -0.20), (0.22, 0.18, 0.22), 16, 8)
    dark = join([eye_l, eye_r, nose])
    dark.data.materials.append(dark_material())
    for poly in dark.data.polygons:
        poly.material_index = 0

    # Origin at the base of the jaw so the art layer can place it on the floor.
    bpy.context.scene.cursor.location = (0.0, -1.55, -1.22)
    bpy.ops.object.select_all(action="DESELECT")
    bone.select_set(True)
    dark.select_set(True)
    bpy.context.view_layer.objects.active = bone
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")

    bpy.ops.object.select_all(action="DESELECT")
    bone.select_set(True)
    dark.select_set(True)
    bpy.context.view_layer.objects.active = bone
    bpy.ops.export_scene.gltf(
        filepath=OUT,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
    )
    print("EXPORTED", OUT, "bone tris", len(bone.data.polygons), "dark tris", len(dark.data.polygons))


if __name__ == "__main__":
    main()

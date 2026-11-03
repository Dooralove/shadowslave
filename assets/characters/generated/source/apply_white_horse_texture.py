import bpy, os, sys

root = r"C:\Users\user\Desktop\shadowslave"
src = os.path.join(root, r"incoming_models\P0_characters\white_horse_v3_geom.glb")
tex = os.path.join(root, r"incoming_models\concepts\white_horse\white_horse_v3_diffuse.png")
out = os.path.join(root, r"incoming_models\P0_characters\white_horse_v3_fixed.glb")
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
obj = next(o for o in bpy.context.scene.objects if o.type == 'MESH' and not o.name.startswith('Icosphere'))
# Use a clean white coat: keep the normal/ORM texture detail but remove the
# photogrammetry diffuse map (leopard spots + halter stains).
for mat in bpy.data.materials:
    if not mat.use_nodes:
        continue
    for node in mat.node_tree.nodes:
        if node.type != 'BSDF_PRINCIPLED':
            continue
        base = node.inputs.get('Base Color')
        if base is not None:
            for link in list(base.links):
                mat.node_tree.links.remove(link)
            base.default_value = (0.92, 0.90, 0.86, 1.0)
        rough = node.inputs.get('Roughness')
        if rough is not None:
            for link in list(rough.links):
                mat.node_tree.links.remove(link)
            rough.default_value = 0.82
print('APPLIED_WHITE_COAT')
bpy.ops.object.select_all(action='DESELECT')
obj.select_set(True); rig.select_set(True); bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(
    filepath=out, export_format='GLB', use_selection=True,
    export_animations=True, export_animation_mode='ACTIONS',
    export_anim_single_armature=True, export_skins=True, export_yup=True,
    export_apply=False,
)
print('WROTE', out, os.path.getsize(out))

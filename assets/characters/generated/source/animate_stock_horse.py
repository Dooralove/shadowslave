"""Author a simple idle+walk cycle for the clean stock horse rig."""
import bpy, os, math

ROOT = r"C:\Users\user\Desktop\shadowslave"
SRC = os.path.join(ROOT, r"incoming_models\horse_stock_white.glb")
OUT = os.path.join(ROOT, r"incoming_models\horse_stock_white_anim.glb")
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
mesh = next(o for o in bpy.context.scene.objects if o.type == 'MESH' and not o.name.startswith('Icosphere'))
names = [b.name for b in rig.data.bones]

def names_with(part):
    return [n for n in names if part in n]

print('NECK', names_with('szyja'))
print('TAIL', names_with('ogon'))
print('LHIND', names_with('udowa.L'), names_with('piszczelowa.L'))
print('RHIND', names_with('udowa.R'), names_with('piszczelowa.R'))
print('LFRONT', names_with('ramienna.L'), names_with('promieniowa.L'))
print('RFRONT', names_with('ramienna.R'), names_with('promieniowa.R'))


def key(action, frame, bone, rot):
    pb = rig.pose.bones.get(bone)
    if pb is None:
        return
    pb.rotation_mode = 'XYZ'
    pb.rotation_euler = rot
    pb.keyframe_insert('rotation_euler', frame=frame)


def new_action(name, end):
    if rig.animation_data is None:
        rig.animation_data_create()
    a = bpy.data.actions.new(name); a.use_fake_user = True
    a.frame_start = 1; a.frame_end = end
    rig.animation_data.action = a
    return a

# Idle: neck/head/tail sway.
a = new_action('Idle', 120)
for f, t in ((1, 0), (30, 1), (60, 0), (90, -1), (120, 0)):
    for n in names_with('szyja'):
        key(a, f, n, (0.018 * t, 0.0, 0.0))
    for n in names_with('ogon'):
        key(a, f, n, (0.0, 0.0, 0.045 * t))
    if names_with('eb'):
        key(a, f, names_with('eb')[-1], (0.015 * t, 0.0, 0.0))
# Walk: alternate hind/front limbs; small local X rotations.
a = new_action('Walk', 48)
for f, t in ((1, 0), (12, 1), (24, 0), (36, -1), (48, 0)):
    for n in names_with('udowa.L') + names_with('ramienna.L'):
        key(a, f, n, (0.20 * t, 0, 0))
    for n in names_with('piszczelowa.L') + names_with('promieniowa.L'):
        key(a, f, n, (-0.14 * t, 0, 0))
    for n in names_with('udowa.R') + names_with('ramienna.R'):
        key(a, f, n, (-0.20 * t, 0, 0))
    for n in names_with('piszczelowa.R') + names_with('promieniowa.R'):
        key(a, f, n, (0.14 * t, 0, 0))
    for n in names_with('ogon'):
        key(a, f, n, (0.0, 0.0, 0.06 * t))
rig.animation_data.action = bpy.data.actions.get('Idle')
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True); mesh.select_set(True); bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(
    filepath=OUT, export_format='GLB', use_selection=True,
    export_animations=True, export_animation_mode='ACTIONS',
    export_anim_single_armature=True, export_skins=True, export_yup=True,
    export_apply=False,
)
print('WROTE', OUT, os.path.getsize(OUT), [a.name for a in bpy.data.actions])

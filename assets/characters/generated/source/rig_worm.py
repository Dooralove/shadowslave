"""Minimal segmented rig for the worm knot. The cluster is a static scan; a
short spine chain with rigid island/segment weights gives a readable writhe.
"""
import bpy, os, math
from mathutils import Vector

ROOT = r"C:\Users\user\Desktop\shadowslave"
SRC = os.path.join(ROOT, r"incoming_models\P1_monsters\worm_knot_gen_b_dark.glb")
OUT = os.path.join(ROOT, r"incoming_models\P1_monsters\worm_knot_gen_b_rigged.glb")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
mesh = next(o for o in bpy.context.scene.objects if o.type == 'MESH' and not o.name.startswith('Icosphere'))
mn = Vector((1e9, 1e9, 1e9)); mx = Vector((-1e9, -1e9, -1e9))
for c in mesh.bound_box:
    p = mesh.matrix_world @ Vector(c)
    for i in range(3): mn[i] = min(mn[i], p[i]); mx[i] = max(mx[i], p[i])
print('DIMS', [round(v, 3) for v in (mx - mn)])
# The scan is a low knot; run the chain through its long Y axis.
y0, y1 = mn.y + 0.04, mx.y - 0.04
zmid = mn.z + (mx.z - mn.z) * 0.5
segments = 7
step = (y1 - y0) / segments
arm_data = bpy.data.armatures.new('WormRig')
arm = bpy.data.objects.new('WormRig', arm_data)
bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='EDIT')
prev = None
for i in range(segments):
    b = arm_data.edit_bones.new('Worm_%02d' % i)
    b.head = (0.0, y0 + i * step, zmid)
    b.tail = (0.0, y0 + (i + 1) * step, zmid)
    b.use_deform = True
    if prev is not None:
        b.parent = prev; b.use_connect = True
    prev = b
bpy.ops.object.mode_set(mode='OBJECT')

mesh.vertex_groups.clear()
groups = [mesh.vertex_groups.new(name='Worm_%02d' % i) for i in range(segments)]
for v in mesh.data.vertices:
    p = mesh.matrix_world @ v.co
    t = max(0.0, min(0.999, (p.y - y0) / max(y1 - y0, 1e-5)))
    groups[int(t * segments)].add([v.index], 1.0, 'REPLACE')
mesh.parent = arm
mesh.matrix_parent_inverse = arm.matrix_world.inverted()
mod = mesh.modifiers.new('Armature', 'ARMATURE')
mod.object = arm
print('BONES', len(arm_data.bones))


def action(name, end, amp):
    if arm.animation_data is None:
        arm.animation_data_create()
    a = bpy.data.actions.new(name); a.use_fake_user = True
    a.frame_start = 1; a.frame_end = end
    arm.animation_data.action = a
    for frame in range(1, end + 1, 4):
        t = (frame - 1) / max(end - 1, 1)
        for i in range(segments):
            pb = arm.pose.bones.get('Worm_%02d' % i)
            if pb is None:
                continue
            pb.rotation_mode = 'XYZ'
            phase = t * math.tau + i * 0.8
            pb.rotation_euler = (math.sin(phase) * amp * 0.4, 0.0, math.sin(phase + 0.6) * amp)
            pb.keyframe_insert('rotation_euler', frame=frame)
    return a

action('Idle', 120, 0.09)
action('Squirm', 60, 0.18)
arm.animation_data.action = bpy.data.actions.get('Idle')
bpy.ops.object.select_all(action='DESELECT')
mesh.select_set(True); arm.select_set(True); bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(
    filepath=OUT, export_format='GLB', use_selection=True,
    export_animations=True, export_animation_mode='ACTIONS',
    export_anim_single_armature=True, export_skins=True, export_yup=True,
    export_apply=False,
)
print('WROTE', OUT, os.path.getsize(OUT), [a.name for a in bpy.data.actions])

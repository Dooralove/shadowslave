@tool
class_name DecalTrail
extends Node3D
## Создаёт визуальный след из Decal-нод вдоль отрезка (следы обуви, крови, камней).
## Не создаёт коллизий и не меняет навигацию.

@export var texture: Texture2D
@export var start := Vector3(0, 0.03, 8.0)
@export var end := Vector3(0, 0.03, -20.0)
@export var count := 18
@export var size := Vector3(0.34, 0.04, 0.58)
@export var side_offset := 0.11
@export var yaw_jitter := 0.12
@export var modulate := Color(0.78, 0.84, 0.92, 0.7)
@export var surface_lift := 0.2
## Если включено, каждый отпечаток/пятно ставится на видимый пол лучом вниз.
## Нужно для неровного снега/камней: фиксированная высота оставляет следы в воздухе.
@export var snap_to_ground := false
@export var ground_lift := 0.02


func _ready() -> void:
	if texture == null:
		return
	if snap_to_ground and not Engine.is_editor_hint():
		await get_tree().physics_frame
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = modulate
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var quad := QuadMesh.new()
	quad.size = Vector2(size.x * 1.35, size.z * 1.35)
	quad.material = material
	for i in count:
		var t := 0.0 if count <= 1 else float(i) / float(count - 1)
		var mesh := MeshInstance3D.new()
		mesh.name = "Step%02d" % i
		mesh.mesh = quad
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var p := start.lerp(end, t)
		p.x += side_offset * (1.0 if i % 2 == 0 else -1.0)
		if snap_to_ground and not Engine.is_editor_hint():
			var visual_top := _visual_surface_y(p)
			if visual_top > -INF:
				p.y = visual_top + ground_lift
			else:
				var space := get_world_3d().direct_space_state
				var query := PhysicsRayQueryParameters3D.create(
					p + Vector3.UP * 2.0, p + Vector3.DOWN * 4.0, 1 | 32
				)
				var hit := space.intersect_ray(query)
				p.y = (hit.position as Vector3).y + ground_lift if not hit.is_empty() else p.y + surface_lift
		else:
			p.y += surface_lift
		var yaw := atan2(end.x - start.x, end.z - start.z) + yaw_jitter * (1.0 if i % 3 else -1.0)
		mesh.position = p
		mesh.rotation = Vector3(-PI * 0.5, yaw, 0)
		add_child(mesh)


## Верх видимой геометрии под точкой. Коллизия дороги/снега может быть выше
## или ниже меша; след должен лежать на том, что игрок видит.
func _visual_surface_y(point: Vector3) -> float:
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_parent()
	if scene == null:
		return -INF
	var best := -INF
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		if mesh == self or is_ancestor_of(mesh):
			continue
		var box := mesh.global_transform * mesh.get_aabb()
		if maxf(box.size.x, maxf(box.size.y, box.size.z)) > 60.0:
			continue
		if point.x < box.position.x or point.x > box.end.x:
			continue
		if point.z < box.position.z or point.z > box.end.z:
			continue
		var top := box.end.y
		if top <= point.y + 0.6 and top > best:
			best = top
	return best

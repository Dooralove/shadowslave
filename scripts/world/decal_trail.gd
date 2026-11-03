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


func _ready() -> void:
	if texture == null:
		return
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
		p.y += surface_lift
		var yaw := atan2(end.x - start.x, end.z - start.z) + yaw_jitter * (1.0 if i % 3 else -1.0)
		mesh.position = p
		mesh.rotation = Vector3(-PI * 0.5, yaw, 0)
		add_child(mesh)

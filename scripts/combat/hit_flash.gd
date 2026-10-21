class_name HitFlash
extends Node
## Визуальная реакция на урон: кратковременно накладывает цвет на все меши под mesh_root.
## Работает с любой моделью и не трогает её анимации (меняется только material_overlay).

@export var health: HealthComponent
@export var mesh_root: Node3D
@export var flash_color := Color(1.0, 0.3, 0.25, 0.3)
@export var duration := 0.1

var _material := StandardMaterial3D.new()
## Номер последней вспышки: вспышку гасит только её собственный таймер,
## поэтому быстрые повторные попадания не обрывают подсветку раньше времени.
var _flash_id := 0


func _ready() -> void:
	_material.albedo_color = flash_color
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if health:
		health.damaged.connect(_on_damaged)


func is_flashing() -> bool:
	return _flash_id > 0


func _on_damaged(_amount: float) -> void:
	_flash_id += 1
	var id := _flash_id
	_set_overlay(_material)
	await get_tree().create_timer(duration).timeout
	if id == _flash_id:
		_flash_id = 0
		_set_overlay(null)


func _set_overlay(material: Material) -> void:
	if not is_instance_valid(mesh_root):
		return
	for mesh in mesh_root.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_overlay = material

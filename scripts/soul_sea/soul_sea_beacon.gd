class_name SoulSeaBeacon
extends Node3D
## Тестовая точка интереса Моря Души. Позже здесь может появиться
## взаимодействие с конкретной тенью или Memory, но сейчас это только
## визуальный ориентир с одним переключаемым состоянием.

signal activated(active: bool)

@export var label_range := 5.2
@export var label_hide_range := 3.0

var active := false

var _material: ShaderMaterial
var _base_y := 0.0
var _elapsed := 0.0

@onready var core: MeshInstance3D = $Core
@onready var rings: Node3D = $Rings
@onready var light: OmniLight3D = $Light
@onready var label: Label3D = $Label


func _ready() -> void:
	add_to_group(&"soul_sea_beacon")
	_base_y = position.y
	if core.material_override is ShaderMaterial:
		_material = (core.material_override as ShaderMaterial).duplicate() as ShaderMaterial
		core.material_override = _material
	_apply()


func _process(delta: float) -> void:
	_elapsed += delta
	position.y = _base_y + sin(_elapsed * 0.72) * 0.045
	rings.rotation.y += delta * 0.14

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		label.visible = false
		return
	var distance := camera.global_position.distance_to(global_position)
	label.visible = distance <= label_range and distance >= label_hide_range


func activate() -> void:
	active = not active
	_apply()
	activated.emit(active)


func _apply() -> void:
	if _material != null:
		_material.set_shader_parameter("energy", 2.6 if active else 1.6)
		_material.set_shader_parameter("swirl", 0.65 if active else 0.45)
		_material.set_shader_parameter("core_color", Color(1.0, 0.9, 0.68) if active else Color(1.0, 0.84, 0.56))
		_material.set_shader_parameter("edge_color", Color(1.0, 0.5, 0.2) if active else Color(0.92, 0.38, 0.14))
	if light != null:
		light.light_energy = 3.2 if active else 1.8
		light.light_color = Color(1.0, 0.82, 0.58) if active else Color(1.0, 0.68, 0.38)
	if label != null:
		label.text = "ПАМЯТЬ"
		label.modulate = Color(1.0, 0.86, 0.64, 0.95) if active else Color(0.82, 0.7, 0.52, 0.9)

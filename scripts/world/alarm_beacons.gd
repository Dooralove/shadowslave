@tool
extends Node3D
## Показывает красные маяки только при активной тревоге (AlarmLights.energy > 0).

@export var alarm_lights_path: NodePath = ^"../../AlarmLights"
@export var threshold := 0.12

var _last := false


func _ready() -> void:
	_set_visible(false)


func _process(_delta: float) -> void:
	var lights := get_node_or_null(alarm_lights_path)
	if lights == null:
		return
	var active := false
	for light in lights.get_children():
		if light is Light3D and (light as Light3D).light_energy > threshold:
			active = true
			break
	_set_visible(active)


func _set_visible(value: bool) -> void:
	if value == _last:
		return
	_last = value
	visible = value

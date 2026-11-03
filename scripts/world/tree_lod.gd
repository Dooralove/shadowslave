@tool
class_name TreeLod
extends Node3D
## Три уровня одного дерева в отдельных GLB. LOD2 — облегчённый фон.
## Переключение только визуальное; коллизий у деревьев нет.

@export var lod1_distance := 30.0
@export var lod2_distance := 70.0
@export var update_interval := 0.25

var _levels: Array[Node3D] = []
var _current := -1
var _timer := 0.0


func _ready() -> void:
	_levels = [
		get_node_or_null("LOD0") as Node3D,
		get_node_or_null("LOD1") as Node3D,
		get_node_or_null("LOD2") as Node3D,
	]
	_apply(0)


func _process(delta: float) -> void:
	if _levels.is_empty():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = update_interval
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var distance := camera.global_position.distance_to(global_position)
	var level := 0
	if distance >= lod2_distance:
		level = 2
	elif distance >= lod1_distance:
		level = 1
	_apply(level)


func _apply(level: int) -> void:
	if level == _current:
		return
	_current = level
	for i in _levels.size():
		if _levels[i] != null:
			_levels[i].visible = i == level

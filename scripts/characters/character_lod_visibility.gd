@tool
class_name CharacterLodVisibility
extends Node
## Переключает LOD-копии внутри одного GLB (общая арматура и анимации).
## Копии мешей собраны в Blender с суффиксами _LOD1/_LOD2; LOD0 — без суффикса.
## Это визуальный компонент: логика, коллизии и сценарий не меняются.

@export var lod1_distance := 10.0
@export var lod2_distance := 22.0
@export var update_interval := 0.15

var _lod0: Array[MeshInstance3D] = []
var _lod1: Array[MeshInstance3D] = []
var _lod2: Array[MeshInstance3D] = []
var _current := -1
var _timer := 0.0


func _ready() -> void:
	_collect()
	_apply(0)


func _collect() -> void:
	_lod0.clear()
	_lod1.clear()
	_lod2.clear()
	var root := get_parent()
	if root == null:
		return
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null:
			continue
		if mesh.is_in_group(&"lod_ignore"):
			continue
		var name := String(mesh.name).to_lower()
		if name.contains("_lod2") or name.contains("lod2_"):
			_lod2.append(mesh)
		elif name.contains("_lod1") or name.contains("lod1_"):
			_lod1.append(mesh)
		else:
			_lod0.append(mesh)


func _process(delta: float) -> void:
	if _lod1.is_empty() and _lod2.is_empty():
		set_process(false)
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = update_interval
	var camera := get_viewport().get_camera_3d()
	var parent_3d := get_parent() as Node3D
	if camera == null or parent_3d == null:
		return
	var distance := camera.global_position.distance_to(parent_3d.global_position)
	var level := 0
	if not _lod2.is_empty() and distance >= lod2_distance:
		level = 2
	elif not _lod1.is_empty() and distance >= lod1_distance:
		level = 1
	_apply(level)


func _apply(level: int) -> void:
	if level == _current:
		return
	_current = level
	for mesh in _lod0:
		mesh.visible = level == 0
	for mesh in _lod1:
		mesh.visible = level == 1
	for mesh in _lod2:
		mesh.visible = level == 2

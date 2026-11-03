class_name CutsceneStage
extends Node3D
## Контейнер данных кат-сцены: ракурсы, маркеры, реквизит и манифест.
## Сценарий — отдельный CutsceneScript, который создаёт CutsceneDirector.

@export var definition: CutsceneDefinition
@export var markers_root: NodePath = ^"Markers"
@export var shots_root: NodePath = ^"Shots"
@export var props_root: NodePath = ^"Props"
@export var tracked_props: Array[NodePath] = []
@export var auto_hide := false


func _ready() -> void:
	if auto_hide:
		visible = false
	_aim_shots()


func _aim_shots() -> void:
	var root := get_node_or_null(shots_root)
	if root == null:
		return
	for child in root.get_children():
		var camera := child as Camera3D
		if camera == null:
			continue
		var target := camera.get_node_or_null(^"LookAt") as Node3D
		if target == null:
			continue
		var direction := target.global_position - camera.global_position
		if direction.length_squared() < 0.0001:
			continue
		var up := Vector3.UP
		if absf(direction.normalized().dot(Vector3.UP)) > 0.999:
			up = Vector3.FORWARD
		camera.look_at(target.global_position, up)


func get_marker(id: StringName) -> Node3D:
	var root := get_node_or_null(markers_root)
	if root == null:
		return null
	return root.get_node_or_null(NodePath(String(id))) as Node3D


func get_shot(id: StringName) -> Camera3D:
	var root := get_node_or_null(shots_root)
	if root == null:
		return null
	return root.get_node_or_null(NodePath(String(id))) as Camera3D


func get_prop(id: StringName) -> Node3D:
	var root := get_node_or_null(props_root)
	if root == null:
		return null
	return root.get_node_or_null(NodePath(String(id))) as Node3D


func get_tracked_props() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for path in tracked_props:
		var node := get_node_or_null(path) as Node3D
		if node != null:
			result.append(node)
	return result

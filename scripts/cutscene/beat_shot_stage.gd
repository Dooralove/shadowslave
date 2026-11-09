class_name BeatShotStage
extends Node3D
## Камеры ключевых beat-ов лагеря и подъёма. Кадры лежат в Shots/<id>,
## точка взгляда — дочерний LookAt (top_level), чтобы её было видно в редакторе.
## Stage сам создаёт CutsceneCamera3D и возвращает игровую камеру после beat-а.

var fast_mode := false
var _camera: CutsceneCamera3D
var _current_shot: StringName = &""


func _ready() -> void:
	_aim_shots()


func _aim_shots() -> void:
	var shots := get_node_or_null(^"Shots")
	if shots == null:
		return
	for child in shots.get_children():
		var camera := child as Camera3D
		if camera == null:
			continue
		var target := camera.get_node_or_null(^"LookAt") as Node3D
		if target == null:
			continue
		var direction := target.global_position - camera.global_position
		if direction.length_squared() < 0.0001:
			continue
		camera.look_at(target.global_position, Vector3.UP)


func play_shot(shot_id: StringName, blend := 0.45) -> bool:
	_ensure_camera()
	if _camera == null:
		return false
	if not _camera.has_method(&"shot"):
		return false
	_camera.make_current()
	_current_shot = shot_id
	await _camera.shot(shot_id, blend)
	return _current_shot == shot_id


func release(blend := 0.35) -> void:
	if _camera == null:
		return
	_current_shot = &""
	await _camera.player(blend)


func is_active() -> bool:
	return _camera != null and is_instance_valid(_camera) and _camera.current


func get_current_shot() -> StringName:
	return _current_shot


func _ensure_camera() -> void:
	if _camera != null and is_instance_valid(_camera):
		return
	var player_camera := _find_player_camera()
	if player_camera == null:
		return
	var parent := get_parent()
	if parent != null:
		var value: Variant = parent.get(&"fast_mode")
		if value != null:
			fast_mode = bool(value)
	_camera = CutsceneCamera3D.new()
	_camera.name = "BeatCamera"
	_camera.scene = self
	_camera.player_camera = player_camera
	_camera.fast_mode = fast_mode
	add_child(_camera)
	_camera.setup_from_camera(player_camera)
	_camera.make_current()


func _find_player_camera() -> Camera3D:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player != null:
		var rig := player.get_node_or_null(^"CameraRig") as Node3D
		if rig != null:
			var cam := rig.get_node_or_null(^"Camera") as Camera3D
			if cam != null:
				return cam
			for child in rig.get_children():
				if child is Camera3D:
					return child as Camera3D
	return get_viewport().get_camera_3d()

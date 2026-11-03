class_name Inspectable
extends Node3D
## Компонент «чутья»: подсвечивает значимый объект, когда игрок рядом и активно
## нужное событие. Не заменяет GuideBeacon: выбранный маяк на время подсветки
## приглушается, чтобы подсказки не дублировались.

const OUTLINE_SHADER := preload("res://assets/shaders/inspect_outline.gdshader")
const FADE_TIME := 0.25

@export var data: InspectableData
## Пусто — подсвечивается родитель. Иначе — перечисленные узлы/их потомки.
@export var target_paths: Array[NodePath] = []
@export var enabled := true

var _active := false
var _thought_shown := false
var _overlay: ShaderMaterial
var _overlays: Dictionary = {}
var _lines: Array[NodePath] = []
var _tween: Tween
var _strength := 0.0
var _suppressed_beacons: Array[GuideBeacon] = []


func _ready() -> void:
	_lines = target_paths.duplicate()
	_overlay = ShaderMaterial.new()
	_overlay.shader = OUTLINE_SHADER
	if data != null:
		_overlay.set_shader_parameter(&"rim_color", data.highlight_color)
		_overlay.set_shader_parameter(&"pulse_speed", data.pulse_speed)
	_overlay.set_shader_parameter(&"strength", 0.0)
	add_to_group(&"inspectable")


func _physics_process(_delta: float) -> void:
	if data == null or not enabled:
		if _active:
			set_active(false)
		return
	if not data.auto_inspect:
		return
	var should := is_event_active() and _player_in_range()
	if should != _active:
		set_active(should)


func _exit_tree() -> void:
	_suppress_beacons(false)


## Публичный вход для кнопки/триггера; auto_inspect использует его же.
func set_active(value: bool, instant := false) -> void:
	if data == null:
		return
	if value == _active and not instant:
		return
	if value == _active and instant:
		_apply_state(value, instant)
		return
	_active = value
	if value:
		_apply_overlays()
		_show_thought_once()
		_suppress_beacons(true)
	else:
		_suppress_beacons(false)
	_apply_state(value, instant)


func is_active() -> bool:
	return _active


func is_event_active() -> bool:
	if data == null or not enabled:
		return false
	if not _targets_visible():
		return false
	if _owner_is_dead():
		return false
	var state := get_node_or_null("/root/NightmareRunState")
	if state != null:
		for flag in data.required_flags:
			if not bool(state.call(&"has_flag", flag)):
				return false
		for flag in data.forbidden_flags:
			if bool(state.call(&"has_flag", flag)):
				return false
		if data.completed_flag != &"" and bool(state.call(&"has_flag", data.completed_flag)):
			return false
		if data.completed_item != &"" and bool(state.call(&"has_item", data.completed_item)):
			return false
	if data.beat_id != &"":
		var guide := get_node_or_null("/root/CampaignGuide")
		if guide != null:
			var beat := StringName(guide.call(&"get_current_beat_id"))
			if beat != &"" and beat != data.beat_id:
				return false
	return true


func get_targets() -> Array[Node3D]:
	var result: Array[Node3D] = []
	if _lines.is_empty():
		var parent := get_parent() as Node3D
		if parent != null:
			result.append(parent)
		return result
	for path in _lines:
		var node := get_node_or_null(path) as Node3D
		if node != null:
			result.append(node)
	return result


func get_overlay_material() -> ShaderMaterial:
	return _overlay


func _player_in_range() -> bool:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return false
	return player.global_position.distance_to(global_position) <= data.detection_radius


func _targets_visible() -> bool:
	for target in get_targets():
		if target.is_visible_in_tree():
			return true
	return false


## Слабое место мёртвого врага больше не подсвечивается, даже без сюжетного флага.
func _owner_is_dead() -> bool:
	for target in get_targets():
		var node: Node = target
		while node != null:
			if node.is_in_group(&"enemy"):
				var health := node.get_node_or_null(^"Health") as HealthComponent
				if health != null and health.is_dead():
					return true
				break
			node = node.get_parent()
	return false


func _apply_state(value: bool, instant: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var target_strength := data.highlight_strength if value else 0.0
	if instant:
		_strength = target_strength
		_overlay.set_shader_parameter(&"strength", _strength)
		if not value:
			_restore_overlays()
		return
	_tween = create_tween()
	_tween.tween_method(_set_strength, _strength, target_strength, FADE_TIME)
	if not value:
		_tween.tween_callback(_restore_overlays)


func _set_strength(value: float) -> void:
	_strength = value
	_overlay.set_shader_parameter(&"strength", _strength)


func _apply_overlays() -> void:
	for node in _collect_geometry():
		if not _overlays.has(node):
			_overlays[node] = node.material_overlay
		node.material_overlay = _overlay


func _restore_overlays() -> void:
	for node in _overlays:
		if is_instance_valid(node):
			node.material_overlay = _overlays[node]
	_overlays.clear()


func _collect_geometry() -> Array[GeometryInstance3D]:
	var result: Array[GeometryInstance3D] = []
	for root in get_targets():
		_collect_from(root, result)
	return result


func _collect_from(node: Node, result: Array[GeometryInstance3D]) -> void:
	if node is GeometryInstance3D:
		result.append(node as GeometryInstance3D)
	for child in node.get_children():
		_collect_from(child, result)


func _show_thought_once() -> void:
	if data.thought_id == &"":
		return
	if data.thought_once and _thought_shown:
		return
	_thought_shown = true
	var guide := get_node_or_null("/root/CampaignGuide")
	if guide != null and guide.has_method(&"show_thought"):
		guide.call(&"show_thought", data.thought_id)


func _suppress_beacons(value: bool) -> void:
	if data == null or data.suppress_beacon_id == &"":
		return
	if value:
		for node in get_tree().get_nodes_in_group(&"guide_beacon"):
			var beacon := node as GuideBeacon
			if beacon != null and beacon.beacon_id == data.suppress_beacon_id:
				beacon.set_sense_suppressed(true, self)
				_suppressed_beacons.append(beacon)
	else:
		for beacon in _suppressed_beacons:
			if is_instance_valid(beacon):
				beacon.set_sense_suppressed(false, self)
		_suppressed_beacons.clear()

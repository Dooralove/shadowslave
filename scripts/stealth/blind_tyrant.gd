class_name BlindTyrant
extends Node3D
## Слепой Тиран стелс-участка. Не имеет зрения: единственный вход —
## hear_noise(event, origin). Идёт к услышанной точке и убивает на контакте.

signal heard_noise(event: NoiseEventData, origin: Vector3)
signal caught_player

@export var visual_path: NodePath
@export var move_speed := 2.4
@export var kill_radius := 1.35
@export var active := false

var visual: Node3D
var target: Node3D
var target_position := Vector3.INF
var last_event: NoiseEventData
var last_noise_origin := Vector3.ZERO
var _start_position := Vector3.ZERO
var _has_target := false


func _ready() -> void:
	if visual == null and not visual_path.is_empty():
		visual = get_node_or_null(visual_path) as Node3D


func configure(visual_node: Node3D, player: Node3D, start_position: Vector3) -> void:
	visual = visual_node
	target = player
	_start_position = start_position
	if visual != null:
		visual.global_position = start_position
	reset(start_position, player)


func reset(start_position: Vector3, player: Node3D = null) -> void:
	active = false
	target = player
	_start_position = start_position
	target_position = Vector3.INF
	last_event = null
	_has_target = false
	if visual != null:
		visual.global_position = start_position
		visual.visible = false


func set_active(value: bool) -> void:
	active = value
	if visual != null:
		visual.visible = value


func hear_noise(event: NoiseEventData, origin: Vector3, target_override: Node3D = null) -> bool:
	if not active or event == null:
		return false
	var listener_position := visual.global_position if visual != null else global_position
	if not event.is_audible_from(listener_position, origin):
		return false
	# Цель удара — всегда Санни; отдельная точка притяжения (bell) задаёт
	# только направление движения и не подменяет жертву.
	target_position = origin
	if target_override != null:
		target_position = target_override.global_position
	last_noise_origin = origin
	last_event = event
	_has_target = true
	heard_noise.emit(event, origin)
	return true


func _physics_process(delta: float) -> void:
	if not active:
		return
	var body := visual if visual != null else self
	if target != null and is_instance_valid(target):
		var offset := target.global_position - body.global_position
		offset.y = 0.0
		if offset.length() <= kill_radius:
			active = false
			caught_player.emit()
			return
	if not _has_target or target_position == Vector3.INF:
		return
	var move := target_position - body.global_position
	move.y = 0.0
	if move.length() <= 0.15:
		_has_target = false
		target_position = Vector3.INF
		return
	body.global_position += move.normalized() * move_speed * delta


func distance_to_player() -> float:
	if target == null or not is_instance_valid(target):
		return INF
	var listener_position := visual.global_position if visual != null else global_position
	var offset := target.global_position - listener_position
	offset.y = 0.0
	return offset.length()

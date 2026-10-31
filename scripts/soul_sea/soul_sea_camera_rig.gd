class_name SoulSeaCameraRig
extends Node3D
## Свободная камера Моря Души: обзор, небольшое перемещение и взаимодействие
## с тестовым ориентиром. Это не тело Санни и не CharacterBody3D: физика
## внешнего мира сюда не подключается.

signal prompt_changed(text: String)
signal beacon_activated(active: bool)

@export var move_speed := 3.6
@export var sprint_multiplier := 1.8
@export var look_sensitivity := 0.0022
@export var bounds_radius := 9.0
@export var interaction_range := 3.0

var active := false

var _yaw := 0.0
var _pitch := -0.08
var _last_prompt := ""

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	add_to_group(&"soul_sea_camera")
	rotation.y = _yaw
	camera.rotation.x = _pitch
	set_process(false)
	set_physics_process(false)


func set_active(value: bool) -> void:
	active = value
	set_process(value)
	set_physics_process(value)
	if not value:
		_set_prompt("")
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_refresh_prompt()


func _physics_process(delta: float) -> void:
	if not active:
		return

	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if input.length_squared() > 0.0:
		var direction := Basis(Vector3.UP, _yaw) * Vector3(input.x, 0.0, input.y)
		var speed := move_speed
		if Input.is_action_pressed(&"sprint"):
			speed *= sprint_multiplier
		position += direction.normalized() * speed * delta

	var flat := Vector2(position.x, position.z)
	if flat.length() > bounds_radius:
		flat = flat.normalized() * bounds_radius
		position.x = flat.x
		position.z = flat.y
	position.y = 0.0

	_refresh_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_yaw = wrapf(_yaw - motion.relative.x * look_sensitivity, -PI, PI)
		_pitch = clampf(_pitch - motion.relative.y * look_sensitivity, -1.25, 0.75)
		rotation.y = _yaw
		camera.rotation.x = _pitch
		return

	if event.is_action_pressed(&"capture_mouse") and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"interact") and _can_interact():
		var beacon := _get_beacon()
		beacon.activate()
		beacon_activated.emit(beacon.active)
		_refresh_prompt()
		get_viewport().set_input_as_handled()


func _get_beacon() -> SoulSeaBeacon:
	return get_tree().get_first_node_in_group(&"soul_sea_beacon") as SoulSeaBeacon


func _can_interact() -> bool:
	var beacon := _get_beacon()
	if beacon == null:
		return false
	if global_position.distance_to(beacon.global_position) > interaction_range:
		return false
	var to_beacon := beacon.global_position - camera.global_position
	if to_beacon.length_squared() < 0.001:
		return false
	var forward := -camera.global_transform.basis.z
	return forward.dot(to_beacon.normalized()) > 0.35


func _refresh_prompt() -> void:
	var beacon := _get_beacon()
	if not active or beacon == null or not _can_interact():
		_set_prompt("")
		return
	if beacon.active:
		_set_prompt("E — погасить Память")
	else:
		_set_prompt("E — коснуться Памяти")


func _set_prompt(text: String) -> void:
	if text == _last_prompt:
		return
	_last_prompt = text
	prompt_changed.emit(text)

class_name ThirdPersonCamera
extends Node3D
## Камера от третьего лица: рыскание на этом узле, тангаж на SpringArm3D.
## SpringArm3D укорачивается при столкновении, поэтому камера не уходит под пол и в стены.
## Также отвечает за захват мыши: захват при старте и по щелчку, освобождение по release_mouse.

@export var mouse_sensitivity := 0.0025
@export_range(-89.0, 0.0) var min_pitch_deg := -70.0
@export_range(0.0, 89.0) var max_pitch_deg := 25.0
@export var initial_pitch_deg := -20.0

var yaw := 0.0
var pitch := 0.0
## Ложь — мышь не вращает камеру (жёсткие постановки). Захват и освобождение мыши работают как обычно.
var look_enabled := true

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	set_pitch(deg_to_rad(initial_pitch_deg))
	# Луч пружины не должен упираться в собственную капсулу персонажа.
	var body := get_parent() as CollisionObject3D
	if body:
		spring_arm.add_excluded_object(body.get_rid())
	capture_mouse()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("release_mouse"):
		release_mouse()
	elif event.is_action_pressed("capture_mouse") and not is_mouse_captured():
		capture_mouse()
		# Этот щелчок только захватывает мышь и не должен считаться атакой.
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and is_mouse_captured() and look_enabled:
		var motion := event as InputEventMouseMotion
		yaw = wrapf(yaw - motion.relative.x * mouse_sensitivity, -PI, PI)
		set_pitch(pitch - motion.relative.y * mouse_sensitivity)


func set_pitch(value: float) -> void:
	pitch = clampf(value, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
	_apply_rotation()


## Базис на горизонтальной плоскости по направлению камеры — для движения персонажа.
func get_planar_basis() -> Basis:
	return Basis(Vector3.UP, yaw)


func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func is_mouse_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _apply_rotation() -> void:
	rotation.y = yaw
	if spring_arm:
		spring_arm.rotation.x = pitch

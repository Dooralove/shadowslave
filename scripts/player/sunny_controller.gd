class_name SunnyController
extends CharacterBody3D
## Передвижение Санни: ходьба, бег, прыжок, гравитация.
## Тело не вращается — поворачивается только узел Visual, поэтому капсулу
## можно заменить моделью со скелетом и анимациями, не трогая этот код.

@export var walk_speed := 4.0
@export var sprint_speed := 7.5
@export var acceleration := 12.0
## Доля ускорения, доступная в воздухе.
@export_range(0.0, 1.0) var air_control := 0.3
@export var jump_velocity := 5.0
@export var turn_speed := 10.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var visual: Node3D = $Visual
@onready var camera_rig: ThirdPersonCamera = $CameraRig


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := camera_rig.get_planar_basis() * Vector3(input.x, 0.0, input.y)
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var accel := acceleration if is_on_floor() else acceleration * air_control
	horizontal = horizontal.lerp(direction * speed, clampf(accel * delta, 0.0, 1.0))
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	move_and_slide()

	if direction.length_squared() > 0.001:
		# Модель смотрит вдоль -Z.
		var target_yaw := atan2(-direction.x, -direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))

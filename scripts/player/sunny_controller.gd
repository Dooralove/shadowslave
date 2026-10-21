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
## Ложь после смерти: ввод игнорируется, гравитация продолжает действовать.
var controls_enabled := true

@onready var visual: Node3D = $Visual
@onready var camera_rig: ThirdPersonCamera = $CameraRig
@onready var health: HealthComponent = $Health
@onready var attack: MeleeAttack = $Visual/MeleeAttack


func _ready() -> void:
	health.died.connect(_on_died)


func _unhandled_input(event: InputEvent) -> void:
	# Щелчок, которым захватывают мышь, камера помечает обработанным, поэтому сюда он не доходит.
	if event.is_action_pressed("attack") and camera_rig.is_mouse_captured():
		try_attack()


## Удар туда, куда смотрит модель (Visual, ось -Z). Камера на направление не влияет.
func try_attack() -> bool:
	if not controls_enabled:
		return false
	return attack.try_attack()


func is_dead() -> bool:
	return health.is_dead()


func _on_died() -> void:
	# Падение показывает клип смерти (SunnyAnimator).
	controls_enabled = false
	attack.disable()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif controls_enabled and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var input := Vector2.ZERO
	if controls_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
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

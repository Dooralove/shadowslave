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
## Разрешения по сцене: в прологе нет бега, прыжков и боя. По умолчанию всё включено (арена).
@export var allow_sprint := true
@export var allow_jump := true
@export var combat_enabled := true

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
## Ложь после смерти: ввод игнорируется, гравитация продолжает действовать.
var controls_enabled := true
## Ложь — ввод передвижения игнорируется (постановки, диалоги). Отдельно от смерти.
var input_enabled := true
## Ненулевой вектор — персонаж идёт в заданном темпе и направлении без участия игрока (цепь каравана).
var forced_velocity := Vector3.ZERO
var _camp_tether_active := false
var _camp_tether_anchor := Vector3.ZERO
var _camp_tether_radius := 0.0
var _chain_restraint_active := false
var _chain_restraint_width := 0.0

@onready var visual: Node3D = $Visual
@onready var camera_rig: ThirdPersonCamera = $CameraRig
@onready var health: HealthComponent = $Health
@onready var attack: MeleeAttack = $Visual/MeleeAttack


func _ready() -> void:
	health.died.connect(_on_died)


func _unhandled_input(event: InputEvent) -> void:
	# Щелчок, которым захватывают мышь, камера помечает обработанным, поэтому сюда он не доходит.
	if combat_enabled and event.is_action_pressed("attack") and camera_rig.is_mouse_captured():
		try_attack()


## Удар туда, куда смотрит модель (Visual, ось -Z). Камера на направление не влияет.
func try_attack() -> bool:
	if not controls_enabled or not combat_enabled:
		return false
	return attack.try_attack()


func is_dead() -> bool:
	return health.is_dead()


## Цепь каравана: проверка, активация и сброс ограничений
var chain_restrained: bool:
	get:
		return _camp_tether_active or _chain_restraint_active or forced_velocity != Vector3.ZERO


func enable_camp_tether(anchor_position: Vector3, radius: float) -> void:
	_camp_tether_active = true
	_camp_tether_anchor = anchor_position
	_camp_tether_radius = radius


func is_camp_tethered() -> bool:
	return _camp_tether_active


func clear_chain_restraint() -> void:
	_camp_tether_active = false
	_chain_restraint_active = false
	_chain_restraint_width = 0.0
	forced_velocity = Vector3.ZERO


func enable_chain_restraint(restraint: Vector3) -> void:
	# Вектор задаёт направление колонны; боковая ширина может быть нулевой
	# (дорога идёт строго по -Z), поэтому активность храним отдельно.
	_chain_restraint_active = restraint.length_squared() > 0.0001
	_chain_restraint_width = absf(restraint.x)


func get_chain_restraint_width() -> float:
	return _chain_restraint_width


func _clamp_to_camp_tether() -> void:
	var horizontal_pos := Vector3(global_position.x, 0.0, global_position.z)
	var anchor_horizontal := Vector3(_camp_tether_anchor.x, 0.0, _camp_tether_anchor.z)
	var to_anchor := horizontal_pos - anchor_horizontal
	if to_anchor.length() > _camp_tether_radius:
		var clamped := anchor_horizontal + to_anchor.normalized() * _camp_tether_radius
		global_position.x = clamped.x
		global_position.z = clamped.z


func get_chain_route() -> Vector3:
	return forced_velocity if forced_velocity != Vector3.ZERO else Vector3(0, 0, -1)


func _on_died() -> void:
	# Падение показывает клип смерти (SunnyAnimator).
	controls_enabled = false
	attack.disable()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif controls_enabled and input_enabled and allow_jump and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var input := Vector2.ZERO
	if controls_enabled and input_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := camera_rig.get_planar_basis() * Vector3(input.x, 0.0, input.y)
	var speed := sprint_speed if allow_sprint and Input.is_action_pressed("sprint") else walk_speed
	if forced_velocity != Vector3.ZERO and controls_enabled:
		direction = forced_velocity.normalized()
		speed = forced_velocity.length()

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var accel := acceleration if is_on_floor() else acceleration * air_control
	horizontal = horizontal.lerp(direction * speed, clampf(accel * delta, 0.0, 1.0))
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	move_and_slide()
	if _camp_tether_active:
		_clamp_to_camp_tether()

	# Во время атаки модель не разворачивается: видимый удар совпадает с зафиксированной зоной поражения.
	if direction.length_squared() > 0.001 and not attack.is_attacking():
		# Модель смотрит вдоль -Z.
		var target_yaw := atan2(-direction.x, -direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))

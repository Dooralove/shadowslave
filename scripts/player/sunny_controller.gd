class_name SunnyController
extends CharacterBody3D
## Передвижение Санни: ходьба, бег, прыжок, гравитация.

const VFX := preload("res://scripts/vfx/one_shot_vfx.gd")
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
var _soul_sea_suspended := false
var _saved_input_enabled := true
var _saved_combat_enabled := true
var _cutscene_mode := false
var _cutscene_state: Dictionary = {}
## Скорость и остаток уклонения: движение на время уклонения задаёт CombatController.
var dodge_velocity := Vector3.ZERO
var dodge_time_left := 0.0

@onready var visual: Node3D = $Visual
@onready var camera_rig: ThirdPersonCamera = $CameraRig
@onready var health: HealthComponent = $Health
@onready var attack: MeleeAttack = $Visual/MeleeAttack
@onready var stamina: StaminaComponent = get_node_or_null(^"Stamina") as StaminaComponent
@onready var combat: Node = get_node_or_null(^"CombatController")


func _ready() -> void:
	health.died.connect(_on_died)


## Поставить модель и камеру по направлению маркера Spawns/<name>.
## Вызывается GreyboxLocation после перехода между сценами.
func apply_spawn_orientation(value: float) -> void:
	var facing := wrapf(value, -PI, PI)
	visual.rotation.y = facing
	camera_rig.set_yaw(facing)


func _unhandled_input(event: InputEvent) -> void:
	# Щелчок, которым захватывают мышь, камера помечает обработанным, поэтому сюда он не доходит.
	if combat != null and combat.has_method(&"handle_input"):
		if bool(combat.call(&"handle_input", event)):
			get_viewport().set_input_as_handled()
		return
	if combat_enabled and event.is_action_pressed("attack") and camera_rig.is_mouse_captured():
		try_attack()


## Удар туда, куда смотрит модель (Visual, ось -Z). Камера на направление не влияет.
func try_attack() -> bool:
	if not controls_enabled or not combat_enabled:
		return false
	if combat != null and combat.has_method(&"try_light_attack"):
		return bool(combat.call(&"try_light_attack"))
	return attack.try_attack()


func is_in_combat() -> bool:
	if combat != null and combat.has_method(&"is_in_combat"):
		return bool(combat.call(&"is_in_combat"))
	return false


func set_unarmed(value: bool) -> void:
	if combat != null and combat.has_method(&"set_unarmed"):
		combat.call(&"set_unarmed", value)


func is_unarmed() -> bool:
	if combat != null and combat.has_method(&"is_unarmed"):
		return bool(combat.call(&"is_unarmed"))
	return false


## N20–N23: раненое состояние подъёма. Не бой и не отдельная полоска:
## только замедление, дыхание и виньетка через ConditionFeedback.
var _wounded := false
var _wounded_saved_walk_speed := 4.0
var _wounded_saved_sprint := false
var _wounded_saved_jump := false
var _wounded_saved_combat := true


func set_wounded(value: bool) -> void:
	if _wounded == value:
		return
	if value:
		_wounded_saved_walk_speed = walk_speed
		_wounded_saved_sprint = allow_sprint
		_wounded_saved_jump = allow_jump
		_wounded_saved_combat = combat_enabled
		walk_speed = minf(walk_speed, 2.35)
		allow_sprint = false
		allow_jump = false
		combat_enabled = false
		var feedback := get_node_or_null("ConditionFeedback") as ConditionFeedback
		if feedback != null:
			feedback.set_cold(0.55)
			feedback.set_noise(0.35)
		_wounded = true
	else:
		walk_speed = _wounded_saved_walk_speed
		allow_sprint = _wounded_saved_sprint
		allow_jump = _wounded_saved_jump
		combat_enabled = _wounded_saved_combat
		var feedback := get_node_or_null("ConditionFeedback") as ConditionFeedback
		if feedback != null:
			feedback.set_cold(0.0)
			feedback.set_noise(0.0)
		_wounded = false


func is_wounded() -> bool:
	return _wounded


func start_dodge(direction: Vector3, speed: float, duration: float) -> void:
	dodge_velocity = direction.normalized() * maxf(speed, 0.0) if direction.length_squared() > 0.001 else Vector3.ZERO
	dodge_time_left = maxf(duration, 0.0)


func cancel_dodge() -> void:
	dodge_time_left = 0.0
	dodge_velocity = Vector3.ZERO


func is_dodging() -> bool:
	return dodge_time_left > 0.0


func is_dead() -> bool:
	return health.is_dead()


## Временное отключение ввода и боя, пока игрок находится в Море Души.
## Само тело, здоровье и физика продолжают работать в обычном мире.
## Временное отключение управления и боя на время кат-сцены.
## Сохраняет и восстанавливает все поля, которые меняет; вложенные вызовы
## безопасны. Физику можно оставить включённой для сцен с forced_velocity.
func set_cutscene_mode(enabled: bool, freeze_physics := true) -> void:
	if enabled == _cutscene_mode:
		return
	if enabled:
		var interactor := get_node_or_null(^"Interactor")
		_cutscene_state = {
			"input_enabled": input_enabled,
			"combat_enabled": combat_enabled,
			"forced_velocity": forced_velocity,
			"physics": is_physics_processing(),
			"unhandled_input": is_processing_unhandled_input(),
			"camera_input": camera_rig.input_enabled,
			"camera_look": camera_rig.look_enabled,
			"invulnerable": health.invulnerable,
			"interactor": interactor.get("enabled") if interactor != null else null,
		}
		input_enabled = false
		combat_enabled = false
		forced_velocity = Vector3.ZERO
		set_process_unhandled_input(false)
		if freeze_physics:
			set_physics_process(false)
		camera_rig.input_enabled = false
		camera_rig.look_enabled = false
		health.invulnerable = true
		if interactor != null:
			interactor.set(&"enabled", false)
		_cutscene_mode = true
	else:
		input_enabled = bool(_cutscene_state.get("input_enabled", true))
		combat_enabled = bool(_cutscene_state.get("combat_enabled", true))
		forced_velocity = _cutscene_state.get("forced_velocity", Vector3.ZERO)
		set_process_unhandled_input(bool(_cutscene_state.get("unhandled_input", true)))
		set_physics_process(bool(_cutscene_state.get("physics", true)))
		camera_rig.input_enabled = bool(_cutscene_state.get("camera_input", true))
		camera_rig.look_enabled = bool(_cutscene_state.get("camera_look", true))
		health.invulnerable = bool(_cutscene_state.get("invulnerable", false))
		var interactor := get_node_or_null(^"Interactor")
		if interactor != null and _cutscene_state.get("interactor", null) != null:
			interactor.set(&"enabled", bool(_cutscene_state["interactor"]))
		_cutscene_mode = false


func is_in_cutscene_mode() -> bool:
	return _cutscene_mode


func set_soul_sea_suspended(value: bool) -> void:
	if value == _soul_sea_suspended:
		return
	if value:
		_saved_input_enabled = input_enabled
		_saved_combat_enabled = combat_enabled
		input_enabled = false
		combat_enabled = false
		_soul_sea_suspended = true
	else:
		input_enabled = _saved_input_enabled
		combat_enabled = _saved_combat_enabled
		_soul_sea_suspended = false


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
	cancel_dodge()
	attack.disable()
	VFX.spawn_dust(global_position + Vector3.UP * 0.2)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif controls_enabled and input_enabled and allow_jump and not is_in_combat() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var input := Vector2.ZERO
	if controls_enabled and input_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := camera_rig.get_planar_basis() * Vector3(input.x, 0.0, input.y)
	var speed := walk_speed
	if allow_sprint and Input.is_action_pressed("sprint") and not is_in_combat():
		speed = sprint_speed
	if forced_velocity != Vector3.ZERO and controls_enabled:
		direction = forced_velocity.normalized()
		speed = forced_velocity.length()

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if dodge_time_left > 0.0:
		# Уклонение задаёт собственный импульс и не зависит от ввода в этот момент.
		dodge_time_left = maxf(dodge_time_left - delta, 0.0)
		horizontal = dodge_velocity
		if dodge_time_left <= 0.0:
			dodge_velocity = Vector3.ZERO
	else:
		var accel := acceleration if is_on_floor() else acceleration * air_control
		var move_speed := speed
		if combat != null and combat.has_method(&"get_move_speed_multiplier"):
			move_speed *= float(combat.call(&"get_move_speed_multiplier"))
		horizontal = horizontal.lerp(direction * move_speed, clampf(accel * delta, 0.0, 1.0))
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	move_and_slide()
	if _camp_tether_active:
		_clamp_to_camp_tether()

	# Во время атаки модель не разворачивается: видимый удар совпадает с зафиксированной зоной поражения.
	if direction.length_squared() > 0.001 and not attack.is_attacking() and not is_dodging():
		# Модель смотрит вдоль -Z.
		var target_yaw := atan2(-direction.x, -direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))

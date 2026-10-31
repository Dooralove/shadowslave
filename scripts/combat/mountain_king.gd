class_name MountainKing
extends CharacterBody3D
## Черновой AI Горного Короля для прототипа засады.
##
## DORMANT → CHASE → TELEGRAPH → ATTACK → RECOVERY → CHASE/DORMANT.
## BLOCKED — монстр не может пройти (стена, повозка, край) и не толкается в неё бесконечно.
## RETREAT — только по явной команде сценария; в текущей сцене не запускается.
##
## Навигационных регионов в greybox пока нет, поэтому перемещение — упрощённое
## прямое рулевое управление с CharacterBody3D.move_and_slide(), без pathfinding.
## Логика состояний (update_ai) отделена от физики, чтобы её можно было тестировать
## без запуска сцены.

signal state_changed(new_state: State)
signal telegraph_started
signal attack_started
signal blocked_started
signal retreat_finished

enum State { DORMANT, CHASE, TELEGRAPH, ATTACK, RECOVERY, BLOCKED, RETREAT, DEAD }

const CHASE_STOP_DISTANCE := 0.35
const BLOCKED_PROGRESS_FRACTION := 0.15

@export var config: MountainKingConfig
## Цель. Если не задана, берётся первый узел группы "player".
@export var target: Node3D
## Маска препятствий для проверки прямой видимости в BLOCKED (слой world).
@export_flags_3d_physics var obstacle_mask: int = 1
## Временный вывод смены состояний в консоль.
@export var debug_log_state_changes := false

var state := State.DORMANT
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _state_time := 0.0
var _attack_cooldown_left := 0.0
var _last_known_target_position := Vector3.ZERO
var _has_last_known_target := false
var _target_hidden := false
var _ai_enabled := true
var _awake := false
## После activate() монстр должен найти игрока, даже если тот появился позже.
var _force_acquire := false
var _blocked_retry_left := 0.0
var _retreat_destination := Vector3.ZERO
var _retreat_timeout := 0.0
var _no_progress_time := 0.0

@onready var visual: Node3D = $Visual
@onready var health: HealthComponent = $Health
@onready var attack: MeleeAttack = $Visual/MeleeAttack
@onready var telegraph_visual: Node3D = $Visual/TelegraphVisual


func _ready() -> void:
	if config == null:
		config = MountainKingConfig.new()
	telegraph_visual.visible = false
	health.died.connect(_on_died)
	_resolve_target()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if state == State.DEAD:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	update_ai(delta)

	var desired := _desired_horizontal_velocity()
	var intended_speed := Vector2(desired.x, desired.z).length()
	velocity.x = move_toward(velocity.x, desired.x, config.acceleration * delta)
	velocity.z = move_toward(velocity.z, desired.z, config.acceleration * delta)

	var before := global_position
	move_and_slide()
	_update_blocked_detection(delta, before, intended_speed)
	_update_visual(delta)


## Публичный шаг автомата: вызывается физикой и тестами.
func update_ai(delta: float) -> void:
	if state == State.DEAD:
		return
	if not _ai_enabled:
		if state != State.DORMANT:
			_enter(State.DORMANT)
		return

	_state_time += delta
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)

	if _has_target() and not _target_hidden:
		_last_known_target_position = target.global_position
		_has_last_known_target = true

	match state:
		State.DORMANT:
			_update_dormant()
		State.CHASE:
			_update_chase()
		State.TELEGRAPH:
			_update_telegraph()
		State.ATTACK:
			_update_attack()
		State.RECOVERY:
			_update_recovery()
		State.BLOCKED:
			_update_blocked(delta)
		State.RETREAT:
			_update_retreat()


## Пробуждает AI и заставляет найти цель. Возвращает true, если цель найдена сразу.
func activate() -> bool:
	if state == State.DEAD:
		return false
	_ai_enabled = true
	attack.enabled = true
	_awake = true
	_force_acquire = true
	_attack_cooldown_left = 0.0
	_no_progress_time = 0.0
	if not _has_target():
		_enter(State.DORMANT)
		return false
	_last_known_target_position = target.global_position
	_has_last_known_target = true
	_force_acquire = false
	_enter(State.CHASE)
	return true


## Полностью выключает принятие решений и обрывает текущую атаку.
func deactivate() -> void:
	_ai_enabled = false
	_awake = false
	_force_acquire = false
	attack.disable()
	_enter(State.DORMANT)


func set_ai_enabled(enabled: bool) -> void:
	if enabled:
		activate()
	else:
		deactivate()


func is_ai_enabled() -> bool:
	return _ai_enabled


func is_awake() -> bool:
	return _awake


func is_player_hidden() -> bool:
	return _target_hidden


## Укрытие скрывает игрока: преследование идёт к последней известной точке,
## но подготовка удара отменяется и новые атаки не начинаются.
func set_player_hidden(hidden: bool) -> void:
	_target_hidden = hidden
	if hidden:
		if state == State.TELEGRAPH:
			_enter(State.CHASE)
		return
	if state == State.BLOCKED:
		_blocked_retry_left = 0.0
	if _awake and state == State.DORMANT and _has_target():
		if _force_acquire or _can_acquire_target():
			_force_acquire = false
			_enter(State.CHASE)


## Переход в BLOCKED. Вызывается детектором отсутствия продвижения и тестами.
func notify_blocked() -> void:
	if state in [State.DORMANT, State.BLOCKED, State.DEAD]:
		return
	_blocked_retry_left = config.blocked_wait_time
	_enter(State.BLOCKED)
	blocked_started.emit()


## Сценарное отступление. destination — точка, куда уходит монстр.
func start_retreat(destination: Vector3, duration := -1.0) -> bool:
	if state == State.DEAD or not _ai_enabled:
		return false
	_retreat_destination = destination
	_retreat_timeout = duration if duration > 0.0 else config.retreat_duration
	_enter(State.RETREAT)
	return true


func distance_to_target() -> float:
	if not _has_target():
		return INF
	var offset := target.global_position - global_position
	offset.y = 0.0
	return offset.length()


func get_attack_cooldown_left() -> float:
	return _attack_cooldown_left


func state_name() -> String:
	return str(State.keys()[state])


## Проверка прямой видимости до центра цели по слою препятствий.
func has_clear_path_to_target() -> bool:
	if not _has_target():
		return false
	var from := global_position + Vector3.UP * 2.0
	var to := target.global_position + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(from, to, obstacle_mask)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _update_dormant() -> void:
	if not _awake or not _has_target():
		return
	if _force_acquire or _can_acquire_target():
		_force_acquire = false
		_last_known_target_position = target.global_position
		_has_last_known_target = true
		_enter(State.CHASE)


func _update_chase() -> void:
	if not _has_target():
		_lose_target()
		return
	if _target_hidden:
		return
	var distance := distance_to_target()
	if distance > config.lose_range:
		_lose_target()
	elif distance <= config.attack_distance and _attack_cooldown_left <= 0.0 and attack.can_attack():
		_enter(State.TELEGRAPH)


func _update_telegraph() -> void:
	if not _has_target() or _target_hidden:
		_enter(State.CHASE)
		return
	if distance_to_target() > config.lose_range:
		_lose_target()
		return
	if _state_time >= config.telegraph_time:
		_enter(State.ATTACK)


func _update_attack() -> void:
	if _state_time >= attack.stats.active_time:
		_enter(State.RECOVERY)


func _update_recovery() -> void:
	if _state_time < config.recovery_time:
		return
	if not _has_target():
		_lose_target()
	elif not _target_hidden and distance_to_target() > config.lose_range:
		_lose_target()
	else:
		_enter(State.CHASE)


func _update_blocked(delta: float) -> void:
	_blocked_retry_left = maxf(_blocked_retry_left - delta, 0.0)
	if _blocked_retry_left > 0.0:
		return
	if not _has_target():
		_lose_target()
		return
	if not _target_hidden and distance_to_target() > config.lose_range:
		_lose_target()
		return
	# Стоя в BLOCKED, монстр не идёт в стену. Он только проверяет, освободился ли путь.
	if not _target_hidden and has_clear_path_to_target():
		_enter(State.CHASE)
	else:
		_blocked_retry_left = config.blocked_retry_delay


func _update_retreat() -> void:
	if _state_time >= _retreat_timeout:
		_finish_retreat()
		return
	var offset := _retreat_destination - global_position
	offset.y = 0.0
	if offset.length() <= config.retreat_arrival_distance:
		_finish_retreat()


func _desired_horizontal_velocity() -> Vector3:
	match state:
		State.CHASE:
			return _chase_velocity()
		State.RETREAT:
			return _retreat_velocity()
		_:
			return Vector3.ZERO


func _chase_velocity() -> Vector3:
	var destination := _chase_destination()
	if destination == Vector3.INF:
		return Vector3.ZERO
	var offset := destination - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance <= CHASE_STOP_DISTANCE:
		return Vector3.ZERO
	if not _target_hidden and distance_to_target() <= config.attack_distance:
		return Vector3.ZERO
	return offset / distance * config.move_speed


func _retreat_velocity() -> Vector3:
	var offset := _retreat_destination - global_position
	offset.y = 0.0
	if offset.length() <= config.retreat_arrival_distance:
		return Vector3.ZERO
	return offset.normalized() * config.retreat_speed


func _chase_destination() -> Vector3:
	if _target_hidden:
		return _last_known_target_position if _has_last_known_target else Vector3.INF
	if _has_target():
		return target.global_position
	return Vector3.INF


func _update_blocked_detection(delta: float, before: Vector3, intended_speed: float) -> void:
	if state != State.CHASE or not _ai_enabled:
		_no_progress_time = 0.0
		return
	if intended_speed < config.move_speed * 0.5:
		_no_progress_time = maxf(_no_progress_time - delta * 2.0, 0.0)
		return
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	var actual_speed := moved / maxf(delta, 0.0001)
	if actual_speed < config.move_speed * BLOCKED_PROGRESS_FRACTION:
		_no_progress_time += delta
		if _no_progress_time >= config.blocked_detect_time:
			notify_blocked()
	else:
		_no_progress_time = maxf(_no_progress_time - delta * 2.0, 0.0)


func _update_visual(delta: float) -> void:
	if state == State.DEAD:
		return
	var facing := Vector3.ZERO
	if state == State.CHASE:
		var destination := _chase_destination()
		if destination != Vector3.INF:
			facing = destination - global_position
			facing.y = 0.0
	elif state == State.RETREAT:
		facing = _retreat_destination - global_position
		facing.y = 0.0
	if facing.length_squared() > 0.001:
		var target_yaw := atan2(-facing.x, -facing.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, clampf(config.turn_speed * delta, 0.0, 1.0))
	if telegraph_visual.visible:
		var pulse := 1.0 + sin(_state_time * 10.0) * 0.04
		telegraph_visual.scale = Vector3(pulse, 1.0, pulse)


func _enter(new_state: State) -> void:
	var previous := state
	if previous == new_state and new_state != State.ATTACK:
		return
	state = new_state
	_state_time = 0.0
	telegraph_visual.visible = new_state == State.TELEGRAPH
	telegraph_visual.scale = Vector3.ONE
	if new_state not in [State.CHASE, State.RETREAT]:
		velocity.x = 0.0
		velocity.z = 0.0
	if new_state == State.CHASE:
		_no_progress_time = 0.0

	match new_state:
		State.TELEGRAPH:
			_face_target_immediately()
			telegraph_started.emit()
		State.ATTACK:
			if attack.try_attack():
				_attack_cooldown_left = config.time_between_attacks
				attack_started.emit()
			else:
				state = State.RECOVERY
		State.RETREAT:
			pass

	if new_state == State.CHASE and previous == State.DORMANT and _has_target():
		_last_known_target_position = target.global_position
		_has_last_known_target = true

	if debug_log_state_changes:
		print("[MountainKing] %s -> %s" % [State.keys()[previous], State.keys()[state]])
	state_changed.emit(state)


func _face_target_immediately() -> void:
	if not _has_target():
		return
	var offset := target.global_position - global_position
	offset.y = 0.0
	if offset.length_squared() > 0.001:
		visual.rotation.y = atan2(-offset.x, -offset.z)


func _lose_target() -> void:
	_force_acquire = false
	_enter(State.DORMANT)


func _finish_retreat() -> void:
	_awake = false
	_force_acquire = false
	_enter(State.DORMANT)
	retreat_finished.emit()


func _resolve_target() -> Node3D:
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group(&"player") as Node3D
	return target


func _has_target() -> bool:
	if _resolve_target() == null:
		return false
	return not (target.has_method("is_dead") and target.is_dead())


func _can_acquire_target() -> bool:
	if not _has_target() or _target_hidden:
		return false
	return distance_to_target() <= config.detection_range


func _on_died() -> void:
	if state == State.DEAD:
		return
	_ai_enabled = false
	_awake = false
	attack.disable()
	velocity = Vector3.ZERO
	collision_layer = 0
	_enter(State.DEAD)
	var tween := create_tween()
	tween.tween_property(visual, "rotation:z", -1.4, 0.7)

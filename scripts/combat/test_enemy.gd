class_name TestEnemy
extends CharacterBody3D
## Тестовый противник ближнего боя с минимальным конечным автоматом.
## Idle → Chase → Telegraph → Attack → Recovery → (Chase | Idle); из любого состояния → Dead.
## Логика состояний в update_ai() отделена от перемещения, чтобы её можно было тестировать без физики.

signal state_changed(new_state: State)

enum State { IDLE, CHASE, TELEGRAPH, ATTACK, RECOVERY, DEAD }

## Цель для преследования. Если не задана — первый узел группы "player".
@export var target: Node3D
@export var detection_range := 10.0
## Дистанция, на которой преследование прекращается (больше detection_range, чтобы не дёргаться на границе).
@export var lose_range := 15.0
## Дистанция, на которой противник останавливается и начинает подготовку удара.
@export var attack_distance := 1.6
@export var move_speed := 2.8
@export var turn_speed := 8.0
@export var telegraph_time := 0.6
@export var recovery_time := 1.0

var state := State.IDLE
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _state_time := 0.0

@onready var visual: Node3D = $Visual
@onready var health: HealthComponent = $Health
@onready var attack: MeleeAttack = $Visual/MeleeAttack
@onready var telegraph_visual: Node3D = $Visual/TelegraphVisual


func _ready() -> void:
	if target == null:
		target = get_tree().get_first_node_in_group("player") as Node3D
	telegraph_visual.visible = false
	health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	update_ai(delta)

	var desired := Vector3.ZERO
	if state == State.CHASE:
		desired = _flat_direction_to_target() * move_speed
	velocity.x = desired.x
	velocity.z = desired.z
	move_and_slide()

	# Во время подготовки и удара направление зафиксировано — от удара можно уйти в сторону.
	if state == State.CHASE:
		var dir := _flat_direction_to_target()
		if dir.length_squared() > 0.001:
			visual.rotation.y = lerp_angle(visual.rotation.y, _yaw_towards(dir), clampf(turn_speed * delta, 0.0, 1.0))


func update_ai(delta: float) -> void:
	if state == State.DEAD:
		return
	_state_time += delta
	match state:
		State.IDLE:
			if _has_target() and distance_to_target() <= detection_range:
				_enter(State.CHASE)
		State.CHASE:
			if not _has_target() or distance_to_target() > lose_range:
				_enter(State.IDLE)
			elif distance_to_target() <= attack_distance and attack.can_attack():
				_enter(State.TELEGRAPH)
		State.TELEGRAPH:
			if _state_time >= telegraph_time:
				_enter(State.ATTACK)
		State.ATTACK:
			if _state_time >= attack.stats.active_time:
				_enter(State.RECOVERY)
		State.RECOVERY:
			if _state_time >= recovery_time:
				_enter(State.CHASE if _has_target() else State.IDLE)


func distance_to_target() -> float:
	var offset := target.global_position - global_position
	offset.y = 0.0
	return offset.length()


func _flat_direction_to_target() -> Vector3:
	if not _has_target():
		return Vector3.ZERO
	var offset := target.global_position - global_position
	offset.y = 0.0
	return offset.normalized()


## Модель смотрит вдоль -Z.
func _yaw_towards(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


func _has_target() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	return not (target.has_method("is_dead") and target.is_dead())


func _enter(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	telegraph_visual.visible = new_state == State.TELEGRAPH
	if new_state == State.TELEGRAPH:
		# Погоня могла длиться один кадр и не успеть развернуть модель: доворачиваем сразу,
		# дальше направление удара зафиксировано.
		var dir := _flat_direction_to_target()
		if dir.length_squared() > 0.001:
			visual.rotation.y = _yaw_towards(dir)
	if new_state == State.ATTACK and not attack.try_attack():
		# Перезарядка ещё не прошла — сразу переходим к восстановлению.
		state = State.RECOVERY
	state_changed.emit(state)


func _on_died() -> void:
	attack.disable()
	# Тело остаётся лежать на полу, но больше не загораживает проход.
	collision_layer = 0
	_enter(State.DEAD)
	create_tween().tween_property(visual, "rotation:x", -PI / 2.0, 0.4)

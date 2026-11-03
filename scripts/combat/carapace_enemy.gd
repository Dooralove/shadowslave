class_name CarapaceEnemy
extends CharacterBody3D
## Canon carapace scavenger: armored crab-like nightmare creature.
## Separate AI from TestEnemy: sideways scuttle, slower turn, claw snap with a
## short forward lunge. The state names match the existing combat HUD/tests, but
## the decisions, timings and movement are its own.

signal state_changed(new_state: State)

const VFX := preload("res://scripts/vfx/one_shot_vfx.gd")

enum State { IDLE, CHASE, TELEGRAPH, ATTACK, RECOVERY, DEAD }

@export var target: Node3D
@export var data: EnemyData
## Необязательный профиль для спавна с конкретным enemy_tag.
## LabyrinthQuestDirector уже добавляет QuestKillCredit; A05 не правит A03.
@export var spawn_profile: EnemyData
@export var spawn_profile_tag: StringName = &""
@export var detection_range := 11.0
@export var lose_range := 16.0
@export var attack_distance := 2.1
@export var move_speed := 2.1
@export var turn_speed := 4.2
@export var telegraph_time := 0.85
@export var recovery_time := 1.05
@export var acceleration := 9.0
@export var scuttle_strength := 0.28
@export var scuttle_frequency := 6.5
@export var lunge_speed := 3.2
@export var lunge_time := 0.16
## Сколько секунд отсутствия реального продвижения считать застреванием.
@export var stuck_detect_time := 0.7
## Длительность бокового обхода после застревания, с.
@export var avoid_time := 0.55
## Сколько подряд неудачных обходов терпеть, прежде чем отпустить цель.
@export var max_stuck_attempts := 3
## Пауза перед повторным обнаружением после трёх неудачных обходов, с.
@export var blocked_cooldown := 2.0
## Сбрасывать живого врага, когда игрок погибает или возвращается после падения.
## Мёртвые враги не воскрешаются: их kill-credit уже записан в NightmareRunState.
@export var reset_on_player_death := true
## Сколько врагов одной группы могут одновременно готовить/проводить атаку.
## 0 отключает ограничение (используется аренами и тестами).
@export var max_simultaneous_attackers := 2
## Радиус локальной группы. E02/Z13 и E03/Z14 разнесены далеко, поэтому
## общий менеджер групп не нужен.
@export var attack_group_radius := 24.0
## Скорость бокового давления, пока враг ждёт свободный attack token.
@export var pressure_strafe_speed := 0.65
## Минимальный интервал между началами атак в локальной группе, с.
## 0 отключает интервал и оставляет только лимит атакующих.
@export var group_attack_gap := 1.0

var state := State.IDLE
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _state_time := 0.0
var _attack_cooldown_left := 0.0
var _stuck_time := 0.0
var _avoid_left := 0.0
var _avoid_side := 1.0
var _stuck_attempts := 0
var _blocked_left := 0.0
var _dormant := false
var _saved_collision_layer := 0
var _saved_collision_mask := 0
var _scuttle_audio_cd := 0.0
var _hit_tween: Tween
var _spawn_transform := Transform3D.IDENTITY
var _spawn_transform_ready := false
var _target_health: HealthComponent
var _target_recovery: Node
var _reset_pending := false
var _spawn_profile_checked := false
var _spawn_profile_wait_frames := 3
var _telegraph_base_scale := Vector3.ONE

@onready var visual: Node3D = $Visual
@onready var health: HealthComponent = $Health
@onready var attack: MeleeAttack = $Visual/MeleeAttack
@onready var telegraph_visual: Node3D = $Visual/TelegraphVisual


func _ready() -> void:
	if data != null:
		_apply_data(data)
	add_to_group(&"enemy")
	if target == null:
		target = get_tree().get_first_node_in_group(&"player") as Node3D
	telegraph_visual.visible = false
	_telegraph_base_scale = telegraph_visual.scale
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	_saved_collision_layer = collision_layer
	_saved_collision_mask = collision_mask
	call_deferred(&"_capture_spawn_transform")
	call_deferred(&"_apply_spawn_profile")
	_connect_target_health()


func _apply_spawn_profile() -> void:
	if _spawn_profile_checked:
		return
	if spawn_profile == null or spawn_profile_tag == &"":
		_spawn_profile_checked = true
		return
	if data == spawn_profile:
		_spawn_profile_checked = true
		return
	var credit := get_node_or_null(^"QuestKillCredit")
	if credit == null:
		_spawn_profile_wait_frames -= 1
		if _spawn_profile_wait_frames <= 0:
			_spawn_profile_checked = true
		return
	_spawn_profile_checked = true
	if credit.get(&"enemy_tag") != spawn_profile_tag:
		return
	apply_data(spawn_profile)


## Спавнер (LabyrinthQuestDirector) добавляет врага в дерево и только потом
## выставляет global_position. Поэтому снимок нельзя делать в _ready напрямую.
func _capture_spawn_transform() -> void:
	_spawn_transform = global_transform
	_spawn_transform_ready = true


func _target_health_component() -> HealthComponent:
	if target == null or not is_instance_valid(target):
		return null
	var direct := target.get(&"health") as HealthComponent
	if direct != null:
		return direct
	return target.get_node_or_null(^"Health") as HealthComponent


func _connect_target_health() -> void:
	var next_health := _target_health_component()
	if next_health != _target_health:
		if _target_health != null and is_instance_valid(_target_health):
			if _target_health.died.is_connected(_on_target_died):
				_target_health.died.disconnect(_on_target_died)
		_target_health = next_health
		if _target_health != null and not _target_health.died.is_connected(_on_target_died):
			_target_health.died.connect(_on_target_died)
	var next_recovery := _target_recovery_component()
	if next_recovery == _target_recovery:
		return
	if _target_recovery != null and is_instance_valid(_target_recovery) and _target_recovery.has_signal(&"recovered"):
		if _target_recovery.is_connected(&"recovered", _on_target_recovered):
			_target_recovery.disconnect(&"recovered", _on_target_recovered)
	_target_recovery = next_recovery
	if _target_recovery != null and _target_recovery.has_signal(&"recovered") and not _target_recovery.is_connected(&"recovered", _on_target_recovered):
		_target_recovery.connect(&"recovered", _on_target_recovered)


func _target_recovery_component() -> Node:
	if target == null or not is_instance_valid(target):
		return null
	return target.get_node_or_null(^"FallRecovery")


func _on_target_died() -> void:
	_schedule_reset_after_recovery()


func _on_target_recovered(_position: Vector3) -> void:
	_schedule_reset_after_recovery()


func _schedule_reset_after_recovery() -> void:
	if not reset_on_player_death or _reset_pending:
		return
	# FallRecovery возвращает игрока в этом же кадре; сброс делаем после него.
	_reset_pending = true
	call_deferred(&"_reset_after_target_death")


func _reset_after_target_death() -> void:
	_reset_pending = false
	if state == State.DEAD:
		return
	health.revive(true)
	velocity = Vector3.ZERO
	if _spawn_transform_ready:
		global_transform = _spawn_transform
	_state_time = 0.0
	_attack_cooldown_left = 0.0
	_stuck_time = 0.0
	_stuck_attempts = 0
	_avoid_left = 0.0
	_blocked_left = blocked_cooldown
	telegraph_visual.visible = false
	if _dormant:
		return
	attack.disable()
	attack.enabled = true
	collision_layer = _saved_collision_layer
	collision_mask = _saved_collision_mask
	_enter(State.IDLE)


func apply_data(value: EnemyData) -> void:
	data = value
	if is_node_ready() and value != null:
		_apply_data(value)


func _apply_data(value: EnemyData) -> void:
	detection_range = value.detection_range
	lose_range = value.lose_range
	attack_distance = value.attack_distance
	move_speed = value.move_speed
	turn_speed = value.turn_speed
	telegraph_time = value.telegraph_time
	recovery_time = value.recovery_time
	health.configure(value.max_health)
	if value.attack != null:
		attack.configure(value.attack)


func get_display_name() -> String:
	return data.display_name if data != null else "Карапакс-падальщик"


func is_alerted() -> bool:
	return state in [State.CHASE, State.TELEGRAPH, State.ATTACK, State.RECOVERY]


func alert_to(new_target: Node3D = null) -> void:
	if state == State.DEAD:
		return
	if new_target != null:
		target = new_target
	_connect_target_health()
	if state == State.IDLE and _has_target():
		_enter(State.CHASE)


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

	if not _spawn_profile_checked:
		_apply_spawn_profile()
	_connect_target_health()
	update_ai(delta)
	var desired := _desired_velocity()
	var intended_speed := Vector2(desired.x, desired.z).length()
	var before := global_position
	velocity.x = move_toward(velocity.x, desired.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired.z, acceleration * delta)
	move_and_slide()
	_update_stuck(delta, before, intended_speed)
	_update_scuttle_audio(delta)

	if state == State.CHASE:
		var dir := _flat_direction_to_target()
		if dir.length_squared() > 0.001:
			visual.rotation.y = lerp_angle(visual.rotation.y, _yaw_towards(dir), clampf(turn_speed * delta, 0.0, 1.0))
	if telegraph_visual.visible:
		var pulse := 1.0 + sin(_state_time * 9.0) * 0.06
		telegraph_visual.scale = Vector3(
			_telegraph_base_scale.x * pulse,
			_telegraph_base_scale.y,
			_telegraph_base_scale.z * pulse
		)


func update_ai(delta: float) -> void:
	if state == State.DEAD:
		return
	_state_time += delta
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	_blocked_left = maxf(_blocked_left - delta, 0.0)
	_avoid_left = maxf(_avoid_left - delta, 0.0)

	match state:
		State.IDLE:
			if _blocked_left > 0.0:
				return
			if _has_target() and distance_to_target() <= detection_range:
				_enter(State.CHASE)
		State.CHASE:
			if not _has_target() or distance_to_target() > lose_range:
				_enter(State.IDLE)
			elif distance_to_target() <= attack_distance \
					and _attack_cooldown_left <= 0.0 \
					and attack.can_attack() \
					and can_start_attack():
				_enter(State.TELEGRAPH)
		State.TELEGRAPH:
			if not _has_target() or distance_to_target() > lose_range:
				_enter(State.IDLE)
			elif _state_time >= telegraph_time:
				_enter(State.ATTACK)
		State.ATTACK:
			# Ждём фактическое закрытие окна MeleeAttack, а не таймер данных:
			# windup/active могут отличаться от прежней фиксированной пары.
			if attack.phase == MeleeAttack.Phase.RECOVERY or attack.phase == MeleeAttack.Phase.READY:
				_enter(State.RECOVERY)
		State.RECOVERY:
			if _state_time >= recovery_time:
				_enter(State.CHASE if _has_target() else State.IDLE)


func distance_to_target() -> float:
	if not _has_target():
		return INF
	var offset := target.global_position - global_position
	offset.y = 0.0
	return offset.length()


## Сколько живых карапаксов в локальной группе уже готовят или проводят атаку.
func nearby_attacker_count() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group(&"enemy"):
		if node == self:
			continue
		var other := node as CarapaceEnemy
		if other == null or other.state == State.DEAD or other.is_dormant():
			continue
		if global_position.distance_to(other.global_position) > attack_group_radius:
			continue
		if other.state == State.TELEGRAPH or other.state == State.ATTACK:
			count += 1
	return count


## Может ли этот враг занять attack token. 0 атакующих означает без лимита.
func can_start_attack() -> bool:
	if max_simultaneous_attackers > 0 and nearby_attacker_count() >= max_simultaneous_attackers:
		return false
	if group_attack_gap <= 0.0:
		return true
	for node in get_tree().get_nodes_in_group(&"enemy"):
		if node == self:
			continue
		var other := node as CarapaceEnemy
		if other == null or other.state == State.DEAD or other.is_dormant():
			continue
		if global_position.distance_to(other.global_position) > attack_group_radius:
			continue
		if other.state in [State.TELEGRAPH, State.ATTACK, State.RECOVERY] \
				and other._state_time < group_attack_gap:
			return false
	return true


## Временная «спячка» для сценического столкновения: AI и физика выключены,
## тело не блокирует проход. Визуальный Idle может продолжать играть.
func set_dormant(value: bool) -> void:
	if state == State.DEAD:
		return
	if _dormant == value:
		return
	_dormant = value
	if value:
		_saved_collision_layer = collision_layer if collision_layer != 0 else _saved_collision_layer
		_saved_collision_mask = collision_mask if collision_mask != 0 else _saved_collision_mask
		collision_layer = 0
		collision_mask = 0
		velocity = Vector3.ZERO
		attack.disable()
		set_physics_process(false)
		attack.enabled = false
		telegraph_visual.visible = false
	else:
		collision_layer = _saved_collision_layer
		collision_mask = _saved_collision_mask
		set_physics_process(true)
		attack.enabled = true
		_state_time = 0.0
		_stuck_time = 0.0
		_stuck_attempts = 0
		_blocked_left = 0.0
		_enter(State.IDLE)


func is_dormant() -> bool:
	return _dormant


## Публичный сигнал «прямой путь перекрыт»: используется детектором застревания
## и тестами, чтобы не ждать реального столкновения со стеной.
func notify_blocked() -> void:
	if state == State.DEAD or state == State.IDLE:
		return
	_stuck_attempts = max_stuck_attempts
	_blocked_left = blocked_cooldown
	_avoid_left = 0.0
	_enter(State.IDLE)


func _update_stuck(delta: float, before: Vector3, intended_speed: float) -> void:
	if state != State.CHASE:
		_stuck_time = 0.0
		return
	if intended_speed < move_speed * 0.5:
		_stuck_time = maxf(_stuck_time - delta * 2.0, 0.0)
		return
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	var actual_speed := moved / maxf(delta, 0.0001)
	if actual_speed >= move_speed * 0.2:
		_stuck_time = maxf(_stuck_time - delta * 2.0, 0.0)
		if _stuck_time <= 0.0:
			_stuck_attempts = 0
		return
	_stuck_time += delta
	if _stuck_time < stuck_detect_time:
		return
	_stuck_time = 0.0
	_stuck_attempts += 1
	_avoid_left = avoid_time
	_avoid_side = -_avoid_side
	if _stuck_attempts >= max_stuck_attempts:
		notify_blocked()


func _desired_velocity() -> Vector3:
	match state:
		State.CHASE:
			var dir := _flat_direction_to_target()
			if dir.length_squared() < 0.001:
				return Vector3.ZERO
			var side := Vector3(-dir.z, 0.0, dir.x)
			if _avoid_left > 0.0:
				return (dir * 0.2 + side * _avoid_side).normalized() * move_speed
			if distance_to_target() <= attack_distance:
				if not can_start_attack():
					return side * _avoid_side * pressure_strafe_speed
				return Vector3.ZERO
			var sway := sin(_state_time * scuttle_frequency) * scuttle_strength
			return (dir + side * sway).normalized() * move_speed
		State.ATTACK:
			if _state_time <= lunge_time:
				return -visual.global_transform.basis.z * lunge_speed
			return Vector3.ZERO
		_:
			return Vector3.ZERO


func _flat_direction_to_target() -> Vector3:
	if not _has_target():
		return Vector3.ZERO
	var offset := target.global_position - global_position
	offset.y = 0.0
	return offset.normalized()


func _yaw_towards(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


func _has_target() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	return not (target.has_method("is_dead") and target.is_dead())


func _enter(new_state: State) -> void:
	var previous := state
	if previous == new_state and new_state != State.ATTACK:
		return
	state = new_state
	_state_time = 0.0
	telegraph_visual.visible = new_state == State.TELEGRAPH
	telegraph_visual.scale = _telegraph_base_scale
	if new_state == State.TELEGRAPH:
		var dir := _flat_direction_to_target()
		if dir.length_squared() > 0.001:
			visual.rotation.y = _yaw_towards(dir)
		_play_cue(&"creature_carapace_chitter", -7.0)
	if new_state == State.ATTACK:
		if attack.try_attack():
			_attack_cooldown_left = attack.stats.cooldown
			attack_started_audio()
			# Ground dust kicked by the lunge; the claw itself is animated.
			var lunge_point := global_position + Vector3.UP * 0.25 - visual.global_transform.basis.z * 0.8
			VFX.spawn_dust(lunge_point)
		else:
			state = State.RECOVERY
	state_changed.emit(state)


func _update_scuttle_audio(delta: float) -> void:
	_scuttle_audio_cd = maxf(_scuttle_audio_cd - delta, 0.0)
	if state != State.CHASE or _scuttle_audio_cd > 0.0:
		return
	if Vector2(velocity.x, velocity.z).length() < 0.25:
		return
	_scuttle_audio_cd = randf_range(0.45, 0.7)
	_play_cue(&"creature_carapace_click", -13.0)


func attack_started_audio() -> void:
	_play_cue(&"creature_carapace_attack", -4.0)


func _play_cue(cue_id: StringName, volume_db := 0.0) -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	if director != null and director.has_method(&"play_sfx"):
		director.call(&"play_sfx", cue_id, global_position, volume_db)


func _on_damaged(_amount: float) -> void:
	if state == State.DEAD or visual == null:
		return
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	_hit_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hit_tween.tween_property(visual, "rotation:z", 0.09, 0.05)
	_hit_tween.tween_property(visual, "rotation:z", 0.0, 0.16)


func _on_died() -> void:
	attack.disable()
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	var weak_spot := get_node_or_null(^"Visual/Model/WeakSpot") as Node3D
	if weak_spot != null:
		weak_spot.visible = false
	_enter(State.DEAD)
	_play_cue(&"creature_carapace_death", -2.0)
	VFX.spawn_death(global_position + Vector3.UP * 0.45, visual.rotation.y)

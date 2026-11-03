class_name CombatController
extends Node
## Боевые действия Санни: лёгкий удар, уклонение с i-frames и блок.
##
## Контроллер не знает конкретных атак и врагов: параметры приходят из
## CombatSettings / AttackData. Поэтому новый лёгкий удар или режим без оружия
## меняет ресурс, а не код. Само попадание по-прежнему считает MeleeAttack.

signal combat_changed(active: bool)
signal combat_target_changed(target: Node3D)
signal dodge_started(direction: Vector3)
signal dodge_finished
signal block_changed(active: bool)
signal guard_broken

const SETTINGS_PATH := "res://resources/combat/combat_settings.tres"
const ARMED_ATTACK_PATH := "res://resources/combat/attacks/sunny_light_armed.tres"
const UNARMED_ATTACK_PATH := "res://resources/combat/attacks/sunny_light_unarmed.tres"

@export var body: SunnyController
@export var attack: MeleeAttack
@export var health: HealthComponent
@export var stamina: StaminaComponent
@export var hurtbox: Hurtbox
@export var animator: SunnyAnimator
@export var fall_recovery: FallRecovery
@export var settings: CombatSettings
@export var armed_attack: AttackData
@export var unarmed_attack: AttackData
@export var armed_attack_clip: StringName = &"1H_Melee_Attack_Slice_Diagonal"
@export var unarmed_attack_clip: StringName = &"Punch_Jab"
@export var guard_clip_armed: StringName = &"Blocking"
@export var guard_clip_unarmed: StringName = &"Punch_Enter"
## Клип реакции на удар по блоку. Если клипа нет, аниматор оставит Hit.
@export var block_hit_clip: StringName = &"Block_Hit"
## Клип пробоя блока. Если клипа нет, аниматор оставит Hit.
@export var guard_break_clip: StringName = &"Block_Hit"
@export var dodge_clip: StringName = &"Dodge_Backward"
## Необязательный визуальный корень оружия: скрывается в режиме без оружия.
@export var weapon_root: Node3D
## Новый слой экипировки. Если назначен, именно он владеет видимостью оружия.
@export var equipment: EquipmentComponent
## Для тестов и сцен, где бой включается постановкой, а не радиусом врага.
@export var force_combat := false
## Стартовать без оружия (пролог/плен): скрывает weapon_root и берёт unarmed-атаку.
@export var start_unarmed := false

var _combat_active := false
var _combat_grace_left := 0.0
var _blocking := false
var _block_requires_release := false
var _dodge_time_left := 0.0
var _iframe_left := 0.0
var _hurt_iframe_left := 0.0
var _stagger_time_left := 0.0
var _unarmed := false
var _dead := false
var _enemy_check_timer := 0.0
var _nearest_enemy: Node3D
var _combat_target: Node3D
## Внешние множители от CharacterStats: броня/перегруз/сет-бонусы.
## 1.0 и 0.0 сохраняют прежнее поведение, если CharacterStats не подключён.
var external_move_speed_multiplier := 1.0
var external_stagger_resistance := 0.0


func _ready() -> void:
	if body == null:
		body = get_parent() as SunnyController
	if settings == null:
		settings = load(SETTINGS_PATH) as CombatSettings
	if armed_attack == null:
		armed_attack = load(ARMED_ATTACK_PATH) as AttackData
	if unarmed_attack == null:
		unarmed_attack = load(UNARMED_ATTACK_PATH) as AttackData
	if stamina != null and settings != null:
		stamina.configure(settings)
	if attack != null:
		attack.configure(armed_attack)
	if animator != null:
		animator.set_attack_clip(armed_attack_clip)
		animator.set_guard_clip(guard_clip_armed)
		animator.set_dodge_clip(dodge_clip)
		animator.set_block_hit_clip(block_hit_clip)
		animator.set_guard_break_clip(guard_break_clip)
	if equipment == null and body != null:
		equipment = body.get_node_or_null(^"Equipment") as EquipmentComponent
	if weapon_root == null and body != null:
		var model := body.get_node_or_null("Visual/ModelPoc")
		if model != null and model.has_method(&"get_weapon_socket"):
			weapon_root = model.call(&"get_weapon_socket") as Node3D
	if start_unarmed:
		set_unarmed(true)
	else:
		_sync_weapon_visual()
	if health != null:
		health.died.connect(_on_died)
	if hurtbox != null:
		hurtbox.hit_received.connect(_on_hurtbox_hit_received)
	_refresh_combat_state(true)


func _physics_process(delta: float) -> void:
	_enemy_check_timer -= delta
	if _enemy_check_timer <= 0.0:
		_enemy_check_timer = 0.2
		_refresh_combat_state(false)
	_update_blocking()
	advance(delta)


## Публичный шаг таймеров: используется физикой и тестами.
func advance(delta: float) -> void:
	if _stagger_time_left > 0.0:
		_stagger_time_left = maxf(_stagger_time_left - delta, 0.0)
	if _iframe_left > 0.0:
		_iframe_left = maxf(_iframe_left - delta, 0.0)
		_refresh_invulnerability()
	if _hurt_iframe_left > 0.0:
		_hurt_iframe_left = maxf(_hurt_iframe_left - delta, 0.0)
		_refresh_invulnerability()
	if _dodge_time_left > 0.0:
		_dodge_time_left = maxf(_dodge_time_left - delta, 0.0)
		if _dodge_time_left <= 0.0:
			dodge_finished.emit()
	if _combat_grace_left > 0.0:
		_combat_grace_left = maxf(_combat_grace_left - delta, 0.0)
		if _combat_grace_left <= 0.0:
			_refresh_combat_state(false)


func handle_input(event: InputEvent) -> bool:
	if body == null or not body.controls_enabled or not body.input_enabled:
		return false
	if event.is_action_pressed(&"attack") and body.camera_rig.is_mouse_captured():
		return try_light_attack()
	if event.is_action_pressed(&"jump") and is_in_combat():
		return try_dodge()
	return false


func try_light_attack() -> bool:
	if not _can_act() or _blocking or _dodge_time_left > 0.0:
		return false
	if attack == null or not attack.can_attack():
		return false
	var data := current_attack_data()
	var cost := data.stamina_cost if data != null else 0.0
	if stamina != null and not stamina.spend(cost):
		return false
	_combat_grace_left = settings.combat_grace if settings != null else 0.0
	var started := attack.try_attack()
	if started:
		_play_audio(&"combat_swing_unarmed" if _unarmed else &"combat_swing_armed")
	return started


func try_dodge() -> bool:
	if not _can_act() or _blocking or _dodge_time_left > 0.0:
		return false
	if settings == null or stamina == null:
		return false
	if not stamina.spend(settings.dodge_stamina_cost):
		return false
	var direction := dodge_direction()
	_dodge_time_left = settings.dodge_duration
	_iframe_left = settings.dodge_iframe_time
	_refresh_invulnerability()
	if body != null:
		body.start_dodge(direction, settings.dodge_speed, settings.dodge_duration)
		if direction.length_squared() > 0.001:
			body.visual.rotation.y = atan2(-direction.x, -direction.z)
	if animator != null:
		animator.play_dodge(dodge_clip)
	_combat_grace_left = settings.combat_grace
	_play_audio(&"combat_dodge")
	dodge_started.emit(direction)
	return true


func dodge_direction() -> Vector3:
	if body == null:
		return Vector3.BACK
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if input.length() > 0.1:
		var direction := body.camera_rig.get_planar_basis() * Vector3(input.x, 0.0, input.y)
		if direction.length_squared() > 0.001:
			return direction.normalized()
	return body.visual.global_transform.basis * Vector3(0.0, 0.0, 1.0)


func set_blocking(value: bool) -> void:
	if _blocking == value:
		return
	_blocking = value
	if hurtbox != null:
		hurtbox.damage_scale = settings.block_damage_multiplier if value and settings != null else 1.0
	if animator != null:
		animator.set_guard(value)
	if value:
		_play_audio(&"combat_block_leather" if _unarmed else &"combat_block_metal", -2.0)
	block_changed.emit(value)


func is_blocking() -> bool:
	return _blocking


func is_dodging() -> bool:
	return _dodge_time_left > 0.0


func is_staggered() -> bool:
	return _stagger_time_left > 0.0


## Открыт ли сейчас любой источник неуязвимости: уклонение или короткий
## post-hit i-frame. Нужен HUD/тестам и не даёт двум ударам сложиться в один стан.
func is_invulnerable() -> bool:
	return _iframe_left > 0.0 or _hurt_iframe_left > 0.0


func is_in_combat() -> bool:
	return force_combat or _combat_active or _combat_grace_left > 0.0


## Текущая цель боя для HUD. null, если живого врага в combat_radius нет.
func get_combat_target() -> Node3D:
	if _combat_target == null or not is_instance_valid(_combat_target):
		return null
	var target_health := _combat_target.get_node_or_null(^"Health") as HealthComponent
	if target_health != null and target_health.is_dead():
		return null
	return _combat_target


func get_move_speed_multiplier() -> float:
	var multiplier := 1.0
	if _blocking and settings != null:
		multiplier = settings.block_move_multiplier
	return multiplier * clampf(external_move_speed_multiplier, 0.4, 1.6)


## Вызывается CharacterStats. Не трогает блок: итог перемножается в
## get_move_speed_multiplier(), поэтому оба источника штрафа сохраняются.
func set_external_move_speed_multiplier(value: float) -> void:
	external_move_speed_multiplier = clampf(value, 0.4, 1.6)


func set_external_stagger_resistance(value: float) -> void:
	external_stagger_resistance = clampf(value, 0.0, 0.9)


func current_attack_data() -> AttackData:
	if attack == null:
		return unarmed_attack if _unarmed else armed_attack
	return attack.stats as AttackData


func set_unarmed(value: bool) -> void:
	_unarmed = value
	var data := unarmed_attack if value else armed_attack
	if data != null and attack != null:
		attack.configure(data)
	if animator != null:
		animator.set_attack_clip(unarmed_attack_clip if value else armed_attack_clip)
		animator.set_guard_clip(guard_clip_unarmed if value else guard_clip_armed)
	_sync_weapon_visual()


func _sync_weapon_visual() -> void:
	if equipment != null:
		equipment.set_weapon_drawn(not _unarmed)
	elif weapon_root != null:
		weapon_root.visible = not _unarmed


func is_unarmed() -> bool:
	return _unarmed


## Явный armed-профиль для квестового оружия (Azure Blade).
## Возвращает false, если клип отсутствует у текущей модели: не подменяем
## визуал кулака «оружейным» уроном без клипа.
func equip_armed(data: AttackData, clip: StringName) -> bool:
	if data == null or clip == &"":
		return false
	if attack != null and attack.is_attacking():
		return false
	if animator != null and animator.animation_player != null:
		if not animator.animation_player.has_animation(clip):
			return false
	armed_attack = data
	armed_attack_clip = clip
	set_unarmed(false)
	return true


func set_forced_combat(value: bool) -> void:
	force_combat = value
	_refresh_combat_state(true)


func reset_after_recovery() -> void:
	_dead = false
	_block_requires_release = false
	_set_stagger(0.0)
	_dodge_time_left = 0.0
	_iframe_left = 0.0
	_hurt_iframe_left = 0.0
	_combat_grace_left = 0.0
	set_blocking(false)
	if hurtbox != null:
		hurtbox.invulnerable = false
		hurtbox.damage_scale = 1.0
	if stamina != null:
		stamina.refill()
	if attack != null:
		attack.enabled = true
	if body != null:
		body.cancel_dodge()
	if animator != null:
		animator.set_guard(false)
	_refresh_combat_state(true)


func _play_audio(cue_id: StringName, volume_offset_db := 0.0) -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	if director == null or body == null or not director.has_method(&"play_sfx"):
		return
	director.call(&"play_sfx", cue_id, body.global_position, volume_offset_db)


func _can_act() -> bool:
	if _dead or body == null or not body.controls_enabled or not body.input_enabled:
		return false
	if not body.combat_enabled:
		return false
	if _stagger_time_left > 0.0:
		return false
	return true


func _update_blocking() -> void:
	if body == null or not body.combat_enabled:
		if _blocking:
			set_blocking(false)
		return
	if not is_in_combat() or _dead or _stagger_time_left > 0.0 or attack == null:
		if _blocking:
			set_blocking(false)
		return
	if attack.is_attacking() or _dodge_time_left > 0.0:
		if _blocking:
			set_blocking(false)
		return
	var held := Input.is_action_pressed(&"sprint")
	if not held:
		_block_requires_release = false
		if _blocking:
			set_blocking(false)
		return
	if _block_requires_release:
		return
	if not _blocking:
		set_blocking(true)
	if _blocking and stamina != null and settings != null:
		if not stamina.drain(settings.block_stamina_per_second * get_physics_process_delta_time()):
			_break_guard()


func _on_hurtbox_hit_received(amount: float, source: Node) -> void:
	if amount <= 0.0 or _dead:
		return
	_combat_grace_left = settings.combat_grace if settings != null else 0.0
	if settings != null and settings.post_hit_iframe_time > 0.0:
		_hurt_iframe_left = maxf(_hurt_iframe_left, settings.post_hit_iframe_time)
		_refresh_invulnerability()
	if not _blocking or stamina == null:
		return
	if animator != null:
		animator.play_block_hit()
	var cost := settings.block_stamina_per_hit if settings != null else 15.0
	if source is MeleeAttack:
		var source_data := (source as MeleeAttack).stats as AttackData
		if source_data != null:
			cost = source_data.guard_damage
	if not stamina.spend(cost):
		_break_guard()


func _break_guard() -> void:
	set_blocking(false)
	if animator != null:
		animator.play_guard_break()
	_play_audio(&"combat_guard_break")
	var base_stagger := settings.guard_break_stagger if settings != null else 0.9
	_set_stagger(base_stagger * (1.0 - clampf(external_stagger_resistance, 0.0, 0.9)))
	guard_broken.emit()


func _set_stagger(seconds: float) -> void:
	_stagger_time_left = maxf(seconds, 0.0)


func _refresh_invulnerability() -> void:
	if hurtbox != null:
		hurtbox.invulnerable = _iframe_left > 0.0 or _hurt_iframe_left > 0.0


func _on_died() -> void:
	_dead = true
	_set_stagger(0.0)
	_dodge_time_left = 0.0
	_iframe_left = 0.0
	_hurt_iframe_left = 0.0
	set_blocking(false)
	if hurtbox != null:
		hurtbox.invulnerable = false
		hurtbox.damage_scale = 1.0


func _refresh_combat_state(force_emit: bool) -> void:
	_nearest_enemy = _find_nearest_enemy()
	var next_target: Node3D = null
	if _nearest_enemy != null and settings != null and body != null:
		var distance := body.global_position.distance_to(_nearest_enemy.global_position)
		if distance <= settings.combat_radius:
			next_target = _nearest_enemy
			if not force_combat:
				_combat_grace_left = settings.combat_grace
	_set_combat_target(next_target)
	var active := force_combat or _combat_grace_left > 0.0
	if active != _combat_active or force_emit:
		_combat_active = active
		combat_changed.emit(active)
	if active and not _blocking:
		_block_requires_release = Input.is_action_pressed(&"sprint")


func _set_combat_target(value: Node3D) -> void:
	if value == _combat_target:
		return
	_combat_target = value
	combat_target_changed.emit(_combat_target)


func _find_nearest_enemy() -> Node3D:
	if body == null:
		return null
	var best: Node3D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var candidate := node as Node3D
		if candidate == null or not is_instance_valid(candidate):
			continue
		if candidate.has_method(&"is_dormant") and bool(candidate.call(&"is_dormant")):
			continue
		var enemy_health := candidate.get_node_or_null(^"Health") as HealthComponent
		if enemy_health != null and enemy_health.is_dead():
			continue
		var distance := body.global_position.distance_to(candidate.global_position)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best

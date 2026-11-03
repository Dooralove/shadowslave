class_name CarapaceAnimator
extends Node
## Visual layer for CarapaceEnemy. One clip covers telegraph -> attack -> recovery.
## Hit reaction is a short procedural recoil on the model node: the rig has no
## dedicated hit clip, and the animation clip must not be interrupted while the
## claw is committed.

@export var enemy: CarapaceEnemy
@export var animation_player: AnimationPlayer
@export var health: HealthComponent
@export var attack: MeleeAttack
## Node3D, который получает процедурную реакцию. Обычно Visual/Model.
@export var model: Node3D

@export_group("Clips")
@export var idle_clip: StringName = &"Idle"
@export var chase_clip: StringName = &"Walk"
@export var attack_clip: StringName = &"Attack"
@export var death_clip: StringName = &"Death"
## Authored hit reaction (A06). Если клипа нет, остаётся procedural flinch.
@export var hit_clip: StringName = &"Hit"

const AUTHORED_HIT := preload("res://assets/animations/enemies/carapace_hit.tres")

@export_group("Tuning")
## Момент контакта в клипе Attack, измерен по скорости LeftPincer: 0.40 с.
@export var attack_contact_time := 0.40
@export var chase_clip_speed := 2.0
@export var blend_time := 0.12
## Длительность и амплитуда процедурной реакции на урон.
@export var flinch_angle := 0.12
@export var flinch_distance := 0.08
@export var flinch_time := 0.08

var _flinch_tween: Tween
var _base_model_position := Vector3.ZERO
var _base_model_rotation := Vector3.ZERO


func _ready() -> void:
	enemy.state_changed.connect(_on_state_changed)
	if health != null:
		health.damaged.connect(_on_damaged)
	_ensure_authored_hit()
	animation_player.animation_finished.connect(_on_animation_finished)
	if model != null:
		_base_model_position = model.position
		_base_model_rotation = model.rotation
	for clip_name in [idle_clip, chase_clip]:
		var anim := animation_player.get_animation(clip_name)
		if anim != null:
			anim.loop_mode = Animation.LOOP_LINEAR
	_play_state_clip()


## A06 положил hit-клип отдельной AnimationLibrary, а GLB-библиотека его не
## содержит. Добавляем клип в default library, чтобы authored-реакция реально
## играла, а procedural flinch оставался fallback'ом.
func _ensure_authored_hit() -> void:
	if animation_player == null or hit_clip == &"":
		return
	if animation_player.has_animation(hit_clip):
		return
	var library := AUTHORED_HIT as AnimationLibrary
	if library == null:
		return
	var clip := library.get_animation(&"Hit")
	if clip == null:
		return
	var default_library := animation_player.get_animation_library(&"")
	if default_library == null:
		default_library = AnimationLibrary.new()
		animation_player.add_animation_library(&"", default_library)
	default_library.add_animation(hit_clip, clip)


func attack_clip_speed() -> float:
	if attack == null or attack.stats == null:
		return 1.0
	var contact_at := enemy.telegraph_time + attack.stats.windup_time + attack.stats.active_time * 0.5
	var contact := attack_contact_time
	var value: Variant = attack.stats.get(&"contact_time")
	if value != null and float(value) > 0.0:
		contact = float(value)
	if contact_at <= 0.0:
		return 1.0
	return clampf(contact / contact_at, 0.36, 1.30)


func _on_state_changed(new_state: CarapaceEnemy.State) -> void:
	if new_state in [CarapaceEnemy.State.TELEGRAPH, CarapaceEnemy.State.ATTACK, CarapaceEnemy.State.DEAD]:
		_kill_flinch()
	_play_state_clip(new_state)


func _play_state_clip(state: CarapaceEnemy.State = enemy.state) -> void:
	match state:
		CarapaceEnemy.State.IDLE:
			_play(idle_clip)
		CarapaceEnemy.State.CHASE:
			_play(chase_clip)
			animation_player.speed_scale = clampf(enemy.move_speed / chase_clip_speed, 0.6, 1.5)
		CarapaceEnemy.State.TELEGRAPH:
			_play(attack_clip, 0.05)
			animation_player.speed_scale = attack_clip_speed()
		CarapaceEnemy.State.ATTACK, CarapaceEnemy.State.RECOVERY:
			if animation_player.assigned_animation != String(attack_clip):
				_play(idle_clip)
		CarapaceEnemy.State.DEAD:
			_play(death_clip, 0.1)
			animation_player.speed_scale = 1.0


func _on_animation_finished(clip: StringName) -> void:
	if clip == attack_clip and enemy.state == CarapaceEnemy.State.RECOVERY:
		_play(idle_clip)
	elif clip == hit_clip \
			and enemy.state not in [CarapaceEnemy.State.TELEGRAPH, CarapaceEnemy.State.ATTACK, CarapaceEnemy.State.DEAD]:
		_play_state_clip()


func _play_hit_clip() -> bool:
	if hit_clip == &"" or animation_player == null or not animation_player.has_animation(hit_clip):
		return false
	_kill_flinch()
	animation_player.speed_scale = 1.0
	animation_player.play(hit_clip, 0.05)
	return true


func _on_damaged(_amount: float) -> void:
	# Не сбиваем замах/удар и не дёргаем труп. current_health уже уменьшен,
	# поэтому смертельный удар тоже не запускает flinch.
	if health != null and health.current_health <= 0.0:
		return
	if enemy.state in [CarapaceEnemy.State.TELEGRAPH, CarapaceEnemy.State.ATTACK, CarapaceEnemy.State.DEAD]:
		return
	if _play_hit_clip():
		return
	if model == null:
		return
	_kill_flinch()
	_flinch_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flinch_tween.tween_property(model, "rotation:x", _base_model_rotation.x - flinch_angle, flinch_time)
	_flinch_tween.parallel().tween_property(model, "position:z", _base_model_position.z + flinch_distance, flinch_time)
	_flinch_tween.tween_property(model, "rotation:x", _base_model_rotation.x, flinch_time * 2.0)
	_flinch_tween.parallel().tween_property(model, "position:z", _base_model_position.z, flinch_time * 2.0)


func _kill_flinch() -> void:
	if _flinch_tween != null and _flinch_tween.is_valid():
		_flinch_tween.kill()
	_flinch_tween = null
	if model != null:
		model.position = _base_model_position
		model.rotation = _base_model_rotation


func _play(clip: StringName, blend := -1.0) -> void:
	animation_player.speed_scale = 1.0
	animation_player.play(clip, blend_time if blend < 0.0 else blend)
	animation_player.seek(0.0, true)

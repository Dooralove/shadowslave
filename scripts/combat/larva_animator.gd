class_name LarvaAnimator
extends Node
## Процедурная читаемая анимация личинки без AnimationPlayer:
## замах — приподняться и откинуться, удар — выпад вперёд, смерть — завалиться.
## Решения принимает TestEnemy; этот узел только двигает модель.

@export var enemy: TestEnemy
@export var model: Node3D
@export var telegraph: Node3D
@export var health: HealthComponent
@export var animation_player: AnimationPlayer
@export var hit_clip: StringName = &"Hit"
@export var death_clip: StringName = &"Death"
@export var idle_writhe := 0.035
@export var chase_bob := 0.025
## Амплитуда короткой реакции на урон.
@export var flinch_scale := 0.06

const AUTHORED_HIT := preload("res://assets/animations/enemies/larva_hit.tres")
const AUTHORED_DEATH := preload("res://assets/animations/enemies/larva_death.tres")

var _tween: Tween
var _hit_tween: Tween
var _time := 0.0
var _base_position := Vector3.ZERO
var _base_scale := Vector3.ONE


func _ready() -> void:
	if enemy != null:
		enemy.state_changed.connect(_on_state_changed)
	if health != null:
		health.damaged.connect(_on_damaged)
	if model != null:
		_base_position = model.position
		_base_scale = model.scale
		if animation_player == null:
			animation_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_ensure_authored_clips()
	if animation_player != null and not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)
	_on_state_changed(enemy.state if enemy != null else TestEnemy.State.IDLE)


## A06 положил Hit/Death отдельными AnimationLibrary; GLB-библиотека личинки
## содержит только Idle. Добавляем authored-клипы, чтобы реакции не были
## чисто процедурными.
func _ensure_authored_clips() -> void:
	if animation_player == null:
		return
	var default_library := animation_player.get_animation_library(&"")
	if default_library == null:
		default_library = AnimationLibrary.new()
		animation_player.add_animation_library(&"", default_library)
	_add_clip(default_library, AUTHORED_HIT, &"Hit", hit_clip)
	_add_clip(default_library, AUTHORED_DEATH, &"Death", death_clip)


func _add_clip(target: AnimationLibrary, source: AnimationLibrary, source_name: StringName, target_name: StringName) -> void:
	if target == null or target_name == &"" or target.has_animation(target_name):
		return
	if source == null:
		return
	var clip := source.get_animation(source_name)
	if clip != null:
		target.add_animation(target_name, clip)


func _process(delta: float) -> void:
	if model == null or enemy == null:
		return
	_time += delta
	if enemy.state == TestEnemy.State.IDLE or enemy.state == TestEnemy.State.CHASE:
		model.rotation.z = sin(_time * 5.0) * idle_writhe
		model.position.y = _base_position.y + absf(sin(_time * 4.0)) * chase_bob


func _on_state_changed(state: TestEnemy.State) -> void:
	if model == null:
		return
	_kill_tween()
	_kill_hit_tween()
	match state:
		TestEnemy.State.TELEGRAPH:
			# Замах: личинка приподнимается и откидывается назад. Красное кольцо
			# под ней уже показывает TestEnemy.
			_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tween.tween_property(model, "rotation:x", -0.55, 0.18)
			_tween.parallel().tween_property(model, "position:y", _base_position.y + 0.16, 0.18)
			_tween.parallel().tween_property(model, "scale", _base_scale * 1.12, 0.18)
		TestEnemy.State.ATTACK:
			# Выпад: тело уходит вперёд, к игроку.
			_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			_tween.tween_property(model, "rotation:x", 0.32, 0.07)
			_tween.parallel().tween_property(model, "position:z", _base_position.z - 0.42, 0.07)
			_tween.parallel().tween_property(model, "scale", _base_scale * 0.96, 0.07)
		TestEnemy.State.RECOVERY:
			_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tween.tween_property(model, "rotation:x", 0.0, 0.22)
			_tween.parallel().tween_property(model, "position", _base_position, 0.22)
			_tween.parallel().tween_property(model, "scale", _base_scale, 0.22)
		TestEnemy.State.DEAD:
			if _play_death_clip():
				return
			_tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			_tween.tween_property(model, "rotation:z", 1.45, 0.35)
			_tween.parallel().tween_property(model, "scale:y", _base_scale.y * 0.22, 0.35)
			_tween.parallel().tween_property(model, "position:y", _base_position.y, 0.35)
		_:
			model.rotation = Vector3.ZERO
			model.position = _base_position
			model.scale = _base_scale


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _on_damaged(_amount: float) -> void:
	# Реакция только в Idle/Chase и только если удар не смертельный:
	# телеграф и удар — обязательство, их нельзя сбивать.
	if model == null or enemy == null:
		return
	if health != null and health.current_health <= 0.0:
		return
	if enemy.state in [TestEnemy.State.TELEGRAPH, TestEnemy.State.ATTACK, TestEnemy.State.DEAD]:
		return
	if _play_hit_clip():
		return
	_kill_hit_tween()
	_hit_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hit_tween.tween_property(model, "scale", _base_scale * (1.0 - flinch_scale), 0.07)
	_hit_tween.tween_property(model, "scale", _base_scale, 0.16)


func _play_hit_clip() -> bool:
	if animation_player == null or not animation_player.has_animation(hit_clip):
		return false
	_kill_hit_tween()
	animation_player.play(hit_clip, 0.05)
	return true


func _play_death_clip() -> bool:
	if animation_player == null or not animation_player.has_animation(death_clip):
		return false
	_kill_hit_tween()
	animation_player.play(death_clip, 0.05)
	return true


func _on_animation_finished(clip: StringName) -> void:
	if clip == hit_clip and enemy != null and enemy.state != TestEnemy.State.DEAD:
		if animation_player != null and animation_player.has_animation(&"Idle"):
			animation_player.play(&"Idle", 0.1)


func _kill_hit_tween() -> void:
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	_hit_tween = null
	if model != null:
		model.scale = _base_scale

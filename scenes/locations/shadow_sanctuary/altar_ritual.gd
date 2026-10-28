class_name AltarRitual
extends Node
## Каноническое подношение алтарю: семь строк Заклятия, приход Тирана,
## смерть Тирана от теней и три завершающих строки.
##
## Ритуал не завершает Первый Кошмар и не выдаёт оценку: после `finished`
## оболочка святилища только подтверждает смерть Тирана и переходит к оценке.
## Тайминги и тексты отделены от геометрии алтаря.

signal stage_changed(stage: Stage)
signal finished

enum Stage {
	IDLE,
	STARTING,
	SPELL,
	TYRANT,
	DEATH,
	FINISHED,
}

const OFFERING_IDS: Array[StringName] = [
	&"altar_sacrifice",
	&"altar_gods_dead",
	&"altar_mark_of_divinity",
	&"altar_temple_slave",
	&"altar_shadow_god_stirs",
	&"altar_blessing_beyond_grave",
	&"altar_child_of_shadows",
]
const DEATH_IDS: Array[StringName] = [
	&"altar_tyrant_slain",
	&"altar_wake_up",
	&"altar_prepare_appraisal",
]

@export var controller: SanctuaryController
@export var altar: Interactable
## Каталог канонических строк алтаря.
@export var messages: SpellMessageCatalog
@export var spell_overlay: SpellOverlay
@export var hud: SanctuaryUI
@export var ritual_light: OmniLight3D
@export var ritual_glow: MeshInstance3D
@export var player: SunnyController
## Силуэт Горного Короля у входа. Появляется только во время ритуала.
@export var tyrant: Node3D
## Чёрные руки/щупальца, которые убивают Тирана.
@export var shadow_hands: Node3D

@export_range(0.0, 5.0, 0.05, "suffix:s") var start_delay := 0.8
@export_range(0.0, 3.0, 0.05, "suffix:s") var line_gap := 0.2
@export_range(0.0, 5.0, 0.05, "suffix:s") var finale_delay := 0.8
## Блокирует управление Санни на время последовательности.
@export var lock_player := true
## Тестовый режим: без длинных твинов и пауз, но с теми же флагами и сообщениями.
@export var fast_mode := false

var stage := Stage.IDLE

var _running := false
var _finished := false
var _saved_input_enabled := true
var _saved_combat_enabled := true


func _ready() -> void:
	if altar != null:
		altar.interacted.connect(_on_altar_interacted)
	if controller != null:
		controller.altar_ready.connect(_on_altar_ready)
	_set_ritual_visuals(false)
	if tyrant != null:
		tyrant.visible = false
	if shadow_hands != null:
		shadow_hands.visible = false
	if hud != null:
		hud.show_status("")


## Временная модель доступности. Здесь появится проверка HP/крови.
func can_offer() -> bool:
	return controller != null and not controller.is_completed()


func is_running() -> bool:
	return _running


func is_finished() -> bool:
	return _finished


## Запускает ритуал. Повторный вызов во время или после ритуала игнорируется.
func begin() -> void:
	if _running or _finished:
		return
	if not can_offer():
		return
	if controller == null or altar == null:
		push_error("AltarRitual: не заданы controller или altar")
		return
	if not controller.begin_offering():
		return

	_running = true
	stage = Stage.STARTING
	stage_changed.emit(stage)
	altar.enabled = false
	_lock_player(true)
	_set_ritual_visuals(true)
	if hud != null:
		hud.show_status("Алтарь принимает подношение…")

	await _wait(start_delay)

	if hud != null:
		hud.show_status("")
	stage = Stage.SPELL
	stage_changed.emit(stage)
	for message in _messages_by_ids(OFFERING_IDS):
		controller.announce_spell_message(message.text, SanctuaryController.Evaluation.NONE)
		await _present(message)
		await _wait(line_gap)

	# Тиран входит в зал. Это не бой: игрок не может атаковать или убежать.
	stage = Stage.TYRANT
	stage_changed.emit(stage)
	await _summon_tyrant()
	if not fast_mode:
		await _wait(1.4)
	stage = Stage.DEATH
	stage_changed.emit(stage)
	await _kill_tyrant()

	for message in _messages_by_ids(DEATH_IDS):
		controller.announce_spell_message(message.text, SanctuaryController.Evaluation.NONE)
		await _present(message)
		await _wait(line_gap)

	NightmareRunState.set_flag(&"tyrant_death_confirmed")
	NightmareRunState.set_flag(&"trial_completed")
	if hud != null:
		hud.show_status("Испытание завершено. Оценка ещё не началась.")
	await _wait(finale_delay)

	stage = Stage.FINISHED
	stage_changed.emit(stage)
	_finished = true
	_running = false
	_lock_player(false)
	finished.emit()


func _on_altar_interacted(id: StringName) -> void:
	if id == &"altar_offering":
		begin()


func _on_altar_ready() -> void:
	if hud != null and not _running and not _finished:
		hud.show_status("Алтарь ждёт подношения.")


func _messages_by_ids(ids: Array[StringName]) -> Array[SpellMessage]:
	var result: Array[SpellMessage] = []
	if messages == null:
		push_error("AltarRitual: не задан каталог сообщений")
		return result
	for id in ids:
		var message := messages.get_message(id)
		if message == null or not message.is_valid():
			push_warning("AltarRitual: нет канонического сообщения %s" % id)
			continue
		result.append(message)
	return result


func _present(message: SpellMessage) -> void:
	if spell_overlay != null:
		await spell_overlay.display_spell_message(message.text, message.duration)
	else:
		await _wait(message.duration)


func _summon_tyrant() -> void:
	if tyrant == null:
		return
	tyrant.visible = true
	if fast_mode:
		tyrant.global_position = Vector3(0.0, 0.05, 1.8)
		return
	var tween := create_tween()
	tween.tween_property(tyrant, "global_position", Vector3(0.0, 0.05, 1.8), 1.8).set_trans(Tween.TRANS_SINE)
	await tween.finished


func _kill_tyrant() -> void:
	if shadow_hands != null:
		shadow_hands.visible = true
		for child in shadow_hands.get_children():
			if child is Node3D:
				child.scale = Vector3(0.2, 0.2, 0.2)
				if not fast_mode:
					var tween := create_tween()
					tween.tween_property(child, "scale", Vector3.ONE, 0.7)
	if tyrant != null:
		if not fast_mode:
			var twitch := create_tween()
			twitch.tween_property(tyrant, "rotation", Vector3(0.0, 0.25, -0.18), 0.5)
			await twitch.finished
			await _wait(0.8)
		tyrant.visible = false
	if shadow_hands != null:
		if not fast_mode:
			await _wait(0.6)
		shadow_hands.visible = false


func _wait(seconds: float) -> void:
	if seconds <= 0.0:
		await get_tree().process_frame
	else:
		await get_tree().create_timer(seconds).timeout


func _set_ritual_visuals(active: bool) -> void:
	if ritual_light != null:
		ritual_light.visible = active
	if ritual_glow != null:
		ritual_glow.visible = active


func _lock_player(locked: bool) -> void:
	if not lock_player or player == null or not is_instance_valid(player):
		return
	if locked:
		_saved_input_enabled = player.input_enabled
		_saved_combat_enabled = player.combat_enabled
		player.input_enabled = false
		player.combat_enabled = false
	else:
		player.input_enabled = _saved_input_enabled
		player.combat_enabled = _saved_combat_enabled


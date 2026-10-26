extends Control
## S15: короткое пробуждение и финальная карточка Первого Кошмара.
##
## Это граница главы 16, а не начало следующего этапа. Имя Flaw не
## раскрывается; R сбрасывает прохождение и возвращает в пролог.

signal completed

const CAMPAIGN_ENTRY := "res://scenes/campaign/campaign_entry.tscn"
const AWAKENING_MESSAGES := preload("res://resources/spell/awakening_messages.tres")
const REQUIRED_FLAGS: Array[StringName] = [
	&"temple_reached",
	&"trial_completed",
	&"appraisal_completed",
]

@export var messages: SpellMessageCatalog
@export var restart_enabled := true
## В тестах переход можно отключить, чтобы проверить сброс без смены сцены.
@export var transition_enabled := true
@export var fast_mode := false
@export var fade_in := true
@export var line_delay := 1.4
## Прямой запуск финала не должен обходить оценку. В тестах редирект можно
## отключить, чтобы проверить, что карточка и финальный флаг не появляются.
@export var redirect_without_gate := true

@onready var _line: Label = %Line
@onready var _card: Control = %Card
@onready var _fade: FadeLayer = %Fade

var _ready_for_restart := false
var _completion_recorded := false
var _restarting := false


func _ready() -> void:
	if messages == null:
		messages = AWAKENING_MESSAGES
	_card.visible = false
	if not can_complete():
		_line.text = "Финальная сцена доступна только после оценки."
		if redirect_without_gate:
			get_tree().change_scene_to_file(CAMPAIGN_ENTRY)
		return
	_line.text = ""
	if fade_in:
		_fade.color.a = 1.0
		if not fast_mode:
			await _fade.fade_to(0.0, 1.2)
	else:
		_fade.color.a = 0.0
	var all_lines_played := await _show_lines()
	if not all_lines_played:
		return
	_complete_awakening()


## Возвращает true, только если все реплики доиграны внутри сцены.
## Ранний выход или удаление узла не должны фиксировать завершение Кошмара.
func _show_lines() -> bool:
	var valid: Array[SpellMessage] = messages.get_valid_messages() if messages else []
	for message in valid:
		if not is_inside_tree():
			return false
		_line.text = message.text
		if not fast_mode:
			await get_tree().create_timer(line_delay).timeout
		else:
			await get_tree().process_frame
	return is_inside_tree()


## Единственная точка фиксации финала. Повторный вызов идемпотентен.
func _complete_awakening() -> void:
	if _completion_recorded or not is_inside_tree():
		return
	_completion_recorded = true
	NightmareRunState.set_flag(&"awakening_completed")
	NightmareRunState.set_flag(&"first_nightmare_finished")
	# Финальный гейт выставляется последним и только после пробуждения.
	NightmareRunState.set_flag(&"first_nightmare_completed")
	_card.visible = true
	_ready_for_restart = true
	completed.emit()


func is_completed() -> bool:
	return _completion_recorded


func is_ready_for_restart() -> bool:
	return _ready_for_restart


func can_complete() -> bool:
	return NightmareRunState.require(REQUIRED_FLAGS)


func _restart() -> void:
	if _restarting:
		return
	_restarting = true
	NightmareRunState.reset()
	if transition_enabled:
		get_tree().change_scene_to_file(CAMPAIGN_ENTRY)


func _unhandled_input(event: InputEvent) -> void:
	if not _ready_for_restart or not restart_enabled or _restarting:
		return
	if event.is_action_pressed(&"restart"):
		get_viewport().set_input_as_handled()
		_restart()

extends Control
## S15: короткое пробуждение и финальная карточка Первого Кошмара.
##
## Это граница главы 16, а не начало следующего этапа. Имя Flaw не
## раскрывается; R сбрасывает прохождение и возвращает в пролог.

signal completed

const CAMPAIGN_ENTRY := "res://scenes/campaign/campaign_entry.tscn"
const POST_NIGHTMARE_SCENE := "res://scenes/locations/post_nightmare/police_precinct.tscn"
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
var beat_director: BeatDirector


func _ready() -> void:
	_ensure_beat_director()
	if messages == null:
		messages = AWAKENING_MESSAGES
	_card.visible = false
	if not can_complete():
		_line.text = "Финальная сцена доступна только после оценки."
		if redirect_without_gate:
			get_tree().change_scene_to_file(CAMPAIGN_ENTRY)
		return
	beat_director.transition_to_beat(&"N26")
	_audio_scene()
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
	# Пробуждение — первая точка, где способности Аспекта и Памяти становятся
	# доступны. Сами способности вне объёма; фиксируем состояние для будущих систем.
	NightmareRunState.set_flag(&"aspect_abilities_unlocked")
	NightmareRunState.set_flag(&"memory_abilities_unlocked")
	NightmareRunState.set_flag(&"shadow_core_awakened")
	NightmareRunState.set_flag(&"shadow_control_unlocked")
	# Финальный гейт выставляется последним и только после пробуждения.
	NightmareRunState.set_flag(&"first_nightmare_completed")
	_card.visible = true
	_ready_for_restart = true
	_build_continue_button()
	_play_ui(&"ui_skill_unlock")
	if beat_director != null and beat_director.current_beat != null:
		beat_director.beat_completed.emit(beat_director.current_beat)
	completed.emit()



func _build_continue_button() -> void:
	if not transition_enabled:
		return
	var text_box := _card.get_node_or_null(^"Text") as VBoxContainer
	if text_box == null or text_box.has_node(^"ContinueButton"):
		return
	var button := Button.new()
	button.name = "ContinueButton"
	button.text = "Продолжить: после Кошмара"
	button.custom_minimum_size = Vector2(320, 44)
	button.pressed.connect(_continue_post_nightmare)
	text_box.add_child(button)


func _continue_post_nightmare() -> void:
	if not transition_enabled:
		return
	NightmareRunState.set_flag(&"post_nightmare_started")
	NightmareRunState.set_current_beat(&"P05")
	get_tree().change_scene_to_file(POST_NIGHTMARE_SCENE)


func is_completed() -> bool:
	return _completion_recorded


func _ensure_beat_director() -> void:
	if beat_director != null:
		return
	beat_director = get_node_or_null("BeatDirector") as BeatDirector
	if beat_director == null:
		beat_director = BeatDirector.new()
		beat_director.name = "BeatDirector"
		add_child(beat_director)



func is_ready_for_restart() -> bool:
	return _ready_for_restart


func can_complete() -> bool:
	return NightmareRunState.require(REQUIRED_FLAGS)


func _restart() -> void:
	if _restarting:
		return
	_restarting = true
	_audio_stop(1.0)
	NightmareRunState.reset()
	if transition_enabled:
		get_tree().change_scene_to_file(CAMPAIGN_ENTRY)


func _audio_scene() -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	if director == null:
		return
	if director.has_method(&"play_music"):
		director.call(&"play_music", &"finale", 3.0)
	if director.has_method(&"play_ambience"):
		director.call(&"play_ambience", &"void", 3.0)
	if director.has_method(&"set_reverb_profile"):
		director.call(&"set_reverb_profile", &"sanctuary")


func _play_ui(cue_id: StringName) -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	if director != null and director.has_method(&"play_ui"):
		director.call(&"play_ui", cue_id)


func _audio_stop(fade: float) -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	if director == null:
		return
	if director.has_method(&"stop_music"):
		director.call(&"stop_music", fade)
	if director.has_method(&"stop_ambience"):
		director.call(&"stop_ambience", fade)
	if director.has_method(&"set_reverb_profile"):
		director.call(&"set_reverb_profile", &"outdoor")


func _unhandled_input(event: InputEvent) -> void:
	if not _ready_for_restart or not restart_enabled or _restarting:
		return
	if event.is_action_pressed(&"restart"):
		get_viewport().set_input_as_handled()
		_restart()

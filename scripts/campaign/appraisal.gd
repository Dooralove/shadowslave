extends Control
## S14: звёздная оценка после смерти Тирана.
##
## Никакой физической геометрии, боя или выбора награды. Строки идут по
## каноническому порядку; True Name и Divine Aspect выдаются здесь, а не
## в святилище. В конце — переход к пробуждению.

signal finished

const FINALE_SCENE := "res://scenes/campaign/finale_arrival.tscn"
const CAMPAIGN_ENTRY := "res://scenes/campaign/campaign_entry.tscn"
const APPRAISAL_MESSAGES := preload("res://resources/spell/appraisal_messages.tres")
const REQUIRED_FLAGS: Array[StringName] = [&"temple_reached", &"trial_completed"]
## Деяние «три дремлющих человека» (CANON-INFERRED, docs/research/first_nightmare/03_ascent_and_climax_canon.md, 5.3).
const DORMANT_HUMANS_REQUIRED := 3

@export var messages: SpellMessageCatalog
@export var transition_enabled := true
@export var fast_mode := false
@export var start_delay := 0.8
@export var end_delay := 2.0
@export var fade_in := true
## Прямой запуск сцены не должен выдавать оценку без завершённого испытания.
## В тестах можно отключить редирект, чтобы проверить закрытый гейт.
@export var redirect_without_gate := true

@onready var _message: RichTextLabel = %Message
@onready var _counter: Label = %Counter
@onready var _hint: Label = %Hint
@onready var _fade: FadeLayer = %Fade

var _completed := false
var _skip_line := false
var beat_director: BeatDirector


func _ready() -> void:
	_ensure_beat_director()
	if messages == null:
		messages = APPRAISAL_MESSAGES
	if not can_appraise():
		_message.text = ""
		_hint.visible = true
		if NightmareRunState.require(REQUIRED_FLAGS):
			_hint.text = "Оценка закрыта: деяния испытания ещё не совершены."
		else:
			_hint.text = "Оценка доступна только после завершения испытания."
		if redirect_without_gate:
			get_tree().change_scene_to_file(CAMPAIGN_ENTRY)
		return
	beat_director.transition_to_beat(&"N25")
	_audio_scene()
	NightmareRunState.set_flag(&"appraisal_started")

	_hint.visible = false
	_message.text = ""
	if fade_in:
		_fade.color.a = 1.0
		await _wait(0.0)
		if not fast_mode:
			await _fade.fade_to(0.0, 1.2)
	else:
		_fade.color.a = 0.0
	await _wait(start_delay)
	await _run()


func is_completed() -> bool:
	return _completed


func _ensure_beat_director() -> void:
	if beat_director != null:
		return
	beat_director = get_node_or_null("BeatDirector") as BeatDirector
	if beat_director == null:
		beat_director = BeatDirector.new()
		beat_director.name = "BeatDirector"
		add_child(beat_director)


func can_appraise() -> bool:

	return NightmareRunState.require(REQUIRED_FLAGS) and defeated_dormant_humans() >= DORMANT_HUMANS_REQUIRED


## Считает трёх «дремлющих людей» по игровым событиям, а не по константе.
## Ветеран засчитывается казнью. Шифти и Учёный засчитываются только если есть
## и отравление общих фляг (причина по канону), и собственное событие: падение
## Шифти (shifty_dead) или оставление Учёного приманкой (scholar_abandoned).
## Сам яд смертью не считается.
func defeated_dormant_humans() -> int:
	var count := 0
	if NightmareRunState.has_flag(&"veteran_dead"):
		count += 1
	if NightmareRunState.has_flag(&"flasks_poisoned"):
		if NightmareRunState.has_flag(&"shifty_dead"):
			count += 1
		if NightmareRunState.has_flag(&"scholar_abandoned"):
			count += 1
	return count


## D14: личинки — отдельные деяния сверх трёх дремлющих людей. Первая
## личинка на стоянке (larva_killed) и личинка из тела Шифти
## (shifty_larva_killed) считаются обе. Вторая личинка на стоянке
## (second_larva_killed) сюда не входит: её добивает Герой.
func defeated_larva() -> int:
	var count := 0
	if NightmareRunState.has_flag(&"larva_killed"):
		count += 1
	if NightmareRunState.has_flag(&"shifty_larva_killed"):
		count += 1
	return count


func defeated_creatures() -> int:
	return defeated_dormant_humans() + defeated_larva()


func _run() -> void:
	var valid: Array[SpellMessage] = messages.get_valid_messages() if messages else []
	if defeated_larva() <= 0:
		valid = valid.filter(func(message: SpellMessage) -> bool:
			return message.id != &"appraisal_deed_larva"
		)
	for index in valid.size():
		_skip_line = false
		var message := valid[index]
		_counter.text = "%d / %d" % [index + 1, valid.size()]
		_message.modulate.a = 0.0
		_message.text = message.text
		if not fast_mode:
			var tween := create_tween()
			tween.tween_property(_message, "modulate:a", 1.0, 0.28)
			await tween.finished
		else:
			_message.modulate.a = 1.0
		await _wait(message.duration)
		if not fast_mode:
			await get_tree().create_timer(0.1).timeout

	NightmareRunState.set_flag(&"appraisal_completed")
	NightmareRunState.set_flag(&"final_appraisal_glorious")
	NightmareRunState.set_flag(&"true_name_lost_from_light")
	NightmareRunState.set_flag(&"aspect_shadow_slave")
	NightmareRunState.set_flag(&"shadow_bond_known")
	NightmareRunState.set_flag(&"first_seal_broken")
	NightmareRunState.set_item(&"puppeteer_shroud")
	_play_ui(&"ui_skill_unlock")
	_audio_stop(2.0)
	_hint.visible = true
	_hint.text = "Оценка завершена. Enter / Space — пробуждение."
	await _wait(end_delay)
	_completed = true
	if beat_director != null and beat_director.current_beat != null:
		beat_director.beat_completed.emit(beat_director.current_beat)
	finished.emit()

	if not transition_enabled:
		return
	if not fast_mode:
		await _fade.fade_to(1.0, 1.2)
	get_tree().change_scene_to_file(FINALE_SCENE)


func _audio_scene() -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	if director == null:
		return
	if director.has_method(&"play_music"):
		director.call(&"play_music", &"appraisal", 2.0)
	if director.has_method(&"play_ambience"):
		director.call(&"play_ambience", &"sanctuary", 2.0)
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


func _wait(seconds: float) -> void:
	if fast_mode or seconds <= 0.0 or _skip_line:
		await get_tree().process_frame
		return
	await get_tree().create_timer(seconds).timeout


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		_skip_line = true
		get_viewport().set_input_as_handled()

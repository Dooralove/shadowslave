class_name DialogueRunner
extends Node
## Показывает реплики последовательности через субтитры и ждёт «далее» или таймера.

signal line_started(line: DialogueLine, index: int, count: int)
signal finished
signal _advanced

@export var subtitles: SubtitleUI
@export var speaker_names := {
	&"sunny": "Санни",
	&"desk_officer": "Дежурный",
	&"policeman": "Седой полицейский",
	&"narration": "",
	&"slave": "Раб",
	&"commander": "Командир",
	&"shifty": "Шифти",
	&"scholar": "Учёный",
	&"broad_slave": "Широкоплечий раб",
	&"hero": "Герой",
	&"veteran": "Ветеран",
	&"nephis": "Нефис",
	&"cassia": "Кассия",
	&"echo": "Эхо",
	&"jett": "Джет",
	&"jet": "Джет",
	&"rock": "Рок",
	&"kasper": "Каспер",
	&"casper": "Каспер",
	&"theo": "Тео",
	&"julius": "Джулиус",
	&"medic": "Медик",
	&"technician": "Медик",
	&"lissa_echo": "Эхо Лиссы",
	&"guard": "Охрана",
	&"administrator": "Администратор",
	&"cadet_mira": "Мира",
	&"cadet_ren": "Рен",
	&"sergeant_holt": "Сержант Хольт",
	&"wall_guard": "Стражник",
	&"sleeper_receptionist": "Регистратор",
	&"gate_guard": "Охрана ворот",
	&"spell": "Заклятие",
}
## Реплики с таймером проходят мгновенно (для тестов).
var fast_mode := false
var running := false
## Кадр, в котором показана текущая реплика: то же нажатие, что открыло диалог, не должно его пролистнуть.
var _line_frame := -1
var _cancelled := false


func _ready() -> void:
	add_to_group(&"dialogue_runner")
	bind_subtitles()


## Привязка субтитров после инстанцирования сцены (GameplayHud делает это
## отложенно). Повторная привязка безопасна.
func bind_subtitles() -> void:
	if subtitles == null:
		return
	if not subtitles.advance_requested.is_connected(advance):
		subtitles.advance_requested.connect(advance)


func run(sequence: DialogueSequence) -> void:
	_cancelled = false
	running = true
	bind_subtitles()
	if sequence == null or sequence.lines.is_empty():
		if subtitles:
			subtitles.hide_line()
		running = false
		finished.emit()
		return
	var count := sequence.lines.size()
	for i in count:
		var line := sequence.lines[i] as DialogueLine
		var waits_for_input := line.duration <= 0.0
		if subtitles:
			subtitles.show_line(display_name(line.speaker), line.text, waits_for_input, i, count)
		_line_frame = Engine.get_process_frames()
		_start_voice(line, i, sequence)
		line_started.emit(line, i, count)
		if waits_for_input:
			await _advanced
		elif not fast_mode:
			await get_tree().create_timer(line.duration).timeout
		if _cancelled:
			_stop_voice()
			if subtitles:
				subtitles.hide_line()
			running = false
			return
		_stop_voice()
	if subtitles:
		subtitles.hide_line()
	_stop_voice()
	running = false
	finished.emit()


## Немедленно завершает показ. Будит ожидание ввода; таймерная реплика
## вернётся после таймера, но новых реплик уже не покажет.
func cancel() -> void:
	if not running:
		return
	_cancelled = true
	_stop_voice()
	if subtitles:
		subtitles.hide_line()
	running = false
	_advanced.emit()


func advance() -> void:
	if running:
		_stop_voice()
		_advanced.emit()


func _start_voice(line: DialogueLine, index: int, sequence: DialogueSequence) -> void:
	if fast_mode or line == null:
		return
	var director := get_node_or_null(^"/root/AudioDirector")
	if director == null or not director.has_method(&"play_voice"):
		return
	var voice_id: StringName = line.voice_id
	if voice_id == &"":
		var base := sequence.resource_path.get_file().get_basename()
		if base.is_empty():
			return
		voice_id = StringName("%s_%03d" % [base, index])
	director.call(&"play_voice", voice_id)


func _stop_voice() -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	if director == null:
		return
	var voice_node: Node = director.get("voice") as Node
	if voice_node != null and voice_node.has_method(&"stop"):
		voice_node.call(&"stop")


func display_name(speaker: StringName) -> String:
	return speaker_names.get(speaker, String(speaker))


func _unhandled_input(event: InputEvent) -> void:
	if running and event.is_action_pressed(&"advance_dialogue") and Engine.get_process_frames() != _line_frame:
		get_viewport().set_input_as_handled()
		advance()

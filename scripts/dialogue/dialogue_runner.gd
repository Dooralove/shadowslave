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
}
## Реплики с таймером проходят мгновенно (для тестов).
var fast_mode := false
var running := false
## Кадр, в котором показана текущая реплика: то же нажатие, что открыло диалог, не должно его пролистнуть.
var _line_frame := -1


func run(sequence: DialogueSequence) -> void:
	running = true
	var count := sequence.lines.size()
	for i in count:
		var line := sequence.lines[i] as DialogueLine
		var waits_for_input := line.duration <= 0.0
		if subtitles:
			subtitles.show_line(display_name(line.speaker), line.text, waits_for_input)
		_line_frame = Engine.get_process_frames()
		line_started.emit(line, i, count)
		if waits_for_input:
			await _advanced
		elif not fast_mode:
			await get_tree().create_timer(line.duration).timeout
	if subtitles:
		subtitles.hide_line()
	running = false
	finished.emit()


func advance() -> void:
	if running:
		_advanced.emit()


func display_name(speaker: StringName) -> String:
	return speaker_names.get(speaker, String(speaker))


func _unhandled_input(event: InputEvent) -> void:
	if running and event.is_action_pressed(&"advance_dialogue") and Engine.get_process_frames() != _line_frame:
		get_viewport().set_input_as_handled()
		advance()

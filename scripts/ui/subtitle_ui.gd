class_name SubtitleUI
extends PanelContainer
## Субтитры: имя говорящего, реплика и подсказка «далее», если реплика ждёт
## нажатия. Панель занимает нижнюю треть, не перекрывает центр и не ловит
## клики мимо себя. Клик по панели работает как «далее».

signal advance_requested

@onready var speaker_label: Label = %SpeakerLabel
@onready var text_label: Label = %TextLabel
@onready var continue_hint: Label = %ContinueHint

var _line_index := 0
var _line_count := 0


func _ready() -> void:
	if theme == null:
		theme = RpgMenuTheme.build()
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	gui_input.connect(_on_gui_input)


func show_line(speaker: String, text: String, waits_for_input: bool, index := 0, count := 0) -> void:
	_line_index = index
	_line_count = count
	speaker_label.text = speaker.to_upper()
	speaker_label.visible = not speaker.is_empty()
	text_label.text = text
	continue_hint.visible = waits_for_input or count > 1
	if waits_for_input:
		continue_hint.text = _hint_text("E / Space / Enter — далее")
	elif count > 1:
		continue_hint.text = _hint_text("")
	visible = true


func hide_line() -> void:
	visible = false


func _hint_text(prefix: String) -> String:
	var counter := ""
	if _line_count > 1:
		counter = "%d / %d" % [_line_index + 1, _line_count]
	if prefix.is_empty():
		return counter
	if counter.is_empty():
		return prefix
	return "%s   ·   %s" % [prefix, counter]


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			advance_requested.emit()
			accept_event()

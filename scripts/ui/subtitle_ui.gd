class_name SubtitleUI
extends PanelContainer
## Субтитры: имя говорящего, реплика и подсказка «далее», если реплика ждёт нажатия.

@onready var speaker_label: Label = %SpeakerLabel
@onready var text_label: Label = %TextLabel
@onready var continue_hint: Label = %ContinueHint


func _ready() -> void:
	visible = false


func show_line(speaker: String, text: String, waits_for_input: bool) -> void:
	speaker_label.text = speaker
	speaker_label.visible = not speaker.is_empty()
	text_label.text = text
	continue_hint.visible = waits_for_input
	visible = true


func hide_line() -> void:
	visible = false

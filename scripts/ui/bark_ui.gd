class_name BarkUI
extends CanvasLayer
## Неблокирующий слой коротких внутренних реплик Санни.
##
## Слушает сигнал DialogueManager и показывает текст через существующий SubtitleUI,
## но в отдельной панели: реплики не смешиваются с сюжетными субтитрами и
## сообщениями Заклятия. Панель исчезает сама и не перехватывает ввод.

const SPEAKER_NAMES := {
	&"sunny": "Санни",
}

@onready var subtitles: SubtitleUI = %BarkSubtitles

@export var default_duration := 4.0
@export var fade_out_time := 0.25

var _display_id := 0
var _tween: Tween


func _ready() -> void:
	visible = false
	DialogueManager.bark_requested.connect(_on_bark_requested)
	DialogueManager.bark_cleared.connect(hide_bark)


func _on_bark_requested(bark: BarkLine) -> void:
	present(bark)


## Показывает реплику. duration <= 0 означает default_duration.
func present(bark: BarkLine, duration := -1.0) -> void:
	if bark == null or bark.text.strip_edges().is_empty():
		return

	_display_id += 1
	var display_id := _display_id
	if _tween != null and _tween.is_valid():
		_tween.kill()

	visible = true
	subtitles.modulate.a = 1.0
	subtitles.show_line(display_name(bark.speaker), bark.text, false)

	var hold := default_duration if duration <= 0.0 else duration
	_tween = create_tween()
	_tween.tween_interval(hold)
	_tween.tween_property(subtitles, "modulate:a", 0.0, fade_out_time)
	_tween.tween_callback(_finish.bind(display_id))


func hide_bark() -> void:
	_display_id += 1
	if _tween != null and _tween.is_valid():
		_tween.kill()
	subtitles.hide_line()
	subtitles.modulate.a = 1.0
	visible = false


func display_name(speaker: StringName) -> String:
	return SPEAKER_NAMES.get(speaker, String(speaker))


func _finish(display_id: int) -> void:
	if display_id != _display_id:
		return
	subtitles.hide_line()
	subtitles.modulate.a = 1.0
	visible = false

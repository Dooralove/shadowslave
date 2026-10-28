class_name SpellMessageUI
extends Label
## Голос Заклятия в темноте — текст поверх шторки.
##
## Совместимый слой для старых оболочек: новые сцены используют SpellOverlay,
## но пролог и S03 по-прежнему показывают Заклятие этой надписью.

signal queue_finished

var _presentation_id := 0


func _ready() -> void:
	visible = false


func present(message: String, duration: float) -> void:
	await _present(message, duration)


## Совместимость со SpellOverlay.show_message(): принимает SpellMessage.
func show_message(message: SpellMessage) -> void:
	if message == null:
		return
	await _present(message.text, message.duration)


## Совместимость со SpellOverlay.show_text(): текст без ресурса.
func show_text(message: String, duration: float) -> void:
	await _present(message, duration)


func _present(message: String, duration: float) -> void:
	_presentation_id += 1
	var token := _presentation_id
	text = message
	modulate.a = 1.0
	visible = true
	if duration > 0.0:
		await get_tree().create_timer(duration).timeout
	if token != _presentation_id:
		return
	visible = false
	queue_finished.emit()

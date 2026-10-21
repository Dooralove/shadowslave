class_name SpellMessageUI
extends Label
## Голос Заклинания в темноте — текст поверх шторки.


func _ready() -> void:
	visible = false


func present(message: String, duration: float) -> void:
	text = message
	modulate.a = 1.0
	visible = true
	if duration > 0.0:
		await get_tree().create_timer(duration).timeout
	visible = false

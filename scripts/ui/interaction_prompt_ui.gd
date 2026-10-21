class_name InteractionPromptUI
extends Label
## Подсказка взаимодействия под прицелом камеры: «E — Отпить».


func _ready() -> void:
	visible = false


func show_for(target: Interactable) -> void:
	if target == null:
		visible = false
		return
	text = "E — %s" % target.prompt
	visible = true

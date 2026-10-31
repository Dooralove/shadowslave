class_name SanctuaryUI
extends CanvasLayer
## HUD святилища: подсказка взаимодействия и статус ритуала.
## Не хранит сюжетные тексты — их присылают контроллер и AltarRitual.

@export var interactor: Interactor
@export var prompt: InteractionPromptUI
@export var status_label: Label


func _ready() -> void:
	if status_label != null:
		status_label.text = ""
		status_label.visible = false
	if interactor != null and prompt != null:
		interactor.focus_changed.connect(prompt.show_for)


## Показывает короткий статус над сценой. Пустая строка скрывает его.
func show_status(text: String) -> void:
	if status_label == null:
		return
	status_label.text = text
	status_label.visible = not text.is_empty()

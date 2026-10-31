extends Node3D
## Тестовая локация: связывает существующий Interactor с подсказкой и пробным действием алтаря.
## Здесь же видно, как будущие механики подписываются на Interactable.interacted.

@onready var interactor: Interactor = $Sunny/Interactor
@onready var prompt: InteractionPromptUI = $HUD/Prompt
@onready var altar: Interactable = $Geometry/Altar/Interaction
@onready var altar_light: OmniLight3D = $AltarLight


func _ready() -> void:
	interactor.focus_changed.connect(prompt.show_for)
	altar.interacted.connect(_on_altar_interacted)


func _on_altar_interacted(id: StringName) -> void:
	if id == &"altar":
		altar_light.visible = not altar_light.visible

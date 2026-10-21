class_name Interactable
extends Node3D
## Точка взаимодействия. Логика живёт здесь, а не в меше рядом, поэтому временную модель
## можно заменить реалистичной, не трогая id и подписки сценария.

signal interacted(id: StringName)

@export var interaction_id: StringName
## Текст подсказки, например «Отпить».
@export var prompt := "Взаимодействовать"
## На каком горизонтальном расстоянии игрок может взаимодействовать, м.
@export var radius := 1.5
## Включает и выключает сценарий; по умолчанию выключено, чтобы ничего не сработало раньше времени.
@export var enabled := false


func _ready() -> void:
	add_to_group(&"interactable")


func can_interact_from(point: Vector3) -> bool:
	if not enabled:
		return false
	var offset := global_position - point
	offset.y = 0.0
	return offset.length() <= radius


func interact() -> void:
	if enabled:
		interacted.emit(interaction_id)

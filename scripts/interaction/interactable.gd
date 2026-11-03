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
## Звук взаимодействия. Мировые объекты не должны щёлкать UI-звуком.
@export var interact_cue: StringName = &"world_pickup"
@export var interact_volume_db := -4.0
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
	if not enabled:
		return
	var director := get_node_or_null(^"/root/AudioDirector")
	if director != null:
		if String(interact_cue).begins_with("ui_") and director.has_method(&"play_ui"):
			director.call(&"play_ui", interact_cue, interact_volume_db)
		elif director.has_method(&"play_sfx"):
			director.call(&"play_sfx", interact_cue, global_position, interact_volume_db)
	interacted.emit(interaction_id)

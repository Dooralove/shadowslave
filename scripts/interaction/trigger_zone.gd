class_name TriggerZone
extends Area3D
## Зона, которая один раз сообщает сценарию, что игрок в неё вошёл.

signal triggered(id: StringName)

@export var trigger_id: StringName
@export var enabled := false


func _ready() -> void:
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		fire()


func fire() -> void:
	if not enabled:
		return
	enabled = false
	triggered.emit(trigger_id)

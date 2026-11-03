class_name QuestTideWait
extends Interactable
## «Переждать прилив»: вызывает публичный advance_to_low/high существующего
## TideController. Не создаёт второй таймер, не лечит и не сохраняет игру.

enum Target {
	LOW,
	HIGH,
}

@export var tide_controller: Node3D
@export var target: Target = Target.LOW
@export var success_message := "Вода отступила."
@export var high_message := "Прилив поднялся."
@export var unavailable_message := "Сейчас нечего ждать."

var _busy := false


func _ready() -> void:
	super._ready()
	add_to_group(&"quest_tide_wait")
	if tide_controller == null:
		tide_controller = get_tree().get_first_node_in_group(&"tide_controller") as Node3D


func can_interact_from(point: Vector3) -> bool:
	return super.can_interact_from(point) and tide_controller != null and is_instance_valid(tide_controller)


func interact() -> void:
	if not enabled or _busy:
		return
	if tide_controller == null or not is_instance_valid(tide_controller):
		return
	var method := &"advance_to_low" if target == Target.LOW else &"advance_to_high"
	if not tide_controller.has_method(method):
		QuestSystem.show_message(unavailable_message, &"warning")
		return
	_busy = true
	var changed: Variant = tide_controller.call(method)
	_busy = false
	if changed is bool and not bool(changed):
		QuestSystem.show_message(unavailable_message, &"warning")
		return
	QuestSystem.show_message(success_message if target == Target.LOW else high_message, &"info")

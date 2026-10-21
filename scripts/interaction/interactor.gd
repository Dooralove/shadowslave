class_name Interactor
extends Node3D
## Выбирает ближайший доступный Interactable рядом с владельцем и вызывает его по действию `interact`.

signal focus_changed(target: Interactable)

var enabled := true
var focused: Interactable


func _physics_process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	var best: Interactable = null
	var best_distance := INF
	if enabled:
		for node in get_tree().get_nodes_in_group(&"interactable"):
			var candidate := node as Interactable
			if candidate == null or not candidate.can_interact_from(global_position):
				continue
			var distance := global_position.distance_to(candidate.global_position)
			if distance < best_distance:
				best = candidate
				best_distance = distance
	if best != focused:
		focused = best
		focus_changed.emit(focused)


func _unhandled_input(event: InputEvent) -> void:
	if enabled and focused and event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		focused.interact()

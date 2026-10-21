extends GutTest
## Точки взаимодействия, их выбор игроком и зоны-триггеры.

var root: Node3D


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)


func _interactable(id: StringName, position: Vector3, on := true) -> Interactable:
	var interactable := Interactable.new()
	interactable.interaction_id = id
	interactable.radius = 1.5
	interactable.enabled = on
	root.add_child(interactable)
	interactable.global_position = position
	return interactable


func _interactor() -> Interactor:
	var interactor := Interactor.new()
	root.add_child(interactor)
	return interactor


func test_disabled_by_default() -> void:
	assert_false(autofree(Interactable.new()).enabled, "сценарий включает точку сам")
	assert_false(autofree(TriggerZone.new()).enabled)


func test_range_is_horizontal() -> void:
	var interactable := _interactable(&"cup", Vector3(1, 0, 0))
	assert_true(interactable.can_interact_from(Vector3(0, 1.5, 0)), "высота не важна")
	assert_false(interactable.can_interact_from(Vector3(-1, 0, 0)), "дальше радиуса")
	interactable.enabled = false
	assert_false(interactable.can_interact_from(Vector3.ZERO))


func test_interact_emits_only_when_enabled() -> void:
	var interactable := _interactable(&"cup", Vector3.ZERO, false)
	watch_signals(interactable)
	interactable.interact()
	assert_signal_not_emitted(interactable, "interacted")
	interactable.enabled = true
	interactable.interact()
	assert_signal_emitted_with_parameters(interactable, "interacted", [&"cup"])


func test_interactor_focuses_nearest_enabled() -> void:
	var near := _interactable(&"near", Vector3(0.5, 0, 0))
	var far := _interactable(&"far", Vector3(1.2, 0, 0))
	var interactor := _interactor()
	interactor.refresh()
	assert_eq(interactor.focused, near)
	near.enabled = false
	interactor.refresh()
	assert_eq(interactor.focused, far)
	far.enabled = false
	interactor.refresh()
	assert_null(interactor.focused)


func test_disabled_interactor_focuses_nothing() -> void:
	_interactable(&"cup", Vector3(0.5, 0, 0))
	var interactor := _interactor()
	interactor.enabled = false
	interactor.refresh()
	assert_null(interactor.focused)


func test_interact_action_triggers_focused() -> void:
	var interactable := _interactable(&"cup", Vector3(0.5, 0, 0))
	var interactor := _interactor()
	interactor.refresh()
	watch_signals(interactable)
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	interactor._unhandled_input(event)
	assert_signal_emitted_with_parameters(interactable, "interacted", [&"cup"])


func test_trigger_fires_once_and_only_for_player() -> void:
	var zone := TriggerZone.new()
	zone.trigger_id = &"door"
	root.add_child(zone)
	watch_signals(zone)
	zone.fire()
	assert_signal_not_emitted(zone, "triggered", "выключенная зона молчит")
	zone.enabled = true
	var stranger := Node3D.new()
	root.add_child(stranger)
	zone._on_body_entered(stranger)
	assert_signal_not_emitted(zone, "triggered", "реагирует только на игрока")
	var player := Node3D.new()
	player.add_to_group(&"player")
	root.add_child(player)
	zone._on_body_entered(player)
	zone._on_body_entered(player)
	assert_signal_emit_count(zone, "triggered", 1)
	assert_false(zone.enabled)

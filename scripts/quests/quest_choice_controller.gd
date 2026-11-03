class_name QuestChoiceController
extends Node
## Backend выбора для SQ-03. Не является вторым dialogue engine и не
## содержит UI: A08 показывает варианты и присылает choice_id, а controller
## валидирует выбор, пишет canonical flag и отправляет quest event.

signal presentation_requested(prompt: String, choices: Array[Dictionary])
signal choice_selected(choice_id: StringName)
signal closed

@export var panel: Node

var _active := false
var _prompt := ""
var _choices: Dictionary = {}
var _panel_connected := false


func _ready() -> void:
	_bind_panel()
	var run_state := get_node_or_null(^"/root/NightmareRunState")
	if run_state != null and not run_state.state_reset.is_connected(_on_state_reset):
		run_state.state_reset.connect(_on_state_reset)


func set_panel(value: Node) -> void:
	if panel == value:
		return
	_disconnect_panel()
	panel = value
	_bind_panel()


func present(prompt: String, choices: Array[Dictionary]) -> bool:
	if _active:
		return false
	_choices.clear()
	for entry in choices:
		var choice: Dictionary = entry.duplicate(true)
		var choice_id := StringName(choice.get("id", &""))
		var text := String(choice.get("text", "")).strip_edges()
		if choice_id == &"" or text.is_empty():
			push_warning("QuestChoiceController: пропущен вариант без id/text")
			continue
		choice["id"] = choice_id
		choice["text"] = text
		choice["enabled"] = bool(choice.get("enabled", true))
		_choices[choice_id] = choice
	if _choices.is_empty():
		push_warning("QuestChoiceController: нет валидных вариантов")
		return false
	_prompt = prompt
	_active = true
	_bind_panel()
	if panel != null and panel.has_method(&"present"):
		panel.call(&"present", _prompt, get_choices())
	elif panel != null and panel.has_method(&"show_choices"):
		panel.call(&"show_choices", _prompt, get_choices())
	presentation_requested.emit(_prompt, get_choices())
	return true


func select(choice_id: StringName) -> bool:
	if not _active:
		return false
	var key := StringName(choice_id)
	if not _choices.has(key):
		return false
	var choice: Dictionary = _choices[key]
	if not bool(choice.get("enabled", true)):
		return false
	_active = false
	var flag_name := StringName(choice.get("flag", &""))
	if flag_name != &"":
		NightmareRunState.set_flag(flag_name)
	var quest_event := StringName(choice.get("quest_event", &""))
	var quest_subject := StringName(choice.get("quest_subject", &""))
	if quest_event != &"" and quest_subject != &"":
		QuestSystem.notify_event(quest_event, quest_subject, 1)
	choice_selected.emit(key)
	close()
	return true


func close() -> void:
	if not _active and _choices.is_empty():
		return
	_active = false
	_choices.clear()
	_prompt = ""
	if panel != null and panel.has_method(&"close"):
		panel.call(&"close")
	closed.emit()


func is_active() -> bool:
	return _active


func get_choices() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in _choices:
		result.append((_choices[key] as Dictionary).duplicate(true))
	return result


func _bind_panel() -> void:
	if panel == null:
		var found := get_tree().get_first_node_in_group(&"quest_choice_panel")
		if found != null:
			panel = found
	if panel == null:
		return
	if panel.has_signal(&"choice_selected") and not _panel_connected:
		var callable := Callable(self, &"_on_panel_choice_selected")
		if not panel.is_connected(&"choice_selected", callable):
			panel.connect(&"choice_selected", callable)
		_panel_connected = true


func _disconnect_panel() -> void:
	if panel == null or not _panel_connected:
		return
	var callable := Callable(self, &"_on_panel_choice_selected")
	if panel.has_signal(&"choice_selected") and panel.is_connected(&"choice_selected", callable):
		panel.disconnect(&"choice_selected", callable)
	_panel_connected = false


func _on_panel_choice_selected(choice_id: StringName) -> void:
	select(choice_id)


func _on_state_reset() -> void:
	if _active:
		close()

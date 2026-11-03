extends GutTest
## Строка переназначения: захват клавиши, отмена, очистка и сброс.

const TEST_PATH := "user://test_input_binding_row.cfg"

var _settings: GameSettings
var _row: InputBindingRow
var _messages: Array[String] = []


func before_each() -> void:
	_delete_test_file()
	_settings = GameSettings.new(TEST_PATH)
	_row = InputBindingRow.new()
	add_child_autofree(_row)
	_row.setup(_settings, &"move_forward")
	_row.binding_changed.connect(_on_binding_changed)
	_messages.clear()
	await wait_process_frames(1)


func after_each() -> void:
	_delete_test_file()
	_settings.reset_all_bindings()


func _delete_test_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func _on_binding_changed(_action: StringName, message: String) -> void:
	_messages.append(message)


func _start_listening() -> void:
	_row._suppress_press_until_ms = 0
	_row.call(&"_start_listening")


func _press(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


func _bind_button() -> Button:
	return _row.find_child("BindButton", true, false) as Button


func _action_has_key(action: StringName, code: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			if key.physical_keycode == code or key.keycode == code:
				return true
	return false


func test_row_starts_with_current_binding() -> void:
	assert_eq(_row.action, &"move_forward")
	assert_string_contains(_bind_button().text, "W", "показывает клавишу из InputMap")
	assert_string_contains(_bind_button().text, "Стик", "показывает и дефолтную ось геймпада")


func test_press_key_rebinds_and_saves() -> void:
	_start_listening()
	assert_eq(_bind_button().text, InputBindingRow.LISTENING_TEXT)
	_row._input(_press(KEY_T))
	await wait_process_frames(1)
	assert_true(_action_has_key(&"move_forward", KEY_T), "клавиша применена к InputMap")
	assert_false(_action_has_key(&"move_forward", KEY_W), "старая клавиша заменена")
	assert_eq(_bind_button().text, "T")
	assert_true(FileAccess.file_exists(TEST_PATH), "привязка сохранена")
	assert_gt(_messages.size(), 0, "родитель получает сообщение")


func test_escape_cancels_listening() -> void:
	_start_listening()
	_row._input(_press(KEY_ESCAPE))
	assert_true(_action_has_key(&"move_forward", KEY_W), "Esc не меняет привязку")
	assert_string_contains(_bind_button().text, "W")
	assert_eq(_messages.size(), 0, "отмена не создаёт сообщение")


func test_backspace_clears_binding() -> void:
	_start_listening()
	_row._input(_press(KEY_BACKSPACE))
	assert_eq(InputMap.action_get_events(&"move_forward").size(), 0, "Backspace очищает действие")
	assert_eq(_bind_button().text, "—")
	assert_string_contains(_messages[0], "очищена")


func test_conflict_is_reported() -> void:
	_start_listening()
	_row._input(_press(KEY_S))
	await wait_process_frames(1)
	assert_true(_action_has_key(&"move_forward", KEY_S))
	assert_true(_action_has_key(&"move_back", KEY_S), "конфликтующая привязка сохраняется")
	assert_string_contains(_messages[0], "используется")


func test_reset_returns_project_default() -> void:
	_settings.assign_action_event(&"move_forward", _key_event(KEY_T))
	_row.refresh()
	_row.call(&"_reset_binding")
	assert_true(_action_has_key(&"move_forward", KEY_W), "сброс возвращает W")
	assert_false(_settings.has_custom_bindings())


func _key_event(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event

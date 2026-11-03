extends GutTest
## Настройки стартового меню: значения по умолчанию, сохранение, загрузка,
## очистка некорректных значений и создание звуковых шин.

const TEST_PATH := "user://test_game_settings.cfg"

var _settings: GameSettings
var _previous_max_fps := 0
var _previous_scale := 1.0
var _previous_master_db := 0.0
var _previous_master_mute := false


func before_each() -> void:
	_delete_test_file()
	_settings = GameSettings.new(TEST_PATH)
	_previous_max_fps = Engine.max_fps
	_previous_scale = get_tree().root.scaling_3d_scale
	var master := AudioServer.get_bus_index(&"Master")
	_previous_master_db = AudioServer.get_bus_volume_db(master)
	_previous_master_mute = AudioServer.is_bus_mute(master)


func after_each() -> void:
	_delete_test_file()
	Engine.max_fps = _previous_max_fps
	get_tree().root.scaling_3d_scale = _previous_scale
	var master := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_volume_db(master, _previous_master_db)
	AudioServer.set_bus_mute(master, _previous_master_mute)
	_settings.reset_all_bindings()


func _delete_test_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func test_defaults_match_constants() -> void:
	assert_almost_eq(_settings.master_volume, GameSettings.DEFAULT_MASTER_VOLUME, 0.001)
	assert_almost_eq(_settings.music_volume, GameSettings.DEFAULT_MUSIC_VOLUME, 0.001)
	assert_almost_eq(_settings.sfx_volume, GameSettings.DEFAULT_SFX_VOLUME, 0.001)
	assert_eq(_settings.fullscreen, GameSettings.DEFAULT_FULLSCREEN)
	assert_eq(_settings.resolution, GameSettings.DEFAULT_RESOLUTION)
	assert_eq(_settings.vsync_enabled, GameSettings.DEFAULT_VSYNC)
	assert_eq(_settings.max_fps, GameSettings.DEFAULT_MAX_FPS)
	assert_almost_eq(_settings.render_scale, GameSettings.DEFAULT_RENDER_SCALE, 0.001)


func test_save_and_load_roundtrip() -> void:
	_settings.master_volume = 0.35
	_settings.music_volume = 0.45
	_settings.ambience_volume = 0.5
	_settings.sfx_volume = 0.55
	_settings.voice_volume = 0.65
	_settings.ui_volume = 0.75
	_settings.fullscreen = true
	_settings.resolution = Vector2i(1920, 1080)
	_settings.vsync_enabled = false
	_settings.max_fps = 120
	_settings.render_scale = 0.75
	_settings.captions_enabled = false
	_settings.mono_downmix = true
	_settings.dynamic_range = GameSettings.DYNAMIC_RANGE_REDUCED
	assert_true(_settings.save_settings(), "файл настроек сохраняется")

	var loaded := GameSettings.new(TEST_PATH)
	assert_true(loaded.load_settings(), "файл настроек читается")
	assert_almost_eq(loaded.master_volume, 0.35, 0.001)
	assert_almost_eq(loaded.music_volume, 0.45, 0.001)
	assert_almost_eq(loaded.ambience_volume, 0.5, 0.001)
	assert_almost_eq(loaded.sfx_volume, 0.55, 0.001)
	assert_almost_eq(loaded.voice_volume, 0.65, 0.001)
	assert_almost_eq(loaded.ui_volume, 0.75, 0.001)
	assert_true(loaded.fullscreen)
	assert_eq(loaded.resolution, Vector2i(1920, 1080))
	assert_false(loaded.vsync_enabled)
	assert_eq(loaded.max_fps, 120)
	assert_almost_eq(loaded.render_scale, 0.75, 0.001)
	assert_false(loaded.captions_enabled, "субтитры звуков сохраняются")
	assert_true(loaded.mono_downmix, "моно-сведение сохраняется")
	assert_eq(loaded.dynamic_range, GameSettings.DYNAMIC_RANGE_REDUCED, "динамический диапазон сохраняется")


func test_missing_file_keeps_defaults() -> void:
	_settings.master_volume = 0.1
	assert_false(_settings.load_settings(), "без файла загрузка сообщает об ошибке")
	assert_almost_eq(
		_settings.master_volume,
		GameSettings.DEFAULT_MASTER_VOLUME,
		0.001,
		"значения по умолчанию не портятся"
	)


func test_invalid_values_are_sanitized() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", 2.0)
	config.set_value("graphics", "resolution_width", 9999)
	config.set_value("graphics", "resolution_height", 100)
	config.set_value("graphics", "max_fps", 37)
	config.set_value("graphics", "render_scale", 4.0)
	assert_eq(config.save(TEST_PATH), OK)

	var loaded := GameSettings.new(TEST_PATH)
	assert_true(loaded.load_settings())
	assert_almost_eq(loaded.master_volume, 1.0, 0.001, "громкость ограничена сверху")
	assert_eq(loaded.resolution, GameSettings.DEFAULT_RESOLUTION, "неизвестное разрешение сброшено")
	assert_eq(loaded.max_fps, GameSettings.DEFAULT_MAX_FPS, "неизвестный FPS сброшен")
	assert_almost_eq(loaded.render_scale, 1.0, 0.001, "масштаб ограничен сверху")


func test_reset_defaults_restores_every_value() -> void:
	_settings.master_volume = 0.1
	_settings.music_volume = 0.2
	_settings.ambience_volume = 0.3
	_settings.sfx_volume = 0.3
	_settings.voice_volume = 0.4
	_settings.ui_volume = 0.5
	_settings.fullscreen = true
	_settings.resolution = Vector2i(2560, 1440)
	_settings.vsync_enabled = false
	_settings.max_fps = 30
	_settings.render_scale = 0.5
	_settings.captions_enabled = false
	_settings.mono_downmix = true
	_settings.dynamic_range = GameSettings.DYNAMIC_RANGE_REDUCED

	_settings.reset_defaults()
	assert_almost_eq(_settings.master_volume, GameSettings.DEFAULT_MASTER_VOLUME, 0.001)
	assert_almost_eq(_settings.music_volume, GameSettings.DEFAULT_MUSIC_VOLUME, 0.001)
	assert_almost_eq(_settings.ambience_volume, GameSettings.DEFAULT_AMBIENCE_VOLUME, 0.001)
	assert_almost_eq(_settings.sfx_volume, GameSettings.DEFAULT_SFX_VOLUME, 0.001)
	assert_almost_eq(_settings.voice_volume, GameSettings.DEFAULT_VOICE_VOLUME, 0.001)
	assert_almost_eq(_settings.ui_volume, GameSettings.DEFAULT_UI_VOLUME, 0.001)
	assert_eq(_settings.fullscreen, GameSettings.DEFAULT_FULLSCREEN)
	assert_eq(_settings.resolution, GameSettings.DEFAULT_RESOLUTION)
	assert_eq(_settings.vsync_enabled, GameSettings.DEFAULT_VSYNC)
	assert_eq(_settings.max_fps, GameSettings.DEFAULT_MAX_FPS)
	assert_almost_eq(_settings.render_scale, GameSettings.DEFAULT_RENDER_SCALE, 0.001)
	assert_eq(_settings.captions_enabled, GameSettings.DEFAULT_CAPTIONS_ENABLED)
	assert_eq(_settings.mono_downmix, GameSettings.DEFAULT_MONO_DOWNMIX)
	assert_eq(_settings.dynamic_range, GameSettings.DEFAULT_DYNAMIC_RANGE)


func test_apply_creates_audio_buses_and_sets_master() -> void:
	_settings.master_volume = 0.5
	_settings.music_volume = 0.0
	_settings.render_scale = 0.75
	_settings.apply()

	var master := AudioServer.get_bus_index(&"Master")
	var music := AudioServer.get_bus_index(&"Music")
	var ambience := AudioServer.get_bus_index(&"Ambience")
	var sfx := AudioServer.get_bus_index(&"SFX")
	var voice := AudioServer.get_bus_index(&"Voice")
	var ui := AudioServer.get_bus_index(&"UI")
	assert_ne(master, -1, "шина Master существует")
	assert_ne(music, -1, "шина Music создана")
	assert_ne(ambience, -1, "шина Ambience создана")
	assert_ne(sfx, -1, "шина SFX создана")
	assert_ne(voice, -1, "шина Voice создана")
	assert_ne(ui, -1, "шина UI создана")
	assert_almost_eq(AudioServer.get_bus_volume_db(master), linear_to_db(0.5), 0.01)
	assert_false(AudioServer.is_bus_mute(master), "ненулевая громкость не глушит шину")
	assert_true(AudioServer.is_bus_mute(music), "нулевая громкость глушит шину")
	assert_almost_eq(get_tree().root.scaling_3d_scale, 0.75, 0.001)


func test_custom_binding_roundtrip_and_reset() -> void:
	_settings.assign_action_event(&"move_forward", _key_event(KEY_T))
	assert_true(_action_has_key(&"move_forward", KEY_T), "новая клавиша применяется сразу")
	assert_false(_action_has_key(&"move_forward", KEY_W), "старая клавиша заменена")
	var pressed_t := _key_event(KEY_T)
	pressed_t.pressed = true
	assert_true(InputMap.event_is_action(pressed_t, &"move_forward"), "InputMap принимает новую клавишу")
	var pressed_w := _key_event(KEY_W)
	pressed_w.pressed = true
	assert_false(InputMap.event_is_action(pressed_w, &"move_forward"), "старая клавиша больше не срабатывает")
	assert_true(_settings.has_custom_bindings())
	assert_true(_settings.save_settings())

	var loaded := GameSettings.new(TEST_PATH)
	assert_true(loaded.load_settings())
	loaded.apply_input()
	assert_true(_action_has_key(&"move_forward", KEY_T), "привязка читается из файла")

	loaded.reset_all_bindings()
	assert_false(loaded.has_custom_bindings())
	assert_true(_action_has_key(&"move_forward", KEY_W), "сброс возвращает project.godot")


func test_binding_conflict_is_reported_but_kept() -> void:
	var conflict := _settings.assign_action_event(&"move_forward", _key_event(KEY_S))
	assert_eq(conflict, &"move_back", "конфликт с движением назад найден")
	assert_true(_action_has_key(&"move_forward", KEY_S))
	assert_true(_action_has_key(&"move_back", KEY_S), "существующая привязка не удаляется молча")


func test_rebinding_to_same_key_keeps_multiple_events() -> void:
	var conflict := _settings.assign_action_event(&"advance_dialogue", _key_event(KEY_E))
	assert_eq(conflict, &"", "своя же клавиша не считается конфликтом")
	var keyboard_events := 0
	for event in InputMap.action_get_events(&"advance_dialogue"):
		if event is InputEventKey:
			keyboard_events += 1
	assert_eq(keyboard_events, 3, "повторное назначение не срезает Space и Enter")


func test_clear_and_reset_single_action() -> void:
	_settings.clear_action(&"jump")
	assert_eq(InputMap.action_get_events(&"jump").size(), 0, "очистка убирает все события")
	_settings.reset_action(&"jump")
	assert_true(_action_has_key(&"jump", KEY_SPACE), "сброс действия возвращает пробел")


func test_binding_serialization_keeps_modifiers() -> void:
	var event := _key_event(KEY_T)
	event.ctrl_pressed = true
	event.shift_pressed = true
	var restored := InputBindings.deserialize_event(InputBindings.serialize_event(event))
	assert_not_null(restored)
	if restored != null:
		assert_true(InputBindings.events_equal(event, restored), "сериализация сохраняет модификаторы")
		assert_string_contains(InputBindings.event_text(restored), "Ctrl+")
		assert_string_contains(InputBindings.event_text(restored), "Shift+")


func test_gamepad_event_text_does_not_fail() -> void:
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	assert_string_contains(InputBindings.event_text(button), "Геймпад")
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 1.0
	assert_string_contains(InputBindings.event_text(motion), "Стик")


func test_default_gamepad_bindings_are_applied() -> void:
	_settings.reset_all_bindings()
	_settings.apply_input()
	var has_jump_button := false
	for event in InputMap.action_get_events(&"jump"):
		if event is InputEventJoypadButton:
			has_jump_button = true
	assert_true(has_jump_button, "прыжок получает кнопку геймпада по умолчанию")
	var has_move_axis := false
	for event in InputMap.action_get_events(&"move_forward"):
		if event is InputEventJoypadMotion:
			has_move_axis = true
	assert_true(has_move_axis, "движение вперёд получает левый стик")


func test_user_override_does_not_add_gamepad_defaults() -> void:
	_settings.assign_action_event(&"jump", _key_event(KEY_J))
	var has_jump_button := false
	for event in InputMap.action_get_events(&"jump"):
		if event is InputEventJoypadButton:
			has_jump_button = true
	assert_false(has_jump_button, "пользовательская привязка не дополняется геймпадом")


func _key_event(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


func _action_has_key(action: StringName, code: int) -> bool:
	if not InputMap.has_action(action):
		return false
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			if key.physical_keycode == code or key.keycode == code:
				return true
	return false

class_name GameSettings
extends RefCounted
## Пользовательские настройки игры.
##
## Шаблон для стартового меню: графика, звук и управление. Значения хранятся
## в user://settings.cfg и применяются сразу. Пока настройки загружает только
## меню; когда появится пауза или отдельный экран настроек, этот класс можно
## сделать автозагрузкой без изменения формата файла.
##
## Разрешения и ограничения FPS — фиксированные списки, поэтому в конфиге
## могут оказаться только известные значения.

const SETTINGS_PATH := "user://settings.cfg"
const CONFIG_VERSION := 4

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const FPS_OPTIONS: Array[int] = [0, 30, 60, 120, 144]

const DEFAULT_MASTER_VOLUME := 0.8
const DEFAULT_MUSIC_VOLUME := 0.7
const DEFAULT_AMBIENCE_VOLUME := 0.8
const DEFAULT_SFX_VOLUME := 0.8
const DEFAULT_VOICE_VOLUME := 1.0
const DEFAULT_UI_VOLUME := 0.8
const DEFAULT_FULLSCREEN := false
const DEFAULT_RESOLUTION := Vector2i(1600, 900)
const DEFAULT_VSYNC := true
const DEFAULT_MAX_FPS := 0
const DEFAULT_RENDER_SCALE := 1.0
const DEFAULT_CAPTIONS_ENABLED := true
const DEFAULT_MONO_DOWNMIX := false
const DEFAULT_DYNAMIC_RANGE := 0

const DYNAMIC_RANGE_FULL := 0
const DYNAMIC_RANGE_REDUCED := 1

var master_volume := DEFAULT_MASTER_VOLUME
var music_volume := DEFAULT_MUSIC_VOLUME
var ambience_volume := DEFAULT_AMBIENCE_VOLUME
var sfx_volume := DEFAULT_SFX_VOLUME
var voice_volume := DEFAULT_VOICE_VOLUME
var ui_volume := DEFAULT_UI_VOLUME
var fullscreen := DEFAULT_FULLSCREEN
var resolution := DEFAULT_RESOLUTION
var vsync_enabled := DEFAULT_VSYNC
var max_fps := DEFAULT_MAX_FPS
var render_scale := DEFAULT_RENDER_SCALE
var captions_enabled := DEFAULT_CAPTIONS_ENABLED
var mono_downmix := DEFAULT_MONO_DOWNMIX
var dynamic_range := DEFAULT_DYNAMIC_RANGE

var _storage_path := SETTINGS_PATH
## Переопределения InputMap: action -> Array[InputEvent]. Если действия нет
## в словаре, используется привязка из project.godot.
var _input_overrides: Dictionary = {}


func _init(storage_path := SETTINGS_PATH) -> void:
	_storage_path = storage_path


## Загружает настройки. Если файла нет или он повреждён, остаются значения
## по умолчанию. Возвращает true только при успешном чтении.
func load_settings() -> bool:
	var config := ConfigFile.new()
	if config.load(_storage_path) != OK:
		reset_defaults()
		return false

	var version := int(config.get_value("meta", "version", 1))
	if version > CONFIG_VERSION:
		push_warning("GameSettings: config version %d is newer than %d; unknown keys are ignored." % [version, CONFIG_VERSION])

	master_volume = clampf(
		float(config.get_value("audio", "master", DEFAULT_MASTER_VOLUME)), 0.0, 1.0
	)
	music_volume = clampf(
		float(config.get_value("audio", "music", DEFAULT_MUSIC_VOLUME)), 0.0, 1.0
	)
	ambience_volume = clampf(
		float(config.get_value("audio", "ambience", DEFAULT_AMBIENCE_VOLUME)), 0.0, 1.0
	)
	sfx_volume = clampf(
		float(config.get_value("audio", "sfx", DEFAULT_SFX_VOLUME)), 0.0, 1.0
	)
	voice_volume = clampf(
		float(config.get_value("audio", "voice", DEFAULT_VOICE_VOLUME)), 0.0, 1.0
	)
	ui_volume = clampf(
		float(config.get_value("audio", "ui", DEFAULT_UI_VOLUME)), 0.0, 1.0
	)

	fullscreen = bool(config.get_value("graphics", "fullscreen", DEFAULT_FULLSCREEN))
	resolution = Vector2i(
		clampi(int(config.get_value("graphics", "resolution_width", DEFAULT_RESOLUTION.x)), 640, 7680),
		clampi(int(config.get_value("graphics", "resolution_height", DEFAULT_RESOLUTION.y)), 360, 4320)
	)
	if not RESOLUTIONS.has(resolution):
		resolution = DEFAULT_RESOLUTION

	vsync_enabled = bool(config.get_value("graphics", "vsync", DEFAULT_VSYNC))
	max_fps = int(config.get_value("graphics", "max_fps", DEFAULT_MAX_FPS))
	if not FPS_OPTIONS.has(max_fps):
		max_fps = DEFAULT_MAX_FPS

	render_scale = clampf(
		float(config.get_value("graphics", "render_scale", DEFAULT_RENDER_SCALE)), 0.5, 1.0
	)
	captions_enabled = bool(config.get_value("accessibility", "captions", DEFAULT_CAPTIONS_ENABLED))
	mono_downmix = bool(config.get_value("accessibility", "mono_downmix", DEFAULT_MONO_DOWNMIX))
	dynamic_range = clampi(
		int(config.get_value("accessibility", "dynamic_range", DEFAULT_DYNAMIC_RANGE)),
		DYNAMIC_RANGE_FULL,
		DYNAMIC_RANGE_REDUCED
	)

	_input_overrides.clear()
	if config.has_section("input"):
		for action_key in config.get_section_keys("input"):
			var action := StringName(action_key)
			if not InputBindings.ACTIONS.has(action):
				continue
			var raw = config.get_value("input", action_key, [])
			if not raw is Array:
				continue
			var events: Array = []
			for item in raw:
				if item is Dictionary:
					var event := InputBindings.deserialize_event(item)
					if event != null:
						events.append(event)
			_input_overrides[action] = events
	return true


## Сохраняет текущие значения. Возвращает true при успешной записи.
func save_settings() -> bool:
	var config := ConfigFile.new()
	config.set_value("meta", "version", CONFIG_VERSION)
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "ambience", ambience_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("audio", "voice", voice_volume)
	config.set_value("audio", "ui", ui_volume)
	config.set_value("graphics", "fullscreen", fullscreen)
	config.set_value("graphics", "resolution_width", resolution.x)
	config.set_value("graphics", "resolution_height", resolution.y)
	config.set_value("graphics", "vsync", vsync_enabled)
	config.set_value("graphics", "max_fps", max_fps)
	config.set_value("graphics", "render_scale", render_scale)
	config.set_value("accessibility", "captions", captions_enabled)
	config.set_value("accessibility", "mono_downmix", mono_downmix)
	config.set_value("accessibility", "dynamic_range", dynamic_range)
	for action in _input_overrides:
		var serialized: Array = []
		for event in _input_overrides[action]:
			serialized.append(InputBindings.serialize_event(event))
		config.set_value("input", String(action), serialized)
	return config.save(_storage_path) == OK


func reset_defaults() -> void:
	master_volume = DEFAULT_MASTER_VOLUME
	music_volume = DEFAULT_MUSIC_VOLUME
	ambience_volume = DEFAULT_AMBIENCE_VOLUME
	sfx_volume = DEFAULT_SFX_VOLUME
	voice_volume = DEFAULT_VOICE_VOLUME
	ui_volume = DEFAULT_UI_VOLUME
	fullscreen = DEFAULT_FULLSCREEN
	resolution = DEFAULT_RESOLUTION
	vsync_enabled = DEFAULT_VSYNC
	max_fps = DEFAULT_MAX_FPS
	render_scale = DEFAULT_RENDER_SCALE
	captions_enabled = DEFAULT_CAPTIONS_ENABLED
	mono_downmix = DEFAULT_MONO_DOWNMIX
	dynamic_range = DEFAULT_DYNAMIC_RANGE


## Применяет все настройки к текущей сессии.
func apply() -> void:
	apply_audio()
	apply_graphics()
	apply_input()


## Применяет пользовательские привязки. Действия без переопределения
## возвращаются к значениям из project.godot.
func apply_input() -> void:
	for action in InputBindings.ACTIONS:
		if not InputMap.has_action(action):
			continue
		var events: Array = []
		if _input_overrides.has(action):
			events = _input_overrides[action]
		else:
			events = _default_events(action)
			events.append_array(InputBindings.default_gamepad_events(action))
		InputMap.action_erase_events(action)
		for event in events:
			InputMap.action_add_event(action, event)


## Возвращает текущие события действия из InputMap.
func get_action_events(action: StringName) -> Array:
	if not InputMap.has_action(action):
		return []
	return InputMap.action_get_events(action)


## Строка для кнопки переназначения: «W», «E / Space / Enter» или «—».
func format_action(action: StringName) -> String:
	return InputBindings.events_text(get_action_events(action))


func is_action_customized(action: StringName) -> bool:
	return _input_overrides.has(action)


func has_custom_bindings() -> bool:
	return not _input_overrides.is_empty()


## Назначает действию одно событие вместо текущего набора. Возвращает имя
## действия, с которым есть конфликт, либо пустой StringName. Конфликт не
## отменяет привязку: в игре есть намеренные пересечения (E, ЛКМ), поэтому
## решение остаётся за игроком, а UI показывает предупреждение.
func assign_action_event(action: StringName, event: InputEvent) -> StringName:
	if not InputBindings.ACTIONS.has(action) or event == null:
		return &""
	if action_has_event(action, event):
		return &""
	var conflict := find_binding_conflict(action, event)
	_input_overrides[action] = [event]
	apply_input()
	return conflict


func action_has_event(action: StringName, event: InputEvent) -> bool:
	for existing in get_action_events(action):
		if InputBindings.events_equal(existing, event):
			return true
	return false


func find_binding_conflict(action: StringName, event: InputEvent) -> StringName:
	for other in InputBindings.ACTIONS:
		if other == action:
			continue
		for existing in get_action_events(other):
			if InputBindings.events_equal(existing, event):
				return other
	return &""


## Очищает все привязки действия. Действие остаётся в InputMap без событий.
func clear_action(action: StringName) -> void:
	if not InputBindings.ACTIONS.has(action):
		return
	_input_overrides[action] = []
	apply_input()


func reset_action(action: StringName) -> void:
	if not InputBindings.ACTIONS.has(action):
		return
	_input_overrides.erase(action)
	apply_input()


func reset_all_bindings() -> void:
	_input_overrides.clear()
	apply_input()


func _default_events(action: StringName) -> Array:
	var events: Array = []
	var configured = ProjectSettings.get_setting("input/" + String(action), {})
	if not configured is Dictionary:
		return events
	for event in configured.get("events", []):
		if event is InputEvent:
			events.append((event as InputEvent).duplicate())
	return events


## Применяет только громкость, не трогая окно и рендер.
func apply_audio() -> void:
	var director := _get_audio_director()
	if director != null and director.has_method(&"apply_bus_levels"):
		director.call(&"apply_bus_levels", master_volume, music_volume, ambience_volume, sfx_volume, voice_volume, ui_volume)
		if director.has_method(&"apply_accessibility"):
			director.call(&"apply_accessibility", captions_enabled, mono_downmix, dynamic_range)
		return
	_ensure_audio_buses()
	_apply_bus(&"Master", master_volume)
	_apply_bus(&"Music", music_volume)
	_apply_bus(&"Ambience", ambience_volume)
	_apply_bus(&"SFX", sfx_volume)
	_apply_bus(&"Voice", voice_volume)
	_apply_bus(&"UI", ui_volume)


func _get_audio_director() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(^"AudioDirector")


## Применяет только окно, V-Sync, лимит FPS и масштаб 3D-рендера.
func apply_graphics() -> void:
	if DisplayServer.get_name() != "headless":
		_apply_window()

	Engine.max_fps = max_fps

	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		tree.root.scaling_3d_scale = render_scale


## Гарантирует наличие шин Music и SFX. Звуковых файлов в проекте пока нет,
## поэтому шины создаются пустыми и готовы к подключению будущей музыки.
func _ensure_audio_buses() -> void:
	# Reverb must exist before buses try to send to it.
	var specs := {
		&"Reverb": &"Master",
		&"Music": &"Reverb",
		&"Ambience": &"Reverb",
		&"SFX": &"Master",
		&"Voice": &"Master",
		&"UI": &"Master",
	}
	for bus_name in specs:
		var index := AudioServer.get_bus_index(bus_name)
		if index == -1:
			AudioServer.add_bus()
			index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, String(bus_name))
		AudioServer.set_bus_send(index, specs[bus_name])


func _apply_bus(bus_name: StringName, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, volume <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.001)))


func _apply_window() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var embedded := tree == null or tree.root == null or tree.root.is_embedded()

	if not embedded:
		var mode := (
			DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		)
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)

	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	)

	# Встроенное в редактор окно игры не поддерживает изменение размера и позиции.
	if embedded:
		return

	if not fullscreen:
		DisplayServer.window_set_size(resolution)
		var screen := DisplayServer.window_get_current_screen()
		var screen_position := DisplayServer.screen_get_position(screen)
		var screen_size := DisplayServer.screen_get_size(screen)
		var center_offset := Vector2i(Vector2(screen_size - resolution) / 2.0)
		DisplayServer.window_set_position(screen_position + center_offset)

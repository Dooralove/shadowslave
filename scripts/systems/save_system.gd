extends Node
## Autoload SaveSystem: быстрый слот для выхода и возврата.
##
## Сохраняет только игровое состояние: NightmareRunState (флаги, предметы,
## квесты, валюту, Памяти, чекпоинт), сцену и позицию игрока. Настройки,
## достижения и косметика живут отдельно. Это не второй QuestSystem и не
## второй инвентарь: снимок делает существующий NightmareRunState.

signal saved(slot: String)
signal loaded(slot: String)
signal save_failed(reason: String)

const DEFAULT_SAVE_PATH := "user://campaign_save.bin"
const SAVE_VERSION := 1
const SAVE_MAGIC := "SHADOWSLAVE_SAVE"
const APPLY_DELAY_FRAMES := 3

var save_path := DEFAULT_SAVE_PATH

var _pending_scene := ""
var _pending_position := Vector3.ZERO
var _pending_rotation := 0.0
var _pending_frames := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_input_actions()


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save_game(slot: String = "quick") -> bool:
	var payload := _build_payload()
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		var reason := "не удалось открыть %s (код %d)" % [save_path, FileAccess.get_open_error()]
		save_failed.emit(reason)
		push_error("SaveSystem: " + reason)
		_notify("Не удалось сохранить.")
		return false
	file.store_line(SAVE_MAGIC)
	file.store_var(payload, true)
	file.close()
	saved.emit(slot)
	_notify("Сохранено.")
	return true


## Снимок без записи: используется тестами и отладочными инструментами.
func build_snapshot() -> Dictionary:
	return _build_payload()


func read_save() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}
	var magic := file.get_line()
	if magic != SAVE_MAGIC:
		file.close()
		print_verbose("SaveSystem: файл не является снимком ShadowSlave")
		return {}
	if file.get_length() - file.get_position() < 4:
		file.close()
		print_verbose("SaveSystem: снимок обрезан")
		return {}
	var value: Variant = file.get_var(true)
	file.close()
	if not (value is Dictionary):
		return {}
	var payload: Dictionary = value
	if int(payload.get("version", 0)) != SAVE_VERSION:
		push_warning("SaveSystem: несовместимая версия снимка")
		return {}
	if not (payload.get("run_state") is Dictionary):
		return {}
	return payload


## Загружает состояние и возвращает игрока в сохранённую сцену/точку.
## Смена сцены откладывается до конца кадра; позиция применяется после
## появления игрока в новой сцене.
func load_game(slot: String = "quick") -> bool:
	var payload := read_save()
	if payload.is_empty():
		save_failed.emit("сохранение не найдено или повреждено")
		_notify("Сохранение не найдено или повреждено.")
		return false
	var state_value: Variant = payload.get("run_state", {})
	if not (state_value is Dictionary):
		save_failed.emit("повреждённое состояние прохождения")
		_notify("Повреждённое состояние прохождения.")
		return false
	NightmareRunState.restore(state_value)
	_pending_scene = String(payload.get("scene", ""))
	var position_value: Variant = payload.get("position", Vector3.ZERO)
	if position_value is Vector3:
		_pending_position = position_value
	_pending_rotation = float(payload.get("rotation_y", 0.0))
	_pending_frames = APPLY_DELAY_FRAMES
	loaded.emit(slot)
	_notify("Загружено.")
	if _pending_scene.is_empty():
		_pending_frames = 0
		_apply_pending()
		return true
	if get_tree().current_scene != null and get_tree().current_scene.scene_file_path == _pending_scene:
		# Та же сцена: перезагружаем её, чтобы сбросить врагов и подобранные
		# предметы к состоянию снимка, а затем применяем позицию.
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file(_pending_scene)
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func _build_payload() -> Dictionary:
	var tree := get_tree()
	var scene_path := ""
	if tree.current_scene != null:
		scene_path = tree.current_scene.scene_file_path
	var player := tree.get_first_node_in_group(&"player") as Node3D
	var position := player.global_position if player != null else Vector3.ZERO
	var rotation_y := 0.0
	if player != null:
		var visual := player.get_node_or_null(^"Visual") as Node3D
		if visual != null:
			rotation_y = visual.rotation.y
	return {
		"version": SAVE_VERSION,
		"scene": scene_path,
		"position": position,
		"rotation_y": rotation_y,
		"saved_at": Time.get_unix_time_from_system(),
		"run_state": NightmareRunState.snapshot(),
	}


func _process(_delta: float) -> void:
	if _pending_frames <= 0:
		return
	_pending_frames -= 1
	if _pending_frames > 0:
		return
	if get_tree().current_scene == null:
		return
	if not _pending_scene.is_empty() and get_tree().current_scene.scene_file_path != _pending_scene:
		return
	_apply_pending()


func _apply_pending() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as SunnyController
	if player == null:
		# Финальная карточка и другие UI-сцены не содержат игрока. Не держим
		# pending вечно: сцена уже загружена, применять позицию некуда.
		_clear_pending()
		return
	player.global_position = _pending_position
	player.velocity = Vector3.ZERO
	player.visual.rotation.y = _pending_rotation
	player.camera_rig.set_yaw(_pending_rotation)
	var recovery := player.get_node_or_null(^"FallRecovery") as FallRecovery
	if recovery != null:
		recovery.set_checkpoint(_pending_position, NightmareRunState.get_checkpoint_id())
	_clear_pending()


func _clear_pending() -> void:
	_pending_scene = ""
	_pending_position = Vector3.ZERO
	_pending_rotation = 0.0
	_pending_frames = 0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"quick_save"):
		save_game()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"quick_load"):
		load_game()
		get_viewport().set_input_as_handled()


func _ensure_input_actions() -> void:
	_add_action_if_missing(&"quick_save", KEY_F5)
	_add_action_if_missing(&"quick_load", KEY_F9)


func _add_action_if_missing(action: StringName, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


func _notify(text: String) -> void:
	var quests := get_node_or_null(^"/root/QuestSystem")
	if quests != null and quests.has_method(&"show_message"):
		quests.call(&"show_message", text, &"info")

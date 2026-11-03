extends Node
## Autoload единого меню паузы.
##
## Меню открывается по Esc только в игровых 3D-сценах и никогда не
## перекрывает уже открытые модальные окна (меню персонажа, карту, рюкзак,
## Море Души). Пауза и мышь восстанавливаются в одном месте.

signal menu_opened
signal menu_closed

const SCENE_PATH := "res://scenes/ui/pause_menu/pause_menu.tscn"
const LAYER := 120

var screen: PauseMenu
var _layer: CanvasLayer
var _open := false
var _saved_paused := false
var _saved_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _ignore_cancel_until_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_screen()
	_connect_modal_signals()


func is_open() -> bool:
	return _open


func open_menu() -> bool:
	if _open:
		return false
	if not _is_gameplay_scene() or _is_modal_open() or _cutscene_locked():
		return false
	_ensure_screen()
	if screen == null:
		return false
	_saved_paused = get_tree().paused
	_saved_mouse_mode = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_open = true
	screen.open()
	menu_opened.emit()
	return true


func close_menu() -> void:
	if not _open:
		return
	_open = false
	if screen != null:
		screen.close()
	get_tree().paused = _saved_paused
	Input.mouse_mode = _saved_mouse_mode
	menu_closed.emit()


func toggle_menu() -> void:
	if _open:
		close_menu()
	else:
		open_menu()


## Пока пауза открыта, игровые горячие клавиши не должны открывать другие
## модальные слои поверх неё. _input срабатывает раньше _unhandled_input,
## поэтому C/I/M не доходят до PlayerMenuSystem/MapSystem.
func _input(event: InputEvent) -> void:
	if not _open:
		return
	for action in [&"open_map", &"open_character", &"open_inventory", &"open_soul_sea"]:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			return


func _unhandled_input(event: InputEvent) -> void:
	if not (event.is_action_pressed(&"release_mouse") or event.is_action_pressed(&"ui_cancel")):
		return
	if _open:
		if screen != null and screen.has_open_confirmation() and event.is_action_pressed(&"ui_cancel"):
			screen.cancel_confirmation()
		else:
			close_menu()
		get_viewport().set_input_as_handled()
		return
	if Time.get_ticks_msec() < _ignore_cancel_until_ms:
		return
	if _cutscene_locked():
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_cancel") and _is_modal_open():
		return
	if not _is_gameplay_scene() or _is_modal_open():
		return
	if open_menu():
		get_viewport().set_input_as_handled()


func _cutscene_locked() -> bool:
	var director := get_node_or_null(^"/root/CutsceneDirector")
	return director != null and director.has_method(&"is_locked") and bool(director.call(&"is_locked"))


func _is_gameplay_scene() -> bool:
	# В редакторском запуске current_scene может быть ещё не назначен на
	# первом кадре; наличие живого игрока — достаточный признак 3D-сцены.
	return get_tree().get_first_node_in_group(&"player") != null


func _is_modal_open() -> bool:
	if _open:
		return true
	var player_menu := get_node_or_null(^"/root/PlayerMenuSystem")
	if player_menu != null and player_menu.has_method(&"is_open") and bool(player_menu.call(&"is_open")):
		return true
	var map_system := get_node_or_null(^"/root/MapSystem")
	if map_system != null and map_system.has_method(&"is_open") and bool(map_system.call(&"is_open")):
		return true
	for group in [&"inventory_modal", &"soul_sea_modal", &"quest_choice_panel", &"final_card"]:
		var node := get_tree().get_first_node_in_group(group)
		if node == null:
			continue
		if node.has_method(&"is_open") and bool(node.call(&"is_open")):
			return true
		if node.has_method(&"is_active") and bool(node.call(&"is_active")):
			return true
	return false


func _ensure_screen() -> void:
	if screen != null:
		return
	if not ResourceLoader.exists(SCENE_PATH):
		push_error("PauseMenuSystem: не найдена сцена %s" % SCENE_PATH)
		return
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		push_error("PauseMenuSystem: не удалось загрузить %s" % SCENE_PATH)
		return
	screen = packed.instantiate() as PauseMenu
	if screen == null:
		push_error("PauseMenuSystem: сцена не является PauseMenu")
		return
	_layer = CanvasLayer.new()
	_layer.name = "PauseMenuLayer"
	_layer.layer = LAYER
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	screen.visible = false
	_layer.add_child(screen)
	screen.resume_requested.connect(close_menu)
	screen.main_menu_requested.connect(_on_main_menu_requested)
	screen.quit_requested.connect(_on_quit_requested)


func _connect_modal_signals() -> void:
	var player_menu := get_node_or_null(^"/root/PlayerMenuSystem")
	if player_menu != null and player_menu.has_signal(&"menu_closed"):
		player_menu.menu_closed.connect(_on_other_modal_closed)
	var map_system := get_node_or_null(^"/root/MapSystem")
	if map_system != null and map_system.has_signal(&"map_closed"):
		map_system.map_closed.connect(_on_other_modal_closed)


func _on_other_modal_closed() -> void:
	# Esc, которым закрыли другое окно, не должен в том же кадре открыть паузу.
	_ignore_cancel_until_ms = Time.get_ticks_msec() + 180


func _on_main_menu_requested() -> void:
	close_menu()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/ui/main_menu/main_menu.tscn")


func _on_quit_requested() -> void:
	get_tree().quit()

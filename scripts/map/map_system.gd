extends Node
## Autoload системы карт.
##
## Единственная точка входа: слушает действие open_map (M), находит карту
## текущей сцены, показывает общий MapScreen и восстанавливает паузу/мышь
## при закрытии. Ни одна игровая локация не обязана знать об этом узле.

signal map_opened(location: MapDefinition)
signal map_closed

const ATLAS_PATH := "res://resources/map/map_atlas.tres"
const MAP_SCREEN_SCENE := preload("res://scenes/ui/map/map_screen.tscn")

var atlas: MapAtlas
var screen: MapScreen

var _open := false
var _saved_paused := false
var _saved_mouse_mode := Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	atlas = load(ATLAS_PATH) as MapAtlas
	if atlas == null:
		push_error("MapSystem: не удалось загрузить %s" % ATLAS_PATH)
		return

	screen = MAP_SCREEN_SCENE.instantiate() as MapScreen
	add_child(screen)
	screen.setup(atlas)
	screen.close_requested.connect(close_map)
	screen.visible = false


func is_open() -> bool:
	return _open


func _prototype_modal_active() -> bool:
	var inventory := get_tree().get_first_node_in_group(&"inventory_modal")
	if inventory != null and inventory.has_method(&"is_open") and bool(inventory.call(&"is_open")):
		return true
	var soul_sea := get_tree().get_first_node_in_group(&"soul_sea_modal")
	if soul_sea != null and soul_sea.has_method(&"is_active") and bool(soul_sea.call(&"is_active")):
		return true
	return false


func open_map() -> bool:
	if _open or screen == null:
		return false

	if _prototype_modal_active():
		return false

	# Карта и меню персонажа — взаимоисключающие модальные слои.
	_close_player_menu_for_switch()

	var location := resolve_current_location()
	_saved_paused = get_tree().paused
	_saved_mouse_mode = Input.mouse_mode

	# Карта — модальный слой: игра замирает, курсор нужен для выбора регионов.
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_open = true
	_update_player_marker(get_tree().current_scene)
	screen.open_for_location(location)
	map_opened.emit(location)
	return true


func close_map() -> void:
	if not _open:
		return
	_open = false
	if screen != null:
		screen.close_screen()
	get_tree().paused = _saved_paused
	Input.mouse_mode = _saved_mouse_mode
	map_closed.emit()


func _close_player_menu_for_switch() -> void:
	var player_menu := get_node_or_null("/root/PlayerMenuSystem")
	if player_menu != null and player_menu.has_method(&"is_open") and player_menu.call(&"is_open"):
		player_menu.call(&"close_menu")


func resolve_current_location() -> MapDefinition:
	return resolve_location_for(get_tree().current_scene)


## Публичный метод для тестов и особых сцен: карта определяется по корню
## сцены, без зависимости от того, что сейчас назначено current_scene.
func resolve_location_for(scene_root: Node) -> MapDefinition:
	if atlas != null:
		var found := atlas.find_location_for_scene(scene_root)
		if found != null:
			return found
	return MapDefinition.create_fallback(_fallback_title(scene_root))


## Переводит игрока в координаты корня текущей сцены (мировые XZ карты).
## Локальные сцены стоят в корне без смещения, поэтому разница — только
## в позиции игрока внутри сцены. Без игрока маркер просто не рисуется.
func _update_player_marker(scene_root: Node) -> void:
	if screen == null:
		return
	var state := player_state(scene_root)
	screen.set_player(state.position, state.forward, state.found)


## Игрок в координатах сцены: {found, position (XZ), forward (XZ)}.
func player_state(scene_root: Node) -> Dictionary:
	var state := {"found": false, "position": Vector2.ZERO, "forward": Vector2.ZERO}
	var root := scene_root as Node3D
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if root == null or player == null:
		return state
	var local := root.to_local(player.global_position)
	var forward := root.global_basis.inverse() * (-player.global_basis.z)
	state.found = true
	state.position = Vector2(local.x, local.z)
	state.forward = Vector2(forward.x, forward.z)
	return state


## Заготовка круглой мини-карты: карта текущей локации (её геометрия в
## мировых XZ сцены) и игрок в тех же координатах. Мини-карта рисует область
## вокруг игрока из location.features/markers; общая карта эти данные не меняет.
func minimap_snapshot() -> Dictionary:
	var scene := get_tree().current_scene
	var state := player_state(scene)
	return {
		"location": resolve_location_for(scene),
		"has_player": state.found,
		"player": state.position,
		"forward": state.forward,
	}


func _unhandled_input(event: InputEvent) -> void:
	if screen == null:
		return

	if event.is_action_pressed(&"open_map"):
		if _open:
			close_map()
		else:
			open_map()
		get_viewport().set_input_as_handled()
		return

	if _open and (
		event.is_action_pressed(&"ui_cancel")
		or event.is_action_pressed(&"release_mouse")
	):
		close_map()
		get_viewport().set_input_as_handled()


func _fallback_title(scene_root: Node) -> String:
	if scene_root == null:
		return "Неизвестная локация"

	var direct := _title_for_node(scene_root)
	if not direct.is_empty():
		return direct

	for node in scene_root.find_children("*", "", true, false):
		var found := _title_for_node(node)
		if not found.is_empty():
			return found

	return String(scene_root.name).replace("_", " ").capitalize()


func _title_for_node(node: Node) -> String:
	if node == null:
		return ""
	if node.has_meta(&"map_title"):
		return str(node.get_meta(&"map_title"))
	if node.has_method(&"get_map_title"):
		return str(node.call(&"get_map_title"))
	return ""

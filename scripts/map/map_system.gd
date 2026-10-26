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


func open_map() -> bool:
	if _open or screen == null:
		return false

	var location := resolve_current_location()
	_saved_paused = get_tree().paused
	_saved_mouse_mode = Input.mouse_mode

	# Карта — модальный слой: игра замирает, курсор нужен для выбора регионов.
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_open = true
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

	if _open and event.is_action_pressed(&"ui_cancel"):
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

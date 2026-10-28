extends Node
## Autoload единой точки входа в интерфейс игрока.
##
## Меню персонажа — существующий презентационный прототип RpgMenuPrototype.
## Сцена загружается только при первом открытии, чтобы не нагружать игровые
## сцены, где интерфейс ещё не вызывали. Карта остаётся владельцем MapSystem:
## при переключении системы закрывают друг друга, поэтому на экране всегда
## только один модальный слой.

signal menu_opened(section: StringName)
signal menu_closed

const MENU_SCENE_PATH := "res://scenes/ui/rpg_menu_prototype.tscn"
const DEFAULT_SECTION := &"character"
const MENU_LAYER := 80

var screen: RpgMenuPrototype
var _layer: CanvasLayer
var _open := false
var _saved_paused := false
var _saved_mouse_mode := Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_open() -> bool:
	return _open


## Открывает меню на указанном разделе. Повторный вызов при открытом меню
## только переключает раздел и не создаёт второй экран.
func open_menu(section: StringName = DEFAULT_SECTION) -> bool:
	if _open:
		if screen != null:
			screen.show_section(section)
		return false

	# Карта и меню — взаимоисключающие модальные слои.
	var map_system := get_node_or_null("/root/MapSystem")
	if map_system != null and map_system.has_method(&"is_open") and map_system.call(&"is_open"):
		map_system.call(&"close_map")

	_ensure_screen()
	if screen == null:
		return false

	_saved_paused = get_tree().paused
	_saved_mouse_mode = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_open = true
	screen.visible = true
	screen.open_menu(section)
	menu_opened.emit(section)
	return true


func close_menu() -> void:
	if not _open:
		return
	_open = false
	if screen != null:
		screen.visible = false
	get_tree().paused = _saved_paused
	Input.mouse_mode = _saved_mouse_mode
	menu_closed.emit()


func toggle_menu(section: StringName = DEFAULT_SECTION) -> void:
	if _open:
		close_menu()
	else:
		open_menu(section)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"open_character"):
		toggle_menu(DEFAULT_SECTION)
		get_viewport().set_input_as_handled()


func _ensure_screen() -> void:
	if screen != null:
		return
	if not ResourceLoader.exists(MENU_SCENE_PATH):
		push_error("PlayerMenuSystem: не найдена сцена %s" % MENU_SCENE_PATH)
		return

	var packed := load(MENU_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("PlayerMenuSystem: не удалось загрузить %s" % MENU_SCENE_PATH)
		return

	screen = packed.instantiate() as RpgMenuPrototype
	if screen == null:
		push_error("PlayerMenuSystem: сцена меню не является RpgMenuPrototype")
		return

	_layer = CanvasLayer.new()
	_layer.name = "PlayerMenuLayer"
	_layer.layer = MENU_LAYER
	add_child(_layer)

	screen.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.close_requested.connect(close_menu)
	screen.visible = false
	_layer.add_child(screen)

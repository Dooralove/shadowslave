class_name SoulSeaController
extends Node
## Локальный контроллер переключения между обычным миром и Морем Души.
##
## Не является autoload: сцена и её временные узлы принадлежат текущей
## игровой сцене. Мир не ставится на паузу, тело Санни остаётся в World3D,
## а меняются только активная камера, ввод тела и видимый HUD.

signal entered
signal exited

const SOUL_SEA_SCENE := preload("res://scenes/soul_sea/soul_sea.tscn")
## Удалённая точка того же World3D: содержимое не пересекается с ареной.
const ORIGIN := Vector3(12000.0, 0.0, 12000.0)

@export var player_path: NodePath
@export var world_camera_path: NodePath
@export var world_hud_path: NodePath
@export var soul_hud_path: NodePath
## Для демо-полигона: при входе разбудить противников, чтобы тело Санни
## действительно могло получить урон, пока игрок внутри. В обычных сценах
## выключено, чтобы не менять их AI.
@export var alert_enemies_on_entry := false

var _active := false
var _transitioning := false
var _soul_scene: SoulSeaScene

var _player: SunnyController
var _world_camera: Camera3D
var _world_hud: CanvasLayer
var _hud: SoulSeaHud
var _interactor: Interactor

var _saved_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _saved_camera_input := true
var _saved_camera_look := true
var _saved_interactor_enabled := true


func _ready() -> void:
	# Контроллер должен уметь отказать в открытии, даже если инвентарь уже
	# поставил дерево на паузу.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"soul_sea_modal")

	_player = get_node_or_null(player_path) as SunnyController
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as SunnyController

	_world_camera = get_node_or_null(world_camera_path) as Camera3D
	if _world_camera == null and _player != null:
		_world_camera = _player.camera_rig.camera as Camera3D

	_world_hud = get_node_or_null(world_hud_path) as CanvasLayer
	_hud = get_node_or_null(soul_hud_path) as SoulSeaHud
	if _hud == null:
		_hud = get_node_or_null("SoulSeaHud") as SoulSeaHud

	if _player == null:
		push_error("SoulSeaController: не найден SunnyController")
		return

	_interactor = _player.get_node_or_null("Interactor") as Interactor
	_player.health.damaged.connect(_on_body_damaged)
	_player.health.died.connect(_on_body_died)
	if _hud != null:
		_hud.bind(_player.health)


func is_active() -> bool:
	return _active


func enter_soul_sea() -> bool:
	if _active or _transitioning:
		return false
	if _player == null or _player.is_dead():
		return false
	if _player.health.is_dead():
		return false
	if not _player.input_enabled or _player.forced_velocity != Vector3.ZERO:
		return false
	if _inventory_open() or _player_menu_open() or _map_open():
		return false

	_transitioning = true
	_saved_mouse_mode = Input.mouse_mode
	_saved_camera_input = _player.camera_rig.input_enabled
	_saved_camera_look = _player.camera_rig.look_enabled
	_saved_interactor_enabled = _interactor.enabled if _interactor != null else true

	_player.set_soul_sea_suspended(true)
	_player.camera_rig.input_enabled = false
	_player.camera_rig.look_enabled = false
	if _interactor != null:
		_interactor.enabled = false
		_interactor.refresh()
	if _world_camera != null:
		_world_camera.current = false
	if _world_hud != null:
		_world_hud.visible = false

	_soul_scene = SOUL_SEA_SCENE.instantiate() as SoulSeaScene
	if _soul_scene == null:
		_restore_world()
		_transitioning = false
		return false

	add_child(_soul_scene)
	_soul_scene.global_position = ORIGIN
	_soul_scene.camera_rig.prompt_changed.connect(_on_prompt_changed)
	_soul_scene.beacon_activated.connect(_on_beacon_activated)
	_soul_scene.set_active(true)

	var soul_camera := _soul_scene.get_camera()
	if soul_camera == null:
		_soul_scene.queue_free()
		_soul_scene = null
		_restore_world()
		_transitioning = false
		return false

	soul_camera.current = true
	if _hud != null:
		_hud.set_active(true)
		_hud.show_message("Мир продолжает жить. Тело Санни остаётся уязвимым.")

	_active = true
	_transitioning = false
	if alert_enemies_on_entry:
		_alert_enemies()
	entered.emit()
	return true


func exit_soul_sea() -> void:
	if not _active or _transitioning:
		return

	_transitioning = true
	_active = false

	if _soul_scene != null and is_instance_valid(_soul_scene):
		_soul_scene.set_active(false)
		_soul_scene.queue_free()
	_soul_scene = null

	if _hud != null:
		_hud.set_active(false)

	_restore_world()
	_transitioning = false
	exited.emit()


func _restore_world() -> void:
	if _player != null and is_instance_valid(_player):
		_player.set_soul_sea_suspended(false)
		_player.camera_rig.input_enabled = _saved_camera_input
		_player.camera_rig.look_enabled = _saved_camera_look
		_player.camera_rig.camera.current = true
	if _world_camera != null and is_instance_valid(_world_camera):
		_world_camera.current = true
	if _world_hud != null and is_instance_valid(_world_hud):
		_world_hud.visible = true
	if _interactor != null and is_instance_valid(_interactor):
		_interactor.enabled = _saved_interactor_enabled
		_interactor.refresh()
	Input.mouse_mode = _saved_mouse_mode


func _unhandled_input(event: InputEvent) -> void:
	if _transitioning:
		return

	if event.is_action_pressed(&"open_soul_sea"):
		if _active:
			exit_soul_sea()
		else:
			enter_soul_sea()
		get_viewport().set_input_as_handled()
		return

	if _active and event.is_action_pressed(&"ui_cancel"):
		exit_soul_sea()
		get_viewport().set_input_as_handled()
		return

	if _active and event.is_action_pressed(&"open_inventory"):
		if _hud != null:
			_hud.show_message("Физический инвентарь недоступен в Море Души.")
		get_viewport().set_input_as_handled()


func _on_prompt_changed(text: String) -> void:
	if _hud != null:
		_hud.set_prompt(text)


func _on_beacon_activated(active: bool) -> void:
	if _hud == null:
		return
	if active:
		_hud.show_message("Память отозвалась. Это тестовая точка, не каноническая сущность.")
	else:
		_hud.show_message("Свет Памяти погас.")


func _on_body_damaged(amount: float) -> void:
	if _active and amount > 0.0 and _hud != null:
		_hud.show_damage_warning()


func _on_body_died() -> void:
	if _active:
		exit_soul_sea()


func _alert_enemies() -> void:
	for node in get_tree().get_nodes_in_group(&"enemy"):
		if node.has_method(&"alert_to"):
			node.call(&"alert_to", _player)


func _inventory_open() -> bool:
	var inventory := get_tree().get_first_node_in_group(&"inventory_modal")
	if inventory != null and inventory.has_method(&"is_open"):
		return bool(inventory.call(&"is_open"))
	return false


func _player_menu_open() -> bool:
	var menu := get_node_or_null("/root/PlayerMenuSystem")
	if menu != null and menu.has_method(&"is_open"):
		return bool(menu.call(&"is_open"))
	return false


func _map_open() -> bool:
	var map_system := get_node_or_null("/root/MapSystem")
	if map_system != null and map_system.has_method(&"is_open"):
		return bool(map_system.call(&"is_open"))
	return false


func _exit_tree() -> void:
	# При смене сцены временные узлы исчезают вместе с контроллером.
	# Успеваем вернуть глобальное состояние мыши и флаги тела, если они были
	# изменены, чтобы новая сцена не унаследовала захваченный курсор.
	if _active:
		Input.mouse_mode = _saved_mouse_mode
		if _player != null and is_instance_valid(_player):
			_player.set_soul_sea_suspended(false)

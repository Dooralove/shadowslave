class_name InventoryPrototype
extends Control
## Отдельный модальный инвентарь для прототипа.
##
## Переиспользует существующий RpgInventoryScreen и демонстрационный каталог,
## но не является вкладкой Моря Души и не связан с NightmareRunState.
## Пока это витрина физических предметов с локальными демо-данными.

signal opened
signal closed

const DEMO_CATALOG := preload("res://resources/rpg_menu/demo_catalog.tres")
const FEEDBACK_TIME := 3.0
const DESIGN_SIZE := Vector2(1600.0, 900.0)

@onready var content: Control = %Content
@onready var inventory_screen: RpgInventoryScreen = %InventoryScreen
@onready var close_button: Button = %CloseButton
@onready var feedback_label: Label = %FeedbackLabel

var session: RpgDemoSession
var _open := false
var _saved_paused := false
var _saved_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _feedback_left := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = RpgMenuTheme.build()
	add_to_group(&"inventory_modal")
	visible = false
	set_process(false)

	session = RpgDemoSession.new()
	session.initialize(DEMO_CATALOG)
	inventory_screen.setup(session)
	inventory_screen.feedback_requested.connect(_on_feedback_requested)
	close_button.pressed.connect(close_inventory)
	_reset_feedback()
	get_viewport().size_changed.connect(_layout_content)
	_layout_content()


func is_open() -> bool:
	return _open


func open_inventory() -> bool:
	if _open or _blocked():
		return false

	_saved_paused = get_tree().paused
	_saved_mouse_mode = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_open = true
	visible = true
	set_process(true)
	inventory_screen.focus_initial()
	opened.emit()
	return true


func close_inventory() -> void:
	if not _open:
		return
	_open = false
	visible = false
	set_process(false)
	get_tree().paused = _saved_paused
	Input.mouse_mode = _saved_mouse_mode
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _open:
		if event.is_action_pressed(&"open_inventory") or event.is_action_pressed(&"ui_cancel"):
			close_inventory()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"open_inventory"):
		# Если открытие запрещено Морем Души, событие не помечаем обработанным:
		# SoulSeaController покажет понятную подсказку.
		if open_inventory():
			get_viewport().set_input_as_handled()


func _layout_content() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var factor := minf(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	content.scale = Vector2(factor, factor)
	content.position = (viewport_size - DESIGN_SIZE * factor) * 0.5


func _process(delta: float) -> void:
	if _feedback_left <= 0.0:
		set_process(false)
		return
	_feedback_left = maxf(_feedback_left - delta, 0.0)
	if _feedback_left <= 0.0:
		_reset_feedback()
		set_process(false)


func _blocked() -> bool:
	var soul_sea := get_tree().get_first_node_in_group(&"soul_sea_modal")
	if soul_sea != null and soul_sea.has_method(&"is_active") and bool(soul_sea.call(&"is_active")):
		return true

	var player_menu := get_node_or_null("/root/PlayerMenuSystem")
	if player_menu != null and player_menu.has_method(&"is_open") and bool(player_menu.call(&"is_open")):
		return true

	var map_system := get_node_or_null("/root/MapSystem")
	if map_system != null and map_system.has_method(&"is_open") and bool(map_system.call(&"is_open")):
		return true

	return false


func _on_feedback_requested(text: String, tone: StringName) -> void:
	feedback_label.text = text
	feedback_label.add_theme_color_override(
		"font_color",
		RpgMenuTheme.RUST if tone == &"warning" else RpgMenuTheme.TEXT
	)
	_feedback_left = FEEDBACK_TIME
	set_process(true)


func _reset_feedback() -> void:
	feedback_label.text = "ДЕМО-ДАННЫЕ · ИЗМЕНЕНИЯ НЕ СОХРАНЯЮТСЯ · I / ESC — ЗАКРЫТЬ"
	feedback_label.add_theme_color_override("font_color", RpgMenuTheme.DIM)

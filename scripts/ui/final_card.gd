class_name FinalCard
extends CanvasLayer
## Переиспользуемая финальная карточка демо-фрагмента.
##
## Компонент не знает, M1 это или tech demo, не пишет флаги и не меняет
## сцену. A04 передаёт текст и слушает return_requested; так обе карточки
## используют один UI-слой, а не две конкурирующие финальные сцены.

signal return_requested

const LAYER := 115

var _root: Control
var _panel: PanelContainer
var _kicker: Label
var _title: Label
var _body: Label
var _hint: Label
var _button: Button
var _open := false
var _returned := false
var _saved_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _mouse_changed := false


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group(&"final_card")
	_ensure_ui()


func is_open() -> bool:
	return _open


func present(kicker_text: String, title_text: String, body_text: String, hint_text := "") -> void:
	_ensure_ui()
	if _open:
		_restore_mouse_mode()
	_kicker.text = kicker_text
	_title.text = title_text
	_body.text = body_text
	var hint := hint_text.strip_edges()
	if hint.is_empty():
		hint = "R / Esc — в главное меню"
	_hint.text = hint
	_hint.visible = true
	_open = true
	_returned = false
	visible = true
	_panel.visible = true
	_remember_mouse_mode()
	_button.call_deferred(&"grab_focus")


func close() -> void:
	if not _open and not visible:
		return
	_open = false
	visible = false
	if _panel != null:
		_panel.visible = false
	_restore_mouse_mode()


func _ensure_ui() -> void:
	if _root != null:
		return

	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = RpgMenuTheme.build()
	add_child(_root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.008, 0.01, 0.012, 0.9)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.theme_type_variation = &"RpgPanel"
	_panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(_panel)

	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 38)
	panel_margin.add_theme_constant_override("margin_right", 38)
	panel_margin.add_theme_constant_override("margin_top", 32)
	panel_margin.add_theme_constant_override("margin_bottom", 28)
	_panel.add_child(panel_margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel_margin.add_child(column)

	_kicker = Label.new()
	_kicker.name = "Kicker"
	_kicker.theme_type_variation = &"OverlineLabel"
	_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_kicker)

	_title = Label.new()
	_title.name = "Title"
	_title.theme_type_variation = &"ScreenTitle"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_title)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Color(0.34, 0.30, 0.23, 0.75)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)

	_body = Label.new()
	_body.name = "Body"
	_body.theme_type_variation = &"BodyLargeLabel"
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_body)

	_hint = Label.new()
	_hint.name = "Hint"
	_hint.theme_type_variation = &"TinyMutedLabel"
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint)

	_button = Button.new()
	_button.name = "BackButton"
	_button.text = "В главное меню"
	_button.theme_type_variation = &"PrimaryButton"
	_button.custom_minimum_size = Vector2(320, 46)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(_on_return_pressed)
	_button.mouse_entered.connect(_play_ui.bind(&"ui_hover"))
	_button.focus_entered.connect(_play_ui.bind(&"ui_hover"))
	column.add_child(_button)

	_panel.visible = false


func _on_return_pressed() -> void:
	if not _open or _returned:
		return
	_returned = true
	_play_ui(&"ui_confirm")
	return_requested.emit()
	close()


func _play_ui(id: StringName) -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	if director != null and director.is_node_ready() and director.has_method(&"play_ui"):
		director.call(&"play_ui", id)


func _remember_mouse_mode() -> void:
	_saved_mouse_mode = Input.mouse_mode
	_mouse_changed = _saved_mouse_mode != Input.MOUSE_MODE_VISIBLE
	if _mouse_changed:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _restore_mouse_mode() -> void:
	if _mouse_changed:
		Input.mouse_mode = _saved_mouse_mode
	_mouse_changed = false


func _input(event: InputEvent) -> void:
	if not _open:
		return
	for action in [&"open_map", &"open_character", &"open_inventory", &"open_soul_sea"]:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			return


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed(&"restart") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_return_pressed()


func _exit_tree() -> void:
	_restore_mouse_mode()

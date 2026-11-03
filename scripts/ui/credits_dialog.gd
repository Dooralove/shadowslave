class_name CreditsDialog
extends CanvasLayer
## Единый модальный экран кредитов и лицензий.
##
## Не использует стандартный AcceptDialog: его светлая тема выбивается из
## тёмного интерфейса игры. Компонент только показывает переданный текст,
## закрывается по Esc/кнопке и не меняет состояние игры.

signal closed

const LAYER := 140
const TITLE := "Кредиты и лицензии"

var _root: Control
var _panel: PanelContainer
var _title: Label
var _text: Label
var _scroll: ScrollContainer
var _close_button: Button
var _open := false
var _saved_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _mouse_changed := false


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group(&"credits_dialog")
	_ensure_ui()


func is_open() -> bool:
	return _open


func present(title_text: String, body_text: String) -> void:
	_ensure_ui()
	_title.text = title_text.strip_edges() if not title_text.strip_edges().is_empty() else TITLE
	_text.text = body_text.strip_edges() if not body_text.strip_edges().is_empty() else "Список лицензий пока пуст."
	_open = true
	visible = true
	_panel.visible = true
	_scroll.scroll_vertical = 0
	_remember_mouse_mode()
	_close_button.call_deferred(&"grab_focus")


func close() -> void:
	if not _open and not visible:
		return
	_open = false
	visible = false
	if _panel != null:
		_panel.visible = false
	_restore_mouse_mode()
	closed.emit()


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
	dim.color = Color(0.008, 0.01, 0.012, 0.84)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.theme_type_variation = &"RpgPanel"
	_panel.custom_minimum_size = Vector2(900, 500)
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var overline := Label.new()
	overline.text = "АРХИВ"
	overline.theme_type_variation = &"OverlineLabel"
	column.add_child(overline)

	_title = Label.new()
	_title.name = "Title"
	_title.text = TITLE
	_title.theme_type_variation = &"ScreenTitleSmall"
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_title)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Color(0.32, 0.29, 0.23, 0.7)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)

	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)

	_text = Label.new()
	_text.name = "Text"
	_text.theme_type_variation = &"BodyLabel"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size = Vector2(0, 1)
	_scroll.add_child(_text)

	var hint := Label.new()
	hint.text = "Esc — закрыть"
	hint.theme_type_variation = &"TinyMutedLabel"
	column.add_child(hint)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "ЗАКРЫТЬ"
	_close_button.theme_type_variation = &"PrimaryButton"
	_close_button.custom_minimum_size = Vector2(180, 44)
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close_button.pressed.connect(close)
	column.add_child(_close_button)

	_panel.visible = false


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	for action in [&"open_map", &"open_character", &"open_inventory", &"open_soul_sea"]:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			return


func _remember_mouse_mode() -> void:
	_saved_mouse_mode = Input.mouse_mode
	_mouse_changed = _saved_mouse_mode != Input.MOUSE_MODE_VISIBLE
	if _mouse_changed:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _restore_mouse_mode() -> void:
	if _mouse_changed:
		Input.mouse_mode = _saved_mouse_mode
	_mouse_changed = false


func _exit_tree() -> void:
	_restore_mouse_mode()

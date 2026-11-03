class_name QuestChoicePanel
extends CanvasLayer
## Модальная панель выбора для диалогов и побочных заданий.
##
## Панель не владеет квестовым состоянием и не знает о QuestSystem: A04
## показывает её, получает choice_selected и сам записывает флаг/событие.
## Это единственный UI-слой выбора, а не второй диалоговый движок.

signal choice_selected(choice_id: StringName)
signal closed

const LAYER := 110
const MAX_CHOICES := 4
const LOCKED_TEXT := "НЕДОСТУПНО"

var _root: Control
var _panel: PanelContainer
var _prompt_label: Label
var _choices_box: VBoxContainer
var _hint_label: Label
var _buttons: Array[Button] = []
var _choice_ids: Array[StringName] = []
var _open := false
var _emitted := false
var _saved_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _mouse_changed := false


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group(&"quest_choice_panel")
	_ensure_ui()


func is_open() -> bool:
	return _open


func get_choice_ids() -> Array[StringName]:
	return _choice_ids.duplicate()


## Показывает панель. choices[i] должен содержать id и text; поля flag,
## quest_event и quest_subject читает только backend A04. Необязательные
## locked/lock_reason позволяют показать заблокированную ложь SQ-03.
func present(prompt: String, choices: Array) -> void:
	_ensure_ui()
	if _open:
		_restore_mouse_mode()
	_open = false
	_clear_choices()
	_emitted = false
	_prompt_label.text = prompt.strip_edges() if not prompt.strip_edges().is_empty() else "Выберите ответ."
	_panel.visible = true

	var limit: int = mini(choices.size(), MAX_CHOICES)
	if choices.size() > MAX_CHOICES:
		push_warning("QuestChoicePanel: показаны первые %d из %d вариантов" % [MAX_CHOICES, choices.size()])
	if limit <= 0:
		push_warning("QuestChoicePanel: пустой список вариантов")
		_panel.visible = false
		visible = false
		return

	for index in limit:
		var choice: Dictionary = choices[index]
		var choice_id := StringName(choice.get("id", &""))
		if choice_id == &"":
			push_warning("QuestChoicePanel: вариант %d без id пропущен" % index)
			continue
		var locked := bool(choice.get("locked", false))
		var reason := String(choice.get("lock_reason", "")).strip_edges()
		var button := _make_choice_button(index, String(choice.get("text", "Вариант %d" % (index + 1))), locked, reason)
		if button == null:
			continue
		_buttons.append(button)
		_choice_ids.append(choice_id)
		_choices_box.add_child(button)

	if _buttons.is_empty():
		push_warning("QuestChoicePanel: нет доступных вариантов для показа")
		_panel.visible = false
		visible = false
		return

	_open = true
	visible = true
	_update_hint()
	_remember_mouse_mode()
	_play_ui(&"ui_tab")
	_focus_first_enabled()


func close() -> void:
	if not _open and not visible:
		return
	_open = false
	visible = false
	_panel.visible = false
	_clear_choices()
	_prompt_label.text = ""
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
	dim.color = Color(0.008, 0.01, 0.012, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 80)
	# Оставляем место для строки субтитров: выбор не должен наезжать на неё.
	margin.add_theme_constant_override("margin_bottom", 148)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(margin)

	var bottom_align := VBoxContainer.new()
	bottom_align.name = "BottomAlign"
	bottom_align.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_align.alignment = BoxContainer.ALIGNMENT_END
	bottom_align.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(bottom_align)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.theme_type_variation = &"RpgPanel"
	_panel.custom_minimum_size = Vector2(980, 0)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottom_align.add_child(_panel)

	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 28)
	panel_margin.add_theme_constant_override("margin_right", 28)
	panel_margin.add_theme_constant_override("margin_top", 22)
	panel_margin.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(panel_margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel_margin.add_child(column)

	var overline := Label.new()
	overline.text = "ВЫБОР"
	overline.theme_type_variation = &"OverlineLabel"
	column.add_child(overline)

	_prompt_label = Label.new()
	_prompt_label.name = "Prompt"
	_prompt_label.theme_type_variation = &"ScreenTitleSmall"
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_prompt_label)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Color(0.32, 0.29, 0.23, 0.7)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)

	_choices_box = VBoxContainer.new()
	_choices_box.name = "Choices"
	_choices_box.add_theme_constant_override("separation", 7)
	column.add_child(_choices_box)

	_hint_label = Label.new()
	_hint_label.name = "Hint"
	_hint_label.theme_type_variation = &"TinyMutedLabel"
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.text = "1–4 / ↑↓ — выбрать · Enter / ЛКМ — подтвердить"
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint_label)

	_panel.visible = false


func _make_choice_button(index: int, text: String, locked: bool, reason: String) -> Button:
	var button := Button.new()
	button.name = "Choice%d" % (index + 1)
	button.theme_type_variation = &"ListButton"
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 54)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 16)
	button.text = "%d.  %s" % [index + 1, text]
	if locked:
		button.disabled = true
		button.text += "  ·  " + (reason if not reason.is_empty() else LOCKED_TEXT)
		button.tooltip_text = reason if not reason.is_empty() else "Этот вариант недоступен."
		button.add_theme_color_override("font_disabled_color", RpgMenuTheme.MUTED)
	else:
		button.pressed.connect(_on_choice_pressed.bind(index))
		button.mouse_entered.connect(_play_ui.bind(&"ui_hover"))
		button.focus_entered.connect(_play_ui.bind(&"ui_hover"))
	return button


func _on_choice_pressed(index: int) -> void:
	if not _open or _emitted:
		return
	if index < 0 or index >= _buttons.size():
		return
	var button := _buttons[index]
	if button == null or button.disabled:
		return
	_emitted = true
	_play_ui(&"ui_confirm")
	var choice_id := _choice_ids[index]
	choice_selected.emit(choice_id)
	close()


func _update_hint() -> void:
	var enabled := 0
	for button in _buttons:
		if button != null and not button.disabled:
			enabled += 1
	if _buttons.size() <= 1:
		_hint_label.text = "1 — выбрать · Enter / ЛКМ — подтвердить"
	elif enabled == 0:
		_hint_label.text = "Нет доступных вариантов. Выбор нужно закрыть из диалога."
	else:
		_hint_label.text = "1–%d / ↑↓ — выбрать · Enter / ЛКМ — подтвердить" % _buttons.size()


func _play_ui(id: StringName) -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	if director != null and director.is_node_ready() and director.has_method(&"play_ui"):
		director.call(&"play_ui", id)


func _focus_first_enabled() -> void:
	for button in _buttons:
		if button != null and not button.disabled:
			button.call_deferred(&"grab_focus")
			return


func _clear_choices() -> void:
	for button in _buttons:
		if button != null and is_instance_valid(button):
			button.visible = false
			button.queue_free()
	_buttons.clear()
	_choice_ids.clear()


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
	for action in [&"open_map", &"open_character", &"open_inventory", &"open_soul_sea", &"release_mouse", &"ui_cancel"]:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			return


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			match key.keycode:
				KEY_1, KEY_2, KEY_3, KEY_4:
					var index := int(key.keycode - KEY_1)
					_on_choice_pressed(index)
					get_viewport().set_input_as_handled()
					return
				KEY_ESCAPE:
					# Не закрываем панель и не отдаём Esc паузе: выбор обязателен.
					get_viewport().set_input_as_handled()
					return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	_restore_mouse_mode()

class_name InputBindingRow
extends HBoxContainer
## Строка переназначения одного действия: название, текущая привязка, сброс.
##
## Пока строка слушает ввод, она перехватывает клавиши, мышь и геймпад.
## Esc отменяет ожидание, Backspace/Delete очищают привязку.

signal binding_changed(action: StringName, message: String)

const LISTENING_TEXT := "Нажмите клавишу…"
const RESET_TEXT := "↺"

static var _active_row: InputBindingRow

var action: StringName = &""
var _settings: GameSettings
var _bind_button: Button
var _reset_button: Button
var _listening := false
var _suppress_press_until_ms := 0


func setup(settings: GameSettings, action_id: StringName, minimum_width := 240.0) -> void:
	_settings = settings
	action = action_id
	add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.theme_type_variation = &"BodyLabel"
	title.text = InputBindings.action_title(action)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(title)

	_bind_button = Button.new()
	_bind_button.name = "BindButton"
	_bind_button.theme_type_variation = &"SecondaryButton"
	_bind_button.custom_minimum_size = Vector2(minimum_width, 32)
	_bind_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_bind_button.focus_mode = Control.FOCUS_ALL
	_bind_button.pressed.connect(_start_listening)
	add_child(_bind_button)

	_reset_button = Button.new()
	_reset_button.name = "ResetButton"
	_reset_button.text = RESET_TEXT
	_reset_button.tooltip_text = "Сбросить привязку"
	_reset_button.theme_type_variation = &"SecondaryButton"
	_reset_button.custom_minimum_size = Vector2(34, 32)
	_reset_button.focus_mode = Control.FOCUS_ALL
	_reset_button.pressed.connect(_reset_binding)
	add_child(_reset_button)
	refresh()


func refresh() -> void:
	if _bind_button == null or _settings == null:
		return
	if _listening:
		_bind_button.text = LISTENING_TEXT
		_bind_button.tooltip_text = "Esc — отмена · Backspace — очистить"
	else:
		_bind_button.text = _settings.format_action(action)
		_bind_button.tooltip_text = "Нажмите, чтобы назначить клавишу"
		_bind_button.disabled = false
	_reset_button.disabled = not _listening and not _settings.is_action_customized(action)


func cancel_listening() -> void:
	if not _listening:
		return
	_listening = false
	if _active_row == self:
		_active_row = null
	refresh()


func _exit_tree() -> void:
	if _active_row == self:
		_active_row = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		cancel_listening()


func _input(event: InputEvent) -> void:
	if not _listening:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		if key.physical_keycode == KEY_ESCAPE and not _has_modifiers(key):
			cancel_listening()
			accept_event()
			return
		if key.physical_keycode == KEY_BACKSPACE or key.physical_keycode == KEY_DELETE:
			_clear_binding()
			accept_event()
			return
		_bind_from_input(key)
		accept_event()
		return
	if event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			_bind_from_input(event)
			accept_event()
		return
	if event is InputEventJoypadButton:
		if (event as InputEventJoypadButton).pressed:
			_bind_from_input(event)
			accept_event()
		return
	if event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= 0.6:
			_bind_from_input(event)
			accept_event()


func _start_listening() -> void:
	if _settings == null:
		return
	if Time.get_ticks_msec() < _suppress_press_until_ms:
		return
	if _active_row != null and is_instance_valid(_active_row) and _active_row != self:
		_active_row.cancel_listening()
	_active_row = self
	_listening = true
	refresh()
	_bind_button.grab_focus()


func _bind_from_input(raw: InputEvent) -> void:
	var event := InputBindings.event_from_input(raw)
	if event == null:
		return
	var conflict := _settings.assign_action_event(action, event)
	_settings.save_settings()
	_finish_listening()
	var title := InputBindings.action_title(action)
	if conflict != &"":
		binding_changed.emit(
			action,
			"%s: клавиша уже используется — «%s»." % [title, InputBindings.action_title(conflict)]
		)
	else:
		binding_changed.emit(action, "%s: %s." % [title, InputBindings.event_text(event)])


func _clear_binding() -> void:
	if _settings == null:
		return
	_settings.clear_action(action)
	_settings.save_settings()
	_finish_listening()
	binding_changed.emit(action, "%s: привязка очищена." % InputBindings.action_title(action))


func _reset_binding() -> void:
	if _settings == null:
		return
	_settings.reset_action(action)
	_settings.save_settings()
	_finish_listening()
	binding_changed.emit(action, "%s: привязка сброшена." % InputBindings.action_title(action))


func _finish_listening() -> void:
	_listening = false
	if _active_row == self:
		_active_row = null
	_suppress_press_until_ms = Time.get_ticks_msec() + 150
	refresh()
	_bind_button.grab_focus()


func _has_modifiers(event: InputEventWithModifiers) -> bool:
	return event.ctrl_pressed or event.shift_pressed or event.alt_pressed or event.meta_pressed

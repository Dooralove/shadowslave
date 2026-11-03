class_name PauseMenu
extends Control
## Единое меню паузы для игровых 3D-сцен.
##
## Экран не владеет паузой и мышью: это делает PauseMenuSystem. Здесь только
## композиция, навигация, настройки и подтверждения. Меню читает те же
## QuestSystem / CampaignGuide, что и HUD, поэтому показывает актуальную цель,
## а не отдельную копию состояния.

signal resume_requested
signal main_menu_requested
signal quit_requested

const SECTION_RESUME := &"resume"
const SECTION_SETTINGS := &"settings"
const SECTION_CONTROLS := &"controls"
const SECTION_QUESTS := &"quests"
const CREDITS_PATH := "res://resources/ui/credits.tres"
const ESC_RESUME := "ESC — ПРОДОЛЖИТЬ"
const ESC_CANCEL := "ESC — ОТМЕНИТЬ"
const FOOTER_DEFAULT := "↑↓ — выбор · Enter — подтвердить · Esc — вернуться в игру"
const FOOTER_CONFIRM := "↑↓ — выбор · Enter — подтвердить · Esc — отменить"

const ACTION_TITLES := {
	&"move_forward": "Движение вперёд",
	&"move_back": "Движение назад",
	&"move_left": "Влево",
	&"move_right": "Вправо",
	&"sprint": "Бег / блок",
	&"jump": "Прыжок / уклонение",
	&"attack": "Удар",
	&"interact": "Взаимодействие",
	&"advance_dialogue": "Следующая реплика",
	&"open_status": "Статус Заклятия",
	&"open_map": "Карта",
	&"open_character": "Меню персонажа",
	&"open_inventory": "Рюкзак",
	&"open_soul_sea": "Море Души",
	&"release_mouse": "Пауза / освободить мышь",
	&"restart": "Перезапуск",
}

const CONTROL_SECTIONS := [
	{"title": "ДВИЖЕНИЕ", "actions": [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint", &"jump"]},
	{"title": "БОЙ", "actions": [&"attack", &"interact", &"advance_dialogue"]},
	{"title": "ИНТЕРФЕЙС", "actions": [&"open_status", &"open_map", &"open_character", &"open_inventory", &"open_soul_sea", &"release_mouse"]},
	{"title": "СЛУЖЕБНЫЕ", "actions": [&"restart"]},
]

@onready var _panel: PanelContainer = %Panel
@onready var _nav: VBoxContainer = %Nav
@onready var _content: VBoxContainer = %Content
@onready var _objective: Label = %Objective
@onready var _objective_meta: Label = %ObjectiveMeta
@onready var _footer_note: Label = %FooterNote
@onready var _esc_hint: Label = $Center/Panel/Margin/Column/Header/EscHint

var _buttons: Dictionary = {}
var _active_section: StringName = SECTION_RESUME
var _settings := GameSettings.new()
var _updating_ui := false
var _confirmation_open := false
var _credits_dialog: CreditsDialog


func _ready() -> void:
	theme = RpgMenuTheme.build()
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _panel != null:
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color(0.045, 0.05, 0.055, 0.985)
		panel_style.border_color = Color(0.48, 0.39, 0.27, 0.9)
		panel_style.set_border_width_all(1)
		panel_style.set_corner_radius_all(2)
		panel_style.set_content_margin_all(0.0)
		_panel.add_theme_stylebox_override("panel", panel_style)
	_build_credits_dialog()
	_build_nav()
	_connect_settings()
	_settings.load_settings()
	_settings.apply_input()
	_show_section(SECTION_RESUME)
	_refresh_objective()


func open() -> void:
	_confirmation_open = false
	visible = true
	_settings.load_settings()
	_settings.apply_input()
	_refresh_objective()
	_show_section(SECTION_RESUME)
	var first := _buttons.get(SECTION_RESUME) as Button
	if first != null:
		first.grab_focus()


func close() -> void:
	_confirmation_open = false
	visible = false
	if _credits_dialog != null and _credits_dialog.is_open():
		_credits_dialog.close()


func is_open() -> bool:
	return visible


func has_open_confirmation() -> bool:
	return _confirmation_open


func cancel_confirmation() -> void:
	if not _confirmation_open:
		return
	_show_section(_active_section)


func refresh_objective() -> void:
	_refresh_objective()


func _build_nav() -> void:
	for child in _nav.get_children():
		_nav.remove_child(child)
		child.queue_free()
	_buttons.clear()

	for item in [
		{"id": SECTION_RESUME, "label": "ПРОДОЛЖИТЬ", "index": "01"},
		{"id": SECTION_QUESTS, "label": "ТЕКУЩАЯ ЦЕЛЬ", "index": "02"},
		{"id": SECTION_SETTINGS, "label": "НАСТРОЙКИ", "index": "03"},
		{"id": SECTION_CONTROLS, "label": "УПРАВЛЕНИЕ", "index": "04"},
	]:
		var button := Button.new()
		button.name = "Pause_%s" % String(item["id"])
		button.theme_type_variation = &"NavButton"
		button.toggle_mode = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 44)
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_show_section.bind(StringName(item["id"])))
		_wire_button(button)
		_nav.add_child(button)

		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		line.add_theme_constant_override("separation", 10)
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_right", 12)
		line.add_child(_label(String(item["index"]), &"TinyMutedLabel", Vector2(24, 0)))
		var label := _label(String(item["label"]), &"BodyLabel")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(label)
		margin.add_child(line)
		button.add_child(margin)
		_buttons[StringName(item["id"])] = button

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nav.add_child(spacer)
	_nav.add_child(_rule())

	_nav.add_child(_action_button("КРЕДИТЫ И ЛИЦЕНЗИИ", _open_credits, &"SecondaryButton"))
	_nav.add_child(_action_button("В ГЛАВНОЕ МЕНЮ", _ask_main_menu, &"SecondaryButton"))
	_nav.add_child(_action_button("ВЫЙТИ ИЗ ИГРЫ", _ask_quit, &"DangerButton"))


func _action_button(text: String, callback: Callable, variation: StringName) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.custom_minimum_size = Vector2(0, 40)
	button.pressed.connect(callback)
	_wire_button(button)
	return button


func _wire_button(button: Button) -> void:
	if button == null:
		return
	button.pressed.connect(_play_ui.bind(&"ui_click"))
	_wire_hover(button)


func _wire_hover(button: Button) -> void:
	if button == null:
		return
	button.mouse_entered.connect(_play_ui.bind(&"ui_hover"))
	button.focus_entered.connect(_play_ui.bind(&"ui_hover"))


func _play_ui(id: StringName) -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	if director != null and director.is_node_ready() and director.has_method(&"play_ui"):
		director.call(&"play_ui", id)


func _show_section(section: StringName) -> void:
	_confirmation_open = false
	_active_section = section
	if _esc_hint != null:
		_esc_hint.text = ESC_RESUME
	if _footer_note != null:
		_footer_note.text = FOOTER_DEFAULT
	for id in _buttons:
		var button := _buttons[id] as Button
		button.set_pressed_no_signal(StringName(id) == section)
	_update_nav_styles()
	_clear_content()
	_content.add_theme_constant_override("separation", 10)
	match section:
		SECTION_RESUME:
			_build_resume()
		SECTION_QUESTS:
			_build_quests()
		SECTION_SETTINGS:
			_build_settings()
		SECTION_CONTROLS:
			_build_controls()
		_:
			_build_resume()
	var focus := _buttons.get(section) as Button
	if focus != null:
		focus.grab_focus()


func _update_nav_styles() -> void:
	for id in _buttons:
		var button := _buttons[id] as Button
		var active := StringName(id) == _active_section
		button.set_pressed_no_signal(active)
		button.add_theme_color_override(
			"font_color",
			RpgMenuTheme.BRONZE_BRIGHT if active else RpgMenuTheme.MUTED
		)


func _build_resume() -> void:
	_content.add_child(_label("МИР ЖДЁТ", &"SectionLabel"))
	_content.add_child(_body("Цель и состояние сохранены в текущей сцене; меню не перезаписывает прогресс."))
	_content.add_child(_rule())

	var resume := Button.new()
	resume.text = "ПРОДОЛЖИТЬ"
	resume.theme_type_variation = &"PrimaryButton"
	resume.custom_minimum_size = Vector2(0, 48)
	resume.pressed.connect(func() -> void: resume_requested.emit())
	_wire_button(resume)
	_content.add_child(resume)

	var tip := _label("Esc — вернуться в игру · ↑↓ — навигация · Enter — выбрать", &"TinyMutedLabel")
	_content.add_child(tip)
	resume.grab_focus()


func _build_quests() -> void:
	_content.add_child(_title("ТЕКУЩАЯ ЦЕЛЬ", "ЖУРНАЛ И ПРОГРЕСС"))
	var source := _get_objective_data()
	_content.add_child(_body(String(source.get("text", "Цель не задана."))))
	_content.add_child(_rule())
	_content.add_child(_label(String(source.get("meta", "")), &"TinyMutedLabel"))
	var open_button := Button.new()
	open_button.text = "ОТКРЫТЬ ЖУРНАЛ"
	open_button.theme_type_variation = &"SecondaryButton"
	open_button.custom_minimum_size = Vector2(0, 42)
	open_button.pressed.connect(func() -> void:
		resume_requested.emit()
		var menu := get_node_or_null(^"/root/PlayerMenuSystem")
		if menu != null and menu.has_method(&"open_menu"):
			menu.call(&"open_menu", &"journal")
	)
	_wire_button(open_button)
	_content.add_child(open_button)


func _build_settings() -> void:
	# Настройки — самый длинный раздел паузы. Уплотняем только его, чтобы
	# кнопка сброса оставалась видимой без обязательной прокрутки.
	_content.add_theme_constant_override("separation", 6)
	_content.add_child(_title("НАСТРОЙКИ", "ПРИМЕНЯЮТСЯ СРАЗУ"))
	_content.add_child(_settings_row("Общая громкость", "MasterSlider", _settings.master_volume))
	_content.add_child(_settings_row("Музыка", "MusicSlider", _settings.music_volume))
	_content.add_child(_settings_row("Окружение", "AmbienceSlider", _settings.ambience_volume))
	_content.add_child(_settings_row("Эффекты", "SfxSlider", _settings.sfx_volume))
	_content.add_child(_settings_row("Голос", "VoiceSlider", _settings.voice_volume))
	_content.add_child(_settings_row("Интерфейс", "UiSlider", _settings.ui_volume))
	_content.add_child(_rule())

	var fullscreen := CheckButton.new()
	fullscreen.text = "Полноэкранный режим"
	fullscreen.button_pressed = _settings.fullscreen
	fullscreen.theme_type_variation = &"CheckButton"
	fullscreen.toggled.connect(_on_fullscreen_toggled)
	_wire_hover(fullscreen)
	_content.add_child(fullscreen)

	var captions := CheckButton.new()
	captions.name = "CaptionsCheck"
	captions.text = "Субтитры"
	captions.button_pressed = _settings.captions_enabled
	captions.theme_type_variation = &"CheckButton"
	captions.toggled.connect(_on_captions_toggled)
	_wire_hover(captions)
	_content.add_child(captions)

	var mono := CheckButton.new()
	mono.name = "MonoCheck"
	mono.text = "Моно-звук"
	mono.button_pressed = _settings.mono_downmix
	mono.theme_type_variation = &"CheckButton"
	mono.toggled.connect(_on_mono_toggled)
	_wire_hover(mono)
	_content.add_child(mono)

	var dynamic_row := HBoxContainer.new()
	dynamic_row.add_theme_constant_override("separation", 12)
	var dynamic_label := _label("Динамический диапазон", &"BodyLabel")
	dynamic_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dynamic_row.add_child(dynamic_label)
	var dynamic_option := OptionButton.new()
	dynamic_option.name = "DynamicRangeOption"
	dynamic_option.add_item("Полный")
	dynamic_option.add_item("Сниженный")
	dynamic_option.select(clampi(_settings.dynamic_range, 0, 1))
	dynamic_option.item_selected.connect(_on_dynamic_range_selected)
	dynamic_row.add_child(dynamic_option)
	_content.add_child(dynamic_row)

	var reset := Button.new()
	reset.text = "СБРОСИТЬ НАСТРОЙКИ"
	reset.theme_type_variation = &"SecondaryButton"
	reset.custom_minimum_size = Vector2(0, 36)
	reset.pressed.connect(func() -> void:
		_show_confirm(
			"СБРОСИТЬ НАСТРОЙКИ?",
			"Все параметры звука, графики и доступности вернутся к значениям по умолчанию.",
			_reset_settings,
			false
		)
	)
	_wire_button(reset)
	_content.add_child(reset)


func _reset_settings() -> void:
	_settings.reset_defaults()
	_settings.reset_all_bindings()
	_settings.apply()
	_settings.save_settings()
	_show_section(SECTION_SETTINGS)
	_footer_note.text = "Настройки сброшены."


func _settings_row(title: String, slider_name: String, value: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := _label(title, &"BodyLabel")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var slider := HSlider.new()
	slider.name = slider_name
	slider.custom_minimum_size = Vector2(180, 24)
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = roundi(value * 100.0)
	slider.value_changed.connect(_on_volume_changed.bind(slider_name))
	row.add_child(slider)

	var value_label := _label("%d%%" % roundi(value * 100.0), &"TinyMutedLabel", Vector2(40, 0))
	value_label.name = slider_name + "Value"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	return row


func _build_controls() -> void:
	_content.add_child(_title("УПРАВЛЕНИЕ", "НАЖМИТЕ, ЧТОБЫ ПЕРЕНАЗНАЧИТЬ"))
	_content.add_child(
		_body("Выберите действие и нажмите новую клавишу. Backspace — очистить, Esc — отмена.")
	)

	var reset_all := Button.new()
	reset_all.text = "СБРОСИТЬ УПРАВЛЕНИЕ"
	reset_all.tooltip_text = "Вернуть все клавиши из project.godot"
	reset_all.theme_type_variation = &"SecondaryButton"
	reset_all.custom_minimum_size = Vector2(0, 36)
	reset_all.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset_all.pressed.connect(_on_reset_bindings_pressed)
	_content.add_child(reset_all)

	for section in InputBindings.SECTIONS:
		_content.add_child(_label(String(section["title"]), &"SectionLabel"))
		for action in section["actions"]:
			if not InputMap.has_action(action):
				continue
			var row := InputBindingRow.new()
			row.setup(_settings, action)
			row.binding_changed.connect(_on_binding_changed)
			_content.add_child(row)


func _on_binding_changed(_action: StringName, message: String) -> void:
	_footer_note.text = message


func _on_reset_bindings_pressed() -> void:
	_settings.reset_all_bindings()
	_settings.save_settings()
	_show_section(SECTION_CONTROLS)
	_footer_note.text = "Управление сброшено."


func _ask_main_menu() -> void:
	_show_confirm(
		"ВЫЙТИ В ГЛАВНОЕ МЕНЮ?",
		"Текущая сцена будет закрыта. Несохранённый прогресс демо-прохождения не переносится.",
		func() -> void: main_menu_requested.emit()
	)


func _ask_quit() -> void:
	_show_confirm(
		"ВЫЙТИ ИЗ ИГРЫ?",
		"Приложение будет закрыто без дополнительного сохранения.",
		func() -> void: quit_requested.emit()
	)


func _show_confirm(title: String, text: String, on_yes: Callable, close_after := true) -> void:
	_confirmation_open = true
	if _esc_hint != null:
		_esc_hint.text = ESC_CANCEL
	if _footer_note != null:
		_footer_note.text = FOOTER_CONFIRM
	_clear_content()
	_content.add_child(_title(title, "ПОДТВЕРЖДЕНИЕ"))
	_content.add_child(_body(text))
	_content.add_child(_rule())

	var yes := Button.new()
	yes.text = "ДА"
	yes.theme_type_variation = &"DangerButton"
	yes.custom_minimum_size = Vector2(0, 42)
	yes.pressed.connect(func() -> void:
		_confirmation_open = false
		if close_after:
			visible = false
		on_yes.call()
	)
	_wire_button(yes)
	_content.add_child(yes)

	var no := Button.new()
	no.text = "ОТМЕНА"
	no.theme_type_variation = &"SecondaryButton"
	no.custom_minimum_size = Vector2(0, 42)
	no.pressed.connect(func() -> void: _show_section(_active_section))
	_wire_button(no)
	_content.add_child(no)
	no.grab_focus()


func _get_objective_data() -> Dictionary:
	var quests := get_node_or_null(^"/root/QuestSystem")
	if quests != null and quests.has_method(&"is_scope_active") and bool(quests.call(&"is_scope_active")):
		var text := String(quests.call(&"get_tracked_objective_text")).strip_edges()
		if not text.is_empty():
			var quest: Resource = quests.call(&"get_tracked_quest") as Resource
			var code := String(quest.get(&"code")) if quest != null else ""
			var meta := "ЗАДАНИЕ"
			if not code.is_empty():
				meta += " " + code
			var objective: Resource = quests.call(&"get_tracked_objective") as Resource
			if objective != null:
				var progress := int(quests.call(&"get_objective_progress", quest.get(&"id"), objective.get(&"id")))
				var required := int(objective.get(&"required_count"))
				if required > 1:
					meta += " · %d/%d" % [progress, required]
			return {"text": text, "meta": meta}
	var guide := get_node_or_null(^"/root/CampaignGuide")
	if guide != null:
		var text := String(guide.get(&"display_objective")).strip_edges()
		var beat_id := StringName(guide.call(&"get_current_beat_id")) if guide.has_method(&"get_current_beat_id") else &""
		var beat_title := String(guide.call(&"get_current_beat_title")) if guide.has_method(&"get_current_beat_title") else ""
		if not text.is_empty():
			return {"text": text, "meta": "СОБЫТИЕ · %s · %s" % [String(beat_id), beat_title]}
	return {"text": "Цель не задана.", "meta": "ПЕРВЫЙ КОШМАР"}


func _refresh_objective() -> void:
	var data := _get_objective_data()
	if _objective != null:
		_objective.text = String(data.get("text", "Цель не задана."))
	if _objective_meta != null:
		_objective_meta.text = String(data.get("meta", ""))


func _connect_settings() -> void:
	pass


func _on_volume_changed(value: float, slider_name: String) -> void:
	if _updating_ui:
		return
	match slider_name:
		"MasterSlider":
			_settings.master_volume = clampf(value / 100.0, 0.0, 1.0)
		"MusicSlider":
			_settings.music_volume = clampf(value / 100.0, 0.0, 1.0)
		"AmbienceSlider":
			_settings.ambience_volume = clampf(value / 100.0, 0.0, 1.0)
		"SfxSlider":
			_settings.sfx_volume = clampf(value / 100.0, 0.0, 1.0)
		"VoiceSlider":
			_settings.voice_volume = clampf(value / 100.0, 0.0, 1.0)
		"UiSlider":
			_settings.ui_volume = clampf(value / 100.0, 0.0, 1.0)
	_settings.apply_audio()
	_settings.save_settings()
	_play_ui(&"ui_slider")
	var value_label := _content.find_child(slider_name + "Value", true, false) as Label
	if value_label != null:
		value_label.text = "%d%%" % roundi(value)


func _on_fullscreen_toggled(enabled: bool) -> void:
	if _updating_ui:
		return
	_play_ui(&"ui_toggle")
	_settings.fullscreen = enabled
	_settings.apply_graphics()
	_settings.save_settings()


func _on_captions_toggled(enabled: bool) -> void:
	if _updating_ui:
		return
	_play_ui(&"ui_toggle")
	_settings.captions_enabled = enabled
	_commit_audio_settings()


func _on_mono_toggled(enabled: bool) -> void:
	if _updating_ui:
		return
	_play_ui(&"ui_toggle")
	_settings.mono_downmix = enabled
	_commit_audio_settings()


func _on_dynamic_range_selected(index: int) -> void:
	if _updating_ui:
		return
	_play_ui(&"ui_toggle")
	_settings.dynamic_range = clampi(index, 0, 1)
	_commit_audio_settings()


func _commit_audio_settings() -> void:
	_settings.apply_audio()
	_settings.save_settings()
	_footer_note.text = "Звук сохранён."


func _build_credits_dialog() -> void:
	_credits_dialog = CreditsDialog.new()
	_credits_dialog.name = "CreditsDialog"
	add_child(_credits_dialog)


func _open_credits() -> void:
	if _credits_dialog == null:
		_build_credits_dialog()
	if _credits_dialog != null:
		_credits_dialog.present("Кредиты и лицензии", _load_credits_text())


func _load_credits_text() -> String:
	var data: Resource = load(CREDITS_PATH)
	if data != null:
		var text := String(data.get(&"text")).strip_edges()
		if not text.is_empty():
			return text
	return "Полный список лицензий: docs/ASSET_LICENSES.md."


func _action_keys_text(action: StringName) -> String:
	var parts: Array[String] = []
	for event in InputMap.action_get_events(action):
		var text := _event_text(event)
		if not text.is_empty() and not parts.has(text):
			parts.append(text)
	return " / ".join(parts) if not parts.is_empty() else "—"


func _event_text(event: InputEvent) -> String:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		var code := key_event.physical_keycode
		if code == 0:
			code = key_event.keycode
		return OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return "ЛКМ"
			MOUSE_BUTTON_RIGHT:
				return "ПКМ"
			MOUSE_BUTTON_MIDDLE:
				return "СКМ"
			_:
				return "Мышь %d" % (event as InputEventMouseButton).button_index
	if event is InputEventJoypadButton:
		return "Геймпад %d" % (event as InputEventJoypadButton).button_index
	if event is InputEventJoypadMotion:
		return "Стик"
	return event.as_text()


func _clear_content() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


func _title(title: String, overline: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(_label(overline, &"OverlineLabel"))
	var value := _label(title, &"ScreenTitleSmall")
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(value)
	return box


func _body(text: String) -> Label:
	var label := _label(text, &"BodyLabel")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _label(text: String, variation: StringName, minimum := Vector2.ZERO) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.custom_minimum_size = minimum
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _rule() -> ColorRect:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 1)
	line.color = Color(0.32, 0.29, 0.23, 0.7)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

class_name HudControlHints
extends VBoxContainer
## Reference-style control reminders, bottom-right. Key labels are read from
## InputMap, so rebinding the action updates the HUD instead of leaving a lie.

const ENTRIES := [
	{"action": &"sprint", "label": "Ускориться"},
	{"action": &"interact", "label": "Взаимодействие"},
	{"action": &"open_map", "label": "Карта"},
]

var _signature := ""
var _refresh_timer := 0.0


func _ready() -> void:
	theme = RpgMenuTheme.build()
	alignment = BoxContainer.ALIGNMENT_END
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rebuild()


func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer > 0.0:
		return
	_refresh_timer = 1.0
	if _build_signature() != _signature:
		_rebuild()


func _rebuild() -> void:
	_signature = _build_signature()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for entry in ENTRIES:
		add_child(_build_row(entry["action"], entry["label"]))


func _build_row(action: StringName, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", RpgMenuTheme.TEXT)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 3)
	row.add_child(label)

	var keycap := PanelContainer.new()
	keycap.custom_minimum_size = Vector2(28, 20)
	keycap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.040, 0.045, 0.9)
	style.border_color = RpgMenuTheme.BRONZE_DIM
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 1.0
	style.content_margin_bottom = 1.0
	keycap.add_theme_stylebox_override("panel", style)

	var key := Label.new()
	key.text = _key_text(action)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key.add_theme_font_size_override("font_size", 11)
	key.add_theme_color_override("font_color", RpgMenuTheme.BRONZE_BRIGHT)
	keycap.add_child(key)
	row.add_child(keycap)
	return row


func _build_signature() -> String:
	var parts := PackedStringArray()
	for entry in ENTRIES:
		parts.append("%s=%s" % [entry["action"], _key_text(entry["action"])])
	return "|".join(parts)


func _key_text(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
			if code != 0:
				return OS.get_keycode_string(code)
		elif event is InputEventMouseButton:
			var mouse := event as InputEventMouseButton
			match mouse.button_index:
				MOUSE_BUTTON_LEFT:
					return "ЛКМ"
				MOUSE_BUTTON_RIGHT:
					return "ПКМ"
	return "?"


func get_rows_text() -> PackedStringArray:
	var result := PackedStringArray()
	for row in get_children():
		var parts := PackedStringArray()
		for child in row.get_children():
			if child is Label:
				parts.append((child as Label).text)
			elif child is PanelContainer:
				for sub in child.get_children():
					if sub is Label:
						parts.append((sub as Label).text)
		result.append(" ".join(parts))
	return result

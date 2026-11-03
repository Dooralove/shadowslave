class_name HudQuickItems
extends PanelContainer
## Compact carried-supplies strip, bottom-left, modeled after the quick-item
## list in the reference HUD. It reads real NightmareRunState item counts.

const ENTRIES := [
	{"id": &"provisions", "name": "Хлеб", "icon": preload("res://assets/ui/rpg_menu/icons/ration.svg")},
	{"id": &"water_skin", "name": "Вода", "icon": preload("res://assets/ui/rpg_menu/icons/potion.svg")},
	{"id": &"torch", "name": "Факел", "icon": preload("res://assets/ui/rpg_menu/icons/torch.svg")},
]

@onready var _rows: VBoxContainer = %Rows

var _run_state: Node


func _ready() -> void:
	theme = RpgMenuTheme.build()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_run_state = get_node_or_null(^"/root/NightmareRunState")
	if _run_state != null and _run_state.has_signal(&"item_changed"):
		_run_state.item_changed.connect(_on_item_changed)
	_rebuild()


func _on_item_changed(_id: StringName, _count: int) -> void:
	_rebuild()


func _rebuild() -> void:
	if _rows == null:
		return
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for entry in ENTRIES:
		var count := _item_count(entry["id"])
		_rows.add_child(_build_row(entry, count))


func _build_row(entry: Dictionary, count: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 7)

	var icon := TextureRect.new()
	icon.texture = entry["icon"] as Texture2D
	icon.custom_minimum_size = Vector2(26, 26)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color(1.0, 0.95, 0.84, 1.0) if count > 0 else Color(1.0, 1.0, 1.0, 0.30)
	row.add_child(icon)

	var quantity := Label.new()
	quantity.text = str(count)
	quantity.custom_minimum_size = Vector2(22, 0)
	quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantity.add_theme_font_size_override("font_size", 13)
	quantity.add_theme_color_override("font_color", RpgMenuTheme.BRONZE_BRIGHT if count > 0 else RpgMenuTheme.DIM)
	quantity.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	quantity.add_theme_constant_override("outline_size", 3)
	row.add_child(quantity)

	var label := Label.new()
	label.text = String(entry["name"])
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", RpgMenuTheme.TEXT if count > 0 else RpgMenuTheme.DIM)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 3)
	row.add_child(label)
	return row


func _item_count(item_id: StringName) -> int:
	if _run_state == null or not _run_state.has_method(&"get_item_count"):
		return 0
	return int(_run_state.call(&"get_item_count", item_id))


func get_rows_text() -> PackedStringArray:
	var result := PackedStringArray()
	for row in _rows.get_children():
		var parts := PackedStringArray()
		for child in row.get_children():
			if child is Label:
				parts.append((child as Label).text)
		result.append(" ".join(parts))
	return result
